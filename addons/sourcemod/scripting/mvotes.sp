#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include <autoexecconfig>
#include <multicolors>
#include <mvotes>

#define LoopValidClients(%1) for (int %1 = 1; %1 <= MaxClients; %1++) if (IsClientValid(%1))

#define LoopPollsArray(%1) for (int %1 = 0; %1 < g_aPolls.Length; %1++)
#define LoopOptionsArray(%1) for (int %1 = 0; %1 < g_aOptions.Length; %1++)
#define LoopVotesArray(%1) for (int %1 = 0; %1 < g_aVotes.Length; %1++)
#define LoopCustomArray(%1,%2) for (int %1 = 0; %1 < %2.Length; %1++)

#include "mvotes/globals.sp"
#include "mvotes/stocks.sp"
#include "mvotes/sql.sp"
#include "mvotes/natives.sp"
#include "mvotes/create.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLoaded = false;

    CreateNative("MVotes_CreatePoll", Native_CreatePoll);
    CreateNative("MVotes_ExtendPoll", Native_ExtendPoll);
    CreateNative("MVotes_ClosePoll", Native_ClosePoll);

    RegPluginLibrary("mvotes");

    return APLRes_Success;
}

public Plugin myinfo = 
{
    name = "mVotes",
    author = "Bara",
    description = "Voting plugin based on mysql",
    version = "1.0.0-beta",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.mvotes");
    g_cDebug = AutoExecConfig_CreateConVar("mvotes_debug_mode", "1", "Enable or disable debug debug mode", _, true, 0.0, true, 1.0);
    g_cEntry = AutoExecConfig_CreateConVar("mvotes_database_entry", "mvotes", "Name for the database entry in your databases.cfg");
    g_cMinOptions = AutoExecConfig_CreateConVar("mvotes_min_options", "2", "Required options for a vote", _, true, 2.0);
    g_cMinLength = AutoExecConfig_CreateConVar("mvotes_min_length", "1", "Minimum length (length in minutes) otherwise Vote start will failed", _, true, 1.0);
    g_cMessageAll = AutoExecConfig_CreateConVar("mvotes_message_all", "1", "Print message to all players if a new poll was created? (0 - disable, 1 - enable)", _, true, 0.0, true, 1.0);
    g_cMessageOnDeath = AutoExecConfig_CreateConVar("mvotes_print_message_on_death", "1", "Print message to a player on their death?", _, true, 0.0, true, 1.0);
    g_cDeadPlayers = AutoExecConfig_CreateConVar("mvotes_only_dead_players", "0", "Allow voting just for dead players?", _, true, 0.0, true, 1.0);
    g_cPluginTag = AutoExecConfig_CreateConVar("mvotes_plugin_tag", "{darkred}[MVotes] {default}", "Set plugin tag for all chat messages");
    g_cMessageInterval = AutoExecConfig_CreateConVar("mvotes_message_interval", "120", "Prints every X seconds an message to all players. (0 - Disabled)", _, true, 0.0);
    g_cMessageType = AutoExecConfig_CreateConVar("mvotes_message_type", "1", "Which message? 0 - Print the amount of all active (unvoted + voted) votes, 1 - Print the amount of all active unvoted votes.", _, true, 0.0, true, 1.0);
    g_cAdminFlag = AutoExecConfig_CreateConVar("mvotes_admin_flags", "k", "Admin flags to get access for creating votes. (Default: k)");
    g_cMenuAfterVote = AutoExecConfig_CreateConVar("mvotes_menu_after_vote", "1", "Which menu after vote? 0 - Main Menu, 1 - Menu with the current poll", _, true, 0.0, true, 1.0);
    g_cDeleteOwnVotes = AutoExecConfig_CreateConVar("mvotes_delete_own_votes", "0", "Allow deleting own votes from a poll? It just work while the Poll is still active.", _, true, 0.0, true, 1.0);
    g_cKeywords = AutoExecConfig_CreateConVar("mvotes_keywords", "", "Set your server keywords (up to 16 keywords), if you have more servers and want polls for specific servers.\nSeparate each keyword with \";\"\nPolls without an keyword will always displayed");
    AutoExecConfig_ExecuteFile();    AutoExecConfig_CleanFile();

    g_cPluginTag.AddChangeHook(CVar_ChangeHook);

    RegConsoleCmd("sm_votes", Command_Votes);
    RegConsoleCmd("sm_createvote", Command_CreateVote);
    RegConsoleCmd("sm_extendvote", Command_ExtendVote);

    HookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);

    LoadTranslations("core.phrases");
    LoadTranslations("mvotes.phrases");
}

public void OnConfigsExecuted()
{
    char sBuffer[64];
    g_cPluginTag.GetString(sBuffer, sizeof(sBuffer));
    CSetPrefix(sBuffer);

    InitSQL();

    if (g_cMessageInterval.FloatValue > 0.0)
    {
        CreateTimer(g_cMessageInterval.FloatValue, Timer_PrintMessage, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void CVar_ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cPluginTag)
    {
        CSetPrefix(newValue);
    }
}

public void OnClientPostAdminCheck(int client)
{
    LoadClientVotes(client);
}

public void OnClientDisconnect(int client)
{
    RemoveClientVotes(client);
    ResetCreateVote(client);
    ResetExtendVote(client);
}

public Action Command_Votes(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    ListPolls(client);

    return Plugin_Continue;
}

public Action Command_ExtendVote(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    char sFlags[24];
    g_cAdminFlag.GetString(sFlags, sizeof(sFlags));
    
    int iFlags = ReadFlagString(sFlags);
    if (!CheckCommandAccess(client, "sm_extendvote", iFlags, true))
    {
        return Plugin_Handled;
    }

    ExtendPollList(client);

    return Plugin_Continue;
}

public Action Event_PlayerDeathPost(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cMessageOnDeath.BoolValue)
    {
        return;
    }

    int iActive = GetActivePolls();

    if (iActive <= 0)
    {
        return;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientValid(client))
    {
        return;
    }

    if (g_cMessageType.IntValue == 0)
    {
        CPrintToChat(client, "%T", "Chat Advert", client, iActive);
    }
    else if (g_cMessageType.IntValue == 1)
    {
        int iUnvoted = GetUnvotedVotes(client, iActive);
        
        if (iUnvoted > 0)
        {
            CPrintToChat(client, "%T", "Chat Advert", client, iUnvoted);
        }
    }
}

public Action Timer_PrintMessage(Handle timer)
{
    int iActive = GetActivePolls();

    if (iActive > 0)
    {
        LoopValidClients(client)
        {
            if (g_cMessageType.IntValue == 0)
            {
                CPrintToChat(client, "%T", "Chat Advert", client, iActive);
            }
            else if (g_cMessageType.IntValue == 1)
            {
                int iUnvoted = GetUnvotedVotes(client, iActive);
                
                if (iUnvoted > 0)
                {
                    CPrintToChat(client, "%T", "Chat Advert", client, iUnvoted);
                }
            }
        }
    }
}

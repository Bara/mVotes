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

#define MVOTES_ADMINFLAG ADMFLAG_GENERIC

#include "mvotes/globals.sp"
#include "mvotes/stocks.sp"
#include "mvotes/sql.sp"
#include "mvotes/natives.sp"
#include "mvotes/create.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLoaded = false;

    CreateNative("MVotes_CreatePoll", Native_CreatePoll);
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
    g_cAllowRevote = AutoExecConfig_CreateConVar("mvotes_allow_revote", "1", "Allow revoting? (0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
    g_cMessageOnDeath = AutoExecConfig_CreateConVar("mvotes_print_message_on_death", "1", "Print message to a player on their death?", _, true, 0.0, true, 1.0);
    g_cDeadPlayers = AutoExecConfig_CreateConVar("mvotes_only_dead_players", "0", "Allow voting just for dead players?", _, true, 0.0, true, 1.0);
    g_cPluginTag = AutoExecConfig_CreateConVar("mvotes_plugin_tag", "{darkred}[MVotes] {default}", "Set plugin tag for all chat messages");
    g_cMessageInterval = AutoExecConfig_CreateConVar("mvotes_message_interval", "120", "Prints every X seconds an message to all players. (0 - Disabled)", _, true, 0.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    g_cPluginTag.AddChangeHook(CVar_ChangeHook);

    RegConsoleCmd("sm_votes", Command_Votes);
    RegAdminCmd("sm_createvote", Command_CreateVote, ADMFLAG_ROOT);

    HookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);

    LoadTranslations("core.phrases");
    LoadTranslations("mvotes.phrases");
}

public void OnConfigsExecuted()
{
    char sBuffer[64];
    g_cPluginTag.GetString(sBuffer, sizeof(sBuffer));
    CSetPrefix(sBuffer);

    initSQL();

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

    CPrintToChat(client, "%T", "Chat Advert", client, iActive);
}

public Action Timer_PrintMessage(Handle timer)
{
    int iActive = GetActivePolls();

    if (iActive > 0)
    {
        LoopValidClients(client)
        {
            CPrintToChat(client, "%T", "Chat Advert", client, iActive);
        }
    }
}
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <mvotes>

#define LoopValidClients(%1) for (int %1 = 1; %1 <= MaxClients; %1++) if (IsClientValid(%1))
#define LoopPollsArray(%1) for (int %1 = 0; %1 < g_aPolls.Length; %1++)
#define LoopOptionsArray(%1) for (int %1 = 0; %1 < g_aOptions.Length; %1++)
#define LoopVotesArray(%1) for (int %1 = 0; %1 < g_aVotes.Length; %1++)

#include "mvotes/globals.sp"
#include "mvotes/stocks.sp"
#include "mvotes/sql.sp"
#include "mvotes/natives.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_bLoaded = false;

    CreateNative("MVotes_CreatePoll", Native_CreatePoll);

    RegPluginLibrary("mvotes");

    return APLRes_Success;
}

public Plugin myinfo = 
{
    name = "mVotes",
    author = "Bara",
    description = "Voting plugin based on mysql",
    version = "1.0.0-dev",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    g_cDebug = CreateConVar("mvotes_debug_mode", "1", "Enable or disable debug debug mode", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cAddTests = CreateConVar("mvotes_debug_add_tests", "1", "Add 3 new test votes on start up?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cEntry = CreateConVar("mvotes_database_entry", "mvotes", "Name for the database entry in your databases.cfg");
    g_cMinOptions = CreateConVar("mvotes_min_options", "2", "Required options for a vote", FCVAR_NOTIFY, true, 2.0);
    g_cMinLength = CreateConVar("mvotes_min_length", "1", "(Time in minutes) Is a length less than this value -> Vote start failed", FCVAR_NOTIFY, true, 1.0);
    g_cMessageAll = CreateConVar("mvotes_message_all", "0", "Print message to all players if a new poll was created? (0 - disable, 1 - enable)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cAllowRevote = CreateConVar("mvotes_allow_revote", "0", "Allow revoting? (0 - disable, 1 - enable", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    RegAdminCmd("sm_votes", Command_Votes, ADMFLAG_ROOT);

    HookEvent("player_death", Event_PlayerDeathPost, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
    initSQL();

    if (g_cDebug.BoolValue && g_cAddTests.BoolValue)
    {
        CreateTimer(3.0, Timer_AddTestPoll);
    }
}

public Action Timer_AddTestPoll(Handle timer)
{
    char sBuffer[64];

    for (int i = 0; i < 3; i++)
    {
        ArrayList aTest = new ArrayList(24);
        aTest.PushString("Yes");
        aTest.PushString("No");
        Format(sBuffer, sizeof(sBuffer), "Test Vote %d", GetRandomInt(100, 999));
        MVotes_CreatePoll(-1, sBuffer, GetRandomInt(43800, 262800), aTest);
    }
}

public void OnClientPostAdminCheck(int client)
{
	LoadClientVotes(client);
}

public void OnClientDisconnect(int client)
{
    RemoveClientVotes(client);
}

public Action Command_Votes(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (!g_bLoaded)
    {
        CReplyToCommand(client, "{darkred}[MVotes] {default}This function is currently not available.");
    }

    ListVotes(client);

    return Plugin_Continue;
}

public Action Event_PlayerDeathPost(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientValid(client))
    {
        return;
    }

    if (!CheckCommandAccess(client, "sm_admin", ADMFLAG_ROOT))
    {
        return;
    }

    CPrintToChat(client, "{darkred}[MVotes] {default}We've currently {darkblue}%d {default}active votes.", GetActivePolls());
}

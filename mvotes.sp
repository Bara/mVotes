#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#include "mvotes/globals.sp"
#include "mvotes/stocks.sp"
#include "mvotes/sql.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("mvotes");

    return APLRes_Success;
}

public Plugin myinfo = 
{
    name = "mVotes",
    author = "Bara",
    description = "Core plugin for mysql votes",
    version = "1.0.0-dev",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    g_cDebug = CreateConVar("mvotes_debug_mode", "1", "Enable or disable debug debug mode", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cEntry = CreateConVar("mvotes_database_entry", "mvotes", "Name for the database entry in your databases.cfg");
    g_cMinOptions = CreateConVar("mvotes_min_options", "2", "Required options for a vote", FCVAR_NOTIFY, true, 2.0);
    g_cMinLength = CreateConVar("mvotes_min_length", "1", "(Time in minutes) Is a length less than this value -> Vote start failed", FCVAR_NOTIFY, true, 1.0);
}

public void OnConfigsExecuted()
{
    initSQL();

    if (g_cDebug.BoolValue)
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

        Format(sBuffer, sizeof(sBuffer), "Test Vote %d", i);
        CreatePoll(-1, sBuffer, GetRandomInt(5, 1000), aTest);
    }
}

Database g_dDatabase = null;

ConVar g_cDebug = null;
ConVar g_cEntry = null;
ConVar g_cMinOptions = null;
ConVar g_cMinLength = null;
ConVar g_cMessageAll = null;

int g_iCreateTables = -1;

enum ePolls
{
    eID = 0,
    bool:eStatus,
    eCreated,
    eExipre,
    String:eTitle[64]
};

int g_iPolls[ePolls];
ArrayList g_aPolls = null;

enum eOptions
{
    eID = 0,
    ePoll,
    String:eOption[32]
}

int g_iOptions[eOptions];
ArrayList g_aOptions = null;

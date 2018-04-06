Database g_dDatabase = null;

ConVar g_cDebug = null;
ConVar g_cPrintToBara = null;
ConVar g_cEntry = null;
ConVar g_cMinOptions = null;
ConVar g_cMinLength = null;
ConVar g_cMessageAll = null;
ConVar g_cAllowRevote = null;
ConVar g_cDeadPlayers = null;
ConVar g_cPluginTag = null;

int g_iCreateTables = -1;

bool g_bLoaded = false;

enum ePolls
{
    eID = 0,
    bool:eStatus,
    eCreated,
    eExpire,
    String:eTitle[64]
};

int g_iPolls[ePolls];
ArrayList g_aPolls = null;

enum eOptions
{
    eID = 0,
    ePoll,
    String:eOption[32]
};

int g_iOptions[eOptions];
ArrayList g_aOptions = null;

enum eVotes
{
    eID = 0,
    eTime,
    ePollID,
    eOptionID,
    String:eCommunity[18]
};

int g_iVotes[eVotes];
ArrayList g_aVotes = null;

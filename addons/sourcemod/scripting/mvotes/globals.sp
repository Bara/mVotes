Database g_dDatabase = null;

ConVar g_cDebug = null;
ConVar g_cEntry = null;
ConVar g_cMinOptions = null;
ConVar g_cMinLength = null;
ConVar g_cMessageAll = null;
ConVar g_cAllowRevote = null;
ConVar g_cDeadPlayers = null;
ConVar g_cPluginTag = null;
ConVar g_cMessageOnDeath = null;
ConVar g_cMessageInterval = null;

int g_iCreateTables = -1;

bool g_bLoaded = false;

enum ePolls
{
    pID = 0,
    bool:pStatus,
    pCreated,
    pExpire,
    String:pTitle[64]
};

int g_iPolls[ePolls];
ArrayList g_aPolls = null;

enum eOptions
{
    oID = 0,
    oPoll,
    String:oOption[32]
};

int g_iOptions[eOptions];
ArrayList g_aOptions = null;

enum eVotes
{
    vID = 0,
    vTime,
    vPollID,
    vOptionID,
    String:vCommunity[18]
};

int g_iVotes[eVotes];
ArrayList g_aVotes = null;

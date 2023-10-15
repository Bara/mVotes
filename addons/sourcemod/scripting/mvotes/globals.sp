Database g_dDatabase = null;

ConVar g_cDebug = null;
ConVar g_cEntry = null;
ConVar g_cMinOptions = null;
ConVar g_cMinLength = null;
ConVar g_cMessageAll = null;
ConVar g_cDeadPlayers = null;
ConVar g_cPluginTag = null;
ConVar g_cMessageOnDeath = null;
ConVar g_cMessageInterval = null;
ConVar g_cMessageType = null;
ConVar g_cAdminFlag = null;
ConVar g_cMenuAfterVote = null;
ConVar g_cDeleteOwnVotes = null;
ConVar g_cKeywords = null;
ConVar g_cRequiredKeywords = null;

int g_iCreateTables = -1;

bool g_bLoaded = false;

enum struct Poll
{
    int ID;
    bool Status;
    int Created;
    int Expire;
    int Votes;
    char Title[64];
    char Keywords[128];
    char Map[32];
}

ArrayList g_aPolls = null;

enum struct Option
{
    int ID;
    int Poll;
    char Option[32];
}

ArrayList g_aOptions = null;

enum struct Vote
{
    int ID;
    int Time;
    int PollID;
    int OptionID;
    char Community[18];
}

ArrayList g_aVotes = null;

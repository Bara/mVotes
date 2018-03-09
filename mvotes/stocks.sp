static int g_iTime = -1;
static int g_iExpire = -1;

stock void initSQL()
{
    if (g_dDatabase == null)
    {
        _sqlConnect();
    }
}

stock void LoadPolls()
{
    if (g_aPolls != null)
    {
        g_aPolls.Clear();
    }

    if (g_aOptions != null)
    {
        g_aOptions.Clear();
    }

    g_aOptions = new ArrayList(sizeof(g_iOptions));
    g_aPolls = new ArrayList(sizeof(g_iPolls));

    char sPolls[] = "SELECT id, status, title, created, expire FROM mvotes_polls WHERE status = 1;";

    if (g_cDebug.BoolValue)
    {
        LogMessage("[CreateTables.LoadPolls] Polls Query: %s", sPolls);
    }

    g_dDatabase.Query(sqlLoadPolls, sPolls);
}

stock void UpdatePollStatus(int poll)
{
    char sUpdate[128];
    Format(sUpdate, sizeof(sUpdate), "UPDATE mvotes_polls SET status = 0 WHERE id = %d;", poll);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.UpdatePollStatus] Update Query: %s", sUpdate);
    }

    g_dDatabase.Query(sqlUpdatePollStatus, sUpdate);
}

stock bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	
	return false;
}

stock void CreatePoll(int client = -1, const char[] title, int length, ArrayList options)
{
    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreatePoll] Poll \"%s\" (Length: %d) will be created...", title, length);
    }

    if (options.Length < g_cMinOptions.IntValue)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (We need %d or more options for a vote)...", title, g_cMinOptions.IntValue);
        }

        return;
    }

    if (length < g_cMinLength.IntValue)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (Length must at least %d minutes)...", title, g_cMinLength.IntValue);
        }

        return;
    }

    g_iTime = GetTime();
    g_iExpire = g_iTime + (length * 60); // length are in minutes, so we'll convert it into seconds

    if (g_iTime > g_iExpire)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (current time it higher as expire time)...", title, g_iTime, g_iExpire);
        }

        return;
    }

    char sAdmin[24];

    if (!IsClientValid(client) || !GetClientAuthId(client, AuthId_SteamID64, sAdmin, sizeof(sAdmin)))
    {
        Format(sAdmin, sizeof(sAdmin), "CONSOLE");
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreatePoll] Poll \"%s\", Admin: %s", title, sAdmin);
    }

    int iPort = GetConVarInt(FindConVar("hostport"));

    char sIP[18];
    int _iIP[4];
    int iIP = GetConVarInt(FindConVar("hostip"));
    _iIP[0] = (iIP >> 24) & 0x000000FF;
    _iIP[1] = (iIP >> 16) & 0x000000FF;
    _iIP[2] = (iIP >> 8) & 0x000000FF;
    _iIP[3] = iIP & 0x000000FF;
    Format(sIP, sizeof(sIP), "%d.%d.%d.%d", _iIP[0], _iIP[1], _iIP[2], _iIP[3]);

    char sInsert[256];
    Format(sInsert, sizeof(sInsert), "INSERT INTO `mvotes_polls` (`status`, `title`, `created`, `expire`, `admin`, `ip`, `port`) VALUES (1, \"%s\", %d, %d, \"%s\", \"%s\", %d);", title, g_iTime, g_iExpire, sAdmin, sIP, iPort);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreatePoll] Insert Query: %s", sInsert);
    }

    DataPack dp = new DataPack();
    g_dDatabase.Query(sqlInsertPoll, sInsert, dp);
    dp.WriteString(title);
    dp.WriteCell(g_iTime);
    dp.WriteCell(g_iExpire);
    dp.WriteCell(options);
}

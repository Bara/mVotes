static int g_iAntiSpam = -1;
static char g_sCharset[12] = "utf8mb4";

void _sqlConnect()
{
    char sEntry[32];
    g_cEntry.GetString(sEntry, sizeof(sEntry));

    if (!SQL_CheckConfig(sEntry))
    {
        SetFailState("[MVotes.OnConfigsExecuted] We can't find the entry \"%s\" in your databases.cfg", sEntry);
        return;
    }

    Database.Connect(sqlConnect, sEntry);
}

public void sqlConnect(Database db, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlConnect] Database handle is invalid! (Error: %s)", error);
        return;
    }

    g_dDatabase = db;

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.sqlConnect] Connection was successful!");
    }

    if (!g_dDatabase.SetCharset("utf8mb4"))
    {
        g_dDatabase.SetCharset("utf8");
        Format(g_sCharset, sizeof(g_sCharset), "utf8");
    }

    CreateTables();
}

void CreateTables()
{
    g_iCreateTables = 0;

    char sQuery[1024];

    Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `mvotes_polls` ( \
            `id` int(11) NOT NULL AUTO_INCREMENT, \
            `status` tinyint(1) NOT NULL, \
            `title` varchar(64) NOT NULL, \
            `created` int(11) NOT NULL, \
            `expire` int(11) NOT NULL, \
            `admin` varchar(24) NOT NULL, \
            `ip` varchar(18) NOT NULL, \
            `port` int(6) NOT NULL, \
            PRIMARY KEY (`id`), \
            UNIQUE KEY (`title`, `created`) \
        ) ENGINE=InnoDB CHARSET=\"%s\"", g_sCharset);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreateTables] Polls Query: %s", sQuery);
    }
    
    g_dDatabase.Query(sqlCreateTables, sQuery, 1);
    
    Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `mvotes_options` ( \
            `id` int(11) NOT NULL AUTO_INCREMENT, \
            `poll` int(11) NOT NULL, \
            `option` varchar(32) NOT NULL, \
            PRIMARY KEY (`id`), \
            UNIQUE KEY (`poll`, `option`) \
        ) ENGINE=InnoDB CHARSET=\"%s\"", g_sCharset);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreateTables] Options Query: %s", sQuery);
    }

    g_dDatabase.Query(sqlCreateTables, sQuery, 2);
    
    Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `mvotes_votes` ( \
            `id` int(11) NOT NULL AUTO_INCREMENT, \
            `time` int(11) NOT NULL, \
            `poll` int(11) NOT NULL, \
            `option` int(11) NOT NULL, \
            `communityid` varchar(24) NOT NULL, \
            `name` varchar(128) NOT NULL, \
            PRIMARY KEY (`id`), \
            UNIQUE KEY (`poll`, `communityid`) \
        ) ENGINE=InnoDB CHARSET=\"%s\"", g_sCharset);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreateTables] Votes Query: %s", sQuery);
    }

    g_dDatabase.Query(sqlCreateTables, sQuery, 3);
}

public void sqlCreateTables(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlCreateTables] Query (%d) failed: %s", data, error);
        return;
    }
    else
    {
        g_iCreateTables++;

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlCreateTables] Table: %d, g_iCreateTables: %d", data, g_iCreateTables);
        }

        if (g_iCreateTables == 3)
        {
            LoadPolls();
            g_bLoaded = true;
        }
    }
}

public void sqlLoadPolls(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlLoadPolls] Query failed: %s", error);
        return;
    }
    else
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlLoadPolls] HasResults: %d RowCount: %d", results.HasResults, results.RowCount);
        }

        if (results.HasResults)
        {
            while (results.FetchRow())
            {
                int iPoll = results.FetchInt(0);
                bool bStatus = view_as<bool>(results.FetchInt(1));

                char sTitle[64];
                results.FetchString(2, sTitle, sizeof(sTitle));

                int iCreated = results.FetchInt(3);
                int iExpire = results.FetchInt(4);

                if (iExpire < GetTime())
                {
                    bStatus = false;
                    ClosePoll(iPoll);
                }

                if (bStatus)
                {
                    int iPolls[ePolls];

                    iPolls[pID] = iPoll;
                    iPolls[pStatus] = bStatus;
                    iPolls[pCreated] = iCreated;
                    iPolls[pExpire] = iExpire;
                    Format(iPolls[pTitle], sizeof(sTitle), sTitle);

                    g_aPolls.PushArray(iPolls[0]);

                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.sqlLoadPolls.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s", iPolls[pID], iPolls[pStatus], iPolls[pCreated], iPolls[pExpire], iPolls[pTitle]);
                    }

                    char sQuery[256];
                    Format(sQuery, sizeof(sQuery), "SELECT `id`, `poll`, `option` FROM `mvotes_options` WHERE `poll` = '%d' ORDER BY `id` ASC;", iPoll);
                    g_dDatabase.Query(sqlLoadOptions, sQuery);
                }
            }
        }

        LoopValidClients(client)
        {
            LoadClientVotes(client);
        }
    }
}

public void sqlLoadOptions(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlLoadOptions] Query failed: %s", error);
        return;
    }
    else
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlLoadOptions] HasResults: %d RowCount: %d", results.HasResults, results.RowCount);
        }

        if (results.HasResults)
        {
            while (results.FetchRow())
            {
                int iOptionID = results.FetchInt(0);
                int iPoll = results.FetchInt(1);

                char sOption[64];
                results.FetchString(2, sOption, sizeof(sOption));

                int iOption[eOptions];

                iOption[oID] = iOptionID;
                iOption[oPoll] = iPoll;
                Format(iOption[oOption], sizeof(sOption), sOption);

                g_aOptions.PushArray(iOption[0]);

                if (g_cDebug.BoolValue)
                {
                    LogMessage("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", iOption[oID], iOption[oPoll], iOption[oOption]);
                }
            }
        }
    }
}

public void sqlClosePoll(Database db, DBResultSet results, const char[] error, int poll)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlClosePoll] Query failed: %s", error);
        return;
    }
    else
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlClosePoll] Clear client stuff...");
        }

        LoopValidClients(i)
        {
            RemoveClientVotes(i, poll);
        }

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlClosePoll] Clear polls array...");
        }

        LoopPollsArray(i)
        {
            int iPolls[ePolls];
            g_aPolls.GetArray(i, iPolls[0]);

            if (iPolls[pID] == poll)
            {
                g_aPolls.Erase(i);
                break;
            }
        }

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlClosePoll] Clear options array...");
        }

        LoopOptionsArray(i)
        {
            int iOptions[eOptions];
            g_aOptions.GetArray(i, iOptions[0]);

            if (iOptions[oPoll] == poll)
            {
                g_aOptions.Erase(i);
            }
        }
    }
}

public void sqlInsertPoll(Database db, DBResultSet results, const char[] error, DataPack dp)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlInsertPoll] Query failed: %s", error);
        delete dp;
        return;
    }
    else
    {
        dp.Reset();
        char sTitle[64];
        dp.ReadString(sTitle, sizeof(sTitle));
        int iCreated = dp.ReadCell();
        int iExpire = dp.ReadCell();
        ArrayList aOptions = dp.ReadCell();
        delete dp;

        int iPoll = results.InsertId;
        bool bStatus = true;

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlInsertPoll] PollID: %d Title: %s, Created: %d, Expire: %d, Options: %d, Options.Length: %d", iPoll, sTitle, iCreated, iExpire, aOptions, aOptions.Length);
        }

        int iPolls[ePolls];

        iPolls[pID] = iPoll;
        iPolls[pStatus] = bStatus;
        iPolls[pCreated] = iCreated;
        iPolls[pExpire] = iExpire;
        Format(iPolls[pTitle], sizeof(sTitle), sTitle);

        g_aPolls.PushArray(iPolls[0]);

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlInsertPoll.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s", iPolls[pID], iPolls[pStatus], iPolls[pCreated], iPolls[pExpire], iPolls[pTitle]);
        }

        LoopCustomArray(i, aOptions)
        {
            char sOption[32];
            aOptions.GetString(i, sOption, sizeof(sOption));

            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlInsertPoll] Poll: %d, Option: %s", iPoll, sOption);
            }

            char sQuery[256];
            Format(sQuery, sizeof(sQuery), "INSERT INTO `mvotes_options` (`poll`, `option`) VALUES ('%d', \"%s\");", iPoll, sOption);

            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlInsertPoll] Insert Query: %s", sQuery);
            }

            DataPack dp2 = new DataPack();
            g_dDatabase.Query(sqlInsertOptions, sQuery, dp2);
            dp2.WriteCell(iPoll);
            dp2.WriteString(sTitle);
            dp2.WriteString(sOption);
        }

        delete aOptions;
    }
}

public void sqlInsertOptions(Database db, DBResultSet results, const char[] error, DataPack dp)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlInsertOptions] Query failed: %s", error);
        delete dp;
        return;
    }
    else
    {
        dp.Reset();
        char sTitle[64], sOption[32];
        int iPoll = dp.ReadCell();
        dp.ReadString(sTitle, sizeof(sTitle));
        dp.ReadString(sOption, sizeof(sOption));
        delete dp;

        int iOptionID = results.InsertId;

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlLoadOptions] PollID: %d Title: %s, sOption: %s, iOption: %d", iPoll, sTitle, sOption, iOptionID);
        }

        int iOption[eOptions];

        iOption[oID] = iOptionID;
        iOption[oPoll] = iPoll;
        Format(iOption[oOption], sizeof(sOption), sOption);

        g_aOptions.PushArray(iOption[0]);

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", iOption[oID], iOption[oPoll], iOption[oOption]);
        }

        if (g_cMessageAll.BoolValue && (g_iAntiSpam == -1 || (g_iAntiSpam + 5 < GetTime())))
        {
            g_iAntiSpam = GetTime();
            CPrintToChatAll("%T", "Chat - Poll Available", LANG_SERVER, sTitle);
        }
    }
}

public void sqlPlayerVote(Database db, DBResultSet results, const char[] error, DataPack dp)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlPlayerVote] Query failed: %s", error);
        delete dp;
        return;
    }
    else
    {
        dp.Reset();

        int userid = dp.ReadCell();
        int poll = dp.ReadCell();
        int option = dp.ReadCell();
        int time = dp.ReadCell();

        delete dp;

        int client = GetClientOfUserId(userid);

        if (!IsClientValid(client))
        {
            return;
        }


        char sCommunity[18];
        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
        {
            return;
        }

        char sTitle[64], sOption[32];

        LoopPollsArray(i)
        {
            int iPolls[ePolls];
            g_aPolls.GetArray(i, iPolls[0]);

            if (iPolls[pID] == poll)
            {
                strcopy(sTitle, sizeof(sTitle), iPolls[pTitle]);
                break;
            }
        }

        LoopOptionsArray(i)
        {
            int iOptions[eOptions];
            g_aOptions.GetArray(i, iOptions[0]);

            if (iOptions[oID] == option)
            {
                strcopy(sOption, sizeof(sOption), iOptions[oOption]);
                break;
            }
        }

        CPrintToChat(client, "%T", "Chat - Voted For", client, sTitle, sOption);

        LoopVotesArray(i)
        {
            int iVotes[eVotes];
            g_aVotes.GetArray(i, iVotes[0]);

            if (StrEqual(sCommunity, iVotes[vCommunity], false))
            {
                if (iVotes[vPollID] == poll)
                {
                    g_aVotes.Erase(i);
                }
            }
        }

        int iVotes[eVotes];
        iVotes[vID] = results.InsertId;
        iVotes[vTime] = time;
        iVotes[vPollID] = poll;
        iVotes[vOptionID] = option;
        Format(iVotes[vCommunity], sizeof(sCommunity), sCommunity);

        g_aVotes.PushArray(iVotes[0]);

        ListPolls(client);
    }
}

public void sqlLoadClientVotes(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlLoadClientVotes] Query failed: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);

        if (IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlLoadClientVotes] HasResults: %d RowCount: %d", results.HasResults, results.RowCount);
            }

            if (results.HasResults)
            {
                while (results.FetchRow())
                {
                    int iID = results.FetchInt(0);
                    int iTime = results.FetchInt(1);
                    int iPoll = results.FetchInt(2);
                    int iOption = results.FetchInt(3);

                    bool bStatus = false;

                    LoopPollsArray(i)
                    {
                        int iPolls[ePolls];
                        g_aPolls.GetArray(i, iPolls[0]);

                        if (iPolls[pID] == iPoll)
                        {
                            if (iPolls[pExpire] > GetTime() && iPolls[pStatus])
                            {
                                bStatus = true;
                            }
                            else
                            {
                                ClosePoll(iPolls[pID]);
                                continue;
                            }
                        }
                    }

                    if (!bStatus)
                    {
                        continue;
                    }

                    char sCommunity[18];
                    results.FetchString(4, sCommunity, sizeof(sCommunity));

                    int iVotes[eVotes];
                    iVotes[vID] = iID;
                    iVotes[vTime] = iTime;
                    iVotes[vPollID] = iPoll;
                    iVotes[vOptionID] = iOption;
                    Format(iVotes[vCommunity], sizeof(sCommunity), sCommunity);

                    g_aVotes.PushArray(iVotes[0]);

                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.sqlLoadClientVotes.Cache] iID: %d, iTime: %d, iPoll: %d, iOption: %d, sCommunity: %s", iVotes[vID], iVotes[vTime], iVotes[vPollID], iVotes[vOptionID], iVotes[vCommunity]);
                    }
                }
            }
        }
    }
}

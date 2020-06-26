static int g_iAntiSpam = -1;
static char g_sCharset[12] = "utf8mb4";

void InitSQL()
{
    if (g_dDatabase != null)
    {
        return;
    }

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

    if (!g_dDatabase.SetCharset(g_sCharset))
    {
        Format(g_sCharset, sizeof(g_sCharset), "utf8");
        
        if (g_dDatabase.SetCharset(g_sCharset))
        {
            SetFailState("[MVotes.sqlConnect] SetCharset failed!");
            return;
        }
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
            `votes` int(11) NOT NULL, \
            `admin` varchar(24) NOT NULL, \
            `ip` varchar(18) NOT NULL, \
            `port` int(6) NOT NULL, \
            `keywords` varchar(128) DEFAULT NULL, \
            `map` varchar(32), \
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
            UNIQUE KEY (`communityid`, `poll`, `option`) \
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

        if (data == 1)
        {
            char sQuery[256];
            g_dDatabase.Format(sQuery, sizeof(sQuery), "ALTER TABLE `mvotes_polls` ADD COLUMN `map` VARCHAR(32) NULL;");
            g_dDatabase.Query(sqlAddColumn, sQuery);
        }

        if (g_iCreateTables == 3)
        {
            LoadPolls();
            g_bLoaded = true;
        }
    }
}

public void sqlAddColumn(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        if (StrContains(error, "duplicate", false) == -1)
        {
            SetFailState("[MVotes.sqlAddColumn] Query failed: %s", error);
        }
        return;
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
                int iVotes = results.FetchInt(5);

                char sKeywords[128];

                results.FetchString(6, sKeywords, sizeof(sKeywords));
                bool bAll = StrEqual(sKeywords, ".", false);

                if (iExpire < GetTime())
                {
                    bStatus = false;
                    ClosePoll(iPoll);
                }

                if (bStatus)
                {
                    bool bKeywords = CompareKeywords(sKeywords);
                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.sqlLoadPolls] iPoll: %d, bAll: %d, bKeywords: %d", iPoll, bAll, bKeywords);
                    }
                    
                    if (!bAll && !bKeywords)
                    {
                        continue;
                    }

                    Poll poll;

                    poll.ID = iPoll;
                    poll.Status = bStatus;
                    poll.Created = iCreated;
                    poll.Expire = iExpire;
                    poll.Votes = iVotes;
                    Format(poll.Title, sizeof(sTitle), sTitle);

                    g_aPolls.PushArray(poll);

                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.sqlLoadPolls.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s, iVotes: %d", poll.ID, poll.Status, poll.Created, poll.Expire, poll.Title, poll.Votes);
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

                Option option;

                option.ID = iOptionID;
                option.Poll = iPoll;
                Format(option.Option, sizeof(sOption), sOption);

                g_aOptions.PushArray(option);

                if (g_cDebug.BoolValue)
                {
                    LogMessage("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", option.ID, option.Poll, option.Option);
                }
            }
        }
    }
}

public void sqlClosePoll(Database db, DBResultSet results, const char[] error, int pollid)
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
            RemoveClientVotes(i, pollid);
        }

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlClosePoll] Clear polls array...");
        }

        LoopPollsArray(i)
        {
            Poll poll;
            g_aPolls.GetArray(i, poll);

            if (poll.ID == pollid)
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
            Option option;
            g_aOptions.GetArray(i, option);

            if (option.Poll == pollid)
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
        int iVotes = dp.ReadCell();
        ArrayList aKeywords = dp.ReadCell();
        int client = dp.ReadCell();
        delete dp;

        int iPoll = results.InsertId;
        bool bStatus = true;

        char sKeywords[128];

        if (aKeywords != null)
        {
            LoopCustomArray(i, aKeywords)
            {
                char sKeyword[16];
                aKeywords.GetString(i, sKeyword, sizeof(sKeyword));

                Format(sKeywords, sizeof(sKeywords), "%s%s;", sKeywords, sKeyword);
            }
        }

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlInsertPoll] PollID: %d Title: %s, Created: %d, Expire: %d, Options: %d, Options.Length: %d, Votes: %d, Keywords: %s", iPoll, sTitle, iCreated, iExpire, aOptions, aOptions.Length, iVotes, sKeywords);
        }


        bool bAll = StrEqual(sKeywords, ".", false);
        bool bKeywords = CompareKeywords(sKeywords);

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlInsertPoll] iPoll: %d, bAll: %d, bKeywords: %d", iPoll, bAll, bKeywords);
        }
        
        bool bServer = (bAll || (!bAll && bKeywords));

        if (bServer)
        {
            Poll poll;

            poll.ID = iPoll;
            poll.Status = bStatus;
            poll.Created = iCreated;
            poll.Expire = iExpire;
            poll.Votes = iVotes;
            Format(poll.Title, sizeof(sTitle), sTitle);
            Format(poll.Keywords, sizeof(sKeywords), sKeywords);

            g_aPolls.PushArray(poll);

            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlInsertPoll.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s, Votes: %d", poll.ID, poll.Status, poll.Created, poll.Expire, poll.Title, poll.Votes);
            }
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

            dp = new DataPack();
            g_dDatabase.Query(sqlInsertOptions, sQuery, dp);
            dp.WriteCell(iPoll);
            dp.WriteString(sTitle);
            dp.WriteString(sOption);
            dp.WriteCell(bServer);
            dp.WriteCell(client);
        }

        delete aOptions;
        delete aKeywords;
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
        bool bServer = dp.ReadCell();
        int client = dp.ReadCell();
        delete dp;

        int iOptionID = results.InsertId;

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlLoadOptions] PollID: %d Title: %s, sOption: %s, iOption: %d", iPoll, sTitle, sOption, iOptionID);
        }

        if (bServer)
        {
            Option option;

            option.ID = iOptionID;
            option.Poll = iPoll;
            Format(option.Option, sizeof(sOption), sOption);

            g_aOptions.PushArray(option);

            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", option.ID, option.Poll, option.Option);
            }

            if (g_cMessageAll.BoolValue && (g_iAntiSpam == -1 || (g_iAntiSpam + 5 < GetTime())))
            {
                g_iAntiSpam = GetTime();
                CPrintToChatAll("%T", "Chat - Poll Available", LANG_SERVER, sTitle);
            }
        }
        else if ((!bServer && IsClientValid(client)) && (g_iAntiSpam == -1 || (g_iAntiSpam + 5 < GetTime())))
        {
            g_iAntiSpam = GetTime();
            CPrintToChat(client, "%T", "Chat - Poll Created", client, sTitle);
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
        int pollid = dp.ReadCell();
        int optionid = dp.ReadCell();
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
        int iMax = 0;

        LoopPollsArray(i)
        {
            Poll poll;
            g_aPolls.GetArray(i, poll);
            if (poll.ID == pollid)
            {
                strcopy(sTitle, sizeof(sTitle), poll.Title);
                iMax = poll.Votes;
                break;
            }
        }

        LoopOptionsArray(i)
        {
            Option option;
            g_aOptions.GetArray(i, option);

            if (option.ID == optionid)
            {
                strcopy(sOption, sizeof(sOption), option.Option);
                break;
            }
        }

        CPrintToChat(client, "%T", "Chat - Voted For", client, sTitle, sOption);

        int votes = GetAmountOfVotes(client, pollid);

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlPlayerVote] Votes: %d, Max Votes: %d", votes, iMax);
        }

        if (votes >= iMax)
        {
            LoopVotesArray(i)
            {
                Vote vote;
                g_aVotes.GetArray(i, vote);

                if (StrEqual(sCommunity, vote.Community, false))
                {
                    if (vote.PollID == pollid)
                    {
                        g_aVotes.Erase(i);

                        char sQuery[512];
                        Format(sQuery, sizeof(sQuery), "DELETE FROM `mvotes_votes` WHERE `id` = '%d'", vote.ID);
                        g_dDatabase.Query(sqlDoNothing, sQuery);

                        break;
                    }
                }
            }
        }

        Vote vote;
        vote.ID = results.InsertId;
        vote.Time = time;
        vote.PollID = pollid;
        vote.OptionID = optionid;
        Format(vote.Community, sizeof(sCommunity), sCommunity);

        g_aVotes.PushArray(vote);

        if (iMax == 1 || g_cMenuAfterVote.IntValue == 0)
        {
            ListPolls(client);
        }
        else
        {
            ListPollOptions(client, pollid);
        }
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
                        Poll poll;
                        g_aPolls.GetArray(i, poll);

                        if (poll.ID == iPoll)
                        {
                            if (poll.Expire > GetTime() && poll.Status)
                            {
                                bStatus = true;
                            }
                            else
                            {
                                ClosePoll(poll.ID);
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

                    Vote vote;
                    vote.ID = iID;
                    vote.Time = iTime;
                    vote.PollID = iPoll;
                    vote.OptionID = iOption;
                    Format(vote.Community, sizeof(sCommunity), sCommunity);

                    g_aVotes.PushArray(vote);

                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.sqlLoadClientVotes.Cache] iID: %d, iTime: %d, iPoll: %d, iOption: %d, sCommunity: %s", vote.ID, vote.Time, vote.PollID, vote.OptionID, vote.Community);
                    }
                }
            }
        }
    }
}

public void sqlDoNothing(Database db, DBResultSet results, const char[] error, int userid)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlDoNothing] Query failed: %s", error);
        return;
    }
}


public void sqlDeletePlayerVote(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlDeletePlayerVote] Query failed: %s", error);
        delete pack;
        return;
    }

    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int poll = pack.ReadCell();
    delete pack;

    if (IsClientValid(client))
    {
        ListPollOptions(client, poll);
    }
}

public void sqlExtendPoll(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlExtendPoll] Query failed: %s", error);
        return;
    }
}

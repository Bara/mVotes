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
        PrintToBaraConsole("[MVotes.sqlConnect] Connection was successful!");
    }

    g_dDatabase.SetCharset("utf8mb4");

    CreateTables();
}

void CreateTables()
{
    g_iCreateTables = 0;

    char sPolls[] = "CREATE TABLE IF NOT EXISTS `mvotes_polls` \
        ( \
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
        ) ENGINE=InnoDB CHARSET=utf8mb4;";
    
    g_dDatabase.Query(sqlCreateTables, sPolls, 1);
    
    char sOptions[] = "CREATE TABLE IF NOT EXISTS `mvotes_options` \
        ( \
            `id` int(11) NOT NULL AUTO_INCREMENT, \
            `poll` int(11) NOT NULL, \
            `option` varchar(32) NOT NULL, \
            PRIMARY KEY (`id`), \
            UNIQUE KEY (`poll`, `option`) \
        ) ENGINE=InnoDB CHARSET=utf8mb4;";
    g_dDatabase.Query(sqlCreateTables, sOptions, 2);
    
    char sVotes[] = "CREATE TABLE IF NOT EXISTS `mvotes_votes` \
        ( \
            `id` int(11) NOT NULL AUTO_INCREMENT, \
            `time` int(11) NOT NULL, \
            `poll` int(11) NOT NULL, \
            `option` int(11) NOT NULL, \
            `communityid` varchar(24) NOT NULL, \
            `name` varchar(128) NOT NULL, \
            PRIMARY KEY (`id`), \
            UNIQUE KEY (`poll`, `communityid`) \
        ) ENGINE=InnoDB CHARSET=utf8mb4;";
    g_dDatabase.Query(sqlCreateTables, sVotes, 3);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreateTables] Polls Query: %s", sPolls);
        LogMessage("[MVotes.CreateTables] Options Query: %s", sOptions);
        LogMessage("[MVotes.CreateTables] Votes Query: %s", sVotes);
        PrintToBaraConsole("[MVotes.CreateTables] Polls Query: %s", sPolls);
        PrintToBaraConsole("[MVotes.CreateTables] Options Query: %s", sOptions);
        PrintToBaraConsole("[MVotes.CreateTables] Votes Query: %s", sVotes);
    }
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
            PrintToBaraConsole("[MVotes.sqlCreateTables] Table: %d, g_iCreateTables: %d", data, g_iCreateTables);
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
            PrintToBaraConsole("[MVotes.sqlLoadPolls] HasResults: %d RowCount: %d", results.HasResults, results.RowCount);
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
                    UpdatePollStatus(iPoll);
                }

                if (bStatus)
                {
                    int iPolls[ePolls];

                    iPolls[eID] = iPoll;
                    iPolls[eStatus] = bStatus;
                    iPolls[eCreated] = iCreated;
                    iPolls[eExipre] = iExpire;
                    Format(iPolls[eTitle], sizeof(sTitle), sTitle);

                    g_aPolls.PushArray(iPolls[0]);

                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.sqlLoadPolls.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s", iPolls[eID], iPolls[eStatus], iPolls[eCreated], iPolls[eExipre], iPolls[eTitle]);
                        PrintToBaraConsole("[MVotes.sqlLoadPolls.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s", iPolls[eID], iPolls[eStatus], iPolls[eCreated], iPolls[eExipre], iPolls[eTitle]);
                    }

                    char sOptions[128];
                    Format(sOptions, sizeof(sOptions), "SELECT id, poll, option FROM mvotes_options WHERE poll = %d ORDER BY id ASC;", iPoll);
                    g_dDatabase.Query(sqlLoadOptions, sOptions);
                }
            }
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
            PrintToBaraConsole("[MVotes.sqlLoadOptions] HasResults: %d RowCount: %d", results.HasResults, results.RowCount);
        }

        if (results.HasResults)
        {
            while (results.FetchRow())
            {
                int iOptionID = results.FetchInt(0);
                int iPoll = results.FetchInt(1);

                char sOption[64];
                results.FetchString(2, sOption, sizeof(sOption));

                int iOption[ePolls];

                iOption[eID] = iOptionID;
                iOption[ePoll] = iPoll;
                Format(iOption[eOption], sizeof(sOption), sOption);

                g_aOptions.PushArray(iOption[0]);

                if (g_cDebug.BoolValue)
                {
                    LogMessage("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", iOption[eID], iOption[ePoll], iOption[eOption]);
                    PrintToBaraConsole("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", iOption[eID], iOption[ePoll], iOption[eOption]);
                }
            }
        }
    }
}

public void sqlUpdatePollStatus(Database db, DBResultSet results, const char[] error, int poll)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("[MVotes.sqlUpdatePollStatus] Query failed: %s", error);
        return;
    }
    else
    {
        for (int i = 0; i < g_aPolls.Length; i++)
        {
            int iPolls[ePolls];
            g_aPolls.GetArray(i, iPolls[0]);

            if (iPolls[eID] == poll)
            {
                g_aPolls.Erase(i);
                break;
            }
        }

        for (int i = 0; i < g_aOptions.Length; i++)
        {
            int iOptions[eOption];
            g_aOptions.GetArray(i, iOptions[0]);

            if (iOptions[ePoll] == poll)
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
        PrintToBaraConsole("[MVotes.sqlInsertPoll] Query failed: %s", error);
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
            PrintToBaraConsole("[MVotes.sqlInsertPoll] PollID: %d Title: %s, Created: %d, Expire: %d, Options: %d, Options.Length: %d", iPoll, sTitle, iCreated, iExpire, aOptions, aOptions.Length);
        }

        int iPolls[ePolls];

        iPolls[eID] = iPoll;
        iPolls[eStatus] = bStatus;
        iPolls[eCreated] = iCreated;
        iPolls[eExipre] = iExpire;
        Format(iPolls[eTitle], sizeof(sTitle), sTitle);

        g_aPolls.PushArray(iPolls[0]);

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlInsertPoll.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s", iPolls[eID], iPolls[eStatus], iPolls[eCreated], iPolls[eExipre], iPolls[eTitle]);
            PrintToBaraConsole("[MVotes.sqlInsertPoll.Cache] iPoll: %d, bStatus: %d, iCreated: %d, iExpire: %d, sTitle: %s", iPolls[eID], iPolls[eStatus], iPolls[eCreated], iPolls[eExipre], iPolls[eTitle]);
        }

        for (int i = 0; i < aOptions.Length; i++)
        {
            char sOption[32];
            aOptions.GetString(i, sOption, sizeof(sOption));

            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlInsertPoll] Poll: %d, Option: %s", iPoll, sOption);
                PrintToBaraConsole("[MVotes.sqlInsertPoll] Poll: %d, Option: %s", iPoll, sOption);
            }

            char sInsert[256];
            Format(sInsert, sizeof(sInsert), "INSERT INTO `mvotes_options` (`poll`, `option`) VALUES (%d, \"%s\");", iPoll, sOption);

            if (g_cDebug.BoolValue)
            {
                LogMessage("[MVotes.sqlInsertPoll] Insert Query: %s", sInsert);
                PrintToBaraConsole("[MVotes.sqlInsertPoll] Insert Query: %s", sInsert);
            }

            DataPack dp2 = new DataPack();
            g_dDatabase.Query(sqlInsertOptions, sInsert, dp2);
            dp2.WriteCell(iPoll);
            dp2.WriteString(sTitle);
            dp2.WriteString(sOption);
        }
    }
}

public void sqlInsertOptions(Database db, DBResultSet results, const char[] error, DataPack dp)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[MVotes.sqlInsertOptions] Query failed: %s", error);
        PrintToBaraConsole("[MVotes.sqlInsertOptions] Query failed: %s", error);
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
            PrintToBaraConsole("[MVotes.sqlLoadOptions] PollID: %d Title: %s, sOption: %s, iOption: %d", iPoll, sTitle, sOption, iOptionID);
        }

        int iOption[ePolls];

        iOption[eID] = iOptionID;
        iOption[ePoll] = iPoll;
        Format(iOption[eOption], sizeof(sOption), sOption);

        g_aOptions.PushArray(iOption[0]);

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", iOption[eID], iOption[ePoll], iOption[eOption]);
            PrintToBaraConsole("[MVotes.sqlLoadOptions.Cache] iOptionID: %d, iPoll: %d, sOption: %s", iOption[eID], iOption[ePoll], iOption[eOption]);
        }

        if (g_cMessageAll.BoolValue)
        {
            CPrintToChatAll("{darkred}[MVotes] {default}The poll {darkblue}\"%s\" {default}is now available!", sTitle);
        }
    }
}

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
    delete g_aPolls;
    delete g_aOptions;
    delete g_aVotes;

    g_aOptions = new ArrayList(sizeof(g_iOptions));
    g_aPolls = new ArrayList(sizeof(g_iPolls));
    g_aVotes = new ArrayList(sizeof(g_iVotes));

    char sPolls[] = "SELECT id, status, title, created, expire FROM mvotes_polls WHERE status = 1 ORDER BY id ASC;";

    if (g_cDebug.BoolValue)
    {
        LogMessage("[CreateTables.LoadPolls] Polls Query: %s", sPolls);
        PrintToBaraConsole("[CreateTables.LoadPolls] Polls Query: %s", sPolls);
    }

    g_dDatabase.Query(sqlLoadPolls, sPolls);
}

stock void ClosePoll(int poll)
{
    char sUpdate[128];
    Format(sUpdate, sizeof(sUpdate), "UPDATE mvotes_polls SET status = 0 WHERE id = %d;", poll);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ClosePoll] Update Query: %s", sUpdate);
        PrintToBaraConsole("[MVotes.ClosePoll] Update Query: %s", sUpdate);
    }

    g_dDatabase.Query(sqlClosePoll, sUpdate, poll);
}

stock bool IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if (IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
        {
            return true;
        }
    }
    
    return false;
}

stock int CreatePoll(int client = -1, const char[] title, int length, ArrayList options)
{
    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreatePoll] Poll \"%s\" (Length: %d) will be created...", title, length);
        PrintToBaraConsole("[MVotes.CreatePoll] Poll \"%s\" (Length: %d) will be created...", title, length);
    }

    if (options.Length < g_cMinOptions.IntValue)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (We need %d or more options for a vote)...", title, g_cMinOptions.IntValue);
            PrintToBaraConsole("[MVotes.CreatePoll] Poll \"%s\" can't created (We need %d or more options for a vote)...", title, g_cMinOptions.IntValue);
        }

        return 2;
    }

    if (length < g_cMinLength.IntValue)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (Length must at least %d minutes)...", title, g_cMinLength.IntValue);
            PrintToBaraConsole("[MVotes.CreatePoll] Poll \"%s\" can't created (Length must at least %d minutes)...", title, g_cMinLength.IntValue);
        }

        return 1;
    }

    g_iTime = GetTime();
    g_iExpire = g_iTime + (length * 60); // length are in minutes, so we'll convert it into seconds

    if (g_iTime > g_iExpire)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (current time it higher as expire time)...", title, g_iTime, g_iExpire);
            PrintToBaraConsole("[MVotes.CreatePoll] Poll \"%s\" can't created (current time it higher as expire time)...", title, g_iTime, g_iExpire);
        }

        return 0;
    }

    char sAdmin[24];

    if (!IsClientValid(client) || !GetClientAuthId(client, AuthId_SteamID64, sAdmin, sizeof(sAdmin)))
    {
        Format(sAdmin, sizeof(sAdmin), "CONSOLE");
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreatePoll] Poll \"%s\", Admin: %s", title, sAdmin);
        PrintToBaraConsole("[MVotes.CreatePoll] Poll \"%s\", Admin: %s", title, sAdmin);
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
        PrintToBaraConsole("[MVotes.CreatePoll] Insert Query: %s", sInsert);
    }

    DataPack dp = new DataPack();
    g_dDatabase.Query(sqlInsertPoll, sInsert, dp);
    dp.WriteString(title);
    dp.WriteCell(g_iTime);
    dp.WriteCell(g_iExpire);
    dp.WriteCell(options);

    return -1;
}

void ListPolls(int client)
{
    if (!g_bLoaded)
    {
        CReplyToCommand(client, "{darkred}[MVotes] {default}This function is currently not available.");
        return;
    }

    if (g_cDeadPlayers.BoolValue && IsPlayerAlive(client))
    {
        CReplyToCommand(client, "{darkred}[MVotes] {default}This function is just for dead players.");
        return;
    }

    Menu menu = new Menu(Menu_PollList);
    menu.SetTitle("Active polls:"); // TODO

    LoopPollsArray(i)
    {
        int iPolls[ePolls];
        g_aPolls.GetArray(i, iPolls[0]);

        if (iPolls[eExpire] <= GetTime() || !iPolls[eStatus])
        {
            ClosePoll(iPolls[eID]);
            continue;
        }

        char sBuffer[12];
        IntToString(iPolls[eID], sBuffer, sizeof(sBuffer));

        char sCommunity[18];
        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
        {
            return;
        }

        bool bVoted = false;
        int option = -1;

        LoopVotesArray(j)
        {
            int iVotes[eVotes];
            g_aVotes.GetArray(j, iVotes[0]);

            if (StrEqual(sCommunity, iVotes[eCommunity], false) && iVotes[ePollID] == iPolls[eID])
            {
                bVoted = true;
                option = iVotes[eOptionID];

                break;
            }
        }

        char sTitle[64];

        if (bVoted)
        {
            if (g_cDebug.BoolValue)
            {
                Format(sTitle, sizeof(sTitle), "[VOTED.%d] ", option);
            }
            else
            {
                Format(sTitle, sizeof(sTitle), "[VOTED] ");
            }
        }

        Format(sTitle, sizeof(sTitle), "%s%s", sTitle, iPolls[eTitle]);
        
        if (g_cDebug.BoolValue)
        {
            Format(sTitle, sizeof(sTitle), "[%d] %s", iPolls[eID], sTitle);
        }

        if (!bVoted || (bVoted && g_cAllowRevote.BoolValue))
        {
            menu.AddItem(sBuffer, sTitle);
        }
        else 
        {
            menu.AddItem(sBuffer, sTitle, ITEMDRAW_DISABLED);
        }
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_PollList(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sBuffer[12];
        menu.GetItem(param, sBuffer, sizeof(sBuffer));
        int iPoll = StringToInt(sBuffer);

        ListPollOptions(client, iPoll);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ListPollOptions(int client, int poll)
{
    if (g_cDeadPlayers.BoolValue && IsPlayerAlive(client))
    {
        CReplyToCommand(client, "{darkred}[MVotes] {default}This function is just for dead players.");
        return;
    }

    Menu menu = new Menu(Menu_OptionList);

    LoopPollsArray(i)
    {
        int iPolls[ePolls];
        g_aPolls.GetArray(i, iPolls[0]);

        if (iPolls[eID] != poll)
        {
            continue;
        }

        menu.SetTitle(iPolls[eTitle]);
        break;
    }

    LoopOptionsArray(i)
    {
        int iOptions[ePolls];
        g_aOptions.GetArray(i, iOptions[0]);

        if (poll == iOptions[ePoll])
        {
            char sParam[24];
            Format(sParam, sizeof(sParam), "%d.%d", poll, iOptions[eID]);

            char sCommunity[18];
            if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
            {
                return;
            }

            bool bVoted = false;

            LoopVotesArray(j)
            {
                int iVotes[eVotes];
                g_aVotes.GetArray(j, iVotes[0]);

                if (StrEqual(sCommunity, iVotes[eCommunity], false) && iVotes[ePollID] == iOptions[ePoll] && iVotes[eOptionID] == iOptions[eID])
                {
                    bVoted = true;

                    break;
                }
            }

            char sOption[64];

            if (bVoted)
            {
                Format(sOption, sizeof(sOption), "[VOTED] ");
            }

            Format(sOption, sizeof(sOption), "%s%s", sOption, iOptions[eOption]);

            if (g_cDebug.BoolValue)
            {
                Format(sOption, sizeof(sOption), "[%d] %s", iOptions[eID], sOption);
            }

            if (!bVoted)
            {
                menu.AddItem(sParam, sOption);
            }
            else
            {
                menu.AddItem(sParam, sOption, ITEMDRAW_DISABLED);
            }
        }
    }

    menu.ExitBackButton = true;
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_OptionList(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sBuffer[24];
        menu.GetItem(param, sBuffer, sizeof(sBuffer));

        char sIDs[2][12];
        ExplodeString(sBuffer, ".", sIDs, sizeof(sIDs), sizeof(sIDs[]));

        int iPoll = StringToInt(sIDs[0]);
        int iOption = StringToInt(sIDs[1]);

        LoopPollsArray(i)
        {
            int iPolls[ePolls];
            g_aPolls.GetArray(i, iPolls[0]);

            if (iPolls[eExpire] <= GetTime() || !iPolls[eStatus])
            {
                ClosePoll(iPolls[eID]);

                if (iPoll == iPolls[eID])
                {
                    CPrintToChat(client, "{darkred}[MVotes] {default}The poll \"%s\" is no longer available.", iPolls[eTitle]);
                }
                
                return;
            }
        }

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.Menu_OptionList] Poll: %d (String: %s), Option: %d (String: %s)", iPoll, sIDs[0], iOption, sIDs[1]);
            PrintToBaraConsole("[MVotes.Menu_OptionList] Poll: %d (String: %s), Option: %d (String: %s)", iPoll, sIDs[0], iOption, sIDs[1]);
        }

        PlayerVote(client, iPoll, iOption);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_ExitBack)
        {
            ListPolls(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void PlayerVote(int client, int poll, int option)
{
    if (g_cDeadPlayers.BoolValue && IsPlayerAlive(client))
    {
        CReplyToCommand(client, "{darkred}[MVotes] {default}This function is just for dead players.");
        return;
    }
    
    char sCommunity[18];

    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return;
    }

    char sInsertUpdate[768];

    int iTime = GetTime();

    // TODO
    if (g_cAllowRevote.BoolValue)
    {
        g_dDatabase.Format(sInsertUpdate, sizeof(sInsertUpdate),
        "INSERT INTO `mvotes_votes` (`time`, `poll`, `option`, `communityid`, `name`) VALUES (%d, %d, %d, \"%s\", \"%N\") \
        ON DUPLICATE KEY UPDATE time = %d, option = %d, name = \"%N\";", iTime, poll, option, sCommunity, client, iTime, option, client);
    }
    else
    {
        g_dDatabase.Format(sInsertUpdate, sizeof(sInsertUpdate),
        "INSERT INTO `mvotes_votes` (`time`, `poll`, `option`, `communityid`, `name`) VALUES (%d, %d, %d, \"%s\", \"%N\");",
        iTime, poll, option, sCommunity, client);
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.PlayerVote] InsertUpdate Query: %s", sInsertUpdate);
        PrintToBaraConsole("[MVotes.PlayerVote] InsertUpdate Query: %s", sInsertUpdate);
    }

    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(poll);
    dp.WriteCell(option);
    dp.WriteCell(iTime);
    g_dDatabase.Query(sqlPlayerVote, sInsertUpdate, dp);
}

void LoadClientVotes(int client)
{
    if (!IsClientValid(client))
    {
        return;
    }

    char sCommunity[18];

    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return;
    }

    char sSelect[128];

    g_dDatabase.Format(sSelect, sizeof(sSelect), "SELECT id, time, poll, option, communityid FROM mvotes_votes WHERE communityid = \"%s\";", sCommunity);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.LoadClientVotes] Select Query: %s", sSelect);
        PrintToBaraConsole("[MVotes.LoadClientVotes] Select Query: %s", sSelect);
    }

    g_dDatabase.Query(sqlLoadClientVotes, sSelect, GetClientUserId(client));
}

void RemoveClientVotes(int client, int poll = -1)
{
    char sCommunity[18];

    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return;
    }

    LoopVotesArray(i)
    {
        int iVotes[eVotes];
        g_aVotes.GetArray(i, iVotes[0]);

        if (StrEqual(sCommunity, iVotes[eCommunity], false))
        {
            if (poll == -1)
            {
                g_aVotes.Erase(i);
            }
            else
            {
                if (iVotes[ePollID] == poll)
                {
                    g_aVotes.Erase(i);
                }
            }
        }
    }
}

void PrintToBaraConsole(const char[] message, any ...) 
{
    if (!g_cPrintToBara.BoolValue)
    {
        return;
    }

    LoopValidClients(i)
    {
        char steamid[64];
        GetClientAuthId(i, AuthId_Steam2, steamid, sizeof(steamid));
        
        if (StrEqual(steamid, "STEAM_1:1:40828751", false))
        {
            char sBuffer[MAX_MESSAGE_LENGTH];
            VFormat(sBuffer, sizeof(sBuffer), message, 2);

            PrintToConsole(i, sBuffer);
        }
    }
}

int GetActivePolls()
{
    int iVotes = 0;

    LoopPollsArray(i)
    {
        int iPolls[ePolls];
        g_aPolls.GetArray(i, iPolls[0]);

        if (iPolls[eExpire] <= GetTime() || !iPolls[eStatus])
        {
            ClosePoll(iPolls[eID]);
            continue;
        }

        if (iPolls[eStatus])
        {
            iVotes++;
        }
    }

    return iVotes;
}

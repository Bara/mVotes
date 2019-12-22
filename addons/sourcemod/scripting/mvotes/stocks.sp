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

    g_aOptions = new ArrayList(sizeof(Option));
    g_aPolls = new ArrayList(sizeof(Poll));
    g_aVotes = new ArrayList(sizeof(Vote));

    char sQuery[256];
    g_dDatabase.Format(sQuery, sizeof(sQuery), "SELECT `id`, `status`, `title`, `created`, `expire`, `votes` FROM `mvotes_polls` WHERE `status` = '1' ORDER BY `id` ASC");

    if (g_cDebug.BoolValue)
    {
        LogMessage("[CreateTables.LoadPolls] Polls Query: %s", sQuery);
    }

    g_dDatabase.Query(sqlLoadPolls, sQuery);
}

stock void ClosePoll(int poll)
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "UPDATE `mvotes_polls` SET `status` = '0' WHERE id = '%d';", poll);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ClosePoll] Update Query: %s", sQuery);
    }

    g_dDatabase.Query(sqlClosePoll, sQuery, poll);
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

stock int CreatePoll(int client = -1, const char[] title, int length, ArrayList options, int votes)
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

        return 2;
    }

    if (votes < 1 || votes > options.Length)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (We need less votes per players (votes %d, options: %d))...", title, votes, options.Length);
        }

        return 3;
    }

    if (length < g_cMinLength.IntValue)
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.CreatePoll] Poll \"%s\" can't created (Length must at least %d minutes)...", title, g_cMinLength.IntValue);
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

    char sQuery[1024];
    Format(sQuery, sizeof(sQuery), "INSERT INTO `mvotes_polls` (`status`, `title`, `created`, `expire`, `votes`, `admin`, `ip`, `port`) VALUES ('1', \"%s\", '%d', '%d', '%d', \"%s\", \"%s\", '%d');", title, g_iTime, g_iExpire, votes, sAdmin, sIP, iPort);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.CreatePoll] Insert Query: %s", sQuery);
    }

    DataPack dp = new DataPack();
    g_dDatabase.Query(sqlInsertPoll, sQuery, dp);
    dp.WriteString(title);
    dp.WriteCell(g_iTime);
    dp.WriteCell(g_iExpire);
    dp.WriteCell(options);
    dp.WriteCell(votes);

    return -1;
}

void ListPolls(int client)
{
    if (!g_bLoaded)
    {
        CReplyToCommand(client, "%T", "Chat - Function Disabled", client);
        return;
    }

    if (g_cDeadPlayers.BoolValue && IsPlayerAlive(client))
    {
        CReplyToCommand(client, "%T", "Chat - Dead Players", client);
        return;
    }

    char sBuffer[24];
    Format(sBuffer, sizeof(sBuffer), "%T", "Menu - Current polls", client);

    Menu menu = new Menu(Menu_PollList);
    menu.SetTitle(sBuffer);

    Format(sBuffer, sizeof(sBuffer), "%T", "Menu - Voted", client);

    LoopPollsArray(i)
    {
        Poll poll;
        g_aPolls.GetArray(i, poll);

        if (poll.Expire <= GetTime() || !poll.Status)
        {
            ClosePoll(poll.ID);
            continue;
        }

        /* int iCount = 0;
        LoopOptionsArray(j)
        {
            int iOptions[eOption];
            g_aOptions.GetArray(j, iOptions[0]);

            if (iPolls[pID] == iOptions[oPoll])
            {
                iCount++;
            }
        }

        if (iCount < g_cMinOptions.IntValue)
        {
            continue;
        } */

        char sPollID[12];
        IntToString(poll.ID, sPollID, sizeof(sPollID));

        char sCommunity[18];
        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
        {
            return;
        }

        bool bVoted = false;
        int option = -1;

        LoopVotesArray(j)
        {
            Vote vote;
            g_aVotes.GetArray(j, vote);

            if (StrEqual(sCommunity, vote.Community, false) && vote.PollID == poll.ID)
            {
                bVoted = true;
                option = vote.OptionID;

                break;
            }
        }

        char sTitle[64];

        if (bVoted)
        {
            if (g_cDebug.BoolValue)
            {
                Format(sTitle, sizeof(sTitle), "[%s.%d] ", sBuffer, option);
            }
            else
            {
                Format(sTitle, sizeof(sTitle), "[%s] ", sBuffer);
            }
        }

        Format(sTitle, sizeof(sTitle), "%s%s", sTitle, poll.Title);
        
        if (g_cDebug.BoolValue)
        {
            Format(sTitle, sizeof(sTitle), "[%d] %s", poll.ID, sTitle);
        }

        menu.AddItem(sPollID, sTitle);
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

void ListPollOptions(int client, int pollid)
{
    if (g_cDeadPlayers.BoolValue && IsPlayerAlive(client))
    {
        CReplyToCommand(client, "%T", "Chat - Dead Players", client);
        return;
    }

    Menu menu = new Menu(Menu_OptionList);

    LoopPollsArray(i)
    {
        Poll poll;
        g_aPolls.GetArray(i, poll);

        if (poll.ID != pollid)
        {
            continue;
        }

        int iVotes = GetAmountOfVotes(client, poll.ID);

        char sTitle[96];
        char sBufTitle[64];
        char sVotes[32];

        if (poll.Votes > 1)
        {
            strcopy(sBufTitle, sizeof(sBufTitle), poll.Title);
            Format(sVotes, sizeof(sVotes), "%T", "Menu - Options Multichoice", client, iVotes, poll.Votes);

            Format(sTitle, sizeof(sTitle), "%T", "Menu - Options menu multi", client, sBufTitle, sVotes);
        }
        else
        {
            strcopy(sTitle, sizeof(sTitle), poll.Title);
        }

        menu.SetTitle(sTitle);
        break;
    }

    LoopOptionsArray(i)
    {
        Option option;
        g_aOptions.GetArray(i, option);

        if (pollid == option.Poll)
        {
            char sCommunity[18];
            if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
            {
                return;
            }

            bool bVoted = false;

            LoopVotesArray(j)
            {
                Vote vote;
                g_aVotes.GetArray(j, vote);

                if (StrEqual(sCommunity, vote.Community, false) && vote.PollID == option.Poll && vote.OptionID == option.ID)
                {
                    bVoted = true;

                    break;
                }
            }

            char sParam[24];
            Format(sParam, sizeof(sParam), "%d.%d.%d", pollid, option.ID, bVoted);

            char sOption[64], sVoted[24];
            Format(sVoted, sizeof(sVoted), "%T", "Menu - Voted", client);

            if (bVoted)
            {
                Format(sOption, sizeof(sOption), "[%s] ", sVoted);
            }

            Format(sOption, sizeof(sOption), "%s%s", sOption, option.Option);

            if (g_cDebug.BoolValue)
            {
                Format(sOption, sizeof(sOption), "[%d.%d] %s", option.ID, bVoted, sOption);
            }

            if (!bVoted || (bVoted && g_cDeleteOwnVotes.BoolValue))
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

        char sIDs[3][12];
        ExplodeString(sBuffer, ".", sIDs, sizeof(sIDs), sizeof(sIDs[]));

        int iPoll = StringToInt(sIDs[0]);
        int iOption = StringToInt(sIDs[1]);
        bool bVoted = view_as<bool>(StringToInt(sIDs[2]));

        LoopPollsArray(i)
        {
            Poll poll;
            g_aPolls.GetArray(i, poll);

            if (poll.Expire <= GetTime() || !poll.Status)
            {
                ClosePoll(poll.ID);

                if (iPoll == poll.ID)
                {
                    CPrintToChat(client, "%T", "Chat - No longer available", client, poll.Title);
                }
                
                return;
            }
        }

        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.Menu_OptionList] Poll: %d (String: %s), Option: %d (String: %s), Voted: %d", iPoll, sIDs[0], iOption, sIDs[1], bVoted);
        }

        if (!bVoted)
        {
            PlayerVote(client, iPoll, iOption);
        }
        else
        {
            DeletePlayerVote(client, iPoll, iOption);
        }
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
        CReplyToCommand(client, "%T", "Chat - Dead Players", client);
        return;
    }
    
    char sCommunity[18];

    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return;
    }

    char sQuery[1024];

    int iTime = GetTime();

    g_dDatabase.Format(sQuery, sizeof(sQuery),
        "INSERT INTO `mvotes_votes` (`time`, `poll`, `option`, `communityid`, `name`) VALUES ('%d', '%d', '%d', \"%s\", \"%N\") \
        ON DUPLICATE KEY UPDATE `time` = '%d', `option` = '%d', `name` = \"%N\";", iTime, poll, option, sCommunity, client, iTime, option, client);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.PlayerVote] InsertUpdate Query: %s", sQuery);
    }

    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(poll);
    dp.WriteCell(option);
    dp.WriteCell(iTime);
    g_dDatabase.Query(sqlPlayerVote, sQuery, dp);
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

    char sQuery[256];
    g_dDatabase.Format(sQuery, sizeof(sQuery), "SELECT `id`, `time`, `poll`, `option`, `communityid` FROM `mvotes_votes` WHERE `communityid` = \"%s\"", sCommunity);

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.LoadClientVotes] Select Query: %s", sQuery);
    }

    g_dDatabase.Query(sqlLoadClientVotes, sQuery, GetClientUserId(client));
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
        Vote vote;
        g_aVotes.GetArray(i, vote);

        if (StrEqual(sCommunity, vote.Community, false))
        {
            if (poll == -1 || vote.PollID == poll)
            {
                g_aVotes.Erase(i);
            }
        }
    }
}


int GetActivePolls()
{
    int iVotes = 0;

    LoopPollsArray(i)
    {
        Poll poll;
        g_aPolls.GetArray(i, poll);

        if (poll.Expire <= GetTime() || !poll.Status)
        {
            ClosePoll(poll.ID);
            continue;
        }

        if (poll.Status)
        {
            iVotes++;
        }
    }

    return iVotes;
}

ArrayList GetActivePollsArray()
{
    ArrayList aPolls = new ArrayList();

    LoopPollsArray(i)
    {
        Poll poll;
        g_aPolls.GetArray(i, poll);

        if (poll.Expire <= GetTime() || !poll.Status)
        {
            ClosePoll(poll.ID);
            continue;
        }

        if (poll.Status)
        {
            aPolls.Push(poll.ID);
        }
    }

    return aPolls;
}

int GetUnvotedVotes(int client, int active)
{
    char sCommunity[18];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return -1;
    }

    ArrayList aPolls = GetActivePollsArray();

    LoopVotesArray(j)
    {
        Vote vote;
        g_aVotes.GetArray(j, vote);

        if (StrEqual(sCommunity, vote.Community, false) && aPolls.FindValue(vote.PollID) != -1)
        {
            active--;
        }
    }

    delete aPolls;

    return active;
}

int GetAmountOfVotes(int client, int poll)
{
    char sCommunity[18];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return -1;
    }

    int votes = 0;

    LoopVotesArray(j)
    {
        Vote vote;
        g_aVotes.GetArray(j, vote);

        if (StrEqual(sCommunity, vote.Community, false) && vote.PollID == poll)
        {
            votes++;
        }
    }

    return votes;
}

void DeletePlayerVote(int client, int poll, int option)
{
    char sCommunity[18];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunity, sizeof(sCommunity)))
    {
        return;
    }

    int iVoteID = 0;

    LoopVotesArray(i)
    {
        Vote vote;
        g_aVotes.GetArray(i, vote);

        if (StrEqual(sCommunity, vote.Community, false) && vote.PollID == poll && vote.OptionID == option)
        {
            iVoteID = vote.ID;
            g_aVotes.Erase(i);
        }
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.DeletePlayerVote] Vote ID: %d", iVoteID);
    }

    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "DELETE FROM `mvotes_votes` WHERE `id` = '%d'", iVoteID);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(poll);
    g_dDatabase.Query(sqlDeletePlayerVote, sQuery, pack);
}

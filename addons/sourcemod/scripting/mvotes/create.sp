static bool g_bTitle[MAXPLAYERS + 1] = { false, ... };
static bool g_bLength[MAXPLAYERS + 1] = { false, ... };
static bool g_bOptions[MAXPLAYERS + 1] = { false, ... };
static bool g_bVotes[MAXPLAYERS + 1] = { false, ... };
static bool g_bKeywords[MAXPLAYERS + 1] = { false, ... };

static int g_iLength[MAXPLAYERS + 1] = { -1, ...};
static int g_iVotes[MAXPLAYERS + 1] = { -1, ... };

static char g_sTitle[MAXPLAYERS + 1][64];
static char g_sMap[MAXPLAYERS + 1][32];

static ArrayList g_aCOptions[MAXPLAYERS + 1] = { null, ...};
static ArrayList g_aKeywords[MAXPLAYERS + 1] = { null, ...};

public Action Command_CreateVote(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    char sFlags[24];
    g_cAdminFlag.GetString(sFlags, sizeof(sFlags));
    
    int iFlags = ReadFlagString(sFlags);
    if (!CheckCommandAccess(client, "sm_createvote", iFlags, true))
    {
        return Plugin_Handled;
    }

    if (g_aCOptions[client] == null)
    {
        g_aCOptions[client] = new ArrayList(24);
    }

    ShowCreateMenu(client);

    return Plugin_Handled;
}

void ShowCreateMenu(int client)
{
    if (!IsClientValid(client))
    {
        return;
    }

    if (IsClientInExtend(client))
    {
        CPrintToChat(client, "%T", "Chat - Running process", client, "Extend Vote");
        return;
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ShowCreateMenu] called");
    }

    char sBuffer[64];

    Format(sBuffer, sizeof(sBuffer), "%T\n ", "Menu - Create Vote", client);

    Menu menu = new Menu(Menu_CreateMenu);
    menu.SetTitle(sBuffer);

    if (strlen(g_sTitle[client]) > 3)
    {
        Format(sBuffer, sizeof(sBuffer), "[X] %T", "Menu - Set title", client);
        menu.AddItem("title", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "[ ] %T", "Menu - Set title", client);
        menu.AddItem("title", sBuffer);
    }

    if (g_iLength[client] >= g_cMinLength.IntValue)
    {
        Format(sBuffer, sizeof(sBuffer), "[X] %T", "Menu - Set length", client);
        menu.AddItem("length", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "[ ] %T", "Menu - Set length", client);
        menu.AddItem("length", sBuffer);
    }

    if (g_aCOptions[client] != null && g_aCOptions[client].Length >= g_cMinOptions.IntValue)
    {
        Format(sBuffer, sizeof(sBuffer), "[X] %T ", "Menu - Set options", client);
        menu.AddItem("options", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "[ ] %T ", "Menu - Set options", client);
        menu.AddItem("options", sBuffer);
    }

    if (g_iVotes[client] > 0)
    {
        Format(sBuffer, sizeof(sBuffer), "[X] %T", "Menu - Set votes", client);
        menu.AddItem("votes", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "[ ] %T", "Menu - Set votes", client);
        menu.AddItem("votes", sBuffer);
    }

    if (g_aKeywords[client] != null)
    {
        Format(sBuffer, sizeof(sBuffer), "[X] %T", "Menu - Set keywords", client);
        menu.AddItem("keywords", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "[ ] %T", "Menu - Set keywords", client);
        menu.AddItem("keywords", sBuffer);
    }

    if (strlen(g_sMap[client]) > 2)
    {
        Format(sBuffer, sizeof(sBuffer), "[X] %T\n ", "Menu - Map based Set", client, g_sMap[client]);
        menu.AddItem("mapvote", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "[ ] %T\n ", "Menu - Map based", client);
        menu.AddItem("mapvote", sBuffer);
    }

    if (strlen(g_sTitle[client]) > 3 && g_iLength[client] >= g_cMinLength.IntValue && g_aCOptions[client].Length >= g_cMinOptions.IntValue && g_iVotes[client] > 0 && g_aKeywords[client] != null)
    {
        Format(sBuffer, sizeof(sBuffer), "> %T\n ", "Menu - Create Vote", client);
        menu.AddItem("create", sBuffer);
    }
    
    Format(sBuffer, sizeof(sBuffer), "%T", "Exit", client);
    menu.AddItem("exit", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_CreateMenu(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (IsClientInExtend(client))
        {
            CPrintToChat(client, "%T", "Chat - Running process", client, "Extend Vote");
            return;
        }

        char sParam[12];
        menu.GetItem(param, sParam, sizeof(sParam));
        
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.Menu_CreateMenu] Param: %s", sParam);
        }

        if (StrEqual(sParam, "title", false))
        {
            g_bTitle[client] = true;
            CPrintToChat(client, "%T", "Chat - Type title", client);
        }
        else if (StrEqual(sParam, "length", false))
        {
            g_bLength[client] = true;
            CPrintToChat(client, "%T", "Chat - Type length", client, g_cMinLength.IntValue);
        }
        else if (StrEqual(sParam, "options", false))
        {
            g_bOptions[client] = true;
            CPrintToChat(client, "%T", "Chat - Type options", client, g_cMinOptions.IntValue);
        }
        else if (StrEqual(sParam, "votes", false))
        {
            g_bVotes[client] = true;
            CPrintToChat(client, "%T", "Chat - Type votes", client);
        }
        else if (StrEqual(sParam, "keywords", false))
        {
            g_bKeywords[client] = true;
            CPrintToChat(client, "%T", "Chat - Type keywords", client);
        }
        else if (StrEqual(sParam, "mapvote", false))
        {
            if (strlen(g_sMap[client]) < 3)
            {
                GetCurrentMap(g_sMap[client], sizeof(g_sMap[]));
                CPrintToChat(client, "%T", "Chat - Map Saved", client, g_sMap[client]);
            }
            else
            {
                g_sMap[client][0] = '\0';
                CPrintToChat(client, "%T", "Chat - Map Reset", client);
            }

            ShowCreateMenu(client);
        }
        else if (StrEqual(sParam, "create", false))
        {
            int reason = -1;

            if (g_aKeywords[client].Length > 0)
            {
                reason = MVotes_CreatePoll(client, g_sTitle[client], g_iLength[client], g_aCOptions[client], g_iVotes[client], g_aKeywords[client], g_sMap[client]);
            }
            else
            {
                reason = MVotes_CreatePoll(client, g_sTitle[client], g_iLength[client], g_aCOptions[client], g_iVotes[client], null, g_sMap[client]);
            }

            DataPack pack = new DataPack();
            pack.WriteCell(GetClientUserId(client));
            pack.WriteCell(reason);
            CreateTimer(1.0, Timer_ResetCreateVote, pack);
        }
        else if (StrEqual(sParam, "exit", false))
        {
            ResetCreateVote(client, true);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Timer_ResetCreateVote(Handle timer, DataPack pack)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());
    int reason = pack.ReadCell();

    delete pack;

    if (IsClientValid(client))
    {
        ResetCreateVote(client);

        if (reason != -1)
        {
            char sReason[64];

            if (reason == 0)
            {
                Format(sReason, sizeof(sReason), "Invalid time");
            }
            else if (reason == 1)
            {
                Format(sReason, sizeof(sReason), "Invalid vote length");
            }
            else if (reason == 2)
            {
                Format(sReason, sizeof(sReason), "Invalid options");
            }
            else if (reason == 3)
            {
                Format(sReason, sizeof(sReason), "Invalid votes per player");
            }

            CPrintToChat(client, "Can't create vote. (%s)", sReason);
        }
    }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] message)
{
    if (IsClientValid(client))
    {
        if (CheckClientStatus(client))
        {
            if (StrEqual(message, "!abort", false))
            {
                ResetCreateVote(client, true);
                return Plugin_Stop;
            }

            if (g_bTitle[client])
            {
                if (strlen(message) > 3)
                {
                    strcopy(g_sTitle[client], sizeof(g_sTitle[]), message);
                    CPrintToChat(client, "%T", "Chat - Title", client, g_sTitle[client]);
                }
                else
                {
                    CPrintToChat(client, "%T", "Chat - Title too short", client);
                }
            }
            else if (g_bLength[client])
            {
                if (IsNumericString(message))
                {
                    int iLength = StringToInt(message);

                    if (iLength >= g_cMinLength.IntValue)
                    {
                        g_iLength[client] = iLength;
                        CPrintToChat(client, "%T", "Chat - Length", client, g_iLength[client]);
                    }
                    else
                    {
                        CPrintToChat(client, "%T", "Chat - Invalid length", client);
                    }
                }
                else
                {
                    CPrintToChat(client, "%T", "Chat - Not numeric length", client);
                }
            }
            else if (g_bOptions[client])
            {
                char sOptions[12][24];
                int iSize = ExplodeString(message, ";", sOptions, sizeof(sOptions), sizeof(sOptions[]));

                if (iSize >= g_cMinOptions.IntValue)
                {
                    for (int i = 0; i < iSize; i++)
                    {
                        if (strlen(sOptions[i]) < 1)
                        {
                            continue;
                        }

                        CPrintToChat(client, "%T", "Chat - Option", client, sOptions[i]);

                        g_aCOptions[client].PushString(sOptions[i]);

                        if (g_cDebug.BoolValue)
                        {
                            LogMessage("[MVotes.OnClientSayCommand] Added option %d: %s", i+1, sOptions[i]);
                        }
                    }
                }
                else
                {
                    CPrintToChat(client, "%T", "Chat - More Options", client);
                }
            }
            else if (g_bVotes[client])
            {
                if (IsNumericString(message))
                {
                    int iVotes = StringToInt(message);

                    if (iVotes > 0)
                    {
                        if (g_aCOptions[client].Length >= g_cMinOptions.IntValue)
                        {
                            if (iVotes <= g_aCOptions[client].Length)
                            {
                                g_iVotes[client] = iVotes;
                            }
                            else
                            {
                                CPrintToChat(client, "%T", "Chat - Too much votes", client);
                            }
                        }
                        else
                        {
                            CPrintToChat(client, "%T", "Chat - No options", client);
                        }
                    }
                    else
                    {
                        CPrintToChat(client, "%T", "Chat - Votes at least", client);
                    }
                }
                else
                {
                    CPrintToChat(client, "%T", "Chat - Not numeric length", client);
                }
            }
            else if (g_bKeywords[client])
            {
                if (strlen(message) > 0)
                {
                    g_aKeywords[client] = new ArrayList();

                    int iContains = StrContains(message, ";", false);
                    if (iContains != -1 || strlen(message) > 2)
                    {
                        char sKeywords[12][24];
                        int iSize = -1;

                        if (iContains > -1)
                        {
                            iSize = ExplodeString(message, ";", sKeywords, sizeof(sKeywords), sizeof(sKeywords[]));
                        }

                        if (iSize > 0)
                        {
                            for (int i = 0; i < iSize; i++)
                            {
                                if (strlen(sKeywords[i]) < 1)
                                {
                                    CPrintToChat(client, "%T", "Chat - Keyword - Too short", client, sKeywords[i]);
                                    continue;
                                }

                                CPrintToChat(client, "%T", "Chat - Keyword", client, sKeywords[i]);

                                g_aKeywords[client].PushString(sKeywords[i]);

                                if (g_cDebug.BoolValue)
                                {
                                    LogMessage("[MVotes.OnClientSayCommand] Added keyword %d: %s", i + 1, sKeywords[i]);
                                }
                            }

                            if (g_aKeywords[client].Length == 0)
                            {
                                CPrintToChat(client, "%T", "Chat - Keywords - All servers", client, message);
                            }
                        }
                        else
                        {
                            CPrintToChat(client, "%T", "Chat - Keyword", client, message);

                            g_aKeywords[client].PushString(message);

                            if (g_cDebug.BoolValue)
                            {
                                LogMessage("[MVotes.OnClientSayCommand] Added keyword: %s", message);
                            }
                        }
                    }
                    else if (StrEqual(message, ".", false))
                    {
                        CPrintToChat(client, "%T", "Chat - Keywords - All servers", client, message);

                        if (g_cDebug.BoolValue)
                        {
                            LogMessage("[MVotes.OnClientSayCommand] Added keyword: %s", message);
                        }
                    }
                }
            }

            g_bTitle[client] = false;
            g_bLength[client] = false;
            g_bOptions[client] = false;
            g_bVotes[client] = false;
            g_bKeywords[client] = false;

            ShowCreateMenu(client);

            return Plugin_Stop;
        }
        else if (IsClientInExtend(client))
        {
            if (StrEqual(message, "!abort", false))
            {
                ResetExtendVote(client);
                return Plugin_Stop;
            }

            
            if (IsNumericString(message))
            {
                int iLength = StringToInt(message);

                if (iLength >= g_cMinLength.IntValue)
                {
                    PrepareExtend(client, iLength);

                    CPrintToChat(client, "%T", "Chat - Length", client, iLength);
                }
                else
                {
                    CPrintToChat(client, "%T", "Chat - Invalid length", client);
                }
            }
            else
            {
                CPrintToChat(client, "%T", "Chat - Not numeric length", client);
            }
            
            ResetExtendVote(client, false);
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

bool CheckClientStatus(int client)
{
    return (g_bTitle[client] || g_bLength[client] || g_bOptions[client] || g_bVotes[client] || g_bKeywords[client]);
}

void ResetCreateVote(int client, bool message = false)
{
    g_bTitle[client] = false;
    g_bLength[client] = false;
    g_bOptions[client] = false;
    g_bVotes[client] = false;
    g_bKeywords[client] = false;

    g_sTitle[client][0] = '\0';
    g_sMap[client][0] = '\0';
    
    g_iLength[client] = -1;
    g_iVotes[client] = -1;

    delete g_aCOptions[client];
    delete g_aKeywords[client];

    if (!IsFakeClient(client) && !IsClientSourceTV(client) && g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ResetCreateVote] called");
    }

    if (message && IsClientValid(client))
    {
        if (!IsFakeClient(client) && !IsClientSourceTV(client) && g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.ResetCreateVote] 3");
        }

        CPrintToChat(client, "%T", "Settings reset", client);
    }
}

// Stock taken from smlib - https://github.com/bcserv/smlib/blob/62da6de/scripting/include/smlib/strings.inc#L16
bool IsNumericString(const char[] str)
{
    int x = 0;
    int dotsFound = 0;
    int numbersFound = 0;

    if (str[x] == '+' || str[x] == '-')
    {
        x++;
    }

    while (str[x] != '\0') {

        if (IsCharNumeric(str[x]))
        {
            numbersFound++;
        }
        else if (str[x] == '.')
        {
            dotsFound++;

            if (dotsFound > 1)
            {
                return false;
            }
        }
        else
        {
            return false;
        }

        x++;
    }

    if (!numbersFound)
    {
        return false;
    }

    return true;
}

static bool g_bTitle[MAXPLAYERS + 1] = { false, ... };
static bool g_bLength[MAXPLAYERS + 1] = { false, ... };
static bool g_bOptions[MAXPLAYERS + 1] = { false, ... };

static char g_sTitle[MAXPLAYERS + 1][64];
static int g_iLength[MAXPLAYERS + 1] = { -1, ...};

static ArrayList g_aCOptions[MAXPLAYERS + 1] = { null, ...};

public Action Command_CreateVote(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.Command_CreateVote] g_aCOptions1: %d", g_aCOptions[client]);
        PrintToBaraConsole("[MVotes.Command_CreateVote] g_aCOptions1: %d", g_aCOptions[client]);
    }

    if (g_aCOptions[client] == null)
    {
        g_aCOptions[client] = new ArrayList(24);
    }

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.Command_CreateVote] g_aCOptions2: %d", g_aCOptions[client]);
        PrintToBaraConsole("[MVotes.Command_CreateVote] g_aCOptions2: %d", g_aCOptions[client]);
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

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ShowCreateMenu] called");
        PrintToBaraConsole("[MVotes.ShowCreateMenu] called");
    }

    char sBuffer[24];

    Menu menu = new Menu(Menu_CreateMenu);
    menu.SetTitle("Create vote\n ");

    if (strlen(g_sTitle[client]) > 3)
    {
        menu.AddItem("title", "[X] Set title");
    }
    else
    {
        menu.AddItem("title", "[ ] Set title");
    }

    if (g_iLength[client] >= g_cMinLength.IntValue)
    {
        menu.AddItem("length", "[X] Set length");
    }
    else
    {
        menu.AddItem("length", "[ ] Set length");
    }

    if (g_aCOptions[client].Length >= g_cMinOptions.IntValue)
    {
        menu.AddItem("options", "[X] Set options\n ");
    }
    else
    {
        menu.AddItem("options", "[ ] Set options\n ");
    }

    if (strlen(g_sTitle[client]) > 3 && g_iLength[client] >= g_cMinLength.IntValue && g_aCOptions[client].Length >= g_cMinOptions.IntValue)
    {
        menu.AddItem("create", "> Create Vote\n");
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
        char sParam[12];
        menu.GetItem(param, sParam, sizeof(sParam));
        
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.Menu_CreateMenu] Param: %s", sParam);
            PrintToBaraConsole("[MVotes.Menu_CreateMenu] Param: %s", sParam);
        }

        if (StrEqual(sParam, "title", false))
        {
            g_bTitle[client] = true;

            CPrintToChat(client, "{darkred}[MVotes] {default}Type your title in chat or abort with '!abort'.");
        }
        else if (StrEqual(sParam, "length", false))
        {
            g_bLength[client] = true;

            CPrintToChat(client, "{darkred}[MVotes] {default}Type your length in chat or abort with '!abort'.");
        }
        else if (StrEqual(sParam, "options", false))
        {
            g_bOptions[client] = true;

            CPrintToChat(client, "{darkred}[MVotes] {default}Type your options in chat or abort with '!abort'.");
        }
        else if (StrEqual(sParam, "create", false))
        {
            MVotes_CreatePoll(client, g_sTitle[client], g_iLength[client], g_aCOptions[client]);
            CreateTimer(1.0, Timer_ResetCreateVote, GetClientUserId(client));
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

public Action Timer_ResetCreateVote(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        ResetCreateVote(client);
    }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] message)
{
    if (IsClientValid(client) && CheckClientStatus(client))
    {
        if (StrEqual(message, "!abort", false))
        {
            ResetCreateVote(client, true);
            return Plugin_Stop;
        }

        if (g_bTitle[client])
        {
            strcopy(g_sTitle[client], sizeof(g_sTitle[]), message);

            PrintToChat(client, "Title: %s", message);
        }
        else if (g_bLength[client])
        {
            if (IsNumericString(message))
            {
                int iLength = StringToInt(message);

                if (iLength >= g_cMinLength.IntValue)
                {
                    g_iLength[client] = iLength;
                    PrintToChat(client, "Length: %d", iLength);
                }
                else
                {
                    CPrintToChat(client, "{darkred}[MVotes] {default} Invalid length!");
                }
            }
            else
            {
                CPrintToChat(client, "{darkred}[MVotes] {default}Length isn't numeric!");
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
                    if (strlen(sOptions[i]) < 2)
                    {
                        continue;
                    }

                    g_aCOptions[client].PushString(sOptions[i]);

                    if (g_cDebug.BoolValue)
                    {
                        LogMessage("[MVotes.OnClientSayCommand] Added option %d: %s", i+1, sOptions[i]);
                        PrintToBaraConsole("[MVotes.OnClientSayCommand] Added option %d: %s", i+1, sOptions[i]);
                    }
                }
            }
            else
            {
                CPrintToChat(client, "{darkred}[MVotes] {default}We need more options!");
            }
        }

        g_bTitle[client] = false;
        g_bLength[client] = false;
        g_bOptions[client] = false;

        ShowCreateMenu(client);

        return Plugin_Stop;
    }

    return Plugin_Continue;
}

bool CheckClientStatus(int client)
{
    return (g_bTitle[client] || g_bLength[client] || g_bOptions[client]);
}

void ResetCreateVote(int client, bool message = false)
{
    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ResetCreateVote] 1");
        PrintToBaraConsole("[MVotes.ResetCreateVote] 1");
    }

    g_bTitle[client] = false;
    g_bLength[client] = false;
    g_bOptions[client] = false;

    Format(g_sTitle[client], sizeof(g_sTitle[]), "");
    g_iLength[client] = -1;

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ResetCreateVote] 2");
        PrintToBaraConsole("[MVotes.ResetCreateVote] 2");
    }

    delete g_aCOptions[client];

    if (g_cDebug.BoolValue)
    {
        LogMessage("[MVotes.ResetCreateVote] g_aCOptions: %d", g_aCOptions[client]);
        PrintToBaraConsole("[MVotes.ResetCreateVote] g_aCOptions: %d", g_aCOptions[client]);
    }

    if (message && IsClientValid(client))
    {
        if (g_cDebug.BoolValue)
        {
            LogMessage("[MVotes.ResetCreateVote] 3");
            PrintToBaraConsole("[MVotes.ResetCreateVote] 3");
        }

        CPrintToChat(client, "{darkred}[MVotes] {default}Create vote settings resettet!");
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

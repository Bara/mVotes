public int Native_CreatePoll(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sTitle[64];
    GetNativeString(2, sTitle, sizeof(sTitle));
    
    int iLength = GetNativeCell(3);

    ArrayList aOptions = view_as<ArrayList>(CloneHandle(GetNativeCell(4)));

    int iVotes = GetNativeCell(5);

    return CreatePoll(client, sTitle, iLength, aOptions, iVotes);
}

public int Native_ClosePoll(Handle plugin, int numParams)
{
    int poll = GetNativeCell(1);

    bool bFound = false;

    LoopPollsArray(i)
    {
        int iPolls[ePolls];
        g_aPolls.GetArray(i, iPolls[0]);

        if (iPolls[pExpire] <= GetTime())
        {
            ClosePoll(iPolls[pID]);
            continue;
        }

        if (iPolls[pID] == poll)
        {
            bFound = true;
            break;
        }
    }

    if (bFound)
    {
        ClosePoll(poll);
    }
}

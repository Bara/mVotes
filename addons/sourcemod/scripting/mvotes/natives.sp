public int Native_CreatePoll(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char sTitle[64];
    GetNativeString(2, sTitle, sizeof(sTitle));

    int iLength = GetNativeCell(3);

    ArrayList aOptions = view_as<ArrayList>(CloneHandle(GetNativeCell(4)));

    int iVotes = GetNativeCell(5);

    ArrayList aKeywords = null;

    if (view_as<Handle>(GetNativeCell(6)) != null)
    {
        aKeywords = view_as<ArrayList>(CloneHandle(GetNativeCell(6)));
    }

    return CreatePoll(client, sTitle, iLength, aOptions, iVotes, aKeywords);
}

public int Native_ClosePoll(Handle plugin, int numParams)
{
    int pollid = GetNativeCell(1);

    bool bFound = false;

    LoopPollsArray(i)
    {
        Poll poll;
        g_aPolls.GetArray(i, poll);

        if (poll.Expire <= GetTime())
        {
            ClosePoll(poll.ID);
            continue;
        }

        if (poll.ID == pollid)
        {
            bFound = true;
            break;
        }
    }

    if (bFound)
    {
        ClosePoll(pollid);
    }
}

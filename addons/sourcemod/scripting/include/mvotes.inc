#if defined _mvotes_included
 #endinput
#endif
#define _mvotes_included


/*
 * Return: -1 - Looks good, 0 - Invalid time/expire time, 1 - Invalid poll length (See mvotes_min_length), 2 - Invalid options (See mvotes_min_options), 3 - Invalid votes (More or equal votes per player as options given)
 *
 */
native int MVotes_CreatePoll(int client = -1, const char[] title, int length, ArrayList options, int votes, ArrayList keywords);
native bool MVovtes_ExtendPoll(int client = -1, int pollID, int length);
native void MVotes_ClosePoll(int pollID);

public SharedPlugin __pl_mvotes =
{
    name = "mvotes",
    file = "mvotes.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_mvotes_SetNTVOptional()
{
    MarkNativeAsOptional("MVotes_CreatePoll");
    MarkNativeAsOptional("MVotes_ExtendPoll");
    MarkNativeAsOptional("MVotes_ClosePoll");
}
#endif

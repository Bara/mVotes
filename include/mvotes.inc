#if defined _mvotes_included
 #endinput
#endif
#define _mvotes_included


/*
 * Return: -1 - Looks good, 0 - Invalid time/expire time, 1 - Invalid poll length (See mvotes_min_length), 2 - Invalid options (See mvotes_min_options)
 *
 */
native int MVotes_CreatePoll(int client = -1, const char[] title, int length, ArrayList options);

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
}
#endif

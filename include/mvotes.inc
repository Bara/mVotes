#if defined _mvotes_included
 #endinput
#endif
#define _mvotes_included


/*
 * Example to create a poll: https://github.com/Bara/mVotes/blob/7755f526567a4501e221bc984b900d010ff0696f/mvotes.sp#L47
 * Return: -1 - Looks good, 0 - Invalid time/expire time, 1 - Invalid poll length (See mvotes_min_length), 2 - Invalid options (See mvotes_min_options)
 *
 */
native void MVotes_CreatePoll(int client = -1, const char[] title, int length, ArrayList options);

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

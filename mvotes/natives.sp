public int Native_CreatePoll(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
    char sTitle[64];
    GetNativeString(2, sTitle, sizeof(sTitle));
    int iLength = GetNativeCell(3);
    ArrayList aOptions = GetNativeCell(4);
	
	return CreatePoll(client, sTitle, iLength, aOptions);
}
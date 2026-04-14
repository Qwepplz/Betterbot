public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int clientIndex = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(clientIndex))
	{
		GivePlayerGloves(clientIndex);
	}
}

public Action ChatListener(int client, const char[] command, int args)
{
	char msg[128];
	GetCmdArgString(msg, sizeof(msg));
	StripQuotes(msg);
	if (StrEqual(msg, "!gloves") || StrEqual(msg, "!glove") || StrEqual(msg, "!eldiven") || StrContains(msg, "!gllang") == 0)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

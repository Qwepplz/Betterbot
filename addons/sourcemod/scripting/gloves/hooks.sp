public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int clientIndex = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(clientIndex))
	{
		CreateTimer(0.1, GivePlayerGlovesTimer, GetClientUserId(clientIndex), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action GivePlayerGlovesTimer(Handle timer, int userid)
{
	int clientIndex = GetClientOfUserId(userid);
	if (IsValidClient(clientIndex) && IsPlayerAlive(clientIndex))
	{
		GivePlayerGloves(clientIndex);
	}
	return Plugin_Stop;
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

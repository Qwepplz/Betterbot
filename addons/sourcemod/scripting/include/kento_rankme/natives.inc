public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Get5_GetGameState");
	CreateNative("RankMe_GivePoint", Native_GivePoint);
	CreateNative("RankMe_GetRank", Native_GetRank);
	CreateNative("RankMe_GetPoints", Native_GetPoints);
	CreateNative("RankMe_GetStats", Native_GetStats);
	CreateNative("RankMe_GetSession", Native_GetSession);
	CreateNative("RankMe_GetWeaponStats", Native_GetWeaponStats);
	CreateNative("RankMe_GetHitbox", Native_GetHitbox);
	CreateNative("RankMe_IsPlayerLoaded", Native_IsPlayerLoaded);
	
	RegPluginLibrary("rankme");
	
	return APLRes_Success;
}
public int Native_GivePoint(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int iPoints = GetNativeCell(2);
	
	int len;
	GetNativeStringLength(3, len);
	
	if (len <= 0)
	{
		return 0;
	}
	
	
	char[] Reason = new char[len + 1];
	char Name[MAX_NAME_LENGTH];
	GetNativeString(3, Reason, len + 1);
	int iPrintToPlayer = GetNativeCell(4);
	int iPrintToAll = GetNativeCell(5);
	g_aStats[client].SCORE += iPoints;
	g_aSession[client].SCORE += iPoints;
	GetClientName(client, Name, sizeof(Name));
	if (!g_bChatChange)
		return 0;
	if (iPrintToAll == 1) {
		for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			//CPrintToChatEx(i,i,"%s %T",MSG,"GotPointsBy",Name,g_aStats[client].SCORE,iPoints,Reason);
		if(!hidechat[i]) CPrintToChat(i, "%s %T", MSG, "GotPointsBy", i, Name, g_aStats[client].SCORE, iPoints, Reason);
	} else if (iPrintToPlayer == 1) {
		//CPrintToChatEx(client,client,"%s %T",MSG,"GotPointsBy",Name,g_aStats[client].SCORE,iPoints,Reason);
		if(!hidechat[client]) CPrintToChat(client, "%s %T", MSG, "GotPointsBy", client, Name, g_aStats[client].SCORE, iPoints, Reason);
	}

	return 0;
}

public int Native_GetRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	Function callback = GetNativeCell(2);
	any data = GetNativeCell(3);
	
	Handle pack = CreateDataPack();
	
	WritePackCell(pack, client);
	WritePackFunction(pack, callback);
	WritePackCell(pack, data);
	WritePackCell(pack, view_as<int>(plugin));
	
	if(g_bRankCache)
	{
		GetClientRank(pack);
		return 0;
	}

	char query[10000];
	MakeSelectQuery(query, sizeof(query));
	
	if (g_RankMode == 1)
		Format(query, sizeof(query), "%s ORDER BY score DESC", query);
	else if (g_RankMode == 2)
		Format(query, sizeof(query), "%s ORDER BY CAST(CAST(kills as float)/CAST (deaths as float) as float) DESC", query);
	
	SQL_TQuery(g_hStatsDb, SQL_GetRankCallback, query, pack);

	return 0;
}

void GetClientRank(Handle pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	Function callback = ReadPackFunction(pack);
	any args = ReadPackCell(pack);
	Handle plugin = ReadPackCell(pack);
	CloseHandle(pack);
	
	int rank;
	int identityMode = GetRankMeIdentityMode(client);
	switch(identityMode)
	{
		case 0:
		{
			rank = FindStringInArray(g_arrayRankCache[0], g_aClientSteam[client]);
		}
		case 1:
		{
			rank = FindStringInArray(g_arrayRankCache[1], g_aClientName[client]);
		}
		case 2:
		{
			rank = FindStringInArray(g_arrayRankCache[2], g_aClientIp[client]);
		}
	}

	if(rank > 0)
		CallRankCallback(client, rank, callback, args, plugin);
	else
		CallRankCallback(client, 0, callback, args, plugin);
}

public void SQL_GetRankCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	Handle pack = data;
	ResetPack(pack);
	int client = ReadPackCell(pack);
	Function callback = ReadPackFunction(pack);
	any args = ReadPackCell(pack);
	Handle plugin = ReadPackCell(pack);
	CloseHandle(pack);
	
	if (hndl == INVALID_HANDLE)
	{
		LogError("[RankMe] Query Fail: %s", error);
		CallRankCallback(0, 0, callback, 0, plugin);
		return;
	}
	int i;
	g_TotalPlayers = SQL_GetRowCount(hndl);
	
	char Receive[64];
	int identityMode = GetRankMeIdentityMode(client);
	
	while (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		i++;
		
		if (identityMode == 0) {
			SQL_FetchString(hndl, 1, Receive, sizeof(Receive));
			if (StrEqual(Receive, g_aClientSteam[client], false))
			{
				CallRankCallback(client, i, callback, args, plugin);
				break;
			}
		} else if (identityMode == 1) {
			SQL_FetchString(hndl, 2, Receive, sizeof(Receive));
			if (StrEqual(Receive, g_aClientName[client], false))
			{
				CallRankCallback(client, i, callback, args, plugin);
				break;
			}
		} else if (identityMode == 2) {
			SQL_FetchString(hndl, 3, Receive, sizeof(Receive));
			if (StrEqual(Receive, g_aClientIp[client], false))
			{
				CallRankCallback(client, i, callback, args, plugin);
				break;
			}
		}
	}
}

void CallRankCallback(int client, int rank, Function callback, any data, Handle plugin)
{
	Call_StartFunction(plugin, callback);
	Call_PushCell(client);
	Call_PushCell(rank);
	Call_PushCell(data);
	Call_Finish();
	CloseHandle(plugin);
}

public int Native_GetPoints(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_aStats[client].SCORE;
}

public int Native_GetStats(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int array[35];
	g_aStats[client].GetData(array);
	SetNativeArray(2, array, 35);

	return 0;
}

public int Native_GetSession(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int array[35];
	g_aSession[client].GetData(array);
	SetNativeArray(2, array, 35);

	return 0;
}

public int Native_GetWeaponStats(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int array[42];
	g_aWeapons[client].GetData(array);
	SetNativeArray(2, array, 42);

	return 0;
}

public int Native_GetHitbox(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int array[8];
	g_aHitBox[client].GetData(array);
	SetNativeArray(2, array, 8);

	return 0;
}

public int Native_IsPlayerLoaded(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return OnDB[client];
}
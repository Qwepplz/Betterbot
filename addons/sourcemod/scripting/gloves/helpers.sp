enum Get5State {
	Get5State_None,
	Get5State_PreVeto,
	Get5State_Veto,
	Get5State_Warmup,
	Get5State_KnifeRound,
	Get5State_WaitingForKnifeRoundDecision,
	Get5State_GoingLive,
	Get5State_Live,
	Get5State_PendingRestore,
	Get5State_PostGame,
};

native Get5State Get5_GetGameState();

stock bool IsGet5CosmeticUnsafePhase()
{
	if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") != FeatureStatus_Available)
	{
		return false;
	}

	Get5State state = Get5_GetGameState();
	return state == Get5State_KnifeRound;
}

stock bool IsGet5ImmediateCosmeticBlockedPhase()
{
	if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") != FeatureStatus_Available)
	{
		return false;
	}

	Get5State state = Get5_GetGameState();
	return state == Get5State_KnifeRound;
}

stock void GetRandomSkin(int client, int team, char[] output, int outputSize, int group = -1)
{
	int max;
	int random;
	if (group != -1)
	{
		char groupStr[10];
		IntToString(group, groupStr, sizeof(groupStr));
		g_smGlovesGroupIndex.GetValue(groupStr, random);
	}
	else
	{
		max = menuGlovesGroup[g_iClientLanguage[client]][team].ItemCount - 1;
		random = GetRandomInt(2, max) - 1;
	}

	max = menuGloves[g_iClientLanguage[client]][team][random].ItemCount - 1;
	int random2 = GetRandomInt(1, max);
	menuGloves[g_iClientLanguage[client]][team][random].GetItem(random2, output, outputSize);
}

stock bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}
	return true;
}

stock int GetClientGloveTeam(int client)
{
	return GetClientTeam(client);
}

stock bool IsClientsCurrentGloveTeam(int client, int team)
{
	return team == GetClientGloveTeam(client);
}

stock void GetGloveTeamPrefix(int team, char[] prefix, int maxlen)
{
	strcopy(prefix, maxlen, team == CS_TEAM_T ? "t" : "ct");
}

stock void FirstCharUpper(char[] string)
{
	if (strlen(string) > 0)
	{
		string[0] = CharToUpper(string[0]);
	}
}

stock void FixCustomArms(int client)
{
	char temp[2];
	GetEntPropString(client, Prop_Send, "m_szArmsModel", temp, sizeof(temp));
	if (temp[0])
	{
		SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
	}
}

stock bool HasConfiguredGlovesForCurrentTeam(int client)
{
	int playerTeam = GetClientGloveTeam(client);
	return playerTeam >= CS_TEAM_T && playerTeam <= CS_TEAM_CT && g_iGloves[client][playerTeam] != 0;
}

stock bool IsCurrentGloveStateApplied(int client, int team)
{
	if (g_iGloves[client][team] <= 0)
	{
		return false;
	}

	int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
	if (ent <= MaxClients || !IsValidEntity(ent))
	{
		return false;
	}

	if (GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex") != g_iGroup[client][team]
		|| GetEntProp(ent, Prop_Send, "m_nFallbackPaintKit") != g_iGloves[client][team])
	{
		return false;
	}

	float currentWear = GetEntPropFloat(ent, Prop_Send, "m_flFallbackWear");
	float targetWear = g_fFloatValue[client][team];
	if (currentWear < targetWear - 0.00001 || currentWear > targetWear + 0.00001)
	{
		return false;
	}

	if (GetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity") != client || GetEntPropEnt(ent, Prop_Data, "m_hParent") != client)
	{
		return false;
	}

	if (g_iEnableWorldModel && GetEntPropEnt(ent, Prop_Data, "m_hMoveParent") != client)
	{
		return false;
	}

	return true;
}

stock void ClearPlayerWearables(int client)
{
	int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
	if (ent != -1)
	{
		AcceptEntityInput(ent, "KillHierarchy");
	}
}

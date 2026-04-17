stock int CalculateEloScoreDifference(int attacker, int victim, bool headshot = false, bool flashed = false, bool throughSmoke = false, bool wallbang = false, bool firstBloodKill = false, bool noScope = false, bool knife = false, bool taser = false)
{
	if (attacker < 1 || attacker > MaxClients || victim < 1 || victim > MaxClients)
		return 0;
	if (!IsClientInGame(attacker) || !IsClientInGame(victim))
		return 0;

	int attackerElo = g_iPlayerElo[attacker] > 0 ? g_iPlayerElo[attacker] : g_aStats[attacker].SCORE;
	int victimElo = g_iPlayerElo[victim] > 0 ? g_iPlayerElo[victim] : g_aStats[victim].SCORE;
	float expected = 1.0 / (1.0 + Pow(10.0, float(victimElo - attackerElo) / 400.0));
	int scoreDiff = RoundToFloor(float(GetDynamicKFactor(attackerElo)) * (1.0 - expected));

	scoreDiff = RoundToFloor(float(scoreDiff) * GetPerformanceMultiplier(attacker));
	if (headshot)
		scoreDiff += 1;
	if (flashed || throughSmoke || wallbang || firstBloodKill || noScope)
		scoreDiff += 1;
	if (knife || taser)
		scoreDiff = RoundToCeil(float(scoreDiff) * (knife ? g_fPointsKnifeMultiplier : g_fPointsTaserMultiplier));
	if (scoreDiff < 1)
		scoreDiff = 1;

	return ValidateEloChange(attacker, scoreDiff);
}

int CalculateScoreDifference(int attacker, int victim, int team)
{
	if (attacker < MAXPLAYERS)
	{
		if (g_bUseEloSystem)
		{
			int attackerScore = g_aStats[attacker].SCORE;
			int victimScore = g_aStats[victim].SCORE;
			float expected = 1.0 / (1.0 + Pow(10.0, float(victimScore - attackerScore) / 400.0));
			int scoreDiff = RoundToFloor(float(GetDynamicKFactor(attackerScore)) * (1.0 - expected));
			scoreDiff = RoundToFloor(float(scoreDiff) * GetPerformanceMultiplier(attacker));
			return scoreDiff < 1 ? 1 : ValidateEloChange(attacker, scoreDiff);
		}

		int scoreDiff = g_aStats[victim].SCORE - g_aStats[attacker].SCORE;
		if (scoreDiff < 0)
			return g_PointsKill[team];
		if (g_PointsKillBonusDif[team] == 0)
			return g_PointsKill[team] + (g_PointsKillBonus[team] * scoreDiff);
		return g_PointsKill[team] + ((g_PointsKillBonus[team] * scoreDiff) / g_PointsKillBonusDif[team]);
	}

	return g_PointsKill[team];
}

void ApplyWeaponMultipliers(const char[] weapon, int &scoreDiff)
{
	if (StrEqual(weapon, "knife", true))
		scoreDiff = RoundToCeil(g_fPointsKnifeMultiplier * scoreDiff);
	else if (StrEqual(weapon, "taser", true))
		scoreDiff = RoundToCeil(g_fPointsTaserMultiplier * scoreDiff);
}

int GetDynamicKFactor(int score)
{
	if (score < 1600)
		return g_iEloKLow;
	if (score < 2200)
		return g_iEloKMidLow;
	if (score < 3000)
		return g_iEloKMid;
	if (score < 3800)
		return g_iEloKHigh;
	return g_iEloKPro;
}

float GetPerformanceMultiplier(int client)
{
	if (client < 1 || client > MaxClients)
		return 1.0;

	float multiplier = 1.0;
	if (g_aKillStreak[client] >= 5)
		multiplier = 1.5;
	else if (g_aKillStreak[client] >= 3)
		multiplier = 1.2;

	if (g_aRevengeCount[client] > 0)
		multiplier += 0.05;
	return multiplier;
}

int CalculateScoreLoss(int client, int scoreDiff)
{
	if (client >= MAXPLAYERS)
		return scoreDiff;

	if (g_bUseEloSystem)
	{
		int score = g_aStats[client].SCORE;
		if (score < 1600)
			return RoundToFloor(float(scoreDiff) * 0.7);
		if (score < 2200)
			return RoundToFloor(float(scoreDiff) * 0.85);
	}

	return scoreDiff;
}

stock float GetConsistencyReward(int client)
{
	if (client >= MAXPLAYERS)
		return 0.0;
	float multiplier = GetPerformanceMultiplier(client);
	if (multiplier >= 1.5)
		return 0.05;
	if (multiplier >= 1.2)
		return 0.02;
	return 0.0;
}

int ValidateEloChange(int client, int change)
{
	if (client >= MAXPLAYERS)
		return change;

	int score = g_iPlayerElo[client] > 0 ? g_iPlayerElo[client] : g_aStats[client].SCORE;
	int maxChange = GetMaxSingleGameChange(score);
	if (change > maxChange)
		return maxChange;
	if (change < -maxChange)
		return -maxChange;
	if (change + score < 1)
		return 1 - score;
	return change;
}
int GetMaxSingleGameChange(int score)
{
	if (score < 1600)
		return 75;
	if (score < 2200)
		return 50;
	if (score < 3000)
		return 35;
	return 20;
}

void InitializeEloOptimization()
{
	LogMessage("ELO Optimization Module Initialized");
	LogMessage("Dynamic K-Factor ranges: Low(%d), Mid-Low(%d), Mid(%d), High(%d), Pro(%d)", g_iEloKLow, g_iEloKMidLow, g_iEloKMid, g_iEloKHigh, g_iEloKPro);
}

void InitializePlayerEloOptimization(int client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && g_bEloDebugLog)
		LogMessage("[ELO] Player Init: %s (%d) ELO optimization initialized", g_aClientName[client], client);
}
void CleanupPlayerEloOptimization(int client)
{
	if (client > 0 && client <= MaxClients && g_bEloDebugLog)
		LogMessage("[ELO] Player Cleanup: %d ELO optimization cleaned up", client);
}

void AddEloBonus(int client, int bonus)
{
	if (client < 1 || client > MaxClients || bonus == 0)
		return;

	g_iPlayerElo[client] += bonus;
	g_aStats[client].SCORE += bonus;
	g_aSession[client].SCORE += bonus;
}

void UpdateKillRecords(int attacker, int victim)
{
	int now = GetTime();
	g_aLastKilledBy[victim] = attacker;
	g_aLastKilledTime[victim] = now;
	g_aKillStreak[victim] = 0;
	g_aLastKillTime[victim] = 0;

	if (g_aLastKillTime[attacker] != 0 && now - g_aLastKillTime[attacker] <= KILL_STREAK_WINDOW)
		g_aKillStreak[attacker]++;
	else
		g_aKillStreak[attacker] = 1;

	g_aLastKillTime[attacker] = now;
	if (g_aKillStreak[attacker] > g_aMaxKillStreak[attacker])
		g_aMaxKillStreak[attacker] = g_aKillStreak[attacker];
}

void ProcessRevengeAndStreakBonuses(int attacker, int victim)
{
	if (attacker > MaxClients || attacker < 1 || victim < 1 || victim > MaxClients || !g_bUseEloSystem)
		return;

	int now = GetTime();
	if (g_aLastKilledBy[attacker] == victim && g_aLastKilledTime[attacker] != 0 && now - g_aLastKilledTime[attacker] <= REVENGE_WINDOW)
	{
		g_aRevengeCount[attacker]++;
		AddEloBonus(attacker, 2);
		g_aLastKilledBy[attacker] = 0;
		g_aLastKilledTime[attacker] = 0;
		if (g_bAnnounceRevengeGlobal && IsClientInGame(attacker) && IsClientInGame(victim))
			CPrintToChatAll("%s %t", MSG, "RevengeGlobal", g_aClientName[attacker], g_aStats[attacker].SCORE, g_aClientName[attacker], g_aClientName[victim], 2);
	}

	int bonus = 0;
	char streakPhrase[32];
	streakPhrase[0] = '\0';
	if (g_aKillStreak[attacker] == 2)
	{
		bonus = 1;
		strcopy(streakPhrase, sizeof(streakPhrase), "DoubleKill");
	}
	else if (g_aKillStreak[attacker] == 3)
	{
		bonus = 2;
		strcopy(streakPhrase, sizeof(streakPhrase), "TripleKill");
	}
	else if (g_aKillStreak[attacker] == 4)
	{
		bonus = 3;
		strcopy(streakPhrase, sizeof(streakPhrase), "MegaKill");
	}
	else if (g_aKillStreak[attacker] == 5)
	{
		bonus = 4;
		strcopy(streakPhrase, sizeof(streakPhrase), "UltraKill");
	}
	if (bonus > 0)
	{
		AddEloBonus(attacker, bonus);
		if (g_bAnnounceKillStreakGlobal && IsClientInGame(attacker))
		{
			char streakName[64];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i))
					continue;

				Format(streakName, sizeof(streakName), "%T", streakPhrase, i);
				CPrintToChat(i, "%s %t", MSG, "KillStreakGlobal", g_aClientName[attacker], g_aStats[attacker].SCORE, streakName, bonus);
			}
		}
	}
}

stock void UpdateBasicKillStats(int attacker, int victim, const char[] weapon, int scoreDiff)
{
	g_aStats[victim].DEATHS++;
	g_aSession[victim].DEATHS++;
	if (attacker < MAXPLAYERS)
	{
		g_aStats[attacker].KILLS++;
		g_aSession[attacker].KILLS++;
		g_aStats[attacker].SCORE += scoreDiff;
		g_aSession[attacker].SCORE += scoreDiff;
		char weaponName[64];
		strcopy(weaponName, sizeof(weaponName), weapon);
		int weaponNum = GetWeaponNum(weaponName);
		if (weaponNum < 42)
			g_aWeapons[attacker].AddKill(weaponNum);
		UpdateKillRecords(attacker, victim);
	}

	if (!g_bUseEloSystem)
	{
		int loss = g_bPointsLoseRoundCeil ? RoundToCeil(scoreDiff * g_fPercentPointsLose) : RoundToFloor(scoreDiff * g_fPercentPointsLose);
		g_aStats[victim].SCORE -= loss;
		if (g_bPointsMinEnabled && g_aStats[victim].SCORE < g_PointsMin)
		{
			int diff = g_PointsMin - g_aStats[victim].SCORE;
			g_aStats[victim].SCORE = g_PointsMin;
			g_aSession[victim].SCORE -= diff;
		}
		else
		{
			g_aSession[victim].SCORE -= loss;
		}
	}
}

stock void ProcessEloOptimizationKill(int attacker, int victim, const char[] weapon, bool headshot, bool flashed, bool throughSmoke, bool wallbang, bool firstBloodKill, bool noScope)
{
	if (!g_bUseEloSystem || attacker < 1 || attacker > MaxClients || victim < 1 || victim > MaxClients)
		return;

	bool knife = StrEqual(weapon, "knife", true);
	bool taser = StrEqual(weapon, "taser", true);
	int eloChange = CalculateEloScoreDifference(attacker, victim, headshot, flashed, throughSmoke, wallbang, firstBloodKill, noScope, knife, taser);
	UpdateBasicKillStats(attacker, victim, weapon, eloChange);
	ProcessRevengeAndStreakBonuses(attacker, victim);
}

void InitializeErrorHandling()
{
	g_bErrorHandlingEnabled = true;
	g_iErrorCount = 0;
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "logs/rankme_errors.log");
	g_hErrorLog = OpenFile(path, "a");
	if (g_hErrorLog == INVALID_HANDLE)
	{
		LogError("[RankMe] Failed to open error log file: %s", path);
		g_bErrorHandlingEnabled = false;
		return;
	}
	LogMessage("[RankMe] Error log opened: %s", path);
}

void LogErrorWithRecovery(const char[] error, const char[] context)
{
	if (!g_bErrorHandlingEnabled)
		return;
	g_iErrorCount++;
	if (g_hErrorLog != INVALID_HANDLE)
	{
		char timestamp[64];
		FormatTime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", -1);
		WriteFileLine(g_hErrorLog, "[%s] [%s] #%d %s", timestamp, context, g_iErrorCount, error);
		FlushFile(g_hErrorLog);
	}

	LogError("[RankMe][%s][%d] %s", context, g_iErrorCount, error);
	if (g_iErrorCount >= g_iMaxErrors)
	{
		LogError("[RankMe] Error recovery disabled after reaching the maximum error count (%d)", g_iMaxErrors);
		g_bErrorHandlingEnabled = false;
	}
}

void HandleDatabaseError(const char[] error, const char[] query)
{
	LogErrorWithRecovery(error, "Database");
	if (query[0] != '\0')
		LogErrorWithRecovery(query, "Database Query");
	if (g_hStatsDb != INVALID_HANDLE)
	{
		CloseHandle(g_hStatsDb);
		g_hStatsDb = INVALID_HANDLE;
	}
	CreateTimer(5.0, Timer_ReconnectDatabase);
}

stock bool ValidateDatabaseConnection()
{
	if (g_hStatsDb == INVALID_HANDLE)
	{
		LogErrorWithRecovery("Database connection is null", "Database");
		return false;
	}
	SQL_TQuery(g_hStatsDb, SQL_NothingCallback, "SELECT 1", _, DBPrio_Low);
	return true;
}

void ValidateStartupConfiguration()
{
	LogMessage("Validating RankMe configuration...");
	bool valid = true;
	if (g_MinimumPlayers < 0)
	{
		LogError("Invalid minimum players setting: %d", g_MinimumPlayers);
		g_MinimumPlayers = 0;
		valid = false;
	}
	if (g_DaysToNotShowOnRank < 0)
	{
		LogError("Invalid days to not show on rank setting: %d", g_DaysToNotShowOnRank);
		g_DaysToNotShowOnRank = 0;
		valid = false;
	}
	if (g_bDebugLog)
		LogMessage("[RankMe] Debug logging enabled.");
	if (valid)
		LogMessage("Configuration validation passed.");
	else
	{
		LogError("Configuration validation failed during startup. Some settings have been reset to defaults.");
		LogError("Please check your configuration file and restart the plugin.");
	}
}

public Action Timer_ReconnectDatabase(Handle timer)
{
	if (g_hStatsDb == INVALID_HANDLE)
	{
		DB_Connect(true);
		if (g_hStatsDb != INVALID_HANDLE)
			LogMessage("[RankMe] Database reconnected successfully.");
		else
			LogError("[RankMe] Failed to reconnect database.");
	}
	return Plugin_Stop;
}

public Action Timer_ReloadBotName(Handle timer, any client)
{
	if (IsClientInGame(client) && IsFakeClient(client) && g_hStatsDb != INVALID_HANDLE)
		LoadPlayer(client);
	return Plugin_Stop;
}

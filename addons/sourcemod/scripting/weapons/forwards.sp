/*  CS:GO Weapons&Knives SourceMod Plugin
 *
 *  Recovered from SMX and BoneTM/weapons source.
 */

public void OnConfigsExecuted() {
  GetConVarString(g_Cvar_DBConnection, g_DBConnection, sizeof(g_DBConnection));
  GetConVarString(g_Cvar_TablePrefix, g_TablePrefix, sizeof(g_TablePrefix));
  g_iGraceInactiveDays = g_Cvar_InactiveDays.IntValue;

  if (g_DBConnectionOld[0] != EOS && strcmp(g_DBConnectionOld, g_DBConnection) != 0 && db != null) {
    delete db;
    db = null;
  }

  if (db == null) {
    g_iDatabaseState = 0;
    Database.Connect(SQLConnectCallback, g_DBConnection);
  } else {
    DeleteInactivePlayerData();
  }

  strcopy(g_DBConnectionOld, sizeof(g_DBConnectionOld), g_DBConnection);
  InitializeConVars();

  if (g_iGracePeriod > 0) {
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
  }
  HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);
  HookEvent("player_team", OnPlayerTeam, EventHookMode_PostNoCopy);
  HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
  HookEvent("player_hurt", OnPlayerHurt, EventHookMode_PostNoCopy);
  CreateTimer(1.0, CheckBotControlStatusTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      OnClientPutInServer(i);
    }
  }

  ReadConfig();
}

public void OnClientPutInServer(int client) {
  if (IsFakeClient(client)) {
    if (g_bEnableStatTrak)
      SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
  } else if (IsValidClient(client)) {
    g_iIndex[client] = 0;
    g_FloatTimer[client] = INVALID_HANDLE;
    g_bWaitingForNametag[client] = false;
    g_bWaitingForSeed[client] = false;
    g_bWaitingForWear[client] = false;
    g_bWasControllingBot[client] = false;
    for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
      g_iSeedRandom[client][i] = 0;
    }
    HookPlayer(client);
  }
}

public void OnClientPostAdminCheck(int client) {
  if (!IsValidClient(client)) {
    return;
  }

  char steam32[20];
  char temp[20];
  if (GetClientAuthId(client, AuthId_Steam3, steam32, sizeof(steam32))) {
    strcopy(temp, sizeof(temp), steam32[5]);
    int index;
    if ((index = StrContains(temp, "]")) > -1) {
      temp[index] = '\0';
    }
    g_iSteam32[client] = StringToInt(temp);
  }

  QueryClientConVar(client, "cl_language", ConVarCallBack);
  if (IsDatabaseReady()) {
    GetPlayerData(client);
  } else {
    CreateTimer(2.0, LoadPlayerDataTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action LoadPlayerDataTimer(Handle timer, int userid) {
  int client = GetClientOfUserId(userid);
  if (IsValidClient(client) && IsDatabaseReady()) {
    GetPlayerData(client);
  }
  return Plugin_Stop;
}

public void ConVarCallBack(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName,
                    const char[] cvarValue) {
  if (!g_smLanguageIndex.GetValue(cvarValue, g_iClientLanguage[client])) {
    g_iClientLanguage[client] = 0;
  }
}

public void OnClientDisconnect(int client) {
  if (IsFakeClient(client)) {
    if (g_bEnableStatTrak)
      SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
  } else {
    if (g_FloatTimer[client] != INVALID_HANDLE) {
      KillTimer(g_FloatTimer[client]);
      g_FloatTimer[client] = INVALID_HANDLE;
    }
    if (IsClientInGame(client)) {
      UnhookPlayer(client);
    }
    g_iSteam32[client] = 0;
    g_bWasControllingBot[client] = false;
  }
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClientIndex(client) && IsClientInGame(client)) {
    CreateTimer(0.2, CheckAndGiveKnifeTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
  }
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsValidClient(client)) {
    CreateTimer(0.3, OnTeamChangeTimer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
  }
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
}

public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast) {
}

public Action OnTeamChangeTimer(Handle timer, int userid) {
  int client = GetClientOfUserId(userid);
  if (IsValidClient(client) && IsPlayerAlive(client)) {
    RefreshWeapon(client, -1, true);
  }
  return Plugin_Stop;
}

public Action CheckAndGiveKnifeTimer(Handle timer, int userid) {
  int client = GetClientOfUserId(userid);
  if (IsValidClientIndex(client) && IsClientInGame(client) && IsPlayerAlive(client) && !HasKnife(client)) {
    GivePlayerItem(client, "weapon_knife");
  }
  return Plugin_Stop;
}

public void CheckBotControlStatus() {
  for (int client = 1; client <= MaxClients; client++) {
    if (IsValidClient(client)) {
      bool controlling = IsPlayerControllingBot(client);
      if (g_bWasControllingBot[client] != controlling) {
        g_bWasControllingBot[client] = controlling;
        if (controlling) {
          int bot = GetControlledBot(client);
          if (bot > 0 && IsPlayerAlive(bot)) {
            CreateTimer(0.2, CheckAndGiveKnifeTimer, GetClientUserId(bot), TIMER_FLAG_NO_MAPCHANGE);
          }
        }
      }
    }
  }
}

public Action CheckBotControlStatusTimer(Handle timer) {
  CheckBotControlStatus();
  return Plugin_Continue;
}

public void OnPluginEnd() {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      OnClientDisconnect(i);
    }
  }

  if (db != null) {
    delete db;
    db = null;
  }
}

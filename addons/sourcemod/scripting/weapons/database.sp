/*  CS:GO Weapons&Knives SourceMod Plugin
 *
 *  Recovered dynamic database layer from SMX and BoneTM/weapons source.
 */

stock void ConnectDatabase() {
  GetConVarString(g_Cvar_DBConnection, g_DBConnection, sizeof(g_DBConnection));
  if (g_DBConnectionOld[0] != EOS && strcmp(g_DBConnectionOld, g_DBConnection, false) != 0 && db != null) {
    delete db;
    db = null;
  }

  if (db == null) {
    g_iDatabaseState = 0;
    LogMessageConditional("Trying to connect weapons database: %s", g_DBConnection);
    Database.Connect(SQLConnectCallback, g_DBConnection);
  } else {
    DeleteInactivePlayerData();
  }
  strcopy(g_DBConnectionOld, sizeof(g_DBConnectionOld), g_DBConnection);
}

public void SQLConnectCallback(Database database, const char[] error, any data) {
  if (database == null) {
    g_iDatabaseState = 0;
    LogError("Weapons database connection failed: %s", error);
    return;
  }

  db = database;
  g_iDatabaseState = 1;

  char identifier[16];
  db.Driver.GetIdentifier(identifier, sizeof(identifier));
  bool mysql = StrEqual(identifier, "mysql", false);
  EnsureDatabaseSchema(mysql);
}

void EnsureDatabaseSchema(bool mysql) {
  CreateBaseTables(mysql);
}

void CreateBaseTables(bool mysql) {
  char query[512];
  if (mysql) {
    Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %sweapons (`steamid` varchar(32) NOT NULL PRIMARY KEY, `knife` int(4) NOT NULL DEFAULT '0', `knife_ct` int(4) NOT NULL DEFAULT '0') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", g_TablePrefix);
  } else {
    Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %sweapons (`steamid` TEXT NOT NULL PRIMARY KEY, `knife` INTEGER NOT NULL DEFAULT '0', `knife_ct` INTEGER NOT NULL DEFAULT '0')", g_TablePrefix);
  }
  db.Query(T_CreateBaseWeaponsTableCallback, query, mysql, DBPrio_High);
}

public void T_CreateBaseWeaponsTableCallback(Database database, DBResultSet results, const char[] error, bool mysql) {
  if (results == null) {
    LogError("Create weapons table failed: %s", error);
    return;
  }
  AddMissingWeaponColumnsToTransaction(mysql);
}

void AddMissingWeaponColumnsToTransaction(bool mysql) {
  Transaction txn = new Transaction();
  char weaponName[32];
  char fieldName[40];

  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    RemoveWeaponPrefix(g_WeaponClasses[i], weaponName, sizeof(weaponName));
    AddWeaponColumnsToTransaction(txn, weaponName);
    if (!IsWeaponIndexInOnlyOneTeam(i)) {
      Format(fieldName, sizeof(fieldName), "ct_%s", weaponName);
      AddWeaponColumnsToTransaction(txn, fieldName);
    }
  }

  db.Execute(txn, T_AddColumnsSuccessCallback, T_AddColumnsFailCallback, mysql);
}

void AddWeaponColumnsToTransaction(Transaction txn, const char[] fieldName) {
  char query[256];
  Format(query, sizeof(query), "ALTER TABLE %sweapons ADD COLUMN `%s` int(4) NOT NULL DEFAULT '0'", g_TablePrefix, fieldName);
  txn.AddQuery(query);
  Format(query, sizeof(query), "ALTER TABLE %sweapons ADD COLUMN `%s_float` decimal(5,4) NOT NULL DEFAULT '0.0'", g_TablePrefix, fieldName);
  txn.AddQuery(query);
  Format(query, sizeof(query), "ALTER TABLE %sweapons ADD COLUMN `%s_trak` int(1) NOT NULL DEFAULT '0'", g_TablePrefix, fieldName);
  txn.AddQuery(query);
  Format(query, sizeof(query), "ALTER TABLE %sweapons ADD COLUMN `%s_trak_count` int(10) NOT NULL DEFAULT '0'", g_TablePrefix, fieldName);
  txn.AddQuery(query);
  Format(query, sizeof(query), "ALTER TABLE %sweapons ADD COLUMN `%s_tag` varchar(128) NOT NULL DEFAULT ''", g_TablePrefix, fieldName);
  txn.AddQuery(query);
  Format(query, sizeof(query), "ALTER TABLE %sweapons ADD COLUMN `%s_seed` int(10) NOT NULL DEFAULT '-1'", g_TablePrefix, fieldName);
  txn.AddQuery(query);
}

public void T_AddColumnsSuccessCallback(Database database, bool mysql, int numQueries, DBResultSet[] results, any[] queryData) {
  CreateTimestampTable(mysql);
}

public void T_AddColumnsFailCallback(Database database, bool mysql, int numQueries, const char[] error, int failIndex, any[] queryData) {
  LogMessageConditional("Weapon column migration skipped or partially failed: %s", error);
  CreateTimestampTable(mysql);
}

void CreateTimestampTable(bool mysql) {
  char query[512];
  if (mysql) {
    Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %sweapons_timestamps (`steamid` varchar(32) NOT NULL PRIMARY KEY, `last_seen` INTEGER NOT NULL) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", g_TablePrefix);
  } else {
    Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %sweapons_timestamps (`steamid` TEXT NOT NULL PRIMARY KEY, `last_seen` INTEGER NOT NULL)", g_TablePrefix);
  }
  db.Query(T_CreateTimestampTableCallback, query, mysql, DBPrio_High);
}

public void T_CreateTimestampTableCallback(Database database, DBResultSet results, const char[] error, bool mysql) {
  if (results == null) {
    LogError("Create timestamp table failed: %s", error);
    return;
  }
  FinishDatabaseInit(mysql);
}

void FinishDatabaseInit(bool mysql) {
  g_iDatabaseState = 2;
  LogMessageConditional("%s DB connection successful", mysql ? "MySQL" : "SQLite");
  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && IsClientAuthorized(i)) {
      OnClientPostAdminCheck(i);
    }
  }
  DeleteInactivePlayerData();
}

void ResetClientWeaponData(int client) {
  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++) {
      g_iSkins[client][i][team] = 0;
      g_iStatTrak[client][i][team] = 0;
      g_iStatTrakCount[client][i][team] = 0;
      g_NameTag[client][i][team][0] = '\0';
      g_fFloatValue[client][i][team] = 0.0;
      g_iWeaponSeed[client][i][team] = -1;
    }
    g_iSeedRandom[client][i] = 0;
  }
  g_iKnife[client][CS_TEAM_T] = 0;
  g_iKnife[client][CS_TEAM_CT] = 0;
}

void GetPlayerData(int client) {
  if (!IsDatabaseReady()) {
    return;
  }

  char steamid[32];
  if (GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true)) {
    char query[256];
    FormatEx(query, sizeof(query), "SELECT * FROM %sweapons WHERE steamid = '%s'", g_TablePrefix, steamid);
    db.Query(T_GetPlayerDataCallback, query, GetClientUserId(client));
  }
}

public void T_GetPlayerDataCallback(Database database, DBResultSet results, const char[] error, int userid) {
  int client = GetClientOfUserId(userid);
  if (!IsValidClient(client)) {
    return;
  }

  if (results == null) {
    LogError("Get player data failed: %s", error);
    return;
  }

  ResetClientWeaponData(client);
  if (results.RowCount == 0 || !results.FetchRow()) {
    CreatePlayerData(client);
    return;
  }

  g_iKnife[client][CS_TEAM_T] = GetIntField(results, "knife", 0);
  g_iKnife[client][CS_TEAM_CT] = GetIntField(results, "knife_ct", 0);
  ReadWeaponDataFromRow(client, results);
  UpdatePlayerTimestamp(client);
}

int GetIntField(DBResultSet results, const char[] fieldName, int defaultValue = 0) {
  int field;
  if (results.FieldNameToNum(fieldName, field)) {
    return results.FetchInt(field);
  }
  return defaultValue;
}

float GetFloatField(DBResultSet results, const char[] fieldName, float defaultValue = 0.0) {
  int field;
  if (results.FieldNameToNum(fieldName, field)) {
    return results.FetchFloat(field);
  }
  return defaultValue;
}

void GetStringField(DBResultSet results, const char[] fieldName, char[] output, int size) {
  int field;
  if (results.FieldNameToNum(fieldName, field)) {
    results.FetchString(field, output, size);
  } else {
    output[0] = '\0';
  }
}

void ReadWeaponDataFromRow(int client, DBResultSet results) {
  char baseField[40];
  char fieldName[64];
  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++) {
      if (!GetWeaponFieldName(i, team, baseField, sizeof(baseField))) {
        continue;
      }

      g_iSkins[client][i][team] = GetIntField(results, baseField, 0);
      Format(fieldName, sizeof(fieldName), "%s_float", baseField);
      g_fFloatValue[client][i][team] = GetFloatField(results, fieldName, 0.0);
      Format(fieldName, sizeof(fieldName), "%s_trak", baseField);
      g_iStatTrak[client][i][team] = GetIntField(results, fieldName, 0);
      Format(fieldName, sizeof(fieldName), "%s_trak_count", baseField);
      g_iStatTrakCount[client][i][team] = GetIntField(results, fieldName, 0);
      Format(fieldName, sizeof(fieldName), "%s_tag", baseField);
      GetStringField(results, fieldName, g_NameTag[client][i][team], 128);
      Format(fieldName, sizeof(fieldName), "%s_seed", baseField);
      g_iWeaponSeed[client][i][team] = GetIntField(results, fieldName, -1);
    }
  }
}

void UpdatePlayerTimestamp(int client) {
  char steamid[32];
  if (db != null && GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true)) {
    char query[256];
    FormatEx(query, sizeof(query), "REPLACE INTO %sweapons_timestamps (steamid, last_seen) VALUES ('%s', %d)", g_TablePrefix, steamid, GetTime());
    db.Query(T_TimestampCallback, query);
  }
}

public void T_TimestampCallback(Database database, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    LogError("Timestamp update failed: %s", error);
  }
}

void CreatePlayerData(int client) {
  char steamid[32];
  if (db != null && GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true)) {
    char query[256];
    FormatEx(query, sizeof(query), "REPLACE INTO %sweapons (steamid) VALUES ('%s')", g_TablePrefix, steamid);
    db.Query(T_InsertCallback, query, GetClientUserId(client));
    ResetClientWeaponData(client);
    UpdatePlayerTimestamp(client);
  }
}

public void T_InsertCallback(Database database, DBResultSet results, const char[] error, int userid) {
  if (results == null) {
    LogError("Insert player data failed: %s", error);
  }
}

void UpdatePlayerData(int client, const char[] updateFields) {
  if (!IsDatabaseReady() || strlen(updateFields) == 0) {
    return;
  }

  char steamid[32];
  if (GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true)) {
    char query[2048];
    FormatEx(query, sizeof(query), "UPDATE %sweapons SET %s WHERE steamid = '%s'", g_TablePrefix, updateFields, steamid);
    db.Query(T_UpdatePlayerDataCallback, query, GetClientUserId(client));
    UpdatePlayerTimestamp(client);
  }
}

public void T_UpdatePlayerDataCallback(Database database, DBResultSet results, const char[] error, int userid) {
  if (results == null) {
    LogError("Update player data failed: %s", error);
  }
}

void DeleteInactivePlayerData() {
  if (db != null && g_iGraceInactiveDays > 0) {
    char query[512];
    int now = GetTime();
    FormatEx(query, sizeof(query), "DELETE FROM %sweapons WHERE steamid in (SELECT steamid FROM %sweapons_timestamps WHERE last_seen < %d - (%d * 86400))", g_TablePrefix, g_TablePrefix, now, g_iGraceInactiveDays);
    db.Query(T_DeleteInactivePlayerDataCallback, query, now);
  }
}

public void T_DeleteInactivePlayerDataCallback(Database database, DBResultSet results, const char[] error, int now) {
  if (results == null) {
    LogError("Delete inactive player data failed: %s", error);
    return;
  }

  if (now > 0) {
    char query[256];
    FormatEx(query, sizeof(query), "DELETE FROM %sweapons_timestamps WHERE last_seen < %d - (%d * 86400)", g_TablePrefix, now, g_iGraceInactiveDays);
    db.Query(T_DeleteInactivePlayerDataCallback, query, 0);
  } else {
    LogMessageConditional("Inactive players data has been deleted");
  }
}

void ResetPlayerData(int target) {
  if (!IsDatabaseReady() || !IsValidClient(target)) {
    return;
  }

  char steamid[32];
  if (GetClientAuthId(target, AuthId_Steam2, steamid, sizeof(steamid), true)) {
    char query[256];
    FormatEx(query, sizeof(query), "DELETE FROM %sweapons WHERE steamid = '%s'", g_TablePrefix, steamid);
    db.Query(T_DeletePlayerDataCallback, query);
    FormatEx(query, sizeof(query), "DELETE FROM %sweapons_timestamps WHERE steamid = '%s'", g_TablePrefix, steamid);
    db.Query(T_DeletePlayerDataCallback, query);
    ResetClientWeaponData(target);
    CreatePlayerData(target);
  }
}

public void T_DeletePlayerDataCallback(Database database, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    LogError("Delete player data failed: %s", error);
  }
}

public Action CommandResetWeaponSkins(int client, int args) {
  if (args < 1) {
    ReplyToCommand(client, "Usage: sm_wsreset <#userid|name>");
    return Plugin_Handled;
  }

  char targetArg[64];
  GetCmdArg(1, targetArg, sizeof(targetArg));
  int target = FindTarget(client, targetArg, true, false);
  if (target <= 0) {
    return Plugin_Handled;
  }

  ResetPlayerData(target);
  ReplyToCommand(client, " %s Reset weapon skin data for %N", g_ChatPrefix, target);
  return Plugin_Handled;
}

public Action Command_DBStatus(int client, int args) {
  char driver[16] = "none";
  if (db != null) {
    db.Driver.GetIdentifier(driver, sizeof(driver));
  }

  ReplyToCommand(client, "Weapons DB status: state=%d connection=%s driver=%s ready=%d", g_iDatabaseState, g_DBConnection, driver, IsDatabaseReady());
  return Plugin_Handled;
}

void InitializeConVars() {
  GetConVarString(g_Cvar_DBConnection, g_DBConnection, sizeof(g_DBConnection));
  GetConVarString(g_Cvar_TablePrefix, g_TablePrefix, sizeof(g_TablePrefix));
  GetConVarString(g_Cvar_ChatPrefix, g_ChatPrefix, sizeof(g_ChatPrefix));
  g_bEnableLogging = g_Cvar_EnableLogging.BoolValue;
  g_iKnifeStatTrakMode = g_Cvar_KnifeStatTrakMode.IntValue;
  g_bEnableFloat = g_Cvar_EnableFloat.BoolValue;
  g_bEnableNameTag = g_Cvar_EnableNameTag.BoolValue;
  g_bEnableStatTrak = g_Cvar_EnableStatTrak.BoolValue;
  g_bEnableSeed = g_Cvar_EnableSeed.BoolValue;
  g_fFloatIncrementSize = g_Cvar_FloatIncrementSize.FloatValue;
  g_iFloatIncrementPercentage = RoundFloat(g_fFloatIncrementSize * 100.0);
  g_bOverwriteEnabled = g_Cvar_EnableWeaponOverwrite.BoolValue;
  g_iGracePeriod = g_Cvar_GracePeriod.IntValue;
  g_iGraceInactiveDays = g_Cvar_InactiveDays.IntValue;
}

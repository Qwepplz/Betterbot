/*  CS:GO Weapons&Knives SourceMod Plugin
 *
 *  Copyright (C) 2017 Kağan 'kgns' Üstüngel
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see http://www.gnu.org/licenses/.
 */

stock void StripHtml(const char[] source, char[] output, int size) {
  int start, end;
  strcopy(output, size, source);
  while ((start = StrContains(output, ">")) > 0) {
    strcopy(output, size, output[start + 1]);
    if ((end = StrContains(output, "<")) > 0) {
      output[end] = '\0';
    }
  }
}

stock void CleanNameTag(char[] nameTag, int size) {
  ReplaceString(nameTag, size, "%", "％");
  while (StrContains(nameTag, "  ") > -1) {
    ReplaceString(nameTag, size, "  ", " ");
  }
  StripQuotes(nameTag);
}

stock int GetClientMenuLanguage(int client) {
  int language = g_iDefaultLanguage;
  if (IsValidClientIndex(client) && 0 <= g_iClientLanguage[client] < MAX_LANG) {
    language = g_iClientLanguage[client];
  }
  if (!(0 <= language < MAX_LANG) || menuWeapons[language][0] == null) {
    language = g_iDefaultLanguage;
  }
  if (!(0 <= language < MAX_LANG) || menuWeapons[language][0] == null) {
    language = 0;
  }
  return language;
}

stock int GetRandomSkin(int client, int index) {
  int language = GetClientMenuLanguage(client);
  Menu menu = menuWeapons[language][index];
  if (menu == null || menu.ItemCount <= 2) {
    return 0;
  }

  int random = GetRandomInt(2, menu.ItemCount - 1);
  char idStr[12];
  menu.GetItem(random, idStr, sizeof(idStr));
  return StringToInt(idStr);
}

stock bool IsValidClient(int client) {
  if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) ||
      IsClientReplay(client)) {
    return false;
  }
  return true;
}

stock int GetWeaponIndex(int entity) {
  char class[32];
  if (GetWeaponClass(entity, class, sizeof(class))) {
    int index;
    if (g_smWeaponIndex.GetValue(class, index)) {
      return index;
    }
  }
  return -1;
}

stock bool GetWeaponClass(int entity, char[] weaponClass, int size) {
  int id = GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
  return ClassByDefIndex(id, weaponClass, size);
}

stock bool IsKnifeClass(const char[] classname) {
  if ((StrContains(classname, "knife") > -1 && strcmp(classname, "weapon_knifegg") != 0) ||
      StrContains(classname, "bayonet") > -1)
    return true;
  return false;
}

stock bool IsKnife(int entity) {
  char classname[32];
  if (GetWeaponClass(entity, classname, sizeof(classname)))
    return IsKnifeClass(classname);
  return false;
}

stock int DefIndexByClass(char[] class) {
  if (StrEqual(class, "weapon_knife")) {
    return 42;
  }
  if (StrEqual(class, "weapon_knife_t")) {
    return 59;
  }
  int index;
  g_smWeaponDefIndex.GetValue(class, index);
  if (index > -1)
    return index;
  return 0;
}

stock void RemoveWeaponPrefix(const char[] source, char[] output, int size) {
  strcopy(output, size, source[7]);
}

stock bool ClassByDefIndex(int index, char[] class, int size) {
  switch (index) {
    case 42: {
      FormatEx(class, size, "weapon_knife");
      return true;
    }
    case 59: {
      FormatEx(class, size, "weapon_knife_t");
      return true;
    }
    default: {
      for (int i = 0; i < sizeof(g_iWeaponDefIndex); i++) {
        if (g_iWeaponDefIndex[i] == index) {
          FormatEx(class, size, g_WeaponClasses[i]);
          return true;
        }
      }
    }
  }
  return false;
}

stock bool IsValidWeapon(int weaponEntity) {
  if (weaponEntity > 4096 && weaponEntity != INVALID_ENT_REFERENCE) {
    weaponEntity = EntRefToEntIndex(weaponEntity);
  }

  if (!IsValidEdict(weaponEntity) || !IsValidEntity(weaponEntity) || weaponEntity == -1) {
    return false;
  }

  char weaponClass[64];
  GetEdictClassname(weaponEntity, weaponClass, sizeof(weaponClass));

  return StrContains(weaponClass, "weapon_") == 0;
}

stock void FirstCharUpper(char[] string) {
  if (strlen(string) > 0) {
    string[0] = CharToUpper(string[0]);
  }
}

stock int GetTotalKnifeStatTrakCount(int client) {
  int count = 0;
  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    if (IsKnifeClass(g_WeaponClasses[i])) {
      count += g_iStatTrakCount[client][i][CS_TEAM_T];
      count += g_iStatTrakCount[client][i][CS_TEAM_CT];
    }
  }
  return count;
}

stock int GetRemainingGracePeriodSeconds(int client) {
  if (g_iGracePeriod == 0 || g_iRoundStartTime == 0 || (IsClientInGame(client) && !IsPlayerAlive(client))) {
    return MENU_TIME_FOREVER;
  } else {
    int remaining = g_iRoundStartTime + g_iGracePeriod - GetTime();
    return remaining > 0 ? remaining : -1;
  }
}

stock bool IsWeaponIndexInOnlyOneTeam(int index) {
  for (int i = 0; i < sizeof(g_OnlyOneTeamWeaponIndex); i++) {
    if (g_OnlyOneTeamWeaponIndex[i] == index) {
      return true;
    }
  }
  return false;
}

stock void LogMessageConditional(const char[] message, any ...) {
  if (!g_bEnableLogging) {
    return;
  }

  char buffer[1024];
  VFormat(buffer, sizeof(buffer), message, 2);
  LogMessage("%s", buffer);
}

stock bool IsValidClientIndex(int client) {
  return 1 <= client <= MaxClients;
}

stock bool IsValidWeaponIndex(int index) {
  return 0 <= index < sizeof(g_WeaponClasses);
}

stock bool IsValidTeam(int team) {
  return team == CS_TEAM_T || team == CS_TEAM_CT;
}

stock bool IsDatabaseReady() {
  return db != null && g_iDatabaseState >= 2;
}

stock int GetClientTeamSafe(int client) {
  if (IsValidClientIndex(client) && IsClientInGame(client)) {
    return GetClientTeam(client);
  }
  return -1;
}

stock int GiveClientDefaultKnife(int client) {
  int team = GetClientTeamSafe(client);
  return GivePlayerItem(client, team == CS_TEAM_T ? "weapon_knife_t" : "weapon_knife");
}

stock int GetRandomKnife() {
  return g_iKnifeIndices[GetRandomInt(0, sizeof(g_iKnifeIndices) - 1)];
}

stock int DefIndexToWeaponIndex(int defIndex) {
  for (int i = 0; i < sizeof(g_iWeaponDefIndex); i++) {
    if (g_iWeaponDefIndex[i] == defIndex) {
      return i;
    }
  }
  return -1;
}

stock bool IsValidKnifeDefIndex(int defIndex) {
  return defIndex == 42 || defIndex == 59 || (507 <= defIndex <= 528);
}

stock bool GetIndex(const char[] classname, int &index) {
  return g_smWeaponIndex != null && g_smWeaponIndex.GetValue(classname, index);
}

stock bool HasKnife(int client) {
  int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
  for (int i = 0; i < size; i++) {
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
    if (IsValidWeapon(weapon) && IsKnife(weapon)) {
      return true;
    }
  }
  return false;
}

stock bool IsPlayerControllingBot(int client) {
  return IsValidClientIndex(client) && IsClientInGame(client) && !IsFakeClient(client) &&
         GetEntProp(client, Prop_Send, "m_bIsControllingBot") == 1;
}

stock int GetControlledBot(int client) {
  if (!IsPlayerControllingBot(client)) {
    return -1;
  }

  int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
  if (IsValidClientIndex(target) && IsClientInGame(target) && IsFakeClient(target)) {
    return target;
  }
  return -1;
}

stock int GetBotController(int bot) {
  for (int client = 1; client <= MaxClients; client++) {
    if (GetControlledBot(client) == bot) {
      return client;
    }
  }
  return -1;
}

stock bool IsWarmUpPeriod() {
  return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

stock bool GetWeaponFieldName(int index, int team, char[] fieldName, int size) {
  if (!IsValidWeaponIndex(index) || !IsValidTeam(team) || size <= 0) {
    return false;
  }

  char weaponName[32];
  RemoveWeaponPrefix(g_WeaponClasses[index], weaponName, sizeof(weaponName));
  if (team == CS_TEAM_CT && !IsWeaponIndexInOnlyOneTeam(index)) {
    Format(fieldName, size, "ct_%s", weaponName);
  } else {
    strcopy(fieldName, size, weaponName);
  }
  return true;
}

stock bool BuildWeaponSkinUpdateField(int index, int team, int skin, char[] output, int size) {
  char fieldName[40];
  if (!GetWeaponFieldName(index, team, fieldName, sizeof(fieldName))) {
    return false;
  }
  Format(output, size, "%s = %d", fieldName, skin);
  return true;
}

stock bool BuildWeaponFloatUpdateField(int index, int team, float wear, char[] output, int size) {
  char fieldName[40];
  if (!GetWeaponFieldName(index, team, fieldName, sizeof(fieldName))) {
    return false;
  }
  Format(output, size, "%s_float = %.4f", fieldName, wear);
  return true;
}

stock bool BuildWeaponStatTrakUpdateField(int index, int team, int enabled, char[] output, int size) {
  char fieldName[40];
  if (!GetWeaponFieldName(index, team, fieldName, sizeof(fieldName))) {
    return false;
  }
  Format(output, size, "%s_trak = %d", fieldName, enabled);
  return true;
}

stock bool BuildWeaponStatTrakCountUpdateField(int index, int team, int count, char[] output, int size) {
  char fieldName[40];
  if (!GetWeaponFieldName(index, team, fieldName, sizeof(fieldName))) {
    return false;
  }
  Format(output, size, "%s_trak_count = %d", fieldName, count);
  return true;
}

stock bool BuildWeaponNameTagUpdateField(int index, int team, const char[] nameTag, char[] output, int size) {
  char fieldName[40];
  if (!GetWeaponFieldName(index, team, fieldName, sizeof(fieldName))) {
    return false;
  }

  char escaped[257];
  if (db != null) {
    db.Escape(nameTag, escaped, sizeof(escaped));
  } else {
    strcopy(escaped, sizeof(escaped), nameTag);
  }
  Format(output, size, "%s_tag = '%s'", fieldName, escaped);
  return true;
}

stock bool BuildWeaponSeedUpdateField(int index, int team, int seed, char[] output, int size) {
  char fieldName[40];
  if (!GetWeaponFieldName(index, team, fieldName, sizeof(fieldName))) {
    return false;
  }
  Format(output, size, "%s_seed = %d", fieldName, seed);
  return true;
}

stock void ApplyToOppositeTeam(int client, int index) {
  int team = IsWeaponIndexInOnlyOneTeam(index) ? CS_TEAM_T : GetClientTeamSafe(client);
  if (!IsValidTeam(team) || IsWeaponIndexInOnlyOneTeam(index)) {
    return;
  }

  int otherTeam = team == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;
  g_iSkins[client][index][otherTeam] = g_iSkins[client][index][team];
  g_fFloatValue[client][index][otherTeam] = g_fFloatValue[client][index][team];
  g_iWeaponSeed[client][index][otherTeam] = g_iWeaponSeed[client][index][team];
  g_iStatTrak[client][index][otherTeam] = g_iStatTrak[client][index][team];
  g_iStatTrakCount[client][index][otherTeam] = g_iStatTrakCount[client][index][team];
  strcopy(g_NameTag[client][index][otherTeam], 128, g_NameTag[client][index][team]);

  char field[6][256];
  BuildWeaponSkinUpdateField(index, otherTeam, g_iSkins[client][index][otherTeam], field[0], sizeof(field[]));
  BuildWeaponFloatUpdateField(index, otherTeam, g_fFloatValue[client][index][otherTeam], field[1], sizeof(field[]));
  BuildWeaponStatTrakUpdateField(index, otherTeam, g_iStatTrak[client][index][otherTeam], field[2], sizeof(field[]));
  BuildWeaponStatTrakCountUpdateField(index, otherTeam, g_iStatTrakCount[client][index][otherTeam], field[3], sizeof(field[]));
  BuildWeaponNameTagUpdateField(index, otherTeam, g_NameTag[client][index][otherTeam], field[4], sizeof(field[]));
  BuildWeaponSeedUpdateField(index, otherTeam, g_iWeaponSeed[client][index][otherTeam], field[5], sizeof(field[]));

  char updateFields[1536];
  Format(updateFields, sizeof(updateFields), "%s, %s, %s, %s, %s, %s", field[0], field[1], field[2], field[3], field[4], field[5]);
  UpdatePlayerData(client, updateFields);
  RefreshWeapon(client, index);
  PrintToChat(client, " %s \x04%t", g_ChatPrefix, "AppliedToOppositeTeam");
}

stock void GetClientKnife(int client, char[] output, int size) {
  int team = GetClientTeamSafe(client);
  if (!IsValidTeam(team) || g_iKnife[client][team] == 0) {
    Format(output, size, team == CS_TEAM_T ? "weapon_knife_t" : "weapon_knife");
    return;
  }

  if (g_iKnife[client][team] == -1) {
    Format(output, size, "random");
    return;
  }

  strcopy(output, size, g_WeaponClasses[g_iKnife[client][team]]);
}

stock bool SetClientKnife(int client, const char[] knifeClass, bool throwError = false, bool refresh = true) {
  if (!IsValidClient(client)) {
    if (throwError) {
      ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is not valid.", client);
    }
    return false;
  }

  int knifeIndex = 0;
  if (StrEqual(knifeClass, "random", false)) {
    knifeIndex = -1;
  } else if (!StrEqual(knifeClass, "weapon_knife", false) && !StrEqual(knifeClass, "weapon_knife_t", false)) {
    knifeIndex = -1;
    for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
      if (IsKnifeClass(g_WeaponClasses[i]) && StrEqual(knifeClass, g_WeaponClasses[i], false)) {
        knifeIndex = i;
        break;
      }
    }

    if (knifeIndex == -1) {
      if (throwError) {
        ThrowNativeError(SP_ERROR_NATIVE, "Knife (%s) is not valid.", knifeClass);
      }
      return false;
    }
  }

  int team = GetClientTeamSafe(client);
  if (!IsValidTeam(team)) {
    return false;
  }

  g_iKnife[client][team] = knifeIndex;
  char teamName[4];
  teamName = team == CS_TEAM_T ? "" : "_ct";
  char updateFields[64];
  Format(updateFields, sizeof(updateFields), "knife%s = %d", teamName, knifeIndex);
  UpdatePlayerData(client, updateFields);

  if (refresh) {
    RefreshWeapon(client, knifeIndex, knifeIndex == 0);
  }
  return true;
}

stock bool SetClientSkin(int client, int index, int team, int skin, bool refresh = true) {
  if (!IsValidClient(client) || !IsValidWeaponIndex(index) || !IsValidTeam(team)) {
    return false;
  }

  g_iSkins[client][index][team] = skin;
  char updateFields[128];
  if (BuildWeaponSkinUpdateField(index, team, skin, updateFields, sizeof(updateFields))) {
    UpdatePlayerData(client, updateFields);
  }
  if (refresh) {
    RefreshWeapon(client, index);
  }
  return true;
}

stock bool SetClientWear(int client, int index, int team, float wear, bool refresh = true) {
  if (!IsValidClient(client) || !IsValidWeaponIndex(index) || !IsValidTeam(team)) {
    return false;
  }

  g_fFloatValue[client][index][team] = wear;
  char updateFields[128];
  if (BuildWeaponFloatUpdateField(index, team, wear, updateFields, sizeof(updateFields))) {
    UpdatePlayerData(client, updateFields);
  }
  if (refresh) {
    RefreshWeapon(client, index);
  }
  return true;
}

stock bool SetClientSeed(int client, int index, int team, int seed, bool refresh = true) {
  if (!IsValidClient(client) || !IsValidWeaponIndex(index) || !IsValidTeam(team)) {
    return false;
  }

  g_iWeaponSeed[client][index][team] = seed;
  g_iSeedRandom[client][index] = 0;
  char updateFields[128];
  if (BuildWeaponSeedUpdateField(index, team, seed, updateFields, sizeof(updateFields))) {
    UpdatePlayerData(client, updateFields);
  }
  if (refresh) {
    RefreshWeapon(client, index);
  }
  return true;
}

stock bool SetClientNameTag(int client, int index, int team, const char[] nameTag, bool refresh = true) {
  if (!IsValidClient(client) || !IsValidWeaponIndex(index) || !IsValidTeam(team)) {
    return false;
  }

  strcopy(g_NameTag[client][index][team], 128, nameTag);
  char updateFields[512];
  if (BuildWeaponNameTagUpdateField(index, team, nameTag, updateFields, sizeof(updateFields))) {
    UpdatePlayerData(client, updateFields);
  }
  if (refresh) {
    RefreshWeapon(client, index);
  }
  return true;
}

stock bool ToggleClientStarTrack(int client, int index, int team, bool refresh = true) {
  if (!IsValidClient(client) || !IsValidWeaponIndex(index) || !IsValidTeam(team)) {
    return false;
  }

  g_iStatTrak[client][index][team] = 1 - g_iStatTrak[client][index][team];
  char updateFields[128];
  if (BuildWeaponStatTrakUpdateField(index, team, g_iStatTrak[client][index][team], updateFields, sizeof(updateFields))) {
    UpdatePlayerData(client, updateFields);
  }
  if (refresh) {
    RefreshWeapon(client, index);
  }
  return true;
}

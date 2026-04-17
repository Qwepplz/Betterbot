/*  CS:GO Weapons&Knives SourceMod Plugin
 *
 *  Recovered from SMX and BoneTM/weapons source.
 */

public void HookPlayer(int client) {
  if (g_bEnableStatTrak)
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void UnhookPlayer(int client) {
  if (g_bEnableStatTrak)
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public Action GiveNamedItemPre(int client, char classname[64], CEconItemView &item, bool &ignoredCEconItemView,
                        bool &OriginIsNULL, float Origin[3]) {
  int owner = client;
  if (IsValidClientIndex(client) && IsClientInGame(client) && IsFakeClient(client)) {
    int controller = GetBotController(client);
    if (controller > 0) {
      owner = controller;
    }
  }

  if (IsValidClient(owner)) {
    int team = GetClientTeamSafe(owner);

    if (IsValidTeam(team) && g_iKnife[owner][team] != 0 && IsKnifeClass(classname)) {
      Action result = Plugin_Continue;
      Call_StartForward(g_hOnKnifeSelect_Pre);
      Call_PushCell(owner);
      Call_PushString(classname);
      Call_PushCell(g_iKnife[owner][team]);
      Call_Finish(result);

      if (result >= Plugin_Handled) {
        return result;
      }

      ignoredCEconItemView = true;

      if (g_iKnife[owner][team] == -1) {
        strcopy(classname, sizeof(classname), g_WeaponClasses[GetRandomKnife()]);
      } else {
        strcopy(classname, sizeof(classname), g_WeaponClasses[g_iKnife[owner][team]]);
      }
      return Plugin_Changed;
    }
  }
  return Plugin_Continue;
}

public void GiveNamedItemPost(int client, const char[] classname, const CEconItemView item, int entity, bool OriginIsNULL,
                       const float Origin[3]) {
  if (!IsValidEntity(entity)) {
    return;
  }

  int owner = client;
  if (IsValidClientIndex(client) && IsClientInGame(client) && IsFakeClient(client)) {
    int controller = GetBotController(client);
    if (controller > 0) {
      owner = controller;
    }
  }

  if (IsValidClient(owner)) {
    int index;
    if (g_smWeaponIndex.GetValue(classname, index)) {
      if (owner == client) {
        SetWeaponProps(owner, entity);
      } else {
        SetWeaponPropsForBotControl(owner, entity);
      }
    }
  }
}

public Action ChatListener(int client, const char[] command, int args) {
  char msg[128];
  GetCmdArgString(msg, sizeof(msg));
  StripQuotes(msg);
  if (StrEqual(msg, "!ws") || StrEqual(msg, "!pf") || StrEqual(msg, "!knife") || StrEqual(msg, "!dao") ||
      StrEqual(msg, "!wslang") || StrContains(msg, "!nametag") == 0 || StrContains(msg, "!seed") == 0) {
    return Plugin_Handled;
  } else if (g_bWaitingForNametag[client] && IsValidClient(client) && g_iIndex[client] > -1 && !IsChatTrigger()) {
    CleanNameTag(msg, sizeof(msg));

    g_bWaitingForNametag[client] = false;

    if (StrEqual(msg, "!cancel") || StrEqual(msg, "!iptal")) {
      PrintToChat(client, " %s \x02%t", g_ChatPrefix, "NameTagCancelled");
      return Plugin_Handled;
    }

    int team = IsWeaponIndexInOnlyOneTeam(g_iIndex[client]) ? CS_TEAM_T : GetClientTeam(client);
    g_NameTag[client][g_iIndex[client]][team] = msg;

    RefreshWeapon(client, g_iIndex[client]);

    char updateFields[512];
    BuildWeaponNameTagUpdateField(g_iIndex[client], team, msg, updateFields, sizeof(updateFields));
    UpdatePlayerData(client, updateFields);

    PrintToChat(client, " %s \x04%t: \x01\"%s\"", g_ChatPrefix, "NameTagSuccess", msg);
    return Plugin_Handled;
  } else if (g_bWaitingForSeed[client] && IsValidClient(client) && g_iIndex[client] > -1 && !IsChatTrigger()) {
    g_bWaitingForSeed[client] = false;

    int seedInt;
    if (StrEqual(msg, "!cancel") || StrEqual(msg, "!iptal") || StrEqual(msg, "")) {
      PrintToChat(client, " %s \x02%t", g_ChatPrefix, "SeedCancelled");
      return Plugin_Handled;
    } else if ((seedInt = StringToInt(msg)) < 0 || seedInt > 8192) {
      PrintToChat(client, " %s \x02%t", g_ChatPrefix, "SeedFailed");
      return Plugin_Handled;
    }
    int team = IsWeaponIndexInOnlyOneTeam(g_iIndex[client]) ? CS_TEAM_T : GetClientTeam(client);
    SetClientSeed(client, g_iIndex[client], team, seedInt, true);

    CreateTimer(0.1, SeedMenuTimer, GetClientUserId(client));
    PrintToChat(client, " %s \x04%t: \x01%i", g_ChatPrefix, "SeedSuccess", seedInt);

    return Plugin_Handled;
  } else if (g_bWaitingForWear[client] && IsValidClient(client) && g_iIndex[client] > -1 && !IsChatTrigger()) {
    g_bWaitingForWear[client] = false;

    float floatVal;
    if (StrEqual(msg, "!cancel") || StrEqual(msg, "!iptal") || StrEqual(msg, "")) {
      PrintToChat(client, " %s \x02%t", g_ChatPrefix, "FloatSetCancelled");
      return Plugin_Handled;
    } else if ((floatVal = StringToFloat(msg)) <= 0 || floatVal >= 1) {
      PrintToChat(client, " %s \x02%t", g_ChatPrefix, "FloatSetFailed");
      return Plugin_Handled;
    }
    int team = IsWeaponIndexInOnlyOneTeam(g_iIndex[client]) ? CS_TEAM_T : GetClientTeam(client);
    SetClientWear(client, g_iIndex[client], team, floatVal, true);

    CreateFloatMenu(client).Display(client, MENU_TIME_FOREVER);
    PrintToChat(client, " %s \x04%t: \x01%f", g_ChatPrefix, "FloatSetSuccess", floatVal);

    return Plugin_Handled;
  }

  return Plugin_Continue;
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon,
                         float damageForce[3], float damagePosition[3]) {
  if (float(GetClientHealth(victim)) - damage > 0.0)
    return Plugin_Continue;

  if (!(damagetype & DMG_SLASH) && !(damagetype & DMG_BULLET))
    return Plugin_Continue;

  if (!IsValidClient(attacker))
    return Plugin_Continue;

  if (!IsValidWeapon(weapon))
    return Plugin_Continue;

  int index = GetWeaponIndex(weapon);

  int team = IsWeaponIndexInOnlyOneTeam(index) ? CS_TEAM_T : GetClientTeam(attacker);
  if (index != -1 && g_iSkins[attacker][index][team] != 0 && g_iStatTrak[attacker][index][team] != 1)
    return Plugin_Continue;

  if (GetEntProp(weapon, Prop_Send, "m_nFallbackStatTrak") == -1)
    return Plugin_Continue;

  int previousOwner;
  if ((previousOwner = GetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner")) != INVALID_ENT_REFERENCE &&
      previousOwner != attacker)
    return Plugin_Continue;

  g_iStatTrakCount[attacker][index][team]++;

  char updateFields[128];
  BuildWeaponStatTrakCountUpdateField(index, team, g_iStatTrakCount[attacker][index][team], updateFields, sizeof(updateFields));
  UpdatePlayerData(attacker, updateFields);
  return Plugin_Continue;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast) {
  g_iRoundStartTime = GetTime();
}


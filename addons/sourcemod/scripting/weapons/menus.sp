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

void DisplayWeaponPaintMenu(int client, int weaponIndex, int menuTime, int menuSelectionPosition = -1) {
  if (weaponIndex < 0 || weaponIndex >= sizeof(g_WeaponClasses)) {
    return;
  }

  int language = GetClientMenuLanguage(client);
  Menu menu = menuWeapons[language][weaponIndex];
  if (menu == null) {
    return;
  }

  if (menuSelectionPosition >= 0) {
    menu.DisplayAt(client, menuSelectionPosition, menuTime);
  } else {
    menu.Display(client, menuTime);
  }
}

void AddKnifeMenuItem(Menu menu, int client, const char[] knifeIndex, const char[] phrase) {
  char buffer[60];
  BB_FormatClient(client, buffer, sizeof(buffer), "%T", phrase, client);
  menu.AddItem(knifeIndex, buffer);
}

Menu CreateKnifeMenu(int client) {
  Menu menu = new Menu(KnifeMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_DrawItem);
  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", "KnifeMenuTitle", client);
    menu.SetTitle("%s", bbText);
  }

  for (int i = 0; i < sizeof(g_KnifeMenuIndex); i++) {
    AddKnifeMenuItem(menu, client, g_KnifeMenuIndex[i], g_KnifeMenuPhrase[i]);
  }

  if (LibraryExists("diy")) {
    menu.ExitBackButton = true;
  }

  return menu;
}

public int WeaponsMenuHandler(Menu menu, MenuAction action, int client, int selection) {

  switch (action) {
    case MenuAction_Display: {
      char title[256];
      for (int k = 0; k < sizeof(g_WeaponClasses); k++) {
        if (menu == menuWeapons[0][k] || menu == menuWeapons[1][k]) {
          BB_FormatClient(client, title, sizeof(title), "%T", g_WeaponClasses[k], client);
          view_as<Panel>(selection).SetTitle(title);
          break;
        }
      }
    }
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        int index = g_iIndex[client];

        char skinIdStr[32];
        menu.GetItem(selection, skinIdStr, sizeof(skinIdStr));
        int skinId = StringToInt(skinIdStr);

        char updateFields[256];
        char weaponName[32];
        RemoveWeaponPrefix(g_WeaponClasses[index], weaponName, sizeof(weaponName));
        char currentWeaponName[32];
        strcopy(currentWeaponName, sizeof(currentWeaponName), weaponName);

        int team = GetWeaponDataTeam(client, index);
        char teamName[4];
        GetWeaponTeamPrefix(team, teamName, sizeof(teamName));
        g_iSkins[client][index][team] = skinId;

        Format(updateFields, sizeof(updateFields), "%s%s = %d", teamName, currentWeaponName, skinId);
        UpdatePlayerData(client, updateFields);

        RefreshWeapon(client, index);

        DataPack pack;
        CreateDataTimer(0.5, WeaponsMenuTimer, pack);
        pack.WriteCell(menu);
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(GetMenuSelectionPosition());
      }
    }
    case MenuAction_DisplayItem: {
      if (IsClientInGame(client)) {
        char info[32];
        char display[64];
        menu.GetItem(selection, info, sizeof(info));

        if (StrEqual(info, "0")) {
          BB_FormatClient(client, display, sizeof(display), "%T", "DefaultSkin", client);
          return RedrawMenuItem(display);
        } else if (StrEqual(info, "-1")) {
          BB_FormatClient(client, display, sizeof(display), "%T", "RandomSkin", client);
          return RedrawMenuItem(display);
        }
        int language = GetClientMenuLanguage(client);
        for (int k = 0; k < sizeof(g_WeaponClasses); k++) {
          if (menu != menuWeapons[1 - language][k]) {
            continue;
          }
          Menu localized = menuWeapons[language][k];
          if (localized != null) {
            char candidate[32];
            int style;
            for (int item = 0; item < localized.ItemCount; item++) {
              localized.GetItem(item, candidate, sizeof(candidate), style, display, sizeof(display));
              if (StrEqual(candidate, info)) {
                return RedrawMenuItem(display);
              }
            }
          }
          break;
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateWeaponMenu(client).Display(client, menuTime);
        }
      }
    }
  }
  return 0;

}

public Action WeaponsMenuTimer(Handle timer, DataPack pack) {
  ResetPack(pack);
  pack.ReadCell();
  int clientIndex = GetClientOfUserId(pack.ReadCell());
  int menuSelectionPosition = pack.ReadCell();

  if (IsValidClient(clientIndex)) {
    int menuTime;
    if ((menuTime = GetRemainingGracePeriodSeconds(clientIndex)) >= 0) {
      DisplayWeaponPaintMenu(clientIndex, g_iIndex[clientIndex], menuTime, menuSelectionPosition);
    }
  }

  return Plugin_Stop;
}

public int WeaponMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        int team = GetWeaponDataTeam(client, g_iIndex[client]);

        char buffer[30];
        menu.GetItem(selection, buffer, sizeof(buffer));
        if (StrEqual(buffer, "skin")) {
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            DisplayWeaponPaintMenu(client, g_iIndex[client], menuTime);
          }
        } else if (StrEqual(buffer, "float")) {
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateFloatMenu(client).Display(client, menuTime);
          }
        } else if (StrEqual(buffer, "stattrak")) {
          char updateFields[256];
          char weaponName[32];
          RemoveWeaponPrefix(g_WeaponClasses[g_iIndex[client]], weaponName, sizeof(weaponName));

          g_iStatTrak[client][g_iIndex[client]][team] = 1 - g_iStatTrak[client][g_iIndex[client]][team];

          char teamName[4];
          GetWeaponTeamPrefix(team, teamName, sizeof(teamName));
          Format(updateFields, sizeof(updateFields), "%s%s_trak = %d", teamName, weaponName,
                 g_iStatTrak[client][g_iIndex[client]][team]);
          UpdatePlayerData(client, updateFields);

          RefreshWeapon(client, g_iIndex[client]);

          CreateTimer(1.0, StatTrakMenuTimer, GetClientUserId(client));
        } else if (StrEqual(buffer, "nametag")) {
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateNameTagMenu(client).Display(client, menuTime);
          }
        } else if (StrEqual(buffer, "seed")) {
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateSeedMenu(client).Display(client, menuTime);
          }
        } else if (StrEqual(buffer, "paints")) {
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateAllWeaponsPaintsMenu(client).Display(client, menuTime);
          }
        } else if (StrEqual(buffer, "applyother")) {
          if (IsWeaponIndexInOnlyOneTeam(g_iIndex[client])) {
            return 0;
          }

          char weaponName[32];
          RemoveWeaponPrefix(g_WeaponClasses[g_iIndex[client]], weaponName, sizeof(weaponName));

          int otherTeam = team == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT;

          g_iSkins[client][g_iIndex[client]][otherTeam] = g_iSkins[client][g_iIndex[client]][team];
          g_fFloatValue[client][g_iIndex[client]][otherTeam] = g_fFloatValue[client][g_iIndex[client]][team];
          g_iWeaponSeed[client][g_iIndex[client]][otherTeam] = g_iWeaponSeed[client][g_iIndex[client]][team];
          g_iStatTrak[client][g_iIndex[client]][otherTeam] = g_iStatTrak[client][g_iIndex[client]][team];
          g_iStatTrakCount[client][g_iIndex[client]][otherTeam] = g_iStatTrakCount[client][g_iIndex[client]][team];
          strcopy(g_NameTag[client][g_iIndex[client]][otherTeam], 128, g_NameTag[client][g_iIndex[client]][team]);

          char otherTeamName[4];
          otherTeamName = team == CS_TEAM_T ? "ct_" : "";
          char updateFields[512];
          Format(updateFields, sizeof(updateFields), "%s%s = %d,			\
																%s%s_float = %.2f,		\
																%s%s_trak = %d,		\
																%s%s_trak_count = %d,	\
																%s%s_tag = '%s',		\
																%s%s_seed = %d",
                 otherTeamName, weaponName, g_iSkins[client][g_iIndex[client]][otherTeam], otherTeamName, weaponName,
                 g_fFloatValue[client][g_iIndex[client]][otherTeam], otherTeamName, weaponName,
                 g_iStatTrak[client][g_iIndex[client]][otherTeam], otherTeamName, weaponName,
                 g_iStatTrakCount[client][g_iIndex[client]][otherTeam], otherTeamName, weaponName,
                 g_NameTag[client][g_iIndex[client]][otherTeam], otherTeamName, weaponName,
                 g_iWeaponSeed[client][g_iIndex[client]][otherTeam]);
          UpdatePlayerData(client, updateFields);

          RefreshWeapon(client, g_iIndex[client]);

          CreateTimer(1.0, StatTrakMenuTimer, GetClientUserId(client));
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateMainMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

public Action StatTrakMenuTimer(Handle timer, int userid) {
  int clientIndex = GetClientOfUserId(userid);
  if (IsValidClient(clientIndex)) {
    int menuTime;
    if ((menuTime = GetRemainingGracePeriodSeconds(clientIndex)) >= 0) {
      CreateWeaponMenu(clientIndex).Display(clientIndex, menuTime);
    }
  }
  return Plugin_Stop;
}

Menu CreateFloatMenu(int client) {
  char buffer[60];
  Menu menu = new Menu(FloatMenuHandler);

  int team = GetWeaponDataTeam(client, g_iIndex[client]);

  float fValue = g_fFloatValue[client][g_iIndex[client]][team];
  fValue = fValue * 100.0;
  int wear = 100 - RoundFloat(fValue);

  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_15", client, "SetFloat", wear, g_fFloatValue[client][g_iIndex[client]][team]);
    menu.SetTitle("%s", bbText);
  }

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "Increase", client, g_iFloatIncrementPercentage);
  menu.AddItem("increase", buffer, wear == 100 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "Decrease", client, g_iFloatIncrementPercentage);
  menu.AddItem("decrease", buffer, wear == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "CustomFloat", client);
  menu.AddItem("set", buffer);

  menu.ExitBackButton = true;

  return menu;
}

public int FloatMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        int team = GetWeaponDataTeam(client, g_iIndex[client]);

        char buffer[30];
        menu.GetItem(selection, buffer, sizeof(buffer));
        if (StrEqual(buffer, "increase")) {
          g_fFloatValue[client][g_iIndex[client]][team] =
              g_fFloatValue[client][g_iIndex[client]][team] - g_fFloatIncrementSize;
          if (g_fFloatValue[client][g_iIndex[client]][team] < 0.0) {
            g_fFloatValue[client][g_iIndex[client]][team] = 0.0;
          }
          if (g_FloatTimer[client] != INVALID_HANDLE) {
            KillTimer(g_FloatTimer[client]);
            g_FloatTimer[client] = INVALID_HANDLE;
          }
          DataPack pack;
          g_FloatTimer[client] = CreateDataTimer(1.0, FloatTimer, pack);
          pack.WriteCell(GetClientUserId(client));
          pack.WriteCell(g_iIndex[client]);
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateFloatMenu(client).Display(client, menuTime);
          }
        } else if (StrEqual(buffer, "decrease")) {
          g_fFloatValue[client][g_iIndex[client]][team] =
              g_fFloatValue[client][g_iIndex[client]][team] + g_fFloatIncrementSize;
          if (g_fFloatValue[client][g_iIndex[client]][team] > 1.0) {
            g_fFloatValue[client][g_iIndex[client]][team] = 1.0;
          }
          if (g_FloatTimer[client] != INVALID_HANDLE) {
            KillTimer(g_FloatTimer[client]);
            g_FloatTimer[client] = INVALID_HANDLE;
          }
          DataPack pack;
          g_FloatTimer[client] = CreateDataTimer(1.0, FloatTimer, pack);
          pack.WriteCell(GetClientUserId(client));
          pack.WriteCell(g_iIndex[client]);
          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateFloatMenu(client).Display(client, menuTime);
          }
        } else if (StrEqual(buffer, "set")) {
          g_bWaitingForWear[client] = true;
          {
            char bbPrefix[32];
            GetClientChatPrefix(client, bbPrefix, sizeof(bbPrefix));
            char bbText[512];
            BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_16", client, bbPrefix, "CustomFloatInstruction");
            PrintToChat(client, "%s", bbText);
          }
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateWeaponMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

public Action FloatTimer(Handle timer, DataPack pack) {
  ResetPack(pack);
  int clientIndex = GetClientOfUserId(pack.ReadCell());
  int index = pack.ReadCell();

  if (IsValidClient(clientIndex)) {
    char updateFields[256];
    char weaponName[32];
    RemoveWeaponPrefix(g_WeaponClasses[index], weaponName, sizeof(weaponName));

    int team = GetWeaponDataTeam(clientIndex, g_iIndex[clientIndex]);
    char teamName[4];
    GetWeaponTeamPrefix(team, teamName, sizeof(teamName));
    Format(updateFields, sizeof(updateFields), "%s%s_float = %.2f", teamName, weaponName,
           g_fFloatValue[clientIndex][g_iIndex[clientIndex]][team]);
    UpdatePlayerData(clientIndex, updateFields);

    RefreshWeapon(clientIndex, index);
  }

  g_FloatTimer[clientIndex] = INVALID_HANDLE;
  return Plugin_Stop;
}

Menu CreateSeedMenu(int client) {
  int team = GetWeaponDataTeam(client, g_iIndex[client]);

  Menu menu = new Menu(SeedMenuHandler);

  char buffer[128];
  if (g_iWeaponSeed[client][g_iIndex[client]][team] != -1) {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SeedTitle", client, g_iWeaponSeed[client][g_iIndex[client]][team]);
  } else if (g_iSeedRandom[client][g_iIndex[client]] > 0) {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SeedTitle", client, g_iSeedRandom[client][g_iIndex[client]]);
  } else {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SeedTitleNoSeed", client);
  }
  menu.SetTitle("%s", buffer);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SeedRandom", client);
  menu.AddItem("rseed", buffer);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SeedManual", client);
  menu.AddItem("cseed", buffer);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SeedSave", client);
  menu.AddItem("sseed", buffer, g_iSeedRandom[client][g_iIndex[client]] == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ResetSeed", client);
  menu.AddItem("seedr", buffer,
               g_iWeaponSeed[client][g_iIndex[client]][team] == -1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

  menu.ExitBackButton = true;

  return menu;
}

public int SeedMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        int team = GetWeaponDataTeam(client, g_iIndex[client]);

        char buffer[30];
        menu.GetItem(selection, buffer, sizeof(buffer));
        if (StrEqual(buffer, "rseed")) {
          g_iWeaponSeed[client][g_iIndex[client]][team] = -1;
          RefreshWeapon(client, g_iIndex[client]);
          CreateTimer(0.1, SeedMenuTimer, GetClientUserId(client));
        } else if (StrEqual(buffer, "cseed")) {
          g_bWaitingForSeed[client] = true;
          {
            char bbPrefix[32];
            GetClientChatPrefix(client, bbPrefix, sizeof(bbPrefix));
            char bbText[512];
            BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_17", client, bbPrefix, "SeedInstruction");
            PrintToChat(client, "%s", bbText);
          }
        } else if (StrEqual(buffer, "sseed")) {
          if (g_iSeedRandom[client][g_iIndex[client]] > 0) {
            g_iWeaponSeed[client][g_iIndex[client]][team] = g_iSeedRandom[client][g_iIndex[client]];
          }
          g_iSeedRandom[client][g_iIndex[client]] = 0;
          RefreshWeapon(client, g_iIndex[client]);

          char updateFields[256];
          char weaponName[32];
          RemoveWeaponPrefix(g_WeaponClasses[g_iIndex[client]], weaponName, sizeof(weaponName));

          char teamName[4];
          GetWeaponTeamPrefix(team, teamName, sizeof(teamName));
          Format(updateFields, sizeof(updateFields), "%s%s_seed = %d", teamName, weaponName,
                 g_iWeaponSeed[client][g_iIndex[client]][team]);
          UpdatePlayerData(client, updateFields);
          CreateTimer(0.1, SeedMenuTimer, GetClientUserId(client));

          {
            char bbPrefix[32];
            GetClientChatPrefix(client, bbPrefix, sizeof(bbPrefix));
            char bbText[512];
            BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_18", client, bbPrefix, "SeedSaved");
            PrintToChat(client, "%s", bbText);
          }
        } else if (StrEqual(buffer, "seedr")) {
          g_iWeaponSeed[client][g_iIndex[client]][team] = -1;
          g_iSeedRandom[client][g_iIndex[client]] = 0;

          char updateFields[256];
          char weaponName[32];
          RemoveWeaponPrefix(g_WeaponClasses[g_iIndex[client]], weaponName, sizeof(weaponName));

          char teamName[4];
          GetWeaponTeamPrefix(team, teamName, sizeof(teamName));
          Format(updateFields, sizeof(updateFields), "%s%s_seed = -1", teamName, weaponName);
          UpdatePlayerData(client, updateFields);
          CreateTimer(0.1, SeedMenuTimer, GetClientUserId(client));

          {
            char bbPrefix[32];
            GetClientChatPrefix(client, bbPrefix, sizeof(bbPrefix));
            char bbText[512];
            BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_19", client, bbPrefix, "SeedReset");
            PrintToChat(client, "%s", bbText);
          }
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateWeaponMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

public Action SeedMenuTimer(Handle timer, int userid) {
  int clientIndex = GetClientOfUserId(userid);
  if (IsValidClient(clientIndex)) {
    int menuTime;
    if ((menuTime = GetRemainingGracePeriodSeconds(clientIndex)) >= 0) {
      CreateSeedMenu(clientIndex).Display(clientIndex, menuTime);
    }
  }
  return Plugin_Stop;
}

Menu CreateNameTagMenu(int client) {
  Menu menu = new Menu(NameTagMenuHandler);

  char buffer[128];
  int team = GetWeaponDataTeam(client, g_iIndex[client]);
  StripHtml(g_NameTag[client][g_iIndex[client]][team], buffer, sizeof(buffer));
  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_20", client, "SetNameTag", buffer);
    menu.SetTitle("%s", bbText);
  }

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ChangeNameTag", client);
  menu.AddItem("nametag", buffer);

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "DeleteNameTag", client);
  menu.AddItem("delete", buffer,
               strlen(g_NameTag[client][g_iIndex[client]][team]) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

  menu.ExitBackButton = true;

  return menu;
}

public int NameTagMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        char buffer[30];
        menu.GetItem(selection, buffer, sizeof(buffer));
        if (StrEqual(buffer, "nametag")) {
          g_bWaitingForNametag[client] = true;
          {
            char bbPrefix[32];
            GetClientChatPrefix(client, bbPrefix, sizeof(bbPrefix));
            char bbText[512];
            BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ClientDisplay_21", client, bbPrefix, "NameTagInstruction");
            PrintToChat(client, "%s", bbText);
          }
        }
        else if (StrEqual(buffer, "delete")) {
          char updateFields[256];
          char weaponName[32];
          RemoveWeaponPrefix(g_WeaponClasses[g_iIndex[client]], weaponName, sizeof(weaponName));

          int team = GetWeaponDataTeam(client, g_iIndex[client]);
          g_NameTag[client][g_iIndex[client]][team] = "";
          char teamName[4];
          GetWeaponTeamPrefix(team, teamName, sizeof(teamName));
          Format(updateFields, sizeof(updateFields), "%s%s_tag = ''", teamName, weaponName);
          UpdatePlayerData(client, updateFields);

          RefreshWeapon(client, g_iIndex[client]);

          int menuTime;
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateWeaponMenu(client).Display(client, menuTime);
          }
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateWeaponMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

Menu CreateAllWeaponsPaintsMenu(int client) {
  int index = g_iIndex[client];

  Menu menu = new Menu(AllWeaponsPaintsMenuHandler);
  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", g_WeaponClasses[index], client);
    menu.SetTitle("%s", bbText);
  }

  char name[32];
  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    BB_FormatClient(client, name, sizeof(name), "%T", g_WeaponClasses[i], client);
    menu.AddItem(g_WeaponClasses[i], name);
  }

  menu.ExitBackButton = true;

  return menu;
}

public int AllWeaponsPaintsMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        char class[30];
        menu.GetItem(selection, class, sizeof(class));

        int temp;
        g_smWeaponIndex.GetValue(class, temp);
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          DisplayWeaponPaintMenu(client, temp, menuTime);
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateWeaponMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

Menu CreateAllWeaponsMenu(int client) {
  Menu menu = new Menu(AllWeaponsMenuHandler);
  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", "AllWeaponsMenuTitle", client);
    menu.SetTitle("%s", bbText);
  }

  char name[32];
  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    BB_FormatClient(client, name, sizeof(name), "%T", g_WeaponClasses[i], client);
    menu.AddItem(g_WeaponClasses[i], name);
  }

  menu.ExitBackButton = true;

  return menu;
}

public int AllWeaponsMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        char class[30];
        menu.GetItem(selection, class, sizeof(class));

        g_smWeaponIndex.GetValue(class, g_iIndex[client]);
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateWeaponMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateMainMenu(client).Display(client, menuTime);
        }
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

Menu CreateWeaponMenu(int client) {
  int index = g_iIndex[client];

  Menu menu = new Menu(WeaponMenuHandler);
  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", g_WeaponClasses[index], client);
    menu.SetTitle("%s", bbText);
  }

  char buffer[128];

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SetSkin", client);
  menu.AddItem("skin", buffer);

  int team = GetWeaponDataTeam(client, index);
  bool weaponHasSkin = (g_iSkins[client][index][team] != 0);

  if (g_bEnablePaints) {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "AllWeaponsMenuTitle", client);
    menu.AddItem("paints", buffer);
  }

  if (!IsWeaponIndexInOnlyOneTeam(index)) {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ApplyToOppositeTeam", client);
    menu.AddItem("applyother", buffer);
  }

  if (g_bEnableFloat) {
    float fValue = g_fFloatValue[client][index][team];
    fValue = fValue * 100.0;
    int wear = 100 - RoundFloat(fValue);
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ClientDisplay_22", client, "SetFloat", wear);
    menu.AddItem("float", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  }

  if (g_bEnableNameTag) {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "SetNameTag", client);
    menu.AddItem("nametag", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  }

  if (g_bEnableSeed) {
    BB_FormatClient(client, buffer, sizeof(buffer), "%T", "Seed", client);
    menu.AddItem("seed", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  }

  if (g_bEnableStatTrak) {
    if (g_iStatTrak[client][index][team] == 1) {
      BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ClientDisplay_23", client, "StatTrak", "On");
    } else {
      BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ClientDisplay_24", client, "StatTrak", "Off");
    }
    menu.AddItem("stattrak", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
  }

  menu.ExitBackButton = true;

  return menu;
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        char info[32];
        menu.GetItem(selection, info, sizeof(info));
        int menuTime;
        if (StrEqual(info, "all")) {
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateAllWeaponsMenu(client).Display(client, menuTime);
          }
        } else {
          g_smWeaponIndex.GetValue(info, g_iIndex[client]);
          if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
            CreateWeaponMenu(client).Display(client, menuTime);
          }
        }
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        ClientCommand(client, "sm_diy");
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }
  return 0;
}

Menu CreateMainMenu(int client) {
  char buffer[60];
  Menu menu = new Menu(MainMenuHandler, MENU_ACTIONS_DEFAULT);

  {
    char bbText[512];
    BB_FormatClient(client, bbText, sizeof(bbText), "%T", "WSMenuTitle", client);
    menu.SetTitle("%s", bbText);
  }

  BB_FormatClient(client, buffer, sizeof(buffer), "%T", "ConfigAllWeapons", client);
  menu.AddItem("all", buffer);

  int index = 2;

  if (IsPlayerAlive(client)) {
    char weaponClass[32];
    char weaponName[32];
    StringMap addedWeapons = new StringMap();

    int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");

    for (int i = 0; i < size; i++) {
      int weaponEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
      if (weaponEntity != -1 && GetWeaponClass(weaponEntity, weaponClass, sizeof(weaponClass))) {
        int alreadyAdded;
        if (addedWeapons.GetValue(weaponClass, alreadyAdded)) {
          continue;
        }

        addedWeapons.SetValue(weaponClass, 1);

        int team = GetClientTeam(client);
        BB_FormatClient(client, weaponName, sizeof(weaponName), "%T", weaponClass, client);
        menu.AddItem(weaponClass, weaponName,
                     (IsKnifeClass(weaponClass) && g_iKnife[client][team] == 0) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        index++;
      }
    }

    delete addedWeapons;
  }

  for (int i = index; i < 6; i++) {
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }

  if (LibraryExists("diy")) {
    menu.ExitBackButton = true;
  }

  return menu;
}

public int KnifeMenuHandler(Menu menu, MenuAction action, int client, int selection) {
  switch (action) {
    case MenuAction_Select: {
      if (IsClientInGame(client)) {
        char knifeIdStr[32];
        menu.GetItem(selection, knifeIdStr, sizeof(knifeIdStr));
        int knifeId = StringToInt(knifeIdStr);

        int team = GetClientTeam(client);

        g_iKnife[client][team] = knifeId;
        char teamName[4];
        teamName = team == CS_TEAM_T ? "" : "_ct";
        char updateFields[50];
        Format(updateFields, sizeof(updateFields), "knife%s = %d", teamName, knifeId);
        UpdatePlayerData(client, updateFields);

        RefreshWeapon(client, knifeId, knifeId == 0);

        int menuTime;
        if ((menuTime = GetRemainingGracePeriodSeconds(client)) >= 0) {
          CreateKnifeMenu(client).DisplayAt(client, GetMenuSelectionPosition(), menuTime);
        }
      }
    }
    case MenuAction_DrawItem: {
      char info[32];
      menu.GetItem(selection, info, sizeof(info));
      int team = GetClientTeam(client);
      if (g_iKnife[client][team] == StringToInt(info)) {
        return ITEMDRAW_DISABLED;
      }
    }
    case MenuAction_Cancel: {
      if (IsClientInGame(client) && selection == MenuCancel_ExitBack) {
        ClientCommand(client, "sm_diy");
      }
    }
    case MenuAction_End: {
      delete menu;
    }
  }

  return 0;
}

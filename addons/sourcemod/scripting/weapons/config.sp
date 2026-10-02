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

public void ReadConfig() {
  delete g_smWeaponIndex;
  g_smWeaponIndex = new StringMap();
  delete g_smWeaponDefIndex;
  g_smWeaponDefIndex = new StringMap();

  for (int i = 0; i < sizeof(g_WeaponClasses); i++) {
    g_smWeaponIndex.SetValue(g_WeaponClasses[i], i);
    g_smWeaponDefIndex.SetValue(g_WeaponClasses[i], g_iWeaponDefIndex[i]);
  }

  char languages[][] = {"english", "schinese"};
  for (int langCounter = 0; langCounter < MAX_LANG; langCounter++) {
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/weapons/weapons_%s.cfg", languages[langCounter]);
    KeyValues kv = CreateKeyValues("Skins");
    if (!FileToKeyValues(kv, configPath) || !KvGotoFirstSubKey(kv)) {
      CloseHandle(kv);
      SetFailState("CFG File not found: %s", configPath);
    }

    for (int k = 0; k < sizeof(g_WeaponClasses); k++) {
      if (menuWeapons[langCounter][k] != null) {
        delete menuWeapons[langCounter][k];
      }
      menuWeapons[langCounter][k] = new Menu(WeaponsMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_Display | MenuAction_DisplayItem);
      menuWeapons[langCounter][k].AddItem("0", "");
      menuWeapons[langCounter][k].AddItem("-1", "");
      menuWeapons[langCounter][k].ExitBackButton = true;
    }

    char weaponTemp[20];
    do {
      char name[64];
      char index[7];
      char classes[1024];

      KvGetSectionName(kv, name, sizeof(name));
      KvGetString(kv, "classes", classes, sizeof(classes));
      KvGetString(kv, "index", index, sizeof(index));

      for (int k = 0; k < sizeof(g_WeaponClasses); k++) {
        Format(weaponTemp, sizeof(weaponTemp), "%s;", g_WeaponClasses[k]);
        if (StrContains(classes, weaponTemp) > -1) {
          menuWeapons[langCounter][k].AddItem(index, name);
        }
      }
    } while (KvGotoNextKey(kv));

    CloseHandle(kv);

  }

  if (menuKnife != null) {
    delete menuKnife;
  }
  menuKnife = new Menu(KnifeMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_DrawItem);

  for (int i = 0; i < sizeof(g_KnifeMenuIndex); i++) {
    menuKnife.AddItem(g_KnifeMenuIndex[i], "");
  }

  if (LibraryExists("diy")) {
    menuKnife.ExitBackButton = true;
  }

}

public void ReadConfig()
{
	if (g_smGlovesGroupIndex != null) delete g_smGlovesGroupIndex;
	g_smGlovesGroupIndex = new StringMap();

	char languages[][] = {"english", "schinese"};
	for (int langCounter = 0; langCounter < MAX_LANG; langCounter++)
	{
		BuildPath(Path_SM, configPath, sizeof(configPath), "configs/gloves/gloves_%s.cfg", languages[langCounter]);

		KeyValues kv = CreateKeyValues("Gloves");
		if (!FileToKeyValues(kv, configPath) || !KvGotoFirstSubKey(kv))
		{
			CloseHandle(kv);
			SetFailState("CFG File not found: %s", configPath);
		}

		for (int k = CS_TEAM_T; k <= CS_TEAM_CT; k++)
		{
			if (menuGlovesGroup[langCounter][k] != null)
			{
				delete menuGlovesGroup[langCounter][k];
			}
			menuGlovesGroup[langCounter][k] = new Menu(GloveMainMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
			menuGlovesGroup[langCounter][k].AddItem("0", "");
			menuGlovesGroup[langCounter][k].AddItem("-1", "");
			menuGlovesGroup[langCounter][k].ExitBackButton = true;
		}

		int counter = 1;
		do
		{
			char name[64];
			char index[10];
			char group[10];
			char team[32];
			char temp[2];
			char buffer[20];

			KvGetSectionName(kv, name, sizeof(name));
			KvGetString(kv, "index", group, sizeof(group));
			g_smGlovesGroupIndex.SetValue(group, counter);
			KvGotoFirstSubKey(kv);
			for (int k = CS_TEAM_T; k <= CS_TEAM_CT; k++)
			{
				IntToString(counter, index, sizeof(index));
				menuGlovesGroup[langCounter][k].AddItem(index, name);

				if (menuGloves[langCounter][k][counter] != null)
				{
					delete menuGloves[langCounter][k][counter];
				}
				menuGloves[langCounter][k][counter] = new Menu(GloveMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
				menuGloves[langCounter][k][counter].SetTitle("%s", name);
				Format(buffer, sizeof(buffer), "%s;-1", group);
				menuGloves[langCounter][k][counter].AddItem(buffer, "");

				menuGloves[langCounter][k][counter].ExitBackButton = true;
			}
			do
			{
				KvGetSectionName(kv, name, sizeof(name));
				KvGetString(kv, "index", index, sizeof(index));
				KvGetString(kv, "team", team, sizeof(team));
				for (int k = CS_TEAM_T; k <= CS_TEAM_CT; k++)
				{
					IntToString(k, temp, sizeof(temp));

					if (StrContains(team, temp) > -1)
					{
						Format(buffer, sizeof(buffer), "%s;%s", group, index);
						menuGloves[langCounter][k][counter].AddItem(buffer, name);
					}
				}
			}
			while (KvGotoNextKey(kv));
			KvGoBack(kv);
			counter++;
		}
		while (KvGotoNextKey(kv));

		CloseHandle(kv);

	}

}

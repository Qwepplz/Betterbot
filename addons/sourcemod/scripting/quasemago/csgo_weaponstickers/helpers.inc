stock bool AddMenuItemFormat(int client, Menu menu, const char[] info, int style = ITEMDRAW_DEFAULT, const char[] format, any ...)
{
	char buffer[MAX_LENGTH_DISPLAY];
	int previousLanguage;
	if (!BB_BeginClientTranslation(client, previousLanguage))
	{
		return false;
	}
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 6);
	BB_EndClientTranslation(client, previousLanguage);
	return menu.AddItem(info, buffer, style);
}

stock bool ClientHasFlag(int client, const char[] flags)
{
	if (strlen(flags) == 0)
	{
		return true;
	}

	int iFlags = GetUserFlagBits(client);
	if (iFlags & ADMFLAG_ROOT)
	{
		return true;
	}

	AdminFlag aFlags[24];
	FlagBitsToArray(ReadFlagString(flags), aFlags, sizeof(aFlags));

	for (int i = 0; i < sizeof(aFlags); i++)
	{
		if (iFlags & FlagToBit(aFlags[i]))
		{
			return true;
		}
	}
	return false;
}

stock bool ClientWeaponHasStickers(int client, int defIndex)
{
	int index = eItems_GetWeaponNumByDefIndex(defIndex);
	if (index < 0)
	{
		return false;
	}

	for (int i = 0; i < MAX_STICKERS_SLOT; i++)
	{
		if (g_PlayerWeapon[client][index].m_sticker[i] != 0)
		{
			return true;
		}
	}
	return false;
}

stock int GetRandomSticker()
{
	int index = Math_GetRandomInt(0, g_stickerCount - 1);
	return g_Sticker[index].m_defIndex;
}

stock bool IsValidDefIndex(int defIndex)
{
	static int blackList[] =
	{
		20, 31, 37, 41, 42, 49, 57, 59, 68, 69, 70, 72, 75, 76, 78, 81, 82, 83, 84, 85
	};

	// Avoid invalid def index, grenades or knifes.
	if (defIndex <= 0 || (defIndex >= 43 && defIndex <= 48) || eItems_IsDefIndexKnife(defIndex))
	{
		return false;
	}

	// Check defIndex blacklist.
	int size = sizeof(blackList);
	for (int i = 0; i < size; i++)
	{
		if (defIndex == blackList[i])
		{
			return false;
		}
	}
	return true;
}

// Snipped from smlib.
#define SIZE_OF_INT		2147483647		// without 0
stock int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();
	if (random == 0)
	{
		random++;
	}
	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}
stock void LoadLocalizedStickerNames()
{
	char languages[][] = {"en", "zh_hans"};
	for (int language = 0; language < 2; language++)
	{
		delete g_smLocalizedStickerNames[language];
		delete g_smLocalizedStickerSetNames[language];
		delete g_smLocalizedStickerWeaponNames[language];
		g_smLocalizedStickerNames[language] = new StringMap();
		g_smLocalizedStickerSetNames[language] = new StringMap();
		g_smLocalizedStickerWeaponNames[language] = new StringMap();

		char path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/items_%s.json", languages[language]);
		JSONObject root = JSONObject.FromFile(path);
		if (root == null)
		{
			SetFailState("Could not load display names: %s", path);
		}
		JSONArray weapons = view_as<JSONArray>(root.Get("weapons"));
		JSONObject stickers = view_as<JSONObject>(root.Get("stickers"));
		JSONArray items = view_as<JSONArray>(stickers.Get("items"));
		JSONArray sets = view_as<JSONArray>(stickers.Get("categories"));
		LoadStickerNameRows(weapons, g_smLocalizedStickerWeaponNames[language], "def_index", "item_name");
		LoadStickerNameRows(items, g_smLocalizedStickerNames[language], "def_index", "item_name");
		LoadStickerNameRows(sets, g_smLocalizedStickerSetNames[language], "id", "name");
		delete weapons;
		delete items;
		delete sets;
		delete stickers;
		delete root;
	}
	if (g_smMissingStickerNames == null)
	{
		g_smMissingStickerNames = new StringMap();
	}
}

stock void LoadStickerNameRows(JSONArray rows, StringMap names, const char[] idField, const char[] nameField)
{
	char key[16], name[MAX_LENGTH_DISPLAY];
	for (int i = 0; i < rows.Length; i++)
	{
		JSONObject row = view_as<JSONObject>(rows.Get(i));
		IntToString(row.GetInt(idField), key, sizeof(key));
		if (row.GetString(nameField, name, sizeof(name)) && name[0] != '\0')
		{
			names.SetString(key, name);
		}
		delete row;
	}
}

stock bool GetStickerMappedName(int client, StringMap names[2], int id, char[] name, int maxlen)
{
	name[0] = '\0';
	char key[16];
	IntToString(id, key, sizeof(key));
	int language = BB_GetClientTextLanguage(client) == GetLanguageByCode("chi") ? 1 : 0;
	if (names[language] != null && names[language].GetString(key, name, maxlen) && name[0] != '\0')
	{
		return true;
	}
	return names[0] != null && names[0].GetString(key, name, maxlen) && name[0] != '\0';
}

stock void LogMissingStickerName(const char[] kind, int id)
{
	char key[32];
	Format(key, sizeof(key), "%s:%d", kind, id);
	int logged;
	if (g_smMissingStickerNames == null)
	{
		g_smMissingStickerNames = new StringMap();
	}
	if (!g_smMissingStickerNames.GetValue(key, logged))
	{
		g_smMissingStickerNames.SetValue(key, 1);
		LogMessage("Display name missing from local JSON: %s %d; using eItems resource", kind, id);
	}
}

stock bool GetLocalizedStickerName(int client, int stickerNum, char[] name, int maxlen)
{
	name[0] = '\0';
	if (stickerNum < 0 || stickerNum >= g_stickerCount)
	{
		return false;
	}
	int id = g_Sticker[stickerNum].m_defIndex;
	if (GetStickerMappedName(client, g_smLocalizedStickerNames, id, name, maxlen))
	{
		return true;
	}
	LogMissingStickerName("sticker", id);
	strcopy(name, maxlen, g_Sticker[stickerNum].m_displayName);
	return name[0] != '\0';
}

stock bool GetLocalizedStickerSetName(int client, int setNum, char[] name, int maxlen)
{
	name[0] = '\0';
	if (setNum < 0 || setNum >= g_stickerSetsCount)
	{
		return false;
	}
	int id = g_StickerSet[setNum].m_Id;
	if (GetStickerMappedName(client, g_smLocalizedStickerSetNames, id, name, maxlen))
	{
		return true;
	}
	LogMissingStickerName("set", id);
	strcopy(name, maxlen, g_StickerSet[setNum].m_displayName);
	return name[0] != '\0';
}

stock bool GetLocalizedStickerWeaponName(int client, int weaponDefIndex, char[] name, int maxlen)
{
	if (GetStickerMappedName(client, g_smLocalizedStickerWeaponNames, weaponDefIndex, name, maxlen))
	{
		return true;
	}
	LogMissingStickerName("weapon", weaponDefIndex);
	return eItems_GetWeaponDisplayNameByDefIndex(weaponDefIndex, name, maxlen) && name[0] != '\0';
}

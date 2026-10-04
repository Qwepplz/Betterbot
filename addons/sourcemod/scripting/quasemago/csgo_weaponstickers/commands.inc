void LoadCommands()
{
	RegConsoleCmd("sm_sticker", Command_Stickers);
	RegConsoleCmd("sm_stickers", Command_Stickers);
	RegConsoleCmd("sm_s", Command_Stickers);
	RegConsoleCmd("sm_tz", Command_Stickers);
}

public Action Command_Stickers(int client, int args)
{
	if (!g_cvarEnabled.BoolValue)
	{
		{
			char bbText[MAX_LENGTH_DISPLAY];
			BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ChatMessage", client, "Prefiks", PREFIX_SEPARATOR, "Disabled Feature");
			CPrintToChat(client, "%s", bbText);
		}
		return Plugin_Handled;
	}

	if (strlen(g_requiredFlag) > 0 && !ClientHasFlag(client, g_requiredFlag))
	{
		{
			char bbText[MAX_LENGTH_DISPLAY];
			BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ChatMessage", client, "Prefiks", PREFIX_SEPARATOR, "Need Access");
			CPrintToChat(client, "%s", bbText);
		}
		return Plugin_Handled;
	}

	if (args != 0)
	{
		char arg[MAX_LENGTH_CLASSNAME];
		GetCmdArgString(arg, sizeof(arg));

		if (strlen(arg) < 2)
		{
			{
				char bbText[MAX_LENGTH_DISPLAY];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", "ChatMessage", client, "Prefiks", PREFIX_SEPARATOR, "Min Length Search");
				CPrintToChat(client, "%s", bbText);
			}
			return Plugin_Handled;
		}

		ShowWeaponStickersMenu(client, arg);
	}
	else
	{
		ShowWeaponStickersMenu(client);
	}
	return Plugin_Handled;
}

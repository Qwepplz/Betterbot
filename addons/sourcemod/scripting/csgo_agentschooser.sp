#include	<sdktools>
#include	<sdkhooks>
#include	<cstrike>
#include	<clientprefs>
#include <bb_client_translations>

#pragma		semicolon	1
#pragma		newdecls	required

#define		HIDE_CROSSHAIR_CSGO	1<<8
#define		HIDE_RADAR_CSGO		1<<12

Handle	g_hTimer[MAXPLAYERS+1];

char CTDistinguished[][][] =
{
	{"AgentName_ctm_st6_variantn",			"models/player/custom_player/legacy/ctm_st6_variantn.mdl"},
	{"AgentName_ctm_sas_variantg",							"models/player/custom_player/legacy/ctm_sas_variantg.mdl"},
	{"AgentName_ctm_gendarmerie_variantd",					"models/player/custom_player/legacy/ctm_gendarmerie_variantd.mdl"},
	{"AgentName_ctm_st6_variante",						"models/player/custom_player/legacy/ctm_st6_variante.mdl"},
	{"AgentName_ctm_st6_variantk",							"models/player/custom_player/legacy/ctm_st6_variantk.mdl"},
	{"AgentName_ctm_fbi_variantf",									"models/player/custom_player/legacy/ctm_fbi_variantf.mdl"},
	{"AgentName_ctm_sas_variantf",							"models/player/custom_player/legacy/ctm_sas_variantf.mdl"},
	{"AgentName_ctm_swat_variantj",							"models/player/custom_player/legacy/ctm_swat_variantj.mdl"},
	{"AgentName_ctm_swat_varianth",							"models/player/custom_player/legacy/ctm_swat_varianth.mdl"},
};

char TDistinguished[][][] =
{
	{"AgentName_tm_jungle_raider_variantf",				"models/player/custom_player/legacy/tm_jungle_raider_variantf.mdl"},
	{"AgentName_tm_leet_variantj",								"models/player/custom_player/legacy/tm_leet_variantj.mdl"},
	{"AgentName_tm_phoenix_variantf",									"models/player/custom_player/legacy/tm_phoenix_variantf.mdl"},
	{"AgentName_tm_phoenix_varianth",									"models/player/custom_player/legacy/tm_phoenix_varianth.mdl"},
	{"AgentName_tm_leet_variantg",							"models/player/custom_player/legacy/tm_leet_variantg.mdl"},
	{"AgentName_tm_phoenix_varianti",							"models/player/custom_player/legacy/tm_phoenix_varianti.mdl"},
	{"AgentName_tm_balkan_variantl",						"models/player/custom_player/legacy/tm_balkan_variantl.mdl"},
};

char CTExceptional[][][] =
{
	{"AgentName_ctm_gendarmerie_variante",		"models/player/custom_player/legacy/ctm_gendarmerie_variante.mdl"},
	{"AgentName_ctm_swat_variantk",				"models/player/custom_player/legacy/ctm_swat_variantk.mdl"},
	{"AgentName_ctm_gendarmerie_varianta",		"models/player/custom_player/legacy/ctm_gendarmerie_varianta.mdl"},
	{"AgentName_ctm_fbi_variantg",									"models/player/custom_player/legacy/ctm_fbi_variantg.mdl"},
	{"AgentName_ctm_st6_variantg",								"models/player/custom_player/legacy/ctm_st6_variantg.mdl"},
	{"AgentName_ctm_swat_variantg",						"models/player/custom_player/legacy/ctm_swat_variantg.mdl"},
	{"AgentName_ctm_swat_varianti",								"models/player/custom_player/legacy/ctm_swat_varianti.mdl"},
	{"AgentName_ctm_st6_variantj",					"models/player/custom_player/legacy/ctm_st6_variantj.mdl"},
};

char TExceptional[][][] =
{
	{"AgentName_tm_jungle_raider_variantd",				"models/player/custom_player/legacy/tm_jungle_raider_variantd.mdl"},
	{"AgentName_tm_jungle_raider_variantf2",							"models/player/custom_player/legacy/tm_jungle_raider_variantf2.mdl"},
	{"AgentName_tm_balkan_varianti",										"models/player/custom_player/legacy/tm_balkan_varianti.mdl"},
	{"AgentName_tm_leet_varianth",									"models/player/custom_player/legacy/tm_leet_varianth.mdl"},
	{"AgentName_tm_phoenix_variantg",									"models/player/custom_player/legacy/tm_phoenix_variantg.mdl"},
	{"AgentName_tm_balkan_variantf",									"models/player/custom_player/legacy/tm_balkan_variantf.mdl"},
	{"AgentName_tm_professional_varj",					"models/player/custom_player/legacy/tm_professional_varj.mdl"},
	{"AgentName_tm_professional_varh",						"models/player/custom_player/legacy/tm_professional_varh.mdl"},
};

char CTSuperior[][][] =
{
	{"AgentName_ctm_gendarmerie_variantb",			"models/player/custom_player/legacy/ctm_gendarmerie_variantb.mdl"},
	{"AgentName_ctm_diver_variantc",				"models/player/custom_player/legacy/ctm_diver_variantc.mdl"},
	{"AgentName_ctm_fbi_varianth",							"models/player/custom_player/legacy/ctm_fbi_varianth.mdl"},
	{"AgentName_ctm_st6_variantm",						"models/player/custom_player/legacy/ctm_st6_variantm.mdl"},
	{"AgentName_ctm_swat_variantf",						"models/player/custom_player/legacy/ctm_swat_variantf.mdl"},
	{"AgentName_ctm_st6_variantl",					"models/player/custom_player/legacy/ctm_st6_variantl.mdl"},
};

char TSuperior[][][] =
{
	{"AgentName_tm_professional_varf5",		"models/player/custom_player/legacy/tm_professional_varf5.mdl"},
	{"AgentName_tm_jungle_raider_varianta",			"models/player/custom_player/legacy/tm_jungle_raider_varianta.mdl"},
	{"AgentName_tm_jungle_raider_variantc",				"models/player/custom_player/legacy/tm_jungle_raider_variantc.mdl"},
	{"AgentName_tm_balkan_variantj",									"models/player/custom_player/legacy/tm_balkan_variantj.mdl"},
	{"AgentName_tm_leet_varianti",							"models/player/custom_player/legacy/tm_leet_varianti.mdl"},
	{"AgentName_tm_balkan_variantg",								"models/player/custom_player/legacy/tm_balkan_variantg.mdl"},
	{"AgentName_tm_professional_vari",						"models/player/custom_player/legacy/tm_professional_vari.mdl"},
	{"AgentName_tm_professional_varg",			"models/player/custom_player/legacy/tm_professional_varg.mdl"},
	{"AgentName_tm_balkan_variantk",							"models/player/custom_player/legacy/tm_balkan_variantk.mdl"},
};

char CTMaster[][][] =
{
	{"AgentName_ctm_gendarmerie_variantc",	"models/player/custom_player/legacy/ctm_gendarmerie_variantc.mdl"},
	{"AgentName_ctm_diver_variantb",			"models/player/custom_player/legacy/ctm_diver_variantb.mdl"},
	{"AgentName_ctm_diver_varianta",		"models/player/custom_player/legacy/ctm_diver_varianta.mdl"},
	{"AgentName_ctm_st6_varianti",					"models/player/custom_player/legacy/ctm_st6_varianti.mdl"},
	{"AgentName_ctm_fbi_variantb",								"models/player/custom_player/legacy/ctm_fbi_variantb.mdl"},
	{"AgentName_ctm_swat_variante",				"models/player/custom_player/legacy/ctm_swat_variante.mdl"},
};

char TMaster[][][] =
{
	{"AgentName_tm_jungle_raider_variante",	"models/player/custom_player/legacy/tm_jungle_raider_variante.mdl"},
	{"AgentName_tm_jungle_raider_variantb2",		"models/player/custom_player/legacy/tm_jungle_raider_variantb2.mdl"},
	{"AgentName_tm_jungle_raider_variantb",		"models/player/custom_player/legacy/tm_jungle_raider_variantb.mdl"},
	{"AgentName_tm_balkan_varianth",						"models/player/custom_player/legacy/tm_balkan_varianth.mdl"},
	{"AgentName_tm_leet_variantf",					"models/player/custom_player/legacy/tm_leet_variantf.mdl"},
	{"AgentName_tm_professional_varf",			"models/player/custom_player/legacy/tm_professional_varf.mdl"},
	{"AgentName_tm_professional_varf1",		"models/player/custom_player/legacy/tm_professional_varf1.mdl"},
	{"AgentName_tm_professional_varf2",		"models/player/custom_player/legacy/tm_professional_varf2.mdl"},
	{"AgentName_tm_professional_varf3",		"models/player/custom_player/legacy/tm_professional_varf3.mdl"},
	{"AgentName_tm_professional_varf4",		"models/player/custom_player/legacy/tm_professional_varf4.mdl"},
};

#define		DATA	"1.2.0"

public Plugin myinfo =
{
	name		=	"[CS:GO] Franug Agents Chooser",
	author		=	"Franc1sco franug, Romeo, TrueProfessional, Teamkiller324",
	description	=	"Plugin giving you opportunity to change agents",
	version 	=	DATA,
	url			=	"http://steamcommunity.com/id/franug"
}

int		g_iTeam[MAXPLAYERS + 1], g_iCategory[MAXPLAYERS + 1];

char	g_ctAgent[MAXPLAYERS + 1][128], g_tAgent[MAXPLAYERS + 1][128];

Cookie	c_CTAgent, c_TAgent;

ConVar	cv_version, cv_timer, cv_noOverwritte, cv_instant, cv_autoopen, cv_PreviewDuration, cv_HidePlayers;

bool	_checkedMsg[MAXPLAYERS + 1];

public void OnPluginStart()
{
	BB_LoadClientTranslations("csgo_agentschooser.phrases");
	RegConsoleCmd("sm_agents", Command_Main);

	RegAdminCmd("sm_agents_generatemodels", Command_GenerateModelsForSkinchooser, ADMFLAG_ROOT);
	RegAdminCmd("sm_agents_generatestoremodels", Command_GenerateModelsForStore, ADMFLAG_ROOT);

	c_CTAgent = new Cookie("CTAgent_b", "", CookieAccess_Private);
	c_TAgent = new Cookie("TAgent_b", "", CookieAccess_Private);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", OnPlayerTeam, EventHookMode_Post);

	cv_version			= CreateConVar("sm_csgoagents_version",				DATA,	"Agents Chooser - Version.");
	cv_autoopen			= CreateConVar("sm_csgoagents_autoopen",			"0",	"Agent Chooser - Enable/Disable auto open menu when you connect and you didnt select a agent yet", _, true, 0.0, true, 1.0);
	cv_instant			= CreateConVar("sm_csgoagents_instantly",			"1",	"Agent Chooser - Enable/Disable apply agents skins instantly", _, true, 0.0, true, 1.0);
	cv_timer			= CreateConVar("sm_csgoagents_timer",				"0.2",	"Agent Chooser - Time on Spawn for apply agent skins", _, true, 0.0);
	cv_noOverwritte		= CreateConVar("sm_csgoagents_nooverwrittecustom",	"1",	"Agent Chooser - No apply agent model if the user already have a custom model. \n1 = No apply when custom model \n0 = Disable this feature", _, true, 0.0, true, 1.0);
	cv_PreviewDuration	= CreateConVar("sm_csgoagents_previewduration",		"1.0",	"Agent Chooser - Preview duration when choosing an agent. Disable: 0", _, true, 0.0);
	cv_HidePlayers		= CreateConVar("sm_csgoagents_hideplayers",			"2",	"Agent Chooser - Hide players when thirdperson view active.\nDisable: 0\nEnemies: 1\nAll: 2", _, true, 0.0, true, 2.0);

	cv_version.AddChangeHook(VersionCallback);
	cv_HidePlayers.AddChangeHook(OnCvarChange);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}

	AutoExecConfig(true, "csgo_agentschooser");
}

void VersionCallback(ConVar cvar, const char[] oldvalue, const char[] newvalue)
{
	cvar.SetString(DATA);
}

void OnCvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	int iNewValue = StringToInt(newValue);
	int iOldValue = StringToInt(oldValue);

	if(iNewValue > 0 && iOldValue == 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
	else if(iNewValue == 0 && iOldValue > 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
			{
				SDKUnhook(i, SDKHook_SetTransmit, Hook_SetTransmit);
			}
		}
	}
}

Action Command_GenerateModelsForSkinchooser(int client, int args)
{

	KeyValues agentPhrases = new KeyValues("Phrases");
	char phrasePath[PLATFORM_MAX_PATH], agentName[256];
	BuildPath(Path_SM, phrasePath, sizeof(phrasePath), "translations/csgo_agentschooser.phrases.txt");
	agentPhrases.ImportFromFile(phrasePath);

	KeyValues kv = new KeyValues("Models");

	kv.JumpToKey("CSGO Agents", true);
	kv.JumpToKey("Team1", true);

	for (int i = 0; i < sizeof(TDistinguished); i++)
	{
		GetAgentExportName(agentPhrases, TDistinguished[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", TDistinguished[i][1]);
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(TExceptional); i++)
	{
		GetAgentExportName(agentPhrases, TExceptional[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", TExceptional[i][1]);
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(TSuperior); i++)
	{
		GetAgentExportName(agentPhrases, TSuperior[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", TSuperior[i][1]);
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(TMaster); i++)
	{
		GetAgentExportName(agentPhrases, TMaster[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", TMaster[i][1]);
		kv.GoBack();
	}

	kv.GoBack();
	kv.JumpToKey("Team2", true);

	for (int i = 0; i < sizeof(CTDistinguished); i++)
	{
		GetAgentExportName(agentPhrases, CTDistinguished[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", CTDistinguished[i][1]);
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(CTExceptional); i++)
	{
		GetAgentExportName(agentPhrases, CTExceptional[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", CTExceptional[i][1]);
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(CTSuperior); i++)
	{
		GetAgentExportName(agentPhrases, CTSuperior[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", CTSuperior[i][1]);
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(CTMaster); i++)
	{
		GetAgentExportName(agentPhrases, CTMaster[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("path", CTMaster[i][1]);
		kv.GoBack();
	}
	kv.Rewind();
	kv.ExportToFile("addons/sourcemod/configs/sm_skinchooser_withagents.cfg");
	delete kv;
	delete agentPhrases;

	if (client == 0)
	{
		ReplyToCommand(client, "CFG file generated for models.");
	}
	else
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MsgModelsGenerated", client);
		ReplyToCommand(client, bbText);
	}

	return Plugin_Handled;

}

Action Command_GenerateModelsForStore(int client, int args)
{

	KeyValues agentPhrases = new KeyValues("Phrases");
	char phrasePath[PLATFORM_MAX_PATH], agentName[256];
	BuildPath(Path_SM, phrasePath, sizeof(phrasePath), "translations/csgo_agentschooser.phrases.txt");
	agentPhrases.ImportFromFile(phrasePath);

	char price[32] = "3000";
	KeyValues kv = new KeyValues("Store");

	kv.JumpToKey("CSGO Agents", true);
	kv.JumpToKey("Terrorist", true);

	for (int i = 0; i < sizeof(TDistinguished); i++)
	{
		GetAgentExportName(agentPhrases, TDistinguished[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", TDistinguished[i][1]);
		kv.SetString("team", "2");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(TExceptional); i++)
	{
		GetAgentExportName(agentPhrases, TExceptional[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", TExceptional[i][1]);
		kv.SetString("team", "2");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(TSuperior); i++)
	{
		GetAgentExportName(agentPhrases, TSuperior[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", TSuperior[i][1]);
		kv.SetString("team", "2");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(TMaster); i++)
	{
		GetAgentExportName(agentPhrases, TMaster[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", TMaster[i][1]);
		kv.SetString("team", "2");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}

	kv.GoBack();
	kv.JumpToKey("Counter-Terrorist", true);

	for (int i = 0; i < sizeof(CTDistinguished); i++)
	{
		GetAgentExportName(agentPhrases, CTDistinguished[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", CTDistinguished[i][1]);
		kv.SetString("team", "3");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(CTExceptional); i++)
	{
		GetAgentExportName(agentPhrases, CTExceptional[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", CTExceptional[i][1]);
		kv.SetString("team", "3");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(CTSuperior); i++)
	{
		GetAgentExportName(agentPhrases, CTSuperior[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", CTSuperior[i][1]);
		kv.SetString("team", "3");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	for (int i = 0; i < sizeof(CTMaster); i++)
	{
		GetAgentExportName(agentPhrases, CTMaster[i][0], agentName, sizeof(agentName));
		kv.JumpToKey(agentName, true);
		kv.SetString("model", CTMaster[i][1]);
		kv.SetString("team", "3");
		kv.SetString("price", price);
		kv.SetString("type", "playerskin");
		kv.GoBack();
	}
	kv.Rewind();
	kv.ExportToFile("addons/sourcemod/configs/storeitems_withagents.txt");
	delete kv;
	delete agentPhrases;

	if (client == 0)
	{
		ReplyToCommand(client, "CFG file generated for models.");
	}
	else
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MsgModelsGenerated", client);
		ReplyToCommand(client, bbText);
	}

	return Plugin_Handled;

}

public void OnClientCookiesCached(int client)
{
	c_CTAgent.Get(client, g_ctAgent[client], 128);
	c_TAgent.Get(client, g_tAgent[client], 128);
}

public void OnClientDisconnect(int client)
{
	if(!IsFakeClient(client) && AreClientCookiesCached(client))
	{
		c_TAgent.Set(client, g_tAgent[client]);
		c_CTAgent.Set(client, g_ctAgent[client]);
	}

	strcopy(g_ctAgent[client], 128, "");
	strcopy(g_tAgent[client], 128, "");
	_checkedMsg[client] = false;

	if(g_hTimer[client] != null)
	{
		KillTimer(g_hTimer[client]);
		g_hTimer[client] = null;
	}

	if(!IsClientSourceTV(client))
	{
		SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

Action Command_Main(int client, int args)
{
	Menu menu = new Menu(SelectTeam, MenuAction_Select  | MenuAction_End);

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuTeam", client);
		menu.SetTitle("%s", bbText);
	}

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuCT", client);
		menu.AddItem("", bbText);
	}
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuT", client);
		menu.AddItem("", bbText);
	}
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

int SelectTeam(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case	MenuAction_Select:
		{
			switch(selection)
			{
				case	0:	g_iTeam[client] = CS_TEAM_CT;
				case	1:	g_iTeam[client] = CS_TEAM_T;
			}

			OpenAgentsMenu(client);
		}

		case	MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void OpenAgentsMenu(int client)
{
	Menu menu = new Menu(SelectType, MenuAction_Select  | MenuAction_End);

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuType", client);
		menu.SetTitle("%s", bbText);
	}

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuDefault", client);
		menu.AddItem("", bbText);
	}
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuDistinguished", client);
		menu.AddItem("", bbText);
	}
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuExceptional", client);
		menu.AddItem("", bbText);
	}
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuSuperior", client);
		menu.AddItem("", bbText);
	}
	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuMaster", client);
		menu.AddItem("", bbText);
	}


	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int SelectType(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case	MenuAction_Select:
		{
			switch(selection)
			{
				case	0:
				{

					if(IsPlayerAlive(client))
						CS_UpdateClientModel(client);

					strcopy(g_ctAgent[client], 128, "");
					strcopy(g_tAgent[client], 128, "");

					{
						char bbText[256];
						BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MsgDefaultSelected", client);
						PrintToChat(client, bbText);
					}

					OpenAgentsMenu(client);
				}
				case	1:	DisMenu(client, 0);
				case	2:	ExMenu(client, 0);
				case	3:	SuMenu(client, 0);
				case	4:	MaMenu(client, 0);
			}
			g_iCategory[client] = selection;
		}

		case	MenuAction_Cancel, view_as<MenuAction>(MenuCancel_ExitBack):
		{
 			Command_Main(client, 0);
 		}

		case	MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void DisMenu(int client, int num)
{
	Menu menu = new Menu(AgentChoosed, MenuAction_Select  | MenuAction_End);

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuDistinguished", client);
		menu.SetTitle("%s", bbText);
	}

	if(g_iTeam[client] == CS_TEAM_CT)
	{
		for(int i = 0; i < sizeof(CTDistinguished); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", CTDistinguished[i][0], client);
				menu.AddItem(CTDistinguished[i][1], bbText, StrEqual(g_ctAgent[client], CTDistinguished[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}
	else
	{
		for(int i = 0; i < sizeof(TDistinguished); i++)	{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", TDistinguished[i][0], client);
				menu.AddItem(TDistinguished[i][1], bbText, StrEqual(g_tAgent[client], TDistinguished[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, num, MENU_TIME_FOREVER);
}

void ExMenu(int client, int num)
{
	Menu menu = new Menu(AgentChoosed, MenuAction_Select  | MenuAction_End);

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuExceptional", client);
		menu.SetTitle("%s", bbText);
	}

	if(g_iTeam[client] == CS_TEAM_CT)
	{
		for(int i = 0; i < sizeof(CTExceptional); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", CTExceptional[i][0], client);
				menu.AddItem(CTExceptional[i][1], bbText, StrEqual(g_ctAgent[client], CTExceptional[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}
	else
	{
		for(int i = 0; i < sizeof(TExceptional); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", TExceptional[i][0], client);
				menu.AddItem(TExceptional[i][1], bbText, StrEqual(g_tAgent[client], TExceptional[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, num, MENU_TIME_FOREVER);
}

void SuMenu(int client, int num)
{
	Menu menu = new Menu(AgentChoosed, MenuAction_Select  | MenuAction_End);

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuSuperior", client);
		menu.SetTitle("%s", bbText);
	}

	if(g_iTeam[client] == CS_TEAM_CT)
	{
		for(int i = 0; i < sizeof(CTSuperior); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", CTSuperior[i][0], client);
				menu.AddItem(CTSuperior[i][1], bbText, StrEqual(g_ctAgent[client], CTSuperior[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}
	else
	{
		for(int i = 0; i < sizeof(TSuperior); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", TSuperior[i][0], client);
				menu.AddItem(TSuperior[i][1], bbText, StrEqual(g_tAgent[client], TSuperior[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, num, MENU_TIME_FOREVER);
}

void MaMenu(int client, int num)
{
	Menu menu = new Menu(AgentChoosed, MenuAction_Select  | MenuAction_End);

	{
		char bbText[256];
		BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MenuMaster", client);
		menu.SetTitle("%s", bbText);
	}

	if(g_iTeam[client] == CS_TEAM_CT)
	{
		for(int i = 0; i < sizeof(CTMaster); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", CTMaster[i][0], client);
				menu.AddItem(CTMaster[i][1], bbText, StrEqual(g_ctAgent[client], CTMaster[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}
	else
	{
		for(int i = 0; i < sizeof(TMaster); i++)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", TMaster[i][0], client);
				menu.AddItem(TMaster[i][1], bbText, StrEqual(g_tAgent[client], TMaster[i][1]) ? ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT);
			}
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, num, MENU_TIME_FOREVER);
}

int AgentChoosed(Menu menu, MenuAction action, any client, int selection)
{
	switch(action)
	{
		case	MenuAction_Select:
		{
			char model[128];
			menu.GetItem(selection, model, sizeof(model));

			switch(g_iTeam[client])
			{
				case	CS_TEAM_CT:	strcopy(g_ctAgent[client], 128, model);
				case	CS_TEAM_T:	strcopy(g_tAgent[client], 128, model);
			}

			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", cv_instant.BoolValue ? "MsgAgentSelected" : "MsgAgentNextSpawn", client);
				PrintToChat(client, bbText);
			}

			switch(g_iCategory[client])
			{
				case	1:	DisMenu(client, GetMenuSelectionPosition());
				case	2:	ExMenu(client, GetMenuSelectionPosition());
				case	3:	SuMenu(client, GetMenuSelectionPosition());
				case	4:	MaMenu(client, GetMenuSelectionPosition());
			}

			if(cv_instant.BoolValue && IsPlayerAlive(client) && GetClientTeam(client) == g_iTeam[client])
			{
				if(cv_noOverwritte.BoolValue)
				{
					char dmodel[128];
					GetClientModel(client, dmodel, sizeof(dmodel));
					if(StrContains(dmodel, "models/player/custom_player/legacy/") == -1)
					{
						{
							char bbText[256];
							BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MsgCustomSkin", client);
							PrintToChat(client, bbText);
						}
						return 0;
					}
				}

				SetEntityModel(client, model);

				if(cv_PreviewDuration.BoolValue)
				{
					SetThirdPersonMode(client, true);

					if(g_hTimer[client] != null)
					{
						KillTimer(g_hTimer[client]);
						g_hTimer[client] = null;
					}

					g_hTimer[client] = CreateTimer(cv_PreviewDuration.FloatValue, Timer_SetBackMode, client, TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
		case	MenuAction_Cancel, view_as<MenuAction>(MenuCancel_ExitBack):
 		{
 			OpenAgentsMenu(client);

			if(cv_PreviewDuration.BoolValue)
			{
				SetThirdPersonMode(client, false);

				if(g_hTimer[client] != null)
				{
					KillTimer(g_hTimer[client]);
					g_hTimer[client] = null;
				}
			}
 		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	CreateTimer(cv_timer.FloatValue, Timer_ApplySkin, event.GetInt("userid"));
	return Plugin_Continue;
}

Action Timer_ApplySkin(Handle timer, int id)
{
	int client = GetClientOfUserId(id);

	if(id < 1 || !IsValidClient(client) || !IsPlayerAlive(client) || !AreClientCookiesCached(client))
		return Plugin_Continue;

	char model[255];
	switch(GetClientTeam(client))
	{
		case	CS_TEAM_CT:	strcopy(model, sizeof(model), g_ctAgent[client]);
		case	CS_TEAM_T:	strcopy(model, sizeof(model), g_tAgent[client]);
	}

	if(strlen(model) < 1)
	{
		if(cv_autoopen.BoolValue && !_checkedMsg[client])
		{
			_checkedMsg[client] = true;
			Command_Main(client, 0);
		}
		return Plugin_Continue;
	}

	if(!IsModelPrecached(model))
	{
		strcopy(g_ctAgent[client], 128, "");
		strcopy(g_tAgent[client], 128, "");
		return Plugin_Continue;
	}

	if(cv_noOverwritte.BoolValue)
	{
		char dmodel[128];
		GetClientModel(client, dmodel, sizeof(dmodel));
		if(StrContains(dmodel, "models/player/custom_player/legacy/") == -1)
		{
			{
				char bbText[256];
				BB_FormatClient(client, bbText, sizeof(bbText), "%T", "MsgCustomSkin", client);
				PrintToChat(client, bbText);
			}
			return Plugin_Continue;
		}
	}

	SetEntityModel(client, model);
	return Plugin_Continue;
}

Action Timer_SetBackMode(Handle timer, any client)
{
	SetThirdPersonMode(client, false);
	g_hTimer[client] = null;
	return Plugin_Continue;
}

void SetThirdPersonMode(int client, bool bEnable)
{
	ConVar mp_forcecamera = FindConVar("mp_forcecamera");
	if(mp_forcecamera == null)
	{
		return;
	}

	if(bEnable)
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(client, Prop_Send, "m_iFOV", 120);
		SendConVarValue(client, mp_forcecamera, "1");
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR_CSGO);
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_CROSSHAIR_CSGO);
	}
	else
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		char sValue[4];
		mp_forcecamera.GetString(sValue, sizeof(sValue));
		SendConVarValue(client, mp_forcecamera, sValue);
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDE_RADAR_CSGO);
		SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDE_CROSSHAIR_CSGO);
	}
}

public void OnClientPutInServer(int client)
{
	if(!IsClientSourceTV(client))
	{
		SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
	}
}

Action Hook_SetTransmit(int client, int agent)
{
	if(client != agent && g_hTimer[agent] != null)	{
		if(cv_HidePlayers.IntValue == 2)
		{
			return Plugin_Handled;
		}
		else if(g_iTeam[client] != g_iTeam[agent])
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");

	if(userid > 0)
		g_iTeam[GetClientOfUserId(userid)] = event.GetInt("team");
}


bool IsValidClient(int client)
{
	if(client == 0 || client == -1)
		return	false;
	if(client < 1 || client > MaxClients)
		return	false;
	if(!IsClientInGame(client))
		return	false;
	if(!IsClientConnected(client))
		return	false;
	if(IsFakeClient(client))
		return	false;
	if(IsClientReplay(client))
		return	false;
	if(IsClientSourceTV(client))
		return	false;

	return	true;
}
void GetAgentExportName(KeyValues phrases, const char[] key, char[] name, int maxlen)
{
	phrases.Rewind();
	phrases.JumpToKey(key);
	phrases.GetString("en", name, maxlen);
}

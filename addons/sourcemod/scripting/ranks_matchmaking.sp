#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <kento_rankme/rankme>
#include <zr_rank>
#include <hlstatsx_api>
#define REQUIRE_PLUGIN

#pragma newdecls required
#pragma semicolon 1

#define RANK_COUNT 18
#define RANK_NAME_COUNT 19
#define RANK_STRING_LENGTH 256
#define RANK_PREFIX_LENGTH 40
#define FLAG_BUFFER_LENGTH 10
#define MENU_INDEX_LENGTH 4

static const char g_RankPhraseKeys[RANK_NAME_COUNT][] =
{
	"Unranked",
	"Silver I",
	"Silver II",
	"Silver III",
	"Silver IV",
	"Silver Elite",
	"Silver Elite Master",
	"Gold Nova I",
	"Gold Nova II",
	"Gold Nova III",
	"Gold Nova Master",
	"Master Guardian I",
	"Master Guardian II",
	"Master Guardian Elite",
	"Distinguished Master Guardian",
	"Legendary Eagle",
	"Legendary Eagle Master",
	"Supreme First Master Class",
	"Global Elite"
};

static const char g_RankPointCvarNames[RANK_COUNT][] =
{
	"ranks_matchmaking_point_s1",
	"ranks_matchmaking_point_s2",
	"ranks_matchmaking_point_s3",
	"ranks_matchmaking_point_s4",
	"ranks_matchmaking_point_se",
	"ranks_matchmaking_point_sem",
	"ranks_matchmaking_point_g1",
	"ranks_matchmaking_point_g2",
	"ranks_matchmaking_point_g3",
	"ranks_matchmaking_point_g4",
	"ranks_matchmaking_point_mg1",
	"ranks_matchmaking_point_mg2",
	"ranks_matchmaking_point_mge",
	"ranks_matchmaking_point_dmg",
	"ranks_matchmaking_point_le",
	"ranks_matchmaking_point_lem",
	"ranks_matchmaking_point_smfc",
	"ranks_matchmaking_point_ge"
};

static const char g_RankPointDefaultValues[RANK_COUNT][] =
{
	"1000",
	"1200",
	"1400",
	"1600",
	"1800",
	"2000",
	"2200",
	"2400",
	"2600",
	"2800",
	"3000",
	"3200",
	"3400",
	"3600",
	"3800",
	"4000",
	"4200",
	"4500"
};

static const char g_RankPointDescriptions[RANK_COUNT][] =
{
	"Number of Points to reach Silver I",
	"Number of Points to reach Silver II",
	"Number of Points to reach Silver III",
	"Number of Points to reach Silver IV",
	"Number of Points to reach Silver Elite",
	"Number of Points to reach Silver Elite Master",
	"Number of Points to reach Gold Nova I",
	"Number of Points to reach Gold Nova II",
	"Number of Points to reach Gold Nova III",
	"Number of Points to reach Gold Nova IV",
	"Number of Points to reach Master Guardian I",
	"Number of Points to reach Master Guardian II",
	"Number of Points to reach Master Guardian Elite",
	"Number of Points to reach Distinguished Master Guardian",
	"Number of Points to reach Legendary Eagle",
	"Number of Points to reach Legendary Eagle Master",
	"Number of Points to reach Supreme Master First Class",
	"Number of Points to reach Global Elite"
};

int rank[MAXPLAYERS + 1] = {0, ...};
int oldrank[MAXPLAYERS + 1] = {0, ...};

ConVar g_CVAR_RanksPoints[RANK_COUNT];
ConVar g_CVAR_RankPoints_Type;
ConVar g_CVAR_RankPoints_Flag;
ConVar g_CVAR_RankPoints_Prefix;

int g_RankPoints_Type;
int g_RankPoints_Flag;
char g_RankPoints_Prefix[RANK_PREFIX_LENGTH];
int RankPoints[RANK_COUNT];

bool g_zrank;
bool g_kentorankme;
bool g_hlstatsx;

char RankStrings[RANK_NAME_COUNT][RANK_STRING_LENGTH];

public Plugin myinfo = 
{
	name = "[CS:GO] Matchmaking Ranks by Points",
	author = "Hallucinogenic Troll",
	description = "Prints the Matchmaking Ranks on scoreboard, based on points stats by a certain rank.",
	version = "1.6",
	url = "https://PTFun.net/"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_mm", Menu_Points);
	HookEvent("announce_phase_end", Event_AnnouncePhaseEnd);
	HookEventEx("cs_win_panel_match", cs_win_panel_match);
	HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
	HookEvent("round_start", Event_RoundStart);
	
	g_CVAR_RankPoints_Type = CreateConVar("ranks_matchmaking_typeofrank", "0", "Type of Rank that you want to use for this plugin (0 for Kento Rankme, 1 for GameMe, 2 for ZR Rank, 3 for HLStatsX)", _, true, 0.0, true, 3.0);
	g_CVAR_RankPoints_Prefix = CreateConVar("ranks_matchmaking_prefix", "[{purple}Fake Ranks{default}]", "Chat Prefix");
	g_CVAR_RankPoints_Flag = CreateConVar("ranks_matchmaking_flag", "", "Flag to restrict the ranks to certain players (leave it empty to enable for everyone)");
	CreateRankPointConVars();
	
	LoadTranslations("ranks_matchmaking.phrases");
	AutoExecConfig(true, "ranks_matchmaking");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("ZR_Rank_GetPoints");
	MarkNativeAsOptional("RankMe_OnPlayerLoaded");
	MarkNativeAsOptional("RankMe_GetPoints");
	return APLRes_Success;
}

void CreateRankPointConVars()
{
	for (int i = 0; i < RANK_COUNT; i++)
	{
		g_CVAR_RanksPoints[i] = CreateConVar(g_RankPointCvarNames[i], g_RankPointDefaultValues[i], g_RankPointDescriptions[i], _, true, 0.0, false);
	}
}

void LoadRankPointValues()
{
	for (int i = 0; i < RANK_COUNT; i++)
	{
		RankPoints[i] = g_CVAR_RanksPoints[i].IntValue;
	}
}

void LoadRankSettings()
{
	char flagBuffer[FLAG_BUFFER_LENGTH];
	
	g_CVAR_RankPoints_Prefix.GetString(g_RankPoints_Prefix, sizeof(g_RankPoints_Prefix));
	g_RankPoints_Type = g_CVAR_RankPoints_Type.IntValue;
	g_CVAR_RankPoints_Flag.GetString(flagBuffer, sizeof(flagBuffer));
	
	if (StrEqual(flagBuffer, "0") || strlen(flagBuffer) < 1)
		g_RankPoints_Flag = -1;
	else
		g_RankPoints_Flag = ReadFlagString(flagBuffer);
}

int GetPlayerManagerEntity()
{
	int playerManager = FindEntityByClassname(MaxClients + 1, "cs_player_manager");
	if (playerManager == -1)
		SetFailState("Unable to find cs_player_manager entity");
	
	return playerManager;
}

int GetRankFromPoints(int points)
{
	if (points < RankPoints[0])
		return 0;
	
	for (int i = 1; i < RANK_COUNT; i++)
	{
		if (points < RankPoints[i])
			return i;
	}
	
	return RANK_COUNT;
}

bool CanUseRank(int client)
{
	return g_RankPoints_Flag == -1 || CheckCommandAccess(client, "", g_RankPoints_Flag, true);
}

void RevealAllRanksToClient(int client)
{
	Handle message = StartMessageOne("ServerRankRevealAll", client);
	if (message == INVALID_HANDLE)
		PrintToChat(client, "INVALID_HANDLE");
	else
		EndMessage();
}

void RevealAllRanksToAll()
{
	Handle message = StartMessageAll("ServerRankRevealAll");
	if (message == INVALID_HANDLE)
		PrintToServer("ServerRankRevealAll = INVALID_HANDLE");
	else
		EndMessage();
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "zr_rank")) {
		g_zrank = true;
	} else if (StrEqual(name, "rankme")) {
		g_kentorankme = true;
	} else if (StrEqual(name, "hlstatsx_api")) {
		g_hlstatsx = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "zr_rank")) {
		g_zrank = false;
	} else if(StrEqual(name, "rankme")) {
		g_kentorankme = false;
	} else if (StrEqual(name, "hlstatsx_api")) {
		g_hlstatsx = false;
	}		
}

public void OnMapStart()
{
	LoadRankPointValues();
	LoadRankSettings();
	SDKHook(GetPlayerManagerEntity(), SDKHook_ThinkPost, Hook_OnThinkPost);
	GetRanksNames();
}

public void GetRanksNames()
{
	for (int i = 0; i < RANK_NAME_COUNT; i++)
	{
		FormatEx(RankStrings[i], sizeof(RankStrings[]), "%t", g_RankPhraseKeys[i]);
	}
}

public Action RankMe_OnPlayerLoaded(int client)
{
	if (g_kentorankme && g_RankPoints_Type == 0)
	{
		int points = RankMe_GetPoints(client);
		CheckRanks(client, points);
	}
	
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidClient(client)) {

		if (g_zrank && g_RankPoints_Type == 2) {
			int points = ZR_Rank_GetPoints(client);
			CheckRanks(client, points);

		} else if (g_hlstatsx && g_RankPoints_Type == 3) {

			HLStatsX_Api_GetStats("playerinfo", client, _HLStatsX_API_Response, 0);
		}
	}
}

public void _HLStatsX_API_Response(int command, int payload, int client, DataPack &datapack)
{
	if (!IsValidClient(client) || command != HLX_CALLBACK_TYPE_PLAYER_INFO) {
		return;
	}

	DataPack pack = view_as<DataPack>(CloneHandle(datapack));
	int points;
	
	points = pack.ReadCell();
	points = pack.ReadCell();

	delete datapack;
	delete pack;

	CheckRanks(client, points);
}

public Action Event_Disconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client)
		rank[client] = 0;
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int playerManager = FindEntityByClassname(MaxClients + 1, "cs_player_manager");
	if (playerManager != -1)
	{
		static int rankOffset = -1;
		if (rankOffset == -1)
			rankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
		
		SetEntDataArray(playerManager, rankOffset, rank, MaxClients + 1);
	}
	
	return Plugin_Continue;
}

public void CheckPoints(int client)
{
	switch (g_RankPoints_Type)
	{
		case 0:
		{
			if (g_kentorankme)
			{
				CheckRanks(client, RankMe_GetPoints(client));
			}
		}
		case 2:
		{
			if (g_zrank)
			{
				CheckRanks(client, ZR_Rank_GetPoints(client));
			}
		}
		case 3:
		{
			if (g_hlstatsx)
			{
				HLStatsX_Api_GetStats("playerinfo", client, _HLStatsX_API_Response, 0);
			}
		}
	}
}

public void CheckRanks(int client, int points)
{
	if (!CanUseRank(client))
	{
		rank[client] = 0;
		return;
	}
	
	rank[client] = GetRankFromPoints(points);
	if (rank[client] > oldrank[client] && rank[client] > 0)
		RankUpdate(client, oldrank[client], rank[client]);
	
	oldrank[client] = rank[client];
}

public void RankUpdate(int client, int old_rank, int new_rank)
{
	Protobuf pb = view_as<Protobuf>(StartMessageAll("ServerRankUpdate", USERMSG_RELIABLE));

	// Можно добавлять сразу несколько оружий в одно сообщение
	Protobuf rank_update = pb.AddMessage("rank_update");
	
	int stats_return[35];
	
	RankMe_GetStats(client, stats_return);
	
	rank_update.SetInt("account_id", GetSteamAccountID(client)); // Defindex оружия
	rank_update.SetInt("rank_old", old_rank); // Skin ID оружия (344 - Dragon Lore)
	rank_update.SetInt("rank_new", new_rank); // Редкость оружия. Влияет на задержку выпадения.
	rank_update.SetInt("num_wins", stats_return[23]); // Редкость оружия. Влияет на задержку выпадения.
	
	EndMessage();
}

public void Hook_OnThinkPost(int iEnt)
{
	static int rankOffset = -1;
	if (rankOffset == -1)
		rankOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompetitiveRanking");
	
	int currentRanks[MAXPLAYERS + 1] = {0, ...};
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			currentRanks[i] = rank[i];
	}
	
	SetEntDataArray(iEnt, rankOffset, currentRanks, MaxClients + 1);
}

public Action Menu_Points(int client, int args)
{
	Menu menu = new Menu(Panel_Handler);
	char buffer[RANK_STRING_LENGTH];
	char indexText[MENU_INDEX_LENGTH];
	
	Format(buffer, sizeof(buffer), "%t", "Rank Menu Title");
	menu.SetTitle(buffer);
	Format(buffer, sizeof(buffer), "%t", "Less Than X Points", RankStrings[0], RankPoints[0] - 1);
	menu.AddItem("0", buffer);
	
	for (int i = 1; i < RANK_COUNT; i++)
	{
		IntToString(i, indexText, sizeof(indexText));
		Format(buffer, sizeof(buffer), "%t", "Between X and Y", RankStrings[i], RankPoints[i - 1], RankPoints[i] - 1);
		menu.AddItem(indexText, buffer);
	}
	
	Format(buffer, sizeof(buffer), "%t", "More Than X Points", RankStrings[RANK_COUNT], RankPoints[RANK_COUNT - 1] - 1);
	menu.AddItem("18", buffer);
	menu.ExitButton = true;
	menu.Display(client, 20);
	return Plugin_Handled;
}

public int Panel_Handler(Menu menu, MenuAction action, int client, int choice)
{
	if (action == MenuAction_End)
		delete menu;
	
	return 0;
}

public void cs_win_panel_match(Handle event, const char[] eventname, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			CheckPoints(i);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (buttons & IN_SCORE && !(GetEntProp(client, Prop_Data, "m_nOldButtons") & IN_SCORE))
		RevealAllRanksToClient(client);
	
	return Plugin_Continue;
}

public Action Event_AnnouncePhaseEnd(Handle event, const char[] name, bool dontBroadcast)
{
	RevealAllRanksToAll();
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	return client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

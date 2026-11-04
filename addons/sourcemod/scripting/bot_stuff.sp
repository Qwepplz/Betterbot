#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <eItems>
#include <smlib>
#include <navmesh>
#include <dhooks>
#include <botmimic>
#include <PTaH>
#include <bot_steamids>
#include <eventptr>
#include <bot_reaction>

#undef REQUIRE_PLUGIN
#include <kento_rankme/rankme>
#define REQUIRE_PLUGIN

#define TEAMMATE_COLOR_COUNT 5
#define PROFILE_RANK_MIN 1
#define PROFILE_RANK_MAX 40
#define PROFILE_RANK_FIRST_MAX_POINTS 1000
#define PROFILE_RANK_DEFAULT_MAX_POINTS 6300
#define BOMB_GUARD_CLEAR_RADIUS 500.0
#define RETAKE_SAVE_MONEY_THRESHOLD 3000
#define RETAKE_SAVE_MIN_BOMB_DISTANCE 1200.0
#define RETAKE_SAVE_MOVE_DISTANCE 900.0
#define RETAKE_SAVE_FAR_DISTANCE 2600.0
#define RETAKE_SAVE_TARGET_STEP 600.0
#define RETAKE_SAVE_START_DELAY 5.0
#define RETAKE_SAVE_PLANT_DISTANCE 400.0
#define RETAKE_SAVE_REPATH_INTERVAL 1.0
#define RETAKE_SAVE_MOVE_INTERVAL 0.5
#define RETAKE_SAVE_TARGET_REACHED_DISTANCE 96.0
#define RETAKE_SAVE_REACH_TIMEOUT 6.0
#define RETAKE_SAVE_PROGRESS_THRESHOLD 64.0
#define BOMB_MOVE_INTERVAL 0.5
#define CT_SAVE_COMMIT_MIN_BOMB_DISTANCE 1200.0
#define CT_SAVE_COMMIT_DEFUSE_CANCEL_DISTANCE 500.0

enum Get5State
{
	Get5State_None,
	Get5State_PreVeto,
	Get5State_Veto,
	Get5State_Warmup,
	Get5State_KnifeRound,
	Get5State_WaitingForKnifeRoundDecision,
	Get5State_GoingLive,
	Get5State_Live,
	Get5State_PendingRestore,
	Get5State_PostGame,
};

native Get5State Get5_GetGameState();

enum
{
	DEFIDX_DEAGLE = 1,
	DEFIDX_DUALIES = 2,
	DEFIDX_FIVESEVEN = 3,
	DEFIDX_GLOCK = 4,
	DEFIDX_AK47 = 7,
	DEFIDX_AUG = 8,
	DEFIDX_AWP = 9,
	DEFIDX_FAMAS = 10,
	DEFIDX_G3SG1 = 11,
	DEFIDX_GALIL = 13,
	DEFIDX_M249 = 14,
	DEFIDX_M4A4 = 16,
	DEFIDX_MAC10 = 17,
	DEFIDX_P90 = 19,
	DEFIDX_MP5SD = 23,
	DEFIDX_UMP45 = 24,
	DEFIDX_XM1014 = 25,
	DEFIDX_BIZON = 26,
	DEFIDX_MAG7 = 27,
	DEFIDX_NEGEV = 28,
	DEFIDX_SAWEDOFF = 29,
	DEFIDX_TEC9 = 30,
	DEFIDX_P2000 = 32,
	DEFIDX_MP7 = 33,
	DEFIDX_MP9 = 34,
	DEFIDX_NOVA = 35,
	DEFIDX_P250 = 36,
	DEFIDX_SCAR20 = 38,
	DEFIDX_SG556 = 39,
	DEFIDX_SSG08 = 40,
	DEFIDX_M4A1S = 60,
	DEFIDX_USPS = 61,
	DEFIDX_CZ75 = 63,
	DEFIDX_REVOLVER = 64,
	DEFIDX_FLASH = 43,
	DEFIDX_HE = 44,
	DEFIDX_SMOKE = 45,
	DEFIDX_MOLOTOV = 46,
	DEFIDX_DECOY = 47,
	DEFIDX_INCENDIARY = 48
};

BotReactionState g_sBotReaction[MAXPLAYERS+1];
int g_iReactionNextCycle, g_iReactionCycleId[MAXPLAYERS+1], g_iReactionCmdNum[MAXPLAYERS+1], g_iReactionPreButtons[MAXPLAYERS+1];
bool g_bReactionReadyLogged[MAXPLAYERS+1];
char g_szCrosshairCode[MAXPLAYERS+1][35], g_szPreviousBuy[MAXPLAYERS+1][128];
bool g_bIsBombScenario, g_bIsHostageScenario, g_bFreezetimeEnd, g_bBombPlanted, g_bHalftimeSwitch, g_bIsCompetitive;
int g_iLooseBombDropper = -1;
bool g_bForceT, g_bForceCT;
bool g_bUseCZ75[MAXPLAYERS+1], g_bUseUSP[MAXPLAYERS+1], g_bUseM4A1S[MAXPLAYERS+1], g_bDontSwitch[MAXPLAYERS+1], g_bDropWeapon[MAXPLAYERS+1], g_bHasGottenDrop[MAXPLAYERS+1], g_bCheapDrop[MAXPLAYERS+1], g_bBuyingCheapDrop[MAXPLAYERS+1];
bool g_bIsProBot[MAXPLAYERS+1], g_bUncrouch[MAXPLAYERS+1], g_bSaveLocked[MAXPLAYERS+1], g_bIssuingSaveMove[MAXPLAYERS+1];
float g_fSaveConditionSince[MAXPLAYERS+1];
float g_fSaveTarget[MAXPLAYERS+1][3];
float g_fSaveNextRepathAt[MAXPLAYERS+1], g_fSaveNextMoveAt[MAXPLAYERS+1];
float g_fSaveTargetSetTime[MAXPLAYERS+1];
float g_fSaveLastProgressDist[MAXPLAYERS+1];
float g_fSaveLastProgressTime[MAXPLAYERS+1];
bool g_bSaveSettled[MAXPLAYERS+1];
float g_fBombMoveTarget[MAXPLAYERS+1][3], g_fNextBombMoveAt[MAXPLAYERS+1];
bool g_bSaveTargetValid[MAXPLAYERS+1], g_bBombMoveTargetValid[MAXPLAYERS+1];
float g_fSaveLookAtDebugTime[MAXPLAYERS+1];
bool g_bCTSaveLocked;
float g_fCTSaveConditionSince;
bool g_bSaveActiveCache[MAXPLAYERS+1];
bool g_bProfileRanksDirty;
int g_iProfileRank[MAXPLAYERS+1], g_iPlayerColor[MAXPLAYERS+1], g_iTarget[MAXPLAYERS+1], g_iPrevTarget[MAXPLAYERS+1], g_iActiveWeapon[MAXPLAYERS+1];
int g_iCurrentRound, g_iRoundsPlayed, g_iCTScore, g_iTScore;
int g_iProfileRankOffset, g_iPlayerColorOffset;
int g_iBotTargetSpotOffset, g_iBotNearbyEnemiesOffset, g_iFireWeaponOffset, g_iEnemyVisibleOffset, g_iBotProfileOffset, g_iBotSafeTimeOffset, g_iBotEnemyOffset, g_iBotLookAtSpotStateOffset, g_iBotMoraleOffset, g_iBotTaskOffset, g_iBotDispositionOffset;
float g_fBotOrigin[MAXPLAYERS+1][3], g_fTargetPos[MAXPLAYERS+1][3];
float g_fRoundStart, g_fFreezeTimeEnd;
float g_fLookAngleMaxAccel[MAXPLAYERS+1], g_fReactionTime[MAXPLAYERS+1], g_fAggression[MAXPLAYERS+1], g_fShootTimestamp[MAXPLAYERS+1], g_fCrouchTimestamp[MAXPLAYERS+1];
float g_fSniperRetreatCooldown[MAXPLAYERS+1];
float g_fBombPos[3];
float g_fBombsitePositions[16][3];
int g_iBombsiteCount;
StringMap g_smHumanTeammateColors;
ConVar g_cvGameMode;
ConVar g_cvGameType;
ConVar g_cvRecoilScale;
ConVar g_cvMaxRounds;
ConVar g_cvOTMaxRounds;
ConVar g_cvHalftime;
ConVar g_cvCanClinch;
ConVar g_cvFreezeTime;
ConVar g_cvRetakeSaveDebug;
ConVar g_cvForceSave;
ConVar g_cvAttackDebug;
ConVar g_cvReactionDebug;
Handle g_hBotMoveTo;
Handle g_hLookupBone;
Handle g_hGetBonePosition;
Handle g_hBotIsVisible;
Handle g_hBotIsHiding;
Handle g_hBotEquipBestWeapon;
Handle g_hBotSetLookAt;
Handle g_hSetCrosshairCode;
Handle g_hSwitchWeaponCall;
Handle g_hIsLineBlockedBySmoke;
Handle g_hAddMoney;
Handle g_hOnAudibleEvent;
Handle g_hTryToRetreat;
Handle g_hCheckPlayerTimer;
Handle g_hMoveToBombTimer;
Handle g_hPlayerResourceRetryTimer;
Handle g_hDropWeaponsTimer;
bool g_bPlayerResourceRetryLogged;
int g_iPlayerResourceRetryCount;
Address g_pTheBots;
CNavArea g_pCurrArea[MAXPLAYERS+1];
int g_iPlayerResourceEntity = -1;
int g_iAliveCountT, g_iAliveCountCT;
int g_iAvgMoneyT, g_iAvgMoneyCT;
float g_fLastNavUpdate[MAXPLAYERS+1][3];
float g_fWeaponPickupCooldown[MAXPLAYERS+1];
float g_fRetakeSaveDebugTime[MAXPLAYERS+1];
float g_fAttackDebugTime[MAXPLAYERS+1];
static const char g_szTopBotNames[][] =
{
    "ZywOo", "donk", "ropz", "m0NESY", "sh1ro",
    "molodoy", "flameZ", "frozen", "KSCERATO", "Spinx"
};

static char g_szBoneNames[][] =  {
	"neck_0",
	"pelvis",
	"spine_0",
	"spine_1",
	"spine_2",
	"spine_3",
	"clavicle_l",
	"clavicle_r",
	"arm_upper_L",
	"arm_lower_L",
	"hand_L",
	"arm_upper_R",
	"arm_lower_R",
	"hand_R",
	"leg_upper_L",
	"leg_lower_L",
	"ankle_L",
	"leg_upper_R",
	"leg_lower_R",
	"ankle_R"
};

enum RouteType
{
	DEFAULT_ROUTE = 0,
	FASTEST_ROUTE,
	SAFEST_ROUTE,
	RETREAT_ROUTE
}

enum PriorityType
{
	PRIORITY_LOWEST = -1,
	PRIORITY_LOW,
	PRIORITY_MEDIUM,
	PRIORITY_HIGH,
	PRIORITY_UNINTERRUPTABLE
}

enum LookAtSpotState
{
	NOT_LOOKING_AT_SPOT,			///< not currently looking at a point in space
	LOOK_TOWARDS_SPOT,				///< in the process of aiming at m_lookAtSpot
	LOOK_AT_SPOT,					///< looking at m_lookAtSpot
	NUM_LOOK_AT_SPOT_STATES
}

enum TaskType
{
	SEEK_AND_DESTROY,
	PLANT_BOMB,
	FIND_TICKING_BOMB,
	DEFUSE_BOMB,
	GUARD_TICKING_BOMB,
	GUARD_BOMB_DEFUSER,
	GUARD_LOOSE_BOMB,
	GUARD_BOMB_ZONE,
	GUARD_INITIAL_ENCOUNTER,
	ESCAPE_FROM_BOMB,
	HOLD_POSITION,
	FOLLOW,
	VIP_ESCAPE,
	GUARD_VIP_ESCAPE_ZONE,
	COLLECT_HOSTAGES,
	RESCUE_HOSTAGES,
	GUARD_HOSTAGES,
	GUARD_HOSTAGE_RESCUE_ZONE,
	MOVE_TO_LAST_KNOWN_ENEMY_POSITION,
	MOVE_TO_SNIPER_SPOT,
	SNIPING,
	ESCAPE_FROM_FLAMES,
	NUM_TASKS
}

enum DispositionType
{
	ENGAGE_AND_INVESTIGATE,								///< engage enemies on sight and investigate enemy noises
	OPPORTUNITY_FIRE,									///< engage enemies on sight, but only look towards enemy noises, dont investigate
	SELF_DEFENSE,										///< only engage if fired on, or very close to enemy
	IGNORE_ENEMIES,										///< ignore all enemies - useful for ducking around corners, running away, etc
	NUM_DISPOSITIONS
}

enum GamePhase
{
	GAMEPHASE_WARMUP_ROUND,
	GAMEPHASE_PLAYING_STANDARD,
	GAMEPHASE_PLAYING_FIRST_HALF,
	GAMEPHASE_PLAYING_SECOND_HALF,
	GAMEPHASE_HALFTIME,
	GAMEPHASE_MATCH_ENDED,
	GAMEPHASE_MAX
}

public Plugin myinfo =
{
	name = "BOT Improvement",
	author = "manico",
	description = "Improves bots and does other things.",
	version = "1.4.4",
	url = "http://steamcommunity.com/id/manico001"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("BB_FilterBotReactionButtons", Native_FilterBotReactionButtons);
	return APLRes_Success;
}

public any Native_FilterBotReactionButtons(Handle plugin, int numParams)
{
	return FilterBotReactionButtons(GetNativeCell(1), GetNativeCell(2));
}

public void OnPluginStart()
{
    g_cvGameMode = FindConVar("game_mode");
    g_cvGameType = FindConVar("game_type");
    g_cvRecoilScale = FindConVar("weapon_recoil_scale");
    g_cvMaxRounds = FindConVar("mp_maxrounds");
    g_cvOTMaxRounds = FindConVar("mp_overtime_maxrounds");
    g_cvHalftime = FindConVar("mp_halftime");
    g_cvCanClinch = FindConVar("mp_match_can_clinch");
    g_cvFreezeTime = FindConVar("mp_freezetime");
    g_cvRetakeSaveDebug = CreateConVar("bb_retake_save_debug", "0", "Log save state. 0=off, 1=save-active clients, 2=all live bots plus LookAt details.", _, true, 0.0, true, 2.0);
    g_cvForceSave = CreateConVar("bb_force_save", "0", "Force all bots into save behavior regardless of conditions.", _, true, 0.0, true, 1.0);
    g_cvAttackDebug = CreateConVar("bb_attack_debug", "0", "Log planted-bomb CT IN_ATTACK lifecycle. 0=off, 1=on.", _, true, 0.0, true, 1.0);
    g_cvReactionDebug = CreateConVar("bb_reaction_debug", "0", "Log bot reaction cycles and weapon fire. 0=off, 1=on.", _, true, 0.0, true, 1.0);

    g_bIsCompetitive = (g_cvGameMode.IntValue == 1 && g_cvGameType.IntValue == 0);

    HookEventEx("round_prestart", OnRoundPreStart);
    HookEventEx("round_start", OnRoundStart);
    HookEventEx("round_end", OnRoundEnd);
    HookEventEx("round_freeze_end", OnFreezetimeEnd);
	HookEventEx("cs_win_panel_match", OnMatchWinPanel);

    HookEventEx("player_spawn", OnPlayerSpawn);
    HookEventEx("player_death", OnPlayerDeath);
    HookEventEx("player_team", OnPlayerTeam);

    HookEventEx("weapon_zoom", OnWeaponZoom);
    HookEventEx("weapon_fire", OnWeaponFire);

    HookEventEx("bomb_planted", OnBombPlanted);
    HookEventEx("bomb_dropped", OnBombDropped);
    HookEventEx("bomb_pickup", OnBombPickup);
    HookEventEx("bomb_defused", OnBombDefused);
    HookEventEx("bomb_exploded", OnBombExploded);
    HookEventEx("bomb_beginplant", OnBombBeginPlant);
    HookEventEx("player_jump", OnPlayerJump);

    PTaH(PTaH_WeaponCanUsePre, Hook, PTaH_WeaponCanUsePreHook);

    LoadSDK();
    LoadDetours();
	InitializeMapRuntime();

    RegServerCmd("team", Command_Team);
    RegConsoleCmd("sm_validate_bots", Command_ValidateBots);
}

public Action Command_Team(int iArgs)
{
    if (iArgs < 2)
    {
        PrintToServer("Usage: team <TeamName> <t|ct>");
        return Plugin_Handled;
    }

    char szTeam[32], szSide[8], szPath[PLATFORM_MAX_PATH];
    GetCmdArg(1, szTeam, sizeof(szTeam));
    GetCmdArg(2, szSide, sizeof(szSide));

    if (strcmp(szSide, "ct", false) != 0 && strcmp(szSide, "t", false) != 0)
    {
        PrintToServer("Invalid side: %s (use t or ct)", szSide);
        return Plugin_Handled;
    }

    BuildPath(Path_SM, szPath, sizeof(szPath), "configs/bot_rosters.txt");
    if (!FileExists(szPath))
    {
        PrintToServer("Configuration file not found: %s", szPath);
        return Plugin_Handled;
    }

    KeyValues hKv = new KeyValues("Teams");
    if (!hKv.ImportFromFile(szPath))
    {
        delete hKv;
        PrintToServer("Unable to parse configuration file: %s", szPath);
        return Plugin_Handled;
    }

    if (!hKv.JumpToKey(szTeam))
    {
        delete hKv;
        PrintToServer("Unknown team: %s", szTeam);
        return Plugin_Handled;
    }

    char szPlayers[256], szLogo[64];
    hKv.GetString("players", szPlayers, sizeof(szPlayers));
    hKv.GetString("logo", szLogo, sizeof(szLogo), "");
    delete hKv;

    ServerCommand("bot_kick %s all", szSide);

    char szPlayerNames[5][MAX_NAME_LENGTH];
    int iCount = ExplodeString(szPlayers, ",", szPlayerNames, sizeof(szPlayerNames), sizeof(szPlayerNames[]));

    for (int i = 0; i < iCount; i++)
    {
        TrimString(szPlayerNames[i]);
        if (szPlayerNames[i][0] != '\0')
        {
            ServerCommand("bot_add_%s \"%s\"", szSide, szPlayerNames[i]);
        }
    }

    int iLogoSlot = strcmp(szSide, "ct", false) == 0 ? 1 : 2;
    ServerCommand("mp_teamlogo_%d \"%s\"", iLogoSlot, szLogo);

    return Plugin_Handled;
}

public Action Command_ValidateBots(int iClient, int iArgs)
{
    char szPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szPath, sizeof(szPath), "configs/bot_rosters.txt");
    if (!FileExists(szPath))
    {
        PrintToServer("[Validate] Configuration file not found: %s", szPath);
        return Plugin_Handled;
    }

    KeyValues hKv = new KeyValues("Teams");
    if (!hKv.ImportFromFile(szPath))
    {
        delete hKv;
        PrintToServer("[Validate] Unable to parse configuration file: %s", szPath);
        return Plugin_Handled;
    }

    if (!hKv.GotoFirstSubKey())
    {
        delete hKv;
        PrintToServer("[Validate] No teams found.");
        return Plugin_Handled;
    }

    int iMissing, iTotal;
    do
    {
        char szTeamName[64], szPlayers[256];
        hKv.GetSectionName(szTeamName, sizeof(szTeamName));
        hKv.GetString("players", szPlayers, sizeof(szPlayers));

        char szPlayerNames[5][MAX_NAME_LENGTH];
        int iCount = ExplodeString(szPlayers, ",", szPlayerNames, sizeof(szPlayerNames), sizeof(szPlayerNames[]));

        for (int i = 0; i < iCount; i++)
        {
            TrimString(szPlayerNames[i]);
            if (szPlayerNames[i][0] == '\0')
                continue;

            iTotal++;
            if (!IsNameInBotDatabase(szPlayerNames[i]))
            {
                PrintToServer("[Validate] MISSING: \"%s\" (team: %s) not found in bot_info.json", szPlayerNames[i], szTeamName);
                iMissing++;
            }
        }
    }
    while (hKv.GotoNextKey());

    delete hKv;
    PrintToServer("[Validate] Done. %d/%d players checked, %d missing from bot_info.json.", iTotal, iTotal, iMissing);
    return Plugin_Handled;
}

public void OnMapStart()
{
	ResetAllBotReactions("map_start");
	InitializeMapRuntime();
}

void HookPlayerResourceEntity()
{
	if (g_hPlayerResourceRetryTimer != null)
	{
		delete g_hPlayerResourceRetryTimer;
		g_hPlayerResourceRetryTimer = null;
	}

	if (g_iPlayerResourceEntity != -1 && IsValidEntity(g_iPlayerResourceEntity))
		SDKUnhook(g_iPlayerResourceEntity, SDKHook_ThinkPost, OnThinkPost);

	g_iPlayerResourceEntity = GetPlayerResourceEntity();
	if (g_iPlayerResourceEntity == -1 || !IsValidEntity(g_iPlayerResourceEntity))
	{
		g_iPlayerResourceEntity = -1;
		g_iPlayerResourceRetryCount = 0;
		g_bPlayerResourceRetryLogged = false;
		g_hPlayerResourceRetryTimer = CreateTimer(1.0, Timer_TryHookPlayerResourceEntity, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	SDKHook(g_iPlayerResourceEntity, SDKHook_ThinkPost, OnThinkPost);
	OnThinkPost(g_iPlayerResourceEntity);
}

void InitializeMapRuntime()
{
    g_iProfileRankOffset = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");
    if (g_iProfileRankOffset == -1)
    {
        LogError("Failed to find m_nPersonaDataPublicLevel offset");
    }

    g_iPlayerColorOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompTeammateColor");
    if (g_iPlayerColorOffset == -1)
    {
        LogError("Failed to find m_iCompTeammateColor offset");
    }

    g_bIsBombScenario = false;
    g_iBombsiteCount = 0;
    int iBombsiteEnt = -1;
    while ((iBombsiteEnt = FindEntityByClassname(iBombsiteEnt, "func_bomb_target")) != -1)
    {
        g_bIsBombScenario = true;
        if (g_iBombsiteCount < 16)
        {
            GetEntPropVector(iBombsiteEnt, Prop_Send, "m_vecOrigin", g_fBombsitePositions[g_iBombsiteCount]);
            g_iBombsiteCount++;
        }
    }
    g_bIsHostageScenario = (FindEntityByClassname(-1, "func_hostage_rescue") != -1);

	if (g_hCheckPlayerTimer == null)
		g_hCheckPlayerTimer = CreateTimer(1.0, Timer_CheckPlayer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	if (g_hMoveToBombTimer == null)
		g_hMoveToBombTimer = CreateTimer(0.1, Timer_MoveToBomb, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	HookPlayerResourceEntity();

	ResetTeammateColorAssignments();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			InitializeClientProfileData(i);
			SetPlayerTeammateColor(i);
		}
	}
}

public Action Timer_TryHookPlayerResourceEntity(Handle hTimer, any data)
{
	int iPlayerResource = GetPlayerResourceEntity();
	if (iPlayerResource == -1 || !IsValidEntity(iPlayerResource))
	{
		g_iPlayerResourceRetryCount++;
		if (!g_bPlayerResourceRetryLogged && g_iPlayerResourceRetryCount >= 30)
		{
			LogError("Failed to find player resource entity after %d retries", g_iPlayerResourceRetryCount);
			g_bPlayerResourceRetryLogged = true;
		}
		return Plugin_Continue;
	}

	g_iPlayerResourceEntity = iPlayerResource;
	g_iPlayerResourceRetryCount = 0;
	g_bPlayerResourceRetryLogged = false;
	SDKHook(g_iPlayerResourceEntity, SDKHook_ThinkPost, OnThinkPost);
	OnThinkPost(g_iPlayerResourceEntity);
	g_hPlayerResourceRetryTimer = null;
	return Plugin_Stop;
}

public Action Timer_CheckPlayer(Handle hTimer, any data)
{
	int iHalfRound = g_cvMaxRounds.IntValue / 2;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsFakeClient(i) || !IsPlayerAlive(i))
			continue;

		if (IsItMyChance(2.0))
			FakeClientCommand(i, "+lookatweapon;-lookatweapon");

		if (g_bDropWeapon[i])
			continue;

		bool bInBuyZone = view_as<bool>(GetEntProp(i, Prop_Send, "m_bInBuyZone"));
		if (!bInBuyZone)
			continue;

		int iAccount = GetEntProp(i, Prop_Send, "m_iAccount");
		int iTeam = GetClientTeam(i);
		int iArmor = GetEntProp(i, Prop_Data, "m_ArmorValue");
		bool bHasDefuser = view_as<bool>(GetEntProp(i, Prop_Send, "m_bHasDefuser"));
		bool bHasHelmet = view_as<bool>(GetEntProp(i, Prop_Send, "m_bHasHelmet"));
		int iPrimary = GetPlayerWeaponSlot(i, CS_SLOT_PRIMARY);

		char szCurrentWeapon[64];
		GetClientWeapon(i, szCurrentWeapon, sizeof(szCurrentWeapon));
		bool bDefaultPistol = IsDefaultPistol(szCurrentWeapon);

		bool bHasPrimary = IsValidEntity(iPrimary);
		int iFriendsWithPrimary = GetFriendsWithPrimary(i);

		if (g_iCurrentRound == 0 || g_iCurrentRound == iHalfRound)
		{
			int iRand = Math_GetRandomInt(1, 100);

			if (iRand <= 2)
				FakeClientCommand(i, "buy %s", (iTeam == CS_TEAM_CT) ? "elite" : "vest");
			else if (iRand <= 32)
				FakeClientCommand(i, "buy %s", (iTeam == CS_TEAM_CT) ? "defuser" : "p250");
			else if (iRand <= 92)
				FakeClientCommand(i, "buy vest");

			continue;
		}

		if (bHasPrimary || (iFriendsWithPrimary >= 1 && !bDefaultPistol))
		{
			if (iArmor < 50 || !bHasHelmet)
				FakeClientCommand(i, "buy vesthelm");

			if (iTeam == CS_TEAM_CT && !bHasDefuser)
				FakeClientCommand(i, "buy defuser");

			float fFreezeWindow = g_cvFreezeTime.FloatValue - 2.0;
			if (fFreezeWindow < 0.0)
				fFreezeWindow = 0.0;

			if (GetGameTime() - g_fRoundStart > fFreezeWindow && !g_bFreezetimeEnd)
			{
				FakeClientCommand(i, "buy smokegrenade");
				FakeClientCommand(i, "buy flashbang");
				FakeClientCommand(i, "buy flashbang");

				switch (Math_GetRandomInt(1, 3))
				{
					case 1: FakeClientCommand(i, "buy hegrenade");
					case 2: FakeClientCommand(i, "buy molotov");
					case 3:
					{
						FakeClientCommand(i, "buy hegrenade");
						FakeClientCommand(i, "buy molotov");
					}
				}
			}
		}
		else if (!IsTeamForcing(iTeam) && ((((iTeam == CS_TEAM_T) ? g_iAvgMoneyT : g_iAvgMoneyCT) < 3000 && iAccount > 2000 && !bHasPrimary) || iFriendsWithPrimary >= 1))
		{
			BuyEcoPistolAndGear(i, bDefaultPistol, iTeam, bHasDefuser);
		}
	}

	return Plugin_Continue;
}

bool ThrottleBombMove(int iClient, const float fTarget[3])
{
	float fNow = GetGameTime();
	if (g_bBombMoveTargetValid[iClient]
		&& fNow < g_fNextBombMoveAt[iClient]
		&& GetVectorDistance(g_fBombMoveTarget[iClient], fTarget) < 16.0)
		return false;

	Array_Copy(fTarget, g_fBombMoveTarget[iClient], 3);
	g_bBombMoveTargetValid[iClient] = true;
	g_fNextBombMoveAt[iClient] = fNow + BOMB_MOVE_INTERVAL;
	return true;
}

void ResetClientBombMove(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return;

	g_bBombMoveTargetValid[iClient] = false;
	g_fNextBombMoveAt[iClient] = 0.0;
	g_fBombMoveTarget[iClient][0] = 0.0;
	g_fBombMoveTarget[iClient][1] = 0.0;
	g_fBombMoveTarget[iClient][2] = 0.0;
}

void BuyEcoPistolAndGear(int iClient, bool bDefaultPistol, int iTeam, bool bHasDefuser)
{
	if (bDefaultPistol)
	{
		switch (Math_GetRandomInt(1, 5))
		{
			case 1: FakeClientCommand(iClient, "buy p250");
			case 2: FakeClientCommand(iClient, "buy tec9");
			case 3: FakeClientCommand(iClient, "buy deagle");
		}
	}
	else
	{
		switch (Math_GetRandomInt(1, 20))
		{
			case 1: FakeClientCommand(iClient, "buy vest");
			case 10: FakeClientCommand(iClient, "buy %s", (iTeam == CS_TEAM_CT && !bHasDefuser) ? "defuser" : "vest");
		}
	}
}

public Action Timer_MoveToBomb(Handle hTimer, any data)
{
	if (!g_bBombPlanted)
		return Plugin_Continue;

	float fC4Pos[3];
	Array_Copy(g_fBombPos, fC4Pos, 3);

	bool bLastManStanding = (g_iAliveCountT == 0 && g_iAliveCountCT == 1);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsFakeClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		if (!bLastManStanding && (g_bDontSwitch[i] || GetEntData(i, g_iBotNearbyEnemiesOffset) != 0))
			continue;

		float fDistanceToBomb = GetVectorDistance(g_fBotOrigin[i], fC4Pos);

		if (GetTask(i) == ESCAPE_FROM_BOMB || GetTask(i) == ESCAPE_FROM_FLAMES)
			continue;

		if (ShouldSaveInsteadOfRetake(i))
			continue;

		int iGuardThreat;
		float fGuardThreatPos[3];
		float fGuardC4Pos[3];
		if (GetBombGuardThreat(i, iGuardThreat, fGuardThreatPos, fGuardC4Pos))
		{
			ClearBombGuardThreat(i, iGuardThreat, fGuardThreatPos);
			continue;
		}

		bool bShouldMoveToBomb = (bLastManStanding && fDistanceToBomb > 30.0) || fDistanceToBomb > 2000.0;

		if (bShouldMoveToBomb && ThrottleBombMove(i, fC4Pos))
		{
			SwitchWeapon(i, GetPlayerWeaponSlot(i, CS_SLOT_KNIFE));
			BotMoveTo(i, fC4Pos, FASTEST_ROUTE);
		}
	}

	return Plugin_Continue;
}

public Action Timer_DropWeapons(Handle hTimer, any data)
{
    if (GetGameTime() - g_fRoundStart <= 3.0)
        return Plugin_Continue;

    if (g_bFreezetimeEnd)
    {
        g_hDropWeaponsTimer = null;
        return Plugin_Stop;
    }

    ArrayList aBotsT = new ArrayList(2);
    ArrayList aBotsCT = new ArrayList(2);

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsValidClient(iClient) || !IsFakeClient(iClient) || !IsPlayerAlive(iClient) || g_bDropWeapon[iClient])
            continue;

        int iPrimaryWeapon = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
        if (!IsValidEntity(iPrimaryWeapon))
            continue;

        int iDefIndex = GetEntProp(iPrimaryWeapon, Prop_Send, "m_iItemDefinitionIndex");
        CSWeaponID eWeaponID = CS_ItemDefIndexToID(iDefIndex);
        if (eWeaponID == CSWeapon_NONE)
            continue;

        int iMoney = GetEntProp(iClient, Prop_Send, "m_iAccount");
        int iWeaponPrice = CS_GetWeaponPrice(iClient, eWeaponID);
        if (iMoney < iWeaponPrice)
            continue;

        GetEntityClassname(iPrimaryWeapon, g_szPreviousBuy[iClient], sizeof(g_szPreviousBuy[]));
        ReplaceString(g_szPreviousBuy[iClient], sizeof(g_szPreviousBuy[]), "weapon_", "");

        int iEntry[2];
        iEntry[0] = iClient;
        iEntry[1] = iMoney;

        int iTeam = GetClientTeam(iClient);
        if (iTeam == CS_TEAM_T)
            aBotsT.PushArray(iEntry);
        else if (iTeam == CS_TEAM_CT)
            aBotsCT.PushArray(iEntry);
    }

    SortADTArrayCustom(aBotsT, Sort_BotMoneyDesc);
    SortADTArrayCustom(aBotsCT, Sort_BotMoneyDesc);

    bool bNeedDropT, bNeedDropCT;
    AssignDrops(aBotsT, aBotsCT, bNeedDropT, bNeedDropCT);

    if (bNeedDropT)
        CollectCheapDroppers(aBotsT, CS_TEAM_T);

    if (bNeedDropCT)
        CollectCheapDroppers(aBotsCT, CS_TEAM_CT);

    if ((bNeedDropT && aBotsT.Length > 0) || (bNeedDropCT && aBotsCT.Length > 0))
        AssignDrops(aBotsT, aBotsCT, bNeedDropT, bNeedDropCT);

    delete aBotsT;
    delete aBotsCT;

    return Plugin_Continue;
}

void AssignDrops(ArrayList aBotsT, ArrayList aBotsCT, bool &bNeedDropT, bool &bNeedDropCT)
{
    bNeedDropT = false;
    bNeedDropCT = false;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || g_bHasGottenDrop[iClient])
            continue;

        if (!GetEntProp(iClient, Prop_Send, "m_bInBuyZone"))
            continue;

        int iPrimaryWeapon = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
        int iMoney = GetEntProp(iClient, Prop_Send, "m_iAccount");
        int iTeam = GetClientTeam(iClient);

        if (IsValidEntity(iPrimaryWeapon) || iMoney >= 3000)
            continue;

        ArrayList aTeamBots = (iTeam == CS_TEAM_T) ? aBotsT : aBotsCT;

        if (aTeamBots.Length == 0)
        {
            if (iTeam == CS_TEAM_T)
                bNeedDropT = true;
            else
                bNeedDropCT = true;

            continue;
        }

        int iEntry[2];
        aTeamBots.GetArray(0, iEntry, 2);
        int iDropBot = iEntry[0];
        aTeamBots.Erase(0);

        float fEyePos[3];
        GetClientEyePosition(iClient, fEyePos);
        BotSetLookAt(iDropBot, "Use entity", fEyePos, PRIORITY_HIGH, 3.0, false, 5.0, false);

        g_bDropWeapon[iDropBot] = true;
        g_bHasGottenDrop[iClient] = true;
    }
}

void CollectCheapDroppers(ArrayList aTeamBots, int iTeam)
{
    aTeamBots.Clear();

    CSWeaponID eRifle = (iTeam == CS_TEAM_T) ? CSWeapon_GALILAR : CSWeapon_FAMAS;
    CSWeaponID eSMG = (iTeam == CS_TEAM_T) ? CSWeapon_MAC10 : CSWeapon_MP9;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsValidClient(iClient) || !IsFakeClient(iClient) || !IsPlayerAlive(iClient) || g_bDropWeapon[iClient])
            continue;

        if (GetClientTeam(iClient) != iTeam)
            continue;

        int iPrimaryWeapon = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
        if (!IsValidEntity(iPrimaryWeapon))
            continue;

        int iMoney = GetEntProp(iClient, Prop_Send, "m_iAccount");

        if (iMoney >= CS_GetWeaponPrice(iClient, eRifle))
            strcopy(g_szPreviousBuy[iClient], sizeof(g_szPreviousBuy[]), (iTeam == CS_TEAM_T) ? "galilar" : "famas");
        else if (iMoney >= CS_GetWeaponPrice(iClient, eSMG))
            strcopy(g_szPreviousBuy[iClient], sizeof(g_szPreviousBuy[]), (iTeam == CS_TEAM_T) ? "mac10" : "mp9");
        else
            continue;

        g_bCheapDrop[iClient] = true;

        int iEntry[2];
        iEntry[0] = iClient;
        iEntry[1] = iMoney;
        aTeamBots.PushArray(iEntry);
    }

    SortADTArrayCustom(aTeamBots, Sort_BotMoneyDesc);
}

void SafeDeleteTimer(Handle &hTimer)
{
	delete hTimer;
	hTimer = null;
}

public void OnMapEnd()
{
	ResetAllBotReactions("map_end");
	SafeDeleteTimer(g_hCheckPlayerTimer);
	SafeDeleteTimer(g_hMoveToBombTimer);
	SafeDeleteTimer(g_hPlayerResourceRetryTimer);
	SafeDeleteTimer(g_hDropWeaponsTimer);

	g_iPlayerResourceRetryCount = 0;
	g_bPlayerResourceRetryLogged = false;

	if (g_iPlayerResourceEntity != -1 && IsValidEntity(g_iPlayerResourceEntity))
		SDKUnhook(g_iPlayerResourceEntity, SDKHook_ThinkPost, OnThinkPost);

	g_iPlayerResourceEntity = -1;
}

public void OnPluginEnd()
{
	ResetAllBotReactions("plugin_end");
}

public void OnClientPutInServer(int iClient)
{
	ResetBotReaction(iClient, "put_in_server");
	if (!IsValidClient(iClient))
		return;

	InitializeClientProfileData(iClient);
	CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPostAdminCheck(int iClient)
{
	InitializeClientProfileData(iClient);
	CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

void InitializeClientProfileData(int iClient)
{
    SetProfileRank(iClient, PROFILE_RANK_MIN);

    if (!IsFakeClient(iClient))
        return;

    g_bIsProBot[iClient] = IsBotInDatabase(iClient);

    if (g_bIsProBot[iClient])
    {
        GetBotCrosshairCode(iClient, g_szCrosshairCode[iClient], sizeof(g_szCrosshairCode[]));

        char szBotName[MAX_NAME_LENGTH];
        GetClientName(iClient, szBotName, sizeof(szBotName));

        if (IsTopBot(szBotName))
        {
            g_fLookAngleMaxAccel[iClient] = 100000.0;
            g_fReactionTime[iClient] = 0.0;
            g_fAggression[iClient] = 1.0;
        }
        else
        {
            g_fLookAngleMaxAccel[iClient] = Math_GetRandomFloat(4000.0, 7000.0);
            g_fReactionTime[iClient] = Math_GetRandomFloat(0.165, 0.325);
            g_fAggression[iClient] = Math_GetRandomFloat(0.0, 1.0);
        }
    }

    g_bUseUSP[iClient] = IsItMyChance(75.0);
    g_bUseM4A1S[iClient] = IsItMyChance(50.0);
    g_bUseCZ75[iClient] = IsItMyChance(20.0);
    g_pCurrArea[iClient] = INVALID_NAV_AREA;
}

void SetProfileRank(int iClient, int iRank)
{
	if (g_iProfileRank[iClient] == iRank)
		return;

	g_iProfileRank[iClient] = iRank;
	g_bProfileRanksDirty = true;
}

int GetProfileRankMaxPoints()
{
	ConVar hMaxRankPoints = FindConVar("ranks_matchmaking_point_ge");
	if (hMaxRankPoints == null || hMaxRankPoints.IntValue <= PROFILE_RANK_FIRST_MAX_POINTS)
		return PROFILE_RANK_DEFAULT_MAX_POINTS;

	return hMaxRankPoints.IntValue;
}

int GetProfileRankFromRankMePoints(int iPoints)
{
	if (iPoints <= PROFILE_RANK_FIRST_MAX_POINTS)
		return PROFILE_RANK_MIN;

	int iMaxPoints = GetProfileRankMaxPoints();
	if (iPoints >= iMaxPoints)
		return PROFILE_RANK_MAX;

	return 2 + ((iPoints - PROFILE_RANK_FIRST_MAX_POINTS - 1) * (PROFILE_RANK_MAX - 2)) / (iMaxPoints - PROFILE_RANK_FIRST_MAX_POINTS - 1);
}

void RefreshProfileRankFromRankMe(int iClient)
{
	if (!IsValidClient(iClient) || !LibraryExists("rankme"))
		return;

	SetProfileRank(iClient, GetProfileRankFromRankMePoints(RankMe_GetPoints(iClient)));
}

public Action RankMe_OnPlayerLoaded(int iClient)
{
	RefreshProfileRankFromRankMe(iClient);
	return Plugin_Continue;
}

public Action OnMatchWinPanel(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	RequestFrame(Frame_RefreshProfileRanksFromRankMe);
	return Plugin_Continue;
}

void Frame_RefreshProfileRanksFromRankMe(any iData)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		RefreshProfileRankFromRankMe(iClient);
}

public void OnRoundPreStart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
    g_iCurrentRound = GameRules_GetProp("m_totalRoundsPlayed");

    g_bForceT = false;
    g_bForceCT = false;

    int iOvertimePlaying = GameRules_GetProp("m_nOvertimePlaying");
    GamePhase eGamePhase = view_as<GamePhase>(GameRules_GetProp("m_gamePhase"));

    if (g_cvHalftime.BoolValue && eGamePhase == GAMEPHASE_PLAYING_FIRST_HALF)
    {
        int iRoundsBeforeHalftime = iOvertimePlaying ? g_cvMaxRounds.IntValue + ((2 * iOvertimePlaying - 1) * (g_cvOTMaxRounds.IntValue / 2)) : (g_cvMaxRounds.IntValue / 2);
        if (iRoundsBeforeHalftime > 0 && g_iRoundsPlayed == iRoundsBeforeHalftime - 1)
        {
            g_bHalftimeSwitch = true;
            g_bForceT = true;
            g_bForceCT = true;
        }
    }

    if (eGamePhase != GAMEPHASE_PLAYING_FIRST_HALF)
    {
        int iNumWinsToClinch = GetNumWinsToClinch();
        if (g_iCTScore == iNumWinsToClinch - 1)
            g_bForceT = true;
        if (g_iTScore == iNumWinsToClinch - 1)
            g_bForceCT = true;
    }

    if (g_cvMaxRounds.IntValue > 0)
    {
        int iLastRound = (g_cvMaxRounds.IntValue - 1) + (iOvertimePlaying * g_cvOTMaxRounds.IntValue);
        if (g_iCurrentRound == iLastRound)
        {
            g_bForceT = true;
            g_bForceCT = true;
        }
    }
}

public void OnRoundStart(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	ResetAllBotReactions("round_start");

	g_bFreezetimeEnd = false;
	g_bBombPlanted = false;
	g_fRoundStart = GetGameTime();
	g_bHalftimeSwitch = false;

	g_bCTSaveLocked = false;
	g_fCTSaveConditionSince = 0.0;
	g_iLooseBombDropper = -1;

	UpdateAliveTeamCounts();

	bool bIsScenario = g_bIsBombScenario || g_bIsHostageScenario;
	int iTeam = g_bIsBombScenario ? CS_TEAM_CT : CS_TEAM_T;
	int iOppositeTeam = g_bIsBombScenario ? CS_TEAM_T : CS_TEAM_CT;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsFakeClient(i))
			continue;

		g_bSaveLocked[i] = false;
		g_fSaveConditionSince[i] = 0.0;
		ResetClientSaveTarget(i);
		ResetClientBombMove(i);
		g_fSaveLookAtDebugTime[i] = 0.0;

		if (!IsPlayerAlive(i))
			continue;

		g_bUncrouch[i] = IsItMyChance(50.0);
		g_bDontSwitch[i] = false;
		g_bDropWeapon[i] = false;
		g_bHasGottenDrop[i] = false;
		g_bCheapDrop[i] = false;

		g_iTarget[i] = -1;
		g_iPrevTarget[i] = -1;

		g_fShootTimestamp[i] = 0.0;
		g_fAttackDebugTime[i] = 0.0;
		g_fCrouchTimestamp[i] = 0.0;
		g_fSniperRetreatCooldown[i] = 0.0;

		if (bIsScenario)
		{
			int iClientTeam = GetClientTeam(i);

			if (iClientTeam == iTeam)
				SetEntData(i, g_iBotMoraleOffset, -3);
			else if (g_bHalftimeSwitch && iClientTeam == iOppositeTeam)
				SetEntData(i, g_iBotMoraleOffset, 1);
		}
	}

	g_iAvgMoneyT = GetTeamAverageMoney(CS_TEAM_T);
	g_iAvgMoneyCT = GetTeamAverageMoney(CS_TEAM_CT);

	if (g_bIsCompetitive && g_hDropWeaponsTimer == null)
		g_hDropWeaponsTimer = CreateTimer(0.5, Timer_DropWeapons, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnRoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	ResetAllBotReactions("round_end");

	if (g_hDropWeaponsTimer != null)
	{
		delete g_hDropWeaponsTimer;
		g_hDropWeaponsTimer = null;
	}

	g_bCTSaveLocked = false;
	g_fCTSaveConditionSince = 0.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		g_bSaveLocked[i] = false;
		g_fSaveConditionSince[i] = 0.0;
		ResetClientSaveTarget(i);
		ResetClientBombMove(i);

	}

    int iEnt = -1;

    while ((iEnt = FindEntityByClassname(iEnt, "cs_team_manager")) != -1)
    {
        int iTeamNum = GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
        int iScore = GetEntProp(iEnt, Prop_Send, "m_scoreTotal");

        if (iTeamNum == CS_TEAM_CT)
            g_iCTScore = iScore;
        else if (iTeamNum == CS_TEAM_T)
            g_iTScore = iScore;
    }

    g_iRoundsPlayed = GameRules_GetProp("m_totalRoundsPlayed");
}

public void OnFreezetimeEnd(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	g_bFreezetimeEnd = true;
	g_fFreezeTimeEnd = GetGameTime();
	UpdateAliveTeamCounts();

}

public void OnBombPlanted(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	g_bBombPlanted = true;

	int iPlantedC4 = FindEntityByClassname(-1, "planted_c4");
	if (IsValidEntity(iPlantedC4))
		GetEntPropVector(iPlantedC4, Prop_Send, "m_vecOrigin", g_fBombPos);

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetClientBombMove(i);
	}
}

public void OnBombDefused(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	OnBombResolved();
}

public void OnBombDropped(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	g_iLooseBombDropper = GetClientOfUserId(eEvent.GetInt("userid"));
}

public void OnBombPickup(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	g_iLooseBombDropper = -1;
}

public void OnBombExploded(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	OnBombResolved();
}

void OnBombResolved()
{
	g_bBombPlanted = false;

}

public void OnPlayerJump(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == iClient || !IsValidClient(i) || !IsPlayerAlive(i) || !IsFakeClient(i) || GetClientTeam(i) == GetClientTeam(iClient))
			continue;

		BotOnAudibleEvent(i, eEvent, iClient, 1100.0, PRIORITY_LOW, false);
	}
}

public void OnBombBeginPlant(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iPlanter = GetClientOfUserId(eEvent.GetInt("userid"));
	if (!IsValidClient(iPlanter) || !IsPlayerAlive(iPlanter))
		return;

	float fPlanterPos[3];
	GetClientAbsOrigin(iPlanter, fPlanterPos);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == iPlanter || !IsValidClient(i) || !IsPlayerAlive(i) || !IsFakeClient(i) || GetClientTeam(i) == GetClientTeam(iPlanter))
			continue;

		BotOnAudibleEvent(i, eEvent, iPlanter, 1100.0, PRIORITY_HIGH, true, false, fPlanterPos);
	}
}

public void OnPlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (iClient > 0 && iClient <= MaxClients)
		ResetBotReaction(iClient, "death");
	if (IsValidClient(iClient))
	{
		g_bSaveLocked[iClient] = false;
		g_fSaveConditionSince[iClient] = 0.0;
		g_fSaveLookAtDebugTime[iClient] = 0.0;
		g_fAttackDebugTime[iClient] = 0.0;
		ResetClientSaveTarget(iClient);
		ResetClientBombMove(iClient);

	}

	UpdateAliveTeamCounts();
}

void UpdateAliveTeamCounts()
{
	g_iAliveCountT = 0;
	g_iAliveCountCT = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsPlayerAlive(i))
			continue;

		int iTeam = GetClientTeam(i);
		if (iTeam == CS_TEAM_T)
			g_iAliveCountT++;
		else if (iTeam == CS_TEAM_CT)
			g_iAliveCountCT++;
	}

	g_iAvgMoneyT = GetTeamAverageMoney(CS_TEAM_T);
	g_iAvgMoneyCT = GetTeamAverageMoney(CS_TEAM_CT);
}

public void OnWeaponZoom(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));

	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return;

	g_fShootTimestamp[iClient] = GetGameTime();
}

public void OnWeaponFire(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return;

	char szWeaponName[32];
	eEvent.GetString("weapon", szWeaponName, sizeof(szWeaponName));

	if (g_cvReactionDebug.BoolValue && !IsClientReplay(iClient))
	{
		int iDefIndex = GetReactionEventWeaponDefIndex(szWeaponName);
		LogReactionEvent(iClient, "weapon_fire", "event", iDefIndex, -1, szWeaponName);
		if (g_sBotReaction[iClient].ownerSerial == GetClientSerial(iClient)
			&& BotReactionWaiting(g_sBotReaction[iClient], GetGameTime()) && IsReactionFirearm(iDefIndex))
			LogReactionEvent(iClient, "early_fire", "weapon_fire", iDefIndex, -1, szWeaponName);
	}

	if (IsValidClient(g_iTarget[iClient]) && StrEqual(szWeaponName, "weapon_deagle"))
	{
		float fTargetLoc[3];
		GetClientAbsOrigin(g_iTarget[iClient], fTargetLoc);

		float fRangeToEnemy = GetVectorDistance(g_fBotOrigin[iClient], fTargetLoc);
		if (fRangeToEnemy > 100.0)
			SetEntDataFloat(iClient, g_iFireWeaponOffset, GetEntDataFloat(iClient, g_iFireWeaponOffset) + Math_GetRandomFloat(0.20, 0.40));
	}

	if ((StrEqual(szWeaponName, "weapon_awp") || StrEqual(szWeaponName, "weapon_ssg08")) && IsItMyChance(50.0))
		RequestFrame(BeginQuickSwitch, GetClientUserId(iClient));

	if (StrEqual(szWeaponName, "weapon_flashbang"))
		CreateTimer(1.1, Timer_AvoidSelfFlash, GetClientUserId(iClient));
}

public void OnThinkPost(int iEnt)
{
	if (g_iProfileRankOffset != -1)
	{
		SetEntDataArray(iEnt, g_iProfileRankOffset, g_iProfileRank, MAXPLAYERS + 1, 4, g_bProfileRanksDirty);
		g_bProfileRanksDirty = false;
	}

	if (g_iPlayerColorOffset != -1)
		SetEntDataArray(iEnt, g_iPlayerColorOffset, g_iPlayerColor, MAXPLAYERS + 1);

	Address pEntAddr = GetEntityAddress(iEnt);
	for (int i = 1; i <= MaxClients; i++)
		if (IsValidClient(i) && IsFakeClient(i))
			SetCrosshairCode(pEntAddr, i, g_szCrosshairCode[i]);
}

public Action Timer_RefreshPlayerResourceData(Handle hTimer, int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (!IsValidClient(iClient))
		return Plugin_Stop;

	SetPlayerTeammateColor(iClient);

	if (g_iPlayerResourceEntity != -1 && IsValidEntity(g_iPlayerResourceEntity))
		OnThinkPost(g_iPlayerResourceEntity);

	return Plugin_Stop;
}

public Action CS_OnBuyCommand(int iClient, const char[] szWeapon)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return Plugin_Continue;

	int iTeam = GetClientTeam(iClient);
	int iAccount = GetEntProp(iClient, Prop_Send, "m_iAccount");
	int iOwnAvgMoney = (iTeam == CS_TEAM_T) ? g_iAvgMoneyT : g_iAvgMoneyCT;
	bool bIsResetRound = IsResetRound();
	bool bIsEco = !bIsResetRound && !IsTeamForcing(iTeam) && iOwnAvgMoney < 3000;
	bool bIsFullSave = bIsEco && iAccount < 2000;

	if (strcmp(szWeapon, "vest") == 0 || strcmp(szWeapon, "vesthelm") == 0 || strcmp(szWeapon, "defuser") == 0)
		return bIsFullSave ? Plugin_Handled : Plugin_Continue;

	if (strcmp(szWeapon, "decoy") == 0)
		return Plugin_Handled;

	if (strcmp(szWeapon, "revolver") == 0)
		return Plugin_Handled;

	if (strcmp(szWeapon, "molotov") == 0 || strcmp(szWeapon, "incgrenade") == 0 ||
	    strcmp(szWeapon, "flashbang") == 0 || strcmp(szWeapon, "hegrenade") == 0 || strcmp(szWeapon, "smokegrenade") == 0)
		return bIsEco ? Plugin_Handled : Plugin_Continue;

	if (strcmp(szWeapon, "p250") == 0 || strcmp(szWeapon, "tec9") == 0 || strcmp(szWeapon, "fiveseven") == 0 ||
	    strcmp(szWeapon, "deagle") == 0 || strcmp(szWeapon, "elite") == 0 || strcmp(szWeapon, "cz75a") == 0 ||
	    strcmp(szWeapon, "hkp2000") == 0 || strcmp(szWeapon, "usp_silencer") == 0 || strcmp(szWeapon, "glock") == 0)
		return bIsFullSave ? Plugin_Handled : Plugin_Continue;

	if (bIsEco && !g_bBuyingCheapDrop[iClient])
		return Plugin_Handled;

	if (IsBlockedOddPrimaryBuy(szWeapon))
	{
		if (IsValidEntity(GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY)))
			return Plugin_Handled;

		CSWeaponID eRifle = (iTeam == CS_TEAM_T) ? CSWeapon_GALILAR : CSWeapon_FAMAS;
		CSWeaponID eSMG = (iTeam == CS_TEAM_T) ? CSWeapon_MAC10 : CSWeapon_MP9;

		if (iAccount >= CS_GetWeaponPrice(iClient, eRifle))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, (iTeam == CS_TEAM_T) ? "weapon_galilar" : "weapon_famas", true);
			return Plugin_Changed;
		}

		if (iAccount >= CS_GetWeaponPrice(iClient, eSMG))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, (iTeam == CS_TEAM_T) ? "weapon_mac10" : "weapon_mp9", true);
			return Plugin_Changed;
		}

		return Plugin_Handled;
	}

	if (!g_bBuyingCheapDrop[iClient] && GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY) != -1 &&
	    (strcmp(szWeapon, "galilar") == 0 || strcmp(szWeapon, "famas") == 0 || strcmp(szWeapon, "ak47") == 0 ||
	     strcmp(szWeapon, "m4a1") == 0 || strcmp(szWeapon, "ssg08") == 0 || strcmp(szWeapon, "aug") == 0 ||
	     strcmp(szWeapon, "sg556") == 0 || strcmp(szWeapon, "awp") == 0 || strcmp(szWeapon, "scar20") == 0 ||
	     strcmp(szWeapon, "g3sg1") == 0 || strcmp(szWeapon, "nova") == 0 || strcmp(szWeapon, "xm1014") == 0 ||
	     strcmp(szWeapon, "mag7") == 0 || strcmp(szWeapon, "m249") == 0 || strcmp(szWeapon, "negev") == 0 ||
	     strcmp(szWeapon, "mac10") == 0 || strcmp(szWeapon, "mp9") == 0 || strcmp(szWeapon, "mp7") == 0 ||
	     strcmp(szWeapon, "ump45") == 0 || strcmp(szWeapon, "p90") == 0 || strcmp(szWeapon, "bizon") == 0))
		return Plugin_Handled;

	int iEnemyAvgMoney = (iTeam == CS_TEAM_CT) ? g_iAvgMoneyT : g_iAvgMoneyCT;

	if ((strcmp(szWeapon, "ak47") == 0 || strcmp(szWeapon, "m4a1") == 0) && !g_bForceT && !g_bForceCT && !IsValidEntity(GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY)) && IsItMyChance(40.0) && iEnemyAvgMoney < 2500)
	{
		if (iTeam == CS_TEAM_T && iAccount >= CS_GetWeaponPrice(iClient, CSWeapon_MAC10))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, "weapon_mac10", true);
			return Plugin_Changed;
		}
		else if (iTeam == CS_TEAM_CT && iAccount >= CS_GetWeaponPrice(iClient, CSWeapon_MP9))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, "weapon_mp9", true);
			return Plugin_Changed;
		}
	}

	if (strcmp(szWeapon, "m4a1") == 0)
	{
		if (g_bUseM4A1S[iClient] && iAccount >= CS_GetWeaponPrice(iClient, CSWeapon_M4A1_SILENCER))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, "weapon_m4a1_silencer", true);
			return Plugin_Changed;
		}

	}

	if (strcmp(szWeapon, "mac10") == 0 && IsItMyChance(40.0) && iAccount >= CS_GetWeaponPrice(iClient, CSWeapon_GALILAR))
	{
		ReplaceWeapon(iClient, CS_SLOT_PRIMARY, "weapon_galilar", true);
		return Plugin_Changed;
	}

	if (strcmp(szWeapon, "mp9") == 0)
	{
		if (IsItMyChance(40.0) && iAccount >= CS_GetWeaponPrice(iClient, CSWeapon_FAMAS))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, "weapon_famas", true);
			return Plugin_Changed;
		}

		if (IsItMyChance(15.0) && iAccount >= CS_GetWeaponPrice(iClient, CSWeapon_UMP45))
		{
			ReplaceWeapon(iClient, CS_SLOT_PRIMARY, "weapon_ump45", true);
			return Plugin_Changed;
		}
	}

	if ((strcmp(szWeapon, "tec9") == 0 || strcmp(szWeapon, "fiveseven") == 0) && g_bUseCZ75[iClient])
	{
		ReplaceWeapon(iClient, CS_SLOT_SECONDARY, "weapon_cz75a", true);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action PTaH_WeaponCanUsePreHook(int iClient, int iWeapon, bool &bPickup)
{
	if (!IsValidClient(iClient) || !IsFakeClient(iClient) || !IsPlayerAlive(iClient) || !IsValidEntity(iWeapon))
		return Plugin_Continue;

	if (!ShouldSaveInsteadOfRetake(iClient) || GetClientTeam(iClient) != CS_TEAM_T)
		return Plugin_Continue;

	char szClassname[64];
	GetEntityClassname(iWeapon, szClassname, sizeof(szClassname));
	if (!StrEqual(szClassname, "weapon_c4"))
		return Plugin_Continue;

	bPickup = false;
	return Plugin_Changed;
}

public MRESReturn CCSBot_GetPartPosition(DHookReturn hReturn, DHookParam hParams)
{
	if (hParams == null)
		return MRES_Ignored;

	Address pPlayer = hParams.GetAddress(1);
	if (pPlayer == Address_Null)
		return MRES_Ignored;

	int iPlayer = GetClientFromAddress(pPlayer);
	int iPart = hParams.Get(2);

	if (!IsValidClient(iPlayer))
		return MRES_Ignored;

	int iBone = LookupBone(iPlayer, "head_0");
	if (iBone < 0 || iPart != 2)
		return MRES_Ignored;

	float fHeadPos[3], fUnused[3];
	GetBonePosition(iPlayer, iBone, fHeadPos, fUnused);
	fHeadPos[2] += 4.0;

	hReturn.SetVector(fHeadPos);
	return MRES_Override;
}

public MRESReturn CCSBot_CanSeeLooseBomb(int iClient, DHookReturn hReturn)
{
	if (!g_bBombPlanted && g_bIsBombScenario && g_bFreezetimeEnd)
	{
		if (ShouldSaveInsteadOfRetake(iClient))
		{
			hReturn.Value = false;
			return MRES_Supercede;
		}

		if (GetClientTeam(iClient) == CS_TEAM_CT)
		{
			int iLooseC4 = FindLooseBomb();
			if (iLooseC4 != -1)
			{
				if (IsLooseBombDroppedByLiveT())
					return MRES_Ignored;

				if (GetTask(iClient) != GUARD_LOOSE_BOMB && GetEntData(iClient, g_iBotNearbyEnemiesOffset) == 0)
				{
					float fC4Pos[3];
					GetEntPropVector(iLooseC4, Prop_Send, "m_vecOrigin", fC4Pos);

					if (GetVectorDistance(g_fBotOrigin[iClient], fC4Pos) > 500.0)
						BotMoveTo(iClient, fC4Pos, FASTEST_ROUTE);
				}

				hReturn.Value = true;
				return MRES_Override;
			}
		}
	}

	return MRES_Ignored;
}

public MRESReturn CCSBot_MoveTo(int iClient, DHookParam hParams)
{
	if (!IsValidClient(iClient) || !IsFakeClient(iClient) || hParams == null)
		return MRES_Ignored;

	if (g_bIssuingSaveMove[iClient])
		return MRES_Ignored;

	if (!g_bSaveActiveCache[iClient])
		return MRES_Ignored;

	if (IsSavingBotUnderDirectThreat(iClient))
		return MRES_Ignored;

	return MRES_Supercede;
}

public MRESReturn CCSBot_SetLookAtLinux(DHookParam hParams)
{
	if (hParams == null)
		return MRES_Ignored;
	return CCSBot_SetLookAt(GetClientFromAddress(view_as<Address>(hParams.Get(8))), hParams);
}

public MRESReturn CCSBot_SetLookAt(int iClient, DHookParam hParams)
{
	if (!IsValidClient(iClient) || !IsFakeClient(iClient) || hParams == null)
		return MRES_Ignored;

	bool bPosNull = hParams.IsNull(2);

	char szDesc[64];
	DHookGetParamString(hParams, 1, szDesc, sizeof(szDesc));
	int iTeam = GetClientTeam(iClient);
	bool bSaveActive = g_bSaveActiveCache[iClient];

	if (strcmp(szDesc, "Defuse bomb") == 0 || strcmp(szDesc, "Use entity") == 0 || strcmp(szDesc, "Open door") == 0 || strcmp(szDesc, "Hostage") == 0 || strcmp(szDesc, "Avoid Flashbang") == 0)
	{
		if (bSaveActive && iTeam == CS_TEAM_CT && strcmp(szDesc, "Defuse bomb") == 0)
		{
			LogCTCommittedSaveObjectiveBlock(iClient, "SetLookAt", "Defuse bomb");
			LogSaveLookAtDebug(iClient, szDesc, true);
			return MRES_Supercede;
		}

		return MRES_Ignored;
	}
	else if (strcmp(szDesc, "Blind") == 0 || strcmp(szDesc, "Face outward") == 0)
	{
		if (bSaveActive)
		{
			LogSaveLookAtDebug(iClient, szDesc, false);
			return MRES_Ignored;
		}

		return MRES_Supercede;
	}
	else if (strcmp(szDesc, "Breakable") == 0 || strcmp(szDesc, "Plant bomb on floor") == 0)
	{
		if (bSaveActive && iTeam == CS_TEAM_T && strcmp(szDesc, "Plant bomb on floor") == 0)
		{
			LogSaveLookAtDebug(iClient, szDesc, true);
			return MRES_Supercede;
		}

		if (bSaveActive)
		{
			LogSaveLookAtDebug(iClient, szDesc, false);
			return MRES_Ignored;
		}

		g_bDontSwitch[iClient] = true;
		CreateTimer(5.0, Timer_EnableSwitch, GetClientUserId(iClient));
		return strcmp(szDesc, "Plant bomb on floor") == 0 ? MRES_Supercede : MRES_Ignored;
	}
	else if (bSaveActive && strcmp(szDesc, "Noise") != 0 && strcmp(szDesc, "Nearby enemy gunfire") != 0)
	{
		LogSaveLookAtDebug(iClient, szDesc, false);
		return MRES_Ignored;
	}
	else if (strcmp(szDesc, "Last Enemy Position") == 0)
	{
		if (bPosNull)
			return MRES_Ignored;
		return MRES_Ignored;
	}
	else if (strcmp(szDesc, "Noise") == 0)
	{
		if (bPosNull)
			return MRES_Ignored;

		bool bIsWalking = !!GetEntProp(iClient, Prop_Send, "m_bIsWalking");
		float fClientEyes[3], fNoisePos[3];
		GetClientEyePosition(iClient, fClientEyes);
		DHookGetParamVector(hParams, 2, fNoisePos);

		if (IsItMyChance(15.0) && IsPointVisible(fClientEyes, fNoisePos) && LineGoesThroughSmoke(fClientEyes, fNoisePos) && !bIsWalking)
			DHookSetParam(hParams, 7, true);
		if (BotMimic_IsPlayerMimicing(iClient))
		{

			BotMimic_StopPlayerMimic(iClient);
		}

		if (eItems_GetWeaponSlotByWeapon(g_iActiveWeapon[iClient]) == CS_SLOT_KNIFE && GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES)
			BotEquipBestWeapon(iClient, true);

		g_bDontSwitch[iClient] = true;
		CreateTimer(5.0, Timer_EnableSwitch, GetClientUserId(iClient));

		fNoisePos[2] += 25.0;
		DHookSetParamVector(hParams, 2, fNoisePos);
		return MRES_ChangedHandled;
	}
	else if (strcmp(szDesc, "Nearby enemy gunfire") == 0)
	{
		if (bPosNull)
			return MRES_Ignored;

		float fPos[3];
		DHookGetParamVector(hParams, 2, fPos);
		fPos[2] += 25.0;
		DHookSetParamVector(hParams, 2, fPos);
		return MRES_ChangedHandled;
	}
	else
	{
		if (bPosNull)
			return MRES_Ignored;

		float fPos[3];
		DHookGetParamVector(hParams, 2, fPos);
		fPos[2] += 25.0;
		DHookSetParamVector(hParams, 2, fPos);
		return MRES_ChangedHandled;
	}
}

public MRESReturn CCSBot_PickNewAimSpot(int iClient, DHookParam hParams)
{
	if (!IsValidClient(iClient) || !IsFakeClient(iClient))
		return MRES_Ignored;

    if (!g_bIsProBot[iClient])
        return MRES_Ignored;

    SelectBestTargetPos(iClient, g_fTargetPos[iClient]);

    if (!IsValidClient(g_iTarget[iClient]) || !IsPlayerAlive(g_iTarget[iClient]) || g_fTargetPos[iClient][2] == 0.0)
        return MRES_Ignored;

    SetEntDataVector(iClient, g_iBotTargetSpotOffset, g_fTargetPos[iClient]);
    return MRES_Ignored;
}

int GetReactionActiveWeaponDefIndex(int iClient)
{
	if (!IsValidClient(iClient))
		return -1;

	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients || !IsValidEntity(iWeapon) || !HasEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"))
		return -1;

	return GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
}

bool IsReactionFirearm(int iDefIndex)
{
	if (iDefIndex < 0 || eItems_GetWeaponNumByDefIndex(iDefIndex) == -1)
		return false;

	int iSlot = eItems_GetWeaponSlotByDefIndex(iDefIndex);
	return iSlot == CS_SLOT_PRIMARY || iSlot == CS_SLOT_SECONDARY;
}

int GetReactionEventWeaponDefIndex(const char[] szWeaponName)
{
	if (szWeaponName[0] == '\0')
		return -1;

	char szClassName[48];
	if (StrContains(szWeaponName, "weapon_", false) == 0)
		strcopy(szClassName, sizeof(szClassName), szWeaponName);
	else
		Format(szClassName, sizeof(szClassName), "weapon_%s", szWeaponName);

	return eItems_GetWeaponDefIndexByClassName(szClassName);
}

void LogReactionEvent(int iClient, const char[] szEvent, const char[] szReason, int iDefIndex, int iButtons, const char[] szWeaponName = "-")
{
	if (g_cvReactionDebug == null || !g_cvReactionDebug.BoolValue)
		return;

	int iOwnerSerial = g_sBotReaction[iClient].ownerSerial;
	if (iOwnerSerial == 0 && IsValidClient(iClient))
		iOwnerSerial = GetClientSerial(iClient);

	LogMessage("[BotReaction] event=%s reason=%s cycle_id=%d client=%d owner_serial=%d enemy_serial=%d cmdnum=%d firstSeenAt=%.6f delay=%.6f readyAt=%.6f now=%.6f defindex=%d pre_buttons=%d buttons=%d weapon=%s",
		szEvent, szReason, g_iReactionCycleId[iClient], iClient, iOwnerSerial, g_sBotReaction[iClient].enemySerial,
		g_iReactionCmdNum[iClient], g_sBotReaction[iClient].firstSeenAt,
		g_sBotReaction[iClient].readyAt - g_sBotReaction[iClient].firstSeenAt, g_sBotReaction[iClient].readyAt,
		GetGameTime(), iDefIndex, g_iReactionPreButtons[iClient], iButtons, szWeaponName);
}

void ResetBotReaction(int iClient, const char[] szReason)
{
	if (!g_sBotReaction[iClient].active)
		return;

	if (g_cvReactionDebug != null && g_cvReactionDebug.BoolValue)
		LogReactionEvent(iClient, "cancel", szReason, GetReactionActiveWeaponDefIndex(iClient), -1);

	BotReactionReset(g_sBotReaction[iClient]);
	g_iReactionCycleId[iClient] = 0;
	g_bReactionReadyLogged[iClient] = false;
}

void ResetAllBotReactions(const char[] szReason)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		ResetBotReaction(iClient, szReason);
}

public void OnPlayerRunCmdPre(int iClient, int iButtons, int iImpulse, const float fVel[3], const float fAngles[3], int iWeapon, int iSubtype, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	if (iClient >= 1 && iClient <= MaxClients && g_cvReactionDebug.BoolValue)
	{
		g_iReactionCmdNum[iClient] = iCmdNum;
		g_iReactionPreButtons[iClient] = iButtons;
	}
	UpdateBotReaction(iClient);
}

void UpdateBotReaction(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return;

	if (!IsValidClient(iClient) || !IsFakeClient(iClient) || IsClientReplay(iClient) || !IsPlayerAlive(iClient))
	{
		ResetBotReaction(iClient, "invalid_owner");
		return;
	}

	int iTeam = GetClientTeam(iClient);
	if ((iTeam != CS_TEAM_T && iTeam != CS_TEAM_CT) || GameRules_GetProp("m_bFreezePeriod") != 0)
	{
		ResetBotReaction(iClient, "freeze_or_team");
		return;
	}

	int iEnemy = BotGetEnemy(iClient);
	if (!IsValidClient(iEnemy) || IsClientReplay(iEnemy) || !IsPlayerAlive(iEnemy))
	{
		ResetBotReaction(iClient, "invalid_enemy");
		return;
	}

	int iEnemyTeam = GetClientTeam(iEnemy);
	if ((iEnemyTeam != CS_TEAM_T && iEnemyTeam != CS_TEAM_CT) || iEnemyTeam == iTeam)
	{
		ResetBotReaction(iClient, "enemy_team");
		return;
	}
	if (GetEntData(iClient, g_iEnemyVisibleOffset, 1) == 0)
	{
		ResetBotReaction(iClient, "not_visible");
		return;
	}

	int iOwnerSerial = GetClientSerial(iClient);
	int iEnemySerial = GetClientSerial(iEnemy);
	if (BotReactionNeedsStart(g_sBotReaction[iClient], iOwnerSerial, iEnemySerial))
	{
		ResetBotReaction(iClient, "identity_change");
		if (g_iReactionNextCycle == 2147483647)
			g_iReactionNextCycle = 0;
		g_iReactionCycleId[iClient] = ++g_iReactionNextCycle;
		BotReactionBegin(g_sBotReaction[iClient], iOwnerSerial, iEnemySerial, GetGameTime(), BotReactionSampleDelay());
		if (g_cvReactionDebug.BoolValue)
			LogReactionEvent(iClient, "begin", "visible", GetReactionActiveWeaponDefIndex(iClient), g_iReactionPreButtons[iClient]);
	}
}

int FilterBotReactionButtons(int iClient, int iButtons)
{
	if (iClient < 1 || iClient > MaxClients || !IsValidClient(iClient) || !IsFakeClient(iClient) || IsClientReplay(iClient) || !IsPlayerAlive(iClient))
		return iButtons;

	if (g_sBotReaction[iClient].ownerSerial != GetClientSerial(iClient) || !BotReactionWaiting(g_sBotReaction[iClient], GetGameTime()))
		return iButtons;

	int iDefIndex = GetReactionActiveWeaponDefIndex(iClient);
	return BotReactionFilterMask(iButtons, true, IsReactionFirearm(iDefIndex), iDefIndex == DEFIDX_REVOLVER);
}

public MRESReturn BotReaction_ContinueBurst(int iWeapon)
{
	if (iWeapon <= MaxClients || !IsValidEntity(iWeapon) || !HasEntProp(iWeapon, Prop_Send, "m_hOwnerEntity"))
		return MRES_Ignored;

	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (!IsValidClient(iClient) || GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") != iWeapon)
		return MRES_Ignored;

	return FilterBotReactionButtons(iClient, IN_ATTACK) == 0 ? MRES_Supercede : MRES_Ignored;
}

public void OnPlayerRunCmdPost(int iClient, int iButtons, int iImpulse, const float fVel[3], const float fAngles[3], int iWeapon, int iSubtype, int iCmdNum, int iTickCount, int iSeed, const int iMouse[2])
{
	if (!g_cvReactionDebug.BoolValue || iClient < 1 || iClient > MaxClients || !IsValidClient(iClient)
		|| !g_sBotReaction[iClient].active || g_sBotReaction[iClient].ownerSerial != GetClientSerial(iClient))
		return;

	bool bWaiting = BotReactionWaiting(g_sBotReaction[iClient], GetGameTime());
	int iDefIndex = GetReactionActiveWeaponDefIndex(iClient);
	if (!bWaiting && !g_bReactionReadyLogged[iClient])
	{
		g_bReactionReadyLogged[iClient] = true;
		LogReactionEvent(iClient, "ready", "deadline", iDefIndex, iButtons);
	}
	else if (bWaiting && BotReactionFilterMask(iButtons, true, IsReactionFirearm(iDefIndex), iDefIndex == DEFIDX_REVOLVER) != iButtons)
	{
		LogReactionEvent(iClient, "early_button", "post", iDefIndex, iButtons);
	}
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapon, int &iSubtype, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2])
{
	Action eResult = ProcessBotPlayerRunCmd(iClient, iButtons, iImpulse, fVel, fAngles, iWeapon, iSubtype, iCmdNum, iTickCount, iSeed, iMouse);
	int iFilteredButtons = FilterBotReactionButtons(iClient, iButtons);
	if (iFilteredButtons != iButtons)
	{
		iButtons = iFilteredButtons;
		if (eResult == Plugin_Continue)
			return Plugin_Changed;
	}
	return eResult;
}

Action ProcessBotPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAngles[3], int &iWeapon, int &iSubtype, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2])
{
	#pragma unused iMouse
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return Plugin_Continue;

	if (!g_bFreezetimeEnd && g_bDropWeapon[iClient] && view_as<LookAtSpotState>(GetEntData(iClient, g_iBotLookAtSpotStateOffset)) == LOOK_AT_SPOT)
	{
		if (g_bCheapDrop[iClient])
		{
			g_bBuyingCheapDrop[iClient] = true;
			FakeClientCommand(iClient, "buy %s", g_szPreviousBuy[iClient]);
			g_bBuyingCheapDrop[iClient] = false;
			RequestFrame(TossCheapDrop, GetClientUserId(iClient));
			g_bCheapDrop[iClient] = false;
		}
		else
		{
			CS_DropWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY), true);
			FakeClientCommand(iClient, "buy %s", g_szPreviousBuy[iClient]);
		}
		g_bDropWeapon[iClient] = false;
	}

	GetClientAbsOrigin(iClient, g_fBotOrigin[iClient]);

	if (IsBotMimicBlockedPhase())
	{
		if (BotMimic_IsPlayerMimicing(iClient))
			BotMimic_StopPlayerMimic(iClient);

	}

	g_iActiveWeapon[iClient] = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(g_iActiveWeapon[iClient]))
		return Plugin_Continue;

	if (!g_bFreezetimeEnd)
		return Plugin_Continue;

	float fNow = GetGameTime();
	int iDefIndex = GetEntProp(g_iActiveWeapon[iClient], Prop_Send, "m_iItemDefinitionIndex");
	BlockBotDisruptiveAltFire(iDefIndex, iButtons);

	float fPlayerVelocity[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fPlayerVelocity);
	fPlayerVelocity[2] = 0.0;
	float fSpeed = GetVectorLength(fPlayerVelocity);

	float fMoveDelta = GetVectorDistance(g_fBotOrigin[iClient], g_fLastNavUpdate[iClient]);
	if (fMoveDelta > 32.0 || g_pCurrArea[iClient] == INVALID_NAV_AREA)
	{
		g_pCurrArea[iClient] = NavMesh_GetNearestArea(g_fBotOrigin[iClient]);
		Array_Copy(g_fBotOrigin[iClient], g_fLastNavUpdate[iClient], 3);
	}

	bool bShouldSaveInsteadOfRetake = ShouldSaveInsteadOfRetake(iClient);
	g_bSaveActiveCache[iClient] = bShouldSaveInsteadOfRetake;

	int iButtonsIn = iButtons;
	bool bCTPlantedBombAttackRebuild = g_bBombPlanted && GetClientTeam(iClient) == CS_TEAM_CT && g_bIsProBot[iClient];
	bool bWeaponCoveredByPluginFire = bCTPlantedBombAttackRebuild && IsPluginFireCoveredWeapon(iDefIndex);
	DispositionType eDispositionBeforeSave = GetDisposition(iClient);
	if (bWeaponCoveredByPluginFire)
		iButtons &= ~IN_ATTACK;
	int iButtonsAfterPreClear = iButtons;

	if (bShouldSaveInsteadOfRetake)
	{
		ProcessRetakeSaveBehavior(iClient, iButtons);
		if (g_bSaveSettled[iClient])
		{
			iButtons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP);
			fVel[0] = 0.0;
			fVel[1] = 0.0;
			fVel[2] = 0.0;
		}
		LogRetakeSaveDebug(iClient);
		return Plugin_Changed;
	}
	else
	{
		LogRetakeSaveDebug(iClient);
	}

	int iPrimary = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
	if (IsValidEntity(iPrimary) && fNow >= g_fSniperRetreatCooldown[iClient])
	{
		int iPrimaryDef = GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex");
		if (iPrimaryDef == DEFIDX_AWP || iPrimaryDef == DEFIDX_SSG08)
		{
			bool bTargetAlive = IsValidClient(g_iTarget[iClient]) && IsPlayerAlive(g_iTarget[iClient]);
			if (bTargetAlive || GetEntData(iClient, g_iBotNearbyEnemiesOffset) > 1)
			{
				BotTryToRetreat(iClient, 400.0, 1.5);
				g_fSniperRetreatCooldown[iClient] = fNow + 3.0;
			}
		}
	}

	if ((g_iAliveCountT == 0 || g_iAliveCountCT == 0) && !g_bDontSwitch[iClient])
	{
		SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE));

		if (BotMimic_IsPlayerMimicing(iClient))
			BotMimic_StopPlayerMimic(iClient);

	}

	if (GetDisposition(iClient) == SELF_DEFENSE && !bShouldSaveInsteadOfRetake)
		SetDisposition(iClient, ENGAGE_AND_INVESTIGATE);

	if (g_pCurrArea[iClient] != INVALID_NAV_AREA)
	{
		int iAreaFlags = NavMeshArea_GetFlags(g_pCurrArea[iClient]);

		if (iAreaFlags & NAV_MESH_WALK)
			iButtons |= IN_SPEED;
		if (iAreaFlags & NAV_MESH_RUN)
			iButtons &= ~IN_SPEED;
	}

	if (IsSafe(iClient))
	{
		iButtons &= ~IN_SPEED;
		if (g_bIsProBot[iClient] && !g_bDontSwitch[iClient] && !BotIsHiding(iClient))
			SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE));
	}

	if (g_bIsProBot[iClient])
	{
		if (!g_bBombPlanted && GetTask(iClient) != COLLECT_HOSTAGES && GetTask(iClient) != RESCUE_HOSTAGES && GetTask(iClient) != GUARD_LOOSE_BOMB && GetTask(iClient) != PLANT_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES)
		{
			if (fNow >= g_fWeaponPickupCooldown[iClient])
			{
				ProcessWeaponPickup(iClient);
				g_fWeaponPickupCooldown[iClient] = fNow + 0.5;
			}
		}

		ProcessBombGuardClearBehavior(iClient, iButtons);

		if (GetDisposition(iClient) != IGNORE_ENEMIES)
			ProcessCombat(iClient, iButtons, fVel, fAngles, iDefIndex, fSpeed, fNow);
	}

	int iButtonsAfterCombat = iButtons;
	LogAttackStateDebug(iClient, iButtonsIn, iButtonsAfterPreClear, iButtonsAfterCombat, iButtons, view_as<int>(GetTask(iClient)), eDispositionBeforeSave, GetDisposition(iClient), !!GetEntData(iClient, g_iEnemyVisibleOffset), g_iTarget[iClient], GetClientAimTarget(iClient, true), g_fTargetPos[iClient], iDefIndex, bWeaponCoveredByPluginFire, false, BotMimic_IsPlayerMimicing(iClient));

	return Plugin_Changed;
}

void ProcessWeaponPickup(int iClient)
{
	float fClientEyes[3];
	GetClientEyePosition(iClient, fClientEyes);

	int iSkipAK[] = {DEFIDX_AK47, DEFIDX_AWP};
	TryPickupWeapon(iClient, "weapon_ak47", iSkipAK, sizeof(iSkipAK), CS_SLOT_PRIMARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipM4[] = {DEFIDX_AK47, DEFIDX_AWP, DEFIDX_M4A4, DEFIDX_M4A1S};
	TryPickupWeapon(iClient, "weapon_m4a1", iSkipM4, sizeof(iSkipM4), CS_SLOT_PRIMARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipGalilFamas[] = {DEFIDX_AK47, DEFIDX_AWP, DEFIDX_M4A4, DEFIDX_M4A1S, DEFIDX_FAMAS, DEFIDX_GALIL};
	TryPickupWeapon(iClient, "weapon_galilar", iSkipGalilFamas, sizeof(iSkipGalilFamas), CS_SLOT_PRIMARY, fClientEyes, g_fBotOrigin[iClient]);
	TryPickupWeapon(iClient, "weapon_famas", iSkipGalilFamas, sizeof(iSkipGalilFamas), CS_SLOT_PRIMARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipSMG[] = {DEFIDX_AK47, DEFIDX_AWP, DEFIDX_M4A4, DEFIDX_M4A1S, DEFIDX_FAMAS, DEFIDX_GALIL, DEFIDX_MAC10, DEFIDX_MP9};
	TryPickupWeapon(iClient, "weapon_mac10", iSkipSMG, sizeof(iSkipSMG), CS_SLOT_PRIMARY, fClientEyes, g_fBotOrigin[iClient]);
	TryPickupWeapon(iClient, "weapon_mp9", iSkipSMG, sizeof(iSkipSMG), CS_SLOT_PRIMARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipDeagle[] = {DEFIDX_DEAGLE};
	TryPickupWeapon(iClient, "weapon_deagle", iSkipDeagle, sizeof(iSkipDeagle), CS_SLOT_SECONDARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipTec9[] = {DEFIDX_DEAGLE, DEFIDX_TEC9, DEFIDX_FIVESEVEN, DEFIDX_CZ75, DEFIDX_DUALIES};
	TryPickupWeapon(iClient, "weapon_tec9", iSkipTec9, sizeof(iSkipTec9), CS_SLOT_SECONDARY, fClientEyes, g_fBotOrigin[iClient]);
	TryPickupWeapon(iClient, "weapon_fiveseven", iSkipTec9, sizeof(iSkipTec9), CS_SLOT_SECONDARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipP250[] = {DEFIDX_DEAGLE, DEFIDX_TEC9, DEFIDX_FIVESEVEN, DEFIDX_CZ75, DEFIDX_P250, DEFIDX_DUALIES};
	TryPickupWeapon(iClient, "weapon_p250", iSkipP250, sizeof(iSkipP250), CS_SLOT_SECONDARY, fClientEyes, g_fBotOrigin[iClient]);

	int iSkipUSP[] = {DEFIDX_DEAGLE, DEFIDX_TEC9, DEFIDX_FIVESEVEN, DEFIDX_CZ75, DEFIDX_P250, DEFIDX_P2000, DEFIDX_USPS, DEFIDX_DUALIES};
	TryPickupWeapon(iClient, "weapon_hkp2000", iSkipUSP, sizeof(iSkipUSP), CS_SLOT_SECONDARY, fClientEyes, g_fBotOrigin[iClient]);
}

void ProcessCombat(int iClient, int &iButtons, float fVel[3], float fAngles[3], int iDefIndex, float fSpeed, float fNow)
{
	g_iTarget[iClient] = BotGetEnemy(iClient);

	float fTargetDistance;
	int iZoomLevel;
	bool bIsEnemyVisible = !!GetEntData(iClient, g_iEnemyVisibleOffset);
	bool bIsHiding = BotIsHiding(iClient);
	bool bIsDucking = !!(GetEntityFlags(iClient) & FL_DUCKING);
	bool bIsReloading = IsPlayerReloading(iClient);
	bool bResumeZoom = !!GetEntProp(iClient, Prop_Send, "m_bResumeZoom");

	if (bResumeZoom)
		g_fShootTimestamp[iClient] = fNow;

	if (HasEntProp(g_iActiveWeapon[iClient], Prop_Send, "m_zoomLevel"))
		iZoomLevel = GetEntProp(g_iActiveWeapon[iClient], Prop_Send, "m_zoomLevel");

	if (bIsHiding && (iDefIndex == DEFIDX_AUG || iDefIndex == DEFIDX_SG556) && iZoomLevel == 0)
		iButtons |= IN_ATTACK2;
	else if (!bIsHiding && (iDefIndex == DEFIDX_AUG || iDefIndex == DEFIDX_SG556) && iZoomLevel == 1)
		iButtons |= IN_ATTACK2;

	if (bIsHiding && g_bUncrouch[iClient])
		iButtons &= ~IN_DUCK;

	if (!IsValidClient(g_iTarget[iClient]) || !IsPlayerAlive(g_iTarget[iClient]) || g_fTargetPos[iClient][2] == 0.0)
	{
		g_iPrevTarget[iClient] = g_iTarget[iClient];
		return;
	}

	if (BotMimic_IsPlayerMimicing(iClient))
	{

		BotMimic_StopPlayerMimic(iClient);
	}

	int iWeaponSlot = eItems_GetWeaponSlotByDefIndex(iDefIndex);
	if ((iWeaponSlot == CS_SLOT_KNIFE || iWeaponSlot == CS_SLOT_GRENADE) && GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES)
		BotEquipBestWeapon(iClient, true);

	if (bIsEnemyVisible && GetEntityMoveType(iClient) != MOVETYPE_LADDER)
	{
		if (g_iPrevTarget[iClient] == -1)
			g_fCrouchTimestamp[iClient] = fNow + Math_GetRandomFloat(0.23, 0.25);
		fTargetDistance = GetVectorDistance(g_fBotOrigin[iClient], g_fTargetPos[iClient]);

		float fClientEyes[3], fClientAngles[3], fAimPunchAngle[3], fToAimSpot[3], fAimDir[3];
		GetClientEyePosition(iClient, fClientEyes);
		SubtractVectors(g_fTargetPos[iClient], fClientEyes, fToAimSpot);
		GetClientEyeAngles(iClient, fClientAngles);
		GetEntPropVector(iClient, Prop_Send, "m_aimPunchAngle", fAimPunchAngle);
		ScaleVector(fAimPunchAngle, g_cvRecoilScale.FloatValue);
		AddVectors(fClientAngles, fAimPunchAngle, fClientAngles);
		GetViewVector(fClientAngles, fAimDir);

		float fRangeToEnemy = NormalizeVector(fToAimSpot, fToAimSpot);
		float fOnTarget = GetVectorDotProduct(fToAimSpot, fAimDir);
		float fAimTolerance = Cosine(ArcTangent(32.0 / fRangeToEnemy));

		if (g_iPrevTarget[iClient] == -1 && fOnTarget > fAimTolerance)
			g_fCrouchTimestamp[iClient] = fNow + Math_GetRandomFloat(0.23, 0.25);

		if (IsRifleOrHeavy(iDefIndex) || IsSprayWeapon(iDefIndex))
		{
			bool bIsSpray = IsSprayWeapon(iDefIndex);

			if (fOnTarget > fAimTolerance && !bIsDucking && fTargetDistance < 2000.0 && !bIsSpray)
				AutoStop(iClient, fVel, fAngles);
			else if (fTargetDistance > 2000.0 && GetEntDataFloat(iClient, g_iFireWeaponOffset) == fNow)
				AutoStop(iClient, fVel, fAngles);
			if (fOnTarget > fAimTolerance && fTargetDistance < 2000.0)
			{
				iButtons &= ~IN_ATTACK;
				if (!bIsReloading && (fSpeed < 50.0 || bIsDucking || bIsSpray))
				{
					iButtons |= IN_ATTACK;
					SetEntDataFloat(iClient, g_iFireWeaponOffset, fNow);
				}
			}
		}
		else if (iDefIndex == DEFIDX_DEAGLE)
		{
			if (fNow - GetEntDataFloat(iClient, g_iFireWeaponOffset) < 0.15 && !bIsDucking && !bIsReloading)
				AutoStop(iClient, fVel, fAngles);
		}
		else if (iDefIndex == DEFIDX_AWP || iDefIndex == DEFIDX_SSG08)
		{
			if (fTargetDistance < 2750.0 && !bIsReloading && GetEntProp(iClient, Prop_Send, "m_bIsScoped") && fNow - g_fShootTimestamp[iClient] > 0.4 && GetClientAimTarget(iClient, true) == g_iTarget[iClient])
			{
				iButtons |= IN_ATTACK;
				SetEntDataFloat(iClient, g_iFireWeaponOffset, fNow);
			}
		}

		float fClientLoc[3];
		Array_Copy(g_fBotOrigin[iClient], fClientLoc, 3);
		fClientLoc[2] += HalfHumanHeight;
		if (fNow >= g_fCrouchTimestamp[iClient] && !GetEntProp(g_iActiveWeapon[iClient], Prop_Data, "m_bInReload") && IsPointVisible(fClientLoc, g_fTargetPos[iClient]) && fOnTarget > fAimTolerance && fTargetDistance < 2000.0 && IsRifleOrHeavy(iDefIndex))
			iButtons |= IN_DUCK;
	}

	g_iPrevTarget[iClient] = g_iTarget[iClient];
}

public void OnPlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!IsValidClient(iClient))
        return;

	ResetBotReaction(iClient, "spawn");
    SetPlayerTeammateColor(iClient);

    if (!IsFakeClient(iClient))
        return;

	g_bSaveLocked[iClient] = false;
	g_fSaveConditionSince[iClient] = 0.0;
	ResetClientSaveTarget(iClient);
	ResetClientBombMove(iClient);
	g_fSaveLookAtDebugTime[iClient] = 0.0;

    if (g_bIsProBot[iClient])
    {
        Address pLocalProfile = view_as<Address>(GetEntData(iClient, g_iBotProfileOffset));
        //All these offsets are inside BotProfileManager::Init which has strings for every botprofile parameter
        StoreToAddress(pLocalProfile + view_as<Address>(104), view_as<int>(g_fLookAngleMaxAccel[iClient]), NumberType_Int32);
        StoreToAddress(pLocalProfile + view_as<Address>(116), view_as<int>(g_fLookAngleMaxAccel[iClient]), NumberType_Int32);
        StoreToAddress(pLocalProfile + view_as<Address>(84), view_as<int>(g_fReactionTime[iClient]), NumberType_Int32);
        StoreToAddress(pLocalProfile + view_as<Address>(4), view_as<int>(g_fAggression[iClient]), NumberType_Int32);
    }

    if (g_bUseUSP[iClient] && GetClientTeam(iClient) == CS_TEAM_CT)
    {
        char szWeapon[32];
        GetClientWeapon(iClient, szWeapon, sizeof(szWeapon));

        if (strcmp(szWeapon, "weapon_hkp2000") == 0)
            ReplaceWeapon(iClient, CS_SLOT_SECONDARY, "weapon_usp_silencer");
    }
}

public void OnPlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (!IsValidClient(iClient))
		return;

	ResetBotReaction(iClient, "team_changed");
	CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int iClient)
{
	ResetBotReaction(iClient, "disconnect");
	SetProfileRank(iClient, 0);
	g_iPlayerColor[iClient] = -1;
	g_bIsProBot[iClient] = false;
	g_fAttackDebugTime[iClient] = 0.0;
	g_bUseCZ75[iClient] = false;
	g_bUseUSP[iClient] = false;
	g_bUseM4A1S[iClient] = false;
	g_bDontSwitch[iClient] = false;
	g_bDropWeapon[iClient] = false;
	g_bHasGottenDrop[iClient] = false;
	g_bCheapDrop[iClient] = false;
	g_bUncrouch[iClient] = false;
	g_iTarget[iClient] = -1;
	g_iPrevTarget[iClient] = -1;

	g_iActiveWeapon[iClient] = -1;
	g_fLookAngleMaxAccel[iClient] = 0.0;
	g_fReactionTime[iClient] = 0.0;
	g_fAggression[iClient] = 0.0;
	g_fShootTimestamp[iClient] = 0.0;
	g_fCrouchTimestamp[iClient] = 0.0;
	g_fSniperRetreatCooldown[iClient] = 0.0;
	g_fWeaponPickupCooldown[iClient] = 0.0;

	g_pCurrArea[iClient] = INVALID_NAV_AREA;
	ResetClientSaveTarget(iClient);
	ResetClientBombMove(iClient);
	g_szCrosshairCode[iClient][0] = '\0';
}

public void LoadSDK()
{
	GameData hConf = new GameData("botstuff.games");
	if (hConf == null)
		SetFailState("Failed to find botstuff.games game config.");

	g_pTheBots = SetupAddress(hConf, "TheBots");
	g_iBotTargetSpotOffset = SetupOffset(hConf, "CCSBot::m_targetSpot");
	g_iBotNearbyEnemiesOffset = SetupOffset(hConf, "CCSBot::m_nearbyEnemyCount");
	g_iFireWeaponOffset = SetupOffset(hConf, "CCSBot::m_fireWeaponTimestamp");
	g_iEnemyVisibleOffset = SetupOffset(hConf, "CCSBot::m_isEnemyVisible");
	g_iBotProfileOffset = SetupOffset(hConf, "CCSBot::m_pLocalProfile");
	g_iBotSafeTimeOffset = SetupOffset(hConf, "CCSBot::m_safeTime");
	g_iBotEnemyOffset = SetupOffset(hConf, "CCSBot::m_enemy");
	g_iBotLookAtSpotStateOffset = SetupOffset(hConf, "CCSBot::m_lookAtSpotState");
	g_iBotMoraleOffset = SetupOffset(hConf, "CCSBot::m_morale");
	g_iBotTaskOffset = SetupOffset(hConf, "CCSBot::m_task");
	g_iBotDispositionOffset = SetupOffset(hConf, "CCSBot::m_disposition");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::MoveTo");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hBotMoveTo = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::MoveTo");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupBone");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CBaseAnimating::LookupBone");

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetBonePosition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CBaseAnimating::GetBonePosition");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::IsVisible");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotIsVisible = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::IsVisible");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::IsAtHidingSpot");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotIsHiding = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::IsAtHidingSpot");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::EquipBestWeapon");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotEquipBestWeapon = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::EquipBestWeapon");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::SetLookAt");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((g_hBotSetLookAt = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::SetLookAt");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "SetCrosshairCode");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((g_hSetCrosshairCode = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: SetCrosshairCode");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "Weapon_Switch");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSwitchWeaponCall = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: Weapon_Switch");

	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBotManager::IsLineBlockedBySmoke");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hIsLineBlockedBySmoke = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CBotManager::IsLineBlockedBySmoke");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSPlayer::AddAccount");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if ((g_hAddMoney = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSPlayer::AddAccount");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::OnAudibleEvent");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	if ((g_hOnAudibleEvent = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::OnAudibleEvent");

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::TryToRetreat");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if ((g_hTryToRetreat = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::TryToRetreat");

	delete hConf;
}

public void LoadDetours()
{
	GameData hConf = new GameData("botstuff.games");
	if (hConf == null)
	{
		SetFailState("Failed to load botstuff.games gamedata.");
		return;
	}

	SetupDetour(hConf, "CCSBot::SetLookAt", Hook_Pre, CCSBot_SetLookAtLinux);
	SetupOptionalDetour(hConf, "CCSBot::MoveTo", Hook_Pre, CCSBot_MoveTo);
	SetupDetour(hConf, "CCSBot::PickNewAimSpot", Hook_Post, CCSBot_PickNewAimSpot);
	SetupDetour(hConf, "CCSBot::GetPartPosition", Hook_Pre, CCSBot_GetPartPosition);
	SetupDetour(hConf, "CCSBot::CanSeeLooseBomb", Hook_Post, CCSBot_CanSeeLooseBomb);
	SetupDetour(hConf, "BotReaction::BurstFollowup", Hook_Pre, BotReaction_ContinueBurst);

	delete hConf;
}

public int LookupBone(int iEntity, const char[] szName)
{
	return SDKCall(g_hLookupBone, iEntity, szName);
}

public void GetBonePosition(int iEntity, int iBone, float fOrigin[3], float fAngles[3])
{
	SDKCall(g_hGetBonePosition, iEntity, iBone, fOrigin, fAngles);
}

public void BotMoveTo(int iClient, float fOrigin[3], RouteType eRouteType)
{
	SDKCall(g_hBotMoveTo, iClient, fOrigin, eRouteType);
}

bool BotIsVisible(int iClient, float fPos[3], bool bTestFOV, int iIgnore = -1)
{
	return SDKCall(g_hBotIsVisible, iClient, fPos, bTestFOV, iIgnore);
}

public bool BotIsHiding(int iClient)
{
	return SDKCall(g_hBotIsHiding, iClient);
}

public void BotEquipBestWeapon(int iClient, bool bMustEquip)
{
	SDKCall(g_hBotEquipBestWeapon, iClient, bMustEquip);
}

public void BotSetLookAt(int iClient, const char[] szDesc, const float fPos[3], PriorityType ePri, float fDuration, bool bClearIfClose, float fAngleTolerance, bool bAttack)
{
	SDKCall(g_hBotSetLookAt, iClient, szDesc, fPos, ePri, fDuration, bClearIfClose, fAngleTolerance, bAttack);
}

void BotOnAudibleEvent(int iBot, Event eEvent, int iPlayer, float fRange, PriorityType ePriority, bool bIsHostile, bool bIsFootstep = false, const float fActualOrigin[3] = NULL_VECTOR)
{
	SDKCall(g_hOnAudibleEvent, iBot, BB_GetGameEventAddress(eEvent), iPlayer, fRange, ePriority, bIsHostile, bIsFootstep, fActualOrigin);
}

public int BotGetEnemy(int iClient)
{
	return GetEntDataEnt2(iClient, g_iBotEnemyOffset);
}

public void SetCrosshairCode(Address pCCSPlayerResource, int iClient, const char[] szCode)
{
	SDKCall(g_hSetCrosshairCode, pCCSPlayerResource, iClient, szCode);
}

public void AddMoney(int iClient, int iAmount, bool bTrackChange, bool bItemBought, const char[] szItemName)
{
	SDKCall(g_hAddMoney, iClient, iAmount, bTrackChange, bItemBought, szItemName);
}

void SwitchWeapon(int iClient, int iWeapon)
{
	SDKCall(g_hSwitchWeaponCall, iClient, iWeapon, 0);
}

bool BotTryToRetreat(int iClient, float fMaxRange = 400.0, float fDuration = -1.0)
{
	return SDKCall(g_hTryToRetreat, iClient, fMaxRange, fDuration);
}

bool IsDefaultPistol(const char[] szWeapon)
{
	return strcmp(szWeapon, "weapon_hkp2000") == 0 || strcmp(szWeapon, "weapon_usp_silencer") == 0 || strcmp(szWeapon, "weapon_glock") == 0;
}

void BlockBotDisruptiveAltFire(int iDefIndex, int &iButtons)
{
	if (!(iButtons & IN_ATTACK2))
		return;

	switch (iDefIndex)
	{
		case DEFIDX_GLOCK, DEFIDX_FAMAS, DEFIDX_M4A1S, DEFIDX_USPS:
		{
			iButtons &= ~IN_ATTACK2;
		}
	}
}

bool IsBlockedOddPrimaryBuy(const char[] szWeapon)
{
	return strcmp(szWeapon, "negev") == 0 || strcmp(szWeapon, "m249") == 0 ||
	       strcmp(szWeapon, "scar20") == 0 || strcmp(szWeapon, "g3sg1") == 0 ||
	       strcmp(szWeapon, "aug") == 0 || strcmp(szWeapon, "sg556") == 0 ||
	       strcmp(szWeapon, "p90") == 0 || strcmp(szWeapon, "xm1014") == 0;
}

public int Sort_BotMoneyDesc(int iIndex1, int iIndex2, Handle hArray, Handle hHndl)
{
    int iEntry1[2], iEntry2[2];
    GetArrayArray(hArray, iIndex1, iEntry1, sizeof(iEntry1));
    GetArrayArray(hArray, iIndex2, iEntry2, sizeof(iEntry2));

    if (iEntry1[1] > iEntry2[1]) return -1;
    if (iEntry1[1] < iEntry2[1]) return 1;
    return 0;
}

bool IsTopBot(const char[] szName)
{
    for (int i = 0; i < sizeof(g_szTopBotNames); i++)
    {
        if (strcmp(szName, g_szTopBotNames[i]) == 0)
            return true;
    }
    return false;
}

int FindLooseBomb()
{
	int iEnt = -1;
	while ((iEnt = FindEntityByClassname(iEnt, "weapon_c4")) != -1)
	{
		int iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
		if (!IsValidClient(iOwner))
			return iEnt;
	}
	return -1;
}

bool IsLooseBombDroppedByLiveT()
{
	int iDropper = g_iLooseBombDropper;
	return (IsValidClient(iDropper) && IsPlayerAlive(iDropper) && GetClientTeam(iDropper) == CS_TEAM_T);
}

bool ShouldSaveInsteadOfRetake(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return false;

	if (IsWarmupPeriod() || IsGet5SaveBlockedPhase())
		return false;

	int iTeam = GetClientTeam(iClient);

	if (iTeam == CS_TEAM_CT)
	{
		if (g_bBombPlanted)
			return IsCTCommittedToSave(iClient);

		if (IsForceSaveEnabled())
			return true;

		return ShouldCTTeamSave();
	}

	if (iTeam == CS_TEAM_T && IsTCarryingC4NearBombsite(iClient))
	{
		g_bSaveLocked[iClient] = false;
		g_fSaveConditionSince[iClient] = 0.0;
		return false;
	}

	if (IsForceSaveEnabled())
		return true;

	if (g_bSaveLocked[iClient])
		return true;

	if (!ShouldStartSaveInsteadOfRetake(iClient))
	{
		g_fSaveConditionSince[iClient] = 0.0;
		return false;
	}

	float fNow = GetGameTime();
	if (g_fSaveConditionSince[iClient] <= 0.0)
	{
		g_fSaveConditionSince[iClient] = fNow;
		return false;
	}

	if ((fNow - g_fSaveConditionSince[iClient]) < RETAKE_SAVE_START_DELAY)
		return false;

	g_bSaveLocked[iClient] = true;
	return true;
}

bool IsForceSaveEnabled()
{
	return (g_cvForceSave != null && g_cvForceSave.BoolValue);
}

bool IsWarmupPeriod()
{
	return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

bool IsGet5SaveBlockedPhase()
{
	if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") != FeatureStatus_Available)
		return false;

	Get5State state = Get5_GetGameState();
	return state == Get5State_Warmup
		|| state == Get5State_KnifeRound
		|| state == Get5State_WaitingForKnifeRoundDecision;
}

bool IsBotMimicBlockedPhase()
{
	return IsWarmupPeriod() || IsGet5SaveBlockedPhase();
}

bool ShouldCTStrategicSaveRuntime()
{
	if (IsForceSaveEnabled())
		return true;

	return ShouldCTTeamSave();
}

bool IsCTStrategicSaveActive()
{
	if (IsForceSaveEnabled())
		return true;

	if (g_iAliveCountT <= 0)
		return false;

	return g_bCTSaveLocked;
}

bool ShouldCTTeamSave()
{
	if (g_iAliveCountT <= 0)
	{
		g_bCTSaveLocked = false;
		g_fCTSaveConditionSince = 0.0;
		return false;
	}

	if (g_bCTSaveLocked)
		return true;

	if (!ShouldStartCTTeamSave())
	{
		g_fCTSaveConditionSince = 0.0;
		return false;
	}

	float fNow = GetGameTime();
	if (g_fCTSaveConditionSince <= 0.0)
	{
		g_fCTSaveConditionSince = fNow;
		return false;
	}

	if ((fNow - g_fCTSaveConditionSince) < RETAKE_SAVE_START_DELAY)
		return false;

	g_bCTSaveLocked = true;
	return true;
}

static bool IsCTCommittedToSaveCore(int iClient, bool bStrategicSave)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return false;

	if (GetClientTeam(iClient) != CS_TEAM_CT)
		return false;

	if (!g_bBombPlanted)
		return false;

	if (!bStrategicSave)
		return false;

	if (!!GetEntProp(iClient, Prop_Send, "m_bIsDefusing"))
		return false;

	if (IsSavingBotUnderDirectThreat(iClient))
		return false;

	float fBombDistance;
	if (!GetDistanceToPlantedBomb(iClient, fBombDistance))
		return false;

	if (fBombDistance <= CT_SAVE_COMMIT_DEFUSE_CANCEL_DISTANCE)
		return false;

	if (fBombDistance < CT_SAVE_COMMIT_MIN_BOMB_DISTANCE)
		return false;

	return true;
}

bool IsCTCommittedToSave(int iClient)
{
	return IsCTCommittedToSaveCore(iClient, ShouldCTStrategicSaveRuntime());
}

bool IsCTCommittedToSaveSnapshot(int iClient)
{
	return IsCTCommittedToSaveCore(iClient, IsCTStrategicSaveActive());
}

bool ShouldStartCTTeamSave()
{
	if (g_bHalftimeSwitch || g_bForceT || g_bForceCT)
		return false;

	if (g_iAliveCountCT <= 0 || g_iAliveCountT <= 0)
		return false;

	if (g_iAliveCountT - g_iAliveCountCT < 3)
		return false;

	return g_iAvgMoneyCT <= RETAKE_SAVE_MONEY_THRESHOLD;
}

bool IsSaveActiveForClient(int iClient)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient))
		return false;

	int iTeam = GetClientTeam(iClient);
	if (iTeam == CS_TEAM_CT)
		return g_bCTSaveLocked;

	return g_bSaveLocked[iClient];
}

bool ShouldStartSaveInsteadOfRetake(int iClient)
{
	if (g_bHalftimeSwitch || g_bForceT || g_bForceCT)
		return false;

	int iTeam = GetClientTeam(iClient);
	int iOwnAlive, iEnemyAlive, iOwnAvgMoney;
	if (iTeam == CS_TEAM_T)
	{
		iOwnAlive = g_iAliveCountT;
		iEnemyAlive = g_iAliveCountCT;
		iOwnAvgMoney = g_iAvgMoneyT;
	}
	else if (iTeam == CS_TEAM_CT)
	{
		iOwnAlive = g_iAliveCountCT;
		iEnemyAlive = g_iAliveCountT;
		iOwnAvgMoney = g_iAvgMoneyCT;
	}
	else
	{
		return false;
	}

	if (iOwnAlive <= 0 || iEnemyAlive <= 0)
		return false;

	if (iEnemyAlive - iOwnAlive < 3)
		return false;

	if (iTeam == CS_TEAM_T && !g_bBombPlanted)
	{
		int iC4 = GetPlayerWeaponSlot(iClient, CS_SLOT_C4);
		if (IsValidEntity(iC4))
		{
			float fC4Pos[3];
			GetClientAbsOrigin(iClient, fC4Pos);
			if (GetVectorDistance(fC4Pos, g_fBombPos) <= RETAKE_SAVE_MIN_BOMB_DISTANCE)
				return false;
		}
	}

	return iOwnAvgMoney <= RETAKE_SAVE_MONEY_THRESHOLD;
}

void LogAttackStateDebug(int iClient, int iButtonsIn, int iButtonsAfterPreClear, int iButtonsAfterCombat, int iButtonsOut, int iTask, DispositionType eDispositionBefore, DispositionType eDispositionAfter, bool bEnemyVisible, int iTarget, int iAimTarget, float fTargetPos[3], int iDefIndex, bool bWeaponCovered, bool bEarlyReturn, bool bBotMimicActive)
{
	if (g_cvAttackDebug.IntValue < 1)
		return;
	if (!g_bBombPlanted || GetClientTeam(iClient) != CS_TEAM_CT)
		return;

	bool bAtkIn = !!(iButtonsIn & IN_ATTACK);
	bool bAtkPreClear = !!(iButtonsAfterPreClear & IN_ATTACK);
	bool bAtkCombat = !!(iButtonsAfterCombat & IN_ATTACK);
	bool bAtkOut = !!(iButtonsOut & IN_ATTACK);
	if (!bAtkIn && !bAtkPreClear && !bAtkCombat && !bAtkOut)
		return;

	float fNow = GetGameTime();
	if (fNow < g_fAttackDebugTime[iClient])
		return;
	g_fAttackDebugTime[iClient] = fNow + 0.5;

	PrintToServer("[AtkDbg] cl=%d task=%d disp_pre=%d disp_post=%d vis=%d tgt=%d aim=%d def=%d cov=%d early=%d mimic=%d atk_in=%d atk_pc=%d atk_cb=%d atk_out=%d pos=%.0f,%.0f,%.0f",
		iClient, iTask, eDispositionBefore, eDispositionAfter, bEnemyVisible, iTarget, iAimTarget, iDefIndex, bWeaponCovered, bEarlyReturn, bBotMimicActive, bAtkIn, bAtkPreClear, bAtkCombat, bAtkOut, fTargetPos[0], fTargetPos[1], fTargetPos[2]);
}

void LogRetakeSaveDebug(int iClient)
{
	if (g_cvRetakeSaveDebug == null || g_cvRetakeSaveDebug.IntValue <= 0)
		return;

	int iTeam = GetClientTeam(iClient);
	if (iTeam != CS_TEAM_T && iTeam != CS_TEAM_CT)
		return;

	float fNow = GetGameTime();
	if (fNow < g_fRetakeSaveDebugTime[iClient])
		return;
	g_fRetakeSaveDebugTime[iClient] = fNow + 0.5;

	int iOwnAlive = (iTeam == CS_TEAM_T) ? g_iAliveCountT : g_iAliveCountCT;
	int iEnemyAlive = (iTeam == CS_TEAM_T) ? g_iAliveCountCT : g_iAliveCountT;
	int iOwnAvgMoney = (iTeam == CS_TEAM_T) ? g_iAvgMoneyT : g_iAvgMoneyCT;
	int iManDisadvantage = iEnemyAlive - iOwnAlive;
	bool bSaveActive = IsSaveActiveForClient(iClient) || IsForceSaveEnabled();
	if (!bSaveActive && g_cvRetakeSaveDebug.IntValue < 2)
		return;

	float fDangerPos[3];
	float fDistanceToDanger = -1.0;
	if (GetSaveDangerPosition(iClient, fDangerPos))
		fDistanceToDanger = GetVectorDistance(g_fBotOrigin[iClient], fDangerPos);

	bool bThreat = IsSavingBotUnderDirectThreat(iClient);
	bool bLocked = (iTeam == CS_TEAM_CT) ? g_bCTSaveLocked : g_bSaveLocked[iClient];
	TaskType eTask = GetTask(iClient);

	float fBombDistance = -1.0;
	if (iTeam == CS_TEAM_CT)
		GetDistanceToPlantedBomb(iClient, fBombDistance);

	bool bCTTeamSave = (iTeam == CS_TEAM_CT) ? IsCTStrategicSaveActive() : false;
	bool bCTCommittedSave = (iTeam == CS_TEAM_CT) ? IsCTCommittedToSaveSnapshot(iClient) : false;
	bool bDefusing = !!GetEntProp(iClient, Prop_Send, "m_bIsDefusing");

	PrintToServer("[BB SaveDebug] client=%N team=%d locked=%d active=%d ct_team_save=%d ct_commit=%d threat=%d task=%d disposition=%d defusing=%d own_alive=%d enemy_alive=%d disadvantage=%d avg_money=%d danger_dist=%.1f bomb_dist=%.1f", iClient, iTeam, bLocked, bSaveActive, bCTTeamSave, bCTCommittedSave, bThreat, view_as<int>(eTask), view_as<int>(GetDisposition(iClient)), bDefusing, iOwnAlive, iEnemyAlive, iManDisadvantage, iOwnAvgMoney, fDistanceToDanger, fBombDistance);
}

void LogCTCommittedSaveObjectiveBlock(int iClient, const char[] szHook, const char[] szReason)
{
	if (g_cvRetakeSaveDebug == null || g_cvRetakeSaveDebug.IntValue < 2)
		return;

	if (GetClientTeam(iClient) != CS_TEAM_CT)
		return;

	float fBombDistance = -1.0;
	GetDistanceToPlantedBomb(iClient, fBombDistance);

	PrintToServer("[BB CTSaveBlock] client=%N hook=%s reason=%s task=%d disposition=%d bomb_dist=%.1f defusing=%d threat=%d",
		iClient, szHook, szReason, view_as<int>(GetTask(iClient)), view_as<int>(GetDisposition(iClient)), fBombDistance, !!GetEntProp(iClient, Prop_Send, "m_bIsDefusing"), IsSavingBotUnderDirectThreat(iClient));
}

void LogSaveLookAtDebug(int iClient, const char[] szDesc, bool bBlocked)
{
	if (g_cvRetakeSaveDebug == null || g_cvRetakeSaveDebug.IntValue < 2)
		return;

	float fNow = GetGameTime();
	if (fNow < g_fSaveLookAtDebugTime[iClient])
		return;
	g_fSaveLookAtDebugTime[iClient] = fNow + 0.5;

	PrintToServer("[BB SaveLookAt] client=%N team=%d desc=\"%s\" objective_block=%d task=%d disposition=%d", iClient, GetClientTeam(iClient), szDesc, bBlocked, view_as<int>(GetTask(iClient)), view_as<int>(GetDisposition(iClient)));
}

bool ProcessRetakeSaveBehavior(int iClient, int &iButtons)
{
	bool bChanged = !!(iButtons & IN_USE);
	iButtons &= ~IN_USE;

	if (BotMimic_IsPlayerMimicing(iClient))
		BotMimic_StopPlayerMimic(iClient);

	SetDisposition(iClient, OPPORTUNITY_FIRE);
	BotEquipBestWeapon(iClient, true);

	if (g_bSaveSettled[iClient])
		return bChanged;

	if (IsSavingBotUnderDirectThreat(iClient))
		return bChanged;

	float fTarget[3];
	if (GetSaveMoveTarget(iClient, fTarget))
	{
		float fNow = GetGameTime();
		if (fNow >= g_fSaveNextMoveAt[iClient] && GetVectorDistance(g_fBotOrigin[iClient], fTarget) > RETAKE_SAVE_TARGET_REACHED_DISTANCE)
		{
			g_bIssuingSaveMove[iClient] = true;
			BotMoveTo(iClient, fTarget, RETREAT_ROUTE);
			g_bIssuingSaveMove[iClient] = false;
			g_fSaveNextMoveAt[iClient] = fNow + RETAKE_SAVE_MOVE_INTERVAL;
		}
	}
	else if (!g_bSaveSettled[iClient])
	{
		float fNow = GetGameTime();
		if (fNow >= g_fSaveNextMoveAt[iClient])
		{
			BotTryToRetreat(iClient);
			g_fSaveNextMoveAt[iClient] = fNow + RETAKE_SAVE_MOVE_INTERVAL;
		}
	}

	return bChanged;
}

bool IsSavingBotUnderDirectThreat(int iClient)
{
	if (GetEntData(iClient, g_iBotNearbyEnemiesOffset) > 0)
		return true;

	return false;
}

bool GetSaveDangerPosition(int iClient, float fDangerPos[3])
{
	if (g_bBombPlanted && GetClientTeam(iClient) == CS_TEAM_CT && GetPlantedBombPosition(fDangerPos))
		return true;

	if (!g_bBombPlanted && GetClientTeam(iClient) == CS_TEAM_T && GetNearestBombsitePosition(iClient, fDangerPos))
		return true;

	return GetLiveEnemyCenter(iClient, fDangerPos);
}

bool GetLiveEnemyCenter(int iClient, float fCenter[3])
{
	int iTeam = GetClientTeam(iClient);
	int iCount;
	fCenter[0] = 0.0;
	fCenter[1] = 0.0;
	fCenter[2] = 0.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) == iTeam)
			continue;

		float fPos[3];
		GetClientAbsOrigin(i, fPos);
		AddVectors(fCenter, fPos, fCenter);
		iCount++;
	}

	if (iCount <= 0)
		return false;

	ScaleVector(fCenter, 1.0 / float(iCount));
	return true;
}

bool FindSaveTargetAwayFrom(int iClient, const float fDangerPos[3], float fTarget[3])
{
	float fBotPos[3];
	GetClientAbsOrigin(iClient, fBotPos);

	if (g_pCurrArea[iClient] == INVALID_NAV_AREA)
		return false;

	float fCurrentDangerDist = GetVectorDistance(fBotPos, fDangerPos);

	ArrayStack hAreas = NavMesh_CollectSurroundingAreas(g_pCurrArea[iClient], RETAKE_SAVE_FAR_DISTANCE);
	if (hAreas == null)
		return false;

	float fBestDist = fCurrentDangerDist;
	bool bFound = false;

	while (!hAreas.Empty)
	{
		CNavArea pArea = hAreas.Pop();
		float fAreaCenter[3];
		if (!NavMeshArea_GetCenter(pArea, fAreaCenter))
			continue;

		float fDist = GetVectorDistance(fAreaCenter, fDangerPos);
		if (fDist > fBestDist)
		{
			fBestDist = fDist;
			Array_Copy(fAreaCenter, fTarget, 3);
			bFound = true;
		}
	}

	delete hAreas;
	return bFound;
}

bool GetSaveMoveTarget(int iClient, float fTarget[3])
{
	if (g_bSaveSettled[iClient])
		return false;

	float fDangerPos[3];
	if (!GetSaveDangerPosition(iClient, fDangerPos))
	{
		ResetClientSaveTarget(iClient);
		return false;
	}

	float fNow = GetGameTime();

	if (g_bSaveTargetValid[iClient])
	{
		float fDistToTarget = GetVectorDistance(g_fBotOrigin[iClient], g_fSaveTarget[iClient]);

		if (fDistToTarget < g_fSaveLastProgressDist[iClient] - RETAKE_SAVE_PROGRESS_THRESHOLD)
		{
			g_fSaveLastProgressDist[iClient] = fDistToTarget;
			g_fSaveLastProgressTime[iClient] = fNow;
		}

		if (fDistToTarget > RETAKE_SAVE_TARGET_REACHED_DISTANCE && (fNow - g_fSaveLastProgressTime[iClient]) >= RETAKE_SAVE_REACH_TIMEOUT)
		{
			g_bSaveSettled[iClient] = true;
			return false;
		}
	}

	bool bNeedRepath = !g_bSaveTargetValid[iClient] || fNow >= g_fSaveNextRepathAt[iClient];
	if (!bNeedRepath)
	{
		Array_Copy(g_fSaveTarget[iClient], fTarget, 3);
		return true;
	}

	if (!FindSaveTargetAwayFrom(iClient, fDangerPos, g_fSaveTarget[iClient]))
	{
		g_bSaveSettled[iClient] = true;
		return false;
	}

	g_bSaveTargetValid[iClient] = true;
	g_fSaveNextRepathAt[iClient] = fNow + RETAKE_SAVE_REPATH_INTERVAL;
	g_fSaveTargetSetTime[iClient] = fNow;
	g_fSaveLastProgressDist[iClient] = GetVectorDistance(g_fBotOrigin[iClient], g_fSaveTarget[iClient]);
	g_fSaveLastProgressTime[iClient] = fNow;
	Array_Copy(g_fSaveTarget[iClient], fTarget, 3);
	return true;
}

void ResetClientSaveTarget(int iClient)
{
	if (iClient < 1 || iClient > MaxClients)
		return;

	g_bSaveTargetValid[iClient] = false;
	g_bSaveSettled[iClient] = false;
	g_fSaveNextRepathAt[iClient] = 0.0;
	g_fSaveNextMoveAt[iClient] = 0.0;
	g_fSaveTargetSetTime[iClient] = 0.0;
	g_fSaveLastProgressDist[iClient] = 0.0;
	g_fSaveLastProgressTime[iClient] = 0.0;
	g_fSaveTarget[iClient][0] = 0.0;
	g_fSaveTarget[iClient][1] = 0.0;
	g_fSaveTarget[iClient][2] = 0.0;
}

bool IsTCarryingC4NearBombsite(int iClient)
{
	if (!g_bIsBombScenario || g_bBombPlanted || GetClientTeam(iClient) != CS_TEAM_T)
		return false;

	int iC4 = GetPlayerWeaponSlot(iClient, CS_SLOT_C4);
	if (iC4 == -1)
		return false;

	if (GetTask(iClient) != PLANT_BOMB)
		return false;

	float fBombPos[3];
	if (!GetNearestBombsitePosition(iClient, fBombPos))
		return false;

	float fClientPos[3];
	GetClientAbsOrigin(iClient, fClientPos);
	return GetVectorDistance(fClientPos, fBombPos) <= RETAKE_SAVE_PLANT_DISTANCE;
}

bool ProcessBombGuardClearBehavior(int iClient, int &iButtons)
{
	int iThreat;
	float fThreatPos[3];
	float fC4Pos[3];
	if (!GetBombGuardThreat(iClient, iThreat, fThreatPos, fC4Pos))
		return false;

	TaskType eTask = GetTask(iClient);
	float fDistanceToC4 = GetVectorDistance(g_fBotOrigin[iClient], fC4Pos);
	bool bDefuseCommitted = (eTask == DEFUSE_BOMB || GetEntProp(iClient, Prop_Send, "m_bIsDefusing") != 0 || fDistanceToC4 <= BOMB_GUARD_CLEAR_RADIUS);
	if (!bDefuseCommitted)
		return false;

	iButtons &= ~IN_USE;
	ClearBombGuardThreat(iClient, iThreat, fThreatPos);
	return true;
}

bool GetBombGuardThreat(int iClient, int &iThreat, float fThreatPos[3], float fC4Pos[3])
{
	iThreat = -1;
	if (!g_bBombPlanted || GetClientTeam(iClient) != CS_TEAM_CT)
		return false;

	if (GetTask(iClient) == ESCAPE_FROM_BOMB || GetTask(iClient) == ESCAPE_FROM_FLAMES)
		return false;

	if (!GetPlantedBombPosition(fC4Pos))
		return false;

	iThreat = FindTerroristNearPlantedBomb(fC4Pos, BOMB_GUARD_CLEAR_RADIUS, fThreatPos);
	return iThreat != -1;
}

void ClearBombGuardThreat(int iClient, int iThreat, const float fThreatPos[3])
{
	if (!IsValidClient(iThreat) || !IsPlayerAlive(iThreat))
		return;

	float fLookPos[3];
	Array_Copy(fThreatPos, fLookPos, 3);
	fLookPos[2] += HalfHumanHeight;

	float fEyePos[3];
	GetClientEyePosition(iClient, fEyePos);
	bool bCanSee = IsPointVisible(fEyePos, fLookPos);

	if (bCanSee)
	{
		SetDisposition(iClient, ENGAGE_AND_INVESTIGATE);
		BotEquipBestWeapon(iClient, true);
		BotSetLookAt(iClient, "Clear bomb guard", fLookPos, PRIORITY_HIGH, 0.5, false, 20.0, true);
	}
	else if (GetVectorDistance(g_fBotOrigin[iClient], fThreatPos) > 150.0)
	{
		float fMovePos[3];
		Array_Copy(fThreatPos, fMovePos, 3);
		BotMoveTo(iClient, fMovePos, FASTEST_ROUTE);
	}
}

bool GetPlantedBombPosition(float fC4Pos[3])
{
	if (!g_bBombPlanted)
		return false;

	Array_Copy(g_fBombPos, fC4Pos, 3);
	return true;
}

bool GetDistanceToPlantedBomb(int iClient, float &fDistance)
{
	float fC4Pos[3];
	if (!GetPlantedBombPosition(fC4Pos))
		return false;

	float fClientPos[3];
	GetClientAbsOrigin(iClient, fClientPos);
	fDistance = GetVectorDistance(fClientPos, fC4Pos);
	return true;
}

bool GetNearestBombsitePosition(int iClient, float fBombPos[3])
{
	if (g_iBombsiteCount <= 0)
		return false;

	float fClientPos[3];
	GetClientAbsOrigin(iClient, fClientPos);

	float fBestDistance = -1.0;
	int iBest = -1;
	for (int i = 0; i < g_iBombsiteCount; i++)
	{
		float fDistance = GetVectorDistance(fClientPos, g_fBombsitePositions[i]);
		if (iBest == -1 || fDistance < fBestDistance)
		{
			fBestDistance = fDistance;
			iBest = i;
		}
	}

	Array_Copy(g_fBombsitePositions[iBest], fBombPos, 3);
	return true;
}

int FindTerroristNearPlantedBomb(const float fC4Pos[3], float fRange, float fThreatPos[3])
{
	int iBestThreat = -1;
	float fBestDistance = fRange;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_T)
			continue;

		float fPos[3];
		GetClientAbsOrigin(i, fPos);
		float fDistance = GetVectorDistance(fPos, fC4Pos);
		if (fDistance < fBestDistance)
		{
			fBestDistance = fDistance;
			iBestThreat = i;
			Array_Copy(fPos, fThreatPos, 3);
		}
	}
	return iBestThreat;
}

void TryPickupWeapon(int iClient, const char[] szClassname, const int[] iSkipList, int iSkipSize, int iSlot, float fClientEyes[3], float fOrigin[3])
{
	int iWeaponEnt = GetNearestEntity(iClient, szClassname);
	if (!IsValidEntity(iWeaponEnt))
		return;

	int iCurrent = GetPlayerWeaponSlot(iClient, iSlot);
	if (IsValidEntity(iCurrent))
	{
		int iCurrentDef = GetEntProp(iCurrent, Prop_Send, "m_iItemDefinitionIndex");
		for (int i = 0; i < iSkipSize; i++)
		{
			if (iCurrentDef == iSkipList[i])
				return;
		}
	}

	float fLoc[3];
	GetEntPropVector(iWeaponEnt, Prop_Send, "m_vecOrigin", fLoc);

	if (GetVectorLength(fLoc) == 0.0 || !IsPointVisible(fClientEyes, fLoc))
		return;

	if (NavMesh_GetNearestArea(fLoc, false, 50.0, false, true) == INVALID_NAV_AREA)
		return;

	BotMoveTo(iClient, fLoc, FASTEST_ROUTE);

	if (GetVectorDistance(fOrigin, fLoc) < 50.0 && IsValidEntity(iCurrent))
		CS_DropWeapon(iClient, iCurrent, false);
}

stock void SetupDetour(GameData hGameData, const char[] szConf, HookMode eMode, DHookCallback hCallback)
{
	DynamicDetour hDetour = DynamicDetour.FromConf(hGameData, szConf);
	if (hDetour == null || !hDetour.Enable(eMode, hCallback))
		SetFailState("Failed to setup detour for %s", szConf);
	delete hDetour;
}

stock bool SetupOptionalDetour(GameData hGameData, const char[] szConf, HookMode eMode, DHookCallback hCallback)
{
	DynamicDetour hDetour = DynamicDetour.FromConf(hGameData, szConf);
	if (hDetour == null)
	{
		LogError("Optional detour %s is unavailable; related behavior will degrade gracefully.", szConf);
		return false;
	}

	if (!hDetour.Enable(eMode, hCallback))
	{
		LogError("Optional detour %s failed to enable; related behavior will degrade gracefully.", szConf);
		delete hDetour;
		return false;
	}

	delete hDetour;
	return true;
}

stock int SetupOffset(GameData hGameConfig, const char[] szName)
{
	int iOffset = hGameConfig.GetOffset(szName);
	if (iOffset == -1)
		SetFailState("Failed to get %s offset.", szName);
	return iOffset;
}

stock Address SetupAddress(GameData hGameConfig, const char[] szName)
{
	Address pAddr = hGameConfig.GetAddress(szName);
	if (!pAddr)
		SetFailState("Failed to get %s address.", szName);
	return pAddr;
}

stock int GetClientFromAddress(Address pEntity)
{
	if (pEntity == Address_Null)
		return -1;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetEntityAddress(i) == pEntity)
			return i;
	}

	return -1;
}

int GetFriendsWithPrimary(int iClient)
{
	int iCount = 0;
	int iTeam = GetClientTeam(iClient);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == iClient || !IsValidClient(i))
			continue;

		if (GetClientTeam(i) != iTeam)
			continue;

		if (IsValidEntity(GetPlayerWeaponSlot(i, CS_SLOT_PRIMARY)))
			iCount++;
	}

	return iCount;
}

stock int GetNearestEntity(int iClient, const char[] szClassname)
{
	int iNearestEntity = -1, iEntity = -1;
	float fClientOrigin[3], fEntityOrigin[3], fDistance, fNearestDistance = -1.0;

	GetClientAbsOrigin(iClient, fClientOrigin);

	while ((iEntity = FindEntityByClassname(iEntity, szClassname)) != -1)
	{
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fEntityOrigin);
		fDistance = GetVectorDistance(fClientOrigin, fEntityOrigin);

		if (fDistance < fNearestDistance || fNearestDistance == -1.0)
		{
			iNearestEntity = iEntity;
			fNearestDistance = fDistance;
		}
	}

	return iNearestEntity;
}

stock int ReplaceWeapon(int iClient, int iSlot, const char[] szClass, bool bHandleMoney = false)
{
	if (bHandleMoney)
	{
		char szAlias[64];
		strcopy(szAlias, sizeof(szAlias), szClass);
		ReplaceString(szAlias, sizeof(szAlias), "weapon_", "");
		CSWeaponID eWeaponID = CS_AliasToWeaponID(szAlias);
		if (eWeaponID != CSWeapon_NONE)
		{
			int iPrice = CS_GetWeaponPrice(iClient, eWeaponID);
			AddMoney(iClient, -iPrice, true, true, szClass);
		}
	}

	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);

	if (IsValidEntity(iWeapon))
	{
		if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") != iClient)
			SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);

		CS_DropWeapon(iClient, iWeapon, false, true);
		AcceptEntityInput(iWeapon, "Kill");
	}

	iWeapon = GivePlayerItem(iClient, szClass);

	if (IsValidEntity(iWeapon))
		EquipPlayerWeapon(iClient, iWeapon);

	return iWeapon;
}

bool IsPlayerReloading(int iClient)
{
	if (!IsValidEntity(g_iActiveWeapon[iClient]))
		return false;

	if (GetEntProp(g_iActiveWeapon[iClient], Prop_Data, "m_bInReload"))
		return true;

	if (GetEntProp(g_iActiveWeapon[iClient], Prop_Data, "m_iClip1") == 0)
		return true;

	if (GetEntPropFloat(g_iActiveWeapon[iClient], Prop_Send, "m_flNextPrimaryAttack") > GetGameTime())
		return true;

	return false;
}

public void TossCheapDrop(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return;

	int iPrimary = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
	if (IsValidEntity(iPrimary))
		CS_DropWeapon(iClient, iPrimary, true);
}

public void BeginQuickSwitch(int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if (!IsValidClient(iClient))
        return;

    SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE));
    RequestFrame(FinishQuickSwitch, iUserId);
}

public void FinishQuickSwitch(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);

	if (!IsValidClient(iClient))
		return;

	SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY));
}

public Action Timer_AvoidSelfFlash(Handle hTimer, any iUserId)
{
	int iClient = GetClientOfUserId(iUserId);
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient))
		return Plugin_Stop;

	float fEyePos[3], fEyeAngles[3], fForward[3], fAway[3];
	GetClientEyePosition(iClient, fEyePos);
	GetClientEyeAngles(iClient, fEyeAngles);

	fEyeAngles[1] += (Math_GetRandomFloat(-1.0, 1.0) < 0.0) ? -120.0 : 120.0;
	GetAngleVectors(fEyeAngles, fForward, NULL_VECTOR, NULL_VECTOR);

	fAway[0] = fEyePos[0] + fForward[0] * 1000.0;
	fAway[1] = fEyePos[1] + fForward[1] * 1000.0;
	fAway[2] = fEyePos[2] + fForward[2] * 1000.0;

	BotSetLookAt(iClient, "Avoid Flashbang", fAway, PRIORITY_UNINTERRUPTABLE, 1.5, false, 5.0, false);
	return Plugin_Stop;
}

public Action Timer_EnableSwitch(Handle hTimer, any iUserId)
{
	int iClient = GetClientOfUserId(iUserId);

	if (IsValidClient(iClient))
		g_bDontSwitch[iClient] = false;

	return Plugin_Stop;
}

public void SelectBestTargetPos(int iClient, float fTargetPos[3])
{
	if (!IsValidClient(g_iTarget[iClient]) || !IsPlayerAlive(g_iTarget[iClient]))
		return;

	int iHeadBone = LookupBone(g_iTarget[iClient], "head_0");
	int iSpineBone = LookupBone(g_iTarget[iClient], "spine_3");
	if (iHeadBone < 0 || iSpineBone < 0)
		return;

	bool bShootSpine;
	float fHead[3], fBody[3], fBad[3];
	GetBonePosition(g_iTarget[iClient], iHeadBone, fHead, fBad);
	GetBonePosition(g_iTarget[iClient], iSpineBone, fBody, fBad);

	fHead[2] += 4.0;

	bool bHeadVisible = BotIsVisible(iClient, fHead, false, -1);
	bool bBodyVisible = bHeadVisible && BotIsVisible(iClient, fBody, false, -1);

	if (bHeadVisible)
	{
		if (bBodyVisible)
		{
			if (!IsValidEntity(g_iActiveWeapon[iClient]))
				return;

			int iDefIndex = GetEntProp(g_iActiveWeapon[iClient], Prop_Send, "m_iItemDefinitionIndex");

			switch (iDefIndex)
			{
				case DEFIDX_AK47, DEFIDX_AUG, DEFIDX_FAMAS, DEFIDX_GALIL, DEFIDX_M249, DEFIDX_M4A4, DEFIDX_MAC10, DEFIDX_P90, DEFIDX_MP5SD, DEFIDX_UMP45, DEFIDX_XM1014, DEFIDX_BIZON, DEFIDX_MAG7, DEFIDX_NEGEV, DEFIDX_SAWEDOFF, DEFIDX_MP7, DEFIDX_MP9, DEFIDX_NOVA, DEFIDX_SG556, DEFIDX_M4A1S:
				{
					float fTargetDistance = GetVectorDistance(g_fBotOrigin[iClient], fHead);
					if (IsItMyChance(70.0) && fTargetDistance < 2000.0)
						bShootSpine = true;
				}
				case DEFIDX_AWP, DEFIDX_G3SG1, DEFIDX_SCAR20:
				{
					bShootSpine = true;
				}
			}
		}
	}
	else
	{
		// Head wasn't visible, check other bones.
		for (int b = 0; b < sizeof(g_szBoneNames); b++)
		{
			int iBone = LookupBone(g_iTarget[iClient], g_szBoneNames[b]);
			if (iBone < 0)
				continue;

			GetBonePosition(g_iTarget[iClient], iBone, fHead, fBad);

			if (BotIsVisible(iClient, fHead, false, -1))
				break;
			else
				fHead[2] = 0.0;
		}
	}

	if (bShootSpine)
		Array_Copy(fBody, fTargetPos, 3);
	else
		Array_Copy(fHead, fTargetPos, 3);
}

stock void GetViewVector(const float fVecAngle[3], float fOutPut[3])
{
    fOutPut[0] = Cosine(fVecAngle[1] * FLOAT_PI / 180.0);
    fOutPut[1] = Sine(fVecAngle[1] * FLOAT_PI / 180.0);
    fOutPut[2] = -Sine(fVecAngle[0] * FLOAT_PI / 180.0);
}

stock bool IsPointVisible(float fStart[3], float fEnd[3])
{
    TR_TraceRayFilter(fStart, fEnd, MASK_VISIBLE_AND_NPCS, RayType_EndPoint, TraceEntityFilterStuff);
    return TR_GetFraction() >= 0.9;
}

public bool TraceEntityFilterStuff(int iEntity, int iMask)
{
    return iEntity > MaxClients;
}

stock bool LineGoesThroughSmoke(const float fFrom[3], const float fTo[3])
{
    return SDKCall(g_hIsLineBlockedBySmoke, g_pTheBots, fFrom, fTo, 1.0);
}

stock bool IsRifleOrHeavy(int iDefIndex)
{
	switch (iDefIndex)
	{
		case DEFIDX_AK47, DEFIDX_AUG, DEFIDX_FAMAS, DEFIDX_GALIL, DEFIDX_M249, DEFIDX_M4A4, DEFIDX_NEGEV, DEFIDX_SG556, DEFIDX_M4A1S:
			return true;
	}
	return false;
}

stock bool IsSprayWeapon(int iDefIndex)
{
	switch (iDefIndex)
	{
		case DEFIDX_MAC10, DEFIDX_P90, DEFIDX_MP5SD, DEFIDX_UMP45, DEFIDX_XM1014, DEFIDX_BIZON, DEFIDX_MP7, DEFIDX_MP9:
			return true;
	}
	return false;
}

stock bool IsPluginFireCoveredWeapon(int iDefIndex)
{
	return IsRifleOrHeavy(iDefIndex) || IsSprayWeapon(iDefIndex);
}

int GetTeamAverageMoney(int iTeam)
{
	int iTotal, iCount;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != iTeam)
			continue;

		iTotal += GetEntProp(i, Prop_Send, "m_iAccount");
		iCount++;
	}
	return iCount > 0 ? iTotal / iCount : 0;
}

stock bool IsSafe(int iClient)
{
	return IsFakeClient(iClient) && (GetGameTime() - g_fFreezeTimeEnd) < GetEntDataFloat(iClient, g_iBotSafeTimeOffset);
}

stock TaskType GetTask(int iClient)
{
    return IsFakeClient(iClient) ? view_as<TaskType>(GetEntData(iClient, g_iBotTaskOffset)) : view_as<TaskType>(-1);
}

stock DispositionType GetDisposition(int iClient)
{
    return IsFakeClient(iClient) ? view_as<DispositionType>(GetEntData(iClient, g_iBotDispositionOffset)) : view_as<DispositionType>(-1);
}

stock void SetDisposition(int iClient, DispositionType eDisposition)
{
	if(!IsFakeClient(iClient))
		return;

	SetEntData(iClient, g_iBotDispositionOffset, eDisposition);
}

void ResetTeammateColorAssignments()
{
	delete g_smHumanTeammateColors;
	g_smHumanTeammateColors = new StringMap();
	Array_Fill(g_iPlayerColor, MaxClients + 1, -1);
}

bool GetHumanTeammateColorKey(int iClient, char[] szKey, int iSize)
{
	if (IsFakeClient(iClient))
		return false;

	if (!GetClientAuthId(iClient, AuthId_Steam2, szKey, iSize, true))
		return false;

	if (szKey[0] == '\0' || StrEqual(szKey, "BOT") || StrEqual(szKey, "STEAM_ID_PENDING"))
		return false;

	return true;
}

bool IsTeammateColorInUse(int iTeam, int iColor, int iIgnoreClient)
{
	for (int iOther = 1; iOther <= MaxClients; iOther++)
	{
		if (iOther == iIgnoreClient || !IsValidClient(iOther))
			continue;

		if (GetClientTeam(iOther) == iTeam && g_iPlayerColor[iOther] == iColor)
			return true;
	}

	return false;
}

int FindAvailableTeammateColor(int iTeam, int iClient)
{
	int iAvailableColors[TEAMMATE_COLOR_COUNT];
	int iAvailableCount = 0;

	for (int iColor = 0; iColor < TEAMMATE_COLOR_COUNT; iColor++)
	{
		if (!IsTeammateColorInUse(iTeam, iColor, iClient))
		{
			iAvailableColors[iAvailableCount] = iColor;
			iAvailableCount++;
		}
	}

	if (iAvailableCount == 0)
		return -1;

	return iAvailableColors[Math_GetRandomInt(0, iAvailableCount - 1)];
}

bool EnsurePlayerTeammateColor(int iClient, int iTeam)
{
	int iColor = g_iPlayerColor[iClient];
	if (iColor >= 0 && iColor < TEAMMATE_COLOR_COUNT && !IsTeammateColorInUse(iTeam, iColor, iClient))
		return true;

	g_iPlayerColor[iClient] = -1;

	char szKey[32];
	bool bHasHumanKey = GetHumanTeammateColorKey(iClient, szKey, sizeof(szKey));

	if (!IsFakeClient(iClient) && !bHasHumanKey)
		return false;

	if (bHasHumanKey && g_smHumanTeammateColors.GetValue(szKey, iColor)
		&& iColor >= 0 && iColor < TEAMMATE_COLOR_COUNT
		&& !IsTeammateColorInUse(iTeam, iColor, iClient))
	{
		g_iPlayerColor[iClient] = iColor;
		return true;
	}

	iColor = FindAvailableTeammateColor(iTeam, iClient);
	if (iColor == -1)
		return false;

	g_iPlayerColor[iClient] = iColor;

	if (bHasHumanKey)
		g_smHumanTeammateColors.SetValue(szKey, iColor);

	return true;
}

stock void SetPlayerTeammateColor(int iClient)
{
	if (!IsValidClient(iClient))
		return;

	int iTeam = GetClientTeam(iClient);
	if (iTeam <= CS_TEAM_SPECTATOR)
		return;

	EnsurePlayerTeammateColor(iClient, iTeam);

	if (g_iPlayerResourceEntity != -1 && IsValidEntity(g_iPlayerResourceEntity))
		OnThinkPost(g_iPlayerResourceEntity);
}

public void AutoStop(int iClient, float fVel[3], float fAngles[3])
{
    float fPlayerVelocity[3], fVelAngle[3];
    GetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fPlayerVelocity);

    float fSpeed = GetVectorLength(fPlayerVelocity);
    if (fSpeed < 1.0)
        return;

    GetVectorAngles(fPlayerVelocity, fVelAngle);
    fVelAngle[1] = fAngles[1] - fVelAngle[1];

    float fDirForward[3];
    GetAngleVectors(fVelAngle, fDirForward, NULL_VECTOR, NULL_VECTOR);

    fVel[0] = -fDirForward[0] * fSpeed;
    fVel[1] = -fDirForward[1] * fSpeed;
}

stock int GetNumWinsToClinch()
{
	int iOvertimePlaying = GameRules_GetProp("m_nOvertimePlaying");
	int iMaxRounds = g_cvMaxRounds.IntValue;
	bool bCanClinch = g_cvCanClinch.BoolValue;
	int iOvertimeMaxRounds = g_cvOTMaxRounds.IntValue;

	return (iMaxRounds > 0 && bCanClinch) ? (iMaxRounds / 2) + 1 + iOvertimePlaying * (iOvertimeMaxRounds / 2) : -1;
}

stock bool IsTeamForcing(int iTeam)
{
	return (iTeam == CS_TEAM_T) ? g_bForceT : g_bForceCT;
}

stock bool IsResetRound()
{
	int iMaxRounds = g_cvMaxRounds.IntValue;
	if (g_iCurrentRound == 0 || g_iCurrentRound == iMaxRounds / 2)
		return true;

	int iOTHalf = g_cvOTMaxRounds.IntValue / 2;
	if (iOTHalf > 0 && g_iCurrentRound >= iMaxRounds && (g_iCurrentRound - iMaxRounds) % iOTHalf == 0)
		return true;

	return false;
}

stock bool IsItMyChance(float fChance)
{
    return (fChance > 0.0) && (Math_GetRandomFloat(0.0, 100.0) <= fChance);
}

stock bool IsValidClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsClientSourceTV(iClient));
}

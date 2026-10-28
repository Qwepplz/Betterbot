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
#define SCRIPT_MOVE_INTERVAL 0.35
#define NADE_SOLVE_TRACE_BUDGET_PER_FRAME 32
#define NADE_SOLVE_MAX_ACTIVE_JOBS 2
#define NADE_SOLVE_RETRY_INTERVAL 0.25
#define NADE_SOLVE_TIME_BUDGET_PER_FRAME 0.0005
#define NADE_SOLVE_TIMEOUT_BASE 3.0
#define NADE_SOLVE_TIMEOUT_PER_EXTRA_JOB 1.0
#define NADE_SOLVE_TIMEOUT_MAX 8.0
#define NADE_SOLVE_ORIGIN_TOLERANCE 64.0
#define NADE_SOLVE_TARGET_TOLERANCE 96.0
#define NADE_SOLVE_CACHE_TTL 1.5
#define NADE_SOLVE_CACHE_SLOTS 2
#define NADE_SIMULATION_MAX_TIME 5.0
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

static const int g_iAllNades[] = {DEFIDX_HE, DEFIDX_MOLOTOV, DEFIDX_INCENDIARY, DEFIDX_FLASH, DEFIDX_SMOKE};
static const int g_iDenialNades[] = {DEFIDX_MOLOTOV, DEFIDX_INCENDIARY, DEFIDX_HE};

BotReactionState g_sBotReaction[MAXPLAYERS+1];
int g_iReactionNextCycle, g_iReactionCycleId[MAXPLAYERS+1], g_iReactionCmdNum[MAXPLAYERS+1], g_iReactionPreButtons[MAXPLAYERS+1];
bool g_bReactionReadyLogged[MAXPLAYERS+1];
char g_szCrosshairCode[MAXPLAYERS+1][35], g_szPreviousBuy[MAXPLAYERS+1][128];
bool g_bIsBombScenario, g_bIsHostageScenario, g_bFreezetimeEnd, g_bBombPlanted, g_bRoundDecided, g_bHalftimeSwitch, g_bIsCompetitive;
int g_iLooseBombDropper = -1;
bool g_bForceT, g_bForceCT;
bool g_bUseCZ75[MAXPLAYERS+1], g_bUseUSP[MAXPLAYERS+1], g_bUseM4A1S[MAXPLAYERS+1], g_bDontSwitch[MAXPLAYERS+1], g_bDropWeapon[MAXPLAYERS+1], g_bHasGottenDrop[MAXPLAYERS+1], g_bCheapDrop[MAXPLAYERS+1], g_bBuyingCheapDrop[MAXPLAYERS+1];
bool g_bIsProBot[MAXPLAYERS+1], g_bThrowGrenade[MAXPLAYERS+1], g_bUncrouch[MAXPLAYERS+1], g_bSaveLocked[MAXPLAYERS+1], g_bIssuingSaveMove[MAXPLAYERS+1];
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
int g_iProfileRank[MAXPLAYERS+1], g_iPlayerColor[MAXPLAYERS+1], g_iTarget[MAXPLAYERS+1], g_iPrevTarget[MAXPLAYERS+1], g_iDoingSmokeNum[MAXPLAYERS+1], g_iActiveWeapon[MAXPLAYERS+1];
int g_iCurrentRound, g_iRoundsPlayed, g_iCTScore, g_iTScore;
int g_iProfileRankOffset, g_iPlayerColorOffset;
int g_iBotTargetSpotOffset, g_iBotNearbyEnemiesOffset, g_iFireWeaponOffset, g_iEnemyVisibleOffset, g_iBotProfileOffset, g_iBotSafeTimeOffset, g_iBotEnemyOffset, g_iBotLookAtSpotStateOffset, g_iBotLookAtInhibitUntilOffset, g_iBotMoraleOffset, g_iBotTaskOffset, g_iBotDispositionOffset;
float g_fBotOrigin[MAXPLAYERS+1][3], g_fTargetPos[MAXPLAYERS+1][3], g_fNadeTarget[MAXPLAYERS+1][3];
float g_fOriginalNoisePos[MAXPLAYERS+1][3];
float g_fRoundStart, g_fFreezeTimeEnd;
float g_fLookAngleMaxAccel[MAXPLAYERS+1], g_fReactionTime[MAXPLAYERS+1], g_fAggression[MAXPLAYERS+1], g_fShootTimestamp[MAXPLAYERS+1], g_fThrowNadeTimestamp[MAXPLAYERS+1], g_fCrouchTimestamp[MAXPLAYERS+1];
float g_fSniperRetreatCooldown[MAXPLAYERS+1];
float g_fLastNadeSolveOrigin[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS][3], g_fLastNadeSolveTarget[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS][3], g_fLastNadeSolveLookAt[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS][3], g_fLastNadeSolveTime[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS];
int g_iLastNadeSolveDefIndex[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS];
bool g_bLastNadeSolveValid[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS], g_bLastNadeSolveSuccess[MAXPLAYERS+1][NADE_SOLVE_CACHE_SLOTS];
float g_fBombPos[3];
float g_fBombsitePositions[16][3];
int g_iBombsiteCount;
StringMap g_smHumanTeammateColors;
enum ScriptAction
{
	ScriptAction_None = 0,
	ScriptAction_Nade,
	ScriptAction_PostPlantNade,
	ScriptAction_Peek,
	ScriptAction_Angle,
	ScriptAction_Fake
}

enum NadeSolvePhase
{
	NadeSolve_Idle,
	NadeSolve_Coarse,
	NadeSolve_Fine,
	NadeSolve_Final
}

enum NadeCandidateState
{
	NadeCandidate_Running,
	NadeCandidate_Finished,
	NadeCandidate_Failed
}

enum NadeSolveRequestResult
{
	NadeRequest_Rejected,
	NadeRequest_Queued,
	NadeRequest_Submitted,
	NadeRequest_Busy
}

enum struct NadeSolveJob
{
	int jobId;
	int parentJobId;
	int traces;
	int candidates;
	int loggedEpoch;
	int startEpoch;
	char caseId[65];
	NadeSolvePhase phase;
	NadeSolvePhase resumePhase;
	float resumePitch;
	int clientUserId;
	int grenadeEntRef;
	int grenadeDefIndex;
	float requestTime;
	float deadlineTime;
	float startOrigin[3];
	float eyePosition[3];
	float target[3];
	bool hasFallbackTarget;
	bool fallbackAttempted;
	float fallbackTarget[3];
	float yaw;
	float currentPitch;
	float bestPitch;
	float fineEndPitch;
	float bestDistance;
	bool candidateActive;
	float candidatePosition[3];
	float candidateVelocity[3];
	float candidateTime;
	float candidateNextThink;
	int candidateBounces;
	bool candidatePendingPush;
	float candidateRemainingTime;
}

enum struct NadeSolvePerfStats
{
	int activeFrames;
	int traces;
	int maxTracesPerFrame;
	int timeBudgetHits;
	int traceBudgetHits;
	int completedJobs;
	int failedJobs;
	int timedOutJobs;
	int maxQueuedJobs;
	int schedulerVisits;
	int nadeFrames;
	float totalNadeFrameSeconds;
	float maxNadeFrameSeconds;
	float totalFrameSeconds;
	float maxFrameSeconds;
}

bool g_bNadeThrowPending[MAXPLAYERS+1];
ScriptAction g_iScriptAction[MAXPLAYERS+1];
int g_iScriptActionIndex[MAXPLAYERS+1];
float g_fScriptActionStart[MAXPLAYERS+1];
float g_fScriptActionLastPos[MAXPLAYERS+1][3];
float g_fScriptActionLastMoveTime[MAXPLAYERS+1];
float g_fScriptNextMoveAt[MAXPLAYERS+1];
float g_fLegacyDefaultNadeActionStart[MAXPLAYERS+1];
float g_fLegacyDefaultNadeLastPos[MAXPLAYERS+1][3];
float g_fLegacyDefaultNadeLastMoveTime[MAXPLAYERS+1];
NadeSolveJob g_sNadeSolveJobs[MAXPLAYERS+1];
int g_iNadeSolveClients[NADE_SOLVE_MAX_ACTIVE_JOBS];
int g_iNadeSolveRoundRobinSlot;
float g_fNadeSolveRetryAt[MAXPLAYERS+1];
int g_iNadeRequestsBusy;
int g_iNadeSolveActiveCount;
NadeSolvePerfStats g_sNadeSolvePerf;
int g_iNadeJobSequence;
int g_iNadeEpoch = 1;
int g_iNadeCarryIn;
int g_iNadeJobsStarted;
int g_iNadeJobsEnded[4];
int g_iNadeRequests[5];
int g_iNadeParentContext[MAXPLAYERS+1];
bool g_bNadeDetail;
char g_szNadeInvalidReason[MAXPLAYERS+1][40];
char g_szNadeCleanupContext[40];
StringMap g_smNadeEndReasons;
enum struct NadeThrowContext
{
	bool active;
	bool lookDeferred;
	int throwId;
	int jobId;
	int userId;
	int weaponRef;
	int defIndex;
	int projectileRef;
	int effectRef;
	int dispatches;
	int switchRequests;
	int equipRequests;
	float submittedAt;
	float target[3];
	char source[16];
	char caseId[65];
}
enum struct NadeProbeContext
{
	int userId;
	int defIndex;
	MoveType moveType;
	int createdWeaponRef;
	bool referenceValid;
	float origin[3];
	float angles[3];
	float viewOffset[3];
	float target[3];
	float lastAttempt;
	char caseId[65];
}
NadeThrowContext g_sNadeThrows[MAXPLAYERS+1];
NadeProbeContext g_sNadeProbes[MAXPLAYERS+1];
int g_iNadeThrowSequence;
int g_iNadeProbeCount;
enum NadeThrowResult
{
	NadeThrow_Started,
	NadeThrow_Succeeded,
	NadeThrow_OffTarget,
	NadeThrow_Failed
}
int g_iNadeThrowCounts[2][NadeThrowResult];
int g_iNadeThrowCarry[2];
static const char g_szNadeEndNames[][] = {"submitted", "no_solution", "timed_out", "cancelled"};

enum NadeSolveEnd
{
	NadeEnd_Submitted,
	NadeEnd_NoSolution,
	NadeEnd_TimedOut,
	NadeEnd_Cancelled
}
bool g_bPeekAssigned[MAXPLAYERS+1];
bool g_bTeamPeekUsedRound[4];
bool g_bTeamPeekRollResolved[4];
bool g_bTeamPeekRollPassed[4];
bool g_bAngleAssigned[MAXPLAYERS+1];
ConVar g_cvGameMode;
ConVar g_cvGameType;
ConVar g_cvRecoilScale;
ConVar g_cvMaxRounds;
ConVar g_cvOTMaxRounds;
ConVar g_cvHalftime;
ConVar g_cvCanClinch;
ConVar g_cvFreezeTime;
ConVar g_cvGravity;
ConVar g_cvMolotovDetonateTime;
ConVar g_cvMolotovMaxSlope;
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
Handle g_hBotThrowGrenade;
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
float g_fNadeLineupCooldown[MAXPLAYERS+1];
float g_fRetakeSaveDebugTime[MAXPLAYERS+1];
float g_fAttackDebugTime[MAXPLAYERS+1];
#define LEGACY_DEFAULT_NADE_STUCK_TIMEOUT 5.0
#define LEGACY_DEFAULT_NADE_RETRY_COOLDOWN 25.0
#define SCRIPT_LINEUP_FAILURE_COOLDOWN 5.0
#define SCRIPT_PEEK_OPENING_WINDOW 35.0
#define SCRIPT_PEEK_CHANCE 35.0
#define SCRIPT_PEEK_ACTION_TIMEOUT 12.0
#define SCRIPT_PEEK_START_DISTANCE 40.0
#define SCRIPT_PEEK_START_SPEED 25.0
#define SCRIPT_PEEK_FREEZE_ROUNDS 2
#define SCRIPT_ANGLE_LIVE_START 15.0
#define SCRIPT_ANGLE_LIVE_END 45.0
#define SCRIPT_ANGLE_LIVE_CANCEL 60.0
#define SCRIPT_ANGLE_ACTION_TIMEOUT 25.0
#define SCRIPT_ANGLE_TEAM_ACTIVE_CAP 2
#define STRATEGY_START_DISTANCE 45.0
#define STRATEGY_START_SPEED 20.0

enum struct NadeLineup
{
	float fPos[3];
	float fLook[3];
	int iDefIndex;
	char szReplay[128];
	float fTimestamp;
	int iTeam;
}

enum struct ScriptLineup
{
	float fPos[3];
	float fLook[3];
	int iDefIndex;
	char szReplay[128];
	float fTimestamp;
	float fClaimTime;
	float fFailureUntil;
	int iClaimClient;
	int iFreezeUntilRound;
	int iTeam;
}

enum struct StrategyConfig
{
	float fChance;
	int iMinPlayers;
	float fTimeout;
	int iRoleStart;
	int iRoleCount;
}

enum struct StrategyRole
{
	float fPos[3];
	float fLook[3];
	char szReplay[128];
	int iUtility1DefIndex;
	int iUtility1Amount;
	int iUtility2DefIndex;
	int iUtility2Amount;
	int iClient;
}

ArrayList g_aNades;
ArrayList g_aPistolNades;
ArrayList g_aPostPlantNades;
ArrayList g_aPeeks;
ArrayList g_aAngles;
ArrayList g_aStrategies;
ArrayList g_aStrategyRoles;
bool g_bStrategyStarted;
int g_iActiveStrategy = -1;
int g_iStrategyConfigMode = -1;
float g_fStrategyAssignTime;
int g_iClientStrategyRole[MAXPLAYERS + 1] = {-1, ...};
char g_szStrategyConfigMap[PLATFORM_MAX_PATH];

static const char g_szTopBotNames[][] =
{
    "sh1ro", "ZywOo", "ropz", "donk", "m0NESY"
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

enum GrenadeTossState
{
	NOT_THROWING,				///< not yet throwing
	START_THROW,				///< lining up throw
	THROW_LINED_UP,				///< pause for a moment when on-line
	FINISH_THROW				///< throwing
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
    g_cvGravity = FindConVar("sv_gravity");
    g_cvMolotovDetonateTime = FindConVar("molotov_throw_detonate_time");
    g_cvMolotovMaxSlope = FindConVar("weapon_molotov_maxdetonateslope");
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
    RegServerCmd("bb_nade_perf", Command_NadePerf);
    RegServerCmd("bb_nade_perf_reset", Command_NadePerfReset);
	RegServerCmd("bb_nade_probe", Command_NadeProbe);
	char szNadeEvents[][] = {"hegrenade_detonate", "flashbang_detonate", "smokegrenade_detonate", "decoy_started", "inferno_startburn"};
	for (int iEvent = 0; iEvent < sizeof(szNadeEvents); iEvent++)
	{
		if (!HookEventEx(szNadeEvents[iEvent], OnNadeEffect, EventHookMode_Pre))
			LogError("[NadeProbe] event_hook_failed event=%s", szNadeEvents[iEvent]);
	}
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

    if (szLogo[0] != '\0')
    {
        int iLogoSlot = strcmp(szSide, "ct", false) == 0 ? 1 : 2;
        ServerCommand("mp_teamlogo_%d %s", iLogoSlot, szLogo);
    }

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

public void OnGameFrame()
{
	float fNadeStartedAt = GetEngineTime();
	UpdateNadeObservation();
	if (g_iNadeSolveActiveCount <= 0)
	{
		RecordNadeFrameCost(fNadeStartedAt);
		return;
	}

	int iTraceBudget = NADE_SOLVE_TRACE_BUDGET_PER_FRAME;
	float fStartedAt = GetEngineTime();
	float fDeadline = fStartedAt + NADE_SOLVE_TIME_BUDGET_PER_FRAME;
	bool bTimeBudgetHit = false;
	int iCursor = g_iNadeSolveRoundRobinSlot;
	int iInactiveSlots;
	int iValidatedJobs[NADE_SOLVE_MAX_ACTIVE_JOBS];

	for (int iTurn = 0; iTurn < NADE_SOLVE_MAX_ACTIVE_JOBS * NADE_SOLVE_TRACE_BUDGET_PER_FRAME && iTraceBudget > 0; iTurn++)
	{
		int iSlot = iCursor;
		iCursor = (iCursor + 1) % NADE_SOLVE_MAX_ACTIVE_JOBS;
		g_sNadeSolvePerf.schedulerVisits++;
		int iClient = g_iNadeSolveClients[iSlot];
		if (iClient == 0)
		{
			iInactiveSlots++;
			if (iInactiveSlots >= NADE_SOLVE_MAX_ACTIVE_JOBS)
				break;
			continue;
		}

		iInactiveSlots = 0;
		int iJobId = g_sNadeSolveJobs[iClient].jobId;
		if (iValidatedJobs[iSlot] != iJobId)
		{
			iValidatedJobs[iSlot] = iJobId;
			if (!IsNadeSolveJobRuntimeValid(iClient))
			{
				bool bTimedOut = GetGameTime() > g_sNadeSolveJobs[iClient].deadlineTime;
				CancelNadeSolveJob(iClient, g_szNadeInvalidReason[iClient]);
				if (bTimedOut)
					g_sNadeSolvePerf.timedOutJobs++;
				continue;
			}
		}

		if (GetEngineTime() >= fDeadline)
		{
			bTimeBudgetHit = true;
			break;
		}

		if (g_iNadeSolveClients[iSlot] == iClient && g_sNadeSolveJobs[iClient].jobId == iJobId)
			AdvanceNadeSolveJob(iClient, iTraceBudget);
	}

	g_iNadeSolveRoundRobinSlot = iCursor;

	int iUsedTraces = NADE_SOLVE_TRACE_BUDGET_PER_FRAME - iTraceBudget;
	float fElapsed = GetEngineTime() - fStartedAt;
	g_sNadeSolvePerf.activeFrames++;
	g_sNadeSolvePerf.traces += iUsedTraces;
	g_sNadeSolvePerf.totalFrameSeconds += fElapsed;
	if (iUsedTraces > g_sNadeSolvePerf.maxTracesPerFrame)
		g_sNadeSolvePerf.maxTracesPerFrame = iUsedTraces;
	if (fElapsed > g_sNadeSolvePerf.maxFrameSeconds)
		g_sNadeSolvePerf.maxFrameSeconds = fElapsed;
	if (iTraceBudget <= 0)
		g_sNadeSolvePerf.traceBudgetHits++;
	if (bTimeBudgetHit)
		g_sNadeSolvePerf.timeBudgetHits++;
	RecordNadeFrameCost(fNadeStartedAt);
}

void RecordNadeFrameCost(float fStartedAt)
{
	float fElapsed = GetEngineTime() - fStartedAt;
	g_sNadeSolvePerf.nadeFrames++;
	g_sNadeSolvePerf.totalNadeFrameSeconds += fElapsed;
	if (fElapsed > g_sNadeSolvePerf.maxNadeFrameSeconds)
		g_sNadeSolvePerf.maxNadeFrameSeconds = fElapsed;
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

    char szMap[PLATFORM_MAX_PATH];
    GetCurrentMap(szMap, sizeof(szMap));
    GetMapDisplayName(szMap, szMap, sizeof(szMap));
    ParseMapNades(szMap);
	ParseScriptLineups("configs/bot_nades_pistol.txt", "Nades", szMap, g_aPistolNades);
	ParseScriptLineups("configs/bot_nades_postplant.txt", "Nades", szMap, g_aPostPlantNades);
	ParseScriptLineups("configs/bot_peeks.txt", "Peeks", szMap, g_aPeeks);
	ParseScriptLineups("configs/bot_angles.txt", "Angles", szMap, g_aAngles);

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

bool IsNadeSolveActive(int iClient)
{
	return iClient >= 1 && iClient <= MaxClients && g_sNadeSolveJobs[iClient].phase != NadeSolve_Idle;
}

void GetNadeTypeName(int iDefIndex, char[] szType, int iLength)
{
	switch (iDefIndex)
	{
		case DEFIDX_HE: strcopy(szType, iLength, "he");
		case DEFIDX_FLASH: strcopy(szType, iLength, "flash");
		case DEFIDX_SMOKE: strcopy(szType, iLength, "smoke");
		case DEFIDX_MOLOTOV: strcopy(szType, iLength, "molotov");
		case DEFIDX_INCENDIARY: strcopy(szType, iLength, "incendiary");
		case DEFIDX_DECOY: strcopy(szType, iLength, "decoy");
		default: strcopy(szType, iLength, "unknown");
	}
}

void LogNadeJob(int iClient, const char[] szEvent, const char[] szResult = "-", const char[] szReason = "-")
{
	if (!g_bNadeDetail || !IsNadeSolveActive(iClient))
		return;
	char szType[16];
	GetNadeTypeName(g_sNadeSolveJobs[iClient].grenadeDefIndex, szType, sizeof(szType));
	float fOriginDelta = -1.0;
	int iEnemyVisible = -1, iNearbyEnemies = -1, iTeam = -1;
	int iGet5State = -1;
	if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") == FeatureStatus_Available)
		iGet5State = view_as<int>(Get5_GetGameState());
	if (IsValidClient(iClient))
	{
		float fOrigin[3];
		GetClientAbsOrigin(iClient, fOrigin);
		fOriginDelta = GetVectorDistance(fOrigin, g_sNadeSolveJobs[iClient].startOrigin);
		iTeam = GetClientTeam(iClient);
		if (IsFakeClient(iClient))
		{
			iEnemyVisible = GetEntData(iClient, g_iEnemyVisibleOffset);
			iNearbyEnemies = GetEntData(iClient, g_iBotNearbyEnemiesOffset);
		}
	}
	LogNadeDiagnostic("[NadeDiag] event=%s epoch=%d job_id=%d parent_job_id=%d case_id=%s userid=%d type=%s result=%s reason=%s phase=%d pitch=%.2f yaw=%.2f candidates=%d traces=%d elapsed=%.6f deadline=%.6f deadline_exceeded=%d origin_delta=%.2f weapon=%d team=%d enemy_visible=%d nearby_enemies=%d pending=%d throwing=%d script=%d lineup=%d strategy=%d save=%d force_save=%d round_decided=%d warmup=%d get5=%d best_distance=%.3f target_x=%.3f target_y=%.3f target_z=%.3f start_epoch=%d", szEvent, g_iNadeEpoch, g_sNadeSolveJobs[iClient].jobId, g_sNadeSolveJobs[iClient].parentJobId, g_sNadeSolveJobs[iClient].caseId, g_sNadeSolveJobs[iClient].clientUserId, szType, szResult, szReason, g_sNadeSolveJobs[iClient].phase, g_sNadeSolveJobs[iClient].currentPitch, g_sNadeSolveJobs[iClient].yaw, g_sNadeSolveJobs[iClient].candidates, g_sNadeSolveJobs[iClient].traces, GetGameTime() - g_sNadeSolveJobs[iClient].requestTime, g_sNadeSolveJobs[iClient].deadlineTime, GetGameTime() > g_sNadeSolveJobs[iClient].deadlineTime, fOriginDelta, g_sNadeSolveJobs[iClient].grenadeEntRef, iTeam, iEnemyVisible, iNearbyEnemies, g_bNadeThrowPending[iClient], g_bThrowGrenade[iClient], g_iScriptAction[iClient], g_iDoingSmokeNum[iClient], g_iClientStrategyRole[iClient], g_bSaveActiveCache[iClient], IsForceSaveEnabled(), g_bRoundDecided, IsWarmupPeriod(), iGet5State, g_sNadeSolveJobs[iClient].bestDistance, g_sNadeSolveJobs[iClient].target[0], g_sNadeSolveJobs[iClient].target[1], g_sNadeSolveJobs[iClient].target[2], g_sNadeSolveJobs[iClient].startEpoch);
	g_sNadeSolveJobs[iClient].loggedEpoch = g_iNadeEpoch;
}

void LogNadeDiagnostic(const char[] szFormat, any ...)
{
	if (!g_bNadeDetail)
		return;
	char szMessage[2048];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	LogMessage("%s", szMessage);
}

void LogNadeProbe(const char[] szFormat, any ...)
{
	if (!g_bNadeDetail)
		return;
	char szMessage[2048];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	LogMessage("%s", szMessage);
}

void LogNadeAccounting(const char[] szFormat, any ...)
{
	char szMessage[2048];
	VFormat(szMessage, sizeof(szMessage), szFormat, 2);
	LogMessage("%s", szMessage);
}

void LogNadeThrow(int iClient, const char[] szEvent, const char[] szReason = "-", const float fEffect[3] = NULL_VECTOR)
{
	if (!g_bNadeDetail)
		return;
	char szType[16];
	float fPosition[3];
	if (StrEqual(szEvent, "effect"))
		Array_Copy(fEffect, fPosition, 3);
	GetNadeTypeName(g_sNadeThrows[iClient].defIndex, szType, sizeof(szType));
	LogNadeDiagnostic("[NadeDiag] event=%s epoch=%d job_id=%d throw_id=%d userid=%d owner_userid=%d type=%s case_id=%s source=%s weapon=%d entity=%d effect_entity=%d dispatches=%d reason=%s target_x=%.3f target_y=%.3f target_z=%.3f x=%.3f y=%.3f z=%.3f", szEvent, g_iNadeEpoch, g_sNadeThrows[iClient].jobId, g_sNadeThrows[iClient].throwId, g_sNadeThrows[iClient].userId, g_sNadeThrows[iClient].userId, szType, g_sNadeThrows[iClient].caseId, g_sNadeThrows[iClient].source, g_sNadeThrows[iClient].weaponRef, g_sNadeThrows[iClient].projectileRef, g_sNadeThrows[iClient].effectRef, g_sNadeThrows[iClient].dispatches, szReason, g_sNadeThrows[iClient].target[0], g_sNadeThrows[iClient].target[1], g_sNadeThrows[iClient].target[2], fPosition[0], fPosition[1], fPosition[2]);
}

void CountNadeThrowResult(int iClient, NadeThrowResult eResult)
{
	if (!StrEqual(g_sNadeThrows[iClient].source, "solver"))
		return;
	g_iNadeThrowCounts[0][eResult]++;
	if (StrEqual(g_sNadeThrows[iClient].caseId, "-"))
		g_iNadeThrowCounts[1][eResult]++;
}

void EndNadeObservation(int iClient, const char[] szReason)
{
	if (iClient < 1 || iClient > MaxClients || !g_sNadeThrows[iClient].active)
		return;
	LogNadeThrow(iClient, "association_error", szReason);
	CountNadeThrowResult(iClient, NadeThrow_Failed);
	g_sNadeThrows[iClient].active = false;
}

void BeginNadeObservation(int iClient, int iWeapon, int iDefIndex, int iJobId, const char[] szSource, const float fTarget[3])
{
	EndNadeObservation(iClient, "submission_replaced");
	g_sNadeThrows[iClient].active = true;
	g_sNadeThrows[iClient].lookDeferred = false;
	g_sNadeThrows[iClient].throwId = ++g_iNadeThrowSequence;
	g_sNadeThrows[iClient].jobId = iJobId;
	g_sNadeThrows[iClient].userId = GetClientUserId(iClient);
	g_sNadeThrows[iClient].weaponRef = EntIndexToEntRef(iWeapon);
	g_sNadeThrows[iClient].defIndex = iDefIndex;
	g_sNadeThrows[iClient].projectileRef = INVALID_ENT_REFERENCE;
	g_sNadeThrows[iClient].effectRef = INVALID_ENT_REFERENCE;
	g_sNadeThrows[iClient].dispatches = 0;
	g_sNadeThrows[iClient].switchRequests = 0;
	g_sNadeThrows[iClient].equipRequests = 0;
	g_sNadeThrows[iClient].submittedAt = GetGameTime();
	Array_Copy(fTarget, g_sNadeThrows[iClient].target, 3);
	strcopy(g_sNadeThrows[iClient].source, sizeof(g_sNadeThrows[].source), szSource);
	strcopy(g_sNadeThrows[iClient].caseId, sizeof(g_sNadeThrows[].caseId), g_sNadeProbes[iClient].userId != 0 ? g_sNadeProbes[iClient].caseId : "-");
	CountNadeThrowResult(iClient, NadeThrow_Started);
	LogNadeThrow(iClient, "submit");
}

bool IsNadeProbeEnvironmentAllowed(int iClient)
{
	char szIp[32];
	GetCommandLineParam("-ip", szIp, sizeof(szIp));
	if (!StrEqual(szIp, "127.0.0.1") || FindConVar("hostport").IntValue != 27025)
		return false;
	if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") != FeatureStatus_Available || Get5_GetGameState() != Get5State_Live)
		return false;
	if (IsWarmupPeriod() || !g_bFreezetimeEnd || g_bRoundDecided || GameRules_GetProp("m_bFreezePeriod") != 0 || GameRules_GetProp("m_bMatchWaitingForResume") != 0)
		return false;
	for (int iOther = 1; iOther <= MaxClients; iOther++)
	{
		if (IsClientConnected(iOther) && !IsFakeClient(iOther) && !IsClientSourceTV(iOther) && !IsClientReplay(iOther))
			return false;
	}
	return IsValidClient(iClient) && IsFakeClient(iClient) && IsPlayerAlive(iClient) && (GetClientTeam(iClient) == CS_TEAM_T || GetClientTeam(iClient) == CS_TEAM_CT);
}

void EndNadeProbe(int iClient, const char[] szReason)
{
	if (iClient < 1 || iClient > MaxClients || g_sNadeProbes[iClient].userId == 0)
		return;
	int iUserId = g_sNadeProbes[iClient].userId;
	if (IsValidClient(iClient) && GetClientUserId(iClient) == iUserId && IsFakeClient(iClient))
	{
		SetEntityMoveType(iClient, g_sNadeProbes[iClient].moveType);
		ResetClientNadeSolve(iClient, szReason);
		g_bThrowGrenade[iClient] = false;
		int iWeapon = EntRefToEntIndex(g_sNadeProbes[iClient].createdWeaponRef);
		if (iWeapon > MaxClients && IsValidEntity(iWeapon) && GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") == iClient)
		{
			RemovePlayerItem(iClient, iWeapon);
			RemoveEntity(iWeapon);
		}
	}
	EndNadeObservation(iClient, szReason);
	LogNadeProbe("[NadeProbe] end userid=%d case_id=%s reason=%s", iUserId, g_sNadeProbes[iClient].caseId, szReason);
	g_sNadeProbes[iClient].userId = 0;
	g_sNadeProbes[iClient].referenceValid = false;
	g_iNadeProbeCount--;
}

void EndNadeProbes(const char[] szReason)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		EndNadeProbe(iClient, szReason);
}

bool IsNadeProbePoseValid(int iClient)
{
	float fOrigin[3], fVelocity[3], fViewOffset[3];
	GetClientAbsOrigin(iClient, fOrigin);
	GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
	GetClientEyePosition(iClient, fViewOffset);
	SubtractVectors(fViewOffset, fOrigin, fViewOffset);
	return GetVectorDistance(fOrigin, g_sNadeProbes[iClient].origin) < 0.1
		&& GetVectorLength(fVelocity) < 0.1
		&& GetVectorDistance(fViewOffset, g_sNadeProbes[iClient].viewOffset) < 0.1;
}

bool IsNadeProbeThrowAllowed(int iClient)
{
	if (!IsNadeProbeEnvironmentAllowed(iClient) || GetClientUserId(iClient) != g_sNadeProbes[iClient].userId)
		return false;
	return g_iScriptAction[iClient] == ScriptAction_None && g_iDoingSmokeNum[iClient] == -1
		&& g_iClientStrategyRole[iClient] == -1 && !BotMimic_IsPlayerMimicing(iClient)
		&& !g_bSaveActiveCache[iClient] && !IsForceSaveEnabled()
		&& GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES
		&& GetEntData(iClient, g_iEnemyVisibleOffset) == 0
		&& GetEntData(iClient, g_iBotNearbyEnemiesOffset) == 0 && IsNadeProbePoseValid(iClient);
}

void UpdateNadeObservation()
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_iNadeProbeCount > 0 && g_sNadeProbes[iClient].userId != 0 && (!IsNadeProbeEnvironmentAllowed(iClient) || GetClientOfUserId(g_sNadeProbes[iClient].userId) != iClient))
			EndNadeProbe(iClient, "environment_changed");
		if (g_sNadeProbes[iClient].userId != 0 && (g_iScriptAction[iClient] != ScriptAction_None || g_iDoingSmokeNum[iClient] != -1 || g_iClientStrategyRole[iClient] != -1 || BotMimic_IsPlayerMimicing(iClient)))
			EndNadeProbe(iClient, "control_takeover");
		if (g_sNadeProbes[iClient].userId != 0 && !IsNadeProbePoseValid(iClient))
			EndNadeProbe(iClient, "pose_changed");
		if (g_sNadeThrows[iClient].active && GetGameTime() - g_sNadeThrows[iClient].submittedAt > 30.0)
			EndNadeObservation(iClient, "effect_timeout");
	}
}

void ApplyNadeProbePose(int iClient, int &iButtons, float fVelocity[3])
{
	if (g_sNadeProbes[iClient].userId == 0)
		return;
	iButtons &= ~IN_JUMP;
	if (g_sNadeProbes[iClient].viewOffset[2] < 60.0)
		iButtons |= IN_DUCK;
	else
		iButtons &= ~IN_DUCK;
	for (int iAxis = 0; iAxis < 3; iAxis++)
		fVelocity[iAxis] = 0.0;
}

int GetNadeProbeWeapon(int iClient)
{
	int iTypes[1];
	iTypes[0] = g_sNadeProbes[iClient].defIndex;
	int iWeapon = FindNadeByDefIndex(iClient, iTypes, 1);
	if (iWeapon != -1)
		return iWeapon;
	int iCount;
	for (int iSlot = 0; iSlot < GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons"); iSlot++)
	{
		int iOwned = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iSlot);
		if (iOwned <= MaxClients || !IsValidEntity(iOwned))
			continue;
		int iDefIndex = GetEntProp(iOwned, Prop_Send, "m_iItemDefinitionIndex");
		if (eItems_GetWeaponSlotByDefIndex(iDefIndex) == CS_SLOT_GRENADE)
		{
			int iAmmoType = GetEntProp(iOwned, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType < 0 || iAmmoType >= GetEntPropArraySize(iClient, Prop_Send, "m_iAmmo"))
				return -1;
			iCount += GetEntProp(iClient, Prop_Send, "m_iAmmo", _, iAmmoType);
		}
		if ((iTypes[0] == DEFIDX_MOLOTOV || iTypes[0] == DEFIDX_INCENDIARY) && (iDefIndex == DEFIDX_MOLOTOV || iDefIndex == DEFIDX_INCENDIARY))
			return -1;
	}
	if (iCount >= FindConVar("ammo_grenade_limit_total").IntValue)
		return -1;
	char szWeapon[32];
	switch (iTypes[0])
	{
		case DEFIDX_HE: strcopy(szWeapon, sizeof(szWeapon), "weapon_hegrenade");
		case DEFIDX_FLASH: strcopy(szWeapon, sizeof(szWeapon), "weapon_flashbang");
		case DEFIDX_SMOKE: strcopy(szWeapon, sizeof(szWeapon), "weapon_smokegrenade");
		case DEFIDX_MOLOTOV: strcopy(szWeapon, sizeof(szWeapon), "weapon_molotov");
		case DEFIDX_INCENDIARY: strcopy(szWeapon, sizeof(szWeapon), "weapon_incgrenade");
		case DEFIDX_DECOY: strcopy(szWeapon, sizeof(szWeapon), "weapon_decoy");
		default: return -1;
	}
	iWeapon = GivePlayerItem(iClient, szWeapon);
	if (iWeapon <= MaxClients || !IsValidEntity(iWeapon))
		return -1;
	g_sNadeProbes[iClient].createdWeaponRef = EntIndexToEntRef(iWeapon);
	LogNadeProbe("[NadeProbe] created userid=%d entity=%d type=%d", GetClientUserId(iClient), g_sNadeProbes[iClient].createdWeaponRef, iTypes[0]);
	return iWeapon;
}

bool IsNadeProbeReady(int iClient)
{
	if (!IsNadeProbeEnvironmentAllowed(iClient) || g_sNadeProbes[iClient].userId != GetClientUserId(iClient) || !IsNadeSolveRequestAllowed(iClient) || IsNadeSolveActive(iClient) || g_sNadeThrows[iClient].active || (g_sNadeProbes[iClient].lastAttempt > 0.0 && GetGameTime() - g_sNadeProbes[iClient].lastAttempt < 3.1))
	{
		PrintToServer("[NadeProbe] not_ready client=%d state=%s job=%d throw=%d", iClient, g_szNadeInvalidReason[iClient], IsNadeSolveActive(iClient), g_sNadeThrows[iClient].active);
		return false;
	}
	bool bReady = IsNadeProbePoseValid(iClient);
	if (!bReady)
		PrintToServer("[NadeProbe] not_ready client=%d reason=pose_changed", iClient);
	return bReady;
}

void SolveNadeProbe(int iClient)
{
	if (!IsNadeProbeReady(iClient) || !g_sNadeProbes[iClient].referenceValid)
	{
		PrintToServer("[NadeProbe] solve rejected client=%d reason=not_ready_or_no_reference", iClient);
		return;
	}
	int iWeapon = GetNadeProbeWeapon(iClient);
	if (iWeapon == -1)
		return;
	g_sNadeProbes[iClient].lastAttempt = GetGameTime();
	NadeSolveRequestResult eResult = ProcessGrenadeThrow(iClient, g_sNadeProbes[iClient].target, iWeapon, true);
	LogNadeProbe("[NadeProbe] solve userid=%d case_id=%s result=%d job_id=%d", GetClientUserId(iClient), g_sNadeProbes[iClient].caseId, eResult, g_sNadeSolveJobs[iClient].jobId);
}

public Action Command_NadeProbe(int iArgs)
{
	char szAction[24], szUserId[16], szType[20], szCase[80];
	GetCmdArg(1, szAction, sizeof(szAction));
	if (StrEqual(szAction, "end") && iArgs == 1)
	{
		EndNadeProbes("explicit_end");
		return Plugin_Handled;
	}
	if (StrEqual(szAction, "status") && iArgs == 1)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (g_sNadeProbes[iClient].userId != 0)
			{
				PrintToServer("[NadeProbe] userid=%d case_id=%s origin=%.3f,%.3f,%.3f reference=%d target=%.3f,%.3f,%.3f active_job=%d active_throw=%d", g_sNadeProbes[iClient].userId, g_sNadeProbes[iClient].caseId, g_sNadeProbes[iClient].origin[0], g_sNadeProbes[iClient].origin[1], g_sNadeProbes[iClient].origin[2], g_sNadeProbes[iClient].referenceValid, g_sNadeProbes[iClient].target[0], g_sNadeProbes[iClient].target[1], g_sNadeProbes[iClient].target[2], IsNadeSolveActive(iClient), g_sNadeThrows[iClient].active);
				int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
				float fOrigin[3], fViewOffset[3], fVelocity[3], fAngles[3];
				GetClientAbsOrigin(iClient, fOrigin);
				GetClientEyePosition(iClient, fViewOffset);
				SubtractVectors(fViewOffset, fOrigin, fViewOffset);
				GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
				GetClientEyeAngles(iClient, fAngles);
				LogNadeProbe("[NadeProbe] pose userid=%d origin=%.3f,%.3f,%.3f view=%.3f,%.3f,%.3f velocity=%.3f,%.3f,%.3f angles=%.3f,%.3f,%.3f movetype=%d saved_movetype=%d", g_sNadeProbes[iClient].userId, fOrigin[0], fOrigin[1], fOrigin[2], fViewOffset[0], fViewOffset[1], fViewOffset[2], fVelocity[0], fVelocity[1], fVelocity[2], fAngles[0], fAngles[1], fAngles[2], GetEntityMoveType(iClient), g_sNadeProbes[iClient].moveType);
				LogNadeProbe("[NadeProbe] weapon_state userid=%d active_weapon=%d submitted_weapon=%d pending=%d throwing=%d next_attack=%.3f now=%.3f", g_sNadeProbes[iClient].userId, iWeapon > MaxClients && IsValidEntity(iWeapon) ? EntIndexToEntRef(iWeapon) : INVALID_ENT_REFERENCE, g_sNadeThrows[iClient].weaponRef, g_bNadeThrowPending[iClient], g_bThrowGrenade[iClient], GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack"), GetGameTime());
			}
		}
		return Plugin_Handled;
	}
	if (StrEqual(szAction, "solve-all") && iArgs == 1)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (g_sNadeProbes[iClient].userId != 0)
				SolveNadeProbe(iClient);
		}
		return Plugin_Handled;
	}
	GetCmdArg(2, szUserId, sizeof(szUserId));
	int iUserId;
	if (StringToIntEx(szUserId, iUserId) != strlen(szUserId) || iUserId <= 0)
		return Plugin_Handled;
	int iClient = GetClientOfUserId(iUserId);
	if (!IsNadeProbeEnvironmentAllowed(iClient))
	{
		PrintToServer("[NadeProbe] rejected reason=environment userid=%d", iUserId);
		char szIp[32];
		GetCommandLineParam("-ip", szIp, sizeof(szIp));
		LogNadeProbe("[NadeProbe] environment ip=%s port=%d warmup=%d freeze_end=%d freeze=%d waiting=%d round_decided=%d client_valid=%d", szIp, FindConVar("hostport").IntValue, IsWarmupPeriod(), g_bFreezetimeEnd, GameRules_GetProp("m_bFreezePeriod"), GameRules_GetProp("m_bMatchWaitingForResume"), g_bRoundDecided, IsValidClient(iClient));
		return Plugin_Handled;
	}
	if (StrEqual(szAction, "begin") && iArgs == 4)
	{
		GetCmdArg(3, szType, sizeof(szType));
		GetCmdArg(4, szCase, sizeof(szCase));
		int iDefIndex;
		for (int iType = 43; iType <= 48; iType++)
		{
			char szName[16];
			GetNadeTypeName(iType, szName, sizeof(szName));
			if (StrEqual(szName, szType))
				iDefIndex = iType;
		}
		if (iDefIndex == 0 || strlen(szCase) == 0 || strlen(szCase) > 64 || StrEqual(szCase, "-") || g_iNadeProbeCount >= 4 || g_sNadeProbes[iClient].userId != 0 || IsNadeSolveActive(iClient) || g_sNadeThrows[iClient].active || !IsNadeSolveRequestAllowed(iClient))
		{
			PrintToServer("[NadeProbe] begin rejected reason=input_or_busy userid=%d", iUserId);
			return Plugin_Handled;
		}
		for (int iChar = 0; szCase[iChar] != '\0'; iChar++)
		{
			if (!IsCharAlpha(szCase[iChar]) && !IsCharNumeric(szCase[iChar]) && szCase[iChar] != '_' && szCase[iChar] != '-')
				return Plugin_Handled;
		}
		if (!(GetEntityFlags(iClient) & FL_ONGROUND) || GetEntityMoveType(iClient) != MOVETYPE_WALK)
			return Plugin_Handled;
		g_sNadeProbes[iClient].userId = iUserId;
		g_sNadeProbes[iClient].defIndex = iDefIndex;
		g_sNadeProbes[iClient].moveType = GetEntityMoveType(iClient);
		g_sNadeProbes[iClient].createdWeaponRef = INVALID_ENT_REFERENCE;
		g_sNadeProbes[iClient].referenceValid = false;
		g_sNadeProbes[iClient].lastAttempt = 0.0;
		strcopy(g_sNadeProbes[iClient].caseId, sizeof(g_sNadeProbes[].caseId), szCase);
		GetClientAbsOrigin(iClient, g_sNadeProbes[iClient].origin);
		GetClientEyeAngles(iClient, g_sNadeProbes[iClient].angles);
		GetClientEyePosition(iClient, g_sNadeProbes[iClient].viewOffset);
		SubtractVectors(g_sNadeProbes[iClient].viewOffset, g_sNadeProbes[iClient].origin, g_sNadeProbes[iClient].viewOffset);
		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		SetEntityMoveType(iClient, MOVETYPE_NONE);
		g_iNadeProbeCount++;
		LogNadeProbe("[NadeProbe] begin userid=%d type=%s case_id=%s origin=%.3f,%.3f,%.3f view=%.3f,%.3f,%.3f", iUserId, szType, szCase, g_sNadeProbes[iClient].origin[0], g_sNadeProbes[iClient].origin[1], g_sNadeProbes[iClient].origin[2], g_sNadeProbes[iClient].viewOffset[0], g_sNadeProbes[iClient].viewOffset[1], g_sNadeProbes[iClient].viewOffset[2]);
		return Plugin_Handled;
	}
	if (g_sNadeProbes[iClient].userId != iUserId)
		return Plugin_Handled;
	if (StrEqual(szAction, "retarget") && iArgs == 3)
	{
		char szReferenceUserId[16];
		int iReferenceUserId;
		GetCmdArg(3, szReferenceUserId, sizeof(szReferenceUserId));
		if (StringToIntEx(szReferenceUserId, iReferenceUserId) != strlen(szReferenceUserId) || iReferenceUserId <= 0)
			return Plugin_Handled;
		int iReferenceClient = GetClientOfUserId(iReferenceUserId);
		if (!IsNadeProbeEnvironmentAllowed(iReferenceClient) || !IsNadeProbeThrowAllowed(iClient)
			|| !IsNadeSolveActive(iClient) || !IsNadeSolveRequestAllowed(iClient)
			|| g_sNadeProbes[iReferenceClient].userId != iReferenceUserId
			|| !g_sNadeProbes[iClient].referenceValid || !g_sNadeProbes[iReferenceClient].referenceValid
			|| g_sNadeProbes[iClient].defIndex != g_sNadeProbes[iReferenceClient].defIndex
			|| GetVectorDistance(g_sNadeSolveJobs[iClient].target, g_sNadeProbes[iReferenceClient].target) <= NADE_SOLVE_TARGET_TOLERANCE)
			return Plugin_Handled;
		int iWeapon = EntRefToEntIndex(g_sNadeSolveJobs[iClient].grenadeEntRef);
		NadeSolveRequestResult eResult = ProcessGrenadeThrow(iClient, g_sNadeProbes[iReferenceClient].target, iWeapon, true);
		LogNadeProbe("[NadeProbe] retarget userid=%d reference_userid=%d result=%d job_id=%d", iUserId, iReferenceUserId, eResult, g_sNadeSolveJobs[iClient].jobId);
		return Plugin_Handled;
	}
	if (StrEqual(szAction, "solve") && iArgs == 2)
		SolveNadeProbe(iClient);
	else if (StrEqual(szAction, "position"))
	{
		if (iArgs != 5 || !IsNadeProbeReady(iClient))
		{
			PrintToServer("[NadeProbe] position rejected reason=arguments_or_not_ready userid=%d", iUserId);
			return Plugin_Handled;
		}
		float fPosition[3], fFrom[3], fTo[3], fMins[3], fMaxs[3], fGround[3], fNormal[3];
		char szCoordinate[64];
		for (int iAxis = 0; iAxis < 3; iAxis++)
		{
			int iLength = GetCmdArg(iAxis + 3, szCoordinate, sizeof(szCoordinate));
			if (iLength >= sizeof(szCoordinate) - 1 || StringToFloatEx(szCoordinate, fPosition[iAxis]) != iLength || iLength == 0
				|| !(fPosition[iAxis] >= -16384.0 && fPosition[iAxis] <= 16384.0))
			{
				PrintToServer("[NadeProbe] position rejected reason=coordinates userid=%d", iUserId);
				return Plugin_Handled;
			}
		}
		GetClientMins(iClient, fMins);
		GetClientMaxs(iClient, fMaxs);
		Array_Copy(fPosition, fFrom, 3);
		Array_Copy(fPosition, fTo, 3);
		fFrom[2] += 0.1;
		fTo[2] -= 2.0;
		Handle hTrace = TR_TraceHullFilterEx(fFrom, fTo, fMins, fMaxs, MASK_PLAYERSOLID, TraceNadeProbePosition, iClient);
		bool bSupported = !TR_StartSolid(hTrace) && !TR_AllSolid(hTrace) && TR_DidHit(hTrace);
		if (bSupported)
		{
			TR_GetEndPosition(fGround, hTrace);
			TR_GetPlaneNormal(hTrace, fNormal);
			bSupported = FloatAbs(fGround[2] - fPosition[2]) < 0.1 && fNormal[2] >= 0.7;
		}
		delete hTrace;
		if (!bSupported)
		{
			PrintToServer("[NadeProbe] position rejected reason=blocked_or_unsupported userid=%d ground_delta=%.3f normal_z=%.3f", iUserId, fGround[2] - fPosition[2], fNormal[2]);
			return Plugin_Handled;
		}
		TeleportEntity(iClient, fPosition, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		GetClientAbsOrigin(iClient, g_sNadeProbes[iClient].origin);
		g_sNadeProbes[iClient].referenceValid = false;
		// Let normal AI observe the destination before the next reference.
		g_sNadeProbes[iClient].lastAttempt = GetGameTime();
		char szNadeType[16];
		GetNadeTypeName(g_sNadeProbes[iClient].defIndex, szNadeType, sizeof(szNadeType));
		LogNadeProbe("[NadeProbe] position userid=%d type=%s case_id=%s origin=%.3f,%.3f,%.3f view=%.3f,%.3f,%.3f", iUserId, szNadeType, g_sNadeProbes[iClient].caseId, g_sNadeProbes[iClient].origin[0], g_sNadeProbes[iClient].origin[1], g_sNadeProbes[iClient].origin[2], g_sNadeProbes[iClient].viewOffset[0], g_sNadeProbes[iClient].viewOffset[1], g_sNadeProbes[iClient].viewOffset[2]);
	}
	else if (StrEqual(szAction, "reference") && iArgs == 4 && IsNadeProbeReady(iClient))
	{
		char szPitch[24], szYaw[24];
		float fAngles[3];
		GetCmdArg(3, szPitch, sizeof(szPitch));
		GetCmdArg(4, szYaw, sizeof(szYaw));
		if (StringToFloatEx(szPitch, fAngles[0]) != strlen(szPitch) || StringToFloatEx(szYaw, fAngles[1]) != strlen(szYaw) || !(fAngles[0] >= -75.0 && fAngles[0] <= 75.0 && fAngles[1] >= -180.0 && fAngles[1] <= 180.0))
			return Plugin_Handled;
		int iWeapon = GetNadeProbeWeapon(iClient);
		if (iWeapon == -1)
			return Plugin_Handled;
		float fEye[3], fDirection[3], fLookAt[3];
		GetClientEyePosition(iClient, fEye);
		GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
		for (int iAxis = 0; iAxis < 3; iAxis++)
			fLookAt[iAxis] = fEye[iAxis] + fDirection[iAxis] * 1000.0;
		g_sNadeProbes[iClient].referenceValid = false;
		g_sNadeProbes[iClient].lastAttempt = GetGameTime();
		LogNadeProbe("[NadeProbe] reference userid=%d case_id=%s pitch=%.3f yaw=%.3f eye=%.3f,%.3f,%.3f", iUserId, g_sNadeProbes[iClient].caseId, fAngles[0], fAngles[1], fEye[0], fEye[1], fEye[2]);
		float fReferenceTarget[3];
		SubmitNadeThrow(iClient, iWeapon, fLookAt, g_sNadeProbes[iClient].defIndex, 0, "reference", fReferenceTarget);
	}
	return Plugin_Handled;
}

public void OnEntityCreated(int iEntity, const char[] szClassname)
{
	if (StrEqual(szClassname, "hegrenade_projectile") || StrEqual(szClassname, "flashbang_projectile") || StrEqual(szClassname, "smokegrenade_projectile") || StrEqual(szClassname, "molotov_projectile") || StrEqual(szClassname, "decoy_projectile") || StrEqual(szClassname, "inferno"))
		SDKHook(iEntity, SDKHook_SpawnPost, OnNadeProjectileSpawn);
}

public void OnNadeProjectileSpawn(int iEntity)
{
	RequestFrame(ObserveNadeProjectile, EntIndexToEntRef(iEntity));
}

public void ObserveNadeProjectile(int iEntityRef)
{
	int iEntity = EntRefToEntIndex(iEntityRef);
	if (iEntity <= MaxClients || !IsValidEntity(iEntity))
		return;
	char szClassname[64];
	GetEntityClassname(iEntity, szClassname, sizeof(szClassname));
	bool bInferno = StrEqual(szClassname, "inferno");
	int iOwner = -1;
	if (HasEntProp(iEntity, Prop_Send, "m_hThrower"))
		iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hThrower");
	else if (HasEntProp(iEntity, Prop_Send, "m_hOwnerEntity"))
		iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (!IsValidClient(iOwner) || !g_sNadeThrows[iOwner].active)
	{
		LogNadeProbe("[NadeProbe] unconfirmed entity=%d class=%s owner=%d source=unknown", iEntityRef, szClassname, iOwner);
		return;
	}
	if (g_sNadeProbes[iOwner].userId != 0 && (!IsNadeProbeEnvironmentAllowed(iOwner) || !IsNadeProbePoseValid(iOwner)))
	{
		EndNadeProbe(iOwner, "projectile_environment");
		return;
	}
	int iDefIndex = g_sNadeThrows[iOwner].defIndex;
	bool bTypeMatches = (StrEqual(szClassname, "hegrenade_projectile") && iDefIndex == DEFIDX_HE) || (StrEqual(szClassname, "flashbang_projectile") && iDefIndex == DEFIDX_FLASH) || (StrEqual(szClassname, "smokegrenade_projectile") && iDefIndex == DEFIDX_SMOKE) || (StrEqual(szClassname, "decoy_projectile") && iDefIndex == DEFIDX_DECOY) || ((bInferno || StrEqual(szClassname, "molotov_projectile")) && (iDefIndex == DEFIDX_MOLOTOV || iDefIndex == DEFIDX_INCENDIARY));
	if (!bTypeMatches || GetClientUserId(iOwner) != g_sNadeThrows[iOwner].userId || g_sNadeThrows[iOwner].dispatches == 0 || GetGameTime() - g_sNadeThrows[iOwner].submittedAt > 10.0)
	{
		EndNadeObservation(iOwner, "projectile_identity");
		return;
	}
	if (bInferno)
	{
		if (g_sNadeThrows[iOwner].effectRef == iEntityRef)
			return;
		if (g_sNadeThrows[iOwner].projectileRef == INVALID_ENT_REFERENCE || g_sNadeThrows[iOwner].effectRef != INVALID_ENT_REFERENCE)
			EndNadeObservation(iOwner, "inferno_ambiguous");
		else
			g_sNadeThrows[iOwner].effectRef = iEntityRef;
		return;
	}
	if (g_sNadeThrows[iOwner].projectileRef != INVALID_ENT_REFERENCE)
	{
		EndNadeObservation(iOwner, "multiple_projectiles");
		return;
	}
	g_sNadeThrows[iOwner].projectileRef = iEntityRef;
	LogNadeThrow(iOwner, "projectile");
	if (g_bNadeDetail)
	{
		float fPosition[3], fVelocity[3], fInitialVelocity[3];
		GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", fPosition);
		GetEntPropVector(iEntity, Prop_Data, "m_vecVelocity", fVelocity);
		bool bHasInitialVelocity = HasEntProp(iEntity, Prop_Send, "m_vInitialVelocity");
		if (bHasInitialVelocity)
			GetEntPropVector(iEntity, Prop_Send, "m_vInitialVelocity", fInitialVelocity);
		LogNadeProbe("[NadeProbe] launch userid=%d throw_id=%d entity=%d position=%.3f,%.3f,%.3f velocity=%.3f,%.3f,%.3f initial_available=%d initial_velocity=%.3f,%.3f,%.3f", GetClientUserId(iOwner), g_sNadeThrows[iOwner].throwId, iEntityRef, fPosition[0], fPosition[1], fPosition[2], fVelocity[0], fVelocity[1], fVelocity[2], bHasInitialVelocity, fInitialVelocity[0], fInitialVelocity[1], fInitialVelocity[2]);
	}
}

public void OnNadeEffect(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iEntity = eEvent.GetInt("entityid");
	if (iEntity <= MaxClients || !IsValidEntity(iEntity))
	{
		LogNadeProbe("[NadeProbe] unconfirmed_effect event=%s entity=%d reason=entity_unavailable source=unknown", szName, iEntity);
		return;
	}
	int iEntityRef = EntIndexToEntRef(iEntity);
	char szClassname[64];
	GetEntityClassname(iEntity, szClassname, sizeof(szClassname));
	bool bTypeMatches = (StrEqual(szName, "hegrenade_detonate") && StrEqual(szClassname, "hegrenade_projectile"))
		|| (StrEqual(szName, "flashbang_detonate") && StrEqual(szClassname, "flashbang_projectile"))
		|| (StrEqual(szName, "smokegrenade_detonate") && StrEqual(szClassname, "smokegrenade_projectile"))
		|| (StrEqual(szName, "decoy_started") && StrEqual(szClassname, "decoy_projectile"))
		|| (StrEqual(szName, "inferno_startburn") && StrEqual(szClassname, "inferno"));
	int iOwner = -1;
	if (HasEntProp(iEntity, Prop_Send, "m_hThrower"))
		iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hThrower");
	else if (HasEntProp(iEntity, Prop_Send, "m_hOwnerEntity"))
		iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (!bTypeMatches || !IsValidClient(iOwner) || (!StrEqual(szName, "inferno_startburn") && GetClientUserId(iOwner) != eEvent.GetInt("userid")))
	{
		LogNadeProbe("[NadeProbe] unconfirmed_effect event=%s entity=%d reason=identity_unconfirmed source=unknown", szName, iEntityRef);
		return;
	}
	if (StrEqual(szName, "inferno_startburn"))
		ObserveNadeProjectile(iEntityRef);
	DataPack hData = new DataPack();
	hData.WriteString(szName);
	hData.WriteCell(iEntityRef);
	hData.WriteCell(GetClientUserId(iOwner));
	hData.WriteFloat(eEvent.GetFloat("x"));
	hData.WriteFloat(eEvent.GetFloat("y"));
	hData.WriteFloat(eEvent.GetFloat("z"));
	RequestFrame(ObserveNadeEffect, hData);
}

public void ObserveNadeEffect(DataPack hData)
{
	hData.Reset();
	char szEvent[40];
	hData.ReadString(szEvent, sizeof(szEvent));
	int iEntity = hData.ReadCell();
	int iUserId = hData.ReadCell();
	float fEffect[3];
	for (int iAxis = 0; iAxis < 3; iAxis++)
		fEffect[iAxis] = hData.ReadFloat();
	delete hData;
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!g_sNadeThrows[iClient].active)
			continue;
		bool bInferno = StrEqual(szEvent, "inferno_startburn");
		int iTrackedRef = bInferno ? g_sNadeThrows[iClient].effectRef : g_sNadeThrows[iClient].projectileRef;
		if (iTrackedRef == INVALID_ENT_REFERENCE || iTrackedRef != iEntity)
			continue;
		if (iUserId != g_sNadeThrows[iClient].userId || GetClientOfUserId(g_sNadeThrows[iClient].userId) != iClient)
		{
			EndNadeObservation(iClient, "effect_owner_mismatch");
			return;
		}
		if (g_sNadeProbes[iClient].userId != 0 && (!IsNadeProbeEnvironmentAllowed(iClient) || !IsNadeProbePoseValid(iClient)))
		{
			EndNadeProbe(iClient, "effect_environment");
			return;
		}
		LogNadeThrow(iClient, "effect", "confirmed", fEffect);
		CountNadeThrowResult(iClient, GetVectorDistance(fEffect, g_sNadeThrows[iClient].target) <= 200.0 ? NadeThrow_Succeeded : NadeThrow_OffTarget);
		if (StrEqual(g_sNadeThrows[iClient].source, "reference") && g_sNadeProbes[iClient].userId == g_sNadeThrows[iClient].userId)
		{
			float fTarget[3], fHeight, fEye[3], fRaised[3], fActualRaised[3];
			Array_Copy(fEffect, fTarget, 3);
			if (TraceGroundHeight(fTarget, fHeight))
				fTarget[2] = fHeight;
			GetClientEyePosition(iClient, fEye);
			Array_Copy(fTarget, fRaised, 3);
			Array_Copy(fEffect, fActualRaised, 3);
			fRaised[2] += 10.0;
			fActualRaised[2] += 10.0;
			g_sNadeProbes[iClient].referenceValid = GetVectorDistance(fTarget, fEye) >= 250.0 && GetVectorDistance(fEffect, fTarget) <= 200.0 && IsPointVisible(fRaised, fActualRaised);
			Array_Copy(fTarget, g_sNadeProbes[iClient].target, 3);
			LogNadeProbe("[NadeProbe] reference_result userid=%d accepted=%d target=%.3f,%.3f,%.3f actual=%.3f,%.3f,%.3f", g_sNadeThrows[iClient].userId, g_sNadeProbes[iClient].referenceValid, fTarget[0], fTarget[1], fTarget[2], fEffect[0], fEffect[1], fEffect[2]);
		}
		g_sNadeThrows[iClient].active = false;
		return;
	}
	LogNadeProbe("[NadeProbe] unconfirmed_effect event=%s entity=%d userid=%d source=unknown", szEvent, iEntity, iUserId);
}

void ClearNadeSolveJob(int iClient, NadeSolveEnd eEnd, const char[] szReason)
{
	if (iClient < 1 || iClient > MaxClients)
		return;

	if (IsNadeSolveActive(iClient))
	{
		g_iNadeJobsEnded[eEnd]++;
		LogNadeJob(iClient, "job_end", g_szNadeEndNames[eEnd], szReason);
		if (g_smNadeEndReasons == null)
			g_smNadeEndReasons = new StringMap();
		int iCount;
		g_smNadeEndReasons.GetValue(szReason, iCount);
		g_smNadeEndReasons.SetValue(szReason, iCount + 1);
	}
	for (int iSlot = 0; iSlot < NADE_SOLVE_MAX_ACTIVE_JOBS; iSlot++)
	{
		if (g_iNadeSolveClients[iSlot] != iClient)
			continue;
		g_iNadeSolveClients[iSlot] = 0;
		if (g_iNadeSolveActiveCount > 0)
			g_iNadeSolveActiveCount--;
	}

	g_sNadeSolveJobs[iClient].phase = NadeSolve_Idle;
	g_sNadeSolveJobs[iClient].resumePhase = NadeSolve_Idle;
	g_sNadeSolveJobs[iClient].resumePitch = 0.0;
	g_sNadeSolveJobs[iClient].jobId = 0;
	g_sNadeSolveJobs[iClient].parentJobId = 0;
	g_sNadeSolveJobs[iClient].traces = 0;
	g_sNadeSolveJobs[iClient].candidates = 0;
	g_sNadeSolveJobs[iClient].loggedEpoch = 0;
	g_sNadeSolveJobs[iClient].clientUserId = 0;
	g_sNadeSolveJobs[iClient].grenadeEntRef = INVALID_ENT_REFERENCE;
	g_sNadeSolveJobs[iClient].grenadeDefIndex = 0;
	g_sNadeSolveJobs[iClient].requestTime = 0.0;
	g_sNadeSolveJobs[iClient].deadlineTime = 0.0;
	g_sNadeSolveJobs[iClient].yaw = 0.0;
	g_sNadeSolveJobs[iClient].currentPitch = 0.0;
	g_sNadeSolveJobs[iClient].bestPitch = 0.0;
	g_sNadeSolveJobs[iClient].fineEndPitch = 0.0;
	g_sNadeSolveJobs[iClient].bestDistance = 0.0;
	g_sNadeSolveJobs[iClient].hasFallbackTarget = false;
	g_sNadeSolveJobs[iClient].fallbackAttempted = false;
	g_sNadeSolveJobs[iClient].candidateActive = false;
	g_sNadeSolveJobs[iClient].candidateTime = 0.0;
	g_sNadeSolveJobs[iClient].candidateNextThink = 0.0;
	g_sNadeSolveJobs[iClient].candidateBounces = 0;
	g_sNadeSolveJobs[iClient].candidatePendingPush = false;
	g_sNadeSolveJobs[iClient].candidateRemainingTime = 0.0;

	for (int i = 0; i < 3; i++)
	{
		g_sNadeSolveJobs[iClient].startOrigin[i] = 0.0;
		g_sNadeSolveJobs[iClient].eyePosition[i] = 0.0;
		g_sNadeSolveJobs[iClient].target[i] = 0.0;
		g_sNadeSolveJobs[iClient].fallbackTarget[i] = 0.0;
		g_sNadeSolveJobs[iClient].candidatePosition[i] = 0.0;
		g_sNadeSolveJobs[iClient].candidateVelocity[i] = 0.0;
	}
}

void CancelNadeSolveJob(int iClient, const char[] szReason)
{
	if (IsNadeSolveActive(iClient) && (StrEqual(szReason, "origin_moved") || StrEqual(szReason, "target_replaced")))
		g_fNadeSolveRetryAt[iClient] = GetGameTime() + NADE_SOLVE_RETRY_INTERVAL;
	ClearNadeSolveJob(iClient, StrEqual(szReason, "deadline") ? NadeEnd_TimedOut : NadeEnd_Cancelled, g_szNadeCleanupContext[0] != '\0' ? g_szNadeCleanupContext : szReason);
	if (iClient >= 1 && iClient <= MaxClients)
		g_bNadeThrowPending[iClient] = false;
}

void ResetClientNadeSolve(int iClient, const char[] szReason)
{
	if (iClient < 1 || iClient > MaxClients)
		return;

	ClearNadeSolveJob(iClient, NadeEnd_Cancelled, szReason);
	g_fNadeSolveRetryAt[iClient] = 0.0;
	g_bNadeThrowPending[iClient] = false;
	for (int iCacheSlot = 0; iCacheSlot < NADE_SOLVE_CACHE_SLOTS; iCacheSlot++)
	{
		g_bLastNadeSolveValid[iClient][iCacheSlot] = false;
		g_bLastNadeSolveSuccess[iClient][iCacheSlot] = false;
		g_iLastNadeSolveDefIndex[iClient][iCacheSlot] = 0;
		g_fLastNadeSolveTime[iClient][iCacheSlot] = 0.0;

		for (int i = 0; i < 3; i++)
		{
			g_fLastNadeSolveOrigin[iClient][iCacheSlot][i] = 0.0;
			g_fLastNadeSolveTarget[iClient][iCacheSlot][i] = 0.0;
			g_fLastNadeSolveLookAt[iClient][iCacheSlot][i] = 0.0;
		}
	}
}

void ResetNadeSolveJobs(const char[] szReason)
{
	for (int i = 1; i <= MaxClients; i++)
		ResetClientNadeSolve(i, szReason);

	g_iNadeSolveActiveCount = 0;
	for (int iSlot = 0; iSlot < NADE_SOLVE_MAX_ACTIVE_JOBS; iSlot++)
		g_iNadeSolveClients[iSlot] = 0;
	g_iNadeSolveRoundRobinSlot = 0;
}

void ResetNadeSolvePerfStats()
{
	g_iNadeEpoch++;
	for (int iScope = 0; iScope < sizeof(g_iNadeThrowCounts); iScope++)
	{
		g_iNadeThrowCarry[iScope] = 0;
		for (int iResult = 0; iResult < sizeof(g_iNadeThrowCounts[]); iResult++)
			g_iNadeThrowCounts[iScope][iResult] = 0;
	}
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_sNadeThrows[iClient].active && StrEqual(g_sNadeThrows[iClient].source, "solver"))
		{
			g_iNadeThrowCarry[0]++;
			if (StrEqual(g_sNadeThrows[iClient].caseId, "-"))
				g_iNadeThrowCarry[1]++;
		}
	}
	g_iNadeCarryIn = g_iNadeSolveActiveCount;
	g_iNadeJobsStarted = 0;
	for (int iResult = 0; iResult < sizeof(g_iNadeJobsEnded); iResult++)
		g_iNadeJobsEnded[iResult] = 0;
	for (int iRequest = 0; iRequest < sizeof(g_iNadeRequests); iRequest++)
		g_iNadeRequests[iRequest] = 0;
	if (g_smNadeEndReasons != null)
		g_smNadeEndReasons.Clear();
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		LogNadeJob(iClient, "job_carry", "-", "stats_reset");
	g_iNadeRequestsBusy = 0;
	g_sNadeSolvePerf.schedulerVisits = 0;
	g_sNadeSolvePerf.nadeFrames = 0;
	g_sNadeSolvePerf.totalNadeFrameSeconds = 0.0;
	g_sNadeSolvePerf.maxNadeFrameSeconds = 0.0;
	g_sNadeSolvePerf.activeFrames = 0;
	g_sNadeSolvePerf.traces = 0;
	g_sNadeSolvePerf.maxTracesPerFrame = 0;
	g_sNadeSolvePerf.timeBudgetHits = 0;
	g_sNadeSolvePerf.traceBudgetHits = 0;
	g_sNadeSolvePerf.completedJobs = 0;
	g_sNadeSolvePerf.failedJobs = 0;
	g_sNadeSolvePerf.timedOutJobs = 0;
	g_sNadeSolvePerf.maxQueuedJobs = 0;
	g_sNadeSolvePerf.totalFrameSeconds = 0.0;
	g_sNadeSolvePerf.maxFrameSeconds = 0.0;
}

public Action Command_NadePerf(int iArgs)
{
	if (iArgs > 0)
	{
		char szAction[16], szValue[8];
		GetCmdArg(1, szAction, sizeof(szAction));
		GetCmdArg(2, szValue, sizeof(szValue));
		if (iArgs != 2 || !StrEqual(szAction, "detail") || (!StrEqual(szValue, "0") && !StrEqual(szValue, "1")))
		{
			PrintToServer("[NadePerf] usage: bb_nade_perf [detail 0|1]");
			return Plugin_Handled;
		}
		g_bNadeDetail = StrEqual(szValue, "1");
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsNadeSolveActive(iClient) && g_sNadeSolveJobs[iClient].loggedEpoch != g_iNadeEpoch)
				LogNadeJob(iClient, "job_carry", "-", "detail_enabled");
		}
	}
	float fAverageTraces = 0.0;
	float fAverageSeconds = 0.0;
	float fAverageNadeSeconds = g_sNadeSolvePerf.nadeFrames > 0 ? g_sNadeSolvePerf.totalNadeFrameSeconds / float(g_sNadeSolvePerf.nadeFrames) : 0.0;
	if (g_sNadeSolvePerf.activeFrames > 0)
	{
		fAverageTraces = float(g_sNadeSolvePerf.traces) / float(g_sNadeSolvePerf.activeFrames);
		fAverageSeconds = g_sNadeSolvePerf.totalFrameSeconds / float(g_sNadeSolvePerf.activeFrames);
	}

	PrintToServer("[NadePerf] active_frames=%d traces=%d avg_traces=%.2f max_traces=%d avg_seconds=%.6f max_seconds=%.6f", g_sNadeSolvePerf.activeFrames, g_sNadeSolvePerf.traces, fAverageTraces, g_sNadeSolvePerf.maxTracesPerFrame, fAverageSeconds, g_sNadeSolvePerf.maxFrameSeconds);
	PrintToServer("[NadePerf] time_budget_hits=%d trace_budget_hits=%d completed=%d failed=%d timed_out=%d max_queued=%d", g_sNadeSolvePerf.timeBudgetHits, g_sNadeSolvePerf.traceBudgetHits, g_sNadeSolvePerf.completedJobs, g_sNadeSolvePerf.failedJobs, g_sNadeSolvePerf.timedOutJobs, g_sNadeSolvePerf.maxQueuedJobs);
	LogNadeAccounting("[NadeDiag] event=perf epoch=%d carry_in=%d jobs_started=%d jobs_active=%d jobs_submitted=%d jobs_no_solution=%d jobs_timed_out=%d jobs_cancelled=%d requests_rejected=%d requests_reused=%d requests_started=%d cache_failed=%d cache_submitted=%d requests_busy=%d solve_capacity=%d scheduler_visits=%d nade_frames=%d nade_frame_avg_seconds=%.6f nade_frame_max_seconds=%.6f active_frames=%d traces=%d max_traces=%d avg_seconds=%.6f max_seconds=%.6f detail=%d", g_iNadeEpoch, g_iNadeCarryIn, g_iNadeJobsStarted, g_iNadeSolveActiveCount, g_iNadeJobsEnded[0], g_iNadeJobsEnded[1], g_iNadeJobsEnded[2], g_iNadeJobsEnded[3], g_iNadeRequests[0], g_iNadeRequests[1], g_iNadeRequests[2], g_iNadeRequests[3], g_iNadeRequests[4], g_iNadeRequestsBusy, NADE_SOLVE_MAX_ACTIVE_JOBS, g_sNadeSolvePerf.schedulerVisits, g_sNadeSolvePerf.nadeFrames, fAverageNadeSeconds, g_sNadeSolvePerf.maxNadeFrameSeconds, g_sNadeSolvePerf.activeFrames, g_sNadeSolvePerf.traces, g_sNadeSolvePerf.maxTracesPerFrame, fAverageSeconds, g_sNadeSolvePerf.maxFrameSeconds, g_bNadeDetail);
	int iThrowsActive[2];
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (g_sNadeThrows[iClient].active && StrEqual(g_sNadeThrows[iClient].source, "solver"))
		{
			iThrowsActive[0]++;
			if (StrEqual(g_sNadeThrows[iClient].caseId, "-"))
				iThrowsActive[1]++;
		}
	}
	for (int iScope = 0; iScope < sizeof(g_iNadeThrowCounts); iScope++)
		LogNadeAccounting("[NadeDiag] event=throw_perf epoch=%d scope=%s carry_in=%d throws_started=%d throws_active=%d throws_succeeded=%d throws_off_target=%d throws_failed=%d detail=%d", g_iNadeEpoch, iScope == 0 ? "solver" : "natural", g_iNadeThrowCarry[iScope], g_iNadeThrowCounts[iScope][NadeThrow_Started], iThrowsActive[iScope], g_iNadeThrowCounts[iScope][NadeThrow_Succeeded], g_iNadeThrowCounts[iScope][NadeThrow_OffTarget], g_iNadeThrowCounts[iScope][NadeThrow_Failed], g_bNadeDetail);
	if (g_smNadeEndReasons != null)
	{
		StringMapSnapshot hReasons = g_smNadeEndReasons.Snapshot();
		char szReason[40];
		int iCount;
		for (int iIndex = 0; iIndex < hReasons.Length; iIndex++)
		{
			hReasons.GetKey(iIndex, szReason, sizeof(szReason));
			g_smNadeEndReasons.GetValue(szReason, iCount);
			PrintToServer("[NadePerf] reason=%s count=%d", szReason, iCount);
		}
		delete hReasons;
	}
	return Plugin_Handled;
}

public Action Command_NadePerfReset(int iArgs)
{
	ResetNadeSolvePerfStats();
	PrintToServer("[NadePerf] stats reset.");
	return Plugin_Handled;
}

bool TryUseCachedNadeSolve(int iClient, const float fOrigin[3], const float fTarget[3], int iNadeDefIndex, float fLookAt[3], float fNow, bool &bSuccess)
{
	for (int iCacheSlot = 0; iCacheSlot < NADE_SOLVE_CACHE_SLOTS; iCacheSlot++)
	{
		if (!g_bLastNadeSolveValid[iClient][iCacheSlot])
			continue;

		if (g_iLastNadeSolveDefIndex[iClient][iCacheSlot] != iNadeDefIndex)
			continue;

		if ((fNow - g_fLastNadeSolveTime[iClient][iCacheSlot]) > NADE_SOLVE_CACHE_TTL)
			continue;

		if (GetVectorDistance(g_fLastNadeSolveOrigin[iClient][iCacheSlot], fOrigin) > NADE_SOLVE_ORIGIN_TOLERANCE)
			continue;

		if (GetVectorDistance(g_fLastNadeSolveTarget[iClient][iCacheSlot], fTarget) > NADE_SOLVE_TARGET_TOLERANCE)
			continue;

		bSuccess = g_bLastNadeSolveSuccess[iClient][iCacheSlot];
		if (bSuccess)
			Array_Copy(g_fLastNadeSolveLookAt[iClient][iCacheSlot], fLookAt, 3);
		return true;
	}

	return false;
}

void StoreNadeSolveCache(int iClient, const float fOrigin[3], const float fTarget[3], int iNadeDefIndex, const float fLookAt[3], bool bSuccess, float fNow)
{
	int iCacheSlot = -1;
	float fOldestTime = fNow;
	for (int i = 0; i < NADE_SOLVE_CACHE_SLOTS; i++)
	{
		if (g_bLastNadeSolveValid[iClient][i] && g_iLastNadeSolveDefIndex[iClient][i] == iNadeDefIndex && GetVectorDistance(g_fLastNadeSolveOrigin[iClient][i], fOrigin) <= NADE_SOLVE_ORIGIN_TOLERANCE && GetVectorDistance(g_fLastNadeSolveTarget[iClient][i], fTarget) <= NADE_SOLVE_TARGET_TOLERANCE)
		{
			iCacheSlot = i;
			break;
		}

		if (!g_bLastNadeSolveValid[iClient][i])
		{
			iCacheSlot = i;
			break;
		}

		if (iCacheSlot == -1 || g_fLastNadeSolveTime[iClient][i] < fOldestTime)
		{
			iCacheSlot = i;
			fOldestTime = g_fLastNadeSolveTime[iClient][i];
		}
	}

	g_bLastNadeSolveValid[iClient][iCacheSlot] = true;
	g_bLastNadeSolveSuccess[iClient][iCacheSlot] = bSuccess;
	g_iLastNadeSolveDefIndex[iClient][iCacheSlot] = iNadeDefIndex;
	g_fLastNadeSolveTime[iClient][iCacheSlot] = fNow;
	Array_Copy(fOrigin, g_fLastNadeSolveOrigin[iClient][iCacheSlot], 3);
	Array_Copy(fTarget, g_fLastNadeSolveTarget[iClient][iCacheSlot], 3);
	if (bSuccess)
		Array_Copy(fLookAt, g_fLastNadeSolveLookAt[iClient][iCacheSlot], 3);
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
			if (!g_bNadeThrowPending[i] && !g_bThrowGrenade[i])
				SwitchWeapon(i, GetPlayerWeaponSlot(i, CS_SLOT_KNIFE), "bomb_move");
			else if (g_bNadeDetail && g_sNadeThrows[i].active && g_sNadeThrows[i].switchRequests++ < 2)
				LogNadeProbe("[NadeProbe] switch_deferred userid=%d throw_id=%d caller=bomb_move", GetClientUserId(i), g_sNadeThrows[i].throwId);
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
	EndNadeProbes("map_end");
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		EndNadeObservation(iClient, "map_end");
	SafeDeleteTimer(g_hCheckPlayerTimer);
	SafeDeleteTimer(g_hMoveToBombTimer);
	SafeDeleteTimer(g_hPlayerResourceRetryTimer);
	SafeDeleteTimer(g_hDropWeaponsTimer);

	g_iPlayerResourceRetryCount = 0;
	g_bPlayerResourceRetryLogged = false;

	if (g_iPlayerResourceEntity != -1 && IsValidEntity(g_iPlayerResourceEntity))
		SDKUnhook(g_iPlayerResourceEntity, SDKHook_ThinkPost, OnThinkPost);

	g_iPlayerResourceEntity = -1;
	ResetNadeSolveJobs("map_end");
}

public void OnPluginEnd()
{
	ResetAllBotReactions("plugin_end");
	EndNadeProbes("plugin_end");
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		EndNadeObservation(iClient, "plugin_end");
	ResetNadeSolveJobs("plugin_end");
}

public void OnClientPutInServer(int iClient)
{
	ResetBotReaction(iClient, "put_in_server");
	if (!IsFakeClient(iClient))
		EndNadeProbes("human_joined");
	if (!IsValidClient(iClient))
		return;

	ClearClientScriptAction(iClient);
	g_bPeekAssigned[iClient] = false;
	g_bAngleAssigned[iClient] = false;
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
	EndNadeProbes("round_start");
	strcopy(g_szNadeCleanupContext, sizeof(g_szNadeCleanupContext), "round_start");
	ClearActiveStrategy(true);
	ResetScriptLineupRuntimeState();

	g_bFreezetimeEnd = false;
	g_bBombPlanted = false;
	g_bRoundDecided = false;
	g_fRoundStart = GetGameTime();
	g_bHalftimeSwitch = false;
	g_bTeamPeekUsedRound[CS_TEAM_T] = false;
	g_bTeamPeekUsedRound[CS_TEAM_CT] = false;
	g_bTeamPeekRollResolved[CS_TEAM_T] = false;
	g_bTeamPeekRollResolved[CS_TEAM_CT] = false;
	g_bTeamPeekRollPassed[CS_TEAM_T] = false;
	g_bTeamPeekRollPassed[CS_TEAM_CT] = false;
	g_bCTSaveLocked = false;
	g_fCTSaveConditionSince = 0.0;
	g_iLooseBombDropper = -1;
	ParseRoundStrategies();
	UpdateAliveTeamCounts();

	bool bIsScenario = g_bIsBombScenario || g_bIsHostageScenario;
	int iTeam = g_bIsBombScenario ? CS_TEAM_CT : CS_TEAM_T;
	int iOppositeTeam = g_bIsBombScenario ? CS_TEAM_T : CS_TEAM_CT;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsFakeClient(i))
			continue;

		ClearClientScriptAction(i);
		g_bSaveLocked[i] = false;
		g_fSaveConditionSince[i] = 0.0;
		ResetClientSaveTarget(i);
		ResetClientBombMove(i);
		ResetClientNadeSolve(i, "round_start");
		g_fSaveLookAtDebugTime[i] = 0.0;
		g_bPeekAssigned[i] = false;
		g_bAngleAssigned[i] = false;

		if (!IsPlayerAlive(i))
			continue;

		g_bUncrouch[i] = IsItMyChance(50.0);
		g_bDontSwitch[i] = false;
		g_bDropWeapon[i] = false;
		g_bHasGottenDrop[i] = false;
		g_bCheapDrop[i] = false;
		g_bThrowGrenade[i] = false;

		g_iTarget[i] = -1;
		g_iPrevTarget[i] = -1;
		g_iDoingSmokeNum[i] = -1;
		ResetClientLegacyDefaultNadeTracking(i);

		g_fShootTimestamp[i] = 0.0;
		g_fThrowNadeTimestamp[i] = 0.0;
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
	g_szNadeCleanupContext[0] = '\0';
}

public void OnRoundEnd(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	ResetAllBotReactions("round_end");
	EndNadeProbes("round_end");
	strcopy(g_szNadeCleanupContext, sizeof(g_szNadeCleanupContext), "round_end");
	g_bRoundDecided = true;
	ClearActiveStrategy(true);

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
		ResetClientNadeSolve(i, "round_end");

		if (IsValidClient(i) && IsFakeClient(i))
			CancelClientActiveLineupActions(i, false);
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
	g_szNadeCleanupContext[0] = '\0';
}

public void OnFreezetimeEnd(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	g_bFreezetimeEnd = true;
	g_fFreezeTimeEnd = GetGameTime();
	UpdateAliveTeamCounts();

	if (g_aStrategies != null && g_aStrategies.Length > 0)
		TrySelectStrategy();
}

public void OnBombPlanted(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	strcopy(g_szNadeCleanupContext, sizeof(g_szNadeCleanupContext), "bomb_planted");
	g_bBombPlanted = true;
	ClearActiveStrategy(true);

	int iPlantedC4 = FindEntityByClassname(-1, "planted_c4");
	if (IsValidEntity(iPlantedC4))
		GetEntPropVector(iPlantedC4, Prop_Send, "m_vecOrigin", g_fBombPos);

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetClientBombMove(i);
		ResetClientNadeSolve(i, "bomb_planted");
		if (IsValidClient(i) && IsFakeClient(i))
			CancelClientActiveLineupActions(i, false);
	}
	g_szNadeCleanupContext[0] = '\0';
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
	g_bRoundDecided = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		ResetClientNadeSolve(i, "bomb_resolved");
		if (IsValidClient(i) && IsFakeClient(i))
			CancelClientActiveLineupActions(i, false);
	}
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

		if (!g_bIsProBot[i] || !CanThrowNade(i) || g_bThrowGrenade[i])
			continue;

		if (GetTask(i) == ESCAPE_FROM_BOMB || GetTask(i) == ESCAPE_FROM_FLAMES || GetEntityMoveType(i) == MOVETYPE_LADDER)
			continue;

		float fEyePos[3];
		GetClientEyePosition(i, fEyePos);

		if (GetVectorDistance(fPlanterPos, fEyePos) > 1500.0)
			continue;

		if (IsPointVisible(fEyePos, fPlanterPos))
			continue;

		if (!IsItMyChance(30.0))
			continue;

		int iNade = FindNadeByDefIndex(i, g_iDenialNades, sizeof(g_iDenialNades));
		if (iNade != -1)
			ProcessGrenadeThrow(i, fPlanterPos, iNade);
	}
}

public void OnPlayerDeath(Event eEvent, const char[] szName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (iClient > 0 && iClient <= MaxClients)
		ResetBotReaction(iClient, "death");
	EndNadeProbe(iClient, "death");
	if (IsValidClient(iClient))
	{
		g_bSaveLocked[iClient] = false;
		g_fSaveConditionSince[iClient] = 0.0;
		g_fSaveLookAtDebugTime[iClient] = 0.0;
		g_fAttackDebugTime[iClient] = 0.0;
		ResetClientSaveTarget(iClient);
		ResetClientBombMove(iClient);
		ResetClientNadeSolve(iClient, "death");

		if (IsFakeClient(iClient))
		{
			CancelClientActiveLineupActions(iClient, false);
			if (g_iClientStrategyRole[iClient] != -1)
				ClearActiveStrategy(true);
		}
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

public MRESReturn CCSBot_OnAudibleEvent(int iBot, DHookParam hParams)
{
	if (!IsValidClient(iBot) || !IsFakeClient(iBot) || hParams == null)
		return MRES_Ignored;

	Address pClient = hParams.GetAddress(2);
	if (pClient == Address_Null)
		return MRES_Ignored;

	int iClient = GetClientFromAddress(pClient);
	if (!IsValidClient(iClient) || GetClientTeam(iBot) == GetClientTeam(iClient))
		return MRES_Ignored;

	Address pActualOrigin = view_as<Address>(hParams.Get(7));

	if (pActualOrigin != Address_Null)
	{
		// Sound origin override (decoys, etc.)
		g_fOriginalNoisePos[iBot][0] = view_as<float>(LoadFromAddress(pActualOrigin, NumberType_Int32));
		g_fOriginalNoisePos[iBot][1] = view_as<float>(LoadFromAddress(pActualOrigin + view_as<Address>(4), NumberType_Int32));
		g_fOriginalNoisePos[iBot][2] = view_as<float>(LoadFromAddress(pActualOrigin + view_as<Address>(8), NumberType_Int32));
	}
	else
	{
		// Player's origin (ground level)
		GetClientAbsOrigin(iClient, g_fOriginalNoisePos[iBot]);
	}

	return MRES_Ignored;
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

		if (IsValidClient(g_iTarget[iClient]) && IsPlayerAlive(g_iTarget[iClient]) && CanThrowNade(iClient) && IsItMyChance(1.0) && GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES && GetEntityMoveType(iClient) != MOVETYPE_LADDER)
		{
			float fPos[3];
			DHookGetParamVector(hParams, 2, fPos);

			int iNade = FindNadeByDefIndex(iClient, g_iAllNades, sizeof(g_iAllNades));
			if (iNade != -1 && ProcessGrenadeThrow(iClient, fPos, iNade) == NadeRequest_Submitted)
				return MRES_Supercede;
		}

		return MRES_Ignored;
	}
	else if (strcmp(szDesc, "GrenadeThrowBend") == 0)
	{
		if (g_bThrowGrenade[iClient] && !bPosNull)
			hParams.SetVector(2, g_fNadeTarget[iClient]);

		hParams.Set(4, 8.0);
		hParams.Set(6, 1.5);
		return MRES_ChangedHandled;
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

		if (CanThrowNade(iClient) && IsItMyChance(3.0) && GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES && GetEntityMoveType(iClient) != MOVETYPE_LADDER)
		{
			int iNade = FindNadeByDefIndex(iClient, g_iAllNades, sizeof(g_iAllNades));
			if (iNade != -1 && ProcessGrenadeThrowWithFallback(iClient, g_fOriginalNoisePos[iClient], fNoisePos, iNade) == NadeRequest_Submitted)
				return MRES_Supercede;
		}

		if (BotMimic_IsPlayerMimicing(iClient))
		{
			if (g_iDoingSmokeNum[iClient] != -1)
				SetNadeTimestamp(g_iDoingSmokeNum[iClient], GetGameTime());

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

		if (CanThrowNade(iClient) && IsItMyChance(25.0) && GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES && GetEntityMoveType(iClient) != MOVETYPE_LADDER)
		{
			int iNade = FindNadeByDefIndex(iClient, g_iAllNades, sizeof(g_iAllNades));
			if (iNade != -1 && ProcessGrenadeThrowWithFallback(iClient, g_fOriginalNoisePos[iClient], fPos, iNade) == NadeRequest_Submitted)
				return MRES_Supercede;
		}

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
	ApplyNadeProbePose(iClient, iButtons, fVel);

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
		if (g_iScriptAction[iClient] != ScriptAction_None)
			CancelClientScriptAction(iClient, false);
		g_iDoingSmokeNum[iClient] = -1;
		ResetClientLegacyDefaultNadeTracking(iClient);
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

	if (HandleStrategyBot(iClient, !!GetEntData(iClient, g_iEnemyVisibleOffset)))
		return Plugin_Continue;

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
		SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE), "round_wipe");

		if (g_iScriptAction[iClient] != ScriptAction_None)
			CancelClientScriptAction(iClient, false);
		else if (BotMimic_IsPlayerMimicing(iClient))
			BotMimic_StopPlayerMimic(iClient);

		ResetNadeTimestamps();
		g_iDoingSmokeNum[iClient] = -1;
		ResetClientLegacyDefaultNadeTracking(iClient);
	}

	if (!bShouldSaveInsteadOfRetake && g_iDoingSmokeNum[iClient] == -1 && fNow >= g_fNadeLineupCooldown[iClient] && !IsBotMimicBlockedPhase())
	{
		bool bAssignedScriptLineup = false;
		if (IsClientScriptIdle(iClient))
		{
			if (g_bBombPlanted)
			{
				if (IsPostPlantScriptLineupAllowed(iClient))
					bAssignedScriptLineup = TryAssignScriptLineup(iClient, g_aPostPlantNades, ScriptAction_PostPlantNade, true);
			}
			else
			{
				if (IsRegulationPistolRound())
					bAssignedScriptLineup = TryAssignScriptLineup(iClient, g_aPistolNades, ScriptAction_Nade, true);

				if (!bAssignedScriptLineup)
					bAssignedScriptLineup = TryAssignTeamPeekScriptLineup(GetClientTeam(iClient), fNow);

				if (!bAssignedScriptLineup && IsAngleScriptLineupAllowed(iClient, fNow))
					bAssignedScriptLineup = TryAssignScriptLineup(iClient, g_aAngles, ScriptAction_Angle, false);
			}
		}

		if (!bAssignedScriptLineup && g_iScriptAction[iClient] == ScriptAction_None && !IsNadeSolveActive(iClient) && !g_bNadeThrowPending[iClient])
		{
			int iLegacyNade = GetNearestGrenade(iClient);
			if (iLegacyNade != -1)
				StartClientLegacyDefaultNadeAction(iClient, iLegacyNade, fNow);
		}

		g_fNadeLineupCooldown[iClient] = fNow + 1.0;
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

	if (!bShouldSaveInsteadOfRetake && g_iDoingSmokeNum[iClient] != -1 && !BotMimic_IsPlayerMimicing(iClient))
	{
		NadeLineup sNade;
		g_aNades.GetArray(g_iDoingSmokeNum[iClient], sNade);
		SetNadeTimestamp(g_iDoingSmokeNum[iClient], fNow);
		float fDisToNade = GetVectorDistance(g_fBotOrigin[iClient], sNade.fPos);

		if ((fNow - g_fLegacyDefaultNadeActionStart[iClient]) > LEGACY_DEFAULT_NADE_STUCK_TIMEOUT)
		{
			FailClientLegacyDefaultNadeAction(iClient, "timed out", fNow);
			return Plugin_Changed;
		}

		if (fDisToNade >= 25.0 && IsLegacyDefaultNadeMovementStale(iClient, fNow))
		{
			FailClientLegacyDefaultNadeAction(iClient, "movement stale", fNow);
			return Plugin_Changed;
		}

		if (ThrottleScriptMove(iClient, sNade.fPos, fNow))
			BotMoveTo(iClient, sNade.fPos, FASTEST_ROUTE);
		if (fDisToNade < 25.0)
		{
			BotSetLookAt(iClient, "Use entity", sNade.fLook, PRIORITY_HIGH, 2.0, false, 3.0, false);
			if (view_as<LookAtSpotState>(GetEntData(iClient, g_iBotLookAtSpotStateOffset)) == LOOK_AT_SPOT && fSpeed == 0.0 && (GetEntityFlags(iClient) & FL_ONGROUND))
				BotMimic_PlayRecordFromFile(iClient, sNade.szReplay);
		}
	}

	ProcessScriptLineupAction(iClient, ScriptAction_Nade, g_aPistolNades, fSpeed, fNow);
	ProcessScriptLineupAction(iClient, ScriptAction_PostPlantNade, g_aPostPlantNades, fSpeed, fNow);
	ProcessScriptLineupAction(iClient, ScriptAction_Peek, g_aPeeks, fSpeed, fNow);
	ProcessScriptLineupAction(iClient, ScriptAction_Angle, g_aAngles, fSpeed, fNow);

	if (g_bThrowGrenade[iClient] && eItems_GetWeaponSlotByDefIndex(iDefIndex) == CS_SLOT_GRENADE)
	{
		BotThrowGrenade(iClient, g_fNadeTarget[iClient]);
		g_fThrowNadeTimestamp[iClient] = fNow;
	}

	if (IsSafe(iClient))
	{
		iButtons &= ~IN_SPEED;
		if (g_bIsProBot[iClient] && !g_bDontSwitch[iClient] && !BotIsHiding(iClient) && !g_bNadeThrowPending[iClient] && !g_bThrowGrenade[iClient])
			SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE), "safe_move");
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
	if (g_bIsProBot[iClient] && CanThrowNade(iClient) && !g_bThrowGrenade[iClient] && !BotMimic_IsPlayerMimicing(iClient) && GetEntityMoveType(iClient) != MOVETYPE_LADDER && GetTask(iClient) != ESCAPE_FROM_BOMB && GetTask(iClient) != ESCAPE_FROM_FLAMES)
	{
		bool bIsEnemyVisible = !!GetEntData(iClient, g_iEnemyVisibleOffset);

		if (g_bBombPlanted && !bIsEnemyVisible && GetClientTeam(iClient) == CS_TEAM_T && IsEnemyNearBomb() && IsItMyChance(0.5))
		{
			float fClientEyes[3];
			GetClientEyePosition(iClient, fClientEyes);

			if (!IsPointVisible(fClientEyes, g_fBombPos))
			{
				int iNade = FindNadeByDefIndex(iClient, g_iDenialNades, sizeof(g_iDenialNades));
				if (iNade != -1)
					ProcessGrenadeThrow(iClient, g_fBombPos, iNade);
			}
		}
	}

	ApplyNadeProbePose(iClient, iButtons, fVel);
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
		if (g_iDoingSmokeNum[iClient] != -1)
			SetNadeTimestamp(g_iDoingSmokeNum[iClient], fNow);

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
	EndNadeProbe(iClient, "spawn");
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
	ResetClientNadeSolve(iClient, "spawn");
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
	EndNadeProbe(iClient, "team_changed");
	if (!IsValidClient(iClient))
		return;

	ResetBotReaction(iClient, "team_changed");
	ResetClientNadeSolve(iClient, "team_changed");
	CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public Action BotMimic_OnPlayerStartsMimicing(int iClient, char[] szName, char[] szCategory, char[] szPath)
{
	CancelNadeSolveJob(iClient, "botmimic_start");
	return Plugin_Continue;
}

public void BotMimic_OnPlayerStopsMimicing(int iClient, char[] szName, char[] szCategory, char[] szPath)
{
	CancelNadeSolveJob(iClient, "botmimic_stop");
    g_iDoingSmokeNum[iClient] = -1;
	ResetClientLegacyDefaultNadeTracking(iClient);
    ClearClientScriptAction(iClient);
}

public void OnClientDisconnect(int iClient)
{
	ResetBotReaction(iClient, "disconnect");
	EndNadeProbe(iClient, "disconnect");
	EndNadeObservation(iClient, "disconnect");
	strcopy(g_szNadeCleanupContext, sizeof(g_szNadeCleanupContext), "disconnect");
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
	g_bThrowGrenade[iClient] = false;
	g_bUncrouch[iClient] = false;
	g_iTarget[iClient] = -1;
	g_iPrevTarget[iClient] = -1;
	g_iDoingSmokeNum[iClient] = -1;
	ResetClientLegacyDefaultNadeTracking(iClient);
	ClearClientScriptAction(iClient);
	g_bPeekAssigned[iClient] = false;
	g_bAngleAssigned[iClient] = false;
	g_iActiveWeapon[iClient] = -1;
	g_fLookAngleMaxAccel[iClient] = 0.0;
	g_fReactionTime[iClient] = 0.0;
	g_fAggression[iClient] = 0.0;
	g_fShootTimestamp[iClient] = 0.0;
	g_fThrowNadeTimestamp[iClient] = 0.0;
	g_fCrouchTimestamp[iClient] = 0.0;
	g_fSniperRetreatCooldown[iClient] = 0.0;
	g_fWeaponPickupCooldown[iClient] = 0.0;
	g_fNadeLineupCooldown[iClient] = 0.0;
	g_pCurrArea[iClient] = INVALID_NAV_AREA;
	ResetClientSaveTarget(iClient);
	ResetClientBombMove(iClient);
	ResetClientNadeSolve(iClient, "disconnect");
	g_szCrosshairCode[iClient][0] = '\0';
	g_szNadeCleanupContext[0] = '\0';
}

void ParseMapNades(const char[] szMap)
{
	delete g_aNades;
	g_aNades = new ArrayList(sizeof(NadeLineup));

	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/bot_nades.txt");

	if (!FileExists(szPath))
	{
		PrintToServer("Configuration file %s is not found.", szPath);
		return;
	}

	KeyValues hKv = new KeyValues("Nades");
	if (!hKv.ImportFromFile(szPath))
	{
		delete hKv;
		PrintToServer("Unable to parse Key Values file %s.", szPath);
		return;
	}

	if (!hKv.JumpToKey(szMap))
	{
		delete hKv;
		PrintToServer("No nades found for %s.", szMap);
		return;
	}

	if (!hKv.GotoFirstSubKey())
	{
		delete hKv;
		PrintToServer("Nades are not configured right for %s.", szMap);
		return;
	}

	do
	{
		NadeLineup sNade;
		char szEntry[128];
		char szTeam[4];

		hKv.GetSectionName(szEntry, sizeof(szEntry));

		if (!ReadLegacyNadeVectorField(hKv, szMap, szEntry, "position", sNade.fPos))
			continue;

		if (!ReadLegacyNadeVectorField(hKv, szMap, szEntry, "lookat", sNade.fLook))
			continue;

		sNade.iDefIndex = hKv.GetNum("nadedefindex");
		hKv.GetString("replay", sNade.szReplay, sizeof(sNade.szReplay));
		sNade.fTimestamp = hKv.GetFloat("timestamp");

		sNade.iTeam = CS_TEAM_NONE;
		hKv.GetString("team", szTeam, sizeof(szTeam));
		if (strcmp(szTeam, "CT", false) == 0)
			sNade.iTeam = CS_TEAM_CT;
		else if (strcmp(szTeam, "T", false) == 0)
			sNade.iTeam = CS_TEAM_T;

		g_aNades.PushArray(sNade);
	}
	while (hKv.GotoNextKey());

	delete hKv;
}

bool ReadLegacyNadeVectorField(KeyValues hKv, const char[] szMap, const char[] szEntry, const char[] szField, float fVector[3])
{
	char szValue[128];
	hKv.GetString(szField, szValue, sizeof(szValue));

	if (!ParseScriptVector(szValue, fVector))
	{
		PrintToServer("Warning: skipping legacy nade config=configs/bot_nades.txt map=%s entry=%s field=%s value=\"%s\" reason=malformed vector.", szMap, szEntry, szField, szValue);
		return false;
	}

	return true;
}

void ParseScriptLineups(const char[] szConfig, const char[] szRoot, const char[] szMap, ArrayList &aLineups)
{
	delete aLineups;
	aLineups = new ArrayList(sizeof(ScriptLineup));

	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), szConfig);

	if (!FileExists(szPath))
	{
		PrintToServer("Warning: script lineup config %s (%s) is not found for root %s map %s.", szConfig, szPath, szRoot, szMap);
		return;
	}

	KeyValues hKv = new KeyValues(szRoot);
	if (!hKv.ImportFromFile(szPath))
	{
		delete hKv;
		PrintToServer("Warning: unable to parse script lineup config %s for root %s map %s.", szConfig, szRoot, szMap);
		return;
	}

	if (!hKv.JumpToKey(szMap))
	{
		delete hKv;
		PrintToServer("Warning: script lineup config %s root %s has no map %s.", szConfig, szRoot, szMap);
		return;
	}

	if (!hKv.GotoFirstSubKey())
	{
		delete hKv;
		PrintToServer("Warning: script lineup config %s root %s map %s has no entries.", szConfig, szRoot, szMap);
		return;
	}

	do
	{
		ScriptLineup sLineup;
		char szEntry[128];
		char szTeam[16];

		hKv.GetSectionName(szEntry, sizeof(szEntry));

		if (!ReadScriptVectorField(hKv, szConfig, szMap, szEntry, "position", sLineup.fPos))
			continue;

		if (!ReadScriptVectorField(hKv, szConfig, szMap, szEntry, "lookat", sLineup.fLook))
			continue;

		sLineup.iDefIndex = hKv.GetNum("nadedefindex");
		hKv.GetString("replay", sLineup.szReplay, sizeof(sLineup.szReplay));
		if (sLineup.szReplay[0] == '\0')
		{
			PrintScriptLineupWarning(szConfig, szMap, szEntry, "replay", sLineup.szReplay, "missing replay");
			continue;
		}

		if (!ScriptReplayExists(sLineup.szReplay))
		{
			PrintScriptLineupWarning(szConfig, szMap, szEntry, "replay", sLineup.szReplay, "replay file not found");
			continue;
		}

		if (!ReadScriptFloatField(hKv, szConfig, szMap, szEntry, "timestamp", sLineup.fTimestamp))
			continue;

		sLineup.fClaimTime = 0.0;
		sLineup.fFailureUntil = 0.0;
		sLineup.iClaimClient = 0;
		sLineup.iFreezeUntilRound = 0;
		sLineup.iTeam = CS_TEAM_NONE;

		hKv.GetString("team", szTeam, sizeof(szTeam));
		if (strcmp(szTeam, "CT", false) == 0)
			sLineup.iTeam = CS_TEAM_CT;
		else if (strcmp(szTeam, "T", false) == 0)
			sLineup.iTeam = CS_TEAM_T;
		else
		{
			PrintScriptLineupWarning(szConfig, szMap, szEntry, "team", szTeam, "missing or invalid team");
			continue;
		}

		aLineups.PushArray(sLineup);
	}
	while (hKv.GotoNextKey());

	delete hKv;
}

void ParseRoundStrategies()
{
	char szMap[PLATFORM_MAX_PATH];
	GetCurrentMap(szMap, sizeof(szMap));
	GetMapDisplayName(szMap, szMap, sizeof(szMap));

	int iMode = IsRegulationPistolRound() ? 1 : 0;
	if (g_iStrategyConfigMode == iMode && strcmp(g_szStrategyConfigMap, szMap, false) == 0 && g_aStrategies != null && g_aStrategyRoles != null)
		return;

	delete g_aStrategies;
	delete g_aStrategyRoles;
	g_aStrategies = new ArrayList(sizeof(StrategyConfig));
	g_aStrategyRoles = new ArrayList(sizeof(StrategyRole));
	g_iStrategyConfigMode = iMode;
	strcopy(g_szStrategyConfigMap, sizeof(g_szStrategyConfigMap), szMap);

	if (iMode == 1)
		ParseMapStrategies("configs/bot_strategies_pistol.txt", "pistolstrats", szMap);
	else
		ParseMapStrategies("configs/bot_strategies.txt", "Strategies", szMap);
}

void ParseMapStrategies(const char[] szConfig, const char[] szRoot, const char[] szMap)
{
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), szConfig);

	if (!FileExists(szPath))
		return;

	KeyValues hKv = new KeyValues(szRoot);
	if (!hKv.ImportFromFile(szPath) || !hKv.JumpToKey(szMap) || !hKv.GotoFirstSubKey())
	{
		delete hKv;
		return;
	}

	do
	{
		StrategyConfig sStrategy;
		char szStrategyName[64];
		char szTeam[16];

		hKv.GetSectionName(szStrategyName, sizeof(szStrategyName));
		hKv.GetString("team", szTeam, sizeof(szTeam), "T");
		if (strcmp(szTeam, "T", false) != 0)
			continue;

		sStrategy.fChance = hKv.GetFloat("chance", 0.0);
		sStrategy.iMinPlayers = hKv.GetNum("minplayers", 1);
		sStrategy.fTimeout = hKv.GetFloat("timeout", 12.0);
		sStrategy.iRoleStart = g_aStrategyRoles.Length;
		sStrategy.iRoleCount = 0;

		if (hKv.GotoFirstSubKey())
		{
			do
			{
				StrategyRole sRole;
				char szRoleName[64];
				char szEntry[160];

				hKv.GetSectionName(szRoleName, sizeof(szRoleName));
				Format(szEntry, sizeof(szEntry), "%s/%s", szStrategyName, szRoleName);

				if (!ReadScriptVectorField(hKv, szConfig, szMap, szEntry, "position", sRole.fPos))
					continue;

				if (!ReadScriptVectorField(hKv, szConfig, szMap, szEntry, "lookat", sRole.fLook))
					continue;

				hKv.GetString("replay", sRole.szReplay, sizeof(sRole.szReplay));
				if (sRole.szReplay[0] == '\0' || !ScriptReplayExists(sRole.szReplay))
					continue;

				ReadStrategyUtility(hKv, "utility1", sRole.iUtility1DefIndex, sRole.iUtility1Amount);
				ReadStrategyUtility(hKv, "utility2", sRole.iUtility2DefIndex, sRole.iUtility2Amount);
				sRole.iClient = 0;

				g_aStrategyRoles.PushArray(sRole);
				sStrategy.iRoleCount++;
			}
			while (hKv.GotoNextKey());

			hKv.GoBack();
		}

		if (sStrategy.iRoleCount > 0)
			g_aStrategies.PushArray(sStrategy);
	}
	while (hKv.GotoNextKey());

	delete hKv;
}

void ReadStrategyUtility(KeyValues hKv, const char[] szKey, int &iDefIndex, int &iAmount)
{
	char szValue[32];
	iDefIndex = 0;
	iAmount = 0;
	hKv.GetString(szKey, szValue, sizeof(szValue), "");

	if (szValue[0] == '\0')
		return;

	char szParts[2][16];
	int iParts = ExplodeString(szValue, " ", szParts, sizeof(szParts), sizeof(szParts[]));
	if (iParts < 1)
		return;

	iDefIndex = StringToInt(szParts[0]);
	iAmount = (iParts >= 2) ? StringToInt(szParts[1]) : 1;
	if (iDefIndex <= 0)
	{
		iDefIndex = 0;
		iAmount = 0;
	}
	else if (iAmount <= 0)
	{
		iAmount = 1;
	}
}

bool ReadScriptVectorField(KeyValues hKv, const char[] szConfig, const char[] szMap, const char[] szEntry, const char[] szField, float fVector[3])
{
	char szValue[128];
	hKv.GetString(szField, szValue, sizeof(szValue));

	if (!ParseScriptVector(szValue, fVector))
	{
		PrintScriptLineupWarning(szConfig, szMap, szEntry, szField, szValue, "malformed vector");
		return false;
	}

	return true;
}

bool ReadScriptFloatField(KeyValues hKv, const char[] szConfig, const char[] szMap, const char[] szEntry, const char[] szField, float &fValue)
{
	char szValue[32];
	hKv.GetString(szField, szValue, sizeof(szValue));

	if (!ParseScriptFloat(szValue, fValue))
	{
		PrintScriptLineupWarning(szConfig, szMap, szEntry, szField, szValue, "malformed float");
		return false;
	}

	return true;
}

bool ParseScriptFloat(const char[] szValue, float &fValue)
{
	int iLen = strlen(szValue);
	int iPos = 0;
	char szToken[32];

	while (iPos < iLen && IsVectorWhitespace(szValue[iPos]))
		iPos++;

	int iTokenLen = 0;
	while (iPos < iLen && !IsVectorWhitespace(szValue[iPos]))
	{
		if (iTokenLen >= sizeof(szToken) - 1)
			return false;

		szToken[iTokenLen++] = szValue[iPos++];
	}
	szToken[iTokenLen] = '\0';

	while (iPos < iLen && IsVectorWhitespace(szValue[iPos]))
		iPos++;

	if (iPos != iLen || !IsStrictFloatToken(szToken))
		return false;

	fValue = StringToFloat(szToken);
	return true;
}

bool ParseScriptVector(const char[] szValue, float fVector[3])
{
	int iLen = strlen(szValue);
	int iPos = 0;
	int iTokenCount = 0;
	char szToken[32];

	while (iPos < iLen)
	{
		while (iPos < iLen && IsVectorWhitespace(szValue[iPos]))
			iPos++;

		if (iPos >= iLen)
			break;

		if (iTokenCount >= 3)
			return false;

		int iTokenLen = 0;
		while (iPos < iLen && !IsVectorWhitespace(szValue[iPos]))
		{
			if (iTokenLen >= sizeof(szToken) - 1)
				return false;

			szToken[iTokenLen++] = szValue[iPos++];
		}
		szToken[iTokenLen] = '\0';

		if (!IsStrictFloatToken(szToken))
			return false;

		fVector[iTokenCount++] = StringToFloat(szToken);
	}

	return iTokenCount == 3;
}

bool IsVectorWhitespace(int iChar)
{
	return (iChar == ' ' || iChar == '\t' || iChar == '\r' || iChar == '\n');
}

bool IsStrictFloatToken(const char[] szToken)
{
	int iLen = strlen(szToken);
	if (iLen == 0)
		return false;

	int iPos = 0;
	if (szToken[iPos] == '+' || szToken[iPos] == '-')
		iPos++;

	bool bSawDigit = false;
	bool bSawDot = false;
	for (; iPos < iLen; iPos++)
	{
		if (szToken[iPos] >= '0' && szToken[iPos] <= '9')
		{
			bSawDigit = true;
			continue;
		}

		if (szToken[iPos] == '.' && !bSawDot)
		{
			bSawDot = true;
			continue;
		}

		return false;
	}

	return bSawDigit;
}

bool ScriptReplayExists(const char[] szReplay)
{
	if (FileExists(szReplay))
		return true;

	if (StrContains(szReplay, "addons/sourcemod/", false) == 0)
	{
		char szPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, szPath, sizeof(szPath), szReplay[17]);
		return FileExists(szPath);
	}

	return false;
}

void PrintScriptLineupWarning(const char[] szConfig, const char[] szMap, const char[] szEntry, const char[] szField, const char[] szValue, const char[] szReason)
{
	PrintToServer("Warning: skipping script lineup config=%s map=%s entry=%s field=%s value=\"%s\" reason=%s.", szConfig, szMap, szEntry, szField, szValue, szReason);
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
	g_iBotLookAtInhibitUntilOffset = SetupOffset(hConf, "CCSBot::SetLookAtInhibitUntil");
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
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CCSBot::ThrowGrenade");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	if ((g_hBotThrowGrenade = EndPrepSDKCall()) == null)
		SetFailState("Failed to create SDKCall: CCSBot::ThrowGrenade");

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
	SetupDetour(hConf, "CCSBot::OnAudibleEvent", Hook_Pre, CCSBot_OnAudibleEvent);
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
	if (g_sNadeThrows[iClient].active && g_bNadeThrowPending[iClient] && g_sNadeThrows[iClient].equipRequests++ == 0)
		LogNadeProbe("[NadeProbe] equip_request userid=%d throw_id=%d active_weapon=%d dispatches=%d must_equip=%d", GetClientUserId(iClient), g_sNadeThrows[iClient].throwId, GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"), g_sNadeThrows[iClient].dispatches, bMustEquip);
	SDKCall(g_hBotEquipBestWeapon, iClient, bMustEquip);
}

public void BotSetLookAt(int iClient, const char[] szDesc, const float fPos[3], PriorityType ePri, float fDuration, bool bClearIfClose, float fAngleTolerance, bool bAttack)
{
	SDKCall(g_hBotSetLookAt, iClient, szDesc, fPos, ePri, fDuration, bClearIfClose, fAngleTolerance, bAttack);
}

public void BotThrowGrenade(int iClient, const float fTarget[3])
{
	if (g_sNadeProbes[iClient].userId != 0)
	{
		if (!IsNadeProbeThrowAllowed(iClient))
		{
			EndNadeProbe(iClient, "dispatch_environment");
			return;
		}
		int iWeapon = EntRefToEntIndex(g_sNadeThrows[iClient].weaponRef);
		if (iWeapon <= MaxClients || !IsValidEntity(iWeapon) || GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") != iWeapon || GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack") > GetGameTime() || GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack") > GetGameTime())
			return;
	}
	if (g_sNadeThrows[iClient].active)
	{
		int iWeapon = EntRefToEntIndex(g_sNadeThrows[iClient].weaponRef);
		if (iWeapon <= MaxClients || !IsValidEntity(iWeapon) || GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon") != iWeapon || GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") != iClient)
			EndNadeObservation(iClient, "dispatch_weapon_mismatch");
	}
	// ThrowGrenade arms its state before SetLookAt can reject a blinded bot.
	// Wait without arming it; the existing three-second cleanup still applies.
	if (GetEntDataFloat(iClient, g_iBotLookAtInhibitUntilOffset) > GetGameTime())
	{
		if (g_sNadeThrows[iClient].active && !g_sNadeThrows[iClient].lookDeferred)
		{
			g_sNadeThrows[iClient].lookDeferred = true;
			LogNadeDispatchState(iClient, "look_blocked");
		}
		return;
	}
	if (g_sNadeThrows[iClient].active)
	{
		g_sNadeThrows[iClient].dispatches++;
		if (g_sNadeThrows[iClient].dispatches == 1)
		{
			LogNadeThrow(iClient, "dispatch");
			LogNadeDispatchState(iClient, "first_dispatch");
		}
	}
	SDKCall(g_hBotThrowGrenade, iClient, fTarget);
	if (g_bNadeDetail && g_sNadeThrows[iClient].active && (g_sNadeThrows[iClient].dispatches == 1 || g_sNadeThrows[iClient].dispatches % 32 == 0))
		LogNadeDispatchState(iClient, "after_dispatch");
}

void LogNadeDispatchState(int iClient, const char[] szStage)
{
	if (!g_bNadeDetail || !g_sNadeThrows[iClient].active)
		return;
	int iWeapon = EntRefToEntIndex(g_sNadeThrows[iClient].weaponRef);
	if (iWeapon <= MaxClients || !IsValidEntity(iWeapon))
		return;
	float fAngles[3];
	GetClientEyeAngles(iClient, fAngles);
	bool bHasPin = HasEntProp(iWeapon, Prop_Send, "m_bPinPulled");
	bool bHasThrowTime = HasEntProp(iWeapon, Prop_Send, "m_fThrowTime");
	int iLookState = GetEntData(iClient, g_iBotLookAtSpotStateOffset);
	int iPriority = -1, iThrowState = -1;
	float fNativeLook[3], fLookGateUntil = -1.0;
	bool bKnownLayout = g_iBotLookAtSpotStateOffset == 0x5a38;
	if (bKnownLayout)
	{
		GetEntDataVector(iClient, g_iBotLookAtSpotStateOffset + 4, fNativeLook);
		iPriority = GetEntData(iClient, g_iBotLookAtSpotStateOffset + 0x10);
		iThrowState = GetEntData(iClient, g_iBotLookAtSpotStateOffset + 0x144);
		fLookGateUntil = GetEntDataFloat(iClient, g_iBotLookAtInhibitUntilOffset);
	}
	LogNadeProbe("[NadeProbe] dispatch_state userid=%d throw_id=%d stage=%s angles=%.3f,%.3f,%.3f lookpoint=%.3f,%.3f,%.3f pin=%d throw_time=%.6f now=%.6f look_state=%d native_layout=%d native_look=%.3f,%.3f,%.3f priority=%d throw_state=%d look_gate_until=%.6f next_attack=%.6f flash_duration=%.6f", GetClientUserId(iClient), g_sNadeThrows[iClient].throwId, szStage, fAngles[0], fAngles[1], fAngles[2], g_fNadeTarget[iClient][0], g_fNadeTarget[iClient][1], g_fNadeTarget[iClient][2], bHasPin ? GetEntProp(iWeapon, Prop_Send, "m_bPinPulled") : -1, bHasThrowTime ? GetEntPropFloat(iWeapon, Prop_Send, "m_fThrowTime") : -1.0, GetGameTime(), iLookState, bKnownLayout, fNativeLook[0], fNativeLook[1], fNativeLook[2], iPriority, iThrowState, fLookGateUntil, GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack"), HasEntProp(iClient, Prop_Send, "m_flFlashDuration") ? GetEntPropFloat(iClient, Prop_Send, "m_flFlashDuration") : -1.0);
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

void SwitchWeapon(int iClient, int iWeapon, const char[] szCaller)
{
	bool bLog = g_sNadeThrows[iClient].active && g_bNadeThrowPending[iClient] && g_sNadeThrows[iClient].switchRequests++ < 2;
	SDKCall(g_hSwitchWeaponCall, iClient, iWeapon, 0);
	if (bLog)
		LogNadeProbe("[NadeProbe] switch_request userid=%d throw_id=%d requested_weapon=%d active_after=%d dispatches=%d requested_defindex=%d pro=%d safe=%d dont_switch=%d caller=%s", GetClientUserId(iClient), g_sNadeThrows[iClient].throwId, iWeapon, GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"), g_sNadeThrows[iClient].dispatches, iWeapon > MaxClients && IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") : -1, g_bIsProBot[iClient], IsSafe(iClient), g_bDontSwitch[iClient], szCaller);
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

bool CanThrowNade(int iClient)
{
	return (GetGameTime() - g_fThrowNadeTimestamp[iClient] > 5.0 && IsValidEntity(GetPlayerWeaponSlot(iClient, CS_SLOT_GRENADE)));
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

	CancelClientActiveLineupActions(iClient, false);
	if (BotMimic_IsPlayerMimicing(iClient))
		BotMimic_StopPlayerMimic(iClient);
	g_bThrowGrenade[iClient] = false;

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

bool IsEnemyNearBomb()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != CS_TEAM_CT)
			continue;

		float fPos[3];
		GetClientAbsOrigin(i, fPos);
		if (GetVectorDistance(fPos, g_fBombPos) < 500.0)
			return true;
	}
	return false;
}

int FindNadeByDefIndex(int iClient, const int[] iDefIndices, int iCount)
{
	for (int i = 0; i < iCount; i++)
	{
		int iWeapon = eItems_FindWeaponByDefIndex(iClient, iDefIndices[i]);
		if (IsValidEntity(iWeapon))
			return iWeapon;
	}
	return -1;
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

public int GetNearestGrenade(int iClient)
{
	if (g_bBombPlanted || g_bRoundDecided)
		return -1;

	int iClosestNade = -1;
	float fOrigin[3], fDist, fClosestDist = -1.0;

	GetClientAbsOrigin(iClient, fOrigin);

	for (int i = 0; i < g_aNades.Length; i++)
	{
		NadeLineup sNade;
		g_aNades.GetArray(i, sNade);

		if ((GetGameTime() - sNade.fTimestamp) < LEGACY_DEFAULT_NADE_RETRY_COOLDOWN)
			continue;

		if (GetClientTeam(iClient) != sNade.iTeam)
			continue;

		int iEntity = eItems_FindWeaponByDefIndex(iClient, sNade.iDefIndex);
		if (!IsValidEntity(iEntity))
			continue;

		fDist = GetVectorDistance(fOrigin, sNade.fPos);
		if (fDist > 250.0)
			continue;

		if (fDist < fClosestDist || fClosestDist == -1.0)
		{
			iClosestNade = i;
			fClosestDist = fDist;
		}
	}

	return iClosestNade;
}

int GetNearestScriptLineup(int iClient, ArrayList aLineups, bool bRequireWeapon, bool bRequireClearLookLine = false)
{
	if (aLineups == null || aLineups.Length == 0)
		return -1;

	int iClosestLineup = -1;
	float fOrigin[3], fEyes[3], fDist, fClosestDist = -1.0;
	float fNow = GetGameTime();

	GetClientAbsOrigin(iClient, fOrigin);
	if (bRequireClearLookLine)
		GetClientEyePosition(iClient, fEyes);

	for (int i = 0; i < aLineups.Length; i++)
	{
		ScriptLineup sLineup;
		aLineups.GetArray(i, sLineup);

		if (sLineup.fTimestamp > 0.0 && (fNow - sLineup.fTimestamp) < 25.0)
			continue;

		if (sLineup.fFailureUntil > fNow)
			continue;

		if (sLineup.iClaimClient != iClient && (fNow - sLineup.fClaimTime) < 10.0 && IsValidClient(sLineup.iClaimClient) && IsPlayerAlive(sLineup.iClaimClient))
			continue;

		if (GetClientTeam(iClient) != sLineup.iTeam)
			continue;

		if (bRequireClearLookLine && LineGoesThroughSmoke(fEyes, sLineup.fLook))
			continue;

		if (bRequireWeapon)
		{
			int iEntity = eItems_FindWeaponByDefIndex(iClient, sLineup.iDefIndex);
			if (!IsValidEntity(iEntity))
				continue;
		}

		fDist = GetVectorDistance(fOrigin, sLineup.fPos);
		if (fDist > 250.0)
			continue;

		if (fDist < fClosestDist || fClosestDist == -1.0)
		{
			iClosestLineup = i;
			fClosestDist = fDist;
		}
	}

	if (iClosestLineup != -1)
	{
		ScriptLineup sLineup;
		aLineups.GetArray(iClosestLineup, sLineup);
		sLineup.fClaimTime = fNow;
		sLineup.iClaimClient = iClient;
		aLineups.SetArray(iClosestLineup, sLineup);
	}

	return iClosestLineup;
}

bool IsScriptLineupCandidateForClient(int iClient, ArrayList aLineups, int iLineup, bool bRequireWeapon, bool bRequireClearLookLine, bool bRespectPeekFreeze, float fNow)
{
	if (aLineups == null || iLineup < 0 || iLineup >= aLineups.Length)
		return false;

	ScriptLineup sLineup;
	aLineups.GetArray(iLineup, sLineup);

	if (sLineup.fTimestamp > 0.0 && (fNow - sLineup.fTimestamp) < 25.0)
		return false;

	if (sLineup.fFailureUntil > fNow)
		return false;

	if (bRespectPeekFreeze && sLineup.iFreezeUntilRound > 0 && g_iCurrentRound <= sLineup.iFreezeUntilRound)
		return false;

	if (sLineup.iClaimClient != iClient && (fNow - sLineup.fClaimTime) < 10.0 && IsValidClient(sLineup.iClaimClient) && IsPlayerAlive(sLineup.iClaimClient))
		return false;

	if (GetClientTeam(iClient) != sLineup.iTeam)
		return false;

	if (bRequireClearLookLine)
	{
		float fEyes[3];
		GetClientEyePosition(iClient, fEyes);
		if (LineGoesThroughSmoke(fEyes, sLineup.fLook))
			return false;
	}

	if (bRequireWeapon)
	{
		int iEntity = eItems_FindWeaponByDefIndex(iClient, sLineup.iDefIndex);
		if (!IsValidEntity(iEntity))
			return false;
	}

	float fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	return GetVectorDistance(fOrigin, sLineup.fPos) <= 250.0;
}

bool HasAvailablePeekLineup(int iClient, float fNow)
{
	for (int i = 0; i < g_aPeeks.Length; i++)
	{
		if (IsScriptLineupCandidateForClient(iClient, g_aPeeks, i, false, false, true, fNow))
			return true;
	}

	return false;
}

int GetRandomPeekLineup(int iClient, float fNow)
{
	int iSelectedLineup = -1;
	int iCandidateCount = 0;

	for (int i = 0; i < g_aPeeks.Length; i++)
	{
		if (!IsScriptLineupCandidateForClient(iClient, g_aPeeks, i, false, false, true, fNow))
			continue;

		iCandidateCount++;
		if (Math_GetRandomInt(1, iCandidateCount) == 1)
			iSelectedLineup = i;
	}

	if (iSelectedLineup != -1)
	{
		ScriptLineup sLineup;
		g_aPeeks.GetArray(iSelectedLineup, sLineup);
		sLineup.fClaimTime = fNow;
		sLineup.iClaimClient = iClient;
		g_aPeeks.SetArray(iSelectedLineup, sLineup);
	}

	return iSelectedLineup;
}

void AssignClientScriptLineupAction(int iClient, int iLineup, ScriptAction iAction, float fNow)
{
	g_iScriptAction[iClient] = iAction;
	g_iScriptActionIndex[iClient] = iLineup;
	g_fScriptActionStart[iClient] = fNow;
	g_fScriptActionLastMoveTime[iClient] = fNow;
	g_fScriptNextMoveAt[iClient] = 0.0;
	GetClientAbsOrigin(iClient, g_fScriptActionLastPos[iClient]);
}

bool TryAssignTeamPeekScriptLineup(int iTeam, float fNow)
{
	if (iTeam != CS_TEAM_T && iTeam != CS_TEAM_CT)
		return false;

	if (g_bRoundDecided || g_bTeamPeekUsedRound[iTeam] || g_aPeeks == null || g_aPeeks.Length == 0)
		return false;

	int iCandidates[MAXPLAYERS+1];
	int iCandidateCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsPeekScriptLineupAllowed(i, fNow) || GetClientTeam(i) != iTeam || !HasAvailablePeekLineup(i, fNow))
			continue;

		iCandidates[iCandidateCount++] = i;
	}

	if (iCandidateCount == 0)
		return false;

	if (!g_bTeamPeekRollResolved[iTeam])
	{
		g_bTeamPeekRollResolved[iTeam] = true;
		g_bTeamPeekRollPassed[iTeam] = IsItMyChance(SCRIPT_PEEK_CHANCE);
	}

	if (!g_bTeamPeekRollPassed[iTeam])
		return false;

	int iClient = iCandidates[Math_GetRandomInt(1, iCandidateCount) - 1];
	int iLineup = GetRandomPeekLineup(iClient, fNow);
	if (iLineup == -1)
		return false;

	AssignClientScriptLineupAction(iClient, iLineup, ScriptAction_Peek, fNow);
	g_bTeamPeekUsedRound[iTeam] = true;
	return true;
}

bool TryAssignScriptLineup(int iClient, ArrayList aLineups, ScriptAction iAction, bool bRequireWeapon)
{
	if (g_bRoundDecided)
		return false;

	if (iAction == ScriptAction_PostPlantNade && !IsPostPlantScriptLineupAllowed(iClient))
		return false;

	if (iAction == ScriptAction_Angle && !IsAngleScriptLineupAllowed(iClient, GetGameTime()))
		return false;

	int iLineup = GetNearestScriptLineup(iClient, aLineups, bRequireWeapon, iAction == ScriptAction_Angle);
	if (iLineup == -1)
		return false;

	AssignClientScriptLineupAction(iClient, iLineup, iAction, GetGameTime());

	return true;
}

void TrySelectStrategy()
{
	if (g_iActiveStrategy != -1 || g_aStrategies == null || g_aStrategies.Length == 0 || IsBotMimicBlockedPhase() || !g_bFreezetimeEnd || g_bBombPlanted || g_bRoundDecided)
		return;

	for (int i = 0; i < g_aStrategies.Length; i++)
	{
		StrategyConfig sStrategy;
		g_aStrategies.GetArray(i, sStrategy);

		if (!IsItMyChance(sStrategy.fChance))
			continue;

		if (!TryAssignStrategy(i))
			continue;

		g_bStrategyStarted = false;
		g_iActiveStrategy = i;
		g_fStrategyAssignTime = GetGameTime();
		return;
	}
}

bool TryAssignStrategy(int iStrategy)
{
	StrategyConfig sStrategy;
	g_aStrategies.GetArray(iStrategy, sStrategy);

	int iSkipRole = GetStrategySkipRole(sStrategy);
	if (iSkipRole == -2)
		return false;

	bool bUsed[MAXPLAYERS + 1];
	for (int i = 1; i <= MaxClients; i++)
		bUsed[i] = false;

	for (int iPass = 0; iPass < 2; iPass++)
	{
		for (int iRole = 0; iRole < sStrategy.iRoleCount; iRole++)
		{
			int iRoleIndex = sStrategy.iRoleStart + iRole;
			StrategyRole sRole;
			g_aStrategyRoles.GetArray(iRoleIndex, sRole);

			bool bHasUtility = StrategyRoleHasUtility(sRole);
			if ((iPass == 0 && !bHasUtility) || (iPass == 1 && bHasUtility))
				continue;

			if (iRole == iSkipRole)
			{
				sRole.iClient = -1;
				g_aStrategyRoles.SetArray(iRoleIndex, sRole);
				continue;
			}

			int iClient = FindBotForStrategyRole(CS_TEAM_T, sRole, bUsed);
			if (iClient == 0)
			{
				ClearActiveStrategy(false);
				return false;
			}

			bUsed[iClient] = true;
			sRole.iClient = iClient;
			g_aStrategyRoles.SetArray(iRoleIndex, sRole);
			g_iClientStrategyRole[iClient] = iRoleIndex;
			CancelClientActiveLineupActions(iClient, false);
		}
	}

	return true;
}

int GetStrategySkipRole(StrategyConfig sStrategy)
{
	int iFakeCount = GetAliveTeamCount(CS_TEAM_T, true);
	int iHumanCount = GetAliveTeamCount(CS_TEAM_T, false);

	if ((iFakeCount + iHumanCount) < sStrategy.iMinPlayers)
		return -2;

	if (iFakeCount >= sStrategy.iRoleCount)
		return -1;

	if (iHumanCount <= 0 || iFakeCount < sStrategy.iRoleCount - 1)
		return -2;

	for (int iRole = 0; iRole < sStrategy.iRoleCount; iRole++)
	{
		StrategyRole sRole;
		g_aStrategyRoles.GetArray(sStrategy.iRoleStart + iRole, sRole);
		if (!StrategyRoleHasUtility(sRole))
			return iRole;
	}

	return -2;
}

int FindBotForStrategyRole(int iTeam, StrategyRole sRole, bool bUsed[MAXPLAYERS + 1])
{
	int iBestClient = 0;
	float fBestDistance = -1.0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (bUsed[i] || !IsValidClient(i) || !IsFakeClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != iTeam)
			continue;

		if (!IsClientScriptIdle(i) || GetEntityMoveType(i) == MOVETYPE_LADDER || !ClientMeetsStrategyUtility(i, sRole))
			continue;

		float fOrigin[3];
		GetClientAbsOrigin(i, fOrigin);
		float fDistance = GetVectorDistance(fOrigin, sRole.fPos);
		if (fDistance < fBestDistance || fBestDistance < 0.0)
		{
			iBestClient = i;
			fBestDistance = fDistance;
		}
	}

	return iBestClient;
}

bool HandleStrategyBot(int iClient, bool bEnemyVisible)
{
	int iRoleIndex = g_iClientStrategyRole[iClient];
	if (iRoleIndex < 0 || g_aStrategyRoles == null || iRoleIndex >= g_aStrategyRoles.Length || g_iActiveStrategy < 0)
		return false;

	StrategyConfig sStrategy;
	StrategyRole sRole;
	g_aStrategies.GetArray(g_iActiveStrategy, sStrategy);
	g_aStrategyRoles.GetArray(iRoleIndex, sRole);

	if (g_bBombPlanted || g_bRoundDecided || !IsPlayerAlive(iClient) || GetClientTeam(iClient) != CS_TEAM_T)
	{
		ClearActiveStrategy(g_bStrategyStarted);
		return false;
	}

	if (g_bStrategyStarted)
	{
		if (bEnemyVisible && BotMimic_IsPlayerMimicing(iClient))
		{
			BotMimic_StopPlayerMimic(iClient);
			BotEquipBestWeapon(iClient, true);
			sRole.iClient = 0;
			g_aStrategyRoles.SetArray(iRoleIndex, sRole);
			g_iClientStrategyRole[iClient] = -1;
			CheckActiveStrategyFinished();
			return false;
		}

		CheckActiveStrategyFinished();
		return g_iClientStrategyRole[iClient] != -1;
	}

	float fNow = GetGameTime();
	if ((fNow - g_fStrategyAssignTime) > sStrategy.fTimeout || !ClientMeetsStrategyUtility(iClient, sRole))
	{
		ClearActiveStrategy(false);
		return false;
	}

	if (ThrottleScriptMove(iClient, sRole.fPos, fNow))
	{
		SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE), "strategy_move");
		BotMoveTo(iClient, sRole.fPos, FASTEST_ROUTE);
	}

	if (GetVectorDistance(g_fBotOrigin[iClient], sRole.fPos) < STRATEGY_START_DISTANCE)
		BotSetLookAt(iClient, "Strategy start", sRole.fLook, PRIORITY_UNINTERRUPTABLE, 0.5, false, 5.0, false);

	TryStartActiveStrategy();
	return true;
}

void TryStartActiveStrategy()
{
	if (g_bStrategyStarted || g_iActiveStrategy < 0)
		return;

	StrategyConfig sStrategy;
	g_aStrategies.GetArray(g_iActiveStrategy, sStrategy);

	for (int iRole = 0; iRole < sStrategy.iRoleCount; iRole++)
	{
		StrategyRole sRole;
		g_aStrategyRoles.GetArray(sStrategy.iRoleStart + iRole, sRole);
		if (sRole.iClient == -1)
			continue;

		if (!IsValidClient(sRole.iClient) || !IsFakeClient(sRole.iClient) || !IsPlayerAlive(sRole.iClient))
			return;

		float fVelocity[3];
		GetEntPropVector(sRole.iClient, Prop_Data, "m_vecAbsVelocity", fVelocity);
		fVelocity[2] = 0.0;

		if (GetVectorDistance(g_fBotOrigin[sRole.iClient], sRole.fPos) > STRATEGY_START_DISTANCE || GetVectorLength(fVelocity) > STRATEGY_START_SPEED || !(GetEntityFlags(sRole.iClient) & FL_ONGROUND))
			return;
	}

	for (int iRole = 0; iRole < sStrategy.iRoleCount; iRole++)
	{
		StrategyRole sRole;
		g_aStrategyRoles.GetArray(sStrategy.iRoleStart + iRole, sRole);
		if (sRole.iClient == -1)
			continue;

		BMError iError = BotMimic_PlayRecordFromFile(sRole.iClient, sRole.szReplay);
		if (iError != BM_NoError)
		{
			ClearActiveStrategy(true);
			return;
		}
	}

	g_bStrategyStarted = true;
}

void CheckActiveStrategyFinished()
{
	if (!g_bStrategyStarted || g_iActiveStrategy < 0)
		return;

	StrategyConfig sStrategy;
	g_aStrategies.GetArray(g_iActiveStrategy, sStrategy);

	for (int iRole = 0; iRole < sStrategy.iRoleCount; iRole++)
	{
		StrategyRole sRole;
		g_aStrategyRoles.GetArray(sStrategy.iRoleStart + iRole, sRole);
		if (sRole.iClient != -1 && IsValidClient(sRole.iClient) && IsFakeClient(sRole.iClient) && IsPlayerAlive(sRole.iClient) && BotMimic_IsPlayerMimicing(sRole.iClient))
			return;
	}

	ClearActiveStrategy(false);
}

void ClearActiveStrategy(bool bStopMimic)
{
	if (bStopMimic)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_iClientStrategyRole[i] != -1 && IsValidClient(i) && IsFakeClient(i) && BotMimic_IsPlayerMimicing(i))
				BotMimic_StopPlayerMimic(i);
		}
	}

	g_bStrategyStarted = false;
	g_iActiveStrategy = -1;
	g_fStrategyAssignTime = 0.0;

	if (g_aStrategyRoles != null)
	{
		for (int i = 0; i < g_aStrategyRoles.Length; i++)
		{
			StrategyRole sRole;
			g_aStrategyRoles.GetArray(i, sRole);
			sRole.iClient = 0;
			g_aStrategyRoles.SetArray(i, sRole);
		}
	}

	for (int i = 1; i <= MaxClients; i++)
		g_iClientStrategyRole[i] = -1;
}

bool ProcessScriptLineupAction(int iClient, ScriptAction iAction, ArrayList aLineups, float fSpeed, float fNow)
{
	if (g_iScriptAction[iClient] != iAction)
		return false;

	int iLineup = g_iScriptActionIndex[iClient];
	if (aLineups == null || iLineup < 0 || iLineup >= aLineups.Length)
	{
		CancelClientScriptAction(iClient);
		return true;
	}

	if (ShouldCancelScriptLineupAction(iClient, iAction))
	{
		CancelClientScriptAction(iClient);
		return true;
	}

	ScriptLineup sLineup;
	float fActionTimeout = 8.0;
	if (iAction == ScriptAction_Peek)
		fActionTimeout = SCRIPT_PEEK_ACTION_TIMEOUT;
	else if (iAction == ScriptAction_Angle)
		fActionTimeout = SCRIPT_ANGLE_ACTION_TIMEOUT;

	if ((fNow - g_fScriptActionStart[iClient]) > fActionTimeout)
	{
		FailScriptLineup(iClient, aLineups, iLineup, "timed out", fNow);
		return true;
	}

	aLineups.GetArray(iLineup, sLineup);

	bool bNeedsScriptWeapon = (iAction == ScriptAction_Nade || iAction == ScriptAction_PostPlantNade);
	if (GetClientTeam(iClient) != sLineup.iTeam
		|| (bNeedsScriptWeapon && !IsValidEntity(eItems_FindWeaponByDefIndex(iClient, sLineup.iDefIndex)))
		|| (iAction == ScriptAction_Angle && !IsClientCurrentPrimarySniperScout(iClient)))
	{
		CancelClientScriptAction(iClient);
		return true;
	}

	if (iAction == ScriptAction_Angle)
	{
		float fEyes[3];
		GetClientEyePosition(iClient, fEyes);
		if (LineGoesThroughSmoke(fEyes, sLineup.fLook))
		{
			FailScriptLineup(iClient, aLineups, iLineup, "look line blocked by smoke", fNow);
			return true;
		}
	}

	if (BotMimic_IsPlayerMimicing(iClient))
		return true;

	float fDisToLineup = GetVectorDistance(g_fBotOrigin[iClient], sLineup.fPos);
	if (fDisToLineup >= 25.0 && IsScriptLineupMovementStale(iClient, fNow))
	{
		FailScriptLineup(iClient, aLineups, iLineup, "movement stale", fNow);
		return true;
	}

	float fStartDistance = (iAction == ScriptAction_Peek) ? SCRIPT_PEEK_START_DISTANCE : 25.0;
	float fStartSpeed = (iAction == ScriptAction_Peek) ? SCRIPT_PEEK_START_SPEED : 5.0;

	if (ThrottleScriptMove(iClient, sLineup.fPos, fNow))
		BotMoveTo(iClient, sLineup.fPos, FASTEST_ROUTE);
	if (fDisToLineup < fStartDistance)
	{
		BotSetLookAt(iClient, "Use entity", sLineup.fLook, PRIORITY_HIGH, 2.0, false, 3.0, false);
		if (view_as<LookAtSpotState>(GetEntData(iClient, g_iBotLookAtSpotStateOffset)) == LOOK_AT_SPOT && fSpeed < fStartSpeed && (GetEntityFlags(iClient) & FL_ONGROUND))
		{
			BMError iError = BotMimic_PlayRecordFromFile(iClient, sLineup.szReplay);
			if (iError != BM_NoError)
			{
				FailScriptLineup(iClient, aLineups, iLineup, "replay playback failed", fNow, iError);
				return true;
			}

			if (iAction == ScriptAction_Peek)
			{
				g_bPeekAssigned[iClient] = true;
				g_bTeamPeekUsedRound[GetClientTeam(iClient)] = true;
				sLineup.iFreezeUntilRound = g_iCurrentRound + SCRIPT_PEEK_FREEZE_ROUNDS;
			}
			else if (iAction == ScriptAction_Angle)
			{
				g_bAngleAssigned[iClient] = true;
			}

			sLineup.fTimestamp = fNow;
			sLineup.fFailureUntil = 0.0;
			aLineups.SetArray(iLineup, sLineup);

		}
	}

	return true;
}

bool IsCriticalScriptObjectiveTask(TaskType iTask)
{
	return (iTask == PLANT_BOMB || iTask == FIND_TICKING_BOMB || iTask == DEFUSE_BOMB || iTask == GUARD_TICKING_BOMB || iTask == GUARD_BOMB_DEFUSER || iTask == GUARD_LOOSE_BOMB || iTask == COLLECT_HOSTAGES || iTask == RESCUE_HOSTAGES || iTask == ESCAPE_FROM_BOMB || iTask == ESCAPE_FROM_FLAMES);
}

int CountActiveTeamAngles(int iTeam)
{
	int iCount = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iScriptAction[i] != ScriptAction_Angle)
			continue;

		if (!IsValidClient(i) || !IsPlayerAlive(i) || GetClientTeam(i) != iTeam)
			continue;

		iCount++;
	}
	return iCount;
}

bool IsClientCurrentPrimarySniperScout(int iClient)
{
	int iPrimary = GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY);
	if (!IsValidEntity(iPrimary))
		return false;

	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != iPrimary)
		return false;

	int iPrimaryDef = GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex");
	return (iPrimaryDef == DEFIDX_AWP || iPrimaryDef == DEFIDX_SSG08);
}

float GetScriptLiveTime(float fNow)
{
	float fOpeningStart = g_fFreezeTimeEnd;
	if (fOpeningStart <= 0.0)
		fOpeningStart = g_fRoundStart;

	return fNow - fOpeningStart;
}

bool IsPeekScriptLineupAllowed(int iClient, float fNow)
{
	if (!g_bFreezetimeEnd || g_bRoundDecided || !IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient) || !IsClientScriptIdle(iClient))
		return false;

	int iTeam = GetClientTeam(iClient);
	if (iTeam != CS_TEAM_T && iTeam != CS_TEAM_CT)
		return false;

	if (g_bTeamPeekUsedRound[iTeam] || g_bPeekAssigned[iClient] || g_bBombPlanted || g_iAliveCountT == 0 || g_iAliveCountCT == 0)
		return false;

	if (GetScriptLiveTime(fNow) > SCRIPT_PEEK_OPENING_WINDOW)
		return false;

	if (GetEntData(iClient, g_iEnemyVisibleOffset) != 0 || GetEntityMoveType(iClient) == MOVETYPE_LADDER)
		return false;

	if (IsCriticalScriptObjectiveTask(GetTask(iClient)))
		return false;

	return true;
}

bool IsAngleScriptLineupAllowed(int iClient, float fNow)
{
	if (!g_bFreezetimeEnd || g_bRoundDecided || !IsValidClient(iClient) || !IsPlayerAlive(iClient) || !IsFakeClient(iClient) || !IsClientScriptIdle(iClient))
		return false;

	if (g_bAngleAssigned[iClient] || g_bBombPlanted || g_iAliveCountT < 3 || g_iAliveCountCT < 3)
		return false;

	float fLiveTime = GetScriptLiveTime(fNow);
	if (fLiveTime < SCRIPT_ANGLE_LIVE_START || fLiveTime > SCRIPT_ANGLE_LIVE_END)
		return false;

	if (!IsClientCurrentPrimarySniperScout(iClient))
		return false;

	if (GetEntData(iClient, g_iEnemyVisibleOffset) != 0 || GetEntityMoveType(iClient) == MOVETYPE_LADDER)
		return false;

	if (IsCriticalScriptObjectiveTask(GetTask(iClient)))
		return false;

	return CountActiveTeamAngles(GetClientTeam(iClient)) < SCRIPT_ANGLE_TEAM_ACTIVE_CAP;
}

bool IsPostPlantScriptLineupAllowed(int iClient)
{
	if (!g_bBombPlanted || g_bRoundDecided)
		return false;

	TaskType iTask = GetTask(iClient);
	int iTeam = GetClientTeam(iClient);
	if (iTeam == CS_TEAM_CT)
	{
		if (iTask == DEFUSE_BOMB || iTask == FIND_TICKING_BOMB || iTask == GUARD_BOMB_DEFUSER)
			return false;

		if (GetEntProp(iClient, Prop_Send, "m_bIsDefusing") != 0)
			return false;
	}
	return true;
}

void FailScriptLineup(int iClient, ArrayList aLineups, int iLineup, const char[] szReason, float fNow, BMError iError = BM_NoError)
{
	if (aLineups != null && iLineup >= 0 && iLineup < aLineups.Length)
	{
		ScriptLineup sLineup;
		aLineups.GetArray(iLineup, sLineup);
		sLineup.fFailureUntil = fNow + SCRIPT_LINEUP_FAILURE_COOLDOWN;
		aLineups.SetArray(iLineup, sLineup);

		if (iError == BM_NoError)
			PrintToServer("Warning: script lineup client=%N replay=%s failed: %s; retry after %.1f sec.", iClient, sLineup.szReplay, szReason, SCRIPT_LINEUP_FAILURE_COOLDOWN);
		else
			PrintToServer("Warning: script lineup client=%N replay=%s failed: %s (BotMimic error %d); retry after %.1f sec.", iClient, sLineup.szReplay, szReason, view_as<int>(iError), SCRIPT_LINEUP_FAILURE_COOLDOWN);
	}
	else
	{
		PrintToServer("Warning: script lineup client=%N index=%d failed: %s; retry after %.1f sec.", iClient, iLineup, szReason, SCRIPT_LINEUP_FAILURE_COOLDOWN);
	}

	CancelClientScriptAction(iClient);
}
bool ShouldCancelScriptLineupAction(int iClient, ScriptAction iAction)
{
	if (g_bRoundDecided)
		return true;

	if (GetEntData(iClient, g_iEnemyVisibleOffset) != 0)
		return true;

	if (GetEntityMoveType(iClient) == MOVETYPE_LADDER)
		return true;

	TaskType iTask = GetTask(iClient);
	if (iTask == ESCAPE_FROM_BOMB || iTask == ESCAPE_FROM_FLAMES)
		return true;

	if (iAction == ScriptAction_PostPlantNade && !IsPostPlantScriptLineupAllowed(iClient))
		return true;

	if (iAction == ScriptAction_Peek && (g_bBombPlanted || g_iAliveCountT == 0 || g_iAliveCountCT == 0 || IsCriticalScriptObjectiveTask(iTask)))
		return true;

	if (iAction == ScriptAction_Angle
		&& (g_bBombPlanted || g_iAliveCountT < 3 || g_iAliveCountCT < 3 || GetScriptLiveTime(GetGameTime()) > SCRIPT_ANGLE_LIVE_CANCEL || IsCriticalScriptObjectiveTask(iTask) || !IsClientCurrentPrimarySniperScout(iClient)))
		return true;

	if (iAction == ScriptAction_Nade && (g_bBombPlanted || !IsRegulationPistolRound()))
		return true;

	return false;
}

bool ThrottleScriptMove(int iClient, const float fTarget[3], float fNow)
{
	if (GetVectorDistance(g_fBotOrigin[iClient], fTarget) < 25.0)
		return false;

	if (fNow < g_fScriptNextMoveAt[iClient])
		return false;

	g_fScriptNextMoveAt[iClient] = fNow + SCRIPT_MOVE_INTERVAL;
	return true;
}

static bool CheckMovementStale(int iClient, float fLastPos[3], float &fLastMoveTime, float fTimeout, float fNow)
{
	float fMoveDelta = GetVectorDistance(g_fBotOrigin[iClient], fLastPos);
	if (fMoveDelta > 8.0)
	{
		Array_Copy(g_fBotOrigin[iClient], fLastPos, 3);
		fLastMoveTime = fNow;
		return false;
	}

	return (fNow - fLastMoveTime) > fTimeout;
}

bool IsScriptLineupMovementStale(int iClient, float fNow)
{
	return CheckMovementStale(iClient, g_fScriptActionLastPos[iClient], g_fScriptActionLastMoveTime[iClient], 2.0, fNow);
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

    SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_KNIFE), "quick_switch");
    RequestFrame(FinishQuickSwitch, iUserId);
}

public void FinishQuickSwitch(int iUserId)
{
	int iClient = GetClientOfUserId(iUserId);

	if (!IsValidClient(iClient))
		return;

	SwitchWeapon(iClient, GetPlayerWeaponSlot(iClient, CS_SLOT_PRIMARY), "quick_switch_finish");
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

public Action Timer_DontForceThrow(Handle hTimer, DataPack hData)
{
	hData.Reset();
	int iUserId = hData.ReadCell();
	int iThrowId = hData.ReadCell();
	int iClient = GetClientOfUserId(iUserId);

	if (IsValidClient(iClient))
	{
		if (g_sNadeThrows[iClient].userId != iUserId || g_sNadeThrows[iClient].throwId != iThrowId)
		{
			if (g_bNadeDetail)
				LogNadeProbe("[NadeProbe] stale_callback stage=wait_end userid=%d callback_throw=%d current_throw=%d", iUserId, iThrowId, g_sNadeThrows[iClient].throwId);
			return Plugin_Stop;
		}
		if (!g_bNadeThrowPending[iClient] && !g_bThrowGrenade[iClient])
			return Plugin_Stop;
		if (g_sNadeThrows[iClient].active)
		{
			LogNadeDispatchState(iClient, "wait_end");
			int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
			LogNadeProbe("[NadeProbe] wait_end userid=%d throw_id=%d active_weapon=%d submitted_weapon=%d dispatches=%d pending=%d throwing=%d save=%d", iUserId, g_sNadeThrows[iClient].throwId, iWeapon > MaxClients && IsValidEntity(iWeapon) ? EntIndexToEntRef(iWeapon) : INVALID_ENT_REFERENCE, g_sNadeThrows[iClient].weaponRef, g_sNadeThrows[iClient].dispatches, g_bNadeThrowPending[iClient], g_bThrowGrenade[iClient], g_bSaveActiveCache[iClient]);
		}
		if (g_sNadeThrows[iClient].active && g_sNadeThrows[iClient].dispatches == 0)
			EndNadeObservation(iClient, g_sNadeThrows[iClient].lookDeferred ? "look_inhibited" : "dispatch_not_ready");
		g_bNadeThrowPending[iClient] = false;
		g_bThrowGrenade[iClient] = false;
		BotEquipBestWeapon(iClient, true);
	}

	return Plugin_Stop;
}

public void DelayThrow(DataPack hData)
{
	hData.Reset();
	int iUserId = hData.ReadCell();
	int iThrowId = hData.ReadCell();
	delete hData;
    int iClient = GetClientOfUserId(iUserId);

    if (IsValidClient(iClient))
    {
		if (g_sNadeThrows[iClient].userId != iUserId || g_sNadeThrows[iClient].throwId != iThrowId)
		{
			if (g_bNadeDetail)
				LogNadeProbe("[NadeProbe] stale_callback stage=delay userid=%d callback_throw=%d current_throw=%d", iUserId, iThrowId, g_sNadeThrows[iClient].throwId);
			return;
		}
		if (g_sNadeProbes[iClient].userId != 0 && !IsNadeProbeThrowAllowed(iClient))
		{
			EndNadeProbe(iClient, "delay_environment");
			return;
		}
        if (!g_bNadeThrowPending[iClient])
            return;

        g_bThrowGrenade[iClient] = true;
		if (g_sNadeThrows[iClient].active)
			LogNadeProbe("[NadeProbe] delay userid=%d throw_id=%d pending=%d throwing=%d", iUserId, g_sNadeThrows[iClient].throwId, g_bNadeThrowPending[iClient], g_bThrowGrenade[iClient]);
		DataPack hTimerData;
		CreateDataTimer(3.0, Timer_DontForceThrow, hTimerData);
		hTimerData.WriteCell(iUserId);
		hTimerData.WriteCell(iThrowId);
    }
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

public bool TraceNadeProbePosition(int iEntity, int iMask, any iClient)
{
	return iEntity != iClient;
}

public bool TraceEntityFilterStuff(int iEntity, int iMask)
{
    return iEntity > MaxClients;
}

stock bool TraceGroundHeight(const float fPos[3], float &fHeight)
{
	float fFrom[3];
	fFrom[0] = fPos[0];
	fFrom[1] = fPos[1];
	fFrom[2] = fPos[2] + HalfHumanHeight + 0.001;

	float fTo[3];
	fTo[0] = fPos[0];
	fTo[1] = fPos[1];
	fTo[2] = fPos[2] - 10000.0;

	Handle hTrace = TR_TraceRayFilterEx(fFrom, fTo, MASK_NPCSOLID_BRUSHONLY, RayType_EndPoint, TraceEntityFilterStuff);
	bool bDidHit = TR_DidHit(hTrace);

	if (bDidHit)
	{
		float fEndPos[3];
		TR_GetEndPosition(fEndPos, hTrace);
		fHeight = fEndPos[2];
	}

	delete hTrace;
	return bDidHit;
}

bool RejectNadeSolveState(int iClient, const char[] szReason)
{
	if (iClient >= 1 && iClient <= MaxClients)
		strcopy(g_szNadeInvalidReason[iClient], sizeof(g_szNadeInvalidReason[]), szReason);
	return false;
}

bool IsNadeSolveCommonStateAllowed(int iClient)
{
	if (!IsValidClient(iClient))
		return RejectNadeSolveState(iClient, "invalid_client");
	if (!IsFakeClient(iClient))
		return RejectNadeSolveState(iClient, "not_bot");
	if (!IsPlayerAlive(iClient))
		return RejectNadeSolveState(iClient, "dead");

	int iTeam = GetClientTeam(iClient);
	if (iTeam != CS_TEAM_T && iTeam != CS_TEAM_CT)
		return RejectNadeSolveState(iClient, "invalid_team");

	if (g_bRoundDecided)
		return RejectNadeSolveState(iClient, "round_decided");
	if (IsWarmupPeriod())
		return RejectNadeSolveState(iClient, "warmup");
	if (IsGet5SaveBlockedPhase())
		return RejectNadeSolveState(iClient, "get5_blocked");
	if (BotMimic_IsPlayerMimicing(iClient))
		return RejectNadeSolveState(iClient, "botmimic");
	if (GetEntDataFloat(iClient, g_iBotLookAtInhibitUntilOffset) > GetGameTime())
		return RejectNadeSolveState(iClient, "look_inhibited");

	if (g_bThrowGrenade[iClient])
		return RejectNadeSolveState(iClient, "throwing");
	if (g_bNadeThrowPending[iClient])
		return RejectNadeSolveState(iClient, "pending");
	if (g_iScriptAction[iClient] != ScriptAction_None)
		return RejectNadeSolveState(iClient, "script_action");
	if (g_iDoingSmokeNum[iClient] != -1)
		return RejectNadeSolveState(iClient, "recorded_lineup");
	if (g_iClientStrategyRole[iClient] != -1)
		return RejectNadeSolveState(iClient, "strategy_role");

	if (GetTask(iClient) == ESCAPE_FROM_BOMB)
		return RejectNadeSolveState(iClient, "escape_bomb");
	if (GetTask(iClient) == ESCAPE_FROM_FLAMES)
		return RejectNadeSolveState(iClient, "escape_flames");
	if (GetEntityMoveType(iClient) == MOVETYPE_LADDER)
		return RejectNadeSolveState(iClient, "ladder");

	if (GetEntData(iClient, g_iEnemyVisibleOffset) != 0)
		return RejectNadeSolveState(iClient, "enemy_visible");
	if (GetEntData(iClient, g_iBotNearbyEnemiesOffset) != 0)
		return RejectNadeSolveState(iClient, "nearby_enemy");

	return true;
}

bool IsNadeSolveRequestAllowed(int iClient)
{
	if (!IsNadeSolveCommonStateAllowed(iClient))
		return false;

	if (ShouldSaveInsteadOfRetake(iClient))
		return RejectNadeSolveState(iClient, "save");

	return true;
}

bool IsNadeSolveJobStateValid(int iClient)
{
	if (!IsNadeSolveActive(iClient))
		return RejectNadeSolveState(iClient, "idle");
	if (!IsNadeSolveCommonStateAllowed(iClient))
		return false;

	if (g_bSaveActiveCache[iClient])
		return RejectNadeSolveState(iClient, "save_cached");
	if (IsForceSaveEnabled())
		return RejectNadeSolveState(iClient, "force_save");

	if (GetGameTime() > g_sNadeSolveJobs[iClient].deadlineTime)
		return RejectNadeSolveState(iClient, "deadline");
	return true;
}

bool IsNadeSolveJobRuntimeValid(int iClient)
{
	if (!IsNadeSolveJobStateValid(iClient))
		return false;

	if (GetClientOfUserId(g_sNadeSolveJobs[iClient].clientUserId) != iClient)
		return RejectNadeSolveState(iClient, "userid_changed");

	int iGrenadeEnt = EntRefToEntIndex(g_sNadeSolveJobs[iClient].grenadeEntRef);
	if (!IsValidEntity(iGrenadeEnt) || !HasEntProp(iGrenadeEnt, Prop_Send, "m_hOwnerEntity"))
		return RejectNadeSolveState(iClient, "weapon_invalid");

	if (GetEntPropEnt(iGrenadeEnt, Prop_Send, "m_hOwnerEntity") != iClient)
		return RejectNadeSolveState(iClient, "owner_changed");

	if (GetEntProp(iGrenadeEnt, Prop_Send, "m_iItemDefinitionIndex") != g_sNadeSolveJobs[iClient].grenadeDefIndex)
		return RejectNadeSolveState(iClient, "type_changed");

	float fOrigin[3];
	GetClientAbsOrigin(iClient, fOrigin);
	if (GetVectorDistance(fOrigin, g_sNadeSolveJobs[iClient].startOrigin) > NADE_SOLVE_ORIGIN_TOLERANCE)
		return RejectNadeSolveState(iClient, "origin_moved");

	return true;
}

bool NadeSolveJobMatchesRequest(int iClient, int iGrenadeEnt, int iNadeDefIndex, const float fTarget[3])
{
	if (!IsNadeSolveActive(iClient))
		return false;

	if (g_sNadeSolveJobs[iClient].grenadeEntRef != EntIndexToEntRef(iGrenadeEnt))
		return false;

	if (g_sNadeSolveJobs[iClient].grenadeDefIndex != iNadeDefIndex)
		return false;

	return GetVectorDistance(g_sNadeSolveJobs[iClient].target, fTarget) <= NADE_SOLVE_TARGET_TOLERANCE;
}

float GetNadeSolveTimeout(int iActiveCount)
{
	int iExtraJobs = iActiveCount > 1 ? iActiveCount - 1 : 0;
	float fTimeout = NADE_SOLVE_TIMEOUT_BASE
		+ float(iExtraJobs) * NADE_SOLVE_TIMEOUT_PER_EXTRA_JOB;
	return fTimeout < NADE_SOLVE_TIMEOUT_MAX
		? fTimeout
		: NADE_SOLVE_TIMEOUT_MAX;
}

bool StartNadeSolveJob(int iClient, int iGrenadeEnt, int iNadeDefIndex, const float fOrigin[3], const float fEyePosition[3], const float fTarget[3], float fNow)
{
	if (IsNadeSolveActive(iClient) || g_iNadeSolveActiveCount >= NADE_SOLVE_MAX_ACTIVE_JOBS)
		return false;
	int iFreeSlot = -1;
	for (int iSlot = 0; iSlot < NADE_SOLVE_MAX_ACTIVE_JOBS; iSlot++)
	{
		if (g_iNadeSolveClients[iSlot] == 0)
		{
			iFreeSlot = iSlot;
			break;
		}
	}
	if (iFreeSlot == -1)
		return false;
	ClearNadeSolveJob(iClient, NadeEnd_Cancelled, "replaced_at_start");
	g_iNadeSolveClients[iFreeSlot] = iClient;

	g_sNadeSolveJobs[iClient].phase = NadeSolve_Coarse;
	g_sNadeSolveJobs[iClient].jobId = ++g_iNadeJobSequence;
	g_sNadeSolveJobs[iClient].startEpoch = g_iNadeEpoch;
	g_sNadeSolveJobs[iClient].parentJobId = g_iNadeParentContext[iClient];
	strcopy(g_sNadeSolveJobs[iClient].caseId, sizeof(g_sNadeSolveJobs[].caseId), g_sNadeProbes[iClient].userId != 0 ? g_sNadeProbes[iClient].caseId : "-");
	g_iNadeJobsStarted++;
	g_iNadeSolveActiveCount++;
	if (g_iNadeSolveActiveCount > g_sNadeSolvePerf.maxQueuedJobs)
		g_sNadeSolvePerf.maxQueuedJobs = g_iNadeSolveActiveCount;
	g_sNadeSolveJobs[iClient].clientUserId = GetClientUserId(iClient);
	g_sNadeSolveJobs[iClient].grenadeEntRef = EntIndexToEntRef(iGrenadeEnt);
	g_sNadeSolveJobs[iClient].grenadeDefIndex = iNadeDefIndex;
	g_sNadeSolveJobs[iClient].requestTime = fNow;
	g_sNadeSolveJobs[iClient].currentPitch = -75.0;
	g_sNadeSolveJobs[iClient].bestPitch = 0.0;
	g_sNadeSolveJobs[iClient].bestDistance = 999999.0;
	g_sNadeSolveJobs[iClient].candidateActive = false;
	float fTimeout = GetNadeSolveTimeout(g_iNadeSolveActiveCount);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsNadeSolveActive(i))
			continue;

		g_sNadeSolveJobs[i].deadlineTime =
			g_sNadeSolveJobs[i].requestTime + fTimeout;
	}

	Array_Copy(fOrigin, g_sNadeSolveJobs[iClient].startOrigin, 3);
	Array_Copy(fEyePosition, g_sNadeSolveJobs[iClient].eyePosition, 3);
	Array_Copy(fTarget, g_sNadeSolveJobs[iClient].target, 3);

	float fDelta[3];
	SubtractVectors(fTarget, fEyePosition, fDelta);
	g_sNadeSolveJobs[iClient].yaw = ArcTangent2(fDelta[1], fDelta[0]) * 180.0 / FLOAT_PI;
	LogNadeJob(iClient, "job_begin");
	return true;
}

bool IsNadeSolveJobValid(int iClient)
{
	if (!IsNadeSolveJobRuntimeValid(iClient))
		return false;
	if (ShouldSaveInsteadOfRetake(iClient))
		return RejectNadeSolveState(iClient, "save");

	return true;
}

bool InitializeNadeCandidate(int iClient, int &iTraceBudget)
{
	if (iTraceBudget <= 0)
		return false;

	float fAngles[3], fDir[3];
	fAngles[0] = -10.0 + g_sNadeSolveJobs[iClient].currentPitch + FloatAbs(g_sNadeSolveJobs[iClient].currentPitch) * 10.0 / 90.0;
	fAngles[1] = g_sNadeSolveJobs[iClient].yaw;
	fAngles[2] = 0.0;

	GetAngleVectors(fAngles, fDir, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fDir, fDir);

	float fVelocity[3];
	fVelocity[0] = fDir[0] * 750.0 * 0.9;
	fVelocity[1] = fDir[1] * 750.0 * 0.9;
	fVelocity[2] = fDir[2] * 750.0 * 0.9;

	float fSpawn[3];
	fSpawn[0] = g_sNadeSolveJobs[iClient].eyePosition[0] + fDir[0] * 22.0;
	fSpawn[1] = g_sNadeSolveJobs[iClient].eyePosition[1] + fDir[1] * 22.0;
	fSpawn[2] = g_sNadeSolveJobs[iClient].eyePosition[2] + fDir[2] * 22.0;

	float fMins[3] = {-2.0, -2.0, -2.0};
	float fMaxs[3] = {2.0, 2.0, 2.0};
	float fPosition[3];
	TR_TraceHullFilter(g_sNadeSolveJobs[iClient].eyePosition, fSpawn, fMins, fMaxs, MASK_SOLID, TraceEntityFilterStuff);
	iTraceBudget--;
	g_sNadeSolveJobs[iClient].traces++;
	float fFraction = TR_GetFraction();
	TR_GetEndPosition(fPosition);

	if (fFraction * 22.0 > 6.0)
	{
		fPosition[0] -= fDir[0] * 6.0;
		fPosition[1] -= fDir[1] * 6.0;
		fPosition[2] -= fDir[2] * 6.0;
	}

	g_sNadeSolveJobs[iClient].candidatePosition[0] = fPosition[0];
	g_sNadeSolveJobs[iClient].candidatePosition[1] = fPosition[1];
	g_sNadeSolveJobs[iClient].candidatePosition[2] = fPosition[2];
	g_sNadeSolveJobs[iClient].candidateVelocity[0] = fVelocity[0];
	g_sNadeSolveJobs[iClient].candidateVelocity[1] = fVelocity[1];
	g_sNadeSolveJobs[iClient].candidateVelocity[2] = fVelocity[2];
	g_sNadeSolveJobs[iClient].candidateTime = 0.0;
	g_sNadeSolveJobs[iClient].candidateNextThink = (g_sNadeSolveJobs[iClient].grenadeDefIndex == DEFIDX_MOLOTOV || g_sNadeSolveJobs[iClient].grenadeDefIndex == DEFIDX_INCENDIARY) ? 0.1 : 0.2;
	g_sNadeSolveJobs[iClient].candidateBounces = 0;
	g_sNadeSolveJobs[iClient].candidatePendingPush = false;
	g_sNadeSolveJobs[iClient].candidateRemainingTime = 0.0;
	g_sNadeSolveJobs[iClient].candidateActive = true;
	return true;
}

NadeCandidateState AdvanceNadeCandidate(int iClient, int &iTraceBudget)
{
	if (!g_sNadeSolveJobs[iClient].candidateActive)
	{
		if (!InitializeNadeCandidate(iClient, iTraceBudget))
			return NadeCandidate_Running;

		return NadeCandidate_Running;
	}

	if (iTraceBudget <= 0)
		return NadeCandidate_Running;

	float fDt = GetTickInterval();
	if (fDt <= 0.0)
		return NadeCandidate_Failed;

	if (g_sNadeSolveJobs[iClient].candidateTime >= NADE_SIMULATION_MAX_TIME)
	{
		g_sNadeSolveJobs[iClient].candidateActive = false;
		return NadeCandidate_Finished;
	}

	float fMins[3] = {-2.0, -2.0, -2.0};
	float fMaxs[3] = {2.0, 2.0, 2.0};
	float fTime = g_sNadeSolveJobs[iClient].candidateTime;

	if (g_sNadeSolveJobs[iClient].candidatePendingPush)
	{
		float fPush[3];
		fPush[0] = g_sNadeSolveJobs[iClient].candidatePosition[0] + g_sNadeSolveJobs[iClient].candidateVelocity[0] * g_sNadeSolveJobs[iClient].candidateRemainingTime;
		fPush[1] = g_sNadeSolveJobs[iClient].candidatePosition[1] + g_sNadeSolveJobs[iClient].candidateVelocity[1] * g_sNadeSolveJobs[iClient].candidateRemainingTime;
		fPush[2] = g_sNadeSolveJobs[iClient].candidatePosition[2] + g_sNadeSolveJobs[iClient].candidateVelocity[2] * g_sNadeSolveJobs[iClient].candidateRemainingTime;

		float fPosition[3];
		TR_TraceHullFilter(g_sNadeSolveJobs[iClient].candidatePosition, fPush, fMins, fMaxs, MASK_SHOT_HULL, TraceEntityFilterStuff);
		iTraceBudget--;
		g_sNadeSolveJobs[iClient].traces++;
		TR_GetEndPosition(fPosition);
		Array_Copy(fPosition, g_sNadeSolveJobs[iClient].candidatePosition, 3);
		g_sNadeSolveJobs[iClient].candidatePendingPush = false;
		g_sNadeSolveJobs[iClient].candidateRemainingTime = 0.0;
		if (g_sNadeSolveJobs[iClient].candidateBounces > 20)
		{
			g_sNadeSolveJobs[iClient].candidateActive = false;
			return NadeCandidate_Finished;
		}
	}
	else
	{
		float fNewVelocityZ = g_sNadeSolveJobs[iClient].candidateVelocity[2] - g_cvGravity.FloatValue * 0.4 * fDt;
		float fAverageVelocityZ = (g_sNadeSolveJobs[iClient].candidateVelocity[2] + fNewVelocityZ) * 0.5;
		float fNext[3];
		fNext[0] = g_sNadeSolveJobs[iClient].candidatePosition[0] + g_sNadeSolveJobs[iClient].candidateVelocity[0] * fDt;
		fNext[1] = g_sNadeSolveJobs[iClient].candidatePosition[1] + g_sNadeSolveJobs[iClient].candidateVelocity[1] * fDt;
		fNext[2] = g_sNadeSolveJobs[iClient].candidatePosition[2] + fAverageVelocityZ * fDt;
		g_sNadeSolveJobs[iClient].candidateVelocity[2] = fNewVelocityZ;

		TR_TraceHullFilter(g_sNadeSolveJobs[iClient].candidatePosition, fNext, fMins, fMaxs, MASK_SHOT_HULL, TraceEntityFilterStuff);
		iTraceBudget--;
		g_sNadeSolveJobs[iClient].traces++;
		float fFraction = TR_GetFraction();

		if (fFraction != 1.0)
		{
			TR_GetEndPosition(fNext);

			float fNormal[3];
			TR_GetPlaneNormal(INVALID_HANDLE, fNormal);
			int iHitEnt = TR_GetEntityIndex();

			if ((g_sNadeSolveJobs[iClient].grenadeDefIndex == DEFIDX_MOLOTOV || g_sNadeSolveJobs[iClient].grenadeDefIndex == DEFIDX_INCENDIARY) && fNormal[2] >= Cosine(DegToRad(g_cvMolotovMaxSlope.FloatValue)))
			{
				if (iHitEnt == 0 || !IsValidClient(iHitEnt))
				{
					Array_Copy(fNext, g_sNadeSolveJobs[iClient].candidatePosition, 3);
					g_sNadeSolveJobs[iClient].candidateActive = false;
					return NadeCandidate_Finished;
				}
			}

			float fDot = GetVectorDotProduct(g_sNadeSolveJobs[iClient].candidateVelocity, fNormal);
			g_sNadeSolveJobs[iClient].candidateVelocity[0] -= 2.0 * fDot * fNormal[0];
			g_sNadeSolveJobs[iClient].candidateVelocity[1] -= 2.0 * fDot * fNormal[1];
			g_sNadeSolveJobs[iClient].candidateVelocity[2] -= 2.0 * fDot * fNormal[2];

			for (int i = 0; i < 3; i++)
			{
				if (g_sNadeSolveJobs[iClient].candidateVelocity[i] > -0.1 && g_sNadeSolveJobs[iClient].candidateVelocity[i] < 0.1)
					g_sNadeSolveJobs[iClient].candidateVelocity[i] = 0.0;
			}

			float fElasticity = 0.45;
			if (iHitEnt > 0)
			{
				if (IsValidClient(iHitEnt))
					fElasticity *= 0.3;
				else if (HasEntProp(iHitEnt, Prop_Send, "m_flElasticity"))
					fElasticity *= GetEntPropFloat(iHitEnt, Prop_Send, "m_flElasticity");
			}

			if (fElasticity > 0.9)
				fElasticity = 0.9;

			ScaleVector(g_sNadeSolveJobs[iClient].candidateVelocity, fElasticity);

			if (fNormal[2] > 0.7)
			{
				float fSpeedSq = GetVectorDotProduct(g_sNadeSolveJobs[iClient].candidateVelocity, g_sNadeSolveJobs[iClient].candidateVelocity);
				if (fSpeedSq > 96000.0)
				{
					float fVelocityNormal[3];
					NormalizeVector(g_sNadeSolveJobs[iClient].candidateVelocity, fVelocityNormal);
					float fDotClamp = GetVectorDotProduct(fVelocityNormal, fNormal);
					if (fDotClamp > 0.5)
						ScaleVector(g_sNadeSolveJobs[iClient].candidateVelocity, 1.0 - fDotClamp + 0.5);
				}

				if (fSpeedSq < 400.0)
				{
					g_sNadeSolveJobs[iClient].candidateVelocity[0] = 0.0;
					g_sNadeSolveJobs[iClient].candidateVelocity[1] = 0.0;
					g_sNadeSolveJobs[iClient].candidateVelocity[2] = 0.0;
					Array_Copy(fNext, g_sNadeSolveJobs[iClient].candidatePosition, 3);
					g_sNadeSolveJobs[iClient].candidateActive = false;
					return NadeCandidate_Finished;
				}
			}

			float fRemaining = (1.0 - fFraction) * fDt;
			Array_Copy(fNext, g_sNadeSolveJobs[iClient].candidatePosition, 3);
			g_sNadeSolveJobs[iClient].candidateBounces++;

			if (fRemaining > 0.0)
			{
				g_sNadeSolveJobs[iClient].candidatePendingPush = true;
				g_sNadeSolveJobs[iClient].candidateRemainingTime = fRemaining;
				return NadeCandidate_Running;
			}

			if (g_sNadeSolveJobs[iClient].candidateBounces > 20)
			{
				g_sNadeSolveJobs[iClient].candidateActive = false;
				return NadeCandidate_Finished;
			}
		}
		else
		{
			Array_Copy(fNext, g_sNadeSolveJobs[iClient].candidatePosition, 3);
		}
	}

	if (fTime >= g_sNadeSolveJobs[iClient].candidateNextThink)
	{
		switch (g_sNadeSolveJobs[iClient].grenadeDefIndex)
		{
			case DEFIDX_HE, DEFIDX_FLASH:
			{
				if (fTime >= GetNadeDetonateTime(g_sNadeSolveJobs[iClient].grenadeDefIndex))
				{
					g_sNadeSolveJobs[iClient].candidateActive = false;
					return NadeCandidate_Finished;
				}
			}
			case DEFIDX_SMOKE:
			{
				if (GetVectorDotProduct(g_sNadeSolveJobs[iClient].candidateVelocity, g_sNadeSolveJobs[iClient].candidateVelocity) <= 0.01)
				{
					g_sNadeSolveJobs[iClient].candidateActive = false;
					return NadeCandidate_Finished;
				}
			}
			case DEFIDX_DECOY:
			{
				if (GetVectorDotProduct(g_sNadeSolveJobs[iClient].candidateVelocity, g_sNadeSolveJobs[iClient].candidateVelocity) < 0.04)
				{
					g_sNadeSolveJobs[iClient].candidateActive = false;
					return NadeCandidate_Finished;
				}
			}
			case DEFIDX_MOLOTOV, DEFIDX_INCENDIARY:
			{
				if (fTime >= GetNadeDetonateTime(g_sNadeSolveJobs[iClient].grenadeDefIndex))
				{
					g_sNadeSolveJobs[iClient].candidateActive = false;
					return NadeCandidate_Finished;
				}
			}
		}
		g_sNadeSolveJobs[iClient].candidateNextThink = fTime + ((g_sNadeSolveJobs[iClient].grenadeDefIndex == DEFIDX_MOLOTOV || g_sNadeSolveJobs[iClient].grenadeDefIndex == DEFIDX_INCENDIARY) ? 0.1 : 0.2);
	}

	g_sNadeSolveJobs[iClient].candidateTime = fTime + fDt;
	if (g_sNadeSolveJobs[iClient].candidateTime >= NADE_SIMULATION_MAX_TIME)
	{
		g_sNadeSolveJobs[iClient].candidateActive = false;
		return NadeCandidate_Finished;
	}

	return NadeCandidate_Running;
}

bool SubmitNadeThrow(int iClient, int iGrenadeEnt, const float fLookAt[3], int iNadeDefIndex, int iJobId = 0, const char[] szSource = "cache", const float fTarget[3] = NULL_VECTOR)
{
	if (!IsValidClient(iClient) || !IsPlayerAlive(iClient) || g_bThrowGrenade[iClient] || g_bNadeThrowPending[iClient] || !IsValidEntity(iGrenadeEnt) || !HasEntProp(iGrenadeEnt, Prop_Send, "m_hOwnerEntity") || GetEntPropEnt(iGrenadeEnt, Prop_Send, "m_hOwnerEntity") != iClient || GetEntProp(iGrenadeEnt, Prop_Send, "m_iItemDefinitionIndex") != iNadeDefIndex)
		return false;

	Array_Copy(fLookAt, g_fNadeTarget[iClient], 3);
	g_bNadeThrowPending[iClient] = true;
	BeginNadeObservation(iClient, iGrenadeEnt, iNadeDefIndex, iJobId, szSource, fTarget);
	SwitchWeapon(iClient, iGrenadeEnt, "nade_submit");
	DataPack hData = new DataPack();
	hData.WriteCell(GetClientUserId(iClient));
	hData.WriteCell(g_sNadeThrows[iClient].throwId);
	RequestFrame(DelayThrow, hData);
	return true;
}

void FailNadeSolveJob(int iClient, const char[] szReason)
{
	if (!IsNadeSolveActive(iClient))
		return;

	float fOrigin[3], fTarget[3], fFallbackTarget[3];
	bool bStartFallback = g_sNadeSolveJobs[iClient].hasFallbackTarget && !g_sNadeSolveJobs[iClient].fallbackAttempted;
	int iGrenadeEnt = EntRefToEntIndex(g_sNadeSolveJobs[iClient].grenadeEntRef);
	Array_Copy(g_sNadeSolveJobs[iClient].startOrigin, fOrigin, 3);
	Array_Copy(g_sNadeSolveJobs[iClient].target, fTarget, 3);
	if (bStartFallback)
		Array_Copy(g_sNadeSolveJobs[iClient].fallbackTarget, fFallbackTarget, 3);

	StoreNadeSolveCache(iClient, fOrigin, fTarget, g_sNadeSolveJobs[iClient].grenadeDefIndex, NULL_VECTOR, false, GetGameTime());

	int iParentJobId = g_sNadeSolveJobs[iClient].jobId;
	ClearNadeSolveJob(iClient, NadeEnd_NoSolution, szReason);

	NadeSolveRequestResult eFallbackResult = NadeRequest_Rejected;
	if (bStartFallback)
	{
		g_iNadeParentContext[iClient] = iParentJobId;
		eFallbackResult = ProcessGrenadeThrow(iClient, fFallbackTarget, iGrenadeEnt);
		g_iNadeParentContext[iClient] = 0;
		if (eFallbackResult == NadeRequest_Queued && IsNadeSolveActive(iClient))
		{
			g_sNadeSolveJobs[iClient].hasFallbackTarget = true;
			g_sNadeSolveJobs[iClient].fallbackAttempted = true;
			Array_Copy(fTarget, g_sNadeSolveJobs[iClient].fallbackTarget, 3);
			return;
		}

		if (eFallbackResult == NadeRequest_Submitted)
		{
			g_sNadeSolvePerf.completedJobs++;
			return;
		}
	}

	g_sNadeSolvePerf.failedJobs++;
}

void CommitNadeSolveJob(int iClient, const float fLookAt[3])
{
	if (!IsNadeSolveJobValid(iClient))
	{
		CancelNadeSolveJob(iClient, g_szNadeInvalidReason[iClient]);
		return;
	}

	int iGrenadeEnt = EntRefToEntIndex(g_sNadeSolveJobs[iClient].grenadeEntRef);
	int iNadeDefIndex = g_sNadeSolveJobs[iClient].grenadeDefIndex;
	float fOrigin[3], fTarget[3];
	Array_Copy(g_sNadeSolveJobs[iClient].startOrigin, fOrigin, 3);
	Array_Copy(g_sNadeSolveJobs[iClient].target, fTarget, 3);
	if (!SubmitNadeThrow(iClient, iGrenadeEnt, fLookAt, iNadeDefIndex, g_sNadeSolveJobs[iClient].jobId, "solver", fTarget))
	{
		CancelNadeSolveJob(iClient, "submit_rejected");
		return;
	}

	StoreNadeSolveCache(iClient, fOrigin, fTarget, iNadeDefIndex, fLookAt, true, GetGameTime());
	g_sNadeSolvePerf.completedJobs++;
	ClearNadeSolveJob(iClient, NadeEnd_Submitted, "accepted");
}

void FinishNadeCandidate(int iClient)
{
	g_sNadeSolveJobs[iClient].candidates++;
	bool bResumingSearch;
	if (g_sNadeSolveJobs[iClient].phase == NadeSolve_Final)
	{
		if (!IsNadeSolveJobValid(iClient))
		{
			CancelNadeSolveJob(iClient, g_szNadeInvalidReason[iClient]);
			return;
		}

		float fFinalLandPos[3], fTargetRaised[3];
		Array_Copy(g_sNadeSolveJobs[iClient].candidatePosition, fFinalLandPos, 3);
		fFinalLandPos[2] += 10.0;
		Array_Copy(g_sNadeSolveJobs[iClient].target, fTargetRaised, 3);
		fTargetRaised[2] += 10.0;
		bool bDistanceValid = GetVectorDistance(g_sNadeSolveJobs[iClient].candidatePosition, g_sNadeSolveJobs[iClient].target) <= 200.0;
		if (bDistanceValid && IsPointVisible(fFinalLandPos, fTargetRaised))
		{
			float fAngles[3], fDirection[3], fLookAt[3];
			fAngles[0] = g_sNadeSolveJobs[iClient].currentPitch;
			fAngles[1] = g_sNadeSolveJobs[iClient].yaw;
			fAngles[2] = 0.0;
			GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
			fLookAt[0] = g_sNadeSolveJobs[iClient].eyePosition[0] + fDirection[0] * 1000.0;
			fLookAt[1] = g_sNadeSolveJobs[iClient].eyePosition[1] + fDirection[1] * 1000.0;
			fLookAt[2] = g_sNadeSolveJobs[iClient].eyePosition[2] + fDirection[2] * 1000.0;
			CommitNadeSolveJob(iClient, fLookAt);
			return;
		}

		if (g_sNadeSolveJobs[iClient].resumePhase == NadeSolve_Idle)
		{
			FailNadeSolveJob(iClient, bDistanceValid ? "final_visibility" : "final_distance");
			return;
		}
		g_sNadeSolveJobs[iClient].phase = g_sNadeSolveJobs[iClient].resumePhase;
		g_sNadeSolveJobs[iClient].currentPitch = g_sNadeSolveJobs[iClient].resumePitch;
		g_sNadeSolveJobs[iClient].resumePhase = NadeSolve_Idle;
		bResumingSearch = true;
		if (g_bNadeDetail)
			LogMessage("[NadeSearch] resume job_id=%d phase=%d pitch=%.2f reason=%s", g_sNadeSolveJobs[iClient].jobId, g_sNadeSolveJobs[iClient].phase, g_sNadeSolveJobs[iClient].currentPitch, bDistanceValid ? "final_visibility" : "final_distance");
	}

	if (!bResumingSearch)
	{
		float fDistance = GetVectorDistance(g_sNadeSolveJobs[iClient].candidatePosition, g_sNadeSolveJobs[iClient].target);
		if (fDistance < g_sNadeSolveJobs[iClient].bestDistance)
		{
			g_sNadeSolveJobs[iClient].bestDistance = fDistance;
			g_sNadeSolveJobs[iClient].bestPitch = g_sNadeSolveJobs[iClient].currentPitch;
		}
		if (fDistance <= 200.0)
		{
			g_sNadeSolveJobs[iClient].resumePhase = g_sNadeSolveJobs[iClient].phase;
			g_sNadeSolveJobs[iClient].resumePitch = g_sNadeSolveJobs[iClient].currentPitch;
			g_sNadeSolveJobs[iClient].phase = NadeSolve_Final;
			if (g_bNadeDetail)
				LogMessage("[NadeSearch] early_final job_id=%d phase=%d pitch=%.2f distance=%.3f", g_sNadeSolveJobs[iClient].jobId, g_sNadeSolveJobs[iClient].resumePhase, g_sNadeSolveJobs[iClient].currentPitch, fDistance);
			return;
		}
	}

	if (g_sNadeSolveJobs[iClient].phase == NadeSolve_Coarse)
	{
		if (g_sNadeSolveJobs[iClient].currentPitch < 75.0)
		{
			g_sNadeSolveJobs[iClient].currentPitch += 3.0;
			return;
		}

		if (g_sNadeSolveJobs[iClient].bestDistance > 500.0)
		{
			FailNadeSolveJob(iClient, "coarse_distance");
			return;
		}

		g_sNadeSolveJobs[iClient].phase = NadeSolve_Fine;
		g_sNadeSolveJobs[iClient].currentPitch = g_sNadeSolveJobs[iClient].bestPitch - 3.0;
		g_sNadeSolveJobs[iClient].fineEndPitch = g_sNadeSolveJobs[iClient].bestPitch + 3.0;
		return;
	}

	if (g_sNadeSolveJobs[iClient].currentPitch < g_sNadeSolveJobs[iClient].fineEndPitch - 0.001)
	{
		g_sNadeSolveJobs[iClient].currentPitch += 0.5;
		return;
	}

	if (g_sNadeSolveJobs[iClient].bestDistance > 200.0)
	{
		FailNadeSolveJob(iClient, "fine_distance");
		return;
	}

	g_sNadeSolveJobs[iClient].phase = NadeSolve_Final;
	g_sNadeSolveJobs[iClient].currentPitch = g_sNadeSolveJobs[iClient].bestPitch;
}

void AdvanceNadeSolveJob(int iClient, int &iTraceBudget)
{
	if (!IsNadeSolveActive(iClient) || iTraceBudget <= 0)
		return;

	NadeCandidateState eState = AdvanceNadeCandidate(iClient, iTraceBudget);
	if (eState == NadeCandidate_Failed)
	{
		FailNadeSolveJob(iClient, "candidate_failed");
		return;
	}

	if (eState == NadeCandidate_Finished)
		FinishNadeCandidate(iClient);
}

stock NadeSolveRequestResult ProcessGrenadeThrow(int iClient, float fTarget[3], int iGrenadeEnt = -1, bool bProbeRequest = false)
{
	float fNow = GetGameTime();
	if (IsNadeSolveActive(iClient) && !IsNadeSolveJobValid(iClient))
		CancelNadeSolveJob(iClient, g_szNadeInvalidReason[iClient]);

	if (!IsNadeSolveRequestAllowed(iClient))
	{
		g_iNadeRequests[0]++;
		return NadeRequest_Rejected;
	}

	if (g_sNadeProbes[iClient].userId != 0 && !bProbeRequest)
	{
		if (g_bNadeDetail)
			LogNadeProbe("[NadeProbe] ignored_natural_request userid=%d case_id=%s", GetClientUserId(iClient), g_sNadeProbes[iClient].caseId);
		g_iNadeRequests[0]++;
		return NadeRequest_Rejected;
	}

	int iGrenadeSlot = iGrenadeEnt != -1 ? iGrenadeEnt : GetPlayerWeaponSlot(iClient, CS_SLOT_GRENADE);
	if (!IsValidEntity(iGrenadeSlot) || !HasEntProp(iGrenadeSlot, Prop_Send, "m_hOwnerEntity") || GetEntPropEnt(iGrenadeSlot, Prop_Send, "m_hOwnerEntity") != iClient)
	{
		g_iNadeRequests[0]++;
		return NadeRequest_Rejected;
	}

	int iNadeDefIndex = GetEntProp(iGrenadeSlot, Prop_Send, "m_iItemDefinitionIndex");

	float fGroundTarget[3];
	fGroundTarget[0] = fTarget[0];
	fGroundTarget[1] = fTarget[1];
	fGroundTarget[2] = fTarget[2];

	float fHeight;
	if (TraceGroundHeight(fTarget, fHeight))
		fGroundTarget[2] = fHeight;

	float fOrigin[3], fEyePosition[3], fDelta[3];
	GetClientAbsOrigin(iClient, fOrigin);
	GetClientEyePosition(iClient, fEyePosition);
	SubtractVectors(fGroundTarget, fEyePosition, fDelta);
	if (GetVectorLength(fDelta) < 250.0)
	{
		StoreNadeSolveCache(iClient, fOrigin, fGroundTarget, iNadeDefIndex, NULL_VECTOR, false, fNow);
		g_iNadeRequests[0]++;
		return NadeRequest_Rejected;
	}

	if (IsNadeSolveActive(iClient))
	{
		if (NadeSolveJobMatchesRequest(iClient, iGrenadeSlot, iNadeDefIndex, fGroundTarget) || (g_sNadeSolveJobs[iClient].hasFallbackTarget && g_sNadeSolveJobs[iClient].grenadeEntRef == EntIndexToEntRef(iGrenadeSlot) && g_sNadeSolveJobs[iClient].grenadeDefIndex == iNadeDefIndex && GetVectorDistance(g_sNadeSolveJobs[iClient].fallbackTarget, fGroundTarget) <= NADE_SOLVE_TARGET_TOLERANCE))
		{
			g_iNadeRequests[1]++;
			return NadeRequest_Queued;
		}

		CancelNadeSolveJob(iClient, g_sNadeSolveJobs[iClient].grenadeEntRef != EntIndexToEntRef(iGrenadeSlot) ? "weapon_replaced" : "target_replaced");
	}

	float fLookAt[3];
	bool bCachedSuccess;
	if (TryUseCachedNadeSolve(iClient, fOrigin, fGroundTarget, iNadeDefIndex, fLookAt, fNow, bCachedSuccess))
	{
		if (!bCachedSuccess)
		{
			g_iNadeRequests[3]++;
			return NadeRequest_Rejected;
		}

		if (SubmitNadeThrow(iClient, iGrenadeSlot, fLookAt, iNadeDefIndex, 0, "cache", fGroundTarget))
		{
			g_iNadeRequests[4]++;
			return NadeRequest_Submitted;
		}

		g_iNadeRequests[0]++;
		return NadeRequest_Rejected;
	}

	if (fNow < g_fNadeSolveRetryAt[iClient] || !StartNadeSolveJob(iClient, iGrenadeSlot, iNadeDefIndex, fOrigin, fEyePosition, fGroundTarget, fNow))
	{
		if (g_iNadeSolveActiveCount >= NADE_SOLVE_MAX_ACTIVE_JOBS)
			g_fNadeSolveRetryAt[iClient] = fNow + NADE_SOLVE_RETRY_INTERVAL;
		g_iNadeRequestsBusy++;
		return NadeRequest_Busy;
	}
	g_iNadeRequests[2]++;
	return NadeRequest_Queued;
}

stock NadeSolveRequestResult ProcessGrenadeThrowWithFallback(int iClient, float fPrimaryTarget[3], float fFallbackTarget[3], int iGrenadeEnt = -1)
{
	NadeSolveRequestResult eResult = ProcessGrenadeThrow(iClient, fPrimaryTarget, iGrenadeEnt);
	if (eResult == NadeRequest_Queued)
	{
		if (IsNadeSolveActive(iClient) && !g_sNadeSolveJobs[iClient].hasFallbackTarget)
		{
			g_sNadeSolveJobs[iClient].hasFallbackTarget = true;
			Array_Copy(fFallbackTarget, g_sNadeSolveJobs[iClient].fallbackTarget, 3);
		}

		return eResult;
	}

	if (eResult == NadeRequest_Rejected)
		return ProcessGrenadeThrow(iClient, fFallbackTarget, iGrenadeEnt);

	return eResult;
}

float GetNadeDetonateTime(int iNadeDefIndex)
{
	switch (iNadeDefIndex)
	{
		case DEFIDX_HE, DEFIDX_FLASH:
			return 1.5;
		case DEFIDX_MOLOTOV, DEFIDX_INCENDIARY:
			return g_cvMolotovDetonateTime.FloatValue;
	}
	return 0.0;
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

stock bool IsRegulationPistolRound()
{
	int iMaxRounds = g_cvMaxRounds.IntValue;
	return (g_iCurrentRound == 0 || (iMaxRounds > 0 && g_iCurrentRound == iMaxRounds / 2));
}

bool StrategyRoleHasUtility(StrategyRole sRole)
{
	return sRole.iUtility1DefIndex > 0 || sRole.iUtility2DefIndex > 0;
}

bool ClientMeetsStrategyUtility(int iClient, StrategyRole sRole)
{
	if (sRole.iUtility1DefIndex > 0 && CountPlayerWeaponsByDefIndex(iClient, sRole.iUtility1DefIndex) < sRole.iUtility1Amount)
		return false;

	if (sRole.iUtility2DefIndex > 0 && CountPlayerWeaponsByDefIndex(iClient, sRole.iUtility2DefIndex) < sRole.iUtility2Amount)
		return false;

	return true;
}

int CountPlayerWeaponsByDefIndex(int iClient, int iDefIndex)
{
	static int iWeaponsOffset = -2;
	if (iWeaponsOffset == -2)
		iWeaponsOffset = FindDataMapInfo(iClient, "m_hMyWeapons");

	int iCount = 0;

	if (iWeaponsOffset == -1)
		return IsValidEntity(eItems_FindWeaponByDefIndex(iClient, iDefIndex)) ? 1 : 0;

	for (int i = 0; i < 64; i++)
	{
		int iWeapon = GetEntDataEnt2(iClient, iWeaponsOffset + (i * 4));
		if (!IsValidEntity(iWeapon) || GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex") != iDefIndex)
			continue;

		iCount++;

		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount"))
		{
			int iReserve = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
			if (iReserve > iCount)
				iCount = iReserve;
		}

		if (HasEntProp(iWeapon, Prop_Data, "m_iPrimaryAmmoCount"))
		{
			int iAmmo = GetEntProp(iWeapon, Prop_Data, "m_iPrimaryAmmoCount");
			if (iAmmo > iCount)
				iCount = iAmmo;
		}
	}

	return iCount;
}

int GetAliveTeamCount(int iTeam, bool bFake)
{
	int iCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == iTeam && IsFakeClient(i) == bFake)
			iCount++;
	}

	return iCount;
}

stock bool IsItMyChance(float fChance)
{
    return (fChance > 0.0) && (Math_GetRandomFloat(0.0, 100.0) <= fChance);
}

stock bool IsClientScriptIdle(int iClient)
{
	return (g_iScriptAction[iClient] == ScriptAction_None && g_iDoingSmokeNum[iClient] == -1 && !BotMimic_IsPlayerMimicing(iClient) && !g_bThrowGrenade[iClient] && !g_bNadeThrowPending[iClient] && g_iClientStrategyRole[iClient] == -1 && !IsNadeSolveActive(iClient));
}

stock void ReleaseClientScriptLineupClaim(int iClient)
{
	ScriptAction iAction = g_iScriptAction[iClient];
	int iLineup = g_iScriptActionIndex[iClient];
	ArrayList aLineups = null;

	if (iAction == ScriptAction_Nade)
		aLineups = g_aPistolNades;
	else if (iAction == ScriptAction_PostPlantNade)
		aLineups = g_aPostPlantNades;
	else if (iAction == ScriptAction_Peek)
		aLineups = g_aPeeks;
	else if (iAction == ScriptAction_Angle)
		aLineups = g_aAngles;

	if (aLineups == null || iLineup < 0 || iLineup >= aLineups.Length)
		return;

	ScriptLineup sLineup;
	aLineups.GetArray(iLineup, sLineup);
	if (sLineup.iClaimClient != iClient)
		return;

	sLineup.iClaimClient = 0;
	sLineup.fClaimTime = 0.0;
	aLineups.SetArray(iLineup, sLineup);
}
stock void ClearClientScriptAction(int iClient)
{
	ReleaseClientScriptLineupClaim(iClient);

	g_iScriptAction[iClient] = ScriptAction_None;
	g_iScriptActionIndex[iClient] = -1;
	g_fScriptActionStart[iClient] = 0.0;
	g_fScriptActionLastMoveTime[iClient] = 0.0;
	g_fScriptNextMoveAt[iClient] = 0.0;
	g_fScriptActionLastPos[iClient][0] = 0.0;
	g_fScriptActionLastPos[iClient][1] = 0.0;
	g_fScriptActionLastPos[iClient][2] = 0.0;
}

stock void ResetClientLegacyDefaultNadeTracking(int iClient)
{
	g_fLegacyDefaultNadeActionStart[iClient] = 0.0;
	g_fLegacyDefaultNadeLastMoveTime[iClient] = 0.0;
	g_fScriptNextMoveAt[iClient] = 0.0;
	g_fLegacyDefaultNadeLastPos[iClient][0] = 0.0;
	g_fLegacyDefaultNadeLastPos[iClient][1] = 0.0;
	g_fLegacyDefaultNadeLastPos[iClient][2] = 0.0;
}

stock void StartClientLegacyDefaultNadeAction(int iClient, int iNade, float fNow)
{
	g_iDoingSmokeNum[iClient] = iNade;
	g_fLegacyDefaultNadeActionStart[iClient] = fNow;
	g_fLegacyDefaultNadeLastMoveTime[iClient] = fNow;
	Array_Copy(g_fBotOrigin[iClient], g_fLegacyDefaultNadeLastPos[iClient], 3);
}

stock bool IsLegacyDefaultNadeMovementStale(int iClient, float fNow)
{
	return CheckMovementStale(iClient, g_fLegacyDefaultNadeLastPos[iClient], g_fLegacyDefaultNadeLastMoveTime[iClient], LEGACY_DEFAULT_NADE_STUCK_TIMEOUT, fNow);
}

stock void FailClientLegacyDefaultNadeAction(int iClient, const char[] szReason, float fNow)
{
	int iNade = g_iDoingSmokeNum[iClient];
	if (g_aNades != null && iNade >= 0 && iNade < g_aNades.Length)
	{
		NadeLineup sNade;
		g_aNades.GetArray(iNade, sNade);
		sNade.fTimestamp = fNow;
		g_aNades.SetArray(iNade, sNade);

		PrintToServer("Warning: legacy default nade client=%N replay=%s failed: %s at pos=%.1f %.1f %.1f; retry after %.1f sec.", iClient, sNade.szReplay, szReason, sNade.fPos[0], sNade.fPos[1], sNade.fPos[2], LEGACY_DEFAULT_NADE_RETRY_COOLDOWN);
	}
	else
	{
		PrintToServer("Warning: legacy default nade client=%N index=%d failed: %s; retry after %.1f sec.", iClient, iNade, szReason, LEGACY_DEFAULT_NADE_RETRY_COOLDOWN);
	}

	CancelClientLegacyDefaultNadeAction(iClient);
}

stock void CancelClientLegacyDefaultNadeAction(int iClient)
{
	if (g_iDoingSmokeNum[iClient] == -1)
		return;

	if (BotMimic_IsPlayerMimicing(iClient))
	{
		if (g_aNades != null && g_iDoingSmokeNum[iClient] >= 0 && g_iDoingSmokeNum[iClient] < g_aNades.Length)
			SetNadeTimestamp(g_iDoingSmokeNum[iClient], GetGameTime());

		BotMimic_StopPlayerMimic(iClient);
	}

	g_iDoingSmokeNum[iClient] = -1;
	g_bThrowGrenade[iClient] = false;
	ResetClientLegacyDefaultNadeTracking(iClient);
}

stock void CancelClientScriptAction(int iClient, bool bSwitchWeapon = true)
{
	if (g_iScriptAction[iClient] == ScriptAction_None)
		return;

	if (BotMimic_IsPlayerMimicing(iClient))
		BotMimic_StopPlayerMimic(iClient);

	g_bThrowGrenade[iClient] = false;
	g_iDoingSmokeNum[iClient] = -1;
	ResetClientLegacyDefaultNadeTracking(iClient);
	ClearClientScriptAction(iClient);

	if (bSwitchWeapon && IsValidClient(iClient) && IsPlayerAlive(iClient))
		BotEquipBestWeapon(iClient, true);
}

stock void CancelClientActiveLineupActions(int iClient, bool bSwitchWeapon = true)
{
	CancelNadeSolveJob(iClient, "lineup_cleanup");
	CancelClientScriptAction(iClient, bSwitchWeapon);
	CancelClientLegacyDefaultNadeAction(iClient);
}

stock bool IsValidClient(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsClientSourceTV(iClient));
}

void SetNadeTimestamp(int iIndex, float fTime)
{
	NadeLineup sNade;
	g_aNades.GetArray(iIndex, sNade);
	sNade.fTimestamp = fTime;
	g_aNades.SetArray(iIndex, sNade);
}

void ResetScriptLineupRuntimeState()
{
	ResetScriptLineupRuntime(g_aPistolNades);
	ResetScriptLineupRuntime(g_aPostPlantNades);
	ResetScriptLineupRuntime(g_aPeeks);
	ResetScriptLineupRuntime(g_aAngles);
}

void ResetScriptLineupRuntime(ArrayList aLineups)
{
	if (aLineups == null)
		return;

	for (int i = 0; i < aLineups.Length; i++)
	{
		ScriptLineup sLineup;
		aLineups.GetArray(i, sLineup);
		sLineup.fTimestamp = 0.0;
		sLineup.fClaimTime = 0.0;
		sLineup.fFailureUntil = 0.0;
		sLineup.iClaimClient = 0;
		aLineups.SetArray(i, sLineup);
	}
}
void ResetNadeTimestamps()
{
	ResetScriptLineupRuntimeState();

	for (int i = 0; i < g_aNades.Length; i++)
	{
		NadeLineup sNade;
		g_aNades.GetArray(i, sNade);
		sNade.fTimestamp = 0.0;
		g_aNades.SetArray(i, sNade);
	}
}

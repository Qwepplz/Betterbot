#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <bot_steamids>

#undef REQUIRE_PLUGIN
#include <kento_rankme/rankme>
#define REQUIRE_PLUGIN

#define TEAMMATE_COLOR_COUNT 5
#define PROFILE_RANK_MIN 1
#define PROFILE_RANK_MAX 40
#define PROFILE_RANK_FIRST_MAX_POINTS 1000
#define PROFILE_RANK_DEFAULT_MAX_POINTS 6300

char g_szCrosshairCode[MAXPLAYERS + 1][35];
int g_iProfileRank[MAXPLAYERS + 1];
int g_iPlayerColor[MAXPLAYERS + 1];
bool g_bProfileRanksDirty;
int g_iProfileRankOffset = -1;
int g_iPlayerColorOffset = -1;
int g_iPlayerResourceEntity = -1;
Handle g_hPlayerResourceRetryTimer;
bool g_bPlayerResourceRetryLogged;
int g_iPlayerResourceRetryCount;
Handle g_hSetCrosshairCode;
StringMap g_smHumanTeammateColors;

public Plugin myinfo =
{
    name = "Bot Presentation",
    author = "BetterBots",
    description = "Publishes Bot profile rank, teammate color and crosshair presentation",
    version = "1.0.0"
};

public void OnPluginStart()
{
    HookEventEx("cs_win_panel_match", OnMatchWinPanel);
    HookEventEx("player_spawn", OnPlayerSpawn);
    HookEventEx("player_team", OnPlayerTeam);

    LoadPresentationSdkCall();
    InitializeMapRuntime();
}

public void OnMapStart()
{
    InitializeMapRuntime();
}

public void OnMapEnd()
{
    SafeDeleteTimer(g_hPlayerResourceRetryTimer);
    g_iPlayerResourceRetryCount = 0;
    g_bPlayerResourceRetryLogged = false;

    if (g_iPlayerResourceEntity != -1 && IsValidEntity(g_iPlayerResourceEntity))
        SDKUnhook(g_iPlayerResourceEntity, SDKHook_ThinkPost, OnThinkPost);

    g_iPlayerResourceEntity = -1;
    delete g_smHumanTeammateColors;
    g_smHumanTeammateColors = null;
}

public void OnClientPutInServer(int iClient)
{
    if (!IsValidClient(iClient))
        return;

    InitializeClientPresentation(iClient);
    CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPostAdminCheck(int iClient)
{
    if (!IsValidClient(iClient))
        return;

    InitializeClientPresentation(iClient);
    CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int iClient)
{
    SetProfileRank(iClient, 0);
    g_iPlayerColor[iClient] = -1;
    g_szCrosshairCode[iClient][0] = '\0';
}

void InitializeClientPresentation(int iClient)
{
    SetProfileRank(iClient, PROFILE_RANK_MIN);
    g_iPlayerColor[iClient] = -1;
    g_szCrosshairCode[iClient][0] = '\0';

    if (IsFakeClient(iClient))
        GetBotCrosshairCode(iClient, g_szCrosshairCode[iClient], sizeof(g_szCrosshairCode[]));
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

    return 2 + ((iPoints - PROFILE_RANK_FIRST_MAX_POINTS - 1) * (PROFILE_RANK_MAX - 2)) /
        (iMaxPoints - PROFILE_RANK_FIRST_MAX_POINTS - 1);
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

public void OnPlayerSpawn(Event eEvent, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    SetPlayerTeammateColor(iClient);
}

public void OnPlayerTeam(Event eEvent, const char[] szName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
    if (!IsValidClient(iClient))
        return;

    CreateTimer(0.2, Timer_RefreshPlayerResourceData, GetClientUserId(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

public void OnThinkPost(int iEnt)
{
    if (g_iProfileRankOffset != -1)
    {
        SetEntDataArray(iEnt, g_iProfileRankOffset, g_iProfileRank, MAXPLAYERS + 1, 4, g_bProfileRanksDirty);
        g_bProfileRanksDirty = false;
    }

    if (g_iPlayerColorOffset != -1)
        SetEntDataArray(iEnt, g_iPlayerColorOffset, g_iPlayerColor, MAXPLAYERS + 1, 4);

    Address pEntAddr = GetEntityAddress(iEnt);
    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (IsValidClient(iClient) && IsFakeClient(iClient))
            SDKCall(g_hSetCrosshairCode, pEntAddr, iClient, g_szCrosshairCode[iClient]);
    }
}

public Action Timer_RefreshPlayerResourceData(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if (!IsValidClient(iClient))
        return Plugin_Stop;

    SetPlayerTeammateColor(iClient);

    return Plugin_Stop;
}

void LoadPresentationSdkCall()
{
    GameData hConf = new GameData("bot_presentation.games");
    if (hConf == null)
    {
        SetFailState("Failed to load bot_presentation.games gamedata.");
        return;
    }

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "SetCrosshairCode");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    g_hSetCrosshairCode = EndPrepSDKCall();
    if (g_hSetCrosshairCode == null)
        SetFailState("Failed to create SDKCall: SetCrosshairCode");

    delete hConf;
}

void InitializeMapRuntime()
{
    g_iProfileRankOffset = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");
    g_iPlayerColorOffset = FindSendPropInfo("CCSPlayerResource", "m_iCompTeammateColor");

    if (g_iProfileRankOffset == -1)
        LogError("Failed to find m_nPersonaDataPublicLevel offset");
    if (g_iPlayerColorOffset == -1)
        LogError("Failed to find m_iCompTeammateColor offset");

    HookPlayerResourceEntity();
    ResetTeammateColorAssignments();

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (IsValidClient(iClient))
        {
            InitializeClientPresentation(iClient);
            SetPlayerTeammateColor(iClient);
        }
    }
}

void HookPlayerResourceEntity()
{
    SafeDeleteTimer(g_hPlayerResourceRetryTimer);

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

public Action Timer_TryHookPlayerResourceEntity(Handle hTimer, any iData)
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

void ResetTeammateColorAssignments()
{
    delete g_smHumanTeammateColors;
    g_smHumanTeammateColors = new StringMap();

    for (int iClient = 0; iClient <= MaxClients; iClient++)
        g_iPlayerColor[iClient] = -1;
}

bool GetHumanTeammateColorKey(int iClient, char[] szKey, int iSize)
{
    if (IsFakeClient(iClient) || !GetClientAuthId(iClient, AuthId_Steam2, szKey, iSize, true))
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
    int iAvailableCount;

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

    return iAvailableColors[GetRandomInt(0, iAvailableCount - 1)];
}

bool EnsurePlayerTeammateColor(int iClient, int iTeam)
{
    int iColor = g_iPlayerColor[iClient];
    if (iColor >= 0 && iColor < TEAMMATE_COLOR_COUNT &&
        !IsTeammateColorInUse(iTeam, iColor, iClient))
    {
        return true;
    }

    g_iPlayerColor[iClient] = -1;
    if (g_smHumanTeammateColors == null)
        return false;

    char szKey[32];
    bool bHasHumanKey = GetHumanTeammateColorKey(iClient, szKey, sizeof(szKey));
    if (IsFakeClient(iClient) == false && !bHasHumanKey)
        return false;

    if (bHasHumanKey && g_smHumanTeammateColors.GetValue(szKey, iColor) &&
        iColor >= 0 && iColor < TEAMMATE_COLOR_COUNT &&
        !IsTeammateColorInUse(iTeam, iColor, iClient))
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

void SetPlayerTeammateColor(int iClient)
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

void SafeDeleteTimer(Handle &hTimer)
{
    delete hTimer;
    hTimer = null;
}

bool IsValidClient(int iClient)
{
    return iClient > 0 && iClient <= MaxClients &&
        IsClientConnected(iClient) && IsClientInGame(iClient) && !IsClientSourceTV(iClient);
}

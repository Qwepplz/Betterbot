// Recovered from addons/sourcemod/plugins/kento_c4msg.smx with lysis-java.
// Manual cleanup was required around decompiler placeholder blocks.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_VERSION "3.0"
#define CHAT_MESSAGE_MAX 256

ConVar g_hCvarTimer;
ConVar g_hCvarPrefix;
ConVar g_hCvarShowPlanted;
ConVar g_hCvarShowDefused;
ConVar g_hCvarShowDefuseStart;
ConVar g_hCvarShowDefuseAbort;
ConVar g_hCvarShowCountdown;
ConVar g_hCvarCountdownMax;
ConVar g_hCvarShowDefuserDied;
ConVar g_hCvarShowExplodeTime;
ConVar g_hCvarDebug;
ConVar g_hCvarColorLow;
ConVar g_hCvarColorMedium;
ConVar g_hCvarColorHigh;
Handle g_hTimer_Countdown = INVALID_HANDLE;
float g_fDetonateTime;
float g_fC4Timer;
float g_fDefuseEndTime;
char g_sChatPrefix[64] = "C4MSG";
int g_iDefusingClient = -1;
bool g_bCurrentlyDefusing;

public Plugin myinfo =
{
    name = "C4 Messages",
    description = "Rewrite C4 countdown and messages.",
    author = "Kento & Matt",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/id/kentomatoryoshika/"
};

public void OnPluginStart()
{
    LoadTranslations("kento.c4msg.phrases");

    g_hCvarTimer = FindConVar("mp_c4timer");
    if (g_hCvarTimer == null)
    {
        SetFailState("无法找到ConVar: mp_c4timer");
        return;
    }

    g_hCvarPrefix = CreateConVar("sm_c4msg_prefix", "C4MSG", "聊天前缀文本");
    g_hCvarShowPlanted = CreateConVar("sm_c4msg_show_planted", "1", "是否在炸弹安放时显示消息", _, true, 0.0, true, 1.0);
    g_hCvarShowDefused = CreateConVar("sm_c4msg_show_defused", "1", "是否在炸弹被拆除时显示剩余时间消息", _, true, 0.0, true, 1.0);
    g_hCvarShowDefuseStart = CreateConVar("sm_c4msg_show_defuse_start", "1", "是否在开始拆弹时显示消息", _, true, 0.0, true, 1.0);
    g_hCvarShowDefuseAbort = CreateConVar("sm_c4msg_show_defuse_abort", "1", "是否在停止拆弹时显示消息", _, true, 0.0, true, 1.0);
    g_hCvarShowCountdown = CreateConVar("sm_c4msg_show_countdown", "1", "是否显示倒计时提示", _, true, 0.0, true, 1.0);
    g_hCvarCountdownMax = CreateConVar("sm_c4msg_countdown_max", "40", "倒计时显示的最大时间（秒）", _, true, 1.0);
    g_hCvarShowDefuserDied = CreateConVar("sm_c4msg_show_defuser_died", "1", "是否在拆弹者死亡时显示时间差信息", _, true, 0.0, true, 1.0);
    g_hCvarShowExplodeTime = CreateConVar("sm_c4msg_show_explode_time", "1", "是否在炸弹爆炸时显示拆弹时间差信息", _, true, 0.0, true, 1.0);
    g_hCvarDebug = CreateConVar("sm_c4msg_debug", "0", "是否对管理员显示调试信息", _, true, 0.0, true, 1.0);
    g_hCvarColorLow = CreateConVar("sm_c4msg_color_low", "#FF0000", "低倒计时颜色（0-10秒），使用HTML颜色代码");
    g_hCvarColorMedium = CreateConVar("sm_c4msg_color_medium", "#FF4500", "中倒计时颜色（11-20秒），使用HTML颜色代码");
    g_hCvarColorHigh = CreateConVar("sm_c4msg_color_high", "#FFFF00", "高倒计时颜色（21-40秒），使用HTML颜色代码");

    g_hCvarTimer.AddChangeHook(OnConVarChanged);
    g_hCvarPrefix.AddChangeHook(OnConVarChanged);
    HookEvent("bomb_planted", EventBombPlanted, EventHookMode_Pre);
    HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
    HookEvent("bomb_exploded", EventBombExploded, EventHookMode_PostNoCopy);
    HookEvent("bomb_defused", EventBombDefused, EventHookMode_Post);
    HookEvent("player_death", EventPlayerDeath, EventHookMode_Pre);
    HookEvent("bomb_planted", EventBombPlantedPost, EventHookMode_Post);
    HookEvent("bomb_begindefuse", EventBombDefuseBeginPost, EventHookMode_Post);
    HookEvent("bomb_abortdefuse", EventBombDefuseAbortPost, EventHookMode_Post);
    HookEvent("bomb_exploded", EventBombExplodedPost, EventHookMode_Post);

    AutoExecConfig(true, "kento_c4msg", "sourcemod");
}

public void OnConfigsExecuted()
{
    g_fC4Timer = g_hCvarTimer.FloatValue;
    if (g_fC4Timer <= 0.0)
    {
        g_fC4Timer = 40.0;
    }

    g_hCvarPrefix.GetString(g_sChatPrefix, sizeof(g_sChatPrefix));

    if (g_hCvarDebug.BoolValue)
    {
        LogMessage("kento_c4msg debug mode enabled.");
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_hCvarTimer)
    {
        g_fC4Timer = g_hCvarTimer.FloatValue;
    }
    else if (convar == g_hCvarPrefix)
    {
        g_hCvarPrefix.GetString(g_sChatPrefix, sizeof(g_sChatPrefix));
    }
}

public Action EventBombDefuseAbortPost(Event event, const char[] name, bool dontBroadcast)
{
    BombTime_BombAbortDefuse(event);
    return Plugin_Continue;
}

public Action EventBombDefuseBeginPost(Event event, const char[] name, bool dontBroadcast)
{
    BombTime_BombBeginDefuse(event);
    return Plugin_Continue;
}
public Action EventBombDefused(Event event, const char[] name, bool dontBroadcast)
{
    StopCountdownTimer();

    if (g_hCvarShowDefused.BoolValue)
    {
        BombTime_BombDefused(event);
    }
    else
    {
        ResetDefuseState();
    }

    return Plugin_Continue;
}

public Action EventBombExploded(Event event, const char[] name, bool dontBroadcast)
{
    StopCountdownTimer();
    return Plugin_Continue;
}

public Action EventBombExplodedPost(Event event, const char[] name, bool dontBroadcast)
{
    if (g_hCvarShowExplodeTime.BoolValue)
    {
        BombTime_BombExploded();
    }
    else
    {
        ResetDefuseState();
    }

    return Plugin_Continue;
}

public Action EventBombPlanted(Event event, const char[] name, bool dontBroadcast)
{
    g_fDetonateTime = GetGameTime() + g_fC4Timer;

    if (g_hCvarShowCountdown.BoolValue)
    {
        StopCountdownTimer();
        g_hTimer_Countdown = CreateTimer(1.0, TimerCountdown, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Continue;
}
public Action EventBombPlantedPost(Event event, const char[] name, bool dontBroadcast)
{
    if (g_hCvarShowPlanted.BoolValue)
    {
        for (int client = 1; client <= MaxClients; client++)
        {
            if (IsHumanClient(client))
            {
                CPrintToChat(client, "%T", "Bomb Planted", client, g_sChatPrefix);
            }
        }
    }

    BombTime_BombPlanted();
    return Plugin_Continue;
}

public Action EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (g_hCvarShowDefuserDied.BoolValue)
    {
        BombTime_PlayerDeath(event);
    }
    else if (GetClientOfUserId(event.GetInt("userid")) == g_iDefusingClient)
    {
        ResetDefuseState();
    }

    return Plugin_Continue;
}

public Action EventRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    StopCountdownTimer();

    g_fDetonateTime = 0.0;
    g_fDefuseEndTime = 0.0;
    ResetDefuseState();

    return Plugin_Continue;
}

public Action TimerCountdown(Handle timer, any data)
{
    if (timer == INVALID_HANDLE || g_hTimer_Countdown != timer)
    {
        return Plugin_Stop;
    }

    if (g_fDetonateTime <= 0.0)
    {
        g_hTimer_Countdown = INVALID_HANDLE;
        return Plugin_Stop;
    }

    float timeLeft = g_fDetonateTime - GetGameTime();
    if (timeLeft < -1.0)
    {
        g_hTimer_Countdown = INVALID_HANDLE;
        return Plugin_Stop;
    }

    if (timeLeft >= 0.0 && timeLeft <= g_hCvarCountdownMax.FloatValue)
    {
        BombMessage(RoundToNearest(timeLeft));
    }

    return Plugin_Continue;
}
void BombMessage(int seconds)
{
    if (seconds < 0)
    {
        return;
    }

    char color[16];
    GetCountdownColor(seconds, color, sizeof(color));

    int phraseSeconds = seconds;
    if (phraseSeconds > 40)
    {
        phraseSeconds = 40;
    }

    char phrase[32];
    Format(phrase, sizeof(phrase), "countdown %d", phraseSeconds);

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsHumanClient(client))
        {
            char message[CHAT_MESSAGE_MAX];
            Format(message, sizeof(message), "%T", phrase, client, seconds);
            ReplaceString(message, sizeof(message), "{COLOR}", color, false);
            PrintHintText(client, "%s", message);
        }
    }
}

void BombTime_PlayerDeath(Event event)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (victim != g_iDefusingClient || !g_bCurrentlyDefusing)
    {
        return;
    }

    g_bCurrentlyDefusing = false;
    g_iDefusingClient = -1;

    if (!IsClientValid(victim))
    {
        return;
    }

    float timeAway = g_fDefuseEndTime - GetGameTime();
    if (timeAway > 0.0)
    {
        char victimName[MAX_NAME_LENGTH];
        char seconds[16];
        GetClientName(victim, victimName, sizeof(victimName));
        FormatSeconds(timeAway, seconds, sizeof(seconds));
        BroadcastC4Message("DefuserDiedTimeLeftMessage", victimName, seconds);
        return;
    }

    if (IsClientValid(attacker))
    {
        char attackerName[MAX_NAME_LENGTH];
        char seconds[16];
        GetClientName(attacker, attackerName, sizeof(attackerName));
        FormatSeconds(-timeAway, seconds, sizeof(seconds));
        BroadcastC4Message("PostDefuseKillTimeMessage", attackerName, seconds);
    }
}

void BombTime_BombPlanted()
{
    ResetDefuseState();
}

void BombTime_BombDefused(Event event)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsClientValid(client))
    {
        ResetDefuseState();
        return;
    }

    float timeLeft = g_fDetonateTime - GetGameTime();
    if (timeLeft < 0.0)
    {
        timeLeft = 0.0;
    }
    char clientName[MAX_NAME_LENGTH];
    char seconds[16];
    GetClientName(client, clientName, sizeof(clientName));
    FormatSeconds(timeLeft, seconds, sizeof(seconds));
    BroadcastC4Message("SuccessfulDefuseTimeLeftMessage", clientName, seconds);
    ResetDefuseState();
}

void BombTime_BombBeginDefuse(Event event)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsClientValid(client))
    {
        return;
    }

    bool hasKit = event.GetBool("haskit", false) || GetEntProp(client, Prop_Send, "m_bHasDefuser") != 0;
    g_iDefusingClient = client;
    g_bCurrentlyDefusing = true;
    g_fDefuseEndTime = GetGameTime() + (hasKit ? 5.0 : 10.0);

    if (!g_hCvarShowDefuseStart.BoolValue)
    {
        return;
    }

    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));

    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsHumanClient(target))
        {
            char kitText[64];
            Format(kitText, sizeof(kitText), "%T", hasKit ? "With Kit" : "Without Kit", target);
            CPrintToChat(target, "%T", "Defuse Started", target, g_sChatPrefix, clientName, kitText);
        }
    }
}

void BombTime_BombAbortDefuse(Event event)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client == g_iDefusingClient)
    {
        ResetDefuseState();
    }

    if (!g_hCvarShowDefuseAbort.BoolValue || !IsClientValid(client))
    {
        return;
    }

    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));

    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsHumanClient(target))
        {
            CPrintToChat(target, "%T", "Defuse Aborted", target, g_sChatPrefix, clientName);
        }
    }
}
void BombTime_BombExploded()
{
    if (!g_bCurrentlyDefusing || !IsClientValid(g_iDefusingClient))
    {
        ResetDefuseState();
        return;
    }

    float lateBy = g_fDefuseEndTime - g_fDetonateTime;
    if (lateBy >= 0.0)
    {
        char clientName[MAX_NAME_LENGTH];
        char seconds[16];
        GetClientName(g_iDefusingClient, clientName, sizeof(clientName));
        FormatSeconds(lateBy, seconds, sizeof(seconds));
        BroadcastC4Message("BombExplodedTimeLeftMessage", clientName, seconds);
    }

    ResetDefuseState();
}

void BroadcastC4Message(const char[] phrase, const char[] clientName, const char[] seconds)
{
    for (int target = 1; target <= MaxClients; target++)
    {
        if (IsHumanClient(target))
        {
            CPrintToChat(target, "%T", phrase, target, g_sChatPrefix, clientName, seconds);
        }
    }
}

void GetCountdownColor(int seconds, char[] color, int maxlen)
{
    if (seconds <= 10)
    {
        g_hCvarColorLow.GetString(color, maxlen);
    }
    else if (seconds <= 20)
    {
        g_hCvarColorMedium.GetString(color, maxlen);
    }
    else
    {
        g_hCvarColorHigh.GetString(color, maxlen);
    }
}

void FormatSeconds(float seconds, char[] buffer, int maxlen)
{
    if (seconds < 0.0)
    {
        seconds = -seconds;
    }

    Format(buffer, maxlen, "%.1f", seconds);
}

void StopCountdownTimer()
{
    if (g_hTimer_Countdown != INVALID_HANDLE)
    {
        KillTimer(g_hTimer_Countdown);
        g_hTimer_Countdown = INVALID_HANDLE;
    }
}

void ResetDefuseState()
{
    g_iDefusingClient = -1;
    g_bCurrentlyDefusing = false;
}

bool IsClientValid(int client)
{
    return client > 0
        && client <= MaxClients
        && IsClientConnected(client)
        && IsClientInGame(client)
        && !IsClientSourceTV(client)
        && !IsClientReplay(client);
}

bool IsHumanClient(int client)
{
    return IsClientValid(client) && !IsFakeClient(client);
}

stock void CPrintToChat(int client, const char[] format, any ...)
{
    if (!IsHumanClient(client))
    {
        return;
    }

    char message[CHAT_MESSAGE_MAX];
    SetGlobalTransTarget(client);
    VFormat(message, sizeof(message), format, 3);
    Colorize(message, sizeof(message));
    PrintToChat(client, "%s", message);
}

void Colorize(char[] message, int maxlen)
{
    ReplaceString(message, maxlen, "{DEFAULT}", "\x01", false);
    ReplaceString(message, maxlen, "{GREEN}", "\x04", false);
    ReplaceString(message, maxlen, "{BLUE}", "\x0B", false);
    ReplaceString(message, maxlen, "{RED}", "\x02", false);
    ReplaceString(message, maxlen, "{ORANGE}", "\x10", false);
}

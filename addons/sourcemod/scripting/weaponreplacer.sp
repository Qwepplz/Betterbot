#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

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

public Plugin myinfo =
{
    name = "Weapon Replacer",
    author = "Rxpev",
    description = "Replaces P2000 with USP-S on spawn and M4A4 with M4A1-S on purchase for CTs",
    version = "1.6",
    url = "https://steamcommunity.com/id/rxpev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Get5_GetGameState");
    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);
}

bool IsGet5WeaponReplacementBlockedPhase()
{
    if (GetFeatureStatus(FeatureType_Native, "Get5_GetGameState") != FeatureStatus_Available)
        return false;

    Get5State state = Get5_GetGameState();
    return state == Get5State_KnifeRound || state == Get5State_WaitingForKnifeRoundDecision;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT)
        return;

    if (IsGet5WeaponReplacementBlockedPhase())
        return;

    int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);

    if (weapon == -1)
    {
        GivePlayerItem(client, "weapon_usp_silencer");
        return;
    }

    char weaponName[32];
    GetEntityClassname(weapon, weaponName, sizeof(weaponName));

    if (StrEqual(weaponName, "weapon_hkp2000"))
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
        GivePlayerItem(client, "weapon_usp_silencer");
    }
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if (!IsValidClient(client) || IsFakeClient(client) || GetClientTeam(client) != CS_TEAM_CT)
        return Plugin_Continue;

    if (!StrEqual(weapon, "m4a1", false))
        return Plugin_Continue;

    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (primary != -1 && IsValidEntity(primary))
        return Plugin_Handled;

    DataPack pack;
    CreateDataTimer(0.1, Timer_ReplaceM4A4, pack, TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(GetClientUserId(client));
    return Plugin_Handled;
}

public Action Timer_ReplaceM4A4(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());

    if (!IsValidClient(client) || IsFakeClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT)
        return Plugin_Stop;

    if (GetEntProp(client, Prop_Send, "m_bInBuyZone") == 0)
        return Plugin_Stop;

    int money = GetEntProp(client, Prop_Send, "m_iAccount");
    const int M4A1S_PRICE = 2900;

    if (money < M4A1S_PRICE)
        return Plugin_Stop;

    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (primary != -1 && IsValidEntity(primary))
        return Plugin_Stop;

    int replacement = GivePlayerItem(client, "weapon_m4a1_silencer");
    if (replacement == -1 || !IsValidEntity(replacement))
        return Plugin_Stop;

    SetEntProp(client, Prop_Send, "m_iAccount", money - M4A1S_PRICE);
    EquipPlayerWeapon(client, replacement);
    return Plugin_Stop;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

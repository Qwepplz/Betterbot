#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

static const char CT_DEFAULT_SECONDARY[] = "mp_ct_default_secondary";
static const char CT_DEFAULT_PISTOL[] = "weapon_usp_silencer";
static const char PURCHASED_M4A4_ALIAS[] = "m4a1";
static const char REPLACEMENT_M4A1S[] = "weapon_m4a1_silencer";
static const char REPLACEMENT_NOTIFICATION[] = " \x04[武器替换]\x01 已自动将M4A4替换为M4A1";

ConVar g_Cvar_ShowNotifications;
ConVar g_Cvar_ReplaceP2000;
ConVar g_Cvar_ReplaceM4A4;

public Plugin myinfo =
{
    name = "CT_Weapon_Replacement",
    description = "Replaces M4A4 with M4A1 for CT and sets default USP",
    author = "Matt",
    version = "2.8",
    url = "https://space.bilibili.com/4970018"
};

public void OnPluginStart()
{
    g_Cvar_ShowNotifications = CreateConVar("sm_ct_weapon_replacement_notifications", "1", "是否显示武器替换通知 (0=不显示, 1=显示)", _, true, 0.0, true, 1.0);
    g_Cvar_ReplaceP2000 = CreateConVar("sm_ct_weapon_replacement_p2000", "1", "是否将P2000替换为USP (0=不替换, 1=替换)", _, true, 0.0, true, 1.0);
    g_Cvar_ReplaceM4A4 = CreateConVar("sm_ct_weapon_replacement_m4a4", "1", "是否将M4A4替换为M4A1 (0=不替换, 1=替换)", _, true, 0.0, true, 1.0);

    AutoExecConfig(true, "CT_Weapon_Replacement", "sourcemod");
}

public void OnConfigsExecuted()
{
    if (!g_Cvar_ReplaceP2000.BoolValue)
    {
        return;
    }

    ConVar defaultSecondary = FindConVar(CT_DEFAULT_SECONDARY);
    if (defaultSecondary != null)
    {
        defaultSecondary.SetString(CT_DEFAULT_PISTOL, true, false);
    }
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
    if (!g_Cvar_ReplaceM4A4.BoolValue || !IsValidBotClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != CS_TEAM_CT)
    {
        return Plugin_Continue;
    }

    if (!StrEqual(weapon, PURCHASED_M4A4_ALIAS, false))
    {
        return Plugin_Continue;
    }

    if (!GetEntProp(client, Prop_Send, "m_bInBuyZone"))
    {
        return Plugin_Stop;
    }

    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (primary != -1 && IsValidEntity(primary))
    {
        return Plugin_Stop;
    }

    int replacementPrice = CS_GetWeaponPrice(client, CSWeapon_M4A1_SILENCER);
    int account = GetEntProp(client, Prop_Send, "m_iAccount");
    if (account < replacementPrice)
    {
        return Plugin_Stop;
    }

    int replacementWeapon = GivePlayerItem(client, REPLACEMENT_M4A1S);
    if (replacementWeapon == -1 || !IsValidEntity(replacementWeapon))
    {
        return Plugin_Stop;
    }

    SetEntProp(client, Prop_Send, "m_iAccount", account - replacementPrice);
    EquipPlayerWeapon(client, replacementWeapon);

    if (g_Cvar_ShowNotifications.BoolValue)
    {
        PrintToChat(client, REPLACEMENT_NOTIFICATION);
    }

    return Plugin_Stop;
}

bool IsValidBotClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client);
}

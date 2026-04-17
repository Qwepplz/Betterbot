#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

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
    HookEvent("item_purchase", Event_ItemPurchase, EventHookMode_Post);

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

    ConVar mpCtDefaultSecondary = FindConVar("mp_ct_default_secondary");
    if (mpCtDefaultSecondary != null)
    {
        mpCtDefaultSecondary.SetString("weapon_usp_silencer", true, false);
    }
}

public Action Event_ItemPurchase(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidBotClient(client) || GetClientTeam(client) != CS_TEAM_CT)
    {
        return Plugin_Continue;
    }

    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));

    if (g_Cvar_ReplaceM4A4.BoolValue && StrEqual(weapon, "weapon_m4a1", true))
    {
        DataPack dataPack = new DataPack();
        dataPack.WriteCell(GetClientUserId(client));
        CreateTimer(0.2, Timer_ReplaceWeapon, dataPack);
    }

    return Plugin_Continue;
}

public Action Timer_ReplaceWeapon(Handle timer, DataPack dataPack)
{
    dataPack.Reset(false);
    int userId = dataPack.ReadCell();
    delete dataPack;

    int client = GetClientOfUserId(userId);
    if (!IsValidBotClient(client) || !IsPlayerAlive(client) || !g_Cvar_ReplaceM4A4.BoolValue)
    {
        return Plugin_Stop;
    }

    int weaponEntity = -1;
    while ((weaponEntity = GetPlayerWeaponByClassname(client, "weapon_m4a1")) != -1)
    {
        RemovePlayerItem(client, weaponEntity);
        AcceptEntityInput(weaponEntity, "Kill");
    }

    GivePlayerItem(client, "weapon_m4a1_silencer");

    if (g_Cvar_ShowNotifications.BoolValue)
    {
        PrintToChat(client, " \x04[武器替换]\x01 已自动将M4A4替换为M4A1");
    }

    return Plugin_Stop;
}

int GetPlayerWeaponByClassname(int client, const char[] targetClassname)
{
    for (int slot = 0; slot < 5; slot++)
    {
        int weaponEntity = GetPlayerWeaponSlot(client, slot);
        if (weaponEntity == -1)
        {
            continue;
        }

        char classname[64];
        GetEntityClassname(weaponEntity, classname, sizeof(classname));

        if (StrEqual(classname, targetClassname, true))
        {
            return weaponEntity;
        }
    }

    return -1;
}

bool IsValidBotClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsFakeClient(client);
}

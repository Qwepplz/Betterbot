#if defined _bot_demo_replays_included
    #endinput
#endif
#define _bot_demo_replays_included

#include <bot_demo_rules>

enum struct DRRecord
{
    char id[64];
    char path[PLATFORM_MAX_PATH];
    char category[64];
    char sourceRound[128];
    char weaponGroup[32];
    int team;
    bool opening;
    bool pistol;
    int frames;
    int freezeFrame;
    float origin[3];
    float startAngles[3];
    float target[3];
    bool requiresPrimary;
    bool requiresC4;
    int grenades[4];
    CSWeaponID fireWeapon;
    CSWeaponID targetWeapon;
    DRGrenadeKind kind;
}

enum struct DRClient
{
    int serial;
    int round;
    int role;
    bool consumed;
    bool preparing;
    bool active;
    bool firstFrame;
    float nextMoveAt;
    float startedAt;
}

enum DRGrenadeStage
{
    DR_GrenadeStageIdle,
    DR_GrenadeStageApproaching,
    DR_GrenadeStagePlaying
}

enum struct DRGrenadePlayback
{
    DRGrenadeStage stage;
    bool firstFrame;
    int serial;
    int round;
    int record;
    int reservation;
    int equippedWeaponRef;
    float startedAt;
    float assignedAt;
    float progressSince;
    float progressOrigin[3];
    float nextMoveAt;
    float pauseSince;
}

enum DREffectPhase
{
    DR_EffectSelected,
    DR_EffectFlying,
    DR_EffectActive
}

enum struct DREffect
{
    int id;
    bool live;
    int round;
    int ownerSerial;
    int ownerHandle;
    int pendingWeaponRef;
    bool throwCommitted;
    float effectStartedAt;
    int team;
    DRGrenadeKind kind;
    DREffectPhase phase;
    bool sourceKnown;
    float target[3];
    float actual[3];
    float lastPosition[3];
    float expiresAt;
    float thrownAt;
    float destroyedAt;
    int projectileRef;
    int projectileIndex;
    int sequence;
    int infernoRef;
    char recordID[64];
}

ArrayList g_DRCatalog;
ArrayList g_DREffects;
int g_DRNextEffect;
int g_DRNextProjectile;
ArrayList g_DRGrenadeIndex[4][4];
float g_DRNextGrenadeScan[MAXPLAYERS + 1];
DRGrenadePlayback g_DRGrenade[MAXPLAYERS + 1];
DRClient g_DRClient[MAXPLAYERS + 1];
int g_DRRoundSerial;
bool g_DRRoundActive;
bool g_DRTeamRolled[4];
bool g_DRTeamAccepted[4];
bool g_DRTeamStarted[4];
char g_DRTeamSource[4][128];

bool DR_IsClient(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client)
        && IsFakeClient(client) && IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T;
}

bool DR_OwnsOpening(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client) && g_DRClient[client].active
        && g_DRClient[client].serial == GetClientSerial(client)
        && g_DRClient[client].round == g_DRRoundSerial;
}

bool DR_MatchesOpeningPlayback(int client)
{
    if (!DR_OwnsOpening(client) || !BotMimic_IsPlayerMimicing(client) || g_DRCatalog == null)
        return false;
    int role = g_DRClient[client].role;
    if (role < 0 || role >= g_DRCatalog.Length) return false;
    DRRecord record;
    g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
    char path[PLATFORM_MAX_PATH];
    BotMimic_GetRecordPlayerMimics(client, path, sizeof(path));
    return StrEqual(path, record.path);
}

void DR_ClearOpeningTeam(int team, const char[] reason)
{
    if (team != CS_TEAM_T && team != CS_TEAM_CT) return;
    g_DRTeamAccepted[team] = false;
    g_DRTeamStarted[team] = false;
    for (int client = 1; client <= MaxClients; client++)
    {
        int role = g_DRClient[client].role;
        if ((!g_DRClient[client].active && !g_DRClient[client].preparing)
            || g_DRCatalog == null || role < 0 || role >= g_DRCatalog.Length)
            continue;
        DRRecord record;
        g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
        if (record.team == team) DR_StopClient(client, reason);
    }
}

void DR_OpeningLifecycle(int client, const char[] reason)
{
    int role = g_DRClient[client].role;
    if ((g_DRClient[client].active || g_DRClient[client].preparing)
        && g_DRCatalog != null && role >= 0 && role < g_DRCatalog.Length)
    {
        DRRecord record;
        g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
        DR_ClearOpeningTeam(record.team, reason);
    }
    else DR_StopClient(client, reason);
}

void DR_StopClient(int client, const char[] reason, bool stopMimic = true)
{
    if (client < 1 || client > MaxClients) return;
    bool owned = DR_MatchesOpeningPlayback(client);
    bool assigned = g_DRClient[client].active || g_DRClient[client].preparing;
    int team, role = g_DRClient[client].role;
    if (assigned && g_DRCatalog != null && role >= 0 && role < g_DRCatalog.Length)
    {
        DRRecord record;
        g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
        team = record.team;
    }
    g_DRClient[client].active = false;
    g_DRClient[client].preparing = false;
    g_DRClient[client].role = -1;
    g_DRClient[client].firstFrame = false;
    g_DRClient[client].nextMoveAt = 0.0;
    if (assigned) g_DRClient[client].consumed = true;
    if (owned && stopMimic) BotMimic_StopPlayerMimic(client);
    if (team >= CS_TEAM_T) DR_CheckOpeningFinished(team);
    if (assigned)
        PrintToServer("[DemoReplay] opening_stop round=%d serial=%d reason=%s",
            g_DRRoundSerial, g_DRClient[client].serial, reason);
}

void DR_CheckOpeningFinished(int team)
{
    if (!g_DRTeamAccepted[team] || g_DRCatalog == null) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        int role = g_DRClient[client].role;
        if ((!g_DRClient[client].active && !g_DRClient[client].preparing)
            || role < 0 || role >= g_DRCatalog.Length)
            continue;
        DRRecord record;
        g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
        if (record.team == team) return;
    }
    g_DRTeamAccepted[team] = false;
    g_DRTeamStarted[team] = false;
    g_DRTeamSource[team][0] = '\0';
}

void DR_OnRoundStart()
{
    DR_ResetRound();
    g_DRRoundSerial++;
    g_DRRoundActive = true;
    for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++)
    {
        g_DRTeamRolled[team] = false;
        g_DRTeamAccepted[team] = false;
        g_DRTeamStarted[team] = false;
        g_DRTeamSource[team][0] = '\0';
    }
    for (int client = 1; client <= MaxClients; client++)
    {
        DR_StopClient(client, "round_reset");
        g_DRClient[client].consumed = false;
        g_DRClient[client].serial = IsClientInGame(client) ? GetClientSerial(client) : 0;
        g_DRClient[client].round = g_DRRoundSerial;
    }
}

void DR_OnRoundEnd()
{
    g_DRRoundActive = false;
    for (int client = 1; client <= MaxClients; client++)
        DR_StopClient(client, "round_end");
    DR_ResetRound();
}

bool DR_FormalRound()
{
    return g_DRRoundActive && !IsWarmupPeriod() && Get5_GetGameState() == Get5State_Live;
}

bool DR_ValidID(const char[] id)
{
    if (strlen(id) != 34 || id[1] != '_' || (id[0] != 'o' && id[0] != 'g'))
        return false;
    for (int i = 2; i < 34; i++)
        if (!((id[i] >= '0' && id[i] <= '9') || (id[i] >= 'a' && id[i] <= 'f')))
            return false;
    return true;
}

bool DR_LoadMapCatalog()
{
    DR_OnRoundEnd();
    delete g_DRCatalog;
    g_DRCatalog = new ArrayList(sizeof(DRRecord));
    for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++)
        for (int kind = 0; kind < 4; kind++)
        {
            delete g_DRGrenadeIndex[team][kind];
            g_DRGrenadeIndex[team][kind] = new ArrayList();
        }
    char map[64], path[PLATFORM_MAX_PATH];
    GetCurrentMap(map, sizeof(map));
    BuildPath(Path_SM, path, sizeof(path), "data/botmimic_catalog/%s.txt", map);
    KeyValues catalog = new KeyValues("DemoReplays");
    if (!catalog.ImportFromFile(path))
    {
        delete catalog;
        PrintToServer("[DemoReplay] catalog_missing map=%s", map);
        return false;
    }
    if (catalog.GetNum("schema") != 1 || catalog.GetNum("tickrate") != DR_TICKRATE
        || catalog.GetNum("opening_chance") != DR_OPENING_CHANCE)
    {
        delete catalog;
        LogError("[DemoReplay] catalog contract mismatch map=%s", map);
        return false;
    }
    int rejected;
    if (catalog.JumpToKey("records") && catalog.GotoFirstSubKey())
        do
        {
            if (catalog.GetNum("enabled") != 1) continue;
            DRRecord record;
            if (!DR_ReadCatalogRecord(catalog, map, record))
            {
                rejected++;
                PrintToServer("[DemoReplay] catalog_record_rejected map=%s rec=%s reason=invalid_or_unavailable",
                    map, record.id);
                continue;
            }
            int index = g_DRCatalog.PushArray(record, sizeof(DRRecord));
            if (!record.opening)
                g_DRGrenadeIndex[record.team][view_as<int>(record.kind)].Push(index);
        }
        while (catalog.GotoNextKey());
    delete catalog;
    PrintToServer("[DemoReplay] catalog_loaded map=%s enabled=%d rejected=%d", map, g_DRCatalog.Length, rejected);
    return true;
}

bool DR_ReadCatalogRecord(KeyValues catalog, const char[] map, DRRecord record)
{
    char relative[PLATFORM_MAX_PATH], entryMap[64], expected[PLATFORM_MAX_PATH], kind[16];
    catalog.GetSectionName(record.id, sizeof(record.id));
    catalog.GetString("path", relative, sizeof(relative));
    catalog.GetString("map", entryMap, sizeof(entryMap));
    catalog.GetString("category", record.category, sizeof(record.category));
    record.opening = StrContains(record.category, "opening_") == 0;
    record.pistol = StrContains(record.category, "_pistol") != -1;
    record.team = catalog.GetNum("team");
    Format(expected, sizeof(expected), "botmimic/%s/%s/%s.rec", record.category, map, record.id);
    if (!DR_ValidID(record.id) || !StrEqual(entryMap, map) || !StrEqual(relative, expected)
        || StrContains(record.category, "..") != -1 || StrContains(record.category, "/") != -1
        || StrContains(record.category, "\\") != -1 || (record.team != CS_TEAM_T && record.team != CS_TEAM_CT))
        return false;
    BuildPath(Path_SM, record.path, sizeof(record.path), "data/%s", relative);
    if (!FileExists(record.path)) return false;
    catalog.GetString("round_uid", record.sourceRound, sizeof(record.sourceRound));
    catalog.GetString("weapon_group", record.weaponGroup, sizeof(record.weaponGroup));
    catalog.GetVector("origin", record.origin);
    catalog.GetVector("angles", record.startAngles);
    catalog.GetVector("target_center", record.target);
    record.frames = catalog.GetNum("frame_count");
    record.freezeFrame = catalog.GetNum("freeze_end_frame", -1);
    record.targetWeapon = view_as<CSWeaponID>(catalog.GetNum("target_weapon"));
    catalog.GetString("kind", kind, sizeof(kind));
    if (StrEqual(kind, "smoke")) record.kind = DR_Smoke;
    else if (StrEqual(kind, "flash")) record.kind = DR_Flash;
    else if (StrEqual(kind, "he")) record.kind = DR_HE;
    else if (StrEqual(kind, "fire")) record.kind = DR_Fire;
    else if (!record.opening) return false;
    record.fireWeapon = record.team == CS_TEAM_CT ? CSWeapon_INCGRENADE : CSWeapon_MOLOTOV;
    if (catalog.JumpToKey("weapons"))
    {
        char key[8];
        for (int weapon = 1; weapon <= 64; weapon++)
        {
            IntToString(weapon, key, sizeof(key));
            if (catalog.GetNum(key) > 0 && DR_IsPrimaryWeapon(view_as<CSWeaponID>(weapon)))
                record.requiresPrimary = true;
        }
        record.requiresC4 = catalog.GetNum("6") > 0;
        record.grenades[DR_Smoke] = catalog.GetNum("9");
        record.grenades[DR_Flash] = catalog.GetNum("24");
        record.grenades[DR_HE] = catalog.GetNum("4");
        record.grenades[DR_Fire] = catalog.GetNum("51") + catalog.GetNum("53");
        if (catalog.GetNum("53") > 0) record.fireWeapon = CSWeapon_INCGRENADE;
        else if (catalog.GetNum("51") > 0) record.fireWeapon = CSWeapon_MOLOTOV;
        catalog.GoBack();
    }
    if (record.frames <= 0 || (record.opening && (record.sourceRound[0] == '\0'
        || record.freezeFrame < 0 || record.freezeFrame >= record.frames)))
        return false;
    char expectedCategory[64];
    if (record.opening)
        Format(expectedCategory, sizeof(expectedCategory), "opening_%s_%s",
            record.team == CS_TEAM_CT ? "ct" : "t", record.pistol ? "pistol" : "nonpistol");
    else
        Format(expectedCategory, sizeof(expectedCategory), "grenade_%s_%s",
            record.team == CS_TEAM_CT ? "ct" : "t", kind);
    if (!StrEqual(record.category, expectedCategory) || record.id[0] != (record.opening ? 'o' : 'g'))
        return false;
    int total;
    for (int type = 0; type < 4; type++)
    {
        if (record.grenades[type] < 0 || record.grenades[type] > (type == view_as<int>(DR_Flash) ? 2 : 1))
            return false;
        total += record.grenades[type];
    }
    if (total > 4) return false;
    if (!record.opening && record.targetWeapon != DR_GrenadeWeapon(record.kind, record))
        return false;
    return true;
}

public void DR_LoadCatalogFrame(any data)
{
    DR_LoadMapCatalog();
}

bool DR_EligibleOpeningClient(int client)
{
    return DR_IsClient(client) && !g_DRClient[client].consumed && !g_DRClient[client].active
        && !BotMimic_IsPlayerMimicing(client) && GetTask(client) != PLANT_BOMB
        && GetTask(client) != GUARD_TICKING_BOMB;
}

bool DR_WeaponGroupMatches(int client, const char[] group)
{
    int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
    if (!IsValidEntity(primary))
        return true;
    int definition = GetEntProp(primary, Prop_Send, "m_iItemDefinitionIndex");
    if (StrEqual(group, "ordinary"))
        return definition != DEFIDX_AWP && definition != DEFIDX_SSG08 && definition != DEFIDX_G3SG1
            && definition != DEFIDX_SCAR20 && definition != DEFIDX_AUG && definition != DEFIDX_SG556;
    if (StrEqual(group, "awp"))
        return definition == DEFIDX_AWP;
    if (StrEqual(group, "ssg_08"))
        return definition == DEFIDX_SSG08;
    if (StrEqual(group, "g3sg1"))
        return definition == DEFIDX_G3SG1;
    if (StrEqual(group, "scar-20"))
        return definition == DEFIDX_SCAR20;
    if (StrEqual(group, "aug"))
        return definition == DEFIDX_AUG;
    if (StrEqual(group, "sg_553"))
        return definition == DEFIDX_SG556;
    return false;
}

bool DR_OpeningEquipmentMatches(int client, DRRecord record)
{
    if (record.requiresPrimary && !IsValidEntity(GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)))
        return false;
    if (!DR_WeaponGroupMatches(client, record.weaponGroup)
        || (record.requiresC4 && DR_CountWeapon(client, CSWeapon_C4) == 0))
        return false;
    for (int kind = 0; kind < 4; kind++)
        if (DR_CountWeapon(client, DR_GrenadeWeapon(view_as<DRGrenadeKind>(kind), record)) < record.grenades[kind])
            return false;
    return true;
}

bool DR_CanAssign(int client, DRRecord record)
{
    return DR_EligibleOpeningClient(client) && GetClientTeam(client) == record.team
        && GetEntityMoveType(client) != MOVETYPE_LADDER && !DR_OwnsGrenade(client)
        && DR_OpeningEquipmentMatches(client, record) && DR_RecordAvailable(record);
}

int DR_FindOpeningClient(int team, DRRecord role, const bool used[MAXPLAYERS + 1])
{
    int selected;
    float nearest = -1.0;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (used[client] || !DR_IsClient(client) || GetClientTeam(client) != team || !DR_CanAssign(client, role))
            continue;
        float origin[3];
        GetClientAbsOrigin(client, origin);
        float distance = GetVectorDistance(origin, role.origin, true);
        if (nearest < 0.0 || distance < nearest)
        {
            nearest = distance;
            selected = client;
        }
    }
    return selected;
}







void DR_AssignOpening(int team)
{
    if (!DR_FormalRound() || !g_bFreezetimeEnd || g_bBombPlanted || g_DRCatalog == null || g_DRTeamRolled[team])
        return;
    bool pistol = DR_IsPistolRound(GameRules_GetProp("m_totalRoundsPlayed"), g_cvMaxRounds.IntValue,
        GameRules_GetProp("m_nOvertimePlaying") != 0);
    ArrayList groups = new ArrayList(ByteCountToCells(128));
    bool used[MAXPLAYERS + 1];
    for (int i = 0; i < g_DRCatalog.Length; i++)
    {
        DRRecord record;
        g_DRCatalog.GetArray(i, record, sizeof(DRRecord));
        if (record.opening && record.team == team && record.pistol == pistol
            && groups.FindString(record.sourceRound) == -1 && DR_FindOpeningClient(team, record, used) != 0)
            groups.PushString(record.sourceRound);
    }
    g_DRTeamRolled[team] = true;
    if (groups.Length == 0)
    {
        delete groups;
        return;
    }
    int roll = GetRandomInt(0, 99);
    g_DRTeamAccepted[team] = DR_AcceptRoll(roll, DR_OPENING_CHANCE);
    if (g_DRTeamAccepted[team])
        groups.GetString(GetRandomInt(0, groups.Length - 1), g_DRTeamSource[team], sizeof(g_DRTeamSource[]));
    delete groups;
    PrintToServer("[DemoReplay] opening_roll round=%d team=%d roll=%d accepted=%d source=%s",
        g_DRRoundSerial, team, roll, g_DRTeamAccepted[team], g_DRTeamSource[team]);
    if (!g_DRTeamAccepted[team])
        return;
    for (int pass = 0; pass < 2; pass++)
        for (int i = 0; i < g_DRCatalog.Length; i++)
        {
            DRRecord record;
            g_DRCatalog.GetArray(i, record, sizeof(DRRecord));
            int utility;
            for (int kind = 0; kind < 4; kind++) utility += record.grenades[kind];
            if (!record.opening || record.team != team || record.pistol != pistol
                || !StrEqual(record.sourceRound, g_DRTeamSource[team]) || (pass == 0) != (utility > 0))
                continue;
            int client = DR_FindOpeningClient(team, record, used);
            if (client == 0)
            {
                DR_ClearOpeningTeam(team, "opening_assignment_failed");
                return;
            }
            used[client] = true;
            g_DRClient[client].role = i;
            g_DRClient[client].preparing = true;
            g_DRClient[client].consumed = true;
            g_DRClient[client].startedAt = GetGameTime();
            g_DRClient[client].nextMoveAt = 0.0;
            PrintToServer("[DemoReplay] opening_assigned round=%d serial=%d rec=%s",
                g_DRRoundSerial, GetClientSerial(client), record.id);
        }
}

bool DR_HandleOpening(int client, bool enemyVisible)
{
    if (!g_DRClient[client].preparing && !DR_OwnsOpening(client))
        return false;
    int role = g_DRClient[client].role;
    if (role < 0 || role >= g_DRCatalog.Length)
    {
        DR_StopClient(client, "invalid_role");
        return false;
    }
    DRRecord record;
    g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
    if (!DR_IsClient(client) || !DR_FormalRound() || g_bBombPlanted || GetClientTeam(client) != record.team)
    {
        DR_ClearOpeningTeam(record.team, "opening_lifecycle");
        return false;
    }
    // A resumed RunCmd may precede the frame that compensates paused time.
    if (DR_Paused() || g_DRGrenade[client].pauseSince >= 0.0)
        return true;
    if (g_DRClient[client].active)
    {
        if (!DR_MatchesOpeningPlayback(client))
        {
            DR_StopClient(client, "playback_replaced");
            return false;
        }
        if (enemyVisible)
        {
            DR_StopClient(client, "visible_enemy");
            BotEquipBestWeapon(client, true);
            return false;
        }
        return true;
    }
    float now = GetGameTime();
    if (now - g_DRClient[client].startedAt > 12.0 || !DR_OpeningEquipmentMatches(client, record))
    {
        DR_ClearOpeningTeam(record.team, "opening_preparation_failed");
        return false;
    }
    if (now >= g_DRClient[client].nextMoveAt)
    {
        SwitchWeapon(client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE));
        BotMoveTo(client, record.origin, FASTEST_ROUTE);
        g_DRClient[client].nextMoveAt = now + 0.35;
    }
    if (GetVectorDistance(g_fBotOrigin[client], record.origin) < 45.0)
    {
        float eye[3], direction[3], look[3];
        GetClientEyePosition(client, eye);
        GetAngleVectors(record.startAngles, direction, NULL_VECTOR, NULL_VECTOR);
        for (int axis = 0; axis < 3; axis++) look[axis] = eye[axis] + direction[axis] * 1000.0;
        BotSetLookAt(client, "Strategy start", look, PRIORITY_UNINTERRUPTABLE, 0.5, false, 5.0, false);
    }
    DR_TryStartOpening(client);
    return g_DRClient[client].preparing || g_DRClient[client].active;
}

bool DR_IsPrimaryWeapon(CSWeaponID weapon)
{
    switch (weapon)
    {
        case CSWeapon_AK47, CSWeapon_AUG, CSWeapon_AWP, CSWeapon_BIZON, CSWeapon_FAMAS,
            CSWeapon_G3SG1, CSWeapon_GALILAR, CSWeapon_M249, CSWeapon_M4A1, CSWeapon_M4A1_SILENCER,
            CSWeapon_MAC10, CSWeapon_MAG7, CSWeapon_MP5NAVY, CSWeapon_MP7, CSWeapon_MP9,
            CSWeapon_NEGEV, CSWeapon_NOVA, CSWeapon_P90, CSWeapon_SAWEDOFF, CSWeapon_SCAR20,
            CSWeapon_SG556, CSWeapon_SSG08, CSWeapon_UMP45, CSWeapon_XM1014:
            return true;
    }
    return false;
}



CSWeaponID DR_GrenadeWeapon(DRGrenadeKind kind, DRRecord record)
{
    switch (kind)
    {
        case DR_Smoke: return CSWeapon_SMOKEGRENADE;
        case DR_Flash: return CSWeapon_FLASHBANG;
        case DR_HE: return CSWeapon_HEGRENADE;
        case DR_Fire: return record.fireWeapon;
    }
    return CSWeapon_NONE;
}

int DR_CountWeapon(int client, CSWeaponID weaponID)
{
    char alias[64], classname[64];
    CS_WeaponIDToAlias(weaponID, alias, sizeof(alias));
    Format(alias, sizeof(alias), "weapon_%s", alias);
    int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for (int slot = 0; slot < size; slot++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", slot);
        if (!IsValidEntity(weapon))
            continue;
        GetEntityClassname(weapon, classname, sizeof(classname));
        if (!StrEqual(alias, classname))
            continue;
        int ammoType = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
        if (ammoType < 0 || ammoType >= GetEntPropArraySize(client, Prop_Send, "m_iAmmo"))
            return 1;
        return GetEntProp(client, Prop_Send, "m_iAmmo", 4, ammoType);
    }
    return 0;
}





bool DR_IsReserved(int client)
{
    return (DR_OwnsGrenade(client) && g_DRGrenade[client].stage == DR_GrenadeStagePlaying)
        || (client >= 1 && client <= MaxClients && IsClientInGame(client)
            && g_DRClient[client].serial == GetClientSerial(client) && g_DRClient[client].round == g_DRRoundSerial
            && (g_DRClient[client].preparing || DR_OwnsOpening(client)));
}

bool DR_HoldsGrenadePosition(int client)
{
    if (!DR_IsClient(client) || !DR_OwnsGrenade(client)
        || g_DRGrenade[client].stage != DR_GrenadeStageApproaching
        || (GetEntityFlags(client) & FL_ONGROUND) == 0 || DR_VisibleEnemy(client))
        return false;
    TaskType task = GetTask(client);
    if (task == ESCAPE_FROM_BOMB || task == ESCAPE_FROM_FLAMES)
        return false;
    DRRecord record;
    g_DRCatalog.GetArray(g_DRGrenade[client].record, record, sizeof(DRRecord));
    float origin[3];
    GetClientAbsOrigin(client, origin);
    return GetVectorDistance(origin, record.origin, true)
        < DR_GRENADE_START_RADIUS * DR_GRENADE_START_RADIUS;
}







bool DR_Paused()
{
    return GameRules_GetProp("m_bMatchWaitingForResume") != 0
        || GameRules_GetProp("m_bTerroristTimeOutActive") != 0
        || GameRules_GetProp("m_bCTTimeOutActive") != 0;
}

void DR_TryStartOpening(int client)
{
    if (!g_DRClient[client].preparing || !DR_FormalRound() || DR_Paused())
        return;
    int team = GetClientTeam(client);
    if (!g_DRTeamAccepted[team] || g_DRTeamStarted[team]) return;
    for (int member = 1; member <= MaxClients; member++)
    {
        int role = g_DRClient[member].role;
        if (!g_DRClient[member].preparing || role < 0 || role >= g_DRCatalog.Length) continue;
        DRRecord record;
        g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
        if (record.team != team) continue;
        if (!DR_IsClient(member) || !DR_OpeningEquipmentMatches(member, record))
        {
            DR_ClearOpeningTeam(team, "opening_member_lost");
            return;
        }
        float origin[3], velocity[3];
        GetClientAbsOrigin(member, origin);
        GetEntPropVector(member, Prop_Data, "m_vecAbsVelocity", velocity);
        velocity[2] = 0.0;
        if (GetVectorDistance(origin, record.origin) > 45.0 || GetVectorLength(velocity) > 20.0
            || (GetEntityFlags(member) & FL_ONGROUND) == 0)
            return;
    }
    g_DRTeamStarted[team] = true;
    for (int member = 1; member <= MaxClients; member++)
    {
        int role = g_DRClient[member].role;
        if (!g_DRClient[member].preparing || role < 0 || role >= g_DRCatalog.Length) continue;
        DRRecord record;
        g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
        if (record.team != team) continue;
        g_DRClient[member].active = true;
        g_DRClient[member].preparing = false;
        g_DRClient[member].firstFrame = false;
        g_DRClient[member].startedAt = GetGameTime();
        BMError result = BotMimic_PlayRecordFromFileEx(member, record.path, record.freezeFrame, BMPlayback_Legacy);
        PrintToServer("[DemoReplay] opening_start_requested round=%d serial=%d rec=%s start=%d result=%d",
            g_DRRoundSerial, GetClientSerial(member), record.id, record.freezeFrame, result);
        if (result != BM_NoError || !DR_MatchesOpeningPlayback(member))
        {
            DR_ClearOpeningTeam(team, "opening_start_failed");
            return;
        }
    }
}

void DR_UpdateGrenadePause(bool paused)
{
    float now = GetGameTime();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (paused)
        {
            if (g_DRGrenade[client].pauseSince < 0.0)
                g_DRGrenade[client].pauseSince = now;
            continue;
        }
        if (g_DRGrenade[client].pauseSince < 0.0)
            continue;
        float elapsed = now - g_DRGrenade[client].pauseSince;
        g_DRGrenade[client].pauseSince = -1.0;
        if (g_DRGrenade[client].stage != DR_GrenadeStageIdle)
        {
            g_DRGrenade[client].assignedAt += elapsed;
            g_DRGrenade[client].progressSince += elapsed;
            g_DRGrenade[client].nextMoveAt += elapsed;
            if (g_DRGrenade[client].stage == DR_GrenadeStagePlaying)
                g_DRGrenade[client].startedAt += elapsed;
        }
        if (g_DRNextGrenadeScan[client] > 0.0)
            g_DRNextGrenadeScan[client] += elapsed;
        if (g_DRClient[client].preparing || (g_DRClient[client].active && !g_DRClient[client].firstFrame))
        {
            g_DRClient[client].startedAt += elapsed;
            g_DRClient[client].nextMoveAt += elapsed;
        }
    }
}

public void OnGameFrame()
{
    if (!g_DRRoundActive || g_DRCatalog == null) return;
    bool paused = DR_Paused();
    DR_UpdateGrenadePause(paused);
    DR_UpdateEffects();
    if (paused) return;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_DRClient[client].active && !g_DRClient[client].firstFrame
            && GetGameTime() - g_DRClient[client].startedAt > 0.5)
        {
            int role = g_DRClient[client].role;
            DRRecord record;
            g_DRCatalog.GetArray(role, record, sizeof(DRRecord));
            DR_ClearOpeningTeam(record.team, "first_frame_timeout");
        }
    }
}



bool DR_VisibleEnemy(int client)
{
    int enemy = BotGetEnemy(client);
    return enemy >= 1 && enemy <= MaxClients && IsClientInGame(enemy) && IsPlayerAlive(enemy)
        && (GetClientTeam(enemy) == CS_TEAM_T || GetClientTeam(enemy) == CS_TEAM_CT)
        && GetClientTeam(enemy) != GetClientTeam(client)
        && GetEntData(client, g_iEnemyVisibleOffset, 1) != 0;
}



Action DR_BeforeFrame(int client)
{
    if (!DR_OwnsOpening(client)) return Plugin_Continue;
    if (!DR_IsClient(client) || !DR_FormalRound() || g_bBombPlanted)
    {
        DR_OpeningLifecycle(client, "opening_lifecycle");
        return Plugin_Stop;
    }
    return DR_Paused() ? Plugin_Changed : Plugin_Continue;
}

public Action BotMimic_OnPlayerMimicFrame(int client, int frameIndex, const float recordedOrigin[3], const float movement[3])
{
    if (g_DRGrenade[client].stage == DR_GrenadeStagePlaying)
    {
        if (!DR_MatchesGrenadePlayback(client))
        {
            DR_StopGrenade(client, "playback_replaced");
            return Plugin_Continue;
        }
        if (DR_Paused())
            return Plugin_Changed;
        DR_UpdateGrenade(client);
        if (g_DRGrenade[client].stage == DR_GrenadeStageIdle)
            return Plugin_Stop;
    }
    return DR_BeforeFrame(client);
}

public void BotMimic_OnPlayerMimicLoops(int client)
{
    if (DR_MatchesGrenadePlayback(client) && !g_DRGrenade[client].firstFrame)
    {
        g_DRGrenade[client].firstFrame = true;
        PrintToServer("[DemoReplay] grenade_first_frame round=%d serial=%d reservation=%d",
            g_DRRoundSerial, g_DRGrenade[client].serial, g_DRGrenade[client].reservation);
    }
    if (DR_OwnsOpening(client))
    {
        g_DRClient[client].firstFrame = true;
        PrintToServer("[DemoReplay] opening_first_frame round=%d serial=%d", g_DRRoundSerial, g_DRClient[client].serial);
    }
}

public void BotMimic_OnPlayerStopsMimicing(int client, char[] name, char[] category, char[] path)
{
    DR_StopGrenade(client, "playback_stopped", false);
    if (g_DRClient[client].active)
    {
        if (!DR_IsClient(client)) DR_OpeningLifecycle(client, "client_lifecycle");
        else DR_StopClient(client, "playback_stopped", false);
    }
}

void DR_ResetClient(int client, bool disconnect = false)
{
    if (client < 1 || client > MaxClients)
        return;
    DR_OpeningLifecycle(client, "client_lifecycle");
    DR_StopGrenade(client, "client_lifecycle");
    int serial = !disconnect && IsClientInGame(client) ? GetClientSerial(client) : 0;
    if (serial != g_DRClient[client].serial || g_DRClient[client].round != g_DRRoundSerial)
        g_DRClient[client].consumed = false;
    g_DRClient[client].serial = serial;
    g_DRClient[client].round = g_DRRoundSerial;
    g_DRNextGrenadeScan[client] = 0.0;
}

bool DR_GrenadeIdle(int client)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(weapon))
        return true;
    return !(HasEntProp(weapon, Prop_Send, "m_bPinPulled") && GetEntProp(weapon, Prop_Send, "m_bPinPulled") != 0)
        && !(HasEntProp(weapon, Prop_Send, "m_fThrowTime") && GetEntPropFloat(weapon, Prop_Send, "m_fThrowTime") > 0.0);
}

bool DR_GrenadePhaseAllowed(int client, bool continuing = false)
{
    if (!DR_IsClient(client) || !DR_FormalRound() || !g_bFreezetimeEnd || DR_Paused()
        || (DR_IsReserved(client) && !DR_OwnsGrenade(client))
        || ShouldSaveInsteadOfRetake(client))
        return false;
    TaskType task = GetTask(client);
    if (task == PLANT_BOMB || GetEntProp(client, Prop_Send, "m_bIsDefusing"))
        return false;
    if (g_bBombPlanted && GetClientTeam(client) == CS_TEAM_CT
        && (task == DEFUSE_BOMB || task == FIND_TICKING_BOMB || task == GUARD_BOMB_DEFUSER))
        return false;
    if (BotMimic_IsPlayerMimicing(client) && (!continuing || !DR_MatchesGrenadePlayback(client)))
        return false;
    if ((!continuing || !g_DRGrenade[client].firstFrame) && !DR_GrenadeIdle(client))
        return false;
    if (g_DRGrenade[client].stage != DR_GrenadeStagePlaying)
        return true;
    if (task == ESCAPE_FROM_BOMB || task == ESCAPE_FROM_FLAMES || GetEntityMoveType(client) == MOVETYPE_LADDER)
        return false;
    g_iTarget[client] = BotGetEnemy(client);
    for (int axis = 0; axis < 3; axis++)
        g_fTargetPos[client][axis] = 0.0;
    int enemy = g_iTarget[client];
    if (!IsValidClient(enemy) || !IsPlayerAlive(enemy) || GetClientTeam(enemy) == GetClientTeam(client))
        return true;
    // Reserved commands skip ProcessCombat, so refresh the state used by aim selection here.
    GetClientAbsOrigin(client, g_fBotOrigin[client]);
    g_iActiveWeapon[client] = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    SelectBestTargetPos(client, g_fTargetPos[client]);
    return g_fTargetPos[client][2] == 0.0;
}

bool DR_OwnsGrenade(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client)
        && g_DRGrenade[client].stage != DR_GrenadeStageIdle
        && g_DRGrenade[client].serial == GetClientSerial(client)
        && g_DRGrenade[client].round == g_DRRoundSerial;
}

bool DR_MatchesGrenadePlayback(int client)
{
    if (!DR_OwnsGrenade(client) || g_DRGrenade[client].stage != DR_GrenadeStagePlaying
        || !BotMimic_IsPlayerMimicing(client))
        return false;
    DRRecord record;
    g_DRCatalog.GetArray(g_DRGrenade[client].record, record, sizeof(DRRecord));
    char path[PLATFORM_MAX_PATH];
    BotMimic_GetRecordPlayerMimics(client, path, sizeof(path));
    return StrEqual(path, record.path);
}

bool DR_RecordAvailable(DRRecord record)
{
    ArrayList loaded = BotMimic_GetLoadedRecordList();
    char category[64];
    BMFileHeader header;
    return FileExists(record.path) && loaded != null && loaded.FindString(record.path) != -1
        && BotMimic_GetFileCategory(record.path, category, sizeof(category))
        && StrEqual(category, record.category)
        && BotMimic_GetFileHeaders(record.path, header, sizeof(BMFileHeader)) == BM_NoError
        && header.BMFH_tickCount > 0 && header.BMFH_tickCount == record.frames
        && (!record.opening || (record.freezeFrame >= 0 && record.freezeFrame < header.BMFH_tickCount));
}

void DR_TryGrenade(int client)
{
    if (!DR_IsClient(client) || g_DRCatalog == null || g_DRGrenade[client].stage != DR_GrenadeStageIdle)
        return;
    float now = GetGameTime();
    if (now < g_DRNextGrenadeScan[client] || !DR_GrenadePhaseAllowed(client)) return;
    g_DRNextGrenadeScan[client] = now + 1.0;
    int team = GetClientTeam(client), selected = -1;
    float origin[3], selectedDistance;
    char selectedID[64];
    GetClientAbsOrigin(client, origin);
    for (int kind = 0; kind < 4; kind++)
    {
        ArrayList candidates = g_DRGrenadeIndex[team][kind];
        if (candidates == null) continue;
        for (int i = 0; i < candidates.Length; i++)
        {
            int index = candidates.Get(i);
            DRRecord record;
            g_DRCatalog.GetArray(index, record, sizeof(DRRecord));
            float distance = GetVectorDistance(origin, record.origin, true);
            if ((selected != -1 && distance > selectedDistance) || DR_CountWeapon(client, record.targetWeapon) == 0
                || DR_EffectBlocked(record.team, record.kind, record.target))
                continue;
            if (!DR_RecordAvailable(record))
            {
                PrintToServer("[DemoReplay] grenade_unavailable rec=%s reason=core_catalog", record.id);
                continue;
            }
            if (selected != -1 && distance == selectedDistance && strcmp(record.id, selectedID) >= 0)
                continue;
            selected = index;
            selectedDistance = distance;
            strcopy(selectedID, sizeof(selectedID), record.id);
        }
    }
    if (selected != -1) DR_AssignGrenade(client, selected);
}

int DR_FindEffect(int id)
{
    if (g_DREffects == null)
        return -1;
    for (int index = 0; index < g_DREffects.Length; index++)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (effect.live && effect.id == id)
            return index;
    }
    return -1;
}

bool DR_EffectBlocked(int team, DRGrenadeKind kind, const float target[3], int ignoreReservation = 0)
{
    if (g_DREffects == null)
        return false;
    float now = GetGameTime();
    for (int index = 0; index < g_DREffects.Length; index++)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (!effect.live || effect.round != g_DRRoundSerial || (!effect.sourceKnown && effect.phase != DR_EffectActive))
            continue;
        if (effect.id == ignoreReservation && effect.phase == DR_EffectSelected)
        {
            int owner = GetClientFromSerial(effect.ownerSerial);
            if (DR_OwnsGrenade(owner) && g_DRGrenade[owner].reservation == ignoreReservation)
                continue;
        }
        float distance = DR_EffectBlockDistanceSquared(GetVectorDistance(target, effect.target, true),
            GetVectorDistance(target, effect.actual, true), effect.sourceKnown, effect.phase == DR_EffectActive);
        if (DR_ShouldBlockEffect(team, view_as<int>(kind), effect.team, view_as<int>(effect.kind), distance,
            effect.phase != DR_EffectActive, effect.expiresAt, now))
            return true;
    }
    return false;
}

void DR_CaptureEffectProjectile(int index)
{
    if (index == -1 || !g_DRRoundActive)
        return;
    DREffect effect;
    g_DREffects.GetArray(index, effect, sizeof(DREffect));
    if (!effect.live || effect.round != g_DRRoundSerial || effect.phase != DR_EffectSelected)
        return;
    int owner = GetClientFromSerial(effect.ownerSerial);
    static const char classes[][] = {
        "smokegrenade_projectile", "flashbang_projectile",
        "hegrenade_projectile", "molotov_projectile"
    };
    int entity = -1;
    while ((entity = FindEntityByClassname(entity, classes[view_as<int>(effect.kind)])) != -1)
        if ((owner > 0 && GetEntPropEnt(entity, Prop_Send, "m_hThrower") == owner)
            || (effect.ownerHandle != 0 && effect.ownerHandle != INVALID_ENT_REFERENCE
                && GetEntProp(entity, Prop_Send, "m_hThrower") == effect.ownerHandle))
            DR_OnProjectileCreated(entity);
}

void DR_CaptureGrenadeProjectile(int client)
{
    if (!DR_OwnsGrenade(client) || g_DRGrenade[client].stage != DR_GrenadeStagePlaying)
        return;
    DR_CaptureEffectProjectile(DR_FindEffect(g_DRGrenade[client].reservation));
}

void DR_StopGrenade(int client, const char[] reason, bool stopMimic = true)
{
    if (client < 1 || client > MaxClients || g_DRGrenade[client].stage == DR_GrenadeStageIdle)
        return;
    bool stopPlayback = stopMimic && DR_MatchesGrenadePlayback(client);
    int equippedWeaponRef = g_DRGrenade[client].equippedWeaponRef;
    bool restoreWeapon = DR_OwnsGrenade(client) && DR_IsClient(client) && !DR_OwnsOpening(client)
        && equippedWeaponRef != INVALID_ENT_REFERENCE
        && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == EntRefToEntIndex(equippedWeaponRef)
        && DR_GrenadeIdle(client) && (!BotMimic_IsPlayerMimicing(client) || stopPlayback);
    int activeWeapon = DR_OwnsGrenade(client) ? GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") : -1;
    bool pendingAction = IsValidEntity(activeWeapon) && HasEntProp(activeWeapon, Prop_Send, "m_bPinPulled")
        && (!BotMimic_IsPlayerMimicing(client) || stopPlayback || !stopMimic)
        && (stopPlayback || EntIndexToEntRef(activeWeapon) == equippedWeaponRef) && !DR_GrenadeIdle(client);
    DR_CaptureGrenadeProjectile(client);
    DRGrenadeStage stage = g_DRGrenade[client].stage;
    g_DRGrenade[client].stage = DR_GrenadeStageIdle;
    g_DRGrenade[client].equippedWeaponRef = INVALID_ENT_REFERENCE;
    int index = DR_FindEffect(g_DRGrenade[client].reservation);
    if (index != -1)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (effect.phase == DR_EffectSelected)
        {
            if (pendingAction)
            {
                effect.pendingWeaponRef = EntIndexToEntRef(activeWeapon);
                effect.ownerHandle = GetEntProp(activeWeapon, Prop_Send, "m_hOwnerEntity");
                effect.throwCommitted = GetEntPropFloat(activeWeapon, Prop_Send, "m_fThrowTime") > 0.0;
                effect.expiresAt = GetGameTime() + 0.25;
            }
            else
                effect.live = false;
            g_DREffects.SetArray(index, effect, sizeof(DREffect));
        }
    }
    if (stopPlayback)
        BotMimic_StopPlayerMimic(client);
    if (restoreWeapon && DR_IsClient(client) && !BotMimic_IsPlayerMimicing(client)
        && GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == EntRefToEntIndex(equippedWeaponRef)
        && DR_GrenadeIdle(client))
        BotEquipBestWeapon(client, true);
    PrintToServer("[DemoReplay] grenade_stop round=%d serial=%d reservation=%d stage=%d reason=%s",
        g_DRRoundSerial, g_DRGrenade[client].serial, g_DRGrenade[client].reservation, stage, reason);
}

void DR_AssignGrenade(int client, int recordIndex)
{
    DRRecord record;
    g_DRCatalog.GetArray(recordIndex, record, sizeof(DRRecord));
    if (!DR_GrenadePhaseAllowed(client) || !DR_RecordAvailable(record)
        || DR_CountWeapon(client, record.targetWeapon) == 0
        || DR_EffectBlocked(record.team, record.kind, record.target))
        return;
    if (g_DREffects == null)
        g_DREffects = new ArrayList(sizeof(DREffect));
    DREffect effect;
    effect.id = ++g_DRNextEffect;
    effect.live = true;
    effect.round = g_DRRoundSerial;
    effect.ownerSerial = GetClientSerial(client);
    effect.team = record.team;
    effect.kind = record.kind;
    effect.phase = DR_EffectSelected;
    effect.sourceKnown = true;
    effect.projectileRef = INVALID_ENT_REFERENCE;
    effect.infernoRef = INVALID_ENT_REFERENCE;
    strcopy(effect.recordID, sizeof(effect.recordID), record.id);
    for (int axis = 0; axis < 3; axis++)
        effect.target[axis] = record.target[axis];
    g_DREffects.PushArray(effect, sizeof(DREffect));
    g_DRGrenade[client].stage = DR_GrenadeStageApproaching;
    g_DRGrenade[client].firstFrame = false;
    g_DRGrenade[client].serial = GetClientSerial(client);
    g_DRGrenade[client].round = g_DRRoundSerial;
    g_DRGrenade[client].record = recordIndex;
    g_DRGrenade[client].reservation = effect.id;
    g_DRGrenade[client].equippedWeaponRef = INVALID_ENT_REFERENCE;
    g_DRGrenade[client].assignedAt = GetGameTime();
    g_DRGrenade[client].progressSince = GetGameTime();
    GetClientAbsOrigin(client, g_DRGrenade[client].progressOrigin);
    g_DRGrenade[client].nextMoveAt = 0.0;
    g_DRGrenade[client].startedAt = 0.0;
    PrintToServer("[DemoReplay] grenade_selected round=%d serial=%d kind=%d reservation=%d rec=%s source=%.3f,%.3f,%.3f tick=%d",
        g_DRRoundSerial, GetClientSerial(client), view_as<int>(record.kind),
        effect.id, record.id, effect.target[0], effect.target[1], effect.target[2], GetGameTickCount());
    PrintToServer("[DemoReplay] grenade_approach_started round=%d serial=%d rec=%s",
        g_DRRoundSerial, GetClientSerial(client), record.id);
}

bool DR_GrenadeWeaponReady(int client, CSWeaponID weaponID)
{
    if (DR_VisibleEnemy(client))
        return false;
    char alias[64];
    CS_WeaponIDToAlias(weaponID, alias, sizeof(alias));
    Format(alias, sizeof(alias), "weapon_%s", alias);
    int weapon = eItems_FindWeaponByClassName(client, alias);
    if (!IsValidEntity(weapon))
        return false;
    if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)
    {
        SDKCall(g_hSwitchWeaponCall, client, weapon, 0);
        if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == weapon)
            g_DRGrenade[client].equippedWeaponRef = EntIndexToEntRef(weapon);
        return false;
    }
    g_DRGrenade[client].equippedWeaponRef = EntIndexToEntRef(weapon);
    float now = GetGameTime();
    return GetEntPropFloat(client, Prop_Send, "m_flNextAttack") <= now
        && GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack") <= now;
}

void DR_UpdateGrenade(int client)
{
    if (g_DRGrenade[client].stage == DR_GrenadeStageIdle)
        return;
    if (!DR_OwnsGrenade(client) || !DR_IsClient(client) || !DR_FormalRound())
    {
        DR_StopGrenade(client, "lifecycle_or_phase");
        return;
    }
    if (DR_Paused())
        return;
    if (g_DRGrenade[client].stage == DR_GrenadeStagePlaying && !DR_MatchesGrenadePlayback(client))
    {
        DR_StopGrenade(client, "playback_replaced");
        return;
    }
    if (!DR_GrenadePhaseAllowed(client, true))
    {
        PrintToServer("[DemoReplay] grenade_phase_state round=%d serial=%d stage=%d task=%d planted=%d movetype=%d defusing=%d enemy=%d target_z=%.3f external=%d tick=%d",
            g_DRRoundSerial, GetClientSerial(client), g_DRGrenade[client].stage, GetTask(client), g_bBombPlanted,
            GetEntityMoveType(client), GetEntProp(client, Prop_Send, "m_bIsDefusing"), g_iTarget[client], g_fTargetPos[client][2],
            BotMimic_IsPlayerMimicing(client) && !DR_MatchesGrenadePlayback(client), GetGameTickCount());
        DR_StopGrenade(client, "phase_or_task");
        return;
    }
    DRRecord record;
    g_DRCatalog.GetArray(g_DRGrenade[client].record, record, sizeof(DRRecord));
    if (!DR_RecordAvailable(record))
    {
        DR_StopGrenade(client, "core_catalog");
        return;
    }
    if (DR_CountWeapon(client, record.targetWeapon) == 0)
    {
        DR_CaptureGrenadeProjectile(client);
        int index = DR_FindEffect(g_DRGrenade[client].reservation);
        bool committed = false;
        if (index != -1)
        {
            DREffect effect;
            g_DREffects.GetArray(index, effect, sizeof(DREffect));
            committed = effect.phase != DR_EffectSelected;
        }
        if (g_DRGrenade[client].stage != DR_GrenadeStagePlaying
            || !g_DRGrenade[client].firstFrame || (!committed && DR_GrenadeIdle(client)))
        {
            DR_StopGrenade(client, "inventory_lost");
            return;
        }
    }
    if (!g_DRGrenade[client].firstFrame
        && DR_EffectBlocked(record.team, record.kind, record.target, g_DRGrenade[client].reservation))
    {
        DR_StopGrenade(client, "effect_blocked");
        return;
    }
    float now = GetGameTime();
    if (g_DRGrenade[client].stage == DR_GrenadeStagePlaying)
    {
        if (!g_DRGrenade[client].firstFrame && now - g_DRGrenade[client].startedAt > 0.5)
            DR_StopGrenade(client, "first_frame_timeout");
        return;
    }
    float origin[3], velocity[3];
    GetClientAbsOrigin(client, origin);
    if (GetVectorDistance(origin, g_DRGrenade[client].progressOrigin, true) > 64.0)
    {
        Array_Copy(origin, g_DRGrenade[client].progressOrigin, 3);
        g_DRGrenade[client].progressSince = now;
    }
    else if (now - g_DRGrenade[client].progressSince > 5.0)
    {
        DR_StopGrenade(client, "movement_stale");
        return;
    }
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
    velocity[2] = 0.0;
    float distanceSquared = GetVectorDistance(origin, record.origin, true);
    if (distanceSquared >= DR_GRENADE_START_RADIUS * DR_GRENADE_START_RADIUS)
    {
        if (now >= g_DRGrenade[client].nextMoveAt)
        {
            BotMoveTo(client, record.origin, FASTEST_ROUTE);
            g_DRGrenade[client].nextMoveAt = now + 0.35;
        }
        return;
    }
    float eye[3], direction[3], look[3];
    GetClientEyePosition(client, eye);
    GetAngleVectors(record.startAngles, direction, NULL_VECTOR, NULL_VECTOR);
    for (int axis = 0; axis < 3; axis++)
        look[axis] = eye[axis] + direction[axis] * 1000.0;
    BotSetLookAt(client, "Use entity", look, PRIORITY_HIGH, 2.0, false, 3.0, false);
    if (!DR_CanStartGrenade(distanceSquared, GetVectorLength(velocity, true), (GetEntityFlags(client) & FL_ONGROUND) != 0))
        return;
    bool weaponReady = DR_GrenadeWeaponReady(client, record.targetWeapon);
    if (weaponReady && view_as<LookAtSpotState>(GetEntData(client, g_iBotLookAtSpotStateOffset)) == LOOK_AT_SPOT)
        DR_StartGrenade(client, g_DRGrenade[client].record);
}

void DR_StartGrenade(int client, int recordIndex)
{
    DRRecord record;
    g_DRCatalog.GetArray(recordIndex, record, sizeof(DRRecord));
    float origin[3], velocity[3];
    GetClientAbsOrigin(client, origin);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
    velocity[2] = 0.0;
    if (!DR_OwnsGrenade(client) || g_DRGrenade[client].stage != DR_GrenadeStageApproaching
        || !DR_GrenadePhaseAllowed(client, true) || !DR_RecordAvailable(record)
        || DR_CountWeapon(client, record.targetWeapon) == 0
        || DR_EffectBlocked(record.team, record.kind, record.target, g_DRGrenade[client].reservation)
        || !DR_CanStartGrenade(GetVectorDistance(origin, record.origin, true), GetVectorLength(velocity, true),
            (GetEntityFlags(client) & FL_ONGROUND) != 0)
        || view_as<LookAtSpotState>(GetEntData(client, g_iBotLookAtSpotStateOffset)) != LOOK_AT_SPOT)
    {
        DR_StopGrenade(client, "start_state_changed");
        return;
    }
    g_DRGrenade[client].stage = DR_GrenadeStagePlaying;
    g_DRGrenade[client].startedAt = GetGameTime();
    PrintToServer("[DemoReplay] grenade_approach_finished round=%d serial=%d rec=%s elapsed=%.3f speed=%.3f",
        g_DRRoundSerial, GetClientSerial(client), record.id,
        GetGameTime() - g_DRGrenade[client].assignedAt, GetVectorLength(velocity));
    BMError result = BotMimic_PlayRecordFromFileEx(client, record.path, 0, BMPlayback_Legacy, true);
    PrintToServer("[DemoReplay] grenade_start_requested round=%d serial=%d reservation=%d result=%d",
        g_DRRoundSerial, GetClientSerial(client), g_DRGrenade[client].reservation, result);
    if (result != BM_NoError || !DR_MatchesGrenadePlayback(client))
        DR_StopGrenade(client, "start_failed");
}

bool DR_ProjectileKind(const char[] classname, DRGrenadeKind &kind)
{
    if (StrEqual(classname, "smokegrenade_projectile"))
        kind = DR_Smoke;
    else if (StrEqual(classname, "flashbang_projectile"))
        kind = DR_Flash;
    else if (StrEqual(classname, "hegrenade_projectile"))
        kind = DR_HE;
    else if (StrEqual(classname, "molotov_projectile"))
        kind = DR_Fire;
    else
        return false;
    return true;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    DRGrenadeKind kind;
    if (DR_ProjectileKind(classname, kind))
        SDKHook(entity, SDKHook_SpawnPost, DR_ProjectileSpawned);
}

public void DR_ProjectileSpawned(int entity)
{
    DataPack pending = new DataPack();
    pending.WriteCell(EntIndexToEntRef(entity));
    pending.WriteCell(g_DRRoundSerial);
    RequestFrame(DR_ProjectileReady, pending);
}

public void DR_ProjectileReady(any data)
{
    DataPack pending = view_as<DataPack>(data);
    pending.Reset();
    int entity = EntRefToEntIndex(pending.ReadCell());
    int round = pending.ReadCell();
    delete pending;
    if (entity != INVALID_ENT_REFERENCE && round == g_DRRoundSerial)
        DR_OnProjectileCreated(entity);
}

int DR_FindPendingEffect(int ownerHandle, DRGrenadeKind kind)
{
    if (g_DREffects == null || ownerHandle == 0 || ownerHandle == INVALID_ENT_REFERENCE)
        return -1;
    int found = -1;
    for (int index = 0; index < g_DREffects.Length; index++)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (!effect.live || effect.round != g_DRRoundSerial || effect.phase != DR_EffectSelected
            || effect.pendingWeaponRef == 0 || effect.ownerHandle != ownerHandle || effect.kind != kind)
            continue;
        if (found != -1)
            return -1;
        found = index;
    }
    return found;
}

void DR_OnProjectileCreated(int entity)
{
    if (!g_DRRoundActive || !IsValidEntity(entity))
        return;
    char classname[64];
    GetEntityClassname(entity, classname, sizeof(classname));
    DRGrenadeKind kind;
    if (!DR_ProjectileKind(classname, kind))
        return;
    int reference = EntIndexToEntRef(entity);
    if (g_DREffects != null)
    {
        for (int existing = 0; existing < g_DREffects.Length; existing++)
        {
            DREffect tracked;
            g_DREffects.GetArray(existing, tracked, sizeof(DREffect));
            if (tracked.round == g_DRRoundSerial && tracked.projectileRef == reference)
                return;
        }
    }
    int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
    bool validOwner = owner >= 1 && owner <= MaxClients && IsClientInGame(owner);
    if (g_DREffects == null)
        g_DREffects = new ArrayList(sizeof(DREffect));
    int index = -1;
    if (validOwner && g_DRGrenade[owner].stage == DR_GrenadeStagePlaying && DR_OwnsGrenade(owner))
        index = DR_FindEffect(g_DRGrenade[owner].reservation);
    DREffect effect;
    if (index != -1)
    {
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (effect.phase != DR_EffectSelected || effect.kind != kind)
            index = -1;
    }
    if (index == -1)
        index = DR_FindPendingEffect(GetEntProp(entity, Prop_Send, "m_hThrower"), kind);
    if (index != -1)
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
    if (index == -1 && !validOwner)
    {
        PrintToServer("[DemoReplay] projectile_unattributed entity=%d reason=owner", entity);
        return;
    }
    if (index == -1)
    {
        effect.id = ++g_DRNextEffect;
        effect.live = true;
        effect.round = g_DRRoundSerial;
        effect.team = GetClientTeam(owner);
        effect.ownerSerial = GetClientSerial(owner);
        effect.kind = kind;
        effect.infernoRef = INVALID_ENT_REFERENCE;
        effect.sourceKnown = false;
        effect.recordID[0] = '\0';
        index = g_DREffects.PushArray(effect, sizeof(DREffect));
    }
    effect.ownerHandle = GetEntProp(entity, Prop_Send, "m_hThrower");
    effect.thrownAt = GetGameTime();
    effect.phase = DR_EffectFlying;
    effect.projectileRef = EntIndexToEntRef(entity);
    effect.projectileIndex = entity;
    effect.sequence = ++g_DRNextProjectile;
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", effect.lastPosition);
    g_DREffects.SetArray(index, effect, sizeof(DREffect));
    PrintToServer("[DemoReplay] projectile_created round=%d serial=%d team=%d kind=%d reservation=%d ref=%d sequence=%d rec=%s",
        effect.round, effect.ownerSerial, effect.team, view_as<int>(effect.kind), effect.id, effect.projectileRef, effect.sequence, effect.recordID);
}

public void OnEntityDestroyed(int entity)
{
    if (g_DREffects == null)
        return;
    for (int index = 0; index < g_DREffects.Length; index++)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (!effect.live || effect.projectileIndex != entity || effect.destroyedAt > 0.0)
            continue;
        if (IsValidEntity(entity) && EntIndexToEntRef(entity) != effect.projectileRef)
            continue;
        if (IsValidEntity(entity))
            GetEntPropVector(entity, Prop_Send, "m_vecOrigin", effect.lastPosition);
        effect.destroyedAt = GetGameTime();
        g_DREffects.SetArray(index, effect, sizeof(DREffect));
    }
}

void DR_CommitEffect(int index, const float center[3], float startedAt)
{
    DREffect effect;
    g_DREffects.GetArray(index, effect, sizeof(DREffect));
    if (!effect.live || effect.phase == DR_EffectActive)
        return;
    effect.phase = DR_EffectActive;
    effect.effectStartedAt = startedAt;
    effect.expiresAt = startedAt + (effect.kind == DR_Smoke ? 20.0 : (effect.kind == DR_Fire ? 8.0 : 0.1));
    for (int axis = 0; axis < 3; axis++)
        effect.actual[axis] = center[axis];
    g_DREffects.SetArray(index, effect, sizeof(DREffect));
    PrintToServer("[DemoReplay] effect_started round=%d serial=%d team=%d kind=%d reservation=%d sequence=%d time=%.6f expires=%.6f rec=%s target=%.3f,%.3f,%.3f actual=%.3f,%.3f,%.3f",
        effect.round, effect.ownerSerial, effect.team, view_as<int>(effect.kind), effect.id, effect.sequence,
        startedAt, effect.expiresAt, effect.recordID, effect.target[0], effect.target[1], effect.target[2],
        center[0], center[1], center[2]);
}

bool DR_FireCenter(int entity, float center[3])
{
    int count = GetEntProp(entity, Prop_Send, "m_fireCount");
    if (count < 1 || count > 64)
        return false;
    float origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    int burning;
    for (int axis = 0; axis < 3; axis++)
        center[axis] = 0.0;
    for (int point = 0; point < count; point++)
    {
        if (!GetEntProp(entity, Prop_Send, "m_bFireIsBurning", 1, point))
            continue;
        center[0] += origin[0] + float(GetEntProp(entity, Prop_Send, "m_fireXDelta", 4, point));
        center[1] += origin[1] + float(GetEntProp(entity, Prop_Send, "m_fireYDelta", 4, point));
        center[2] += origin[2] + float(GetEntProp(entity, Prop_Send, "m_fireZDelta", 4, point));
        burning++;
    }
    if (!burning)
        return false;
    for (int axis = 0; axis < 3; axis++)
        center[axis] /= float(burning);
    return true;
}

void DR_OnEffectStarted(int entity, int kind)
{
    if (g_DREffects == null || !IsValidEntity(entity) || kind != view_as<int>(DR_Fire))
        return;
    int reference = EntIndexToEntRef(entity);
    for (int index = 0; index < g_DREffects.Length; index++)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (!effect.live || effect.infernoRef != reference || effect.phase == DR_EffectActive)
            continue;
        float center[3];
        if (DR_FireCenter(entity, center))
            DR_CommitEffect(index, center, effect.effectStartedAt);
    }
}

void DR_UpdateEffects()
{
    if (g_DREffects == null)
        return;
    float now = GetGameTime();
    for (int index = 0; index < g_DREffects.Length; index++)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (!effect.live)
            continue;
        if (effect.phase == DR_EffectSelected && effect.pendingWeaponRef != 0)
        {
            DR_CaptureEffectProjectile(index);
            g_DREffects.GetArray(index, effect, sizeof(DREffect));
            if (effect.phase == DR_EffectSelected)
            {
                int weapon = EntRefToEntIndex(effect.pendingWeaponRef);
                if (weapon != INVALID_ENT_REFERENCE && IsValidEntity(weapon)
                    && GetEntProp(weapon, Prop_Send, "m_hOwnerEntity") == effect.ownerHandle)
                {
                    bool pin = GetEntProp(weapon, Prop_Send, "m_bPinPulled") != 0;
                    bool committed = GetEntPropFloat(weapon, Prop_Send, "m_fThrowTime") > 0.0;
                    if (pin || committed)
                    {
                        effect.throwCommitted = effect.throwCommitted || committed;
                        effect.expiresAt = now + 0.25;
                        g_DREffects.SetArray(index, effect, sizeof(DREffect));
                        continue;
                    }
                    if (!effect.throwCommitted)
                        effect.expiresAt = now;
                }
                if (now >= effect.expiresAt)
                {
                    effect.live = false;
                    g_DREffects.SetArray(index, effect, sizeof(DREffect));
                    PrintToServer("[DemoReplay] effect_released round=%d reservation=%d phase=0 time=%.6f",
                        effect.round, effect.id, now);
                }
                continue;
            }
        }
        int projectile = EntRefToEntIndex(effect.projectileRef);
        if (effect.phase == DR_EffectFlying && projectile != INVALID_ENT_REFERENCE && IsValidEntity(projectile))
        {
            GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", effect.lastPosition);
            g_DREffects.SetArray(index, effect, sizeof(DREffect));
            // A disconnected thrower can suppress the event while the smoke still blooms.
            if (effect.kind == DR_Smoke && GetEntProp(projectile, Prop_Send, "m_bDidSmokeEffect"))
            {
                int startedTick = GetEntProp(projectile, Prop_Send, "m_nSmokeEffectTickBegin");
                if (startedTick > 0 && startedTick <= GetGameTickCount())
                {
                    float startedAt = now - float(GetGameTickCount() - startedTick) * GetTickInterval();
                    DR_CommitEffect(index, effect.lastPosition, startedAt);
                    continue;
                }
            }
        }
        int inferno = EntRefToEntIndex(effect.infernoRef);
        if (effect.phase == DR_EffectFlying && inferno != INVALID_ENT_REFERENCE && IsValidEntity(inferno))
        {
            DR_OnEffectStarted(inferno, view_as<int>(DR_Fire));
            continue;
        }
        if ((effect.phase == DR_EffectActive && now >= effect.expiresAt)
            || (effect.phase == DR_EffectFlying && effect.infernoRef != INVALID_ENT_REFERENCE
                && (inferno == INVALID_ENT_REFERENCE || !IsValidEntity(inferno)))
            || (effect.phase == DR_EffectFlying && effect.destroyedAt > 0.0 && now - effect.destroyedAt >= 0.25))
        {
            effect.live = false;
            g_DREffects.SetArray(index, effect, sizeof(DREffect));
            PrintToServer("[DemoReplay] effect_released round=%d reservation=%d phase=%d time=%.6f",
                effect.round, effect.id, view_as<int>(effect.phase), now);
        }
    }
}

void DR_ResetRound()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        DR_StopGrenade(client, "round_reset");
        g_DRGrenade[client].pauseSince = -1.0;
        g_DRNextGrenadeScan[client] = 0.0;
    }
    if (g_DREffects != null)
        g_DREffects.Clear();
}

int DR_NewObservedEffect(int team, int ownerSerial, DRGrenadeKind kind)
{
    if (g_DREffects == null)
        g_DREffects = new ArrayList(sizeof(DREffect));
    DREffect effect;
    effect.id = ++g_DRNextEffect;
    effect.live = true;
    effect.round = g_DRRoundSerial;
    effect.team = team;
    effect.ownerSerial = ownerSerial;
    effect.kind = kind;
    effect.phase = DR_EffectFlying;
    effect.projectileRef = INVALID_ENT_REFERENCE;
    effect.infernoRef = INVALID_ENT_REFERENCE;
    effect.thrownAt = GetGameTime();
    return g_DREffects.PushArray(effect, sizeof(DREffect));
}

int DR_InfernoProjectile(int entity)
{
    float origin[3], position[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    int projectile = -1, reference = INVALID_ENT_REFERENCE;
    while ((projectile = FindEntityByClassname(projectile, "molotov_projectile")) != -1)
    {
        GetEntPropVector(projectile, Prop_Send, "m_vecOrigin", position);
        float dx = origin[0] - position[0], dy = origin[1] - position[1];
        if (dx * dx + dy * dy > 4096.0)
            continue;
        if (reference != INVALID_ENT_REFERENCE)
            return INVALID_ENT_REFERENCE;
        reference = EntIndexToEntRef(projectile);
    }
    return reference;
}

void DR_LinkInferno(int entity, float startedAt = -1.0, int projectileRef = INVALID_ENT_REFERENCE)
{
    if (!IsValidEntity(entity))
        return;
    if (startedAt < 0.0)
        startedAt = GetGameTime();
    int reference = EntIndexToEntRef(entity);
    float origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    int ownerHandle = GetEntProp(entity, Prop_Send, "m_hOwnerEntity");
    int matched = -1, count;
    if (g_DREffects != null)
    {
        for (int index = 0; index < g_DREffects.Length; index++)
        {
            DREffect effect;
            g_DREffects.GetArray(index, effect, sizeof(DREffect));
            if (effect.round == g_DRRoundSerial && effect.infernoRef == reference)
                return;
            bool ownerMatches = ownerHandle != INVALID_ENT_REFERENCE && effect.ownerHandle == ownerHandle;
            bool endedAtEffect = effect.destroyedAt > 0.0 && effect.destroyedAt >= startedAt
                && effect.destroyedAt - startedAt <= GetTickInterval();
            // The effect event precedes projectile destruction. A deferred orphan
            // match requires that destruction at the event tick and a unique source.
            if (!ownerMatches && ownerHandle == INVALID_ENT_REFERENCE && effect.ownerSerial > 0
                && projectileRef != INVALID_ENT_REFERENCE && effect.projectileRef == projectileRef
                && GetClientFromSerial(effect.ownerSerial) == 0 && endedAtEffect)
                ownerMatches = true;
            if (!effect.live || effect.round != g_DRRoundSerial || effect.kind != DR_Fire
                || effect.phase != DR_EffectFlying || effect.infernoRef != INVALID_ENT_REFERENCE
                || !ownerMatches || GetGameTime() - effect.thrownAt > 10.0
                || (!endedAtEffect && GetVectorDistance(origin, effect.lastPosition, true) > 4096.0))
                continue;
            matched = index;
            count++;
        }
    }
    if (count != 1)
    {
        int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        if (owner < 1 || owner > MaxClients || !IsClientInGame(owner) || GetClientTeam(owner) < CS_TEAM_T)
        {
            PrintToServer("[DemoReplay] fire_unattributed entity=%d matches=%d owner_handle=%d", entity, count, ownerHandle);
            return;
        }
        matched = DR_NewObservedEffect(GetClientTeam(owner), GetClientSerial(owner), DR_Fire);
    }
    DREffect effect;
    g_DREffects.GetArray(matched, effect, sizeof(DREffect));
    effect.infernoRef = reference;
    effect.effectStartedAt = startedAt;
    g_DREffects.SetArray(matched, effect, sizeof(DREffect));
}

public void DR_InfernoReady(any data)
{
    DataPack pending = view_as<DataPack>(data);
    pending.Reset();
    int entity = EntRefToEntIndex(pending.ReadCell());
    int round = pending.ReadCell();
    int projectileRef = pending.ReadCell();
    float startedAt = pending.ReadFloat();
    delete pending;
    if (entity != INVALID_ENT_REFERENCE && g_DRRoundActive && round == g_DRRoundSerial)
        DR_LinkInferno(entity, startedAt, projectileRef);
}

public void DR_EffectEvent(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_DRRoundActive)
        return;
    int entity = event.GetInt("entityid");
    if (StrEqual(name, "inferno_startburn"))
    {
        if (!IsValidEntity(entity))
            return;
        int projectileRef = INVALID_ENT_REFERENCE;
        if (GetEntProp(entity, Prop_Send, "m_hOwnerEntity") == INVALID_ENT_REFERENCE)
        {
            projectileRef = DR_InfernoProjectile(entity);
            if (projectileRef == INVALID_ENT_REFERENCE)
            {
                PrintToServer("[DemoReplay] fire_unattributed entity=%d reason=projectile_identity", entity);
                return;
            }
        }
        DataPack pending = new DataPack();
        pending.WriteCell(EntIndexToEntRef(entity));
        pending.WriteCell(g_DRRoundSerial);
        pending.WriteCell(projectileRef);
        pending.WriteFloat(GetGameTime());
        RequestFrame(DR_InfernoReady, pending);
        return;
    }
    DRGrenadeKind kind = DR_HE;
    if (StrEqual(name, "smokegrenade_detonate"))
        kind = DR_Smoke;
    else if (StrEqual(name, "flashbang_detonate"))
        kind = DR_Flash;
    int matched = -1;
    if (g_DREffects != null)
    {
        for (int index = 0; index < g_DREffects.Length; index++)
        {
            DREffect effect;
            g_DREffects.GetArray(index, effect, sizeof(DREffect));
            if (!effect.live || effect.round != g_DRRoundSerial || effect.kind != kind
                || effect.phase != DR_EffectFlying || effect.projectileIndex != entity)
                continue;
            if (IsValidEntity(entity) && EntIndexToEntRef(entity) != effect.projectileRef)
                continue;
            if (!IsValidEntity(entity) && (effect.destroyedAt <= 0.0 || GetGameTime() - effect.destroyedAt > 0.1))
                continue;
            matched = index;
            break;
        }
    }
    if (matched == -1)
    {
        int owner = GetClientOfUserId(event.GetInt("userid"));
        if (owner < 1 || !IsClientInGame(owner) || GetClientTeam(owner) < CS_TEAM_T)
        {
            PrintToServer("[DemoReplay] effect_unattributed entity=%d kind=%d", entity, view_as<int>(kind));
            return;
        }
        matched = DR_NewObservedEffect(GetClientTeam(owner), GetClientSerial(owner), kind);
    }
    float center[3];
    center[0] = event.GetFloat("x");
    center[1] = event.GetFloat("y");
    center[2] = event.GetFloat("z");
    DR_CommitEffect(matched, center, GetGameTime());
}
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
    int prepareFrame;
    float origin[3];
    float target[3];
    bool requiresArmor;
    bool helmet;
    bool defuser;
    bool requiresPrimary;
    bool requiresC4;
    int grenades[4];
    CSWeaponID fireWeapon;
    CSWeaponID targetWeapon;
    DRGrenadeKind kind;
    float retryAfter;
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
    bool preparationSent;
    int preparedRole;
    float preparedAt;
    float startedAt;
    float progressSince;
    float actualProgressOrigin[3];
    float referenceProgressOrigin[3];
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
    float startedAt;
    float assignedAt;
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
DROpportunity g_DROpportunity[MAXPLAYERS + 1][4];
DRGrenadePlayback g_DRGrenade[MAXPLAYERS + 1];
ArrayList g_DRUsedRoles;
DRClient g_DRClient[MAXPLAYERS + 1];
bool g_DRBuying[MAXPLAYERS + 1];
bool g_DRIssuingMove[MAXPLAYERS + 1];
int g_DRRoundSerial;
bool g_DRRoundActive;
bool g_DRTeamRolled[4];
bool g_DRTeamAccepted[4];
char g_DRTeamSource[4][128];
float g_DRNextScan;

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

void DR_StopClient(int client, const char[] reason)
{
    if (client < 1 || client > MaxClients)
        return;
    bool active = g_DRClient[client].active;
    g_DRClient[client].active = false;
    g_DRClient[client].preparing = false;
    g_DRClient[client].role = -1;
    g_DRClient[client].progressSince = 0.0;
    if (active)
    {
        g_DRClient[client].consumed = true;
        if (IsClientInGame(client) && BotMimic_IsPlayerMimicing(client))
            BotMimic_StopPlayerMimic(client);
    }
    if (active)
        PrintToServer("[DemoReplay] opening_stop round=%d serial=%d reason=%s", g_DRRoundSerial, g_DRClient[client].serial, reason);
}

void DR_OnRoundStart()
{
    DR_ResetRound();
    g_DRRoundSerial++;
    g_DRNextScan = 0.0;
    g_DRRoundActive = true;
    if (g_DRUsedRoles == null)
        g_DRUsedRoles = new ArrayList(ByteCountToCells(64));
    g_DRUsedRoles.Clear();
    for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++)
    {
        g_DRTeamRolled[team] = false;
        g_DRTeamAccepted[team] = false;
        g_DRTeamSource[team][0] = '\0';
    }
    for (int client = 1; client <= MaxClients; client++)
    {
        DR_StopClient(client, "round_reset");
        g_DRClient[client].consumed = false;
        g_DRClient[client].preparationSent = false;
        g_DRClient[client].preparedRole = -1;
        g_DRBuying[client] = false;
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
        || catalog.GetNum("opening_chance") != DR_OPENING_CHANCE
        || catalog.GetNum("grenade_chance") != DR_GRENADE_CHANCE
        || catalog.GetNum("minimum_survival_ticks") != 3840)
    {
        delete catalog;
        LogError("[DemoReplay] catalog contract mismatch map=%s", map);
        return false;
    }
    bool valid = true;
    if (catalog.JumpToKey("records") && catalog.GotoFirstSubKey())
    {
        do
        {
            if (catalog.GetNum("enabled") != 1)
                continue;
            DRRecord record;
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
            {
                valid = false;
                break;
            }
            BuildPath(Path_SM, record.path, sizeof(record.path), "data/%s", relative);
            if (!FileExists(record.path))
            {
                valid = false;
                break;
            }
            catalog.GetString("round_uid", record.sourceRound, sizeof(record.sourceRound));
            catalog.GetString("weapon_group", record.weaponGroup, sizeof(record.weaponGroup));
            catalog.GetVector("origin", record.origin);
            catalog.GetVector("target_center", record.target);
            record.frames = catalog.GetNum("frame_count");
            record.freezeFrame = catalog.GetNum("freeze_end_frame", -1);
            record.prepareFrame = catalog.GetNum("prepare_frame");
            int armor = catalog.GetNum("armor");
            record.requiresArmor = armor > 0;
            record.helmet = catalog.GetNum("helmet") != 0;
            record.defuser = catalog.GetNum("defuser") != 0;
            record.targetWeapon = view_as<CSWeaponID>(catalog.GetNum("target_weapon"));
            catalog.GetString("kind", kind, sizeof(kind));
            if (StrEqual(kind, "smoke"))
                record.kind = DR_Smoke;
            else if (StrEqual(kind, "flash"))
                record.kind = DR_Flash;
            else if (StrEqual(kind, "he"))
                record.kind = DR_HE;
            else
                record.kind = DR_Fire;
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
                if (catalog.GetNum("53") > 0)
                    record.fireWeapon = CSWeapon_INCGRENADE;
                else if (catalog.GetNum("51") > 0)
                    record.fireWeapon = CSWeapon_MOLOTOV;
                catalog.GoBack();
            }
            if (record.frames <= 0 || record.sourceRound[0] == '\0'
                || (record.opening && (record.freezeFrame < 0 || record.freezeFrame >= record.frames
                    || record.prepareFrame < 0 || record.prepareFrame > record.freezeFrame))
                || (!record.opening && StrContains(record.category, "grenade_") != 0))
            {
                valid = false;
                break;
            }
            char side[4], expectedCategory[64];
            strcopy(side, sizeof(side), record.team == CS_TEAM_CT ? "ct" : "t");
            if (record.opening)
                Format(expectedCategory, sizeof(expectedCategory), "opening_%s_%s", side, record.pistol ? "pistol" : "nonpistol");
            else
                Format(expectedCategory, sizeof(expectedCategory), "grenade_%s_%s", side, kind);
            int total;
            for (int type = 0; type < 4; type++)
            {
                if (record.grenades[type] < 0 || record.grenades[type] > (type == view_as<int>(DR_Flash) ? 2 : 1))
                    valid = false;
                total += record.grenades[type];
            }
            if (!StrEqual(record.category, expectedCategory) || armor < 0 || armor > 1
                || total > 4 || (record.defuser && record.team != CS_TEAM_CT)
                || (record.opening && record.id[0] != 'o')
                || (!record.opening && (record.id[0] != 'g' || (!StrEqual(kind, "smoke") && !StrEqual(kind, "flash")
                    && !StrEqual(kind, "he") && !StrEqual(kind, "fire")))))
                valid = false;
            if (!valid)
                break;
            int recordIndex = g_DRCatalog.PushArray(record, sizeof(DRRecord));
            if (!record.opening)
                g_DRGrenadeIndex[record.team][view_as<int>(record.kind)].Push(recordIndex);
        }
        while (catalog.GotoNextKey());
    }
    delete catalog;
    if (!valid)
    {
        g_DRCatalog.Clear();
        for (int team = CS_TEAM_T; team <= CS_TEAM_CT; team++)
            for (int kindIndex = 0; kindIndex < 4; kindIndex++)
                g_DRGrenadeIndex[team][kindIndex].Clear();
        LogError("[DemoReplay] catalog rejected map=%s", map);
        return false;
    }
    PrintToServer("[DemoReplay] catalog_loaded map=%s enabled=%d", map, g_DRCatalog.Length);
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

bool DR_CanAssign(int client, DRRecord record)
{
    float origin[3];
    GetClientAbsOrigin(client, origin);
    return DR_EligibleOpeningClient(client) && GetClientTeam(client) == record.team
        && GetVectorDistance(origin, record.origin) <= DR_OPENING_START_RADIUS
        && DR_WeaponGroupMatches(client, record.weaponGroup) && DR_CanPrepare(client, record);
}

void DR_PrepareOpening(int team)
{
    if (!DR_FormalRound() || g_bFreezetimeEnd || g_bBombPlanted || g_DRCatalog == null)
        return;
    if (g_DRTeamRolled[team] && !g_DRTeamAccepted[team])
        return;
    bool pistol = DR_IsPistolRound(GameRules_GetProp("m_totalRoundsPlayed"), g_cvMaxRounds.IntValue,
        GameRules_GetProp("m_nOvertimePlaying") != 0);
    int clients[5], clientCount;
    for (int client = 1; client <= MaxClients && clientCount < 5; client++)
        if (DR_EligibleOpeningClient(client) && GetClientTeam(client) == team)
            clients[clientCount++] = client;
    if (clientCount == 0)
        return;
    ArrayList groups = new ArrayList(ByteCountToCells(128));
    for (int i = 0; i < g_DRCatalog.Length; i++)
    {
        DRRecord record;
        g_DRCatalog.GetArray(i, record, sizeof(DRRecord));
        if (!record.opening || record.team != team || record.pistol != pistol
            || g_DRUsedRoles.FindString(record.id) != -1)
            continue;
        for (int bot = 0; bot < clientCount; bot++)
        {
            if (DR_CanAssign(clients[bot], record))
            {
                if (groups.FindString(record.sourceRound) == -1)
                    groups.PushString(record.sourceRound);
                break;
            }
        }
    }
    if (groups.Length == 0)
    {
        delete groups;
        return;
    }
    if (!g_DRTeamRolled[team])
    {
        int roll = GetRandomInt(0, 99);
        g_DRTeamRolled[team] = true;
        g_DRTeamAccepted[team] = DR_AcceptRoll(roll, DR_OPENING_CHANCE);
        if (g_DRTeamAccepted[team])
            groups.GetString(GetRandomInt(0, groups.Length - 1), g_DRTeamSource[team], sizeof(g_DRTeamSource[]));
        PrintToServer("[DemoReplay] opening_roll round=%d team=%d roll=%d accepted=%d source=%s",
            g_DRRoundSerial, team, roll, g_DRTeamAccepted[team], g_DRTeamSource[team]);
    }
    delete groups;
    if (!g_DRTeamAccepted[team])
        return;
    int roles[5], roleCount;
    for (int i = 0; i < g_DRCatalog.Length && roleCount < 5; i++)
    {
        DRRecord record;
        g_DRCatalog.GetArray(i, record, sizeof(DRRecord));
        if (record.opening && record.team == team && record.pistol == pistol
            && StrEqual(record.sourceRound, g_DRTeamSource[team])
            && g_DRUsedRoles.FindString(record.id) == -1)
            roles[roleCount++] = i;
    }
    bool edges[5][5];
    for (int bot = 0; bot < clientCount; bot++)
    {
        g_DRClient[clients[bot]].preparing = false;
        g_DRClient[clients[bot]].role = -1;
        for (int role = 0; role < roleCount; role++)
        {
            DRRecord record;
            g_DRCatalog.GetArray(roles[role], record, sizeof(DRRecord));
            edges[bot][role] = DR_CanAssign(clients[bot], record);
        }
    }
    int assignment[5];
    DR_MaximumMatching(edges, clientCount, roleCount, assignment);
    for (int bot = 0; bot < clientCount; bot++)
    {
        if (assignment[bot] == -1)
            continue;
        int client = clients[bot];
        g_DRClient[client].role = roles[assignment[bot]];
        g_DRClient[client].preparing = true;
        DR_PrepareClient(client);
    }
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

CSWeaponID DR_PreparationPrimary(DRRecord record)
{
    if (StrEqual(record.weaponGroup, "ordinary"))
        return record.team == CS_TEAM_T ? CSWeapon_GALILAR : CSWeapon_FAMAS;
    if (StrEqual(record.weaponGroup, "awp"))
        return CSWeapon_AWP;
    if (StrEqual(record.weaponGroup, "ssg_08"))
        return CSWeapon_SSG08;
    if (StrEqual(record.weaponGroup, "g3sg1"))
        return CSWeapon_G3SG1;
    if (StrEqual(record.weaponGroup, "scar-20"))
        return CSWeapon_SCAR20;
    if (StrEqual(record.weaponGroup, "aug"))
        return CSWeapon_AUG;
    if (StrEqual(record.weaponGroup, "sg_553"))
        return CSWeapon_SG556;
    return CSWeapon_NONE;
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

int DR_PreparationCost(int client, DRRecord record)
{
    int cost;
    int armor = GetEntProp(client, Prop_Send, "m_ArmorValue");
    bool helmet = GetEntProp(client, Prop_Send, "m_bHasHelmet") != 0;
    if (record.helmet && !helmet)
    {
        cost += CS_GetWeaponPrice(client, CSWeapon_ASSAULTSUIT);
        if (armor >= 100)
            cost -= CS_GetWeaponPrice(client, CSWeapon_KEVLAR);
    }
    else if (record.requiresArmor && armor <= 0)
        cost += CS_GetWeaponPrice(client, CSWeapon_KEVLAR);
    if (record.defuser && !GetEntProp(client, Prop_Send, "m_bHasDefuser"))
    {
        if (GetClientTeam(client) != CS_TEAM_CT)
            return -1;
        cost += CS_GetWeaponPrice(client, CSWeapon_DEFUSER);
    }
    if (record.requiresPrimary && !IsValidEntity(GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)))
    {
        CSWeaponID primary = DR_PreparationPrimary(record);
        if (primary == CSWeapon_NONE)
            return -1;
        cost += CS_GetWeaponPrice(client, primary);
    }
    int total = DR_CountWeapon(client, CSWeapon_DECOY);
    for (int kind = 0; kind < view_as<int>(DR_GrenadeKinds); kind++)
    {
        CSWeaponID weapon = DR_GrenadeWeapon(view_as<DRGrenadeKind>(kind), record);
        int owned = DR_CountWeapon(client, weapon);
        int missing = record.grenades[kind] - owned;
        total += owned;
        if (missing <= 0)
            continue;
        if (kind == view_as<int>(DR_Fire)
            && ((record.team == CS_TEAM_CT && weapon == CSWeapon_MOLOTOV)
                || (record.team == CS_TEAM_T && weapon == CSWeapon_INCGRENADE)))
            return -1;
        int price = CS_GetWeaponPrice(client, weapon);
        if (price <= 0)
            return -1;
        cost += missing * price;
        total += missing;
    }
    ConVar limit = FindConVar("ammo_grenade_limit_total");
    if (limit == null || total > limit.IntValue)
        return -1;
    return cost;
}

bool DR_CanPrepare(int client, DRRecord record)
{
    int cost = DR_PreparationCost(client, record);
    return cost >= 0 && GetEntProp(client, Prop_Send, "m_iAccount") >= cost
        && (!record.requiresC4 || DR_CountWeapon(client, CSWeapon_C4) > 0)
        && (cost == 0 || GetEntProp(client, Prop_Send, "m_bInBuyZone") != 0);
}

bool DR_IsReserved(int client)
{
    return DR_OwnsGrenade(client)
        || (client >= 1 && client <= MaxClients && IsClientInGame(client)
            && g_DRClient[client].serial == GetClientSerial(client) && g_DRClient[client].round == g_DRRoundSerial
            && (g_DRClient[client].preparing || DR_OwnsOpening(client)));
}

void DR_Buy(int client, const char[] alias)
{
    g_DRBuying[client] = true;
    FakeClientCommand(client, "buy %s", alias);
    g_DRBuying[client] = false;
}

void DR_BuyWeapon(int client, CSWeaponID weapon)
{
    char alias[32];
    CS_WeaponIDToAlias(weapon, alias, sizeof(alias));
    DR_Buy(client, alias);
}

void DR_PrepareClient(int client)
{
    if (!DR_IsClient(client) || !DR_FormalRound() || g_DRClient[client].serial != GetClientSerial(client))
    {
        DR_StopClient(client, "preparation_lifecycle");
        return;
    }
    if (g_bFreezetimeEnd)
    {
        g_DRClient[client].consumed = true;
        DR_StopClient(client, "freeze_ended_without_start");
        return;
    }
    DRRecord record;
    g_DRCatalog.GetArray(g_DRClient[client].role, record, sizeof(DRRecord));
    if (!DR_CanAssign(client, record))
    {
        DR_StopClient(client, "preparation_ineligible");
        return;
    }
    if (g_DRClient[client].preparationSent && g_DRClient[client].preparedRole == g_DRClient[client].role)
    {
        if (DR_PreparationCost(client, record) == 0)
            DR_TryStartOpening(client);
        else if (GetGameTime() - g_DRClient[client].preparedAt >= 0.25)
        {
            g_DRClient[client].consumed = true;
            PrintToServer("[DemoReplay] preparation_failed round=%d serial=%d rec=%s money=%d", g_DRRoundSerial,
                g_DRClient[client].serial, record.id, GetEntProp(client, Prop_Send, "m_iAccount"));
            DR_StopClient(client, "purchase_failed");
        }
        return;
    }
    g_DRClient[client].preparationSent = true;
    g_DRClient[client].preparedRole = g_DRClient[client].role;
    g_DRClient[client].preparedAt = GetGameTime();
    int armor = GetEntProp(client, Prop_Send, "m_ArmorValue");
    if (record.helmet && !GetEntProp(client, Prop_Send, "m_bHasHelmet"))
        DR_Buy(client, "vesthelm");
    else if (record.requiresArmor && armor <= 0)
        DR_Buy(client, "vest");
    if (record.defuser && !GetEntProp(client, Prop_Send, "m_bHasDefuser"))
        DR_Buy(client, "defuser");
    if (record.requiresPrimary && !IsValidEntity(GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)))
        DR_BuyWeapon(client, DR_PreparationPrimary(record));
    for (int kind = 0; kind < view_as<int>(DR_GrenadeKinds); kind++)
    {
        CSWeaponID weapon = DR_GrenadeWeapon(view_as<DRGrenadeKind>(kind), record);
        int missing = record.grenades[kind] - DR_CountWeapon(client, weapon);
        for (int count = 0; count < missing; count++)
            DR_BuyWeapon(client, weapon);
    }
    PrintToServer("[DemoReplay] preparation_requested round=%d serial=%d rec=%s money=%d", g_DRRoundSerial,
        g_DRClient[client].serial, record.id, GetEntProp(client, Prop_Send, "m_iAccount"));
}

bool DR_Paused()
{
    return GameRules_GetProp("m_bMatchWaitingForResume") != 0
        || GameRules_GetProp("m_bTerroristTimeOutActive") != 0
        || GameRules_GetProp("m_bCTTimeOutActive") != 0;
}

void DR_TryStartOpening(int client)
{
    if (!g_DRClient[client].preparing || !DR_FormalRound() || g_bFreezetimeEnd || DR_Paused())
        return;
    DRRecord record;
    g_DRCatalog.GetArray(g_DRClient[client].role, record, sizeof(DRRecord));
    if (!DR_CanAssign(client, record) || DR_PreparationCost(client, record) != 0)
        return;
    int remaining = RoundToCeil((GameRules_GetPropFloat("m_fRoundStartTime") - GetGameTime()) / GetTickInterval());
    if (remaining > record.freezeFrame)
        return;
    int startFrame = record.freezeFrame - remaining;
    if (remaining < 0 || startFrame < 0 || startFrame > record.prepareFrame)
    {
        g_DRClient[client].consumed = true;
        DR_StopClient(client, "insufficient_freeze_preparation");
        return;
    }
    ArrayList loaded = BotMimic_GetLoadedRecordList();
    char category[64];
    if (loaded == null || loaded.FindString(record.path) == -1
        || !BotMimic_GetFileCategory(record.path, category, sizeof(category))
        || !StrEqual(category, record.category))
    {
        PrintToServer("[DemoReplay] opening_unavailable rec=%s reason=core_catalog", record.id);
        return;
    }
    g_DRClient[client].active = true;
    g_DRClient[client].preparing = false;
    g_DRClient[client].consumed = true;
    g_DRClient[client].firstFrame = false;
    g_DRClient[client].startedAt = GetGameTime();
    g_DRUsedRoles.PushString(record.id);
    g_bDropWeapon[client] = false;
    g_bCheapDrop[client] = false;
    g_bDontSwitch[client] = false;
    BMError result = BotMimic_PlayRecordFromFileEx(client, record.path, startFrame, BMPlayback_LiveInput);
    PrintToServer("[DemoReplay] opening_start_requested round=%d serial=%d rec=%s start=%d remaining=%d result=%d",
        g_DRRoundSerial, g_DRClient[client].serial, record.id, startFrame, remaining, result);
    if (result != BM_NoError || !BotMimic_IsPlayerMimicing(client))
        DR_StopClient(client, "start_failed");
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
            g_DRGrenade[client].nextMoveAt += elapsed;
            if (g_DRGrenade[client].stage == DR_GrenadeStagePlaying)
                g_DRGrenade[client].startedAt += elapsed;
        }
        for (int kind = 0; kind < 4; kind++)
            if (g_DROpportunity[client][kind].outsideSince >= 0.0)
                g_DROpportunity[client][kind].outsideSince += elapsed;
        if (g_DRClient[client].active && !g_DRClient[client].firstFrame)
            g_DRClient[client].startedAt += elapsed;
    }
}

public void OnGameFrame()
{
    if (!g_DRRoundActive || g_DRCatalog == null)
        return;
    bool paused = DR_Paused();
    DR_UpdateGrenadePause(paused);
    DR_UpdateEffects();
    if (paused)
        return;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (g_DRClient[client].preparing && g_DRClient[client].preparationSent)
            DR_PrepareClient(client);
        if (g_DRClient[client].active && !g_DRClient[client].firstFrame
            && GetGameTime() - g_DRClient[client].startedAt > 0.5)
            DR_StopClient(client, "first_frame_timeout");
        DR_UpdateGrenade(client);
    }
    float now = GetGameTime();
    if (now < g_DRNextScan)
        return;
    g_DRNextScan = now + 0.05;
    DR_PrepareOpening(CS_TEAM_T);
    DR_PrepareOpening(CS_TEAM_CT);
    for (int client = 1; client <= MaxClients; client++)
        if (DR_IsClient(client))
            DR_TryGrenade(client);
}

public void DR_OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!DR_OwnsOpening(client))
        return;
    int attackerUserID = event.GetInt("attacker");
    int attacker = GetClientOfUserId(attackerUserID);
    int team = GetClientTeam(client);
    int attackerTeam = attacker >= 1 && attacker <= MaxClients && IsClientInGame(attacker)
        ? GetClientTeam(attacker) : 0;
    bool friendly = attacker != client && (team == CS_TEAM_T || team == CS_TEAM_CT)
        && attackerTeam == team;
    int health = event.GetInt("dmg_health");
    int armor = event.GetInt("dmg_armor");
    PrintToServer("[DemoReplay] opening_hurt round=%d serial=%d attacker_userid=%d attacker=%d team=%d attacker_team=%d health=%d armor=%d friendly=%d",
        g_DRRoundSerial, GetClientSerial(client), attackerUserID, attacker, team, attackerTeam, health, armor, friendly);
    if (friendly)
        return;
    if (health > 0 || armor > 0)
        DR_StopClient(client, "damage");
}

bool DR_VisibleEnemy(int client)
{
    int enemy = BotGetEnemy(client);
    return enemy >= 1 && enemy <= MaxClients && IsClientInGame(enemy) && IsPlayerAlive(enemy)
        && (GetClientTeam(enemy) == CS_TEAM_T || GetClientTeam(enemy) == CS_TEAM_CT)
        && GetClientTeam(enemy) != GetClientTeam(client)
        && GetEntData(client, g_iEnemyVisibleOffset, 1) != 0;
}

Action DR_BeforeFrame(int client, int frameIndex, const float recordedOrigin[3], const float movement[3])
{
    if (!DR_OwnsOpening(client))
        return Plugin_Continue;
    if (!DR_IsClient(client) || !DR_FormalRound())
    {
        DR_StopClient(client, "lifecycle_or_phase");
        return Plugin_Stop;
    }
    if (DR_Paused())
    {
        g_DRClient[client].progressSince = 0.0;
        return Plugin_Changed;
    }
    if (DR_VisibleEnemy(client))
    {
        DR_StopClient(client, "visible_enemy");
        return Plugin_Stop;
    }
    TaskType task = GetTask(client);
    if (g_bBombPlanted || task == PLANT_BOMB || task == GUARD_TICKING_BOMB)
    {
        DR_StopClient(client, "plant_or_guard");
        return Plugin_Stop;
    }
    DRRecord record;
    g_DRCatalog.GetArray(g_DRClient[client].role, record, sizeof(DRRecord));
    if (!g_DRClient[client].firstFrame)
    {
        float origin[3];
        GetClientAbsOrigin(client, origin);
        if (GetVectorDistance(origin, record.origin) > DR_OPENING_START_RADIUS
            || !DR_WeaponGroupMatches(client, record.weaponGroup) || DR_PreparationCost(client, record) != 0)
        {
            DR_StopClient(client, "first_frame_state_changed");
            return Plugin_Stop;
        }
    }
    if (!g_bFreezetimeEnd)
    {
        g_DRClient[client].progressSince = 0.0;
        if (frameIndex >= record.freezeFrame)
            return Plugin_Changed;
        return Plugin_Continue;
    }
    if (frameIndex < record.freezeFrame)
    {
        DR_StopClient(client, "freeze_anchor_mismatch");
        return Plugin_Stop;
    }
    if (FloatAbs(movement[0]) < 1.0 && FloatAbs(movement[1]) < 1.0)
    {
        g_DRClient[client].progressSince = 0.0;
        return Plugin_Continue;
    }
    float actual[3], now = GetGameTime();
    GetClientAbsOrigin(client, actual);
    if (g_DRClient[client].progressSince == 0.0)
    {
        g_DRClient[client].progressSince = now;
        for (int axis = 0; axis < 3; axis++)
        {
            g_DRClient[client].actualProgressOrigin[axis] = actual[axis];
            g_DRClient[client].referenceProgressOrigin[axis] = recordedOrigin[axis];
        }
    }
    float actualDistance, referenceDistance;
    for (int axis = 0; axis < 2; axis++)
    {
        float delta = actual[axis] - g_DRClient[client].actualProgressOrigin[axis];
        actualDistance += delta * delta;
        delta = recordedOrigin[axis] - g_DRClient[client].referenceProgressOrigin[axis];
        referenceDistance += delta * delta;
    }
    if (DR_IsProgressBlocked(now - g_DRClient[client].progressSince, referenceDistance, actualDistance))
    {
        DR_StopClient(client, "cannot_advance");
        return Plugin_Stop;
    }
    if (now - g_DRClient[client].progressSince >= 1.0)
        g_DRClient[client].progressSince = 0.0;
    return Plugin_Continue;
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
    return DR_BeforeFrame(client, frameIndex, recordedOrigin, movement);
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
    DR_StopGrenade(client, "playback_stopped");
    if (g_DRClient[client].active)
        DR_StopClient(client, "playback_stopped");
}

void DR_ResetClient(int client, bool disconnect = false)
{
    if (client < 1 || client > MaxClients)
        return;
    DR_StopClient(client, "client_lifecycle");
    DR_StopGrenade(client, "client_lifecycle");
    int serial = !disconnect && IsClientInGame(client) ? GetClientSerial(client) : 0;
    if (serial != g_DRClient[client].serial || g_DRClient[client].round != g_DRRoundSerial)
        g_DRClient[client].consumed = false;
    g_DRClient[client].serial = serial;
    g_DRClient[client].round = g_DRRoundSerial;
    g_DRClient[client].preparationSent = false;
    g_DRClient[client].preparedRole = -1;
    g_DRBuying[client] = false;
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
    if (task == PLANT_BOMB || task == ESCAPE_FROM_BOMB || task == ESCAPE_FROM_FLAMES
        || GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Send, "m_bIsDefusing"))
        return false;
    if (g_bBombPlanted && GetClientTeam(client) == CS_TEAM_CT
        && (task == DEFUSE_BOMB || task == FIND_TICKING_BOMB || task == GUARD_BOMB_DEFUSER))
        return false;
    if (BotMimic_IsPlayerMimicing(client) && (!continuing || !DR_MatchesGrenadePlayback(client)))
        return false;
    if ((!continuing || !g_DRGrenade[client].firstFrame) && !DR_GrenadeIdle(client))
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
    return FileExists(record.path) && loaded != null && loaded.FindString(record.path) != -1
        && BotMimic_GetFileCategory(record.path, category, sizeof(category))
        && StrEqual(category, record.category);
}

void DR_TryGrenade(int client)
{
    if (!DR_IsClient(client) || g_DRCatalog == null
        || g_DRGrenade[client].stage != DR_GrenadeStageIdle)
        return;
    int team = GetClientTeam(client);
    float origin[3], now = GetGameTime();
    GetClientAbsOrigin(client, origin);
    bool phaseAllowed = DR_GrenadePhaseAllowed(client);
    int selected = -1;
    float selectedDistance = DR_GRENADE_SELECT_RADIUS * DR_GRENADE_SELECT_RADIUS;
    char selectedID[64];
    for (int kind = 0; kind < 4; kind++)
    {
        ArrayList candidates = g_DRGrenadeIndex[team][kind];
        int nearest = -1;
        float nearestDistance = DR_GRENADE_SELECT_RADIUS * DR_GRENADE_SELECT_RADIUS;
        char nearestID[64];
        if (phaseAllowed && candidates != null)
        {
            for (int i = 0; i < candidates.Length; i++)
            {
                int index = candidates.Get(i);
                DRRecord record;
                g_DRCatalog.GetArray(index, record, sizeof(DRRecord));
                float distance = GetVectorDistance(origin, record.origin, true);
                if (now < record.retryAfter || distance > nearestDistance
                    || DR_CountWeapon(client, record.targetWeapon) == 0
                    || DR_EffectBlocked(record.team, record.kind, record.target))
                    continue;
                if (!DR_RecordAvailable(record))
                {
                    record.retryAfter = now + 25.0;
                    g_DRCatalog.SetArray(index, record, sizeof(DRRecord));
                    PrintToServer("[DemoReplay] grenade_unavailable rec=%s reason=core_catalog", record.id);
                    continue;
                }
                if (nearest != -1 && distance == nearestDistance && strcmp(record.id, nearestID) >= 0)
                    continue;
                nearest = index;
                nearestDistance = distance;
                strcopy(nearestID, sizeof(nearestID), record.id);
            }
        }
        bool ready = DR_UpdateOpportunity(g_DROpportunity[client][kind], nearest != -1, now,
            GetClientSerial(client), g_DRRoundSerial);
        if (!ready || g_DROpportunity[client][kind].requested)
            continue;
        if (!g_DROpportunity[client][kind].rolled)
        {
            int roll = GetRandomInt(0, 99);
            g_DROpportunity[client][kind].rolled = true;
            g_DROpportunity[client][kind].accepted = DR_AcceptRoll(roll, DR_GRENADE_CHANCE);
            PrintToServer("[DemoReplay] grenade_roll round=%d serial=%d kind=%d opportunity=%d roll=%d accepted=%d",
                g_DRRoundSerial, GetClientSerial(client), kind, g_DROpportunity[client][kind].sequence,
                roll, g_DROpportunity[client][kind].accepted);
        }
        if (!g_DROpportunity[client][kind].accepted || nearestDistance > selectedDistance
            || (selected != -1 && nearestDistance == selectedDistance && strcmp(nearestID, selectedID) >= 0))
            continue;
        selected = nearest;
        selectedDistance = nearestDistance;
        strcopy(selectedID, sizeof(selectedID), nearestID);
    }
    if (selected != -1)
    {
        DRRecord record;
        g_DRCatalog.GetArray(selected, record, sizeof(DRRecord));
        g_DROpportunity[client][view_as<int>(record.kind)].requested = true;
        DR_AssignGrenade(client, selected);
    }
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

void DR_CaptureGrenadeProjectile(int client)
{
    if (!DR_OwnsGrenade(client) || g_DRGrenade[client].stage != DR_GrenadeStagePlaying)
        return;
    int index = DR_FindEffect(g_DRGrenade[client].reservation);
    // SpawnPost defers ownership attribution. Bind an already-thrown projectile
    // before losing this client's serial and active reservation.
    if (index != -1 && g_DRRoundActive && IsClientInGame(client)
        && g_DRGrenade[client].serial == GetClientSerial(client)
        && g_DRGrenade[client].round == g_DRRoundSerial)
    {
        DREffect selected;
        g_DREffects.GetArray(index, selected, sizeof(DREffect));
        if (selected.phase == DR_EffectSelected)
        {
            static const char classes[][] = {
                "smokegrenade_projectile", "flashbang_projectile",
                "hegrenade_projectile", "molotov_projectile"
            };
            int entity = -1;
            while ((entity = FindEntityByClassname(entity, classes[view_as<int>(selected.kind)])) != -1)
                if (GetEntPropEnt(entity, Prop_Send, "m_hThrower") == client)
                    DR_OnProjectileCreated(entity);
        }
    }
}

void DR_StopGrenade(int client, const char[] reason)
{
    if (client < 1 || client > MaxClients || g_DRGrenade[client].stage == DR_GrenadeStageIdle)
        return;
    bool stopPlayback = DR_MatchesGrenadePlayback(client);
    DR_CaptureGrenadeProjectile(client);
    DRGrenadeStage stage = g_DRGrenade[client].stage;
    g_DRGrenade[client].stage = DR_GrenadeStageIdle;
    g_DRIssuingMove[client] = false;
    int index = DR_FindEffect(g_DRGrenade[client].reservation);
    if (index != -1)
    {
        DREffect effect;
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (effect.phase == DR_EffectSelected)
        {
            effect.live = false;
            g_DREffects.SetArray(index, effect, sizeof(DREffect));
        }
    }
    if (g_DRCatalog != null && g_DRGrenade[client].record >= 0
        && g_DRGrenade[client].record < g_DRCatalog.Length)
    {
        DRRecord record;
        g_DRCatalog.GetArray(g_DRGrenade[client].record, record, sizeof(DRRecord));
        record.retryAfter = GetGameTime() + 25.0;
        g_DRCatalog.SetArray(g_DRGrenade[client].record, record, sizeof(DRRecord));
    }
    if (stopPlayback)
        BotMimic_StopPlayerMimic(client);
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
    g_DRGrenade[client].assignedAt = GetGameTime();
    g_DRGrenade[client].nextMoveAt = 0.0;
    g_DRGrenade[client].startedAt = 0.0;
    PrintToServer("[DemoReplay] grenade_selected round=%d serial=%d kind=%d opportunity=%d reservation=%d rec=%s source=%.3f,%.3f,%.3f",
        g_DRRoundSerial, GetClientSerial(client), view_as<int>(record.kind),
        g_DROpportunity[client][view_as<int>(record.kind)].sequence, effect.id, record.id, effect.target[0], effect.target[1], effect.target[2]);
    PrintToServer("[DemoReplay] grenade_approach_started round=%d serial=%d rec=%s",
        g_DRRoundSerial, GetClientSerial(client), record.id);
}

bool DR_GrenadeWeaponReady(int client, CSWeaponID weaponID)
{
    char alias[64];
    CS_WeaponIDToAlias(weaponID, alias, sizeof(alias));
    Format(alias, sizeof(alias), "weapon_%s", alias);
    int weapon = eItems_FindWeaponByClassName(client, alias);
    if (!IsValidEntity(weapon))
        return false;
    if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") != weapon)
    {
        SDKCall(g_hSwitchWeaponCall, client, weapon, 0);
        return false;
    }
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
    if (now - g_DRGrenade[client].assignedAt > 5.0)
    {
        DR_StopGrenade(client, "approach_timeout");
        return;
    }
    float origin[3], velocity[3];
    GetClientAbsOrigin(client, origin);
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", velocity);
    velocity[2] = 0.0;
    bool weaponReady = DR_GrenadeWeaponReady(client, record.targetWeapon);
    if (weaponReady && DR_CanStartGrenade(GetVectorDistance(origin, record.origin, true), GetVectorLength(velocity, true),
        (GetEntityFlags(client) & FL_ONGROUND) != 0))
    {
        DR_StartGrenade(client, g_DRGrenade[client].record);
        return;
    }
    if (now >= g_DRGrenade[client].nextMoveAt)
    {
        g_DRIssuingMove[client] = true;
        BotMoveTo(client, record.origin, FASTEST_ROUTE);
        g_DRIssuingMove[client] = false;
        g_DRGrenade[client].nextMoveAt = now + 0.35;
    }
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
            (GetEntityFlags(client) & FL_ONGROUND) != 0))
    {
        DR_StopGrenade(client, "start_state_changed");
        return;
    }
    g_DRGrenade[client].stage = DR_GrenadeStagePlaying;
    g_DRGrenade[client].startedAt = GetGameTime();
    PrintToServer("[DemoReplay] grenade_approach_finished round=%d serial=%d rec=%s elapsed=%.3f speed=%.3f",
        g_DRRoundSerial, GetClientSerial(client), record.id,
        GetGameTime() - g_DRGrenade[client].assignedAt, GetVectorLength(velocity));
    BMError result = BotMimic_PlayRecordFromFileEx(client, record.path, 0, BMPlayback_LiveInput, true);
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
    if (owner < 1 || owner > MaxClients || !IsClientInGame(owner))
    {
        PrintToServer("[DemoReplay] projectile_unattributed entity=%d reason=owner", entity);
        return;
    }
    if (g_DREffects == null)
        g_DREffects = new ArrayList(sizeof(DREffect));
    int index = -1;
    if (g_DRGrenade[owner].stage == DR_GrenadeStagePlaying && DR_OwnsGrenade(owner))
        index = DR_FindEffect(g_DRGrenade[owner].reservation);
    DREffect effect;
    if (index != -1)
    {
        g_DREffects.GetArray(index, effect, sizeof(DREffect));
        if (effect.phase != DR_EffectSelected || effect.kind != kind)
            index = -1;
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
        for (int kind = 0; kind < 4; kind++)
            DR_UpdateOpportunity(g_DROpportunity[client][kind], false, GetGameTime(), 0, 0);
    }
    if (g_DREffects != null)
        g_DREffects.Clear();
    if (g_DRCatalog != null)
    {
        for (int index = 0; index < g_DRCatalog.Length; index++)
        {
            DRRecord record;
            g_DRCatalog.GetArray(index, record, sizeof(DRRecord));
            record.retryAfter = 0.0;
            g_DRCatalog.SetArray(index, record, sizeof(DRRecord));
        }
    }
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
        if (GetVectorDistance(origin, position, true) > 4096.0)
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
            // The effect event precedes projectile destruction. A deferred orphan
            // match requires that destruction at the event tick and a unique source.
            if (!ownerMatches && ownerHandle == INVALID_ENT_REFERENCE && effect.ownerSerial > 0
                && projectileRef != INVALID_ENT_REFERENCE && effect.projectileRef == projectileRef
                && GetClientFromSerial(effect.ownerSerial) == 0 && effect.destroyedAt > 0.0
                && effect.destroyedAt >= startedAt
                && effect.destroyedAt - startedAt <= GetTickInterval())
                ownerMatches = true;
            if (!effect.live || effect.round != g_DRRoundSerial || effect.kind != DR_Fire
                || effect.phase != DR_EffectFlying || effect.infernoRef != INVALID_ENT_REFERENCE
                || !ownerMatches || GetGameTime() - effect.thrownAt > 10.0
                || GetVectorDistance(origin, effect.lastPosition, true) > 4096.0)
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

public void DR_OrphanInfernoReady(any data)
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
        if (GetEntProp(entity, Prop_Send, "m_hOwnerEntity") == INVALID_ENT_REFERENCE)
        {
            int projectileRef = DR_InfernoProjectile(entity);
            if (projectileRef == INVALID_ENT_REFERENCE)
            {
                PrintToServer("[DemoReplay] fire_unattributed entity=%d reason=projectile_identity", entity);
                return;
            }
            DataPack pending = new DataPack();
            pending.WriteCell(EntIndexToEntRef(entity));
            pending.WriteCell(g_DRRoundSerial);
            pending.WriteCell(projectileRef);
            pending.WriteFloat(GetGameTime());
            RequestFrame(DR_OrphanInfernoReady, pending);
        }
        else
            DR_LinkInferno(entity);
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

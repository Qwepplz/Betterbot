#if defined _bot_demo_rules_included
    #endinput
#endif
#define _bot_demo_rules_included

#define DR_TICKRATE 128
#define DR_OPENING_CHANCE 80
#define DR_GRENADE_CHANCE 60
#define DR_OPENING_START_RADIUS 1.0
#define DR_GRENADE_START_RADIUS 16.0
#define DR_STILL_SPEED 3.0
#define DR_STILL_TIME 0.25
#define DR_OPPORTUNITY_RESET 0.5

stock bool DR_AcceptRoll(int roll, int chance)
{
    return roll >= 0 && roll < 100 && chance >= 0 && chance <= 100 && roll < chance;
}

stock bool DR_IsPistolRound(int roundsPlayed, int maxRounds, bool overtime)
{
    return !overtime && maxRounds >= 2 && maxRounds % 2 == 0 && roundsPlayed >= 0
        && (roundsPlayed == 0 || roundsPlayed == maxRounds / 2);
}

enum DRGrenadeKind
{
    DR_Smoke = 0,
    DR_Flash,
    DR_HE,
    DR_Fire,
    DR_GrenadeKinds
};

stock bool DR_AugmentMatching(int bot, const bool edges[5][5], int roles, int owner[5], bool visited[5])
{
    for (int role = 0; role < roles; role++)
    {
        if (!edges[bot][role] || visited[role])
            continue;
        visited[role] = true;
        if (owner[role] == -1 || DR_AugmentMatching(owner[role], edges, roles, owner, visited))
        {
            owner[role] = bot;
            return true;
        }
    }
    return false;
}

stock int DR_MaximumMatching(const bool edges[5][5], int bots, int roles, int assignment[5])
{
    int owner[5], matches;
    for (int i = 0; i < 5; i++)
    {
        owner[i] = -1;
        assignment[i] = -1;
    }
    for (int bot = 0; bot < bots && bot < 5; bot++)
    {
        bool visited[5];
        for (int role = 0; role < 5; role++)
            visited[role] = false;
        if (DR_AugmentMatching(bot, edges, roles, owner, visited))
            matches++;
    }
    for (int role = 0; role < roles && role < 5; role++)
        if (owner[role] != -1)
            assignment[owner[role]] = role;
    return matches;
}

stock bool DR_IsProgressBlocked(float elapsed, float referenceDistanceSquared, float actualDistanceSquared)
{
    return elapsed >= 1.0 && referenceDistanceSquared >= 1024.0 && actualDistanceSquared < 64.0;
}

stock bool DR_ShouldBlockEffect(int requestTeam, int requestType, int effectTeam, int effectType,
    float distanceSquared, bool pending, float expiresAt, float now)
{
    return requestTeam == effectTeam && requestType == effectType
        && (requestType == view_as<int>(DR_Smoke) || requestType == view_as<int>(DR_Fire))
        && distanceSquared >= 0.0 && distanceSquared <= 4096.0
        && (pending || now < expiresAt);
}

enum struct DROpportunity
{
    int serial;
    int round;
    int sequence;
    bool engaged;
    bool rolled;
    bool accepted;
    bool requested;
    float stillSince;
    float outsideSince;
}

stock bool DR_UpdateOpportunity(DROpportunity opportunity, bool qualified, float now, int serial, int round)
{
    if (opportunity.serial != serial || opportunity.round != round)
    {
        opportunity.serial = serial;
        opportunity.round = round;
        opportunity.sequence = 0;
        opportunity.engaged = false;
        opportunity.stillSince = -1.0;
        opportunity.outsideSince = -1.0;
    }
    if (!qualified)
    {
        opportunity.stillSince = -1.0;
        if (opportunity.outsideSince < 0.0)
            opportunity.outsideSince = now;
        if (now - opportunity.outsideSince >= DR_OPPORTUNITY_RESET)
            opportunity.engaged = false;
        return false;
    }
    if (!opportunity.engaged)
    {
        opportunity.engaged = true;
        opportunity.sequence++;
        opportunity.rolled = false;
        opportunity.accepted = false;
        opportunity.requested = false;
        opportunity.stillSince = now;
    }
    if (opportunity.stillSince < 0.0)
        opportunity.stillSince = now;
    opportunity.outsideSince = -1.0;
    return now - opportunity.stillSince >= DR_STILL_TIME;
}


stock float DR_EffectBlockDistanceSquared(float targetDistanceSquared, float actualDistanceSquared, bool sourceKnown, bool active)
{
    if (!active)
        return targetDistanceSquared;
    if (sourceKnown && targetDistanceSquared < actualDistanceSquared)
        return targetDistanceSquared;
    return actualDistanceSquared;
}

#if defined _bot_demo_rules_included
    #endinput
#endif
#define _bot_demo_rules_included

#define DR_TICKRATE 128
#define DR_OPENING_CHANCE 80
#define DR_OPENING_START_RADIUS 1.0
#define DR_GRENADE_SELECT_RADIUS 250.0
#define DR_GRENADE_START_RADIUS 25.0

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

stock bool DR_CanStartGrenade(float distanceSquared, float horizontalSpeedSquared, bool onGround)
{
    return onGround && distanceSquared >= 0.0 && horizontalSpeedSquared >= 0.0
        && distanceSquared < DR_GRENADE_START_RADIUS * DR_GRENADE_START_RADIUS
        && horizontalSpeedSquared == 0.0;
}


stock float DR_EffectBlockDistanceSquared(float targetDistanceSquared, float actualDistanceSquared, bool sourceKnown, bool active)
{
    if (!active)
        return targetDistanceSquared;
    if (sourceKnown && targetDistanceSquared < actualDistanceSquared)
        return targetDistanceSquared;
    return actualDistanceSquared;
}

stock void DR_CorrectOpeningMovement(const float error[3], float yaw, float movement[3])
{
    float distance = SquareRoot(error[0] * error[0] + error[1] * error[1]);
    if (distance <= 4.0)
        return;
    float gain = 12.0;
    if (distance * gain > 225.0)
        gain = 225.0 / distance;
    float radians = DegToRad(yaw);
    float correction[2];
    correction[0] = (error[0] * Cosine(radians) + error[1] * Sine(radians)) * gain;
    correction[1] = (error[0] * Sine(radians) - error[1] * Cosine(radians)) * gain;
    for (int axis = 0; axis < 2; axis++)
    {
        movement[axis] += correction[axis];
        if (movement[axis] > 450.0)
            movement[axis] = 450.0;
        else if (movement[axis] < -450.0)
            movement[axis] = -450.0;
    }
}

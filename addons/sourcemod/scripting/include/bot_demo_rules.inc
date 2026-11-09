#if defined _bot_demo_rules_included
    #endinput
#endif
#define _bot_demo_rules_included

#define DR_TICKRATE 128
#define DR_OPENING_CHANCE 80
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

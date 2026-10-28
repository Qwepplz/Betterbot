#if defined _bot_reaction_included
    #endinput
#endif
#define _bot_reaction_included

#define BOT_REACTION_MIN_DELAY 0.150
#define BOT_REACTION_MAX_DELAY 0.450
#define BOT_REACTION_MEAN_DELAY 0.250
#define BOT_REACTION_SIGMA 0.060

enum struct BotReactionState
{
    int ownerSerial;
    int enemySerial;
    float firstSeenAt;
    float readyAt;
    bool active;
}

stock bool BotReactionTryNormalDelay(float u1, float u2, float &delay)
{
    if (!(u1 > 0.0 && u1 <= 1.0) || !(u2 >= 0.0 && u2 <= 1.0))
        return false;

    float z = SquareRoot(-2.0 * Logarithm(u1, 2.718281828459045))
        * Cosine(6.283185307179586 * u2);
    float candidate = BOT_REACTION_MEAN_DELAY + BOT_REACTION_SIGMA * z;
    if (!(candidate >= BOT_REACTION_MIN_DELAY && candidate <= BOT_REACTION_MAX_DELAY))
        return false;

    delay = candidate;
    return true;
}

stock float BotReactionSampleDelay()
{
    float delay;
    while (!BotReactionTryNormalDelay(GetURandomFloat(), GetURandomFloat(), delay))
    {
    }
    return delay;
}

stock void BotReactionReset(BotReactionState state)
{
    state.ownerSerial = 0;
    state.enemySerial = 0;
    state.firstSeenAt = 0.0;
    state.readyAt = 0.0;
    state.active = false;
}

stock bool BotReactionNeedsStart(BotReactionState state, int ownerSerial, int enemySerial)
{
    return !state.active || state.ownerSerial != ownerSerial || state.enemySerial != enemySerial;
}

stock void BotReactionBegin(BotReactionState state, int ownerSerial, int enemySerial, float now, float delay)
{
    state.ownerSerial = ownerSerial;
    state.enemySerial = enemySerial;
    state.firstSeenAt = now;
    state.readyAt = now + delay;
    state.active = true;
}

stock bool BotReactionWaiting(BotReactionState state, float now)
{
    return state.active && now < state.readyAt;
}

stock int BotReactionFilterMask(int buttons, bool waiting, bool isFirearm, bool isRevolver)
{
    if (waiting && isFirearm)
    {
        buttons &= ~IN_ATTACK;
        if (isRevolver)
            buttons &= ~IN_ATTACK2;
    }
    return buttons;
}

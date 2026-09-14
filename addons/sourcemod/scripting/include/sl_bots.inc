#if defined _sl_bots_included
    #endinput
#endif
#define _sl_bots_included

native bool SLBots_IsManaged(int client);

stock bool IsSLBotsManaged(int client)
{
    if (GetFeatureStatus(FeatureType_Native, "SLBots_IsManaged") != FeatureStatus_Available)
        return false;

    return SLBots_IsManaged(client);
}

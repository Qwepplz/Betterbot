stock bool IsValidClient(int client, bool alive = false)
{
    return (0 < client && client <= MaxClients && IsClientInGame(client) && (alive == false || IsPlayerAlive(client)));
}

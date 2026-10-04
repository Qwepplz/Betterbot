// Recovered from the repository SMX; message protocol verified against its bytecode.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Anti Client Crash Fix For Legacy CSGO",
    description = "...",
    author = "backwards",
    version = "1.0",
    url = "http://www.steamcommunity.com/id/mypassword"
};

public void OnPluginStart()
{
    HookUserMessage(GetUserMessageId("SendPlayerItemFound"), Hook_ItemFound, true);
}

public Action Hook_ItemFound(UserMsg msg_id, Protobuf msg, const int[] players,
    int playersNum, bool reliable, bool init)
{
    return Plugin_Handled;
}

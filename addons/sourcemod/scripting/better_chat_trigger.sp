#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

enum
{
    CHAT_MESSAGE_LENGTH = 128,
    COMMAND_NAME_LENGTH = 32
};

public Plugin myinfo =
{
    name = "Better Chat Trigger",
    description = ".",
    author = "Bone",
    version = "1.0",
    url = "https://bonetm.github.io/"
};

public void OnPluginStart()
{
    static const char commands[][] =
    {
        "say",
        "say2",
        "say_team"
    };

    for (int i; i < sizeof(commands); i++)
        AddCommandListener(ChatListener, commands[i]);
}

public Action ChatListener(int client, const char[] command, int args)
{
    if (!IsPlayer(client))
    {
        return Plugin_Continue;
    }

    char message[CHAT_MESSAGE_LENGTH];
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);

    int prefixLength = GetPrefixLength(message);
    if (prefixLength == 0)
    {
        return Plugin_Continue;
    }

    char loweredCommand[COMMAND_NAME_LENGTH];
    strcopy(loweredCommand, sizeof(loweredCommand), message[prefixLength]);

    for (int i; loweredCommand[i] != '\0'; i++)
        loweredCommand[i] = CharToLower(loweredCommand[i]);

    char commandToRun[COMMAND_NAME_LENGTH];
    FormatEx(commandToRun, sizeof(commandToRun), "sm_%s", loweredCommand);

    if (!CommandExists(commandToRun))
    {
        return Plugin_Continue;
    }

    if (prefixLength == 3 || !StrEqual(message[prefixLength], loweredCommand, true))
    {
        FakeClientCommand(client, commandToRun);
    }

    return Plugin_Continue;
}

int GetPrefixLength(const char[] message)
{
    if (message[0] == '!' || message[0] == '.')
    {
        return 1;
    }

    if (StrContains(message, "！", true) == 0 || StrContains(message, "。", true) == 0)
    {
        return 3;
    }

    return 0;
}

bool IsPlayer(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}

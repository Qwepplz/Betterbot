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

    for (int index = 0; index < sizeof(commands); index++)
    {
        AddCommandListener(ChatListener, commands[index]);
    }
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
    String_ToLower(message[prefixLength], loweredCommand, sizeof(loweredCommand));

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

void String_ToLower(const char[] input, char[] output, int size)
{
    int maxLength = size - 1;
    int index = 0;

    while (index < maxLength && input[index] != '\0')
    {
        output[index] = CharToLower(input[index]);
        index++;
    }

    output[index] = '\0';
}

bool IsPlayer(int client)
{
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client);
}

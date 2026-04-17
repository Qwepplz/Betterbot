#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

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
    AddCommandListener(ChatListener, "say");
    AddCommandListener(ChatListener, "say2");
    AddCommandListener(ChatListener, "say_team");
}

public Action ChatListener(int client, const char[] command, int args)
{
    char message[128];
    GetCmdArgString(message, sizeof(message));
    StripQuotes(message);

    if (!IsPlayer(client))
    {
        return Plugin_Continue;
    }

    int prefixLength = GetPrefixLength(message);    if (prefixLength == 0)
    {
        return Plugin_Continue;
    }

    char loweredCommand[32];
    String_ToLower(message[prefixLength], loweredCommand, sizeof(loweredCommand));

    char commandToRun[32];
    FormatEx(commandToRun, sizeof(commandToRun), "sm_%s", loweredCommand);

    if (commandToRun[0] == '\0' || !CommandExists(commandToRun))
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
    int index;

    while (input[index] != '\0' && index < maxLength)
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

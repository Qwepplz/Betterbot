// Recovered from the repository SMX; message flow verified against its bytecode.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

UserMsg g_TextMsg;
UserMsg g_HintText;
UserMsg g_KeyHintText;
char g_sSpace[2048];

public Plugin myinfo =
{
    name = "Fix Hint Color Messages",
    description = "Fix for PrintHintText and PrintCenterText colors msgs in csgo",
    author = "Phoenix (˙·٠●Феникс●٠·˙)",
    version = "1.2.1 Franc1sco franug github version",
    url = "https://github.com/Franc1sco/FixHintColorMessages"
};

public void OnPluginStart()
{
    for (int i = 0; i < 2047; i++)
    {
        g_sSpace[i] = ' ';
    }
    g_TextMsg = GetUserMessageId("TextMsg");
    g_HintText = GetUserMessageId("HintText");
    g_KeyHintText = GetUserMessageId("KeyHintText");
    HookUserMessage(g_TextMsg, TextMsgHintTextHook, true);
    HookUserMessage(g_HintText, TextMsgHintTextHook, true);
    HookUserMessage(g_KeyHintText, TextMsgHintTextHook, true);
}

Action TextMsgHintTextHook(UserMsg msg_id, Protobuf msg, const int[] players,
    int playersNum, bool reliable, bool init)
{
    static char sBuf[2048];
    if (g_HintText == msg_id)
    {
        msg.ReadString("text", sBuf, sizeof(sBuf));
    }
    else if (g_KeyHintText == msg_id)
    {
        msg.ReadString("hints", sBuf, sizeof(sBuf), 0);
    }
    else if (msg.ReadInt("msg_dst") == 4)
    {
        msg.ReadString("params", sBuf, sizeof(sBuf), 0);
    }
    else
    {
        return Plugin_Continue;
    }

    if (StrContains(sBuf, "<font", true) != -1 || StrContains(sBuf, "<span", true) != -1)
    {
        DataPack hPack = new DataPack();
        hPack.WriteCell(playersNum);
        for (int i = 0; i < playersNum; i++)
        {
            hPack.WriteCell(players[i]);
        }
        hPack.WriteString(sBuf);
        hPack.Reset();
        RequestFrame(TextMsgFix, hPack);
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void TextMsgFix(any data)
{
    DataPack hPack = view_as<DataPack>(data);
    int iCount = hPack.ReadCell();
    static int iPlayers[66];
    for (int i = 0; i < iCount; i++)
    {
        iPlayers[i] = hPack.ReadCell();
    }
    int[] newClients = new int[MaxClients];
    int newTotal;
    for (int i = 0; i < iCount; i++)
    {
        int client = iPlayers[i];
        if (IsClientInGame(client))
        {
            newClients[newTotal++] = client;
        }
    }
    if (!newTotal)
    {
        return;
    }
    static char sBuf[2048];
    hPack.ReadString(sBuf, sizeof(sBuf));
    CloseHandle(hPack);
    hPack = null;
    Protobuf hMessage = view_as<Protobuf>(StartMessageEx(g_TextMsg, newClients, newTotal, 132));
    if (hMessage != null)
    {
        hMessage.SetInt("msg_dst", 4);
        hMessage.AddString("params", "#SFUI_ContractKillStart");
        Format(sBuf, sizeof(sBuf), "</font>%s%s", sBuf, g_sSpace);
        hMessage.AddString("params", sBuf);
        hMessage.AddString("params", NULL_STRING);
        hMessage.AddString("params", NULL_STRING);
        hMessage.AddString("params", NULL_STRING);
        hMessage.AddString("params", NULL_STRING);
        EndMessage();
    }
}

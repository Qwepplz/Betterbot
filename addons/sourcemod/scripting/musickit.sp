// Recovered from the repository SMX; menu and cookie flow verified against bytecode.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

public Plugin myinfo =
{
    name = "Music Kits",
    description = "Music Kits Changer",
    author = "Bone",
    version = "1.0.0",
    url = ""
};

int g_iMusic[66] = {1, ...};
Menu menuMusic;
Cookie g_cookieMusic;

public void OnPluginStart()
{
    LoadTranslations("musickit.phrases");
    g_cookieMusic = new Cookie("music_kit", "Music Kits Changer", CookieAccess_Private);
    ReadConfig();
    HookEvent("player_spawn", Event_Player_Spawn, EventHookMode_Pre);
    HookEvent("player_disconnect", Event_Disc, EventHookMode_Post);
    RegConsoleCmd("sm_music", CommandMusic, "Set Music Kit in Game");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && AreClientCookiesCached(i))
        {
            OnClientCookiesCached(i);
        }
    }
}

public void OnClientCookiesCached(int client)
{
    char value[16];
    g_cookieMusic.Get(client, value, sizeof(value));
    if (strlen(value) > 0)
    {
        g_iMusic[client] = StringToInt(value);
    }
    if (client < 1 || client > MaxClients)
    {
        return;
    }
    if (!IsClientInGame(client))
    {
        return;
    }
    if (IsFakeClient(client))
    {
        return;
    }
    if (g_iMusic[client] != 1)
    {
        EquipMusic(client);
    }
}

bool IsValidClient(int client)
{
    return client >= 1 && client <= MaxClients && IsClientInGame(client)
        && !IsFakeClient(client) && !IsClientSourceTV(client) && !IsClientReplay(client);
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(client) && g_iMusic[client] != 1)
    {
        EquipMusic(client);
    }
    return Plugin_Continue;
}

public Action Event_Disc(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client)
    {
        g_iMusic[client] = 1;
    }
    return Plugin_Continue;
}

public Action CommandMusic(int client, int args)
{
    menuMusic.Display(client, 0);
    return Plugin_Continue;
}

public int MusicMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char musicKitIdStr[20];
            menu.GetItem(selection, musicKitIdStr, sizeof(musicKitIdStr));
            int music = StringToInt(musicKitIdStr);
            g_iMusic[client] = music;
            UpdatePlayerData(client, music);
            EquipMusic(client);

            Handle packHandle;
            CreateDataTimer(0.5, MusicMenuTimer, packHandle);
            DataPack pack = view_as<DataPack>(packHandle);
            pack.WriteCell(menu);
            pack.WriteCell(client);
            pack.WriteCell(GetMenuSelectionPosition());
        }
        case MenuAction_Cancel:
        {
            if (IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                ClientCommand(client, "sm_diy");
            }
        }
        case MenuAction_DisplayItem:
        {
            if (IsClientInGame(client))
            {
                char info[32];
                char display[64];
                menu.GetItem(selection, info, sizeof(info));
                if (StrEqual(info, "1", true))
                {
                    Format(display, sizeof(display), "%T", "Default", client);
                    return RedrawMenuItem(display);
                }
                if (StrEqual(info, "-1", true))
                {
                    Format(display, sizeof(display), "%T", "Random", client);
                    return RedrawMenuItem(display);
                }
            }
        }
    }
    return 0;
}

public Action MusicMenuTimer(Handle timer, any data)
{
    DataPack pack = view_as<DataPack>(data);
    ResetPack(pack, false);
    Menu menu = view_as<Menu>(pack.ReadCell());
    int clientIndex = pack.ReadCell();
    int menuSelectionPosition = pack.ReadCell();
    if (IsClientInGame(clientIndex))
    {
        menu.DisplayAt(clientIndex, menuSelectionPosition, 0);
    }
    return Plugin_Continue;
}

public void EquipMusic(int client)
{
    if (GetEntProp(client, Prop_Send, "m_unMusicID", 4, 0))
    {
        if (g_iMusic[client] == -1)
        {
            SetEntProp(client, Prop_Send, "m_unMusicID", GetRandomMusic(client), 4, 0);
        }
        else
        {
            SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusic[client], 4, 0);
        }
    }
}

void UpdatePlayerData(int client, int index)
{
    char temp[4];
    IntToString(index, temp, sizeof(temp));
    g_cookieMusic.Set(client, temp);
}

void ReadConfig()
{
    char configPath[256];
    char code[4];
    char language[32];
    GetLanguageInfo(GetServerLanguage(), code, sizeof(code), language, sizeof(language));
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/musickit/musickit_%s.cfg", language);
    if (!FileExists(configPath, false, "GAME"))
    {
        BuildPath(Path_SM, configPath, sizeof(configPath), "configs/musickit/musickit_english.cfg");
    }
    if (!FileExists(configPath, false, "GAME"))
    {
        SetFailState("Could not find a config file for any languages.");
    }
    KeyValues kv = CreateKeyValues("Musickit", "", "");
    FileToKeyValues(kv, configPath);
    if (!KvGotoFirstSubKey(kv, false))
    {
        SetFailState("CFG File not found: %s", configPath);
        CloseHandle(kv);
    }
    if (menuMusic)
    {
        CloseHandle(menuMusic);
        menuMusic = null;
    }
    menuMusic = new Menu(MusicMenuHandler, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
    menuMusic.SetTitle("%T", "MusicMenuTitle", 0);
    menuMusic.AddItem("1", "Default");
    menuMusic.AddItem("-1", "Random");
    if (LibraryExists("diy"))
    {
        menuMusic.ExitBackButton = true;
    }
    do
    {
        char name[256];
        char index[4];
        KvGetSectionName(kv, index, sizeof(index));
        KvGetString(kv, NULL_STRING, name, 255);
        menuMusic.AddItem(index, name);
    }
    while (KvGotoNextKey(kv, false));
    CloseHandle(kv);
}

int GetRandomMusic(int client)
{
    #pragma unused client
    int random = GetRandomInt(2, menuMusic.ItemCount - 1);
    char output[4];
    menuMusic.GetItem(random, output, sizeof(output));
    return StringToInt(output);
}

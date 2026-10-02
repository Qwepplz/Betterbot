#if defined _bb_client_translations_included
    #endinput
#endif
#define _bb_client_translations_included
#include <sourcemod>

int g_BBTextClientSerial[MAXPLAYERS + 1];
int g_BBTextReportedLanguage[MAXPLAYERS + 1];
QueryCookie g_BBTextQueryCookie[MAXPLAYERS + 1];
bool g_BBTextQueryPending[MAXPLAYERS + 1];
bool g_BBTextQueryComplete[MAXPLAYERS + 1];

void BB_RequestClientTextLanguage(int client)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client))
    {
        return;
    }
    int serial = GetClientSerial(client);
    if (g_BBTextClientSerial[client] != serial)
    {
        g_BBTextClientSerial[client] = serial;
        g_BBTextReportedLanguage[client] = -1;
        g_BBTextQueryPending[client] = false;
        g_BBTextQueryComplete[client] = false;
    }
    if (g_BBTextQueryComplete[client] || g_BBTextQueryPending[client])
    {
        return;
    }
    g_BBTextQueryPending[client] = true;
    g_BBTextQueryCookie[client] = QueryClientConVar(client, "cl_language", BB_OnClientTextLanguageQueried, serial);
    if (g_BBTextQueryCookie[client] == QUERYCOOKIE_FAILED)
    {
        g_BBTextQueryPending[client] = false;
        g_BBTextQueryComplete[client] = true;
    }
}

public void BB_OnClientTextLanguageQueried(QueryCookie cookie, int client, ConVarQueryResult result,
    const char[] cvarName, const char[] cvarValue, any serial)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client)
        || g_BBTextClientSerial[client] != serial || GetClientSerial(client) != serial
        || g_BBTextQueryCookie[client] != cookie || !g_BBTextQueryPending[client])
    {
        return;
    }
    g_BBTextQueryPending[client] = false;
    g_BBTextQueryComplete[client] = true;
    g_BBTextReportedLanguage[client] = result == ConVarQuery_Okay && StrEqual(cvarName, "cl_language")
        ? GetLanguageByName(cvarValue) : -1;
}

public void OnClientConnected(int client)
{
    BB_RequestClientTextLanguage(client);
}

public void OnClientLanguageChanged(int client, int language)
{
    BB_RequestClientTextLanguage(client);
}

// Validate both resources before any output can temporarily change language.
stock void BB_LoadClientTranslations(const char[] file)
{
    int english = GetLanguageByCode("en");
    int chinese = GetLanguageByCode("chi");
    if (english < 0 || chinese < 0)
    {
        SetFailState("Client translations require en and chi in languages.cfg");
    }
    char path[PLATFORM_MAX_PATH];
    KeyValues en = new KeyValues("Phrases");
    KeyValues chi = new KeyValues("Phrases");
    BuildPath(Path_SM, path, sizeof(path), "translations/%s.txt", file);
    bool valid = en.ImportFromFile(path);
    BuildPath(Path_SM, path, sizeof(path), "translations/chi/%s.txt", file);
    valid = chi.ImportFromFile(path) && valid;
    if (!valid || !en.GotoFirstSubKey())
    {
        delete en;
        delete chi;
        SetFailState("Missing client translation resource: %s", file);
    }
    LoadTranslations(file);
    do
    {
        char key[256], text[4096];
        en.GetSectionName(key, sizeof(key));
        en.GetString("en", text, sizeof(text));
        bool covered = text[0] != '\0' && chi.JumpToKey(key);
        if (covered)
        {
            chi.GetString("chi", text, sizeof(text));
            covered = text[0] != '\0';
            chi.GoBack();
        }
        if (!covered || !TranslationPhraseExists(key)
            || !IsTranslatedForLanguage(key, english)
            || !IsTranslatedForLanguage(key, chinese))
        {
            delete en;
            delete chi;
            SetFailState("Incomplete client translation: %s / %s", file, key);
        }
    }
    while (en.GotoNextKey());
    delete en;
    delete chi;
    for (int client = 1; client <= MaxClients; client++)
    {
        BB_RequestClientTextLanguage(client);
    }
}

stock int BB_SelectClientTextLanguage(int english, int chinese, bool queryComplete, int reportedLanguage)
{
    return queryComplete && chinese >= 0 && reportedLanguage == chinese
        ? chinese : english;
}

stock int BB_GetClientTextLanguage(int client)
{
    int english = GetLanguageByCode("en");
    int chinese = GetLanguageByCode("chi");
    if (client < 1 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client))
    {
        return english;
    }
    BB_RequestClientTextLanguage(client);
    bool queryComplete = g_BBTextClientSerial[client] == GetClientSerial(client)
        && g_BBTextQueryComplete[client];
    return BB_SelectClientTextLanguage(english, chinese, queryComplete, g_BBTextReportedLanguage[client]);
}

stock bool BB_BeginClientTranslation(int client, int &previousLanguage)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client))
    {
        return false;
    }
    previousLanguage = GetClientLanguage(client);
    int target = BB_GetClientTextLanguage(client);
    if (target < 0)
    {
        return false;
    }
    if (previousLanguage != target)
    {
        SetClientLanguage(client, target);
    }
    return true;
}

stock void BB_EndClientTranslation(int client, int previousLanguage)
{
    if (client >= 1 && client <= MaxClients && IsClientConnected(client)
        && previousLanguage >= 0 && GetClientLanguage(client) != previousLanguage)
    {
        SetClientLanguage(client, previousLanguage);
    }
}
stock bool BB_FormatClient(int client, char[] buffer, int maxlen, const char[] format, any ...)
{
    int previousLanguage;
    if (!BB_BeginClientTranslation(client, previousLanguage))
    {
        buffer[0] = '\0';
        return false;
    }
    SetGlobalTransTarget(client);
    VFormat(buffer, maxlen, format, 5);
    BB_EndClientTranslation(client, previousLanguage);
    return true;
}

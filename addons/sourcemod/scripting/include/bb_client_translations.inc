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

StringMap g_BBTextPhraseMap;
char g_BBTextPhraseLanguage[8];
int g_BBTextPhraseDepth;
bool g_BBTextPhraseRootSeen;
bool g_BBTextPhraseComplete;
bool g_BBTextPhraseInPhrase;
char g_BBTextPhraseKey[256];
bool g_BBTextPhraseHasEnglish;
bool g_BBTextPhraseHasChinese;
bool g_BBTextPhraseHasFormat;
char g_BBTextPhraseError[256];
int g_BBTextPhraseLine;

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
    char englishError[256];
    char chineseError[256];
    StringMap englishPhrases = new StringMap();
    StringMap chinesePhrases = new StringMap();

    BuildPath(Path_SM, path, sizeof(path), "translations/%s.txt", file);
    bool englishValid = BB_ReadClientTranslationPhrases(path, "en", englishPhrases,
        englishError, sizeof(englishError));
    BuildPath(Path_SM, path, sizeof(path), "translations/chi/%s.txt", file);
    bool chineseValid = BB_ReadClientTranslationPhrases(path, "chi", chinesePhrases,
        chineseError, sizeof(chineseError));
    if (!englishValid || !chineseValid)
    {
        delete englishPhrases;
        delete chinesePhrases;
        SetFailState("Invalid client translation resource: %s",
            englishValid ? chineseError : englishError);
    }

    LoadTranslations(file);
    StringMapSnapshot snapshot = englishPhrases.Snapshot();
    StringMapSnapshot chineseSnapshot = chinesePhrases.Snapshot();
    if (snapshot == null || chineseSnapshot == null)
    {
        delete snapshot;
        delete chineseSnapshot;
        delete englishPhrases;
        delete chinesePhrases;
        SetFailState("Unable to snapshot client translation keys: %s", file);
    }

    char key[256];
    for (int i = 0; i < snapshot.Length; i++)
    {
        snapshot.GetKey(i, key, sizeof(key));
        bool covered = chinesePhrases.ContainsKey(key);
        if (!covered || !TranslationPhraseExists(key)
            || !IsTranslatedForLanguage(key, english)
            || !IsTranslatedForLanguage(key, chinese))
        {
            delete snapshot;
            delete chineseSnapshot;
            delete englishPhrases;
            delete chinesePhrases;
            SetFailState("Incomplete client translation: %s / %s", file, key);
        }
    }
    for (int i = 0; i < chineseSnapshot.Length; i++)
    {
        chineseSnapshot.GetKey(i, key, sizeof(key));
        if (!englishPhrases.ContainsKey(key))
        {
            delete snapshot;
            delete chineseSnapshot;
            delete englishPhrases;
            delete chinesePhrases;
            SetFailState("English client translation key missing: %s / %s", file, key);
        }
    }

    delete snapshot;
    delete chineseSnapshot;
    delete englishPhrases;
    delete chinesePhrases;
    for (int client = 1; client <= MaxClients; client++)
    {
        BB_RequestClientTextLanguage(client);
    }
}

stock bool BB_ReadClientTranslationPhrases(const char[] path, const char[] language,
    StringMap phrases, char[] error, int maxlen)
{
    g_BBTextPhraseMap = phrases;
    strcopy(g_BBTextPhraseLanguage, sizeof(g_BBTextPhraseLanguage), language);
    g_BBTextPhraseDepth = 0;
    g_BBTextPhraseRootSeen = false;
    g_BBTextPhraseComplete = false;
    g_BBTextPhraseInPhrase = false;
    g_BBTextPhraseKey[0] = '\0';
    g_BBTextPhraseHasEnglish = false;
    g_BBTextPhraseHasChinese = false;
    g_BBTextPhraseHasFormat = false;
    g_BBTextPhraseError[0] = '\0';
    g_BBTextPhraseLine = 0;
    error[0] = '\0';

    if (!StrEqual(language, "en") && !StrEqual(language, "chi"))
    {
        Format(g_BBTextPhraseError, sizeof(g_BBTextPhraseError),
            "unsupported translation language: %s", language);
    }

    SMCParser parser = new SMCParser();
    parser.OnEnterSection = BB_OnClientPhraseSection;
    parser.OnKeyValue = BB_OnClientPhraseValue;
    parser.OnLeaveSection = BB_OnClientPhraseEnd;
    parser.OnRawLine = BB_OnClientPhraseLine;

    int line;
    int column;
    SMCError parseError = parser.ParseFile(path, line, column);
    bool success = g_BBTextPhraseComplete && parseError == SMCError_Okay;
    if (!success)
    {
        if (phrases != null)
        {
            phrases.Clear();
        }
        if (g_BBTextPhraseError[0] == '\0')
        {
            char parserError[128];
            parserError[0] = '\0';
            parser.GetErrorString(parseError, parserError, sizeof(parserError));
            Format(g_BBTextPhraseError, sizeof(g_BBTextPhraseError),
                "parse failed at %d:%d (%s)", line, column, parserError);
        }
        Format(error, maxlen, "%s:%d:%d: %s", path, line, column, g_BBTextPhraseError);
    }

    delete parser;
    parser = null;
    g_BBTextPhraseMap = null;
    g_BBTextPhraseLanguage[0] = '\0';
    g_BBTextPhraseDepth = 0;
    g_BBTextPhraseRootSeen = false;
    g_BBTextPhraseComplete = false;
    g_BBTextPhraseInPhrase = false;
    g_BBTextPhraseKey[0] = '\0';
    g_BBTextPhraseHasEnglish = false;
    g_BBTextPhraseHasChinese = false;
    g_BBTextPhraseHasFormat = false;
    g_BBTextPhraseLine = 0;
    return success;
}

stock void BB_SetClientPhraseError(const char[] reason, const char[] context)
{
    if (g_BBTextPhraseError[0] != '\0')
    {
        return;
    }
    Format(g_BBTextPhraseError, sizeof(g_BBTextPhraseError),
        "%s (phrase=%s, language=%s, line=%d)", reason, context,
        g_BBTextPhraseLanguage, g_BBTextPhraseLine);
}

public SMCResult BB_OnClientPhraseLine(SMCParser smc, const char[] line, int lineno)
{
    g_BBTextPhraseLine = lineno;
    return SMCParse_Continue;
}

public SMCResult BB_OnClientPhraseSection(SMCParser smc, const char[] name, bool opt_quotes)
{
    if (g_BBTextPhraseDepth == 0)
    {
        if (g_BBTextPhraseRootSeen || g_BBTextPhraseComplete || !StrEqual(name, "Phrases"))
        {
            BB_SetClientPhraseError("expected one Phrases root", name);
            return SMCParse_HaltFail;
        }
        g_BBTextPhraseRootSeen = true;
        g_BBTextPhraseDepth = 1;
        return SMCParse_Continue;
    }

    if (g_BBTextPhraseDepth != 1 || g_BBTextPhraseInPhrase)
    {
        BB_SetClientPhraseError("nested phrase sections are not allowed", name);
        return SMCParse_HaltFail;
    }
    if (strlen(name) >= sizeof(g_BBTextPhraseKey))
    {
        BB_SetClientPhraseError("phrase key exceeds 255 UTF-8 bytes", name);
        return SMCParse_HaltFail;
    }
    if (g_BBTextPhraseMap == null)
    {
        BB_SetClientPhraseError("phrase map is unavailable", name);
        return SMCParse_HaltFail;
    }

    strcopy(g_BBTextPhraseKey, sizeof(g_BBTextPhraseKey), name);
    g_BBTextPhraseHasEnglish = false;
    g_BBTextPhraseHasChinese = false;
    g_BBTextPhraseHasFormat = false;
    g_BBTextPhraseInPhrase = true;
    g_BBTextPhraseDepth = 2;
    return SMCParse_Continue;
}

public SMCResult BB_OnClientPhraseValue(SMCParser smc, const char[] key, const char[] value,
    bool key_quotes, bool value_quotes)
{
    if (g_BBTextPhraseDepth != 2 || !g_BBTextPhraseInPhrase)
    {
        BB_SetClientPhraseError("phrase value is outside a phrase section", key);
        return SMCParse_HaltFail;
    }
    if (strlen(key) >= sizeof(g_BBTextPhraseKey))
    {
        BB_SetClientPhraseError("phrase field exceeds 255 UTF-8 bytes", g_BBTextPhraseKey);
        return SMCParse_HaltFail;
    }

    char trimmed[4096];
    strcopy(trimmed, sizeof(trimmed), value);
    TrimString(trimmed);
    if (StrEqual(key, "#format"))
    {
        if (!StrEqual(g_BBTextPhraseLanguage, "en") || g_BBTextPhraseHasFormat
            || trimmed[0] == '\0')
        {
            BB_SetClientPhraseError("invalid #format field", g_BBTextPhraseKey);
            return SMCParse_HaltFail;
        }
        g_BBTextPhraseHasFormat = true;
        return SMCParse_Continue;
    }
    if (!StrEqual(key, g_BBTextPhraseLanguage))
    {
        BB_SetClientPhraseError("unexpected translation language field", g_BBTextPhraseKey);
        return SMCParse_HaltFail;
    }
    if (trimmed[0] == '\0')
    {
        BB_SetClientPhraseError("translation value is empty", g_BBTextPhraseKey);
        return SMCParse_HaltFail;
    }
    if (StrEqual(g_BBTextPhraseLanguage, "en"))
    {
        if (g_BBTextPhraseHasEnglish)
        {
            BB_SetClientPhraseError("duplicate English translation field", g_BBTextPhraseKey);
            return SMCParse_HaltFail;
        }
        g_BBTextPhraseHasEnglish = true;
    }
    else
    {
        if (g_BBTextPhraseHasChinese)
        {
            BB_SetClientPhraseError("duplicate simplified Chinese translation field", g_BBTextPhraseKey);
            return SMCParse_HaltFail;
        }
        g_BBTextPhraseHasChinese = true;
    }
    return SMCParse_Continue;
}

public SMCResult BB_OnClientPhraseEnd(SMCParser smc)
{
    if (g_BBTextPhraseDepth == 2)
    {
        bool hasTarget = StrEqual(g_BBTextPhraseLanguage, "en")
            ? g_BBTextPhraseHasEnglish : g_BBTextPhraseHasChinese;
        if (!hasTarget)
        {
            BB_SetClientPhraseError("phrase has no non-empty target translation", g_BBTextPhraseKey);
            return SMCParse_HaltFail;
        }
        if (!g_BBTextPhraseMap.SetValue(g_BBTextPhraseKey, 1, false))
        {
            BB_SetClientPhraseError("duplicate phrase key", g_BBTextPhraseKey);
            return SMCParse_HaltFail;
        }
        g_BBTextPhraseInPhrase = false;
        g_BBTextPhraseDepth = 1;
        return SMCParse_Continue;
    }
    if (g_BBTextPhraseDepth == 1)
    {
        if (!g_BBTextPhraseRootSeen || g_BBTextPhraseMap == null
            || g_BBTextPhraseMap.Size == 0)
        {
            BB_SetClientPhraseError("Phrases root has no direct phrase entries", "Phrases");
            return SMCParse_HaltFail;
        }
        g_BBTextPhraseComplete = true;
        g_BBTextPhraseDepth = 0;
        return SMCParse_Continue;
    }
    BB_SetClientPhraseError("unexpected section end", g_BBTextPhraseKey);
    return SMCParse_HaltFail;
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

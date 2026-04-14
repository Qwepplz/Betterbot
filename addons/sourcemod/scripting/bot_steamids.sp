#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLAYER_INFO_LEN 344
#define MAX_COMMUNITYID_LENGTH 18

enum
{
	PlayerInfo_Version = 0,             // int64
	PlayerInfo_XUID = 8,               // int64
	PlayerInfo_Name = 16,              // char[128]
	PlayerInfo_UserID = 144,           // int
	PlayerInfo_SteamID = 148,          // char[33]
	PlayerInfo_AccountID = 184,        // int
	PlayerInfo_FriendsName = 188,      // char[128]
	PlayerInfo_IsFakePlayer = 316,     // bool
	PlayerInfo_IsHLTV = 317,           // bool
	PlayerInfo_CustomFile1 = 320,      // int
	PlayerInfo_CustomFile2 = 324,      // int
	PlayerInfo_CustomFile3 = 328,      // int
	PlayerInfo_CustomFile4 = 332,      // int
	PlayerInfo_FilesDownloaded = 336   // char
};

int g_iAccountID[MAXPLAYERS+1];
char g_szSteamID64[MAXPLAYERS+1][MAX_COMMUNITYID_LENGTH]; 
StringMap g_smBotSteamIDs;
StringMap g_smBotCrosshairs;

public Plugin myinfo = 
{
	name = "BOT SteamIDs", 
	author = "manico", 
	description = "'Gives' BOTs SteamIDs", 
	version = "1.1.1", 
	url = "http://steamcommunity.com/id/manico001"
};

public void OnPluginStart()
{
	LoadBotInfo();
	CreateTimer(0.1, Timer_ApplyAllBotSteamIDs, _, TIMER_FLAG_NO_MAPCHANGE);
}

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	CreateNative("GetBotAccountID", Native_GetBotAccountID);
	CreateNative("GetBotSteamID64", Native_GetBotSteamID64);
	CreateNative("GetBotCrosshairCode", Native_GetBotCrosshairCode);
	CreateNative("IsBotInDatabase", Native_IsBotInDatabase);
	CreateNative("IsNameInBotDatabase", Native_IsNameInBotDatabase);
	
	RegPluginLibrary("bot_steamids");
	return APLRes_Success;
}

public void OnMapStart()
{
	LoadBotInfo();
	CreateTimer(1.0, Timer_ApplyAllBotSteamIDs, _, TIMER_FLAG_NO_MAPCHANGE);
}

void LoadBotInfo()
{
	delete g_smBotSteamIDs;
	delete g_smBotCrosshairs;
	g_smBotSteamIDs = new StringMap();
	g_smBotCrosshairs = new StringMap();

	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/bot_info.json");
	
	if (!FileExists(szPath))
	{
		LogError("Configuration file %s is not found.", szPath);
		return;
	}
	
	File hFile = OpenFile(szPath, "r");
	if (hFile == null)
	{
		LogError("Failed to open JSON file: %s", szPath);
		return;
	}

	char szLine[256], szKey[MAX_NAME_LENGTH], szCrosshair[35];
	int iSteamID = 0;
	bool bInBotObject = false;

	while (!hFile.EndOfFile() && hFile.ReadLine(szLine, sizeof(szLine)))
	{
		TrimString(szLine);

		if (!bInBotObject)
		{
			if (ExtractJsonObjectKey(szLine, szKey, sizeof(szKey)))
			{
				bInBotObject = true;
				iSteamID = 0;
				szCrosshair[0] = '\0';
			}
		}
		else if (StrContains(szLine, "\"steamid\"", false) != -1)
		{
			iSteamID = ExtractJsonIntValue(szLine);
		}
		else if (StrContains(szLine, "\"crosshair_code\"", false) != -1)
		{
			ExtractJsonStringValue(szLine, szCrosshair, sizeof(szCrosshair));
		}
		else if (szLine[0] == '}')
		{
			StoreBotInfo(szKey, iSteamID, szCrosshair);
			bInBotObject = false;
		}
	}

	if (bInBotObject)
		StoreBotInfo(szKey, iSteamID, szCrosshair);

	delete hFile;
}

public int Native_GetBotAccountID(Handle plugins, int numParams)
{
	int client = GetNativeCell(1);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index or not a bot [%i]", client);
		return -1;
	}

	return g_iAccountID[client];
}

public int Native_GetBotSteamID64(Handle plugins, int numParams)
{
	int client = GetNativeCell(1);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index or not a bot [%i]", client);
		return -1;
	}
	
	return SetNativeString(2, g_szSteamID64[client], GetNativeCell(3)) == SP_ERROR_NONE;
}

public int Native_GetBotCrosshairCode(Handle plugins, int numParams)
{
	int client = GetNativeCell(1);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index or not a bot [%i]", client);
		return 0;
	}

	char szBotName[MAX_NAME_LENGTH], szNameLower[MAX_NAME_LENGTH], szCrosshair[35];
	GetClientName(client, szBotName, sizeof(szBotName));
	strcopy(szNameLower, sizeof(szNameLower), szBotName);
	String_ToLower(szNameLower, szNameLower, sizeof(szNameLower));

	if (!g_smBotCrosshairs.GetString(szNameLower, szCrosshair, sizeof(szCrosshair)))
		return 0;

	return SetNativeString(2, szCrosshair, GetNativeCell(3)) == SP_ERROR_NONE;
}

public int Native_IsBotInDatabase(Handle plugins, int numParams)
{
	int client = GetNativeCell(1);
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index or not a bot [%i]", client);
		return 0;
	}

	char szBotName[MAX_NAME_LENGTH], szNameLower[MAX_NAME_LENGTH];
	GetClientName(client, szBotName, sizeof(szBotName));
	strcopy(szNameLower, sizeof(szNameLower), szBotName);
	String_ToLower(szNameLower, szNameLower, sizeof(szNameLower));

	int iDummy;
	return g_smBotSteamIDs.GetValue(szNameLower, iDummy);
}

public int Native_IsNameInBotDatabase(Handle plugins, int numParams)
{
	char szName[MAX_NAME_LENGTH], szNameLower[MAX_NAME_LENGTH];
	GetNativeString(1, szName, sizeof(szName));
	strcopy(szNameLower, sizeof(szNameLower), szName);
	String_ToLower(szNameLower, szNameLower, sizeof(szNameLower));

	int iDummy;
	return g_smBotSteamIDs.GetValue(szNameLower, iDummy);
}

public void OnClientSettingsChanged(int client)
{
	ApplyBotSteamID(client);
}

public void OnClientPutInServer(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsFakeClient(client))
		CreateTimer(0.1, Timer_ApplyBotSteamID, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ApplyBotSteamID(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	ApplyBotSteamID(client);
	return Plugin_Stop;
}

public Action Timer_ApplyAllBotSteamIDs(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		ApplyBotSteamID(client);
	}

	return Plugin_Stop;
}

bool ApplyBotSteamID(int client)
{
	if (!IsValidClient(client) || !IsFakeClient(client))
		return false;

	int iTableIdx = FindStringTable("userinfo");
	if (iTableIdx == INVALID_STRING_TABLE)
		return false;

	char szUserInfo[PLAYER_INFO_LEN];
	if (!GetStringTableData(iTableIdx, client - 1, szUserInfo, PLAYER_INFO_LEN))
		return false;

	int iAccountID = g_iAccountID[client];
	if (!iAccountID)
	{
		char szBotName[MAX_NAME_LENGTH];
		GetClientName(client, szBotName, sizeof(szBotName));

		if (!GetAccountID(szBotName, iAccountID))
			iAccountID = Math_GetRandomInt(3, 2147483647);
	}

	int iSteamIdHigh = 16781313;

	szUserInfo[PlayerInfo_XUID] = iSteamIdHigh;
	szUserInfo[PlayerInfo_XUID + 1] = iSteamIdHigh >> 8;
	szUserInfo[PlayerInfo_XUID + 2] = iSteamIdHigh >> 16;
	szUserInfo[PlayerInfo_XUID + 3] = iSteamIdHigh >> 24;

	szUserInfo[PlayerInfo_XUID + 7] = iAccountID;
	szUserInfo[PlayerInfo_XUID + 6] = iAccountID >> 8;
	szUserInfo[PlayerInfo_XUID + 5] = iAccountID >> 16;
	szUserInfo[PlayerInfo_XUID + 4] = iAccountID >> 24;

	char szSteamID32[32];
	Format(szSteamID32, sizeof(szSteamID32), "STEAM_1:%i:%i", iAccountID & 1, iAccountID >> 1);
	Format(szUserInfo[PlayerInfo_SteamID], 32, szSteamID32);
	AccountIDToSteamID64(iAccountID, g_szSteamID64[client], MAX_COMMUNITYID_LENGTH);

	szUserInfo[PlayerInfo_AccountID] = iAccountID;
	szUserInfo[PlayerInfo_AccountID + 1] = iAccountID >> 8;
	szUserInfo[PlayerInfo_AccountID + 2] = iAccountID >> 16;
	szUserInfo[PlayerInfo_AccountID + 3] = iAccountID >> 24;

	szUserInfo[PlayerInfo_IsFakePlayer] = 0;

	bool lockTable = LockStringTables(false);
	SetStringTableData(iTableIdx, client - 1, szUserInfo, PLAYER_INFO_LEN);
	LockStringTables(lockTable);

	g_iAccountID[client] = iAccountID;
	return true;
}

public void OnClientDisconnect(int client)
{
	g_iAccountID[client] = 0;
	g_szSteamID64[client][0] = '\0';
}

bool GetAccountID(const char[] szName, int &iAccountID)
{
	char szNameLower[MAX_NAME_LENGTH];
	strcopy(szNameLower, sizeof(szNameLower), szName);
	String_ToLower(szNameLower, szNameLower, sizeof(szNameLower));

	return g_smBotSteamIDs.GetValue(szNameLower, iAccountID);
}

void StoreBotInfo(const char[] szName, int iSteamID, const char[] szCrosshair)
{
	if (szName[0] == '\0' || iSteamID <= 0)
		return;

	char szNameLower[MAX_NAME_LENGTH];
	strcopy(szNameLower, sizeof(szNameLower), szName);
	String_ToLower(szNameLower, szNameLower, sizeof(szNameLower));

	g_smBotSteamIDs.SetValue(szNameLower, iSteamID);
	g_smBotCrosshairs.SetString(szNameLower, szCrosshair);
}

bool ExtractJsonObjectKey(const char[] szLine, char[] szKey, int iSize)
{
	int iFirstQuote = -1;
	int iSecondQuote = -1;

	for (int i = 0; szLine[i] != '\0'; i++)
	{
		if (szLine[i] == '"')
		{
			iFirstQuote = i;
			break;
		}
	}

	if (iFirstQuote == -1)
		return false;

	for (int i = iFirstQuote + 1; szLine[i] != '\0'; i++)
	{
		if (szLine[i] == '"')
		{
			iSecondQuote = i;
			break;
		}
	}

	if (iSecondQuote == -1)
		return false;

	bool bHasObjectStart = false;
	for (int i = iSecondQuote + 1; szLine[i] != '\0'; i++)
	{
		if (szLine[i] == '{')
		{
			bHasObjectStart = true;
			break;
		}
	}

	if (!bHasObjectStart)
		return false;

	int iOutput = 0;
	for (int i = iFirstQuote + 1; i < iSecondQuote && iOutput < iSize - 1; i++)
	{
		szKey[iOutput++] = szLine[i];
	}

	szKey[iOutput] = '\0';
	return szKey[0] != '\0';
}

int ExtractJsonIntValue(const char[] szLine)
{
	int iValue = 0;
	bool bHasDigit = false;

	for (int i = 0; szLine[i] != '\0'; i++)
	{
		if (szLine[i] >= '0' && szLine[i] <= '9')
		{
			bHasDigit = true;
			iValue = iValue * 10 + szLine[i] - '0';
		}
		else if (bHasDigit)
		{
			break;
		}
	}

	return iValue;
}

void ExtractJsonStringValue(const char[] szLine, char[] szValue, int iSize)
{
	szValue[0] = '\0';

	int iColon = -1;
	for (int i = 0; szLine[i] != '\0'; i++)
	{
		if (szLine[i] == ':')
		{
			iColon = i;
			break;
		}
	}

	if (iColon == -1)
		return;

	int iFirstQuote = -1;
	int iSecondQuote = -1;

	for (int i = iColon + 1; szLine[i] != '\0'; i++)
	{
		if (szLine[i] == '"')
		{
			iFirstQuote = i;
			break;
		}
	}

	if (iFirstQuote == -1)
		return;

	for (int i = iFirstQuote + 1; szLine[i] != '\0'; i++)
	{
		if (szLine[i] == '"')
		{
			iSecondQuote = i;
			break;
		}
	}

	if (iSecondQuote == -1)
		return;

	int iOutput = 0;
	for (int i = iFirstQuote + 1; i < iSecondQuote && iOutput < iSize - 1; i++)
	{
		szValue[iOutput++] = szLine[i];
	}

	szValue[iOutput] = '\0';
}

stock void String_ToLower(const char[] input, char[] output, int size)
{
	int length = strlen(input);
	if (length >= size)
		length = size - 1;

	for (int i = 0; i < length; i++)
	{
		output[i] = CharToLower(input[i]);
	}

	output[length] = '\0';
}

stock int Math_GetRandomInt(int min, int max)
{
	return GetURandomInt() % (max - min + 1) + min;
}

stock void AccountIDToSteamID64(int accountID, char[] buffer, int size)
{
	char base[18] = "76561197960265728";
	char account[12];
	IntToString(accountID, account, sizeof(account));

	char reversed[20];
	int baseIndex = strlen(base) - 1;
	int accountIndex = strlen(account) - 1;
	int carry = 0;
	int length = 0;

	while (baseIndex >= 0 || accountIndex >= 0 || carry)
	{
		int digit = carry;
		if (baseIndex >= 0)
			digit += base[baseIndex--] - '0';

		if (accountIndex >= 0)
			digit += account[accountIndex--] - '0';

		reversed[length++] = digit % 10 + '0';
		carry = digit / 10;
	}

	int outputIndex = 0;
	while (length > 0 && outputIndex < size - 1)
	{
		buffer[outputIndex++] = reversed[--length];
	}

	buffer[outputIndex] = '\0';
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}

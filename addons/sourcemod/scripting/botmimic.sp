/**
 * Bot Mimic - Record your movments and have bots playing it back.
 * by Peace-Maker
 * visit http://wcfan.de
 * 
 * Changelog:
 * 2.0   - 22.07.2013: Released rewrite
 * 2.0.1 - 01.08.2013: Actually made DHooks an optional dependency.
 * 2.1   - 02.10.2014: Added bookmarks and pausing/resuming while recording. Fixed crashes and problems with CS:GO.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
#include <botmimic>
#include <eItems>

#undef REQUIRE_EXTENSIONS
#include <dhooks>

#pragma newdecls required

native int BB_FilterBotReactionButtons(int client, int buttons);

#define PLUGIN_VERSION "2.1"

#define BM_MAGIC 0xdeadbeef

// New in 0x02: bookmarkCount and bookmarks list
#define BINARY_FORMAT_VERSION 0x02

enum
{
	BM_DEFIDX_GLOCK = 4,
	BM_DEFIDX_FAMAS = 10,
	BM_DEFIDX_M4A1S = 60,
	BM_DEFIDX_USPS = 61
};

#define DEFAULT_RECORD_FOLDER "data/botmimic/"

// Flags set in FramInfo.additionalFields to inform, that there's more info afterwards.
#define ADDITIONAL_FIELD_TELEPORTED_ORIGIN (1<<0)
#define ADDITIONAL_FIELD_TELEPORTED_ANGLES (1<<1)
#define ADDITIONAL_FIELD_TELEPORTED_VELOCITY (1<<2)

enum struct FrameInfo {
    int playerButtons;
    int playerImpulse;
    float actualVelocity[3];
    float predictedVelocity[3];
    float predictedAngles[2]; // Ignore roll
	float origin[3];
    CSWeaponID newWeapon;
    int playerSubtype;
    int playerSeed;
    int additionalFields; // see ADDITIONAL_FIELD_* defines
}

enum struct AdditionalTeleport {
	float atOrigin[3];
	float atAngles[3];
	float atVelocity[3];
	int atFlags;
}


enum struct FileHeader {
	int FH_binaryFormatVersion;
	int FH_recordEndTime;
	char FH_recordName[MAX_RECORD_NAME_LENGTH];
	int FH_tickCount;
	int FH_bookmarkCount;
	float FH_initialPosition[3];
	float FH_initialAngles[3];
	ArrayList FH_bookmarks;
	ArrayList FH_frames;
    bool FH_releaseWhenIdle;
}

enum struct Bookmarks {
	int BKM_frame;
	int BKM_additionalTeleportTick;
	char BKM_name[MAX_BOOKMARK_NAME_LENGTH];
}

// Used to fire the OnPlayerMimicBookmark effciently during playback
enum struct BookmarkWhileMimicing {
	int BWM_frame; // The frame this bookmark was saved in
	int BWM_index; // The index into the FH_bookmarks array in the fileheader for the corresponding bookmark (to get the name)
}

// Initial position and angles cached for playback.
float g_fInitialPosition[MAXPLAYERS+1][3];
float g_fInitialAngles[MAXPLAYERS+1][3];

int g_iCurrentAdditionalTeleportIndex[MAXPLAYERS+1];

StringMap g_hLoadedRecords;
StringMap g_hLoadedRecordsAdditionalTeleport;
StringMap g_hLoadedRecordsCategory;
ArrayList g_hSortedRecordList;
ArrayList g_hSortedCategoryList;

ArrayList g_hBotMimicsRecord[MAXPLAYERS+1] = {null,...};
int g_iBotMimicTick[MAXPLAYERS+1] = {0,...};
int g_iBotMimicRecordTickCount[MAXPLAYERS+1] = {0,...};
int g_iBotActiveWeapon[MAXPLAYERS+1] = {-1,...};
bool g_bBotSwitchedWeapon[MAXPLAYERS+1];
BMPlaybackMode g_PlaybackMode[MAXPLAYERS+1];
int g_PlaybackSerial[MAXPLAYERS+1];
bool g_FirstFramePending[MAXPLAYERS+1];
bool g_MapEnding;
CSWeaponID g_InitialRecordedWeapon[MAXPLAYERS+1];
bool g_bValidTeleportCall[MAXPLAYERS+1];
BookmarkWhileMimicing g_iBotMimicNextBookmarkTick[MAXPLAYERS+1];

GlobalForward g_hfwdOnPlayerStartsMimicing;
GlobalForward g_hfwdOnPlayerStopsMimicing;
GlobalForward g_hfwdOnPlayerMimicLoops;
GlobalForward g_hfwdOnPlayerMimicBookmark;
GlobalForward g_hfwdOnPlayerMimicFrame;

// DHooks/SDK
Handle g_hTeleport;
Handle g_hSetOrigin;
Handle g_hSetVelocity;
Handle g_hSwitchWeaponCall;


public Plugin myinfo = 
{
	name = "Bot Mimic",
	author = "Jannik \"Peace-Maker\" Hartung",
	description = "Bots mimic your movements!",
	version = PLUGIN_VERSION,
	url = "http://www.wcfan.de/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("BB_FilterBotReactionButtons");
	RegPluginLibrary("botmimic");
	CreateNative("BotMimic_IsPlayerMimicing", IsPlayerMimicing);
	CreateNative("BotMimic_GetRecordPlayerMimics", GetRecordPlayerMimics);
	CreateNative("BotMimic_PlayRecordFromFile", PlayRecordFromFile);
	CreateNative("BotMimic_PlayRecordFromFileEx", PlayRecordFromFileEx);
	CreateNative("BotMimic_PlayRecordByName", PlayRecordByName);
	CreateNative("BotMimic_ResetPlayback", ResetPlayback);
	CreateNative("BotMimic_GoToBookmark", GoToBookmark);
	CreateNative("BotMimic_StopPlayerMimic", StopPlayerMimic);
	CreateNative("BotMimic_GetFileHeaders", GetFileHeaders);
	CreateNative("BotMimic_GetLoadedRecordCategoryList", GetLoadedRecordCategoryList);
	CreateNative("BotMimic_GetLoadedRecordList", GetLoadedRecordList);
	CreateNative("BotMimic_GetFileCategory", GetFileCategory);
	CreateNative("BotMimic_GetRecordBookmarks", GetRecordBookmarks);
	
	g_hfwdOnPlayerStartsMimicing = new GlobalForward("BotMimic_OnPlayerStartsMimicing", ET_Hook, Param_Cell, Param_String, Param_String, Param_String);
	g_hfwdOnPlayerStopsMimicing = new GlobalForward("BotMimic_OnPlayerStopsMimicing", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);
	g_hfwdOnPlayerMimicLoops = new GlobalForward("BotMimic_OnPlayerMimicLoops", ET_Ignore, Param_Cell);
	g_hfwdOnPlayerMimicBookmark = new GlobalForward("BotMimic_OnPlayerMimicBookmark", ET_Ignore, Param_Cell, Param_String);
	g_hfwdOnPlayerMimicFrame = new GlobalForward("BotMimic_OnPlayerMimicFrame", ET_Hook, Param_Cell, Param_Cell, Param_Array, Param_Array);
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	ConVar hVersion = CreateConVar("sm_botmimic_version", PLUGIN_VERSION, "Bot Mimic version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	if(hVersion != null)
	{
		hVersion.SetString(PLUGIN_VERSION);
		hVersion.AddChangeHook(ConVar_VersionChanged);
	}
	
	// Maps path to .rec -> record enum
	g_hLoadedRecords = new StringMap();
	g_hLoadedRecordsAdditionalTeleport = new StringMap();
	
	// Maps path to .rec -> record category
	g_hLoadedRecordsCategory = new StringMap();
	
	// Save all paths to .rec files in the trie sorted by time
	g_hSortedRecordList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSortedCategoryList = new ArrayList(ByteCountToCells(64));
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	
	if(LibraryExists("dhooks"))
	{
		OnLibraryAdded("dhooks");
	}
	
	GameData hGameConfig = new GameData("botmimic.games");
	if (hGameConfig == null)
		SetFailState("Failed to find botstuff.games game config.");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBaseEntity::SetLocalOrigin");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	if ((g_hSetOrigin = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseEntity::SetLocalOrigin signature!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Signature, "CBaseEntity::SetAbsVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	if ((g_hSetVelocity = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for CBaseEntity::SetAbsVelocity signature!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "Weapon_Switch");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hSwitchWeaponCall = EndPrepSDKCall()) == null)SetFailState("Failed to create SDKCall for Weapon_Switch offset!");
	
	delete hGameConfig;
}

public void ConVar_VersionChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.SetString(PLUGIN_VERSION);
}

/**
 * Public forwards
 */
public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "dhooks") && g_hTeleport == null)
	{
		// Optionally setup a hook on CBaseEntity::Teleport to keep track of sudden place changes
		GameData hGameData = new GameData("botmimic.games");
		if(hGameData == null)
			return;
		int iOffset = hGameData.GetOffset("Teleport");
		delete hGameData;
		if(iOffset == -1)
			return;
		
		g_hTeleport = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, DHooks_OnTeleport);
		if(g_hTeleport == null)
			return;
		DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
		DHookAddParam(g_hTeleport, HookParamType_ObjectPtr);
		DHookAddParam(g_hTeleport, HookParamType_VectorPtr);
		if(GetEngineVersion() == Engine_CSGO)
			DHookAddParam(g_hTeleport, HookParamType_Bool);
		
		for(int i=1;i<=MaxClients;i++)
		{
			if(IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "dhooks"))
	{
		g_hTeleport = null;
	}
}

public void OnMapStart()
{
    g_MapEnding = false;
	// Clear old records for old map
	int iSize = g_hSortedRecordList.Length;
	char sPath[PLATFORM_MAX_PATH];
	FileHeader iFileHeader;
	ArrayList hAdditionalTeleport;
	for(int i=0;i<iSize;i++)
	{
		g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
		if (!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader)))
		{
			LogError("Internal state error. %s was in the sorted list, but not in the actual storage.", sPath);
			continue;
		}
		if(iFileHeader.FH_frames != null)
			delete iFileHeader.FH_frames;
		if(iFileHeader.FH_bookmarks != null)
			delete iFileHeader.FH_bookmarks;
		if(g_hLoadedRecordsAdditionalTeleport.GetValue(sPath, hAdditionalTeleport))
			delete hAdditionalTeleport;
	}
	g_hLoadedRecords.Clear();
	g_hLoadedRecordsAdditionalTeleport.Clear();
	g_hLoadedRecordsCategory.Clear();
	g_hSortedRecordList.Clear();
	g_hSortedCategoryList.Clear();
	
	// Create our record directory
	BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
	if(!DirExists(sPath))
		CreateDirectory(sPath, 511);
	
	// Check for categories
	DirectoryListing hDir = OpenDirectory(sPath);
	if(hDir == null)
		return;
	
	char sFile[64];
	FileType fileType;
	while(hDir.GetNext(sFile, sizeof(sFile), fileType))
	{
		switch(fileType)
		{
			// Check all directories for records on this map
			case FileType_Directory:
			{
				// INFINITE RECURSION ANYONE?
				if(StrEqual(sFile, ".") || StrEqual(sFile, ".."))
					continue;
				
				BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, sFile);
				ParseRecordsInDirectory(sPath, sFile, false);
			}
		}
		
	}
	delete hDir;
}

public void OnMapEnd()
{
    g_MapEnding = true;
    for (int client = 1; client <= MaxClients; client++)
        if (g_hBotMimicsRecord[client] != null)
            StopMimicPlayback(client);
}

public void OnPluginEnd()
{
    OnMapEnd();
}

public void OnClientPutInServer(int client)
{
	if(g_hTeleport != null)
		DHookEntity(g_hTeleport, false, client);
}

public void OnClientDisconnect(int client)
{
    if (g_hBotMimicsRecord[client] != null)
        StopMimicPlayback(client);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	// Bot is mimicing something
	if(g_hBotMimicsRecord[client] == null)
		return Plugin_Continue;

	// Is this a valid living bot?
	if(!IsPlayerAlive(client) || GetClientTeam(client) < CS_TEAM_T)
		return Plugin_Continue;
	
	if(g_iBotMimicTick[client] >= g_iBotMimicRecordTickCount[client])
	{
		BotMimic_StopPlayerMimic(client);
		return Plugin_Continue;
	}
	
	FrameInfo iFrame;
	g_hBotMimicsRecord[client].GetArray(g_iBotMimicTick[client], iFrame, sizeof(FrameInfo));

	bool liveInput = g_PlaybackMode[client] == BMPlayback_LiveInput;
    int playbackSerial = g_PlaybackSerial[client];
    if (liveInput)
    {
        Action result;
        Call_StartForward(g_hfwdOnPlayerMimicFrame);
        Call_PushCell(client);
        Call_PushCell(g_iBotMimicTick[client]);
        Call_PushArray(iFrame.origin, 3);
        Call_PushArray(iFrame.predictedVelocity, 3);
        Call_Finish(result);
        if (g_PlaybackSerial[client] != playbackSerial || g_hBotMimicsRecord[client] == null)
            return Plugin_Continue;
        if (result >= Plugin_Handled)
        {
            StopMimicPlayback(client);
            return Plugin_Continue;
        }
        if (result == Plugin_Changed)
            return Plugin_Continue;
        if (g_FirstFramePending[client] && iFrame.newWeapon == CSWeapon_NONE)
            iFrame.newWeapon = g_InitialRecordedWeapon[client];
    }

    buttons = iFrame.playerButtons;
    if (!liveInput)
        BlockBotDisruptiveAltFire(client, buttons);
	impulse = iFrame.playerImpulse;
	Array_Copy(iFrame.predictedVelocity, vel, 3);
	
	Array_Copy(iFrame.predictedAngles, angles, 2);
    if (liveInput)
    {
        g_bValidTeleportCall[client] = true;
        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
    }
	subtype = iFrame.playerSubtype;
	seed = iFrame.playerSeed;
	weapon = 0;
	
	float fActualVelocity[3];
	Array_Copy(iFrame.actualVelocity, fActualVelocity, 3);
	
	// We're supposed to teleport stuff?
	if(iFrame.additionalFields & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN|ADDITIONAL_FIELD_TELEPORTED_ANGLES|ADDITIONAL_FIELD_TELEPORTED_VELOCITY))
	{
		AdditionalTeleport iAT;
		ArrayList hAdditionalTeleport;
		char sPath[PLATFORM_MAX_PATH];
		GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
		g_hLoadedRecordsAdditionalTeleport.GetValue(sPath, hAdditionalTeleport);
		hAdditionalTeleport.GetArray(g_iCurrentAdditionalTeleportIndex[client], iAT, sizeof(AdditionalTeleport));
		
		float fOrigin[3], fAngles[3], fVelocity[3];
		Array_Copy(iAT.atOrigin, fOrigin, 3);
		Array_Copy(iAT.atAngles, fAngles, 3);
		Array_Copy(iAT.atVelocity, fVelocity, 3);
		
		// The next call to Teleport is ok.
		g_bValidTeleportCall[client] = true;
		
		// THATS STUPID!
		// Only pass the arguments, if they were set..
		if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_ORIGIN)
		{
			if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
			{
				if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
				{
					SDKCall(g_hSetOrigin, client, fOrigin);
					TeleportEntity(client, NULL_VECTOR, fAngles, NULL_VECTOR);
					SDKCall(g_hSetVelocity, client, fVelocity);
				}
				else
				{
					SDKCall(g_hSetOrigin, client, fOrigin);
					TeleportEntity(client, NULL_VECTOR, fAngles, NULL_VECTOR);
				}
			}
			else
			{
				if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
				{
					SDKCall(g_hSetOrigin, client, fOrigin);
					SDKCall(g_hSetVelocity, client, fVelocity);
				}
				else
					SDKCall(g_hSetOrigin, client, fOrigin);
			}
		}
		else
		{
			if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
			{
				if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
				{
					TeleportEntity(client, NULL_VECTOR, fAngles, NULL_VECTOR);
					SDKCall(g_hSetVelocity, client, fVelocity);
				}
				else
					TeleportEntity(client, NULL_VECTOR, fAngles, NULL_VECTOR);
			}
			else
			{
				if(iAT.atFlags & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
					SDKCall(g_hSetVelocity, client, fVelocity);
			}
		}
		
		g_iCurrentAdditionalTeleportIndex[client]++;
	}
	
	// This is the first tick. Teleport him to the initial position
	if (liveInput)
    {
        if (g_FirstFramePending[client])
        {
            g_FirstFramePending[client] = false;
            Call_StartForward(g_hfwdOnPlayerMimicLoops);
            Call_PushCell(client);
            Call_Finish();
        }
    }
    else if(g_iBotMimicTick[client] == 0)
    {
		g_bValidTeleportCall[client] = true;
		TeleportEntity(client, g_fInitialPosition[client], g_fInitialAngles[client], fActualVelocity);
		SDKCall(g_hSwitchWeaponCall, client, GetPlayerWeaponSlot(client, CS_SLOT_KNIFE), 0);
		
		Call_StartForward(g_hfwdOnPlayerMimicLoops);
		Call_PushCell(client);
		Call_Finish();
	}
	else
	{
		g_bValidTeleportCall[client] = true;
		
		SDKCall(g_hSetOrigin, client, iFrame.origin);
		SDKCall(g_hSetVelocity, client, fActualVelocity);
		TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
	}
	
	if (g_PlaybackSerial[client] != playbackSerial || g_hBotMimicsRecord[client] == null)
        return Plugin_Changed;

    if(iFrame.newWeapon != CSWeapon_NONE)
    {
		char sAlias[64];
		CS_WeaponIDToAlias(iFrame.newWeapon, sAlias, sizeof(sAlias));
		
		Format(sAlias, sizeof(sAlias), "weapon_%s", sAlias);
		
		if(BotMimic_ClientHasWeapon(client, sAlias))
		{
			weapon = BotMimic_GetClientWeapon(client, sAlias);
			g_iBotActiveWeapon[client] = weapon;
			g_bBotSwitchedWeapon[client] = true;
			SDKCall(g_hSwitchWeaponCall, client, weapon, 0);
		}
		else
		{
			weapon = GetPlayerWeaponSlot(client, BotMimic_GetWeaponSlotByClassName(sAlias));
            if (liveInput && !IsValidEntity(weapon))
            {
                StopMimicPlayback(client);
                return Plugin_Changed;
            }
            g_iBotActiveWeapon[client] = weapon;
			g_bBotSwitchedWeapon[client] = true;
			SDKCall(g_hSwitchWeaponCall, client, weapon, 0);
		}
	}
	// Switch the weapon on the next frame after it was selected.
	else if (g_bBotSwitchedWeapon[client])
	{
		g_bBotSwitchedWeapon[client] = false;
		if (!liveInput || (IsValidEntity(g_iBotActiveWeapon[client])
            && GetEntPropEnt(g_iBotActiveWeapon[client], Prop_Send, "m_hOwnerEntity") == client))
            SDKCall(g_hSwitchWeaponCall, client, g_iBotActiveWeapon[client], 0);
    }
    if (liveInput)
        BlockBotDisruptiveAltFire(client, buttons);

    // See if there's a bookmark on this tick
	if(g_iBotMimicTick[client] == g_iBotMimicNextBookmarkTick[client].BWM_frame)
	{
		// Get the file header of the current playing record.
		char sPath[PLATFORM_MAX_PATH];
		GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
		FileHeader iFileHeader;
		g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));

		Bookmarks iBookmark;
		iFileHeader.FH_bookmarks.GetArray(g_iBotMimicNextBookmarkTick[client].BWM_index, iBookmark, sizeof(Bookmarks));
		
		// Cache the next tick in which we should fire the forward.
		UpdateNextBookmarkTick(client);
		
		// Call the forward
		Call_StartForward(g_hfwdOnPlayerMimicBookmark);
		Call_PushCell(client);
		Call_PushString(iBookmark.BKM_name);
		Call_Finish();
	}
	
	g_iBotMimicTick[client]++;
	
	if (GetFeatureStatus(FeatureType_Native, "BB_FilterBotReactionButtons") == FeatureStatus_Available)
		buttons = BB_FilterBotReactionButtons(client, buttons);

	return Plugin_Changed;
}

/**
 * Event Callbacks
 */
public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	// Restart moving on spawn!
	if(g_hBotMimicsRecord[client] != null)
		BotMimic_StopPlayerMimic(client);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client))
		return;
	
	if(g_hBotMimicsRecord[client] != null)
		BotMimic_StopPlayerMimic(client);
}


/**
 * SDKHooks Callbacks
 */
// Don't allow mimicing players any other weapon than the one recorded!!
public Action Hook_WeaponCanSwitchTo(int client, int weapon)
{
	if(g_hBotMimicsRecord[client] == null)
		return Plugin_Continue;
	
	if(g_iBotActiveWeapon[client] != weapon)
		return Plugin_Stop;

	return Plugin_Continue;
}

/**
 * DHooks Callbacks
 */
public MRESReturn DHooks_OnTeleport(int client, Handle hParams)
{
	// This one is currently mimicing something.
	if(g_hBotMimicsRecord[client] != null)
	{
		// We didn't allow that teleporting. STOP THAT.
		if(!g_bValidTeleportCall[client])
			return MRES_Supercede;
		g_bValidTeleportCall[client] = false;
		return MRES_Ignored;
	}
	
	return MRES_Ignored;
}

/**
 * Natives
 */
public int IsPlayerMimicing(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}
	
	return g_hBotMimicsRecord[client] != null;
}

public int GetRecordPlayerMimics(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return -1;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return -1;
	}
	
	int iLen = GetNativeCell(3);
	char[] sPath = new char[iLen];
	GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, iLen);
	SetNativeString(2, sPath, iLen);
	
	return 1;
}

public int GoToBookmark(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return -1;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return -1;
	}
	
	char sBookmarkName[MAX_BOOKMARK_NAME_LENGTH];
	GetNativeString(2, sBookmarkName, sizeof(sBookmarkName));
	
	// Get the file header
	char sPath[PLATFORM_MAX_PATH];
	GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
	
	FileHeader iFileHeader;
	g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
	
	// Get the bookmark with this name
	Bookmarks iBookmark;
	int	iBookmarkIndex;
	bool bBookmarkFound;
	for(;iBookmarkIndex<iFileHeader.FH_bookmarkCount;iBookmarkIndex++)
	{
		iFileHeader.FH_bookmarks.GetArray(iBookmarkIndex, iBookmark, sizeof(Bookmarks));
		if(StrEqual(iBookmark.BKM_name, sBookmarkName, false))
		{
			bBookmarkFound = true;
			break;
		}
	}
	
	if(!bBookmarkFound)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "There is no bookmark named \"%s\" in this record.", sBookmarkName);
		return -1;
	}
	
	g_PlaybackSerial[client]++;
    g_iBotMimicTick[client] = iBookmark.BKM_frame;
	g_iCurrentAdditionalTeleportIndex[client] = iBookmark.BKM_additionalTeleportTick;
	
	// Remember that we're now at this bookmark.
	g_iBotMimicNextBookmarkTick[client].BWM_frame = iBookmark.BKM_frame;
	g_iBotMimicNextBookmarkTick[client].BWM_index = iBookmarkIndex;
	
	return 1;
}

public int StopPlayerMimic(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return -1;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return -1;
	}
	
	StopMimicPlayback(client);
    return 1;
}

void StopMimicPlayback(int client)
{
    char sPath[PLATFORM_MAX_PATH];
    GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));

    g_PlaybackSerial[client]++;
    g_PlaybackMode[client] = BMPlayback_Legacy;
    g_FirstFramePending[client] = false;
    g_InitialRecordedWeapon[client] = CSWeapon_NONE;
    g_iBotActiveWeapon[client] = INVALID_ENT_REFERENCE;
    g_bBotSwitchedWeapon[client] = false;
    g_hBotMimicsRecord[client] = null;
	g_iBotMimicTick[client] = 0;
	g_iCurrentAdditionalTeleportIndex[client] = 0;
	g_iBotMimicRecordTickCount[client] = 0;
	g_bValidTeleportCall[client] = false;
	g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
	g_iBotMimicNextBookmarkTick[client].BWM_index = -1;
	
	FileHeader iFileHeader;
	g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
	
	if (IsClientInGame(client))
        SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);
	
	char sCategory[64];
	g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory));
	
	Call_StartForward(g_hfwdOnPlayerStopsMimicing);
	Call_PushCell(client);
	Call_PushString(iFileHeader.FH_recordName);
	Call_PushString(sCategory);
	Call_PushString(sPath);
    Call_Finish();
    ReleaseUnusedFrames(sPath);
}

void ReleaseUnusedFrames(const char[] path)
{
    FileHeader header;
    if (!g_hLoadedRecords.GetArray(path, header, sizeof(FileHeader))
        || !header.FH_releaseWhenIdle || header.FH_frames == null)
        return;
    for (int client = 1; client <= MaxClients; client++)
        if (g_hBotMimicsRecord[client] == header.FH_frames)
            return;
    delete header.FH_frames;
    ArrayList teleports;
    if (g_hLoadedRecordsAdditionalTeleport.GetValue(path, teleports))
    {
        delete teleports;
        g_hLoadedRecordsAdditionalTeleport.Remove(path);
    }
    g_hLoadedRecords.SetArray(path, header, sizeof(FileHeader));
}

public int PlayRecordFromFile(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return view_as<int>(BM_BadClient);
	}
	
	int iLen;
	GetNativeStringLength(2, iLen);
	char[] sPath = new char[iLen+1];
	GetNativeString(2, sPath, iLen+1);
	
	if(!FileExists(sPath))
		return view_as<int>(BM_FileNotFound);
	
	return view_as<int>(PlayRecord(client, sPath));
}

public int PlayRecordFromFileEx(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return view_as<int>(BM_BadClient);
    int startFrame = GetNativeCell(3);
    BMPlaybackMode mode = view_as<BMPlaybackMode>(GetNativeCell(4));
    if (startFrame < 0 || (mode != BMPlayback_Legacy && mode != BMPlayback_LiveInput))
        return view_as<int>(BM_BadParameter);
    char path[PLATFORM_MAX_PATH];
    int length;
    GetNativeStringLength(2, length);
    if (length >= sizeof(path))
        return view_as<int>(BM_BadParameter);
    GetNativeString(2, path, sizeof(path));
    if (!FileExists(path))
        return view_as<int>(BM_FileNotFound);
    return view_as<int>(PlayRecord(client, path, startFrame, mode));
}

public int PlayRecordByName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return view_as<int>(BM_BadClient);
	}
	
	int iLen;
	GetNativeStringLength(2, iLen);
	char[] sName = new char[iLen+1];
	GetNativeString(2, sName, iLen+1);
	
	char sPath[PLATFORM_MAX_PATH];
	int iSize = g_hSortedRecordList.Length;
	FileHeader iFileHeader;
	int iRecentTimeStamp;
	char sRecentPath[PLATFORM_MAX_PATH];
	for(int i=0;i<iSize;i++)
	{
		g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
		g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
		if(StrEqual(sName, iFileHeader.FH_recordName))
		{
			if(iRecentTimeStamp == 0 || iRecentTimeStamp < iFileHeader.FH_recordEndTime)
			{
				iRecentTimeStamp = iFileHeader.FH_recordEndTime;
				strcopy(sRecentPath, sizeof(sRecentPath), sPath);
			}
		}
	}
	
	if(!iRecentTimeStamp || !FileExists(sRecentPath))
		return view_as<int>(BM_FileNotFound);
	
	return view_as<int>(PlayRecord(client, sRecentPath));
}

public int ResetPlayback(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return -1;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return -1;
	}
	
	g_PlaybackSerial[client]++;
    g_FirstFramePending[client] = true;
    g_InitialRecordedWeapon[client] = CSWeapon_NONE;
    g_bBotSwitchedWeapon[client] = false;
    if (g_PlaybackMode[client] == BMPlayback_LiveInput)
        g_iBotActiveWeapon[client] = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    g_iBotMimicTick[client] = 0;
    g_iCurrentAdditionalTeleportIndex[client] = 0;
    g_bValidTeleportCall[client] = false;
	g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
	g_iBotMimicNextBookmarkTick[client].BWM_index = -1;
	UpdateNextBookmarkTick(client);
	
	return 1;
}

public int GetFileHeaders(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen+1];
	GetNativeString(1, sPath, iLen+1);
	
	if(!FileExists(sPath))
	{
		return view_as<int>(BM_FileNotFound);
	}
	
	FileHeader iFileHeader;
	if(!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader)))
	{
		char sCategory[64];
		if(!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
			strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
		BMError error = LoadRecordFromFile(sPath, sCategory, iFileHeader, true, false);
		if(error != BM_NoError)
			return view_as<int>(error);
	}
	
	BMFileHeader iExposedFileHeader;
	iExposedFileHeader.BMFH_binaryFormatVersion = iFileHeader.FH_binaryFormatVersion;
	iExposedFileHeader.BMFH_recordEndTime = iFileHeader.FH_recordEndTime;
	strcopy(iExposedFileHeader.BMFH_recordName, MAX_RECORD_NAME_LENGTH, iFileHeader.FH_recordName);
	iExposedFileHeader.BMFH_tickCount = iFileHeader.FH_tickCount;
	Array_Copy(iFileHeader.FH_initialPosition, iExposedFileHeader.BMFH_initialPosition, 3);
	Array_Copy(iFileHeader.FH_initialAngles, iExposedFileHeader.BMFH_initialAngles, 3);
	iExposedFileHeader.BMFH_bookmarkCount = iFileHeader.FH_bookmarkCount;
	
	
	int iSize = sizeof(BMFileHeader);
	if(numParams > 2)
		iSize = GetNativeCell(3);
	if(iSize > sizeof(BMFileHeader))
		iSize = sizeof(BMFileHeader);
	
	SetNativeArray(2, iExposedFileHeader, iSize);
	return view_as<int>(BM_NoError);
}

public int GetLoadedRecordCategoryList(Handle plugin, int numParams)
{
	return view_as<int>(g_hSortedCategoryList);
}

public int GetLoadedRecordList(Handle plugin, int numParams)
{
	return view_as<int>(g_hSortedRecordList);
}

public int GetFileCategory(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen+1];
	GetNativeString(1, sPath, iLen+1);
	
	iLen = GetNativeCell(3);
	char[] sCategory = new char[iLen];
	bool bFound = g_hLoadedRecordsCategory.GetString(sPath, sCategory, iLen);
	
	SetNativeString(2, sCategory, iLen);
	return view_as<int>(bFound);
}

public int GetRecordBookmarks(Handle plugin, int numParams)
{
	int iLen;
	GetNativeStringLength(1, iLen);
	char[] sPath = new char[iLen+1];
	GetNativeString(1, sPath, iLen+1);
	
	if(!FileExists(sPath))
	{
		return view_as<int>(BM_FileNotFound);
	}
	
	FileHeader iFileHeader;
	if(!g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader)))
	{
		char sCategory[64];
		if(!g_hLoadedRecordsCategory.GetString(sPath, sCategory, sizeof(sCategory)))
			strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
		BMError error = LoadRecordFromFile(sPath, sCategory, iFileHeader, true, false);
		if(error != BM_NoError)
			return view_as<int>(error);
	}
	
	ArrayList hBookmarks = new ArrayList(ByteCountToCells(MAX_BOOKMARK_NAME_LENGTH));
	Bookmarks iBookmark;
	for(int i=0;i<iFileHeader.FH_bookmarkCount;i++)
	{
		iFileHeader.FH_bookmarks.GetArray(i, iBookmark, sizeof(Bookmarks));
		hBookmarks.PushString(iBookmark.BKM_name);
	}
	
	Handle hClone = CloneHandle(hBookmarks, plugin);
	delete hBookmarks;
	SetNativeCellRef(2, hClone);
	return view_as<int>(BM_NoError);
}


/**
 * Helper functions
 */

void ParseRecordsInDirectory(const char[] sPath, const char[] sCategory, bool subdir)
{
	char sMapFilePath[PLATFORM_MAX_PATH];
	// We already are in the map folder? Don't add it again!
	if(subdir)
	{
		strcopy(sMapFilePath, sizeof(sMapFilePath), sPath);
	}
	// We're in a category. add the mapname to load the correct records for the current map
	else
	{
		char sMapName[64];
		GetCurrentMap(sMapName, sizeof(sMapName));
		Format(sMapFilePath, sizeof(sMapFilePath), "%s/%s", sPath, sMapName);
	}
	
	DirectoryListing hDir = OpenDirectory(sMapFilePath);
	if(hDir == null)
		return;
	
	char sFile[64], sFilePath[PLATFORM_MAX_PATH];
	FileType fileType;
	FileHeader iFileHeader;
	while(hDir.GetNext(sFile, sizeof(sFile), fileType))
	{
		switch(fileType)
		{
			// This is a record for this map.
			case FileType_File:
			{
				Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
				LoadRecordFromFile(sFilePath, sCategory, iFileHeader, true, false);
			}
			// There's a subdir containing more records.
			case FileType_Directory:
			{
				// INFINITE RECURSION ANYONE?
				if(StrEqual(sFile, ".") || StrEqual(sFile, ".."))
					continue;
				
				Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
				ParseRecordsInDirectory(sFilePath, sCategory, true);
			}
		}
		
	}
	delete hDir;
}

BMError LoadRecordFromFile(const char[] path, const char[] sCategory, FileHeader headerInfo, bool onlyHeader, bool forceReload)
{
	if(!FileExists(path))
		return BM_FileNotFound;
	
	// Make sure the handle references are null in the input structure.
	headerInfo.FH_frames = null;
	headerInfo.FH_bookmarks = null;

	// Already loaded that file?
	bool bAlreadyLoaded = false;
	if(g_hLoadedRecords.GetArray(path, headerInfo, sizeof(FileHeader)))
	{
		// Header already loaded.
		if(onlyHeader && !forceReload)
			return BM_NoError;
		
		bAlreadyLoaded = true;
	}
	
	File hFile = OpenFile(path, "rb");
	if(hFile == null)
		return BM_FileNotFound;
	
	int iMagic;
	hFile.ReadInt32(iMagic);
	if(iMagic != BM_MAGIC)
	{
		delete hFile;
		return BM_BadFile;
	}
	
	int iBinaryFormatVersion;
	hFile.ReadUint8(iBinaryFormatVersion);
	headerInfo.FH_binaryFormatVersion = iBinaryFormatVersion;
	
	if(iBinaryFormatVersion > BINARY_FORMAT_VERSION)
	{
		delete hFile;
		return BM_NewerBinaryVersion;
	}
	
	int iRecordTime, iNameLength;
	hFile.ReadInt32(iRecordTime);
	hFile.ReadUint8(iNameLength);
	char[] sRecordName = new char[iNameLength+1];
	hFile.ReadString(sRecordName, iNameLength+1, iNameLength);
	sRecordName[iNameLength] = '\0';
	
	hFile.Read(headerInfo.FH_initialPosition, 3, 4);
	hFile.Read(headerInfo.FH_initialAngles, 2, 4);
	
	int iTickCount;
	hFile.ReadInt32(iTickCount);
	
	int iBookmarkCount;
	if(iBinaryFormatVersion >= 0x02)
	{
		hFile.ReadInt32(iBookmarkCount);
	}
	headerInfo.FH_bookmarkCount = iBookmarkCount;
	
	headerInfo.FH_recordEndTime = iRecordTime;
	strcopy(headerInfo.FH_recordName, MAX_RECORD_NAME_LENGTH, sRecordName);
	headerInfo.FH_tickCount = iTickCount;

	delete headerInfo.FH_frames;
	delete headerInfo.FH_bookmarks;
	ArrayList hAT;
	if(g_hLoadedRecordsAdditionalTeleport.GetValue(path, hAT))
	{
 		delete hAT;
 		g_hLoadedRecordsAdditionalTeleport.Remove(path);
	}
	
	//PrintToServer("Record %s:", sRecordName);
	//PrintToServer("File %s:", path);
	//PrintToServer("EndTime: %d, BinaryVersion: 0x%x, ticks: %d, initialPosition: %f,%f,%f, initialAngles: %f,%f,%f", iRecordTime, iBinaryFormatVersion, iTickCount, headerInfo.FH_initialPosition[0], headerInfo.FH_initialPosition[1], headerInfo.FH_initialPosition[2], headerInfo.FH_initialAngles[0], headerInfo.FH_initialAngles[1], headerInfo.FH_initialAngles[2]);
	
	if (iBookmarkCount > 0)
	{
		// Read in all bookmarks
		ArrayList hBookmarks = new ArrayList(sizeof(Bookmarks));
		
		Bookmarks iBookmark;
		for(int i=0;i<iBookmarkCount;i++)
		{
			hFile.ReadInt32(iBookmark.BKM_frame);
			hFile.ReadInt32(iBookmark.BKM_additionalTeleportTick);
			hFile.ReadString(iBookmark.BKM_name, MAX_BOOKMARK_NAME_LENGTH);
			hBookmarks.PushArray(iBookmark, sizeof(Bookmarks));
		}
		
		headerInfo.FH_bookmarks = hBookmarks;
	}
	
	g_hLoadedRecords.SetArray(path, headerInfo, sizeof(FileHeader));
	g_hLoadedRecordsCategory.SetString(path, sCategory);
	
	if(!bAlreadyLoaded)
		g_hSortedRecordList.PushString(path);
	
	if(g_hSortedCategoryList.FindString(sCategory) == -1)
		g_hSortedCategoryList.PushString(sCategory);
	
	// Sort it by record end time
	SortRecordList();
	
	if(onlyHeader)
	{
		delete hFile;
		return BM_NoError;
	}
	
	// Read in all the saved frames
	ArrayList hRecordFrames = new ArrayList(sizeof(FrameInfo));
	ArrayList hAdditionalTeleport = new ArrayList(sizeof(AdditionalTeleport));
	
	FrameInfo iFrame;
	for(int i=0;i<iTickCount;i++)
	{
		hFile.Read(iFrame, sizeof(FrameInfo), 4);
		hRecordFrames.PushArray(iFrame, sizeof(FrameInfo));
		
		if(iFrame.additionalFields & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN|ADDITIONAL_FIELD_TELEPORTED_ANGLES|ADDITIONAL_FIELD_TELEPORTED_VELOCITY))
		{
			AdditionalTeleport iAT;
			if(iFrame.additionalFields & ADDITIONAL_FIELD_TELEPORTED_ORIGIN)
				hFile.Read(iAT.atOrigin, 3, 4);
			if(iFrame.additionalFields & ADDITIONAL_FIELD_TELEPORTED_ANGLES)
				hFile.Read(iAT.atAngles, 3, 4);
			if(iFrame.additionalFields & ADDITIONAL_FIELD_TELEPORTED_VELOCITY)
				hFile.Read(iAT.atVelocity, 3, 4);
			iAT.atFlags = iFrame.additionalFields & (ADDITIONAL_FIELD_TELEPORTED_ORIGIN|ADDITIONAL_FIELD_TELEPORTED_ANGLES|ADDITIONAL_FIELD_TELEPORTED_VELOCITY);
			hAdditionalTeleport.PushArray(iAT, sizeof(AdditionalTeleport));
		}
	}
	
	headerInfo.FH_frames = hRecordFrames;
	
	g_hLoadedRecords.SetArray(path, headerInfo, sizeof(FileHeader));
	if(hAdditionalTeleport.Length > 0)
		g_hLoadedRecordsAdditionalTeleport.SetValue(path, hAdditionalTeleport);
	else
		delete hAdditionalTeleport;
	
	delete hFile;
	return BM_NoError;
}

void SortRecordList()
{
	SortADTArrayCustom(g_hSortedRecordList, SortFuncADT_ByEndTime);
	SortADTArray(g_hSortedCategoryList, Sort_Descending, Sort_String);
}

public int SortFuncADT_ByEndTime(int index1, int index2, Handle arrayHndl, Handle hndl)
{
	char path1[PLATFORM_MAX_PATH], path2[PLATFORM_MAX_PATH];
	ArrayList array = view_as<ArrayList>(arrayHndl);
	array.GetString(index1, path1, sizeof(path1));
	array.GetString(index2, path2, sizeof(path2));
	
	FileHeader header1, header2;
	g_hLoadedRecords.GetArray(path1, header1, sizeof(FileHeader));
	g_hLoadedRecords.GetArray(path2, header2, sizeof(FileHeader));
	
	return header1.FH_recordEndTime - header2.FH_recordEndTime;
}

BMError PlayRecord(int client, const char[] path, int startFrame = 0, BMPlaybackMode mode = BMPlayback_Legacy)
{
    if (g_MapEnding)
        return BM_BadClient;
    if (g_hBotMimicsRecord[client] != null)
        StopMimicPlayback(client);
	FileHeader iFileHeader;
	g_hLoadedRecords.GetArray(path, iFileHeader, sizeof(FileHeader));
	
	// That record isn't fully loaded yet. Do that now.
	if(iFileHeader.FH_frames == null)
	{
		char sCategory[64];
		if(!g_hLoadedRecordsCategory.GetString(path, sCategory, sizeof(sCategory)))
			strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
		BMError error = LoadRecordFromFile(path, sCategory, iFileHeader, false, true);
		if(error != BM_NoError)
			return error;
	}
	
	if (mode == BMPlayback_LiveInput)
    {
        iFileHeader.FH_releaseWhenIdle = true;
        g_hLoadedRecords.SetArray(path, iFileHeader, sizeof(FileHeader));
    }
    if (startFrame >= iFileHeader.FH_tickCount)
    {
        ReleaseUnusedFrames(path);
        return BM_BadParameter;
    }
    if (mode == BMPlayback_LiveInput)
    {
        FrameInfo frame;
        for (int tick = 0; tick < iFileHeader.FH_tickCount; tick++)
        {
            iFileHeader.FH_frames.GetArray(tick, frame, sizeof(FrameInfo));
            if (frame.additionalFields != 0)
            {
                ReleaseUnusedFrames(path);
                return BM_BadParameter;
            }
        }
    }
    g_PlaybackSerial[client]++;
    int playbackSerial = g_PlaybackSerial[client];
    g_PlaybackMode[client] = mode;
    g_FirstFramePending[client] = true;
    g_hBotMimicsRecord[client] = iFileHeader.FH_frames;
    g_iBotMimicTick[client] = startFrame;
	g_iBotMimicRecordTickCount[client] = iFileHeader.FH_tickCount;
	g_iCurrentAdditionalTeleportIndex[client] = 0;
    FrameInfo precedingFrame;
    g_InitialRecordedWeapon[client] = CSWeapon_NONE;
    for (int tick = 0; tick < startFrame; tick++)
    {
        iFileHeader.FH_frames.GetArray(tick, precedingFrame, sizeof(FrameInfo));
        if (precedingFrame.newWeapon != CSWeapon_NONE)
            g_InitialRecordedWeapon[client] = precedingFrame.newWeapon;
        if (precedingFrame.additionalFields & 7)
            g_iCurrentAdditionalTeleportIndex[client]++;
    }
    g_iBotActiveWeapon[client] = mode == BMPlayback_LiveInput ? GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") : INVALID_ENT_REFERENCE;
	g_bBotSwitchedWeapon[client] = false;
	
	// Cache at which tick we should fire the first OnPlayerMimicBookmark forward.
	g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
	g_iBotMimicNextBookmarkTick[client].BWM_index = -1;
    UpdateNextBookmarkTick(client);
    if (startFrame > 0 && iFileHeader.FH_bookmarks != null)
    {
        g_iBotMimicNextBookmarkTick[client].BWM_frame = -1;
        for (int index = 0; index < iFileHeader.FH_bookmarkCount; index++)
        {
            Bookmarks bookmark;
            iFileHeader.FH_bookmarks.GetArray(index, bookmark, sizeof(Bookmarks));
            if (bookmark.BKM_frame >= startFrame)
            {
                g_iBotMimicNextBookmarkTick[client].BWM_frame = bookmark.BKM_frame;
                g_iBotMimicNextBookmarkTick[client].BWM_index = index;
                break;
            }
        }
    }

    Array_Copy(iFileHeader.FH_initialPosition, g_fInitialPosition[client], 3);
	Array_Copy(iFileHeader.FH_initialAngles, g_fInitialAngles[client], 3);
	
	SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);
	
	char sCategory[64];
	g_hLoadedRecordsCategory.GetString(path, sCategory, sizeof(sCategory));
	
	Action result;
	Call_StartForward(g_hfwdOnPlayerStartsMimicing);
	Call_PushCell(client);
	Call_PushString(iFileHeader.FH_recordName);
	Call_PushString(sCategory);
	Call_PushString(path);
	Call_Finish(result);
	
	// Someone doesn't want this guy to play that record.
	if (result >= Plugin_Handled && g_PlaybackSerial[client] == playbackSerial
        && g_hBotMimicsRecord[client] != null)
        StopMimicPlayback(client);
	
	return BM_NoError;
}

// Find the next frame in which a bookmark was saved, so the OnPlayerMimicBookmark forward can be called.
void UpdateNextBookmarkTick(int client)
{
	// Not mimicing anything.
	if(g_hBotMimicsRecord[client] == null)
		return;
	
	char sPath[PLATFORM_MAX_PATH];
	GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
	FileHeader iFileHeader;
	g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
	
	if(iFileHeader.FH_bookmarks == null)
		return;
	
	int iSize = iFileHeader.FH_bookmarks.Length;
	if(iSize == 0)
		return;
	
	int iCurrentIndex = g_iBotMimicNextBookmarkTick[client].BWM_index;
	// We just reached some bookmark regularly and want to proceed to wait for the next one sequentially.
	// If there is no further bookmarks, restart from the first one.
	iCurrentIndex++;
	if(iCurrentIndex >= iSize)
		iCurrentIndex = 0;
	
	Bookmarks iBookmark;
	iFileHeader.FH_bookmarks.GetArray(iCurrentIndex, iBookmark, sizeof(Bookmarks));
	g_iBotMimicNextBookmarkTick[client].BWM_frame = iBookmark.BKM_frame;
	g_iBotMimicNextBookmarkTick[client].BWM_index = iCurrentIndex;
}

void BlockBotDisruptiveAltFire(int client, int &buttons)
{
	if (!(buttons & IN_ATTACK2))
		return;

	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(activeWeapon))
		return;

	int defIndex = GetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex");
	switch (defIndex)
	{
		case BM_DEFIDX_GLOCK, BM_DEFIDX_FAMAS, BM_DEFIDX_M4A1S, BM_DEFIDX_USPS:
		{
			buttons &= ~IN_ATTACK2;
		}
	}
}

bool BotMimic_ClientHasWeapon(int client, const char[] classname)
{
	return IsValidEntity(BotMimic_GetClientWeapon(client, classname));
}

int BotMimic_GetClientWeapon(int client, const char[] classname)
{
	int weapon = -1;
	while ((weapon = FindEntityByClassname(weapon, classname)) != -1)
	{
		if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == client)
			return weapon;
	}

	return -1;
}

int BotMimic_GetWeaponSlotByClassName(const char[] classname)
{
	if (StrEqual(classname, "weapon_glock") || StrEqual(classname, "weapon_hkp2000") ||
		StrEqual(classname, "weapon_usp_silencer") || StrEqual(classname, "weapon_p250") ||
		StrEqual(classname, "weapon_deagle") || StrEqual(classname, "weapon_elite") ||
		StrEqual(classname, "weapon_fiveseven") || StrEqual(classname, "weapon_tec9") ||
		StrEqual(classname, "weapon_cz75a") || StrEqual(classname, "weapon_revolver"))
		return CS_SLOT_SECONDARY;

	if (StrEqual(classname, "weapon_flashbang") || StrEqual(classname, "weapon_hegrenade") ||
		StrEqual(classname, "weapon_smokegrenade") || StrEqual(classname, "weapon_molotov") ||
		StrEqual(classname, "weapon_incgrenade") || StrEqual(classname, "weapon_decoy"))
		return CS_SLOT_GRENADE;

	if (StrContains(classname, "weapon_knife") == 0 || StrEqual(classname, "weapon_bayonet"))
		return CS_SLOT_KNIFE;

	if (StrEqual(classname, "weapon_c4"))
		return CS_SLOT_C4;

	return CS_SLOT_PRIMARY;
}

stock void GetFileFromFrameHandle(ArrayList frames, char[] path, int maxlen)
{
	int iSize = g_hSortedRecordList.Length;
	char sPath[PLATFORM_MAX_PATH];
	FileHeader iFileHeader;
	for(int i=0;i<iSize;i++)
	{
		g_hSortedRecordList.GetString(i, sPath, sizeof(sPath));
		g_hLoadedRecords.GetArray(sPath, iFileHeader, sizeof(FileHeader));
		if(iFileHeader.FH_frames != frames)
			continue;
		
		strcopy(path, maxlen, sPath);
		break;
	}
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}
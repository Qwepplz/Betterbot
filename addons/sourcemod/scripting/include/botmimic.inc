#if defined _botmimic_included
  #endinput
#endif
#define _botmimic_included

#define MAX_RECORD_NAME_LENGTH 64
#define MAX_BOOKMARK_NAME_LENGTH 64
#define DEFAULT_CATEGORY "default"

enum BMError {
	BM_NoError = 0,
	BM_BadClient, // Provided client index is invalid
	BM_FileNotFound, // The file does not exists or can't be opened
	BM_BadFile, // Not a Bot Mimic record.
	BM_NewerBinaryVersion, // The record was recorded with a newer version of Bot Mimic and can't be played.
	BM_BadParameter // Invalid frame, mode or unsupported LiveInput payload.
};

enum BMPlaybackMode
{
    BMPlayback_Legacy = 0,
    BMPlayback_LiveInput
};

enum struct BMFileHeader {
	int BMFH_binaryFormatVersion;
	int BMFH_recordEndTime;
	char BMFH_recordName[MAX_RECORD_NAME_LENGTH];
	int BMFH_tickCount;
	float BMFH_initialPosition[3];
	float BMFH_initialAngles[3];
	int BMFH_bookmarkCount;
}

/**
 * Is the player currently mimicing something?
 * 
 * @param client	The client to check
 * @return			true, if the player is mimicing, false otherwise
 */
native bool BotMimic_IsPlayerMimicing(int client);

/**
 * Get the path to the record file this player is currently mimicing.
 *
 * @param client	The mimicing client
 * @param path		A String where to store the path
 * @param maxlen	The maximal length of the path
 */
native void BotMimic_GetRecordPlayerMimics(int client, char[] path, int maxlen);

/**
 * Let a client start to mimic a record from a file.
 *
 * @param client	The client, which should start mimicing
 * @param path		The path to a .rec recording file
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_PlayRecordFromFile(int client, const char[] path);

// LiveInput applies commands through engine physics. Changed suspends the cursor.
// Handled/Stop ends playback. The callback precedes every replay field write.
// alignStart aligns origin, angles and actual velocity once on the first approved
// frame. It requires LiveInput at frame zero. Reset and bookmarks clear the option.
native BMError BotMimic_PlayRecordFromFileEx(int client, const char[] path, int startFrame, BMPlaybackMode mode, bool alignStart = false);
forward Action BotMimic_OnPlayerMimicFrame(int client, int frameIndex, const float recordedOrigin[3], const float movement[3]);

/**
 * Let a client start to mimic a record by providing the record name.
 * Since record names don't have to be unique, this native picks the most recent one.
 *
 * @param client	The client, which should start mimicing.
 * @param name		The name of the record to play.
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_PlayRecordByName(int client, const char[] name);

/**
 * Have a bot restart the record he's currently playing from the beginning.
 *
 * @param client   The client, who should start over with the record he's currently mimicing.
 */
native void BotMimic_ResetPlayback(int client);

/**
 * Jump the the frame where this bookmark was set in the record.
 *
 * @param client	The client, which is mimicing some record
 * @param name		The name of a bookmark stored in the record
 */
native void BotMimic_GoToBookmark(int client, const char[] name);

/**
 * Stops a player from mimicing a record.
 *
 * @param client	The client who should stop mimicing
 */
native void BotMimic_StopPlayerMimic(int client);

/**
 * Get the Handle to a sorted adt_array, containing a list of paths to all loaded record files.
 * DON'T CLOSE THIS HANDLE!
 * Just use GetArrayString to read the path.
 *
 * @return Handle to sorted adt_array containing all paths to records
 */
native ArrayList BotMimic_GetLoadedRecordList();

/**
 * Get the Handle to a sorted adt_array, containing a list of categorys.
 * DON'T CLOSE THIS HANDLE!
 * Just use GetArrayString to read the category.
 *
 * @return Handle to sorted adt_array containing all categories.
 */
native ArrayList BotMimic_GetLoadedRecordCategoryList();

/**
 * Get the header information of a record. This includes the record name.
 *
 * @param path	The path to the .rec record file
 * @param iFileHeader	An array to store the file header in.
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_GetFileHeaders(const char[] path, any[] iFileHeader, int size);

/**
 * Get the category of a record.
 *
 * @param path			The path to the .rec record file.
 * @param category	The String where to store the category in.
 * @param maxlen		The maximal length of the category buffer.
 * @return				true if category of file found, false otherwise
 */
native bool BotMimic_GetFileCategory(const char[] path, char[] category, int maxlen);

/**
 * Get a list of all bookmarks stored in this record as an adt_array.
 * You have to close the returned Handle using CloseHandle.
 *
 * @param path		The path to the .rec record file.
 * @param bookmarks	The handle where the bookmark array will be stored in.
 * @return			BM_NoError if all went smooth, see BMError definition.
 */
native BMError BotMimic_GetRecordBookmarks(const char[] path, ArrayList &bookmarks);

/**
 * Called when a player starts to mimic a record
 *
 * @param client		The client which starts mimicing.
 * @param name			The name of the record (stored in file header)
 * @param category	The category of the file.
 * @param path			The path to the record file.
 * @return 					>= Plugin_Handled to stop the player from mimicing, Plugin_Continue to allow
 */
forward Action BotMimic_OnPlayerStartsMimicing(int client, char[] name, char[] category, char[] path);

/**
 * Called when a player stops mimicing a record.
 *
 * @param client		The client who was mimicing
 * @param name			The name of the record (stored in file header)
 * @param category	The category of the file.
 * @param path			The path to the record file.
 */
forward void BotMimic_OnPlayerStopsMimicing(int client, char[] name, char[] category, char[] path);

/**
 * Called everytime a mimicing player starts to mimic the record again from the beginning,
 * when he was teleported back to the start.
 *
 * @param client		The mimicing client
 */
forward void BotMimic_OnPlayerMimicLoops(int client);

/**
 * Called when a bookmark is reached during playback of a record.
 *
 * @param client	The client which is mimicing.
 * @param bookmark	The name of the bookmark.
 */
forward void BotMimic_OnPlayerMimicBookmark(int client, const char[] bookmark);

/**
 * Translate an error id to a human readable string
 * 
 * @param error		The error id
 * @param str		The string to store the error message in
 * @param maxlen	The maximal length of the error message string
 */
stock void BotMimic_GetErrorString(BMError error, char[] str, int maxlen)
{
	switch(error)
	{
		case BM_BadClient:
		{
			strcopy(str, maxlen, "Invalid client index.");
		}
		case BM_FileNotFound:
		{
			strcopy(str, maxlen, "File not found.");
		}
		case BM_NewerBinaryVersion:
		{
			strcopy(str, maxlen, "The file was recorded with a newer version of Bot Mimic and can't be played.");
		}
		case BM_BadParameter:
        {
            strcopy(str, maxlen, "Invalid playback frame, mode or record payload.");
        }
        case BM_BadFile:
		{
			strcopy(str, maxlen, "The file is not a record. Bad format.");
		}
		case BM_NoError:
		{
			strcopy(str, maxlen, "");
		}
	}
}

public SharedPlugin __pl_botmimic = 
{
	name = "botmimic",
	file = "botmimic.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_botmimic_SetNTVOptional()
{
	MarkNativeAsOptional("BotMimic_GoToBookmark");
	MarkNativeAsOptional("BotMimic_IsPlayerMimicing");
	MarkNativeAsOptional("BotMimic_GetRecordPlayerMimics");
	MarkNativeAsOptional("BotMimic_PlayRecordFromFile");
	MarkNativeAsOptional("BotMimic_PlayRecordFromFileEx");
	MarkNativeAsOptional("BotMimic_ResetPlayback");
	MarkNativeAsOptional("BotMimic_PlayRecordByName");
	MarkNativeAsOptional("BotMimic_StopPlayerMimic");
	MarkNativeAsOptional("BotMimic_GetLoadedRecordCategoryList");
	MarkNativeAsOptional("BotMimic_GetLoadedRecordList");
	MarkNativeAsOptional("BotMimic_GetFileHeaders");
	MarkNativeAsOptional("BotMimic_GetFileCategory");
	MarkNativeAsOptional("BotMimic_GetRecordBookmarks");
}
#endif
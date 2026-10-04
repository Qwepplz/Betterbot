#include <sourcemod>
#include <sdktools>

char Master[][] =
{
	"models/player/custom_player/legacy/ctm_st6_varianti.mdl",
	"models/player/custom_player/legacy/ctm_fbi_variantb.mdl",
	"models/player/custom_player/legacy/tm_balkan_varianth.mdl",
	"models/player/custom_player/legacy/tm_leet_variantf.mdl",
}

#define DATA "1.0"

public Plugin myinfo =
{
	name = "[CS:GO] Franug Voice Agents Enabler",
	author = "Franc1sco franug",
	description = "Voice Agents",
	version = DATA,
	url = "http://steamcommunity.com/id/franug"
}

public void OnPluginStart()
{
	AddNormalSoundHook(VoiceLineSounds);
}

public Action VoiceLineSounds(int clients[MAXPLAYERS], int &numClients,
	char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume,
	int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (!IsValidClient(entity) || !IsPlayerAlive(entity)
		|| numClients < 0 || numClients > sizeof(clients))
		return Plugin_Continue;

	if (StrContains(sample, "player\\vo\\", false) == -1)
		return Plugin_Continue;

	int team = GetClientTeam(entity);
	if (team != 2 && team != 3)
		return Plugin_Continue;

	bool changed = false;
	char model[128];
	GetClientModel(entity, model, sizeof(model));

	char candidate[PLATFORM_MAX_PATH];
	if (BuildAgentVoiceSample(sample, getMasterModel(model), candidate, sizeof(candidate)))
	{
		char filePath[PLATFORM_MAX_PATH];
		int pathStart = StrContains(candidate, "player\\vo\\", false);
		int fileLength = strlen(candidate) - pathStart + 6;
		if (fileLength < sizeof(filePath))
		{
			Format(filePath, sizeof(filePath), "sound/%s", candidate[pathStart]);
			ReplaceString(filePath, sizeof(filePath), "\\", "/");
			if (FileExists(filePath, true, "GAME") && PrecacheSound(candidate))
			{
				strcopy(sample, sizeof(sample), candidate);
				changed = true;
			}
		}
	}

	int kept = 0;
	for (int i = 0; i < numClients; i++)
	{
		int recipient = clients[i];
		// Leave existing GOTV recipients to the game's original routing.
		if (IsValidClient(recipient) && !IsClientSourceTV(recipient)
			&& GetClientTeam(recipient) != team)
		{
			changed = true;
			continue;
		}
		clients[kept++] = recipient;
	}
	numClients = kept;

	return changed ? Plugin_Changed : Plugin_Continue;
}

bool BuildAgentVoiceSample(const char[] sample, int modelIndex, char[] output, int outputSize)
{
	static const char voices[][] = {"seal_epic", "fbihrt_epic", "balkan_epic", "leet_epic"};
	if (modelIndex < 1 || modelIndex > sizeof(voices))
		return false;

	int separators = 0;
	for (int i = 0; sample[i] != '\0'; i++)
	{
		if (sample[i] == '\\')
			separators++;
	}
	if (separators != 3)
		return false;

	char parts[4][PLATFORM_MAX_PATH];
	if (ExplodeString(sample, "\\", parts, sizeof(parts), sizeof(parts[])) != 4
		|| !StrEqual(parts[1], "vo", false))
		return false;

	if (StrEqual(parts[2], voices[modelIndex - 1]))
		return false;

	bool knownVoice;
	if (modelIndex <= 2)
	{
		knownVoice = StrEqual(parts[2], "fbihrt") || StrEqual(parts[2], "gign")
			|| StrEqual(parts[2], "idf") || StrEqual(parts[2], "sas")
			|| StrEqual(parts[2], "swat") || StrEqual(parts[2], "seal");
	}
	else
	{
		knownVoice = StrEqual(parts[2], "anarchist") || StrEqual(parts[2], "balkan")
			|| StrEqual(parts[2], "leet") || StrEqual(parts[2], "phoenix")
			|| StrEqual(parts[2], "separatist");
	}
	if (!knownVoice)
		return false;

	char line[PLATFORM_MAX_PATH];
	if (PostEditSoundPath(parts[3], sizeof(parts[]), line, sizeof(line)) < 0)
		return false;

	if (modelIndex == 4 && StrContains(line, "negative_") == 0)
		ReplaceString(line, sizeof(line), "negative_", "disagree_");

	if (modelIndex == 2
		&& (StrEqual(line, "takingfire_11.wav") || StrEqual(line, "takingfire_12.wav")))
		Format(line, sizeof(line), "takingfire_0%i.wav", GetRandomInt(1, 7));

	int length = strlen(parts[0]) + strlen(parts[1]) + strlen(voices[modelIndex - 1])
		+ strlen(line) + 3;
	if (length >= outputSize)
		return false;

	Format(output, outputSize, "%s\\%s\\%s\\%s", parts[0], parts[1],
		voices[modelIndex - 1], line);
	return true;
}

int PostEditSoundPath(char[] input, int inputSize, char[] output, int outputSize)
{
	static const char aliases[][][] =
	{
		{"positive", "affirmation_"},
		{"affirmative", "affirmation_"},
		{"cheer", "cheer_"},
		{"hold", "request_hold_"},
		{"agree", "agree_"},
		{"negative", "negative_"},
		{"negativeno", "negative_"},
		{"onarollbrag", "compliment_"},
		{"preventescapebrag", "compliment_"},
		{"radio_followme", "request_follow_me_"},
		{"radio_locknload", "request_follow_me_"},
		{"thanks", "thankful_"},
		{"radio_enemyspotted", "sees_enemy_"},
		{"radio_needbackup", "request_backup_"},
		{"followingfriend", "following_friend_"},
		{"clearedarea", "sees_area_clear_"},
		{"inposition", "omw_position_"},
		{"spottedloosebomb", "sees_dropped_bomb_"},
		{"followme", "request_follow_me_"},
		{"target", "sees_enemy_"},
		{"underfire", "takingfire_"},
		{"followyou", "following_friend_"},
		{"clear", "sees_area_clear_"},
		{"at_position", "omw_position_"}
	};

	int inputLength = strlen(input);
	if (inputSize <= 0 || outputSize <= 0 || inputLength >= inputSize
		|| inputLength < 5 || !StrEqual(input[inputLength - 4], ".wav"))
		return -1;

	int start = 0;
	if (StrContains(input, "radiobotreponse") == 0)
		start = strlen("radiobotreponse");
	else if (StrContains(input, "radiobot") == 0)
		start = strlen("radiobot");

	int numberStart = inputLength - 4;
	while (numberStart > start && IsCharNumeric(input[numberStart - 1]))
		numberStart--;

	int wordEnd = numberStart;
	while (wordEnd > start && input[wordEnd - 1] == '_')
		wordEnd--;
	if (wordEnd <= start)
		return -1;

	char word[PLATFORM_MAX_PATH];
	if (wordEnd - start >= sizeof(word))
		return -1;
	strcopy(word, wordEnd - start + 1, input[start]);

	for (int i = 0; i < sizeof(aliases); i++)
	{
		if (!StrEqual(word, aliases[i][0]))
			continue;

		int length = strlen(aliases[i][1]) + inputLength - numberStart;
		if (length >= outputSize)
			return -1;

		char candidate[PLATFORM_MAX_PATH];
		if (length >= sizeof(candidate))
			return -1;
		Format(candidate, sizeof(candidate), "%s%s", aliases[i][1], input[numberStart]);
		strcopy(output, outputSize, candidate);
		return length;
	}

	int length = inputLength - start;
	if (length >= outputSize)
		return -1;
	strcopy(output, outputSize, input[start]);
	return length;
}

int getMasterModel(char[] model)
{
	if(StrContains(model, "models/player/custom_player/legacy/") == -1) // player use a custom model by other plugin
		return 0;

	for (int i = 0; i < sizeof(Master); i++)
	{
		if(StrEqual(model, Master[i]))
		{
			return i+1;
		}
	}
	return 0;
}

public bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client))
		return false;

	return true;
}

/*  CS:GO Weapons&Knives SourceMod Plugin
 *
 *  Native API recovered from local SMX metadata.
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  RegPluginLibrary("weapons");
  CreateNative("Weapons_GetClientKnife", Weapons_GetClientKnife_Native);
  CreateNative("Weapons_SetClientKnife", Weapons_SetClientKnife_Native);
  CreateNative("Weapons_SetClientSkin", Weapons_SetClientSkin_Native);
  CreateNative("Weapons_SetClientWear", Weapons_SetClientWear_Native);
  CreateNative("Weapons_SetClientSeed", Weapons_SetClientSeed_Native);
  CreateNative("Weapons_SetClientNameTag", Weapons_SetClientNameTag_Native);
  CreateNative("Weapons_ToggleClientStarTrack", Weapons_ToggleClientStarTrack_Native);

  g_hOnKnifeSelect_Pre = CreateGlobalForward("Weapons_OnClientKnifeSelectPre", ET_Event, Param_Cell, Param_String, Param_Cell);
  g_hOnKnifeSelect_Post = CreateGlobalForward("Weapons_OnClientKnifeSelectPost", ET_Ignore, Param_Cell, Param_String, Param_Cell);
  return APLRes_Success;
}

public any Weapons_GetClientKnife_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int maxlength = GetNativeCell(3);

  char knifeClass[64];
  GetClientKnife(client, knifeClass, sizeof(knifeClass));
  SetNativeString(2, knifeClass, maxlength);
  return true;
}
public any Weapons_SetClientKnife_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  char knifeClass[64];
  GetNativeString(2, knifeClass, sizeof(knifeClass));
  bool refresh = numParams >= 3 ? view_as<bool>(GetNativeCell(3)) : true;

  Action result = Plugin_Continue;
  Call_StartForward(g_hOnKnifeSelect_Pre);
  Call_PushCell(client);
  Call_PushString(knifeClass);
  Call_PushCell(-1);
  Call_Finish(result);

  if (result >= Plugin_Handled) {
    return false;
  }

  bool success = SetClientKnife(client, knifeClass, true, refresh);
  if (success) {
    Call_StartForward(g_hOnKnifeSelect_Post);
    Call_PushCell(client);
    Call_PushString(knifeClass);
    Call_PushCell(-1);
    Call_Finish();
  }
  return success;
}

public any Weapons_SetClientSkin_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int index = GetNativeCell(2);
  int team = GetNativeCell(3);
  int skin = GetNativeCell(4);
  bool refresh = numParams >= 5 ? view_as<bool>(GetNativeCell(5)) : true;
  return SetClientSkin(client, index, team, skin, refresh);
}

public any Weapons_SetClientWear_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int index = GetNativeCell(2);
  int team = GetNativeCell(3);
  float wear = view_as<float>(GetNativeCell(4));
  bool refresh = numParams >= 5 ? view_as<bool>(GetNativeCell(5)) : true;
  return SetClientWear(client, index, team, wear, refresh);
}

public any Weapons_SetClientSeed_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int index = GetNativeCell(2);
  int team = GetNativeCell(3);
  int seed = GetNativeCell(4);
  bool refresh = numParams >= 5 ? view_as<bool>(GetNativeCell(5)) : true;
  return SetClientSeed(client, index, team, seed, refresh);
}

public any Weapons_SetClientNameTag_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int index = GetNativeCell(2);
  int team = GetNativeCell(3);
  char nameTag[128];
  GetNativeString(4, nameTag, sizeof(nameTag));
  bool refresh = numParams >= 5 ? view_as<bool>(GetNativeCell(5)) : true;
  return SetClientNameTag(client, index, team, nameTag, refresh);
}

public any Weapons_ToggleClientStarTrack_Native(Handle plugin, int numParams) {
  int client = GetNativeCell(1);
  int index = GetNativeCell(2);
  int team = GetNativeCell(3);
  bool refresh = numParams >= 4 ? view_as<bool>(GetNativeCell(4)) : true;
  return ToggleClientStarTrack(client, index, team, refresh);
}

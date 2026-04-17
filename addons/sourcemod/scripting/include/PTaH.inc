#if defined _PTaH_included
  #endinput
#endif
#define _PTaH_included

#define PTaH_AVATAR_SIZE 64 * 64 * 3

enum PTaH_HookType
{
  UnHook = 0,
  Hook
};

enum PTaH_HookEvent
{
  PTaH_GiveNamedItemPre = 10,
  PTaH_GiveNamedItemPost,
  PTaH_WeaponCanUsePre,
  PTaH_WeaponCanUsePost
};

enum CEconItemView
{
  CEconItemView_NULL = 0
};

typeset PTaHCB
{
  function Action(int client, char classname[64], CEconItemView &item, bool &ignoredCEconItemView, bool &originIsNull, float origin[3]);
  function void(int client, const char[] classname, const CEconItemView item, int entity, bool originIsNull, const float origin[3]);
  function Action(int client, int weapon, bool &pickup);
};

native int PTaH_Version(char[] buffer = NULL_STRING, int maxlength = 0);
native bool PTaH(PTaH_HookEvent hookEvent, PTaH_HookType hookType, PTaHCB callback);

public Extension __ext_PTaH =
{
  name = "PTaH",
  file = "PTaH.ext",
  autoload = 1,
  required = 1,
};

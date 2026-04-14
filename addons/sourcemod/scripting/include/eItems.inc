#if defined _eItems_included
	#endinput
#endif
#define _eItems_included

native int eItems_GetWeaponSlotByWeapon(int weapon);
native int eItems_GetWeaponSlotByDefIndex(int defIndex);
native int eItems_FindWeaponByDefIndex(int client, int defIndex);

// Recovered from the repository SMX; control flow verified against its bytecode.
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Hider For Menu",
    description = "",
    author = "Bone",
    version = "1.0",
    url = "https://bonetm.github.io/"
};

bool g_IsMenuOpen[66];

public void OnGameFrame()
{
    for (int i = 0; i < MaxClients; i++)
    {
        if (!(i > 0 && i <= MaxClients && IsClientConnected(i)
            && IsClientInGame(i) && !IsFakeClient(i)))
        {
            continue;
        }

        if (GetClientMenu(i) == MenuSource_None)
        {
            if (g_IsMenuOpen[i] == true)
            {
                g_IsMenuOpen[i] = false;
                SetEntProp(i, Prop_Send, "m_iHideHUD",
                    GetEntProp(i, Prop_Send, "m_iHideHUD") & 0);
                SendConVarValue(i, FindConVar("mp_playercashawards"), "1");
                SendConVarValue(i, FindConVar("mp_teamcashawards"), "1");
            }
        }
        else if (!g_IsMenuOpen[i])
        {
            g_IsMenuOpen[i] = true;
            SetEntProp(i, Prop_Send, "m_iHideHUD",
                GetEntProp(i, Prop_Send, "m_iHideHUD") | 4096);
            SendConVarValue(i, FindConVar("mp_playercashawards"), "0");
            SendConVarValue(i, FindConVar("mp_teamcashawards"), "0");
        }
    }
}

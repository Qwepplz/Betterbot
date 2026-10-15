## Forked from https://github.com/manicogaming/CSGOBetterBots

## Installation

This branch supports Linux only. Use a legacy CS:GO Source 1 dedicated server. Stability is not guaranteed when installing plugins directly into the game client.

1. Deploy BetterBots into the server's `csgo` directory, including `botprofile.db` and `botchatter.db`.
2. Install Get5 and its required dependencies.
3. Install `sourcemod-1.12.0-git7253-linux`; skip files whose names already exist instead of overwriting them.
4. Install `mmsource-1.12.0-git1227-linux`.
5. Set `FollowCSGOServerGuidelines` to `"no"` in `addons/sourcemod/configs/core.cfg` and move `addons/sourcemod/plugins/nextmap.smx` into `addons/sourcemod/plugins/disabled`.

On an amd64 host, this legacy server and the bundled extensions use ELF32. Install the matching 32-bit libc, libgcc, libstdc++ and zlib runtimes. On the tested Ubuntu 26.04.1 host these came from `libc6-i386`, `lib32gcc-s1`, `lib32stdc++6` and `lib32z1`. The MySQL driver requires the 32-bit `libz.so.1` supplied by `lib32z1`. Configure the existing database entries for your server with authentication supported by SourceMod's MySQL driver.

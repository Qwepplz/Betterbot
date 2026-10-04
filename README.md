## Forked from https://github.com/manicogaming/CSGOBetterBots

## Installation

Use a CS:GO dedicated server. Stability is not guaranteed when installing plugins directly into the game client.

1. Install `mmsource-1.12.0-git1227-windows` and `sourcemod-1.12.0-git7253-windows`.
2. Deploy BetterBots.
3. Install Get5, which is required for BetterBots.
4. Delete `addons/sourcemod/plugins/nextmap.smx` and set `FollowCSGOServerGuidelines` to `"no"` in `addons/sourcemod/configs/core.cfg`.

## AI branch

SL-Bots owns Bot behavior. `bot_presentation` only publishes profile rank, teammate colors and crosshair presentation. BotMimic and its menu remain in `plugins/disabled`.

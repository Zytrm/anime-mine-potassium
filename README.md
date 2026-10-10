# Anime Mine Potassium panel

Client-side Luau panel for the Anime Mine place. It uses the game's existing `GamestateEvent` actions, so collection and purchases do not click game UI or move the character.

## Load in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zytrm/anime-mine-potassium/main/main.luau"))()
```

## Controls

- **Collect chest:** takes all available chest contents.
- **Buy pickaxes:** buys one copy of each selected pickaxe when it is unlocked, affordable, and in stock. Click names in the scroll list to include or exclude them. Robux pickaxes are excluded.
- **Level miners:** buys the least expensive available character level.
- **Buy upgrades:** buys the least expensive available core or skill tree upgrade.
- **Equip best:** calls the game's equip-best action every 15 seconds.
- **Mine stage:** cycles between highest unlocked, off, and individual zones.

Chest collection, equip best, and highest unlocked stage are enabled initially. Spending controls start off so you can choose which purchases to automate. The panel can be dragged, minimized, closed, and rerun without leaving a second loop.

The loop does not use simulated input, so it can run while the Roblox window is unfocused as long as the client remains running and connected. Server-side purchase and distance rules still apply.

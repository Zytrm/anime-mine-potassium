# Anime Mine Potassium panel

Client-side Luau panel for the Anime Mine place. It uses the game's existing `GamestateEvent` actions, so collection and purchases do not click game UI or move the character.

## Load in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zytrm/anime-mine-potassium/main/main.luau"))()
```

## Controls

- **Collect chest:** takes all available chest contents.
- **Buy pickaxes:** buys the remaining personal stock of each selected pickaxe while it is unlocked and affordable, in quick batches of up to 12 purchases. Pickaxes start unselected; click the names you want. The unstocked Wooden Pickaxe is limited to one copy, and Robux pickaxes are excluded.
- **Level miners:** buys available character levels in quick batches. Its slider starts at 20%. Each purchase must cost less than that share of the remaining balance.
- **Buy upgrades:** buys available core and skill tree upgrades in the same quick batch. Its slider also starts at 20%. Each batch uses the current balance; combined spending is capped by the higher slider, and each category obeys its own slider. A new batch can run after the balance updates.
- **Equip best:** calls the game's equip-best action every 15 seconds.
- **Promote Mythic+:** compares Mythical, Exotic, Limited, Exclusive, and Scaled miners in inventory against the weakest placed miner at their maximum possible level. Scaled estimates use the remaining team's reference power and the game's pad cap. If a candidate could become stronger, it unequips the held item, uses Potassium's prompt automation to replace the weak miner, then levels the new miner under the spending slider. The small line below the toggle shows why it is waiting or where a swap stopped. This is opt in and turns on miner levelling. The game server may still reject distant prompt actions.
- **Claim rewards:** claims available index, event, and enabled daily quest rewards. This starts on.
- **Rare drop webhook:** paste a webhook URL into the panel and turn on the main toggle. Separate toggles control Mythical, Exotic, and higher rarity alerts. A JSON message is sent when a selected rarity enters inventory. Existing inventory is used as the baseline, so loading the script does not announce old items.
- **Mine stage:** cycles between highest unlocked, off, and individual zones.
- **Quiet anti-AFK:** sends a virtual off-screen click when Roblox reports the player idle. It does not move the avatar or require the Roblox window to be focused.
- **Auto reconnect:** when the Roblox disconnect prompt appears, attempts to rejoin the same place up to three times. Potassium's teleport queue reloads the script after a successful teleport, and the saved settings are restored. It also reloads after ordinary in-game teleports while enabled. A completed kick can end the client connection before any script can rejoin; in that case you must reconnect manually and run the loader again.

Chest collection, equip best, reward claims, anti-AFK, auto reconnect, and highest unlocked stage are enabled initially. Spending controls start off so you can choose which purchases to automate. The panel can be dragged, minimized, closed, and rerun without leaving a second loop.

Settings save automatically to `AnimeMinePotassium/config-<game ID>-<user ID>.json` in Potassium's workspace and load the next time the script runs. This includes toggles, sliders, stage, selected pickaxes, and the webhook URL. The webhook URL is stored as plain text in that local file. When upgrading from an earlier script version in the same session, the current panel settings are carried over.

The purchase and reward loop uses game events, so it can run while the Roblox window is unfocused as long as the client remains running and connected. Mythic swapping uses prompt automation; server-side distance rules may reject it.

# Anime Mine Potassium panel

Client-side Luau panel for the Anime Mine place. It uses the game's existing `GamestateEvent` actions, so collection and purchases do not click game UI or move the character.

## Load in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zytrm/anime-mine-potassium/2c90ede/bootstrap.luau"))()
```

The bootstrap resolves the latest `main` commit through GitHub's API, then downloads that exact revision. Its URL is pinned so GitHub's raw-file cache cannot serve an older bootstrap.

## Controls

- **Collect chest:** takes all available chest contents.
- **Buy pickaxes:** buys the remaining personal stock of each selected pickaxe while it is unlocked and affordable, in quick batches of up to 12 purchases. Pickaxes start unselected; click the names you want. The unstocked Wooden Pickaxe is limited to one copy, and Robux pickaxes are excluded.
- **Level miners:** upgrades placed miners' Damage, Speed, and Mining Speed in quick batches using the game's own upgrade actions. It picks the cheapest eligible stat each time. The Miner stats budget slider starts at 20% and caps combined miner spending per batch; each purchase must fit the remaining budget.
- **Buy upgrades:** buys available core and skill tree upgrades in the same quick batch. Its slider also starts at 20%. Each batch uses the current balance; combined spending is capped by the higher slider, and each category obeys its own slider. A new batch can run after the balance updates.
- **Equip best:** calls the game's equip-best action every 15 seconds.
- **Promote Mythic+:** compares Mythical, Exotic, Limited, Exclusive, and Scaled miners in inventory against placed miners at their maximum possible level, starting with the weakest. Scaled estimates use the remaining team's reference power and the game's pad cap. It unequips the held item, picks up the weaker miner, places the candidate, and levels it under the spending slider. Pickup and placement use Potassium's `replicatesignal(prompt.TriggeredActionReplicated, player)` when supported. The live API inspection confirmed this signal is replicable and expects one Player argument; the public `Triggered` signal is not replicable. The prompt is looked up again for each action, and a submitted replicated action is not sent twice while waiting for the holder state to update. Older executors retain the executor/native prompt fallback. If a holder does not update, the script reports its slot and tries another eligible holder; failed slots rest for five minutes. This is opt in and turns on miner levelling. Server validation may still reject an action.
- **Claim rewards:** claims available index, event, and enabled daily quest rewards. This starts on.
- **Rare drop webhook:** paste a webhook URL into the panel and turn on the main toggle. Separate toggles control Mythical, Exotic, and higher rarity alerts. A JSON message is sent when a selected rarity enters inventory. Existing inventory is used as the baseline, so loading the script does not announce old items.
- **Mine stage:** cycles between highest unlocked, off, and individual zones.
- **Quiet anti-AFK:** sends a virtual off-screen click when Roblox reports the player idle. It does not move the avatar or require the Roblox window to be focused.
- **Auto reconnect:** when the Roblox disconnect prompt appears, attempts to rejoin the same place up to three times. Potassium's teleport queue reloads the script after a successful teleport, and the saved settings are restored. It also reloads after ordinary in-game teleports while enabled. A completed kick can end the client connection before any script can rejoin; in that case you must reconnect manually and run the loader again.

Chest collection, equip best, reward claims, anti-AFK, auto reconnect, and highest unlocked stage are enabled initially. Spending controls start off so you can choose which purchases to automate. The panel can be dragged, minimized, closed, and rerun without leaving a second loop.

Settings save automatically to `AnimeMinePotassium/config-<game ID>-<user ID>.json` in Potassium's workspace and load the next time the script runs. This includes toggles, sliders, stage, selected pickaxes, and the webhook URL. The webhook URL is stored as plain text in that local file. When upgrading from an earlier script version in the same session, the current panel settings are carried over.

The purchase and reward loop uses game events, so it can run while the Roblox window is unfocused as long as the client remains running and connected. Mythic swapping uses prompt automation; server-side distance rules may reject it.

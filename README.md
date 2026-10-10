# Anime Mine Potassium panel

Client-side Luau panel for the Anime Mine place. It uses the game's existing `GamestateEvent` actions, so collection and purchases do not click game UI or move the character.

## Load in Potassium

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Zytrm/anime-mine-potassium/main/main.luau"))()
```

## Controls

- **Collect chest:** takes all available chest contents.
- **Buy pickaxes:** buys one copy of each selected pickaxe when it is unlocked, affordable, and in stock. Click names in the scroll list to include or exclude them. Robux pickaxes are excluded.
- **Level miners:** buys available character levels in quick batches. Its slider starts at 20%. Each purchase must cost less than that share of the remaining balance.
- **Buy upgrades:** buys available core and skill tree upgrades in the same quick batch. Its slider also starts at 20%. The script tracks spending across batches until the balance recovers: combined spending is capped by the higher slider, and each category obeys its own slider.
- **Equip best:** calls the game's equip-best action every 15 seconds.
- **Promote mythics:** compares mythic or rarer miners in inventory against the weakest placed miner after affordable levelling. If one would be stronger, it uses Potassium's prompt automation to pick up the weak miner and place the stronger one. This is opt in and turns on miner levelling. The game server may still reject distant prompt actions.
- **Claim rewards:** claims available index, event, and enabled daily quest rewards. This starts on.
- **Rare drop webhook:** paste a webhook URL into the panel and turn on the main toggle. Separate toggles control Mythical, Exotic, and higher rarity alerts. A JSON message is sent when a selected rarity enters inventory. Existing inventory is used as the baseline, so loading the script does not announce old items. The URL is kept only in the current script session.
- **Mine stage:** cycles between highest unlocked, off, and individual zones.

Chest collection, equip best, reward claims, and highest unlocked stage are enabled initially. Spending controls start off so you can choose which purchases to automate. The panel can be dragged, minimized, closed, and rerun without leaving a second loop.

The purchase and reward loop uses game events, so it can run while the Roblox window is unfocused as long as the client remains running and connected. Mythic swapping uses prompt automation; server-side distance rules may reject it.

-- Anime Mine automation panel for Potassium (client-side Luau).
-- Uses the same GamestateEvent actions as the game's own client UI.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local GameState = require(modules:WaitForChild("GameState"))
local MineConfig = require(modules:WaitForChild("MineConfig"))
local MineStock = require(modules:WaitForChild("MineStock"))
local Items = require(modules:WaitForChild("Items"))
local MineInventory = require(modules:WaitForChild("MineInventory"))
local IndexRewards = require(modules:WaitForChild("MineIndexRewardsConfig"))
local EventsConfig = require(modules:WaitForChild("MineEventsConfig"))
local DailyQuests = require(modules:WaitForChild("MineDailyQuestsCatalog"))

local global = (type(getgenv) == "function" and getgenv()) or _G
local previousState = global.AnimeMinePotassium
if global.AnimeMinePotassium then
    if type(global.AnimeMinePotassium.stop) == "function" then
        global.AnimeMinePotassium.stop()
    else
        global.AnimeMinePotassium.running = false
        if global.AnimeMinePotassium.gui then
            global.AnimeMinePotassium.gui:Destroy()
        end
    end
end

local state = {
    running = true,
    chest = true,
    pickaxes = false,
    characters = false,
    upgrades = false,
    characterPercent = 20,
    upgradePercent = 20,
    equipBest = true,
    promoteMythics = false,
    rewards = true,
    webhook = false,
    webhookMythical = true,
    webhookExotic = true,
    webhookHigher = true,
    webhookUrl = "",
    stage = "Highest",
    choices = {},
    lastAction = "Ready",
    budgetRevision = 0,
    eventPayload = nil,
    rewardCooldowns = {},
    connections = {},
}

local configFolder = "AnimeMinePotassium"
local configPath = configFolder .. "/config-" .. tostring(game.GameId)
    .. "-" .. tostring(player.UserId) .. ".json"
local booleanSettings = {
    "chest", "pickaxes", "characters", "upgrades", "equipBest", "promoteMythics",
    "rewards", "webhook", "webhookMythical", "webhookExotic", "webhookHigher",
}
local validStages = {Highest = true, Off = true}
for _, zone in ipairs(MineConfig.ZoneKeys or {}) do
    validStages[zone] = true
end

local function applyConfig(config)
    if type(config) ~= "table" then
        return
    end
    for _, key in ipairs(booleanSettings) do
        if type(config[key]) == "boolean" then
            state[key] = config[key]
        end
    end
    for _, key in ipairs({"characterPercent", "upgradePercent"}) do
        local value = tonumber(config[key])
        if value and value == value and value > -math.huge and value < math.huge then
            state[key] = math.clamp(math.floor(value + 0.5), 0, 100)
        end
    end
    if type(config.stage) == "string" and validStages[config.stage] then
        state.stage = config.stage
    end
    if type(config.webhookUrl) == "string" then
        state.webhookUrl = config.webhookUrl
    end
    if type(config.choices) == "table" then
        for _, pickaxe in ipairs(MineConfig.Pickaxes or {}) do
            if not pickaxe.RobuxOnly and not MineConfig.IsPickaxeFree(pickaxe) then
                state.choices[pickaxe.Name] = config.choices[pickaxe.Name] == true
            end
        end
    end
    if state.promoteMythics then
        state.characters = true
    end
end

if type(readfile) == "function" and type(isfile) == "function" then
    local ok, config = pcall(function()
        return isfile(configPath) and HttpService:JSONDecode(readfile(configPath)) or nil
    end)
    if ok then
        applyConfig(config)
    end
end
applyConfig(previousState)

local function saveConfig()
    if type(writefile) ~= "function" or type(makefolder) ~= "function" then
        return
    end
    local config = {version = 1, choices = {}}
    for _, key in ipairs(booleanSettings) do
        config[key] = state[key]
    end
    config.characterPercent = state.characterPercent
    config.upgradePercent = state.upgradePercent
    config.stage = state.stage
    config.webhookUrl = state.webhookUrl
    for name, selected in pairs(state.choices) do
        if selected then
            config.choices[name] = true
        end
    end
    pcall(function()
        if type(isfolder) ~= "function" or not isfolder(configFolder) then
            makefolder(configFolder)
        end
        writefile(configPath, HttpService:JSONEncode(config))
    end)
end

local saveRevision = 0
local function scheduleSave()
    saveRevision += 1
    local revision = saveRevision
    task.delay(0.6, function()
        if state.running and revision == saveRevision then
            saveConfig()
        end
    end)
end

global.AnimeMinePotassium = state
saveConfig()

local function send(action, ...)
    if action == IndexRewards.Events.Claim or action == EventsConfig.Events.Claim
        or action == DailyQuests.Events.Claim then
        local pieces = {action}
        for index = 1, select("#", ...) do
            pieces[#pieces + 1] = tostring(select(index, ...))
        end
        local key = table.concat(pieces, "|")
        local now = os.clock()
        if now < (state.rewardCooldowns[key] or 0) then
            return false
        end
        state.rewardCooldowns[key] = now + 8
    end
    GameState.SendEvent(action, ...)
    state.lastAction = action
    return true
end

local function snapshot()
    local data = GameState.GetData2()
    if type(data) ~= "table" or type(data.MineGame) ~= "table" then
        return nil
    end
    return data, data.MineGame, tonumber(data.Money) or 0
end

local function cheapestCharacter(mine, limit)
    local best
    for key, holder in pairs(mine.Holders or {}) do
        if type(holder) == "table" and type(holder.CharName) == "string" then
            local item = Items.GetItemData(holder.CharName)
            if item then
                local level = MineConfig.GetHolderLevel(holder)
                local cap = MineConfig.GetCharLevelCap(mine, key, holder, item, Items.GetItemData)
                if level < cap then
                    local cost = tonumber(MineConfig.GetCharacterUpgradeCost(level, item))
                    if cost and cost > 0 and cost < limit and (not best or cost < best.cost) then
                        best = {key = key, cost = cost}
                    end
                end
            end
        end
    end
    return best
end

local function cheapestUpgrade(mine, limit)
    local best
    for _, upgrade in ipairs(MineConfig.CoreUpgrades or {}) do
        local level = MineConfig.GetCoreLevel(mine, upgrade.Id)
        if level < upgrade.Max then
            local cost = tonumber(upgrade.Cost(level))
            if cost and cost > 0 and cost < limit and (not best or cost < best.cost) then
                best = {action = upgrade.Event, cost = cost}
            end
        end
    end
    for _, zone in ipairs(MineConfig.ZoneKeys or {}) do
        if (mine.UnlockedZones or {})[zone] then
            local skills = (mine.Skills or {})[zone] or {}
            for _, node in ipairs(MineConfig.GetSkillNodes(zone)) do
                if not MineConfig.IsSkillNodeMaxed(skills, node)
                    and MineConfig.IsSkillNodeOpen(skills, node) then
                    local level = tonumber(skills[node.Family]) or 0
                    local cost = tonumber(MineConfig.GetSkillCost(zone, level, node.Family))
                    if cost and cost > 0 and cost < limit and (not best or cost < best.cost) then
                        best = {
                            action = "MineBuySkill",
                            zone = zone,
                            family = node.Family,
                            id = node.Id,
                            cost = cost,
                        }
                    end
                end
            end
        end
    end
    return best
end

local function buySelectedPickaxes(data, mine, money)
    local available, sent = money, 0
    for index = #(MineConfig.Pickaxes or {}), 1, -1 do
        local pickaxe = MineConfig.Pickaxes[index]
        if state.choices[pickaxe.Name]
            and not pickaxe.RobuxOnly
            and not MineConfig.IsPickaxeFree(pickaxe)
            and (mine.UnlockedZones or {})[pickaxe.ZoneReq] then
            local remaining = MineStock.GetRemaining(data, pickaxe.Name)
            local cost = tonumber(pickaxe.Cost)
            if cost and cost > 0 and cost <= available then
                local quantity = 0
                if MineStock.IsStocked(pickaxe) then
                    if type(remaining) == "number" then
                        quantity = math.min(math.floor(remaining), math.floor(available / cost), 12 - sent)
                    end
                else
                    local owned = (tonumber((mine.Pickaxes or {})[pickaxe.Name]) or 0)
                        + MineConfig.CountAssignedPickaxes(mine.Holders, pickaxe.Name)
                    if owned < 1 then
                        quantity = 1
                    end
                end
                for _ = 1, quantity do
                    if not state.running or not state.pickaxes or not state.choices[pickaxe.Name] then
                        return sent
                    end
                    send("MineBuyPickaxe", index)
                    available -= cost
                    sent += 1
                    task.wait(0.12)
                end
                if sent >= 12 then
                    break
                end
            end
        end
    end
    return sent
end

local function copyForPurchases(mine)
    local copy = table.clone(mine)
    copy.Holders = {}
    for key, holder in pairs(mine.Holders or {}) do
        copy.Holders[key] = type(holder) == "table" and table.clone(holder) or holder
    end
    copy.Skills = {}
    for zone, skills in pairs(mine.Skills or {}) do
        copy.Skills[zone] = type(skills) == "table" and table.clone(skills) or skills
    end
    return copy
end

local function affordablePriority(mine, limit)
    local key = state.priorityMiner
    local holder = key and (mine.Holders or {})[key]
    if type(holder) ~= "table" or type(holder.CharName) ~= "string" then
        return nil
    end
    local item = Items.GetItemData(holder.CharName)
    if not item then
        return nil
    end
    local currentDamage = MineConfig.GetHolderDamage(holder, item)
    local weakestOther
    for otherKey, otherHolder in pairs(mine.Holders or {}) do
        if otherKey ~= key and type(otherKey) == "string" and otherKey:match("^M%d+$")
            and type(otherHolder) == "table" and type(otherHolder.CharName) == "string" then
            local otherItem = Items.GetItemData(otherHolder.CharName)
            if otherItem then
                local damage = MineConfig.GetHolderDamage(otherHolder, otherItem)
                if type(damage) == "number" and (not weakestOther or damage < weakestOther) then
                    weakestOther = damage
                end
            end
        end
    end
    if weakestOther and type(currentDamage) == "number"
        and currentDamage > weakestOther * 1.05 then
        state.priorityMiner = nil
        return nil
    end
    local level = MineConfig.GetHolderLevel(holder)
    if level >= MineConfig.GetCharLevelCap(mine, key, holder, item, Items.GetItemData) then
        state.priorityMiner = nil
        return nil
    end
    local cost = tonumber(MineConfig.GetCharacterUpgradeCost(level, item))
    return cost and cost > 0 and cost < limit and {key = key, cost = cost} or nil
end

local function spendBatch(mine, money, characterBudget, upgradeBudget, sharedBudget)
    characterBudget = state.characters and math.max(0, characterBudget) or 0
    upgradeBudget = state.upgrades and math.max(0, upgradeBudget) or 0
    sharedBudget = math.max(0, sharedBudget)
    if sharedBudget <= 0 then
        return 0, 0, 0
    end

    local planned = copyForPurchases(mine)
    local available = money
    local sent, characterSpent, upgradeSpent = 0, 0, 0
    local startingRevision = state.budgetRevision
    for _ = 1, 12 do
        if not state.running or sharedBudget <= 0
            or state.budgetRevision ~= startingRevision then
            break
        end
        local charLimit = math.min(characterBudget, sharedBudget, available,
            available * state.characterPercent / 100)
        local upgradeLimit = math.min(upgradeBudget, sharedBudget, available,
            available * state.upgradePercent / 100)
        local character
        if state.characters then
            if state.priorityMiner then
                character = affordablePriority(planned, charLimit)
            else
                character = cheapestCharacter(planned, charLimit)
            end
        end
        local upgrade = state.upgrades and cheapestUpgrade(planned, upgradeLimit) or nil
        if not character and not upgrade then
            break
        end

        if character and (not upgrade or character.cost <= upgrade.cost or state.priorityMiner == character.key) then
            send("MineUpgradeCharacter", character.key)
            local holder = planned.Holders[character.key]
            holder.CharLevel = MineConfig.GetHolderLevel(holder) + 1
            characterBudget -= character.cost
            sharedBudget -= character.cost
            available -= character.cost
            characterSpent += character.cost
        else
            if upgrade.action == "MineBuySkill" then
                send(upgrade.action, upgrade.zone, upgrade.family, upgrade.id)
                local skills = planned.Skills[upgrade.zone]
                skills[upgrade.family] = (tonumber(skills[upgrade.family]) or 0) + 1
            else
                send(upgrade.action)
                for _, def in ipairs(MineConfig.CoreUpgrades or {}) do
                    if def.Event == upgrade.action then
                        planned[def.Field] = MineConfig.GetCoreLevel(planned, def.Id) + 1
                        break
                    end
                end
            end
            upgradeBudget -= upgrade.cost
            sharedBudget -= upgrade.cost
            available -= upgrade.cost
            upgradeSpent += upgrade.cost
        end
        sent += 1
        task.wait(0.1)
    end
    return sent, characterSpent, upgradeSpent
end

local function rarityRank(name)
    return MineConfig.RarityIndex[name] or 0
end

local function bestMythicPromotion(mine, money)
    local weakest
    for key, holder in pairs(mine.Holders or {}) do
        if type(key) == "string" and key:match("^M%d+$")
            and type(holder) == "table" and type(holder.CharName) == "string" then
            local item = Items.GetItemData(holder.CharName)
            if item and item.MineRole ~= "Hauler" then
                local damage = MineConfig.GetHolderDamage(holder, item)
                if type(damage) == "number" and (not weakest or damage < weakest.damage) then
                    weakest = {key = key, holder = holder, damage = damage}
                end
            end
        end
    end
    if not weakest then
        return nil
    end

    local budget = money * state.characterPercent / 100
    local best
    for _, entry in ipairs(MineInventory.EntriesFromCounts(mine, mine.Characters or {})) do
        if entry.Kind == "Character" and entry.Role == "Miner"
            and entry.Count > 0 and rarityRank(entry.Rarity) >= rarityRank("Mythical") then
            local item = Items.GetItemData(entry.Name)
            if item and not MineConfig.GetScaledPct(item) then
                local level = entry.Level or 1
                local spent = 0
                while level < MineConfig.CharMaxLevel do
                    local cost = tonumber(MineConfig.GetCharacterUpgradeCost(level, item))
                    if not cost or cost <= 0 or spent + cost > budget then
                        break
                    end
                    spent += cost
                    level += 1
                end
                local pickaxe = MineConfig.GetHolderPickaxe(weakest.holder)
                local damage = MineConfig.GetCharacterDamage(item)
                    * MineConfig.GetCharacterLevelMultiplier(level)
                    * MineConfig.GetVariantMult(entry.Variant)
                    * (pickaxe and pickaxe.Multiplier or 1)
                if damage > weakest.damage * 1.05 and (not best or damage > best.damage) then
                    best = {key = entry.Key, name = entry.Name, slot = weakest.key, damage = damage}
                end
            end
        end
    end
    return best
end

local function ownHolderPrompt(slot)
    local world = workspace:FindFirstChild("MineWorld")
    local plots = world and world:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            local holders = plot:FindFirstChild("Holders")
            local holder = holders and holders:FindFirstChild(slot)
            local pad = holder and holder:FindFirstChild("Pad")
            return pad and pad:FindFirstChild("HolderPrompt") or nil
        end
    end
    return nil
end

local function processPromotion(mine, money)
    if not state.promoteMythics and not state.promotion then
        state.priorityMiner = nil
        return
    end
    if type(fireproximityprompt) ~= "function" then
        state.lastAction = "Mythic: prompt API unavailable"
        return
    end
    local job = state.promotion
    if not job then
        if os.clock() < (state.nextPromotionAt or 0) then
            return
        end
        local candidate = bestMythicPromotion(mine, money)
        if not candidate then
            return
        end
        local prompt = ownHolderPrompt(candidate.slot)
        if not prompt then
            state.lastAction = "Mythic: plot prompt unavailable"
            return
        end
        job = {key = candidate.key, name = candidate.name, slot = candidate.slot,
            phase = "awaitEmpty", deadline = os.clock() + 7, prompt = prompt}
        state.promotion = job
        state.nextPromotionAt = os.clock() + 60
        state.suppressDropsUntil = os.clock() + 3
        fireproximityprompt(prompt)
        state.lastAction = "Mythic: picking up weakest miner"
        return
    end
    if os.clock() > job.deadline then
        state.promotion = nil
        send("MineEquipBest")
        state.lastAction = "Mythic swap timed out"
        return
    end
    local holder = (mine.Holders or {})[job.slot]
    if job.phase == "awaitEmpty" and not (holder and holder.CharName) then
        job.hotbar = MineInventory.TargetSlot(mine, job.key)
        send("MineAssignHotbar", job.hotbar, job.key)
        job.phase = "awaitHotbar"
    elseif job.phase == "awaitHotbar" then
        if (mine.Hotbar or {})[job.hotbar] == job.key then
            send("MineEquipSlot", job.hotbar)
            job.phase = "awaitEquip"
        end
    elseif job.phase == "awaitEquip" then
        if MineInventory.EquippedSlot(mine) == job.hotbar then
            fireproximityprompt(job.prompt)
            job.phase = "awaitPlace"
            state.lastAction = "Mythic: placing " .. job.name
        end
    elseif job.phase == "awaitPlace" and holder and holder.CharName == job.name then
        state.priorityMiner = job.slot
        state.promotion = nil
        state.lastAction = "Mythic placed; levelling next"
    end
end

local function postRareDrop(key, amount, rarity)
    local url = state.webhookUrl
    if not state.webhook or not url:match("^https://") then
        return
    end
    local body = HttpService:JSONEncode({
        content = string.format("Anime Mine · %s found %dx %s (%s)", player.Name, amount, key, rarity),
    })
    task.spawn(function()
        local httpRequest = request or http_request
        if type(httpRequest) == "function" then
            pcall(httpRequest, {
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body,
            })
        end
    end)
end

local function scanRareDrops(mine)
    local current = {}
    for key, count in pairs(mine.Characters or {}) do
        current[key] = tonumber(count) or 0
        local previous = state.lastInventory and (state.lastInventory[key] or 0)
        if previous and current[key] > previous
            and os.clock() >= (state.suppressDropsUntil or 0) then
            local name = MineConfig.ParseCharStack(key)
            local item = Items.GetItemData(name)
            local rarity = item and item.Rarity and item.Rarity.Rarity
            local notify = rarity == "Mythical" and state.webhookMythical
                or rarity == "Exotic" and state.webhookExotic
                or rarity and rarityRank(rarity) > rarityRank("Exotic") and state.webhookHigher
            if notify then
                postRareDrop(key, current[key] - previous, rarity)
            end
        end
    end
    state.lastInventory = current
end

state.eventConnection = GameState.ListenToEvent(EventsConfig.Events.State, function(payload)
    if state.running and type(payload) == "table" then
        state.eventPayload = payload
    end
end)

local function claimIndex(mine)
    local held = IndexRewards.HeldNames(mine)
    for _, key in ipairs(IndexRewards.Keys()) do
        local category = IndexRewards.Category(key)
        if category and (not category.Zone or (mine.UnlockedZones or {})[key]) then
            local progress = IndexRewards.State(mine, key, held)
            for _, tier in ipairs(progress.Track or {}) do
                if tier.Reached then
                    for index = 1, #(tier.Rewards or {}) do
                        if not tier.ClaimedRewards[index] then
                            if send(IndexRewards.Events.Claim, key, tier.Key, index) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

local function claimEventLadder(ladder, personal)
    if type(ladder) ~= "table" or ladder.Id == nil then
        return false
    end
    local tiers = personal and EventsConfig.PersonalTiers()
        or EventsConfig.Tiers(ladder.Days, EventsConfig.Catalog[ladder.Key])
    for tierIndex, threshold in ipairs(ladder.Thresholds or {}) do
        if (tonumber(ladder.Points) or 0) >= threshold
            and not (ladder.Claimed and ladder.Claimed[tierIndex]) then
            local tier = tiers and tiers[tierIndex]
            for _, reward in ipairs(tier and EventsConfig.Shown(tier.Rewards) or {}) do
                local index = table.find(tier.Rewards, reward)
                local flags = tonumber((ladder.Got or {})[tierIndex]) or 0
                if index and not bit32.btest(flags, 2 ^ (index - 1)) then
                    if send(EventsConfig.Events.Claim, ladder.Id, tierIndex, index) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function claimEvents()
    local payload = state.eventPayload
    for _, event in ipairs(payload and payload.Events or {}) do
        if claimEventLadder(event, false) then
            return true
        end
        if EventsConfig.PersonalOn() and claimEventLadder(event.Personal, true) then
            return true
        end
    end
    return false
end

local function claimDaily(data)
    if DailyQuests.Enabled ~= true then
        return false
    end
    local daily = data.DailyQuests
    if type(daily) ~= "table" or not DailyQuests.IsToday(daily, workspace:GetServerTimeNow()) then
        return false
    end
    for _, slot in ipairs(DailyQuests.Slots) do
        local quest = DailyQuests.Quest(daily, slot)
        if quest and quest.Claimed ~= true and DailyQuests.IsComplete(quest) then
            if send(DailyQuests.Events.Claim, slot) then
                return true
            end
        end
    end
    if DailyQuests.AllDone(daily) and not (daily.Grand and daily.Grand.Claimed) then
        if send(DailyQuests.Events.Claim, DailyQuests.GrandSlot) then
            return true
        end
    end
    return false
end

local accent = Color3.fromRGB(250, 179, 65)
local bg = Color3.fromRGB(22, 24, 29)
local surface = Color3.fromRGB(36, 39, 46)
local muted = Color3.fromRGB(151, 157, 169)
local white = Color3.fromRGB(239, 241, 246)

local function make(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    make("UICorner", parent, {CornerRadius = UDim.new(0, radius)})
end

local gui = make("ScreenGui", playerGui, {
    Name = "AnimeMinePotassiumPanel",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
state.gui = gui
state.stop = function()
    saveConfig()
    state.running = false
    for _, connection in ipairs(state.connections) do
        connection:Disconnect()
    end
    if state.eventConnection then
        state.eventConnection:Disconnect()
    end
    gui:Destroy()
    if global.AnimeMinePotassium == state then
        global.AnimeMinePotassium = nil
    end
end
local function track(connection)
    table.insert(state.connections, connection)
    return connection
end

local panel = make("Frame", gui, {
    Size = UDim2.fromOffset(310, 450),
    Position = UDim2.new(1, -326, 0.5, -225),
    BackgroundColor3 = bg,
    BorderSizePixel = 0,
})
corner(panel, 10)
make("UIStroke", panel, {Color = Color3.fromRGB(72, 76, 86), Thickness = 1})

local header = make("Frame", panel, {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundTransparency = 1,
    Active = true,
})
make("TextLabel", header, {
    Size = UDim2.new(1, -76, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1,
    Text = "ANIME MINE  /  AUTO",
    TextColor3 = accent,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local minimize = make("TextButton", header, {
    Size = UDim2.fromOffset(28, 25),
    Position = UDim2.new(1, -63, 0, 6),
    BackgroundColor3 = surface,
    BorderSizePixel = 0,
    Text = "−",
    TextColor3 = white,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
})
corner(minimize, 5)
local close = make("TextButton", header, {
    Size = UDim2.fromOffset(28, 25),
    Position = UDim2.new(1, -32, 0, 6),
    BackgroundColor3 = surface,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = white,
    TextSize = 17,
    Font = Enum.Font.GothamBold,
})
corner(close, 5)

local body = make("ScrollingFrame", panel, {
    Size = UDim2.new(1, -20, 1, -48),
    Position = UDim2.fromOffset(10, 40),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
local list = make("UIListLayout", body, {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
})

local function row(label, order, height)
    local frame = make("Frame", body, {
        Size = UDim2.new(1, 0, 0, height or 28),
        BackgroundColor3 = surface,
        BorderSizePixel = 0,
        LayoutOrder = order,
    })
    corner(frame, 5)
    make("TextLabel", frame, {
        Size = UDim2.new(1, -113, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = white,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local button = make("TextButton", frame, {
        Size = UDim2.fromOffset(103, (height or 28) - 6),
        Position = UDim2.new(1, -106, 0, 3),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
        TextColor3 = muted,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
    })
    corner(button, 4)
    return button
end

local function toggle(label, key, order)
    local button = row(label, order)
    local function refresh()
        button.Text = state[key] and "ON" or "OFF"
        button.TextColor3 = state[key] and accent or muted
    end
    button.MouseButton1Click:Connect(function()
        state[key] = not state[key]
        if key == "characters" or key == "upgrades" or key == "promoteMythics" then
            state.budgetRevision += 1
        end
        if key == "promoteMythics" and state[key] then
            state.characters = true
            if state.refreshCharacters then
                state.refreshCharacters()
            end
        end
        refresh()
        scheduleSave()
    end)
    refresh()
    return refresh
end

toggle("Collect chest", "chest", 1)
toggle("Buy pickaxes", "pickaxes", 2)
state.refreshCharacters = toggle("Level miners", "characters", 3)

local function percentSlider(label, key, order)
    local frame = make("Frame", body, {
        Size = UDim2.new(1, 0, 0, 41),
        BackgroundColor3 = surface,
        BorderSizePixel = 0,
        LayoutOrder = order,
    })
    corner(frame, 5)
    local title = make("TextLabel", frame, {
        Size = UDim2.new(1, -18, 0, 19),
        Position = UDim2.fromOffset(9, 2),
        BackgroundTransparency = 1,
        TextColor3 = white,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local sliderTrack = make("Frame", frame, {
        Size = UDim2.new(1, -18, 0, 7),
        Position = UDim2.fromOffset(9, 27),
        BackgroundColor3 = bg,
        BorderSizePixel = 0,
        Active = true,
    })
    corner(sliderTrack, 4)
    local fill = make("Frame", sliderTrack, {
        Size = UDim2.fromScale(state[key] / 100, 1),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
    })
    corner(fill, 4)
    local dragging = false
    local function setFromX(x)
        local percent = math.clamp(math.floor((x - sliderTrack.AbsolutePosition.X)
            / math.max(sliderTrack.AbsoluteSize.X, 1) * 100 + 0.5), 0, 100)
        if state[key] ~= percent then
            state[key] = percent
            state.budgetRevision += 1
            scheduleSave()
        end
        title.Text = label .. " · " .. tostring(percent) .. "% of current money"
        fill.Size = UDim2.fromScale(percent / 100, 1)
    end
    title.Text = label .. " · " .. tostring(state[key]) .. "% of current money"
    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

percentSlider("Miner level budget", "characterPercent", 4)
toggle("Buy upgrades", "upgrades", 5)
percentSlider("Upgrade budget", "upgradePercent", 6)
toggle("Equip best", "equipBest", 7)
toggle("Promote mythics", "promoteMythics", 8)
toggle("Claim rewards", "rewards", 9)
toggle("Rare drop webhook", "webhook", 10)
toggle("Mythical alerts", "webhookMythical", 11)
toggle("Exotic alerts", "webhookExotic", 12)
toggle("Higher alerts", "webhookHigher", 13)

local webhookBox = make("TextBox", body, {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = surface,
    BorderSizePixel = 0,
    LayoutOrder = 14,
    PlaceholderText = "Paste webhook URL here",
    PlaceholderColor3 = muted,
    Text = state.webhookUrl,
    TextColor3 = white,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
})
corner(webhookBox, 5)
make("UIPadding", webhookBox, {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)})
webhookBox:GetPropertyChangedSignal("Text"):Connect(function()
    state.webhookUrl = webhookBox.Text:match("^%s*(.-)%s*$") or ""
    scheduleSave()
end)

local stageButton = row("Mine stage", 15)
local stageOptions = {"Highest", "Off"}
for _, zone in ipairs(MineConfig.ZoneKeys or {}) do
    table.insert(stageOptions, zone)
end
local function refreshStage()
    stageButton.Text = state.stage
    stageButton.TextColor3 = state.stage == "Off" and muted or accent
end
stageButton.MouseButton1Click:Connect(function()
    local index = table.find(stageOptions, state.stage) or 1
    state.stage = stageOptions[index % #stageOptions + 1]
    refreshStage()
    scheduleSave()
end)
refreshStage()

local optionLabel = make("TextLabel", body, {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    LayoutOrder = 16,
    Text = "PICKAXES TO BUY  ·  ALL STOCK",
    TextColor3 = muted,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
})
local picker = make("ScrollingFrame", body, {
    Size = UDim2.new(1, 0, 0, 96),
    BackgroundColor3 = surface,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = accent,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 17,
})
corner(picker, 5)
make("UIListLayout", picker, {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 1),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
for index, pickaxe in ipairs(MineConfig.Pickaxes or {}) do
    if not pickaxe.RobuxOnly and not MineConfig.IsPickaxeFree(pickaxe) then
        state.choices[pickaxe.Name] = state.choices[pickaxe.Name] == true
        local button = make("TextButton", picker, {
            Size = UDim2.new(1, -6, 0, 23),
            BackgroundColor3 = bg,
            BorderSizePixel = 0,
            TextColor3 = white,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = index,
        })
        local function refresh()
            button.Text = (state.choices[pickaxe.Name] and "  ✓  " or "  ○  ") .. pickaxe.Name
            button.TextColor3 = state.choices[pickaxe.Name] and white or muted
        end
        button.MouseButton1Click:Connect(function()
            state.choices[pickaxe.Name] = not state.choices[pickaxe.Name]
            refresh()
            scheduleSave()
        end)
        refresh()
    end
end

local status = make("TextLabel", body, {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    LayoutOrder = 18,
    Text = "Ready · waiting for game data",
    TextColor3 = muted,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

local collapsed = false
minimize.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    body.Visible = not collapsed
    panel.Size = UDim2.fromOffset(310, collapsed and 38 or 450)
    minimize.Text = collapsed and "+" or "−"
end)
close.MouseButton1Click:Connect(function()
    state.stop()
end)

do
    local dragging, startInput, startPosition
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startInput = input.Position
            startPosition = panel.Position
        end
    end)
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - startInput
            panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end))
end

task.spawn(function()
    local lastChest, lastZone, lastEquip, lastPickaxe = 0, 0, 0, 0
    local lastReward, lastEventOpen = 0, 0
    local lastBatchAt = 0
    local rewardTurn = 0
    while state.running and gui.Parent do
        local ok, err = pcall(function()
            local data, mine, money = snapshot()
            if not data then
                status.Text = "Waiting for MineGame data…"
                return
            end

            local now = os.clock()
            scanRareDrops(mine)
            if state.chest and now - lastChest >= 4 and next(mine.Chest or {}) ~= nil then
                send("MineTakeChest")
                lastChest = now
            end

            if state.stage ~= "Off" and now - lastZone >= 3 then
                local target = state.stage
                if target == "Highest" then
                    target = "Z" .. tostring(MineConfig.DeepestUnlockedZone(mine))
                end
                local current = "Z" .. tostring(tonumber(mine.CurrentZone) or 1)
                if target ~= current and (mine.UnlockedZones or {})[target] then
                    send("MineSelectZone", target)
                    lastZone = now
                end
            end

            if state.equipBest and not state.promotion and not state.priorityMiner
                and now - lastEquip >= 15 then
                send("MineEquipBest")
                lastEquip = now
            end

            local boughtPickaxe = false
            if state.pickaxes and now - lastPickaxe >= 2.5 then
                local count = buySelectedPickaxes(data, mine, money)
                if count > 0 then
                    lastPickaxe = now
                    boughtPickaxe = true
                    state.lastAction = "Bought " .. count .. " selected pickaxes"
                end
            end

            processPromotion(mine, money)

            if (state.characters or state.upgrades) and not state.promotion
                and not boughtPickaxe and now - lastPickaxe >= 2.5 and money > 0
                and now - lastBatchAt >= 3 then
                local characterCap = state.characters and money * state.characterPercent / 100 or 0
                local upgradeCap = state.upgrades and money * state.upgradePercent / 100 or 0
                local sharedCap = money * math.max(
                    state.characters and state.characterPercent or 0,
                    state.upgrades and state.upgradePercent or 0
                ) / 100
                if math.max(characterCap, upgradeCap) > 0 and sharedCap > 0 then
                    local count = spendBatch(
                        mine, money, characterCap, upgradeCap, sharedCap)
                    if count > 0 then
                        lastBatchAt = now
                        state.lastAction = "Bought " .. count .. " levels/upgrades within budget"
                    end
                end
            end

            if state.rewards then
                if now - lastEventOpen >= 15 and EventsConfig.Enabled then
                    send(EventsConfig.Events.Open)
                    lastEventOpen = now
                end
                if now - lastReward >= 1.5 then
                    rewardTurn = rewardTurn % 3 + 1
                    local claimed = false
                    for offset = 0, 2 do
                        local kind = (rewardTurn + offset - 1) % 3 + 1
                        if kind == 1 then
                            claimed = claimIndex(mine)
                        elseif kind == 2 then
                            claimed = claimEvents()
                        else
                            claimed = claimDaily(data)
                        end
                        if claimed then
                            lastReward = now
                            break
                        end
                    end
                end
            end

            status.Text = "Stage " .. tostring(mine.CurrentZone or 1)
                .. "  ·  " .. state.lastAction
        end)
        if not ok then
            status.Text = "Error: " .. tostring(err)
        end
        task.wait(0.25)
    end
end)

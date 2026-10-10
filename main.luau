-- Anime Mine automation panel for Potassium (client-side Luau).
-- Uses the same GamestateEvent actions as the game's own client UI.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modules = ReplicatedStorage:WaitForChild("Modules")
local GameState = require(modules:WaitForChild("GameState"))
local MineConfig = require(modules:WaitForChild("MineConfig"))
local MineStock = require(modules:WaitForChild("MineStock"))
local Items = require(modules:WaitForChild("Items"))

local global = (type(getgenv) == "function" and getgenv()) or _G
if global.AnimeMinePotassium then
    global.AnimeMinePotassium.running = false
    if global.AnimeMinePotassium.gui then
        global.AnimeMinePotassium.gui:Destroy()
    end
end

local state = {
    running = true,
    chest = true,
    pickaxes = false,
    characters = false,
    upgrades = false,
    equipBest = true,
    stage = "Highest",
    choices = {},
    lastAction = "Ready",
}
global.AnimeMinePotassium = state

local function send(action, ...)
    GameState.SendEvent(action, ...)
    state.lastAction = action
end

local function snapshot()
    local data = GameState.GetData2()
    if type(data) ~= "table" or type(data.MineGame) ~= "table" then
        return nil
    end
    return data, data.MineGame, tonumber(data.Money) or 0
end

local function cheapestCharacter(mine, money)
    local best
    for key, holder in pairs(mine.Holders or {}) do
        if type(holder) == "table" and type(holder.CharName) == "string" then
            local item = Items.GetItemData(holder.CharName)
            if item then
                local level = MineConfig.GetHolderLevel(holder)
                local cap = MineConfig.GetCharLevelCap(mine, key, holder, item, Items.GetItemData)
                if level < cap then
                    local cost = tonumber(MineConfig.GetCharacterUpgradeCost(level, item))
                    if cost and cost > 0 and cost <= money and (not best or cost < best.cost) then
                        best = {key = key, cost = cost}
                    end
                end
            end
        end
    end
    return best
end

local function cheapestUpgrade(mine, money)
    local best
    for _, upgrade in ipairs(MineConfig.CoreUpgrades or {}) do
        local level = MineConfig.GetCoreLevel(mine, upgrade.Id)
        if level < upgrade.Max then
            local cost = tonumber(upgrade.Cost(level))
            if cost and cost > 0 and cost <= money and (not best or cost < best.cost) then
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
                    if cost and cost > 0 and cost <= money and (not best or cost < best.cost) then
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

local function bestPickaxe(data, mine, money)
    local best
    for index, pickaxe in ipairs(MineConfig.Pickaxes or {}) do
        if state.choices[pickaxe.Name]
            and not pickaxe.RobuxOnly
            and not MineConfig.IsPickaxeFree(pickaxe)
            and (mine.UnlockedZones or {})[pickaxe.ZoneReq] then
            local owned = (tonumber((mine.Pickaxes or {})[pickaxe.Name]) or 0)
                + MineConfig.CountAssignedPickaxes(mine.Holders, pickaxe.Name)
            local remaining = MineStock.GetRemaining(data, pickaxe.Name)
            local cost = tonumber(pickaxe.Cost)
            if owned < 1 and cost and cost <= money
                and (remaining == nil or remaining > 0)
                and (not best or (tonumber(pickaxe.Multiplier) or 0) > best.multiplier) then
                best = {index = index, multiplier = tonumber(pickaxe.Multiplier) or 0}
            end
        end
    end
    return best
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

local panel = make("Frame", gui, {
    Size = UDim2.fromOffset(310, 395),
    Position = UDim2.new(1, -326, 0.5, -197),
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

local body = make("Frame", panel, {
    Size = UDim2.new(1, -20, 1, -48),
    Position = UDim2.fromOffset(10, 40),
    BackgroundTransparency = 1,
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
        refresh()
    end)
    refresh()
end

toggle("Collect chest", "chest", 1)
toggle("Buy pickaxes", "pickaxes", 2)
toggle("Level miners", "characters", 3)
toggle("Buy upgrades", "upgrades", 4)
toggle("Equip best", "equipBest", 5)

local stageButton = row("Mine stage", 6)
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
end)
refreshStage()

local optionLabel = make("TextLabel", body, {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    LayoutOrder = 7,
    Text = "PICKAXES TO BUY  ·  ONE OF EACH",
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
    LayoutOrder = 8,
})
corner(picker, 5)
make("UIListLayout", picker, {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 1),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
for index, pickaxe in ipairs(MineConfig.Pickaxes or {}) do
    if not pickaxe.RobuxOnly and not MineConfig.IsPickaxeFree(pickaxe) then
        state.choices[pickaxe.Name] = true
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
        end)
        refresh()
    end
end

local status = make("TextLabel", body, {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    LayoutOrder = 9,
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
    panel.Size = UDim2.fromOffset(310, collapsed and 38 or 395)
    minimize.Text = collapsed and "+" or "−"
end)
close.MouseButton1Click:Connect(function()
    state.running = false
    gui:Destroy()
    if global.AnimeMinePotassium == state then
        global.AnimeMinePotassium = nil
    end
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
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - startInput
            panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
end

task.spawn(function()
    local lastChest, lastZone, lastEquip, lastPurchase = 0, 0, 0, 0
    while state.running and gui.Parent do
        local ok, err = pcall(function()
            local data, mine, money = snapshot()
            if not data then
                status.Text = "Waiting for MineGame data…"
                return
            end

            local now = os.clock()
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

            if state.equipBest and now - lastEquip >= 15 then
                send("MineEquipBest")
                lastEquip = now
            end

            if now - lastPurchase >= 2.5 then
                local pickaxe = state.pickaxes and bestPickaxe(data, mine, money)
                local character = state.characters and cheapestCharacter(mine, money)
                local upgrade = state.upgrades and cheapestUpgrade(mine, money)
                if pickaxe then
                    send("MineBuyPickaxe", pickaxe.index)
                    lastPurchase = now
                elseif character and (not upgrade or character.cost <= upgrade.cost) then
                    send("MineUpgradeCharacter", character.key)
                    lastPurchase = now
                elseif upgrade then
                    if upgrade.action == "MineBuySkill" then
                        send(upgrade.action, upgrade.zone, upgrade.family, upgrade.id)
                    else
                        send(upgrade.action)
                    end
                    lastPurchase = now
                end
            end

            status.Text = "Stage " .. tostring(mine.CurrentZone or 1)
                .. "  ·  " .. state.lastAction
        end)
        if not ok then
            status.Text = "Error: " .. tostring(err)
        end
        task.wait(0.5)
    end
end)

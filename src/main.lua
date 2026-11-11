local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    loopDelay = 0.05,
    moveSpeed = 80,
    moveStopDistance = 2.5,
    mineTimeSafety = 1.05,

    mushroomDelay = 0.4,
    mineName = "Mine",
    oreRange = 500,
    oreCacheTime = 1,
    lootRange = 300,

    blockEvent = "BlockEvent",
    minedEvent = "BlockMinedEvent",
    pickaxeRemote = "UpdatePickaxe",
    defaultMineTime = 4,

    orePrices = {
        Dirt = 3,
        Stone = 5,
        Coal = 12,
        ["Copper Ore"] = 20,
        ["Iron Ore"] = 32,
        Sulfur = 38,
        ["Silver Ore"] = 45,
        Emerald = 65,
        Ruby = 85,
        Ignis = 90,
        Sapphire = 110,
        ["Gold Ore"] = 150,
        Hellstone = 18,
        Sanctite = 20,
        Quartz = 225,
        Amethyst = 300,
        Obsidian = 300,
        Diamond = 400,
        ["Uranium Ore"] = 300,
        ["Mithril Ore"] = 300,
        ["Promethium Ore"] = 300,
        ["Malachite Ore"] = 550,
        ["Azurite Ore"] = 550,
    },
}

---------------------------------------------------------------------------
-- Game modules
---------------------------------------------------------------------------

local Game = {}

pcall(function()
    local modules = ReplicatedStorage:WaitForChild("Modules")
    Game.Resources = require(modules:WaitForChild("Resources"))
    Game.Mine = require(modules:WaitForChild("Mining"):WaitForChild("Mine"))
    Game.Constants = require(modules:WaitForChild("Constants"))
end)

Game.attrMinePosition = (Game.Constants and Game.Constants.ATTR_MINE_POSITION) or "MinePosition"
Game.attrWorldId = (Game.Constants and Game.Constants.ATTR_WORLD_ID) or "WorldId"

local blockSize = (Game.Mine and Game.Mine.BLOCK_SIZE) or 7
local blockOffsets = (Game.Mine and Game.Mine.OFFSETS) or {
    LEFT = Vector3.new(-1, 0, 0),
    RIGHT = Vector3.new(1, 0, 0),
    UP = Vector3.new(0, -1, 0),
    DOWN = Vector3.new(0, 1, 0),
    FRONT = Vector3.new(0, 0, 1),
    BACK = Vector3.new(0, 0, -1),
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local Log = {
    enabled = false,
}

function Log.print(...)
    if Log.enabled then
        print("[em2]", ...)
    end
end

function Log.warn(...)
    if Log.enabled then
        warn("[em2]", ...)
    end
end

local function vec3ToString(position)
    return ("%d,%d,%d"):format(position.X, position.Y, position.Z)
end

local function typeOf(block)
    local typeValue = block:FindFirstChild("Type")
    if typeValue then
        return typeValue.Value
    end
    return block:GetAttribute("Resource")
end

local function resourceInfo(name)
    if not name or not Game.Resources then
        return nil
    end
    return Game.Resources[name]
end

---------------------------------------------------------------------------
-- Manager
---------------------------------------------------------------------------

local Manager = {}

function Manager.new(step, cleanup)
    local manager = {
        enabled = false,
        token = 0,
    }

    function manager.start()
        if manager.enabled then
            return
        end

        manager.enabled = true
        manager.token += 1
        local token = manager.token

        task.spawn(function()
            while manager.enabled and manager.token == token do
                local ok, err = pcall(step)
                if not ok then
                    warn("[main] " .. tostring(err))
                end
                task.wait(Config.loopDelay)
            end
        end)
    end

    function manager.stop()
        if not manager.enabled then
            return
        end

        manager.enabled = false
        manager.token += 1
        if cleanup then
            cleanup()
        end
    end

    function manager.toggle()
        if manager.enabled then
            manager.stop()
        else
            manager.start()
        end
        return manager.enabled
    end

    return manager
end

---------------------------------------------------------------------------
-- Character
---------------------------------------------------------------------------

local Character = {}

local function isPickaxe(tool)
    if not tool:IsA("Tool") then
        return false
    end
    if tool:FindFirstChild(Config.pickaxeRemote) then
        return true
    end
    local name = tool.Name:lower()
    return name:find("pick") ~= nil and name:find("axe") == nil
end

function Character.get()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character or not character.PrimaryPart then
        character = player.CharacterAdded:Wait()
    end
    return character
end

function Character.getPickaxe(character)
    local equipped = character:FindFirstChildWhichIsA("Tool")
    if equipped and isPickaxe(equipped) then
        return equipped
    end

    local backpack = Players.LocalPlayer:FindFirstChild("Backpack")
    if not backpack then
        return nil
    end
    for _, item in ipairs(backpack:GetChildren()) do
        if isPickaxe(item) then
            return item
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Movement (anchored tween)
---------------------------------------------------------------------------

local Movement = {}

local function setPlatformStand(character, state)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = state
    end
end

function Movement.release()
    if Movement.tween then
        Movement.tween:Cancel()
    end
    Movement.tween = nil

    if Movement.holdRoot then
        Movement.holdRoot.Anchored = false
        Movement.holdRoot = nil
    end

    if Movement.root then
        Movement.root.Anchored = false
    end
    Movement.root = nil

    setPlatformStand(Movement.character, false)
    Movement.character = nil
end

function Movement.hold(character)
    local root = character.PrimaryPart
    if root then
        root.Anchored = true
        Movement.holdRoot = root
    end
end

function Movement.releaseHold()
    if Movement.holdRoot then
        Movement.holdRoot.Anchored = false
        Movement.holdRoot = nil
    end
end

function Movement.cancel()
    Movement.release()
end

function Movement.to(character, position, speed)
    local root = character.PrimaryPart
    if not root then
        return
    end

    Movement.release()

    local distance = (position - root.Position).Magnitude
    if distance < Config.moveStopDistance then
        return
    end

    speed = speed or Config.moveSpeed
    setPlatformStand(character, true)

    root.Anchored = true
    Movement.character = character
    Movement.root = root

    local duration = math.clamp(distance / speed, 0.1, 5)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(position),
    })

    Movement.tween = tween
    tween:Play()

    local deadline = os.clock() + duration + 1
    while Movement.tween == tween and os.clock() < deadline do
        task.wait(0.03)
    end

    local reached = (root.Position - position).Magnitude <= Config.moveStopDistance + 3

    if Movement.tween == tween then
        Movement.release()
    end

    if not reached and root.Parent then
        character:PivotTo(CFrame.new(position))
    end
end

---------------------------------------------------------------------------
-- Mining
---------------------------------------------------------------------------

local Mining = {
    baseMineTime = Config.defaultMineTime,
    lastReject = 0,
}

function Mining.bind(pickaxe)
    local remote = pickaxe:FindFirstChild(Config.pickaxeRemote)
    if not remote then
        return
    end

    remote.OnClientEvent:Connect(function(data)
        if typeof(data) == "table" and type(data.BaseMineTime) == "number" then
            Mining.baseMineTime = data.BaseMineTime
        end
    end)
end

function Mining.prepare(character)
    local pickaxe = Character.getPickaxe(character)
    if not pickaxe then
        return nil
    end

    if Mining.pickaxe ~= pickaxe then
        Mining.pickaxe = pickaxe
        Mining.bind(pickaxe)
    end

    if pickaxe.Parent ~= character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return nil
        end
        humanoid:EquipTool(pickaxe)
        task.wait(0.15)
    end

    return pickaxe
end

function Mining.mineTime(block)
    local info = resourceInfo(typeOf(block))
    local modifier = info and info.MineTimeModifier or 1
    local speed = Players.LocalPlayer:GetAttribute("ToolSpeedModifier") or 0

    return Mining.baseMineTime * ((100 - speed) / 100) * modifier
end

function Mining.maxDistance()
    local maxDistance = Mining.pickaxe and Mining.pickaxe:FindFirstChild("MaxDistance")
    return maxDistance and maxDistance.Value or 25
end

function Mining.besideLiquid(block)
    local position = block:GetAttribute(Game.attrMinePosition)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not position or not mine then
        return false
    end

    for _, offset in pairs(blockOffsets) do
        if offset.Y ~= 1 then
            local neighbor = mine:FindFirstChild(vec3ToString(position + offset))
            local info = neighbor and resourceInfo(typeOf(neighbor))
            if info and info.LiquidResource then
                return true
            end
        end
    end

    return false
end

function Mining.why(block)
    if not block.Parent then
        return "parent"
    end

    if not block:GetAttribute(Game.attrMinePosition) then
        return "position"
    end

    local name = typeOf(block)
    if not name then
        return "type"
    end

    if name == "Bedrock" or block:GetAttribute("IsBedrock") == true then
        return "bedrock"
    end

    local blocked = { Oil = true, Lava = true, Grass = true, Void = true }
    if blocked[name] then
        return "blocked"
    end

    local world = block:GetAttribute(Game.attrWorldId)
    local playerWorld = Players.LocalPlayer:GetAttribute(Game.attrWorldId)
    if world ~= nil and playerWorld ~= nil and tostring(world) ~= tostring(playerWorld) then
        return "world"
    end

    local dug = block:FindFirstChild("Dug")
    if dug and dug.Value ~= "" and dug.Value ~= Players.LocalPlayer.Name then
        return "dug"
    end

    if Mining.besideLiquid(block) then
        return "liquid"
    end

    return nil
end

function Mining.allowed(block)
    return Mining.why(block) == nil
end

function Mining.inRange(character, block)
    local root = character.PrimaryPart
    if not root then
        return false
    end
    return (block.Position - root.Position).Magnitude <= Mining.maxDistance()
end

function Mining.mine(character, block)
    if not Mining.allowed(block) then
        if os.clock() - Mining.lastReject > 5 then
            Mining.lastReject = os.clock()
            warn("[mining] rejected " .. block.Name .. " type=" .. tostring(typeOf(block)))
        end
        return false
    end

    if not Mining.inRange(character, block) then
        Log.warn("out of range " .. block.Name)
        return false
    end

    local position = block:GetAttribute(Game.attrMinePosition)
    local blockEvent = ReplicatedStorage:FindFirstChild(Config.blockEvent)
    local minedEvent = ReplicatedStorage:FindFirstChild(Config.minedEvent)
    if not position or not blockEvent or not minedEvent then
        warn("[mining] remotes not found")
        return false
    end

    Log.print(("mine start %s type=%s time=%.2f"):format(
        block.Name,
        tostring(typeOf(block)),
        Mining.mineTime(block)
    ))

    blockEvent:FireServer(block.Name, { dug = true })
    task.wait(Mining.mineTime(block) * Config.mineTimeSafety + 0.3)

    if not block.Parent then
        return true
    end

    minedEvent:FireServer({ blockName = vec3ToString(position) })
    task.wait(0.3)

    if block.Parent then
        blockEvent:FireServer(block.Name, { dug = false })
        warn("[mining] server rejected " .. block.Name .. " (" .. tostring(typeOf(block)) .. ")")
        return false
    end

    return true
end

function Mining.approach(block)
    local position = block:GetAttribute(Game.attrMinePosition)
    local mine = workspace:FindFirstChild(Config.mineName)

    if position and mine then
        for _, offset in pairs(blockOffsets) do
            if mine:FindFirstChild(vec3ToString(position + offset)) == nil then
                return block.Position + offset * Vector3.new(blockSize, -blockSize, blockSize)
            end
        end
    end

    return block.Position + Vector3.new(0, blockSize, 0)
end

---------------------------------------------------------------------------
-- Target (mushrooms)
---------------------------------------------------------------------------

local Target = {}

function Target.mushroom()
    for _, node in ipairs(workspace:GetChildren()) do
        if node.Name == "HarvestableNode" then
            local model = node:FindFirstChildWhichIsA("Model")
            if model and model:FindFirstChild("BoundingBox") then
                return model
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Ores
---------------------------------------------------------------------------

local Ores = {}

local cache = {}
local cacheTime = 0
local lastWarning = 0
local selected = {}
local ignored = {}

function Ores.price(name)
    local info = resourceInfo(name)
    if info and info.BasePrice then
        return info.BasePrice
    end
    return Config.orePrices[name] or 0
end

function Ores.names()
    local names, seen = {}, {}
    local sources = {}

    if Game.Resources then
        for name, info in pairs(Game.Resources) do
            if type(info) == "table" and info.Natural and info.BasePrice then
                sources[name] = true
            end
        end
    end
    for name in pairs(Config.orePrices) do
        sources[name] = true
    end

    for name in pairs(sources) do
        if not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end

    table.sort(names, function(a, b)
        return Ores.price(a) > Ores.price(b)
    end)

    return names
end

function Ores.defaultSelected(name)
    return Ores.price(name) > 0
end

function Ores.setSelected(names)
    selected = names or {}
end

function Ores.getSelected()
    if #selected > 0 then
        return selected
    end

    local defaults = {}
    for _, name in ipairs(Ores.names()) do
        if Ores.defaultSelected(name) then
            table.insert(defaults, name)
        end
    end
    return defaults
end

function Ores.bindSelection(selection, names)
    Ores.selection = selection
    Ores.namesList = names
end

local function currentNames()
    local selection = Ores.selection
    if selection and Ores.namesList then
        local indices = selection.getSelected()
        if #indices > 0 then
            local names = {}
            for _, index in ipairs(indices) do
                local name = Ores.namesList[index]
                if name then
                    table.insert(names, name)
                end
            end
            return names
        end
    end
    return selected
end

function Ores.isSelected(name)
    local names = currentNames()
    if #names == 0 then
        return Ores.defaultSelected(name)
    end
    for _, entry in ipairs(names) do
        if entry == name then
            return true
        end
    end
    return false
end

local function claimable(block)
    if not block.Parent or not block:GetAttribute(Game.attrMinePosition) then
        return false
    end
    local dug = block:FindFirstChild("Dug")
    if dug and dug.Value ~= "" and dug.Value ~= Players.LocalPlayer.Name then
        return false
    end
    return true
end

local function formatReasons(reasons)
    local parts = {}
    for reason, count in pairs(reasons) do
        table.insert(parts, ("%s=%d"):format(reason, count))
    end
    table.sort(parts)
    return table.concat(parts, " ")
end

function Ores.refresh()
    cache = {}
    cacheTime = os.clock()

    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        Log.warn("mine not found")
        return
    end

    local blocks = mine:GetChildren()
    local reasons = {}

    for _, block in ipairs(blocks) do
        local name = typeOf(block)
        local reason = Mining.why(block)

        if not reason and not Ores.isSelected(name or "") then
            reason = "notSelected"
        end

        if reason then
            reasons[reason] = (reasons[reason] or 0) + 1
        else
            table.insert(cache, block)
        end
    end

    Log.print(("ores: blocks=%d cached=%d %s"):format(#blocks, #cache, formatReasons(reasons)))

    if #cache == 0 and os.clock() - lastWarning > 10 then
        lastWarning = os.clock()
        local sample = blocks[1]
        warn(("[ores] 0 targets, blocks=%d, reasons: %s"):format(#blocks, formatReasons(reasons)))
        if sample then
            warn(("[ores] sample=%s type=%s position=%s world=%s"):format(
                sample.Name,
                tostring(typeOf(sample)),
                tostring(sample:GetAttribute(Game.attrMinePosition)),
                tostring(sample:GetAttribute(Game.attrWorldId))
            ))
        end
    end
end

function Ores.nearest(position)
    if os.clock() - cacheTime > Config.oreCacheTime then
        Ores.refresh()
    end

    local best, bestDistance, bestPrice
    local now = os.clock()

    for _, block in ipairs(cache) do
        local untilIgnore = ignored[block]
        if (not untilIgnore or untilIgnore <= now) and claimable(block) then
            local distance = (block.Position - position).Magnitude
            local price = Ores.price(typeOf(block))

            local better = not best
                or price > bestPrice
                or (price == bestPrice and distance < bestDistance)

            if distance <= Config.oreRange and better then
                best, bestDistance, bestPrice = block, distance, price
            end
        end
    end

    return best, bestDistance
end

function Ores.ignore(block)
    ignored[block] = os.clock() + 5
end

function Ores.invalidate()
    cacheTime = 0
end

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------

local Loot = {}
local lootIgnored = {}

function Loot.position(drop)
    if drop:IsA("Model") then
        return drop:GetPivot().Position
    end
    return drop.Position
end

function Loot.nearest(position)
    local drops = workspace:FindFirstChild("Drops")
    if not drops then
        return nil
    end

    local best, bestDistance
    local now = os.clock()

    for _, drop in ipairs(drops:GetChildren()) do
        local untilIgnore = lootIgnored[drop]
        if (drop:IsA("Model") or drop:IsA("BasePart")) and (not untilIgnore or untilIgnore <= now) then
            local distance = (Loot.position(drop) - position).Magnitude
            if distance <= Config.lootRange and (not bestDistance or distance < bestDistance) then
                best, bestDistance = drop, distance
            end
        end
    end

    return best, bestDistance
end

function Loot.ignore(drop)
    lootIgnored[drop] = os.clock() + 10
end

---------------------------------------------------------------------------
-- Mushrooms (manager)
---------------------------------------------------------------------------

local Mushrooms

Mushrooms = Manager.new(function()
    local model = Target.mushroom()
    if not model then
        task.wait(0.3)
        return
    end

    local box = model.BoundingBox
    local interact = box:FindFirstChild("Interact")
    if not interact then
        return
    end

    local character = Character.get()
    if not Mushrooms.enabled then
        return
    end

    Movement.to(character, box.Position + Vector3.new(0, 3, 0), Config.moveSpeed)
    Movement.hold(character)
    task.wait(Config.mushroomDelay)

    if not Mushrooms.enabled then
        Movement.releaseHold()
        return
    end
    interact.InteractEvent:FireServer()
    Movement.releaseHold()
end, Movement.cancel)

---------------------------------------------------------------------------
-- Farmer (manager)
---------------------------------------------------------------------------

local Farmer

Farmer = Manager.new(function()
    local character = Character.get()
    if not Farmer.enabled then
        return
    end

    local root = character.PrimaryPart
    if not root then
        return
    end

    local ore, oreDistance = Ores.nearest(root.Position)
    local loot, lootDistance = Loot.nearest(root.Position)

    if loot and (not ore or lootDistance < oreDistance) then
        Movement.to(character, Loot.position(loot) + Vector3.new(0, 3, 0), Config.moveSpeed)
        Loot.ignore(loot)
        return
    end

    if not ore then
        Log.print("no ore targets")
        task.wait(0.3)
        return
    end

    Log.print(("target %s type=%s dist=%.1f price=%d"):format(
        ore.Name,
        tostring(typeOf(ore)),
        oreDistance,
        Ores.price(typeOf(ore))
    ))

    if not Mining.prepare(character) then
        warn("[farmer] no pickaxe")
        task.wait(0.5)
        return
    end

    Movement.to(character, Mining.approach(ore), Config.moveSpeed)

    if not Farmer.enabled then
        return
    end

    Movement.hold(character)
    Mining.mine(character, ore)
    Movement.releaseHold()

    if ore.Parent then
        Ores.ignore(ore)
    else
        Ores.invalidate()
    end
end, Movement.cancel)

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local Ui = {}

function Ui.load()
    if type(readfile) == "function" and type(isfile) == "function" then
        for _, path in ipairs({ "vendor/uilib/source.lua", "vendor\\uilib\\source.lua" }) do
            if isfile(path) then
                local ok, library = pcall(function()
                    return loadstring(readfile(path))()
                end)
                if ok and type(library) == "table" then
                    return library
                end
            end
        end
    end
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/cueshut/saves/main/compact"))()
end

function Ui.create(managers)
    local library = Ui.load()
    local window = library.init("Epic Mining 2", "v1.0.0", "EM2_MAIN")

    local main, _ = window:AddTab("Managers", "white-hat tests")
    local toggles = main:AddSeperator("Toggles")

    for _, manager in ipairs(managers) do
        toggles:AddToggle({
            title = manager.title,
            desc = manager.desc,
            checked = manager.instance.enabled,
            callback = function(state)
                if state then
                    manager.instance.start()
                else
                    manager.instance.stop()
                end
            end,
        })
    end

    local ores = main:AddSeperator("Ore selection")
    local names = Ores.names()
    local defaults = {}

    for index, name in ipairs(names) do
        if Ores.defaultSelected(name) then
            table.insert(defaults, index)
        end
    end

    local selection = ores:AddSelection({
        title = "Ores",
        options = names,
        callback = function(indices)
            local picked = {}
            for _, index in ipairs(indices) do
                if names[index] then
                    table.insert(picked, names[index])
                end
            end
            Ores.setSelected(picked)
            Ores.invalidate()
        end,
    })

    selection.setSelected(defaults)
    Ores.bindSelection(selection, names)

    local debug = main:AddSeperator("Debug")
    debug:AddToggle({
        title = "Verbose logs",
        desc = "print ore rejection reasons and mining steps",
        callback = function(state)
            Log.enabled = state
            print("[em2] verbose logs " .. (state and "on" or "off"))
        end,
    })

    return window
end

local managers = {
    {
        title = "Mushrooms",
        desc = "tween to HarvestableNode and fire Interact",
        instance = Mushrooms,
        key = Enum.KeyCode.F1,
    },
    {
        title = "Farmer",
        desc = "tween to selected ore or loot, mine within range",
        instance = Farmer,
        key = Enum.KeyCode.F2,
    },
}

local ok, err = pcall(Ui.create, managers)
if not ok then
    warn("[main] ui failed: " .. tostring(err))
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end
    for _, manager in ipairs(managers) do
        if input.KeyCode == manager.key then
            manager.instance.toggle()
            print(("[main] %s = %s"):format(manager.title, tostring(manager.instance.enabled)))
        end
    end
end)

task.spawn(function()
    local character = Character.get()
    local pickaxe = Character.getPickaxe(character)
    local mine = workspace:FindFirstChild(Config.mineName)

    local blocks = mine and mine:GetChildren() or {}
    local sample = blocks[1]

    print(("[main] mine=%s blocks=%d pickaxe=%s ores=%d selected=%d"):format(
        mine and "yes" or "no",
        #blocks,
        pickaxe and pickaxe.Name or "none",
        #Ores.names(),
        #Ores.getSelected()
    ))

    if sample then
        print(("[main] sample=%s type=%s position=%s"):format(
            sample.Name,
            tostring(typeOf(sample)),
            tostring(sample:GetAttribute(Game.attrMinePosition))
        ))
    end

    print("[main] F1 mushrooms, F2 farmer")
end)

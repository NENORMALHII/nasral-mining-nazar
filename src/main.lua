local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    mushroomDelay = 0.5,

    blockEvent = "BlockEvent",
    minedEvent = "BlockMinedEvent",
    pickaxeRemote = "UpdatePickaxe",
    defaultMineTime = 4,
    mineTimeSafety = 1.15,

    mineName = "Mine",
    minOreValue = 100,
    oreRange = 500,
    oreCacheTime = 1,
    moveSpeed = 80,
    lootRange = 200,

    -- White-hat toggles. false = keep the flow valid, true = test the server.
    bypass = {
        skipStart = false,
        skipWait = false,
        ignoreLiquid = false,
        ignoreWorld = false,
        anyType = false,
    },

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
-- Game modules (client-accessible)
---------------------------------------------------------------------------

local Game = {}

pcall(function()
    local modules = ReplicatedStorage:WaitForChild("Modules")
    Game.Resources = require(modules:WaitForChild("Resources"))
    Game.Mine = require(modules:WaitForChild("Mining"):WaitForChild("Mine"))
    Game.Constants = require(modules:WaitForChild("Constants"))
    Game.Pickaxes = require(modules:WaitForChild("Tools"):WaitForChild("Pickaxes"))
end)

Game.attrMinePosition = (Game.Constants and Game.Constants.ATTR_MINE_POSITION) or "MinePosition"
Game.attrWorldId = (Game.Constants and Game.Constants.ATTR_WORLD_ID) or "WorldId"
Game.attrToolClass = (Game.Constants and Game.Constants.ATTR_TOOL_TYPE) or "ToolClass"

-- Ore tier required by progression. Any pickaxe of that tier or higher can mine it.
local OreTier = {
    Dirt = 1,
    Stone = 1,
    Coal = 1,
    ["Copper Ore"] = 2,
    ["Iron Ore"] = 3,
    Sulfur = 3,
    ["Silver Ore"] = 3,
    Emerald = 4,
    Ruby = 4,
    Sapphire = 4,
    Sanctite = 4,
    ["Gold Ore"] = 5,
    Quartz = 5,
    Amethyst = 5,
    Hellstone = 5,
    Ignis = 5,
    Diamond = 6,
    Obsidian = 6,
    ["Uranium Ore"] = 6,
    ["Mithril Ore"] = 6,
    ["Promethium Ore"] = 6,
    ["Malachite Ore"] = 6,
    ["Azurite Ore"] = 6,
}

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
                task.wait(0.1)
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
-- Mining
---------------------------------------------------------------------------

local Mining = { baseMineTime = Config.defaultMineTime }

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
        Mining.tier = nil
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

---------------------------------------------------------------------------
-- Movement (tween)
---------------------------------------------------------------------------

local Movement = {}

function Movement.cancel()
    if Movement.tween then
        Movement.tween:Cancel()
        Movement.tween = nil
    end
end

function Movement.to(character, position, speed)
    local root = character.PrimaryPart
    if not root then
        return
    end

    Movement.cancel()

    local distance = (position - root.Position).Magnitude
    if distance < 0.5 then
        return
    end

    local duration = math.clamp(distance / (speed or Config.moveSpeed), 0.1, 4)
    local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(position),
    })

    Movement.tween = tween
    tween:Play()

    local elapsed = 0
    while Movement.tween == tween and elapsed < duration do
        task.wait(0.05)
        elapsed += 0.05
    end

    if Movement.tween == tween then
        Movement.tween = nil
    end
end

function Mining.pickaxeTier()
    if Mining.tier then
        return Mining.tier
    end

    local pickaxe = Mining.pickaxe
    if not pickaxe then
        return nil
    end

    local className = pickaxe:GetAttribute(Game.attrToolClass) or pickaxe.Name
    local info = Game.Pickaxes and Game.Pickaxes[className]
    if info and info.Tier then
        Mining.tier = info.Tier
        return Mining.tier
    end

    if Game.Pickaxes then
        for _, data in pairs(Game.Pickaxes) do
            if type(data) == "table" and data.BaseMineTime and data.Tier then
                if math.abs(data.BaseMineTime - Mining.baseMineTime) < 0.05 then
                    Mining.tier = data.Tier
                    return Mining.tier
                end
            end
        end
    end

    return nil
end

function Mining.tierAllowed(block)
    local required = OreTier[typeOf(block)]
    local tier = Mining.pickaxeTier()
    if not required or not tier then
        return true
    end
    return required <= tier
end

function Mining.mineTime(block)
    local name = typeOf(block)
    local info = resourceInfo(name)
    local modifier = info and info.MineTimeModifier or 1
    local speed = Players.LocalPlayer:GetAttribute("ToolSpeedModifier") or 0

    return Mining.baseMineTime * ((100 - speed) / 100) * modifier
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

function Mining.allowed(block)
    local position = block:GetAttribute(Game.attrMinePosition)
    if not position or not block.Parent then
        return false
    end

    local name = typeOf(block)
    if not name then
        return false
    end

    local blocked = { Oil = true, Lava = true, Grass = true, Void = true }

    if not Config.bypass.anyType then
        if name == "Bedrock" or block:GetAttribute("IsBedrock") == true or blocked[name] then
            return false
        end
    end

    if not Config.bypass.ignoreWorld then
        local world = block:GetAttribute(Game.attrWorldId)
        local playerWorld = Players.LocalPlayer:GetAttribute(Game.attrWorldId)
        if world ~= nil and playerWorld ~= nil and world ~= playerWorld then
            return false
        end
    end

    if not Config.bypass.ignoreLiquid and Mining.besideLiquid(block) then
        return false
    end

    if not Mining.tierAllowed(block) then
        return false
    end

    return true
end

function Mining.mine(block)
    if not Mining.allowed(block) then
        return false
    end

    local position = block:GetAttribute(Game.attrMinePosition)
    local blockEvent = ReplicatedStorage:FindFirstChild(Config.blockEvent)
    local minedEvent = ReplicatedStorage:FindFirstChild(Config.minedEvent)
    if not position or not blockEvent or not minedEvent then
        warn("[mining] remotes not found")
        return false
    end

    local name = block.Name

    if not Config.bypass.skipStart then
        blockEvent:FireServer(name, { dug = true })
    end

    if not Config.bypass.skipWait then
        task.wait(Mining.mineTime(block) * Config.mineTimeSafety + 0.2)
    end

    if not block.Parent then
        return true
    end

    minedEvent:FireServer({ blockName = vec3ToString(position) })
    task.wait(0.3)

    if block.Parent and not Config.bypass.skipStart then
        blockEvent:FireServer(name, { dug = false })
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
-- Target
---------------------------------------------------------------------------

local Target = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

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

function Target.blockBelow(character)
    local root = character.PrimaryPart
    if not root then
        return nil
    end
    rayParams.FilterDescendantsInstances = { character }
    local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), rayParams)
    if hit and hit.Instance:GetAttribute(Game.attrMinePosition) then
        return hit.Instance
    end
    return nil
end

---------------------------------------------------------------------------
-- Ores
---------------------------------------------------------------------------

local Ores = {}

local cache = {}
local cacheTime = 0
local ignored = {}

local function valueOf(block)
    local name = typeOf(block)
    if not name then
        return 0
    end
    local info = resourceInfo(name)
    if info and info.BasePrice then
        return info.BasePrice
    end
    return Config.orePrices[name] or 0
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

function Ores.refresh()
    cache = {}
    cacheTime = os.clock()

    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return
    end

    for _, block in ipairs(mine:GetChildren()) do
        if valueOf(block) >= Config.minOreValue and claimable(block) and Mining.allowed(block) then
            table.insert(cache, block)
        end
    end
end

function Ores.nearest(position)
    if os.clock() - cacheTime > Config.oreCacheTime then
        Ores.refresh()
    end

    local best, bestDistance
    local now = os.clock()

    for _, block in ipairs(cache) do
        local untilIgnore = ignored[block]
        if not untilIgnore or untilIgnore <= now then
            if claimable(block) then
                local distance = (block.Position - position).Magnitude
                if distance <= Config.oreRange and (not bestDistance or distance < bestDistance) then
                    best, bestDistance = block, distance
                end
            end
        end
    end

    return best, bestDistance
end

function Ores.ignore(block)
    ignored[block] = os.clock() + 5
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
    local best, bestDistance
    local drops = workspace:FindFirstChild("Drops")
    if not drops then
        return nil
    end

    local now = os.clock()
    for _, drop in ipairs(drops:GetChildren()) do
        local untilIgnore = lootIgnored[drop]
        local valid = drop.Parent and (drop:IsA("Model") or drop:IsA("BasePart"))
        if valid and (not untilIgnore or untilIgnore <= now) then
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
        warn("[mushrooms] no mushies")
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
    task.wait(Config.mushroomDelay)

    if not Mushrooms.enabled then
        return
    end
    interact.InteractEvent:FireServer()
end, Movement.cancel)

---------------------------------------------------------------------------
-- Digger (manager)
---------------------------------------------------------------------------

local Digger

Digger = Manager.new(function()
    local character = Character.get()
    if not Digger.enabled then
        return
    end

    local block = Target.blockBelow(character)
    if not block then
        task.wait(0.3)
        return
    end

    if not Mining.prepare(character) then
        warn("[digger] no pickaxe")
        task.wait(0.5)
        return
    end

    Mining.mine(block)
end)

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

    if not Mining.prepare(character) then
        warn("[farmer] no pickaxe")
        task.wait(0.5)
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
        task.wait(0.5)
        return
    end

    Movement.to(character, Mining.approach(ore), Config.moveSpeed)

    if not Farmer.enabled then
        return
    end

    Mining.mine(ore)

    if ore.Parent then
        Ores.ignore(ore)
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
    local section = main:AddSeperator("Teleport / Mine")

    for _, manager in ipairs(managers) do
        section:AddToggle({
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

    return window
end

Ui.create({
    {
        title = "Mushrooms",
        desc = "tween to HarvestableNode and fire Interact",
        instance = Mushrooms,
    },
    {
        title = "Auto-dig",
        desc = "mine the block below through BlockEvent",
        instance = Digger,
    },
    {
        title = "Farmer",
        desc = "tween to valuable ore and loot, mine what the pickaxe tier allows",
        instance = Farmer,
    },
})

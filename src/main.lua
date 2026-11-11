local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    loopDelay = 0.04,

    instantMove = false,
    tweenSpeed = 120,
    moveStopDistance = 2.5,

    mineTimeSafety = 0.05,
    mineRejectGrace = 0.6,

    mushroomDelay = 0.35,
    mushroomIgnore = 5,

    mineName = "Mine",
    oreRange = 160,
    oreCacheTime = 1,
    depthWeight = 8,
    shaftDig = true,
    lootRange = 150,
    lootDwell = 0.12,
    lootAttempts = 2,
    lootSpawnWait = 0.35,

    surfaceY = 0,
    surfaceDig = true,


    blockEvent = "BlockEvent",
    minedEvent = "BlockMinedEvent",
    pickaxeRemote = "UpdatePickaxe",
    defaultMineTime = 4,
}

---------------------------------------------------------------------------
-- Log
---------------------------------------------------------------------------

local Log = {
    enabled = false,
}

local function logPrint(...)
    if Log.enabled then
        print("[em2]", ...)
    end
end

local function logWarn(...)
    if Log.enabled then
        warn("[em2]", ...)
    end
end

---------------------------------------------------------------------------
-- Game modules
---------------------------------------------------------------------------

local Game = {}

pcall(function()
    local modules = ReplicatedStorage:WaitForChild("Modules")
    Game.Resources = require(modules:WaitForChild("Resources"))
    Game.Mine = require(modules:WaitForChild("Mining"):WaitForChild("Mine"))
    Game.Constants = require(modules:WaitForChild("Constants"))
    Game.Pickaxes = require(modules:WaitForChild("Tools"):WaitForChild("Pickaxes"))
    Game.Handles = require(modules:WaitForChild("Tools"):WaitForChild("ToolHandles"))
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

local offsetOrder = { "UP", "FRONT", "BACK", "LEFT", "RIGHT", "DOWN" }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

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
-- Mode (base class)
---------------------------------------------------------------------------

local Mode = {}
Mode.__index = Mode

function Mode.new(name, step, cleanup)
    return setmetatable({
        name = name,
        enabled = false,
        token = 0,
        step = step,
        cleanup = cleanup,
    }, Mode)
end

function Mode:start()
    if self.enabled then
        return
    end

    self.enabled = true
    self.token += 1
    local token = self.token

    task.spawn(function()
        while self.enabled and self.token == token do
            local ok, err = pcall(self.step, self)
            if not ok then
                logWarn(self.name .. " error: " .. tostring(err))
            end
            task.wait(Config.loopDelay)
        end
    end)
end

function Mode:stop()
    if not self.enabled then
        return
    end

    self.enabled = false
    self.token += 1

    if self.cleanup then
        local ok, err = pcall(self.cleanup, self)
        if not ok then
            logWarn(self.name .. " cleanup error: " .. tostring(err))
        end
    end
end

function Mode:toggle()
    if self.enabled then
        self:stop()
    else
        self:start()
    end
    return self.enabled
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

function Character.platformStand(character, state)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = state
    end
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------

local Movement = {}

local function safeAnchor(root, state)
    if root and root.Parent then
        pcall(function()
            root.Anchored = state
        end)
    end
end

function Movement.release()
    if Movement.tween then
        pcall(function()
            Movement.tween:Cancel()
        end)
        Movement.tween = nil
    end

    safeAnchor(Movement.holdRoot, false)
    Movement.holdRoot = nil

    safeAnchor(Movement.root, false)
    Movement.root = nil

    Character.platformStand(Movement.character, false)
    Movement.character = nil
end

function Movement.cancel()
    Movement.release()
end

function Movement.instant(character, position)
    Movement.release()
    if character and character.PrimaryPart then
        character:PivotTo(CFrame.new(position))
    end
end

function Movement.hold(character)
    local root = character.PrimaryPart
    if root then
        safeAnchor(root, true)
        Movement.holdRoot = root
    end
end

function Movement.releaseHold()
    safeAnchor(Movement.holdRoot, false)
    Movement.holdRoot = nil
end

function Movement.to(character, position, speed)
    local root = character.PrimaryPart
    if not root then
        return
    end

    Movement.release()

    if (position - root.Position).Magnitude < Config.moveStopDistance then
        return
    end

    if Config.instantMove then
        character:PivotTo(CFrame.new(position))
        Character.platformStand(character, false)
        return
    end

    Character.platformStand(character, true)
    safeAnchor(root, true)
    Movement.character = character
    Movement.root = root

    local duration = math.clamp(
        (position - root.Position).Magnitude / math.max(speed or Config.tweenSpeed, 1),
        0.05,
        5
    )

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
-- Predictor (depth + seed based)
---------------------------------------------------------------------------

local Predictor = {}

local BASE_X = 61.5
local BASE_Z = -56.5
local BASE_ALTITUDE = 7998.5

function Predictor.toBlock(position)
    return Vector3.new(
        math.floor((position.X - BASE_X) / 7 + 0.5),
        -math.floor((position.Y - BASE_ALTITUDE) / 7 + 0.5),
        math.floor((position.Z - BASE_Z) / 7 + 0.5)
    )
end

function Predictor.seed()
    if Predictor.value then
        return Predictor.value
    end

    local sources = {
        workspace,
        workspace:FindFirstChild(Config.mineName),
        ReplicatedStorage,
    }

    for _, instance in ipairs(sources) do
        if instance then
            for name, value in pairs(instance:GetAttributes()) do
                if type(name) == "string" and name:lower():find("seed") then
                    Predictor.value = tostring(value)
                    break
                end
            end
        end
        if Predictor.value then
            break
        end
    end

    Predictor.value = Predictor.value
        or ("w" .. tostring(Players.LocalPlayer:GetAttribute(Game.attrWorldId) or 0))

    logPrint("predictor seed " .. Predictor.value)

    return Predictor.value
end

function Predictor.hash(blockPosition)
    local seed = Predictor.seed()
    local value = 0

    for index = 1, #seed do
        value = (value * 31 + seed:byte(index)) % 2147483647
    end

    value = bit32.bxor(value, math.floor(blockPosition.X) * 73856093)
    value = bit32.bxor(value, math.floor(blockPosition.Y) * 19349663)
    value = bit32.bxor(value, math.floor(blockPosition.Z) * 83492791)

    return value % 1000
end

function Predictor.worldOf(blockPosition)
    return Vector3.new(
        BASE_X + 7 * blockPosition.X,
        BASE_ALTITUDE - 7 * blockPosition.Y,
        BASE_Z + 7 * blockPosition.Z
    )
end

function Predictor.blockBelow(worldPosition)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return nil
    end

    local blockPosition = Predictor.toBlock(worldPosition)
    return mine:FindFirstChild(vec3ToString(blockPosition + Vector3.new(0, 1, 0)))
end

---------------------------------------------------------------------------
-- Mining
---------------------------------------------------------------------------

local Mining = {
    baseMineTime = Config.defaultMineTime,
}

function Mining.pickaxeInfo(pickaxe)
    if not Game.Pickaxes or not pickaxe then
        return nil
    end

    local className = pickaxe:GetAttribute("ToolClass") or pickaxe.Name
    return Game.Pickaxes[className]
end

function Mining.handleName(pickaxe)
    if not pickaxe then
        return nil
    end

    local attrName = (Game.Constants and Game.Constants.ATTR_TOOL_WOOD_MATERIAL) or "WoodMaterial"
    local name = pickaxe:GetAttribute(attrName)

    if type(name) ~= "string" then
        name = pickaxe:GetAttribute("Handle") or pickaxe:GetAttribute("Wood")
    end

    if type(name) == "string" then
        return name
    end

    for _, descendant in ipairs(pickaxe:GetDescendants()) do
        local lower = descendant.Name:lower()
        if descendant:IsA("StringValue") and (lower:find("wood") or lower:find("handle")) then
            return descendant.Value
        end
    end

    if Game.Handles then
        for handle in pairs(Game.Handles) do
            if pickaxe.Name:find(handle, 1, true) then
                return handle
            end
        end
    end

    return nil
end

function Mining.handleInfo(pickaxe)
    local name = Mining.handleName(pickaxe)
    if name and Game.Handles and Game.Handles[name] then
        return Game.Handles[name], name
    end
    return nil, name
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

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end

    if Mining.pickaxe ~= pickaxe then
        Mining.pickaxe = pickaxe
        Mining.rebound = false
        Mining.bind(pickaxe)

        local info = Mining.pickaxeInfo(pickaxe)
        if info and type(info.BaseMineTime) == "number" then
            Mining.baseMineTime = info.BaseMineTime
        end

        local _, handleName = Mining.handleInfo(pickaxe)
        Mining.handle = handleName
        logPrint(("pickaxe %s base=%.2f handle=%s"):format(
            pickaxe.Name,
            Mining.baseMineTime,
            tostring(handleName)
        ))
    end

    if pickaxe.Parent ~= character then
        humanoid:EquipTool(pickaxe)
        task.wait(0.1)
    elseif not Mining.rebound then
        humanoid:UnequipTools()
        task.wait(0.05)
        humanoid:EquipTool(pickaxe)
        task.wait(0.1)
    end

    Mining.rebound = true

    return pickaxe
end

function Mining.mineTime(block)
    local info = resourceInfo(typeOf(block))
    local modifier = info and info.MineTimeModifier or 1
    local speed = Players.LocalPlayer:GetAttribute("ToolSpeedModifier") or 0

    return math.max(Mining.baseMineTime * ((100 - speed) / 100) * modifier, 0.05)
end

function Mining.waitTime(block)
    local ping = 0
    local ok, value = pcall(function()
        return Players.LocalPlayer:GetNetworkPing()
    end)
    if ok and type(value) == "number" then
        ping = math.min(value, 0.5)
    end

    return Mining.mineTime(block) + Config.mineTimeSafety + ping * 2
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
    if playerWorld ~= nil and tostring(world) ~= tostring(playerWorld) then
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
    return (block.Position - root.Position).Magnitude <= Mining.maxDistance() - 1
end

function Mining.surface(character)
    local root = character and character.PrimaryPart
    if not root then
        return false
    end
    return Predictor.toBlock(root.Position).Y <= Config.surfaceY
end

function Mining.mine(character, block, skipCell)
    local reason = Mining.why(block)
    if reason then
        logWarn(("skip %s: %s"):format(block.Name, reason))
        return false
    end

    if not Mining.inRange(character, block) then
        logWarn("out of range " .. block.Name)
        return false
    end

    if not skipCell and not Mining.inCell(character) then
        logWarn("not between blocks " .. block.Name)
        return false
    end

    local position = block:GetAttribute(Game.attrMinePosition)
    local blockEvent = ReplicatedStorage:FindFirstChild(Config.blockEvent)
    local minedEvent = ReplicatedStorage:FindFirstChild(Config.minedEvent)
    if not position or not blockEvent or not minedEvent then
        logWarn("remotes not found")
        return false
    end

    logPrint(("mine %s type=%s wait=%.2f"):format(
        block.Name,
        tostring(typeOf(block)),
        Mining.waitTime(block)
    ))

    blockEvent:FireServer(block.Name, { dug = true })
    task.wait(Mining.waitTime(block))

    if not block.Parent then
        return true
    end

    minedEvent:FireServer({ blockName = vec3ToString(position) })

    local deadline = os.clock() + Config.mineRejectGrace
    while block.Parent and os.clock() < deadline do
        task.wait(0.03)
    end

    if block.Parent then
        blockEvent:FireServer(block.Name, { dug = false })
        warn("[mining] server rejected " .. block.Name .. " (" .. tostring(typeOf(block)) .. ")")
        return false
    end

    return true
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

function Mining.inCell(character)
    local root = character and character.PrimaryPart
    local mine = workspace:FindFirstChild(Config.mineName)
    if not root or not mine then
        return false
    end

    local cell = Predictor.toBlock(root.Position)
    if mine:FindFirstChild(vec3ToString(cell)) then
        return false
    end

    overlapParams.FilterDescendantsInstances = { mine }
    local parts = workspace:GetPartBoundsInBox(
        CFrame.new(root.Position),
        Vector3.new(1, 1, 1),
        overlapParams
    )

    return #parts == 0
end

function Mining.solidNeighbors(blockPosition, mine)
    local count = 0

    for _, key in ipairs(offsetOrder) do
        local offset = blockOffsets[key]
        if offset and mine:FindFirstChild(vec3ToString(blockPosition + offset)) then
            count += 1
        end
    end

    return count
end

function Mining.approach(block)
    local position = block:GetAttribute(Game.attrMinePosition)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not position or not mine then
        return nil
    end

    local best, bestCount

    for _, key in ipairs(offsetOrder) do
        local offset = blockOffsets[key]
        local cell = offset and position + offset

        if cell and cell.Y >= 1 and mine:FindFirstChild(vec3ToString(cell)) == nil then
            local count = Mining.solidNeighbors(cell, mine)
            if count >= 3 and (not bestCount or count > bestCount) then
                best, bestCount = cell, count
            end
        end
    end

    if not best then
        return nil
    end

    return Predictor.worldOf(best)
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
    return 0
end

function Ores.names()
    local names = {}
    local seen = {}

    if Game.Resources then
        for name, info in pairs(Game.Resources) do
            if type(info) == "table" and info.Natural and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end

    table.sort(names, function(a, b)
        return Ores.price(a) > Ores.price(b)
    end)

    return names
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
        return true
    end
    for _, entry in ipairs(names) do
        if entry == name then
            return true
        end
    end
    return false
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
        logWarn("mine not found")
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

    logPrint(("ores: blocks=%d cached=%d %s"):format(#blocks, #cache, formatReasons(reasons)))

    if #cache == 0 and os.clock() - lastWarning > 10 then
        lastWarning = os.clock()
        warn(("[ores] 0 targets, blocks=%d, reasons: %s"):format(#blocks, formatReasons(reasons)))
    end
end

function Ores.nearest(position)
    if os.clock() - cacheTime > Config.oreCacheTime then
        Ores.refresh()
    end

    local best, bestDistance, bestScore
    local now = os.clock()
    local playerBlock = Predictor.toBlock(position)

    for _, block in ipairs(cache) do
        local untilIgnore = ignored[block]
        if not untilIgnore or untilIgnore <= now then
            local distance = (block.Position - position).Magnitude
            if distance <= Config.oreRange then
                local blockPosition = block:GetAttribute(Game.attrMinePosition)
                local price = Ores.price(typeOf(block))
                local depth = 0

                if blockPosition then
                    depth = math.max(0, blockPosition.Y - playerBlock.Y)
                end

                local score = price + depth * Config.depthWeight + Predictor.hash(blockPosition or block.Position) / 1000

                if not best or score > bestScore then
                    best, bestDistance, bestScore = block, distance, score
                end
            end
        end
    end

    return best, bestDistance
end

function Ores.random(character)
    local root = character and character.PrimaryPart
    local mine = workspace:FindFirstChild(Config.mineName)
    if not root or not mine then
        return nil
    end

    local limit = Mining.maxDistance() - 1
    for _, block in ipairs(mine:GetChildren()) do
        if Mining.allowed(block) and (block.Position - root.Position).Magnitude <= limit then
            return block
        end
    end

    return nil
end

function Ores.ignore(block)
    ignored[block] = os.clock() + 5
end

function Ores.invalidate()
    cacheTime = 0
end

---------------------------------------------------------------------------
-- Loot (workspace.TargetFilter/{BlockName}_Drop)
---------------------------------------------------------------------------

local Loot = {}
local lootIgnored = {}

function Loot.container()
    return workspace:FindFirstChild("TargetFilter") or workspace:FindFirstChild("Drops")
end

function Loot.part(drop)
    if drop:IsA("BasePart") then
        return drop
    end

    for _, child in ipairs(drop:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end

    return drop:FindFirstChildWhichIsA("BasePart", true)
end

function Loot.owner(drop)
    local dropScript = drop:FindFirstChild("DropScript", true)
    local playerValue = dropScript and dropScript:FindFirstChild("Player")
    return playerValue and playerValue.Value
end

function Loot.mine(drop)
    return Loot.owner(drop) == Players.LocalPlayer
end

local function tryPickup(character, drop)
    local part = Loot.part(drop)
    if not part then
        return false
    end

    for _ = 1, Config.lootAttempts do
        if not drop.Parent or not part.Parent then
            return true
        end

        Movement.instant(character, part.Position)
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        task.wait(Config.lootDwell)

        if not drop.Parent then
            return true
        end
    end

    return not drop.Parent
end

function Loot.collectAll(character)
    local container = Loot.container()
    if not container then
        return 0
    end

    local origin = character.PrimaryPart and character.PrimaryPart.Position
    if not origin then
        return 0
    end

    local candidates = {}
    local now = os.clock()

    for _, drop in ipairs(container:GetChildren()) do
        local untilIgnore = lootIgnored[drop]
        if (drop:IsA("Model") or drop:IsA("BasePart")) and (not untilIgnore or untilIgnore <= now) then
            local part = Loot.part(drop)
            if part and Loot.mine(drop) then
                local distance = (part.Position - origin).Magnitude
                if distance <= Config.lootRange then
                    table.insert(candidates, { drop = drop, distance = distance })
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    local picked = 0
    for _, candidate in ipairs(candidates) do
        if tryPickup(character, candidate.drop) or candidate.drop.Parent then
            Loot.ignore(candidate.drop)
            picked += 1
        end
    end

    if picked > 0 then
        logPrint("loot picked " .. picked)
    end

    return picked
end

---------------------------------------------------------------------------
-- Mushroom node
---------------------------------------------------------------------------

local MushroomNode = {}
local mushroomIgnored = {}

function MushroomNode.nearest(position)
    local best, bestDistance
    local now = os.clock()

    for _, node in ipairs(workspace:GetChildren()) do
        if node.Name == "HarvestableNode" then
            local untilIgnore = mushroomIgnored[node]
            if not untilIgnore or untilIgnore <= now then
                local model = node:FindFirstChildWhichIsA("Model")
                local box = model and model:FindFirstChild("BoundingBox")
                if box and box:FindFirstChild("Interact") then
                    local distance = (box.Position - position).Magnitude
                    if not bestDistance or distance < bestDistance then
                        best, bestDistance = box, distance
                    end
                end
            end
        end
    end

    return best, bestDistance
end

function MushroomNode.ignore(box)
    local node = box.Parent or box
    mushroomIgnored[node] = os.clock() + Config.mushroomIgnore
end

---------------------------------------------------------------------------
-- Farm mode
---------------------------------------------------------------------------

local FarmMode = Mode.new("Farm", function(self)
    local character = Character.get()
    if not self.enabled then
        return
    end

    local root = character.PrimaryPart
    if not root then
        return
    end

    Loot.collectAll(character)

    if Config.surfaceDig and Mining.surface(character) then
        local target = Predictor.blockBelow(root.Position) or Ores.random(character)
        if target and Mining.prepare(character) then
            logPrint("surface break " .. target.Name)
            Movement.hold(character)
            local ok = pcall(Mining.mine, character, target, true)
            Movement.releaseHold()
            if ok then
                task.wait(Config.lootSpawnWait)
                Loot.collectAll(character)
            end
        end
        return
    end

    local ore, oreDistance = Ores.nearest(root.Position)

    local function digDown()
        if not Config.shaftDig then
            return false
        end

        local below = Predictor.blockBelow(root.Position)
        local stand = below and (Mining.approach(below) or root.Position)
        if not stand or not Mining.prepare(character) then
            return false
        end

        Movement.to(character, stand)
        if not Mining.inCell(character) then
            logWarn("shaft stand is not an empty cell")
            return false
        end

        Movement.hold(character)
        local dug = pcall(Mining.mine, character, below)
        Movement.releaseHold()
        return dug
    end

    if not ore then
        if not digDown() then
            task.wait(0.2)
        end
        return
    end

    if not Mining.prepare(character) then
        logWarn("no pickaxe")
        task.wait(0.3)
        return
    end

    logPrint(("target %s type=%s dist=%.1f price=%d"):format(
        ore.Name,
        tostring(typeOf(ore)),
        oreDistance,
        Ores.price(typeOf(ore))
    ))

    local stand = Mining.approach(ore)
    if not stand then
        logWarn("no empty cell next to " .. ore.Name .. ", digging down")
        Ores.ignore(ore)
        digDown()
        return
    end

    Movement.to(character, stand)

    if not self.enabled then
        return
    end

    if not Mining.inCell(character) then
        logWarn("not in a cell, skipping " .. ore.Name)
        Ores.ignore(ore)
        return
    end

    Movement.hold(character)
    local mined, result = pcall(Mining.mine, character, ore)
    Movement.releaseHold()

    if not mined then
        logWarn("mine error: " .. tostring(result))
        Ores.ignore(ore)
    elseif result then
        Ores.invalidate()
        task.wait(Config.lootSpawnWait)
        Loot.collectAll(character)
    else
        Ores.ignore(ore)
    end
end, Movement.cancel)

---------------------------------------------------------------------------
-- Mushroom mode
---------------------------------------------------------------------------

local MushroomMode = Mode.new("Mushrooms", function(self)
    local character = Character.get()
    if not self.enabled then
        return
    end

    local root = character.PrimaryPart
    if not root then
        return
    end

    local box = MushroomNode.nearest(root.Position)
    if not box then
        logPrint("no mushrooms")
        task.wait(0.2)
        return
    end

    local interact = box:FindFirstChild("Interact")
    if not interact then
        return
    end

    Movement.to(character, box.Position + Vector3.new(0, 3, 0))
    Movement.hold(character)
    task.wait(Config.mushroomDelay)

    if self.enabled then
        interact.InteractEvent:FireServer()
    end

    Movement.releaseHold()
    MushroomNode.ignore(box)
end, Movement.cancel)

---------------------------------------------------------------------------
-- Modes registry
---------------------------------------------------------------------------

local Modes = {
    list = { FarmMode, MushroomMode },
    active = FarmMode,
}

function Modes.byName(name)
    for _, mode in ipairs(Modes.list) do
        if mode.name == name then
            return mode
        end
    end
    return nil
end

function Modes.select(mode)
    if not mode or Modes.active == mode then
        return
    end
    for _, other in ipairs(Modes.list) do
        other:stop()
    end
    Modes.active = mode
end

function Modes.enable(mode)
    if not mode then
        return
    end
    for _, other in ipairs(Modes.list) do
        if other ~= mode then
            other:stop()
        end
    end
    Modes.active = mode
    mode:start()
end

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

function Ui.create()
    local library = Ui.load()
    local window = library.init("Epic Mining 2", "v1.1.0", "EM2_MAIN")

    local main, _ = window:AddTab("Main", "white-hat tests")

    local modePanel = main:AddSeperator("Mode")
    local enabled = false

    local modeDropdown
    modeDropdown = modePanel:AddDropdown({
        title = "Category",
        options = { "Farm", "Mushrooms" },
        callback = function(index)
            local mode = Modes.list[index]
            Modes.select(mode)
            if enabled and mode then
                Modes.enable(mode)
            end
        end,
    })

    modePanel:AddToggle({
        title = "Enabled",
        callback = function(state)
            enabled = state
            if state then
                Modes.enable(Modes.active)
            else
                for _, mode in ipairs(Modes.list) do
                    mode:stop()
                end
            end
        end,
    })

    local movePanel = main:AddSeperator("Movement")
    movePanel:AddToggle({
        title = "Instant move",
        desc = "teleport instead of tween",
        callback = function(state)
            Config.instantMove = state
        end,
    })

    movePanel:AddToggle({
        title = "Dig down",
        desc = "dig the block below when no selected ore is near",
        checked = Config.shaftDig,
        callback = function(state)
            Config.shaftDig = state
        end,
    })

    movePanel:AddSlider({
        title = "Tween speed",
        values = { min = 20, max = 400, default = Config.tweenSpeed, round = 1 },
        callback = function(value)
            Config.tweenSpeed = value
        end,
    })

    local orePanel = main:AddSeperator("Farm ores")
    local names = Ores.names()
    local defaults = {}

    for index, name in ipairs(names) do
        table.insert(defaults, index)
    end

    local selection = orePanel:AddSelection({
        title = "Ores",
        options = names,
        default = defaults,
    })

    selection.setSelected(defaults)
    Ores.bindSelection(selection, names)

    local debugPanel = main:AddSeperator("Debug")
    debugPanel:AddToggle({
        title = "Verbose logs",
        desc = "print ore reasons and mining steps",
        callback = function(state)
            Log.enabled = state
        end,
    })

    modeDropdown.setSelected(1)

    return window
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

local ok, err = pcall(Ui.create)
if not ok then
    warn("[main] ui failed: " .. tostring(err))
end

local hotkeys = {
    [Enum.KeyCode.F1] = FarmMode,
    [Enum.KeyCode.F2] = MushroomMode,
}

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    local mode = hotkeys[input.KeyCode]
    if mode then
        if mode.enabled then
            mode:stop()
        else
            Modes.enable(mode)
        end
        print(("[main] %s = %s"):format(mode.name, tostring(mode.enabled)))
    end
end)

task.spawn(function()
    local character = Character.get()
    local pickaxe = Character.getPickaxe(character)
    local mine = workspace:FindFirstChild(Config.mineName)
    local blocks = mine and mine:GetChildren() or {}
    local sample = blocks[1]

    print(("[main] mine=%s blocks=%d pickaxe=%s ores=%d"):format(
        mine and "yes" or "no",
        #blocks,
        pickaxe and pickaxe.Name or "none",
        #Ores.names()
    ))

    if sample then
        print(("[main] sample=%s type=%s world=%s"):format(
            sample.Name,
            tostring(typeOf(sample)),
            tostring(sample:GetAttribute(Game.attrWorldId))
        ))
    end

    local info = pickaxe and Mining.pickaxeInfo(pickaxe)
    local handle, handleName = pickaxe and Mining.handleInfo(pickaxe)
    print(("[main] player world=%s toolspeed=%s pickaxe_tier=%s base=%s handle=%s"):format(
        tostring(Players.LocalPlayer:GetAttribute(Game.attrWorldId)),
        tostring(Players.LocalPlayer:GetAttribute("ToolSpeedModifier")),
        tostring(info and info.Tier),
        tostring(info and info.BaseMineTime),
        tostring(handleName)
    ))
    if handle then
        print(("[main] handle speed=%s luck=%s double=%s"):format(
            tostring(handle.SpeedModifier),
            tostring(handle.LuckModifier),
            tostring(handle.DoubleDropChanceModifier)
        ))
    end

    print("[main] F1 farm, F2 mushrooms")
end)

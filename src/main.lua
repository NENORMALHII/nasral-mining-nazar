local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    loopDelay = 0.08,

    instantMove = false,
    tweenSpeed = 120,
    moveStopDistance = 2.5,

    mineWaitForServer = 1.5,

    mineSafetyBase = 0.08,
    mineSafetyPingMult = 1.0,
    mineJitterMin = 0.03,
    mineJitterMax = 0.12,
    minePreSwingMin = 0.03,
    minePreSwingMax = 0.10,
    mineSwingMin = 0.01,
    mineSwingMax = 0.05,
    mineRejectGrace = 0.8,

    mushroomDelay = 0.35,
    mushroomIgnore = 5,

    mineName = "Mine",
    oreRange = 21,

    mineReachMargin = 4,
    moveCooldown = 0.5,

    surfaceDepth = 2,
    surfaceScanRadius = 6,
    surfaceMaxDepth = 10,
    surfaceMinDepth = 2,
    surfacePitBan = 12,
    moveSettleTime = 0.25,
    moveSettleEpsilon = 0.2,

    lootDwell = 0.12,
    lootSpawnWait = 0.3,
    lootSyncInterval = 0.4,

    blockEvent = "BlockEvent",
    minedEvent = "BlockMinedEvent",
    pickaxeRemote = "UpdatePickaxe",
    defaultMineTime = 4,
}

---------------------------------------------------------------------------
-- Ping tracker (rolling min for stable safety buffer)
---------------------------------------------------------------------------

local Ping = {
    samples = {},
    maxSamples = 8,
    minPing = 0,
}

function Ping.sample()
    local ok, value = pcall(function()
        return Players.LocalPlayer:GetNetworkPing()
    end)
    if not ok or type(value) ~= "number" then
        return Ping.minPing
    end

    value = math.max(0, math.min(value, 2))

    table.insert(Ping.samples, value)
    while #Ping.samples > Ping.maxSamples do
        table.remove(Ping.samples, 1)
    end

    local min = math.huge
    for _, v in ipairs(Ping.samples) do
        if v < min then
            min = v
        end
    end

    Ping.minPing = min == math.huge and 0 or min
    return Ping.minPing
end

---------------------------------------------------------------------------
-- Log
---------------------------------------------------------------------------

local Log = {
    enabled = false,
    lines = {},
    maxLines = 12,
    render = nil,
}

local function joinArgs(...)
    local parts = {}

    for index = 1, select("#", ...) do
        table.insert(parts, tostring(select(index, ...)))
    end

    return table.concat(parts, " ")
end

local function pushLog(text)
    local line = ("%s  %s"):format(os.date("%H:%M:%S"), text)
    table.insert(Log.lines, line)

    while #Log.lines > Log.maxLines do
        table.remove(Log.lines, 1)
    end

    if Log.render then
        pcall(Log.render, Log.lines)
    end
end

local function logPrint(...)
    local text = joinArgs(...)
    pushLog(text)
    if Log.enabled then
        print("[nm2]", text)
    end
end

local function logWarn(...)
    local text = joinArgs(...)
    pushLog(text)
    if Log.enabled then
        warn("[nm2]", text)
    end
end

---------------------------------------------------------------------------
-- Game modules
---------------------------------------------------------------------------

local Game = {}

local function loadModule(...)
    local path = { ... }

    local ok, module = pcall(function()
        local current = ReplicatedStorage
        for _, name in ipairs(path) do
            current = current:WaitForChild(name)
        end
        return require(current)
    end)

    if ok then
        return module
    end
    return nil
end

Game.Resources = loadModule("Modules", "Resources")
Game.Mine = loadModule("Modules", "Mining", "Mine")
Game.Constants = loadModule("Modules", "Constants")
Game.Pickaxes = loadModule("Modules", "Tools", "Pickaxes")
Game.Handles = loadModule("Modules", "Tools", "ToolHandles")

Game.attrMinePosition = (Game.Constants and Game.Constants.ATTR_MINE_POSITION) or "MinePosition"
Game.attrWorldId = (Game.Constants and Game.Constants.ATTR_WORLD_ID) or "WorldId"

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

function Movement.settle(character)
    local root = character and character.PrimaryPart
    if not root then
        return
    end

    local deadline = os.clock() + Config.moveSettleTime
    local last = root.Position
    local stable = 0

    while os.clock() < deadline do
        RunService.Heartbeat:Wait()

        if (root.Position - last).Magnitude <= Config.moveSettleEpsilon then
            stable += 1
        else
            stable = 0
        end

        last = root.Position

        if stable >= 2 then
            return
        end
    end
end

function Movement.waitLanded(character, timeout)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local deadline = os.clock() + (timeout or 0.7)
    while os.clock() < deadline do
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            return
        end
        RunService.Heartbeat:Wait()
    end
end

function Movement.to(character, position, speed)
    local root = character.PrimaryPart
    if not root then
        return
    end

    Movement.release()

    if (position - root.Position).Magnitude < Config.moveStopDistance then
        Movement.settle(character)
        return
    end

    if Config.instantMove then
        character:PivotTo(CFrame.new(position))
        Character.platformStand(character, false)
        Movement.lastMoveAt = os.clock()
        Movement.settle(character)
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

    Movement.lastMoveAt = os.clock()
    Movement.settle(character)
end

function Movement.jump(character, position)
    local root = character.PrimaryPart
    if not root then
        return
    end

    Movement.release()
    character:PivotTo(CFrame.new(position))
    Movement.lastMoveAt = os.clock()
end

---------------------------------------------------------------------------
-- Blocks (world <-> block coordinates)
---------------------------------------------------------------------------

local Blocks = {}

local BASE_X = 61.5
local BASE_Z = -56.5
local BASE_ALTITUDE = 7998.5

function Blocks.toBlock(position)
    return Vector3.new(
        math.floor((position.X - BASE_X) / 7 + 0.5),
        -math.floor((position.Y - BASE_ALTITUDE) / 7 + 0.5),
        math.floor((position.Z - BASE_Z) / 7 + 0.5)
    )
end

function Blocks.worldOf(cell)
    return Vector3.new(
        BASE_X + 7 * cell.X,
        BASE_ALTITUDE - 7 * cell.Y,
        BASE_Z + 7 * cell.Z
    )
end

function Blocks.below(worldPosition)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return nil
    end

    local cell = Blocks.toBlock(worldPosition) + Vector3.new(0, 1, 0)
    return mine:FindFirstChild(vec3ToString(cell))
end

---------------------------------------------------------------------------
-- Surface shafts
---------------------------------------------------------------------------

local Surface = {
    remembered = nil,
    lastCell = nil,
    lastScan = 0,
    pitCache = {},
    banned = {},
}

-- Counts empty cells from topY down to the first solid block.
-- hasBottom is false when the column never hits a block: that is outside the
-- generated mine (void / unloaded area), not a shaft.
function Surface.depth(mine, cell, topY)
    local depth = 0

    for y = topY, topY + Config.surfaceMaxDepth - 1 do
        local block = mine:FindFirstChild(vec3ToString(Vector3.new(cell.X, y, cell.Z)))
        if block then
            return depth, true
        end
        depth += 1
    end

    return depth, false
end

function Surface.key(cell)
    return cell.X .. "," .. cell.Z
end

function Surface.cacheGet(key)
    local cached = Surface.pitCache[key]
    if not cached then
        return nil
    end
    local now = os.clock()
    if now - cached.time > 5 then
        Surface.pitCache[key] = nil
        return nil
    end
    return cached.pit
end

function Surface.cacheSet(key, pit)
    Surface.pitCache[key] = { pit = pit, time = os.clock() }
end

-- Pits we are not allowed to dig out (floor claimed by another player, liquid-adjacent,
-- blocked type, or no floor at all) are dropped from the cache and skipped for
-- surfacePitBan seconds. Without the ban the next scan re-finds the same pit and the
-- bot stands at its mouth forever.
function Surface.drop(cell)
    local key = Surface.key(cell)
    Surface.pitCache[key] = nil
    Surface.banned[key] = os.clock() + Config.surfacePitBan

    if Surface.remembered and Surface.key(Surface.remembered.cell) == key then
        Surface.remembered = nil
    end

    Surface.lastScan = 0
end

function Surface.isBanned(key, now)
    local untilTime = Surface.banned[key]
    return untilTime ~= nil and untilTime > now
end

function Surface.choose(position)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return nil
    end

    local now = os.clock()
    local center = Blocks.toBlock(position)
    local topY = center.Y

    -- 1. Try remembered pit first (same X,Z)
    if Surface.remembered then
        local key = Surface.key(Surface.remembered.cell)

        if Surface.isBanned(key, now) then
            Surface.remembered = nil
        else
            local cached = Surface.cacheGet(key)
            if cached then
                return cached
            end
        end

        if Surface.remembered then
            local cell = Vector3.new(Surface.remembered.cell.X, topY, Surface.remembered.cell.Z)
            local depth, hasBottom = Surface.depth(mine, cell, topY)

            if hasBottom and depth >= Config.surfaceMinDepth then
                Surface.remembered.cell = cell
                Surface.remembered.depth = depth
                Surface.cacheSet(key, Surface.remembered)
                return Surface.remembered
            end

            Surface.remembered = nil
        end
    end

    -- 2. Check cache for current column
    local currentKey = Surface.key(center)
    local cached = Surface.cacheGet(currentKey)

    if cached and not Surface.isBanned(currentKey, now) then
        return cached
    end

    -- 3. Full scan only if cache miss
    if Surface.lastCell == center and os.clock() - Surface.lastScan < 2 then
        return nil
    end

    Surface.lastCell = center
    Surface.lastScan = os.clock()

    local radius = Config.surfaceScanRadius
    local best, bestDepth, bestDistance

    for dx = -radius, radius do
        for dz = -radius, radius do
            local cell = Vector3.new(center.X + dx, topY, center.Z + dz)
            local key = Surface.key(cell)

            if not Surface.isBanned(key, now) then
                local cachedPit = Surface.cacheGet(key)

                if cachedPit then
                    if not bestDepth
                        or cachedPit.depth > bestDepth
                        or (cachedPit.depth == bestDepth and (Blocks.worldOf(cell) - position).Magnitude < bestDistance) then
                        best, bestDepth, bestDistance = cell, cachedPit.depth, (Blocks.worldOf(cell) - position).Magnitude
                    end
                    continue
                end

                local depth, hasBottom = Surface.depth(mine, cell, topY)

                if hasBottom and depth >= Config.surfaceMinDepth then
                    local distance = (Blocks.worldOf(cell) - position).Magnitude

                    if not bestDepth
                        or depth > bestDepth
                        or (depth == bestDepth and distance < bestDistance) then
                        best, bestDepth, bestDistance = cell, depth, distance
                    end

                    Surface.cacheSet(key, { cell = cell, depth = depth })
                end
            end
        end
    end

    if not best then
        return nil
    end

    Surface.remembered = { cell = best, depth = bestDepth }
    Surface.cacheSet(Surface.key(best), Surface.remembered)
    logPrint(("surface shaft %s depth=%d"):format(vec3ToString(best), bestDepth))
    return Surface.remembered
end


---------------------------------------------------------------------------
-- Mining
---------------------------------------------------------------------------

local Mining = {
    baseMineTime = Config.defaultMineTime,
}

local BLOCKED = { Oil = true, Lava = true, Grass = true, Void = true }

local function colorOf(value)
    local kind = typeof(value)

    if kind == "BrickColor" then
        return value.Color
    end

    if kind == "Color3" then
        return value
    end

    return nil
end

local function colorMatches(a, b)
    local left = colorOf(a)
    local right = colorOf(b)
    return left ~= nil and right ~= nil and (left - right).Magnitude < 0.08
end

local function normalizeName(value)
    if type(value) ~= "string" then
        return nil
    end

    local text = value:lower()

    for _, word in ipairs({ "pickaxe", "pick", "axe", "wooden", "wood", "handle" }) do
        text = text:gsub(word, "")
    end

    text = text:gsub("[^%a%d]", "")

    if text == "" then
        return nil
    end

    return text
end

local function matchTable(map, value)
    if not map or type(value) ~= "string" or value == "" then
        return nil
    end

    if map[value] then
        return value
    end

    local target = normalizeName(value)
    if not target then
        return nil
    end

    for key in pairs(map) do
        if normalizeName(key) == target then
            return key
        end
    end

    for key in pairs(map) do
        local normalized = normalizeName(key)

        if normalized and #normalized > 2 then
            if normalized:find(target, 1, true) or target:find(normalized, 1, true) then
                return key
            end
        end
    end

    return nil
end

local function attrList(constant, fallback)
    local names = {}

    if type(constant) == "string" and constant ~= "" then
        table.insert(names, constant)
    end

    for _, name in ipairs(fallback) do
        if not table.find(names, name) then
            table.insert(names, name)
        end
    end

    return names
end

Mining.pickaxeAttrs = attrList(
    Game.Constants and Game.Constants.ATTR_TOOL_MATERIAL,
    { "Material", "Pickaxe", "ToolClass" }
)

Mining.handleAttrs = attrList(
    Game.Constants and Game.Constants.ATTR_TOOL_WOOD_MATERIAL,
    { "WoodMaterial", "Handle", "Wood" }
)

local function headPart(pickaxe)
    local head = pickaxe:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head
    end

    for _, child in ipairs(pickaxe:GetChildren()) do
        if child:IsA("BasePart") and child.Name ~= "Handle" then
            return child
        end
    end

    return nil
end

local function resolvePickaxe(pickaxe)
    for _, attrName in ipairs(Mining.pickaxeAttrs) do
        local key = matchTable(Game.Pickaxes, pickaxe:GetAttribute(attrName))
        if key then
            return Game.Pickaxes[key], key, attrName
        end
    end

    local key = matchTable(Game.Pickaxes, pickaxe.Name)
    if key then
        return Game.Pickaxes[key], key, "name"
    end

    local head = headPart(pickaxe)
    if head and Game.Pickaxes then
        for name, info in pairs(Game.Pickaxes) do
            if info.Material == head.Material and colorMatches(info.Color, head.Color) then
                return info, name, "head"
            end
        end
    end

    return nil
end

local function resolveHandle(pickaxe)
    for _, attrName in ipairs(Mining.handleAttrs) do
        local key = matchTable(Game.Handles, pickaxe:GetAttribute(attrName))
        if key then
            return key, attrName
        end
    end

    local part = pickaxe:FindFirstChild("Handle")
    if part and part:IsA("BasePart") and Game.Handles then
        for key, info in pairs(Game.Handles) do
            if colorMatches(info.Color, part.Color) then
                return key, "handle-part"
            end
        end
    end

    return nil
end

local function signature(pickaxe)
    local parts = { pickaxe.Name }

    for _, attrName in ipairs(Mining.pickaxeAttrs) do
        table.insert(parts, tostring(pickaxe:GetAttribute(attrName)))
    end

    for _, attrName in ipairs(Mining.handleAttrs) do
        table.insert(parts, tostring(pickaxe:GetAttribute(attrName)))
    end

    return table.concat(parts, "|")
end

local detectCache = setmetatable({}, { __mode = "k" })

function Mining.detect(pickaxe)
    if not pickaxe then
        return nil
    end

    local sig = signature(pickaxe)
    local cached = detectCache[pickaxe]

    if cached and cached.signature == sig then
        return cached
    end

    local info, pickaxeName, pickaxeSource = resolvePickaxe(pickaxe)
    local handleName, handleSource = resolveHandle(pickaxe)

    local result = {
        signature = sig,
        pickaxeInfo = info,
        pickaxeName = pickaxeName,
        pickaxeSource = pickaxeSource,
        handleName = handleName,
        handleSource = handleSource,
    }

    detectCache[pickaxe] = result
    return result
end

function Mining.handleInfo(pickaxe)
    local detected = Mining.detect(pickaxe)
    if not detected then
        return nil
    end

    local name = detected.handleName
    return name and Game.Handles and Game.Handles[name] or nil, name, detected.handleSource
end

function Mining.describe(pickaxe)
    if not pickaxe then
        return "none"
    end

    local parts = {}

    for _, attrName in ipairs(Mining.pickaxeAttrs) do
        table.insert(parts, ("%s=%s"):format(attrName, tostring(pickaxe:GetAttribute(attrName))))
    end

    for _, attrName in ipairs(Mining.handleAttrs) do
        table.insert(parts, ("%s=%s"):format(attrName, tostring(pickaxe:GetAttribute(attrName))))
    end

    return table.concat(parts, " ")
end

function Mining.refreshBase()
    local source = "default"
    local base = Config.defaultMineTime

    if type(Mining.serverBase) == "number" and Mining.serverBase > 0 then
        base = Mining.serverBase
        source = "server"
    elseif type(Mining.tableBase) == "number" and Mining.tableBase > 0 then
        base = Mining.tableBase
        source = "table"
    end

    Mining.baseMineTime = base
    Mining.baseSource = source
end

Mining.bound = setmetatable({}, { __mode = "k" })

function Mining.bind(pickaxe)
    local remote = pickaxe:FindFirstChild(Config.pickaxeRemote)
    if not remote or Mining.bound[pickaxe] then
        return
    end

    Mining.bound[pickaxe] = true

    remote.OnClientEvent:Connect(function(data)
        if typeof(data) == "table" and type(data.BaseMineTime) == "number" then
            Mining.serverBase = data.BaseMineTime
            Mining.refreshBase()
            logPrint(("update pickaxe base=%.2f source=server"):format(data.BaseMineTime))
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

    local detected = Mining.detect(pickaxe)
    local toolChanged = Mining.pickaxe ~= pickaxe
    local statsChanged = toolChanged or Mining.statsSignature ~= detected.signature

    if toolChanged then
        Mining.pickaxe = pickaxe
        Mining.rebound = false
        Mining.serverBase = nil
        Mining.bind(pickaxe)
    end

    if statsChanged then
        Mining.statsSignature = detected.signature
        Mining.tableBase = detected.pickaxeInfo and detected.pickaxeInfo.BaseMineTime or nil
        Mining.pickaxeName = detected.pickaxeName
        Mining.pickaxeSource = detected.pickaxeSource
        Mining.handle = detected.handleName
        Mining.handleSource = detected.handleSource
        Mining.refreshBase()

        logPrint(("pickaxe %s (%s) base=%.2f source=%s handle=%s (%s)"):format(
            pickaxe.Name,
            tostring(Mining.pickaxeName),
            Mining.baseMineTime,
            tostring(Mining.baseSource),
            tostring(Mining.handle),
            tostring(Mining.handleSource)
        ))
        logPrint("tool attributes: " .. Mining.describe(pickaxe))
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

    -- The server sends BaseMineTime on equip via UpdatePickaxe.OnClientEvent.
    -- Wait for it once per tool, after the re-equip above has triggered it.
    if toolChanged and type(Mining.serverBase) ~= "number" then
        local deadline = os.clock() + Config.mineWaitForServer
        while os.clock() < deadline do
            if type(Mining.serverBase) == "number" and Mining.serverBase > 0 then
                break
            end
            RunService.Heartbeat:Wait()
        end
        Mining.refreshBase()
        logPrint(("pickaxe ready base=%.2f source=%s handle=%s"):format(
            Mining.baseMineTime,
            tostring(Mining.baseSource),
            tostring(Mining.handle)
        ))
    end

    return pickaxe
end

function Mining.mineTime(block)
    local info = resourceInfo(typeOf(block))
    local modifier = info and info.MineTimeModifier or 1
    local speed = Players.LocalPlayer:GetAttribute("ToolSpeedModifier") or 0

    return math.max(Mining.baseMineTime * ((100 - speed) / 100) * modifier, 0.1)
end

function Mining.waitTime(block)
    local ping = Ping.sample()

    local baseMine = Mining.mineTime(block)
    local jitter = math.random() * (Config.mineJitterMax - Config.mineJitterMin) + Config.mineJitterMin

    local safety = Config.mineSafetyBase + ping * Config.mineSafetyPingMult
    return baseMine + safety + jitter
end

function Mining.preSwingDelay()
    return math.random() * (Config.minePreSwingMax - Config.minePreSwingMin) + Config.minePreSwingMin
end

function Mining.swingDelay()
    return math.random() * (Config.mineSwingMax - Config.mineSwingMin) + Config.mineSwingMin
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

function Mining.valid(block)
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

    if BLOCKED[name] then
        return "blocked"
    end

    local world = block:GetAttribute(Game.attrWorldId)
    local playerWorld = Players.LocalPlayer:GetAttribute(Game.attrWorldId)
    if tostring(world) ~= tostring(playerWorld) then
        return "world"
    end

    local dug = block:FindFirstChild("Dug")
    if dug and dug.Value ~= "" and dug.Value ~= Players.LocalPlayer.Name then
        return "dug"
    end

    return nil
end

function Mining.why(block)
    local reason = Mining.valid(block)
    if reason then
        return reason
    end

    if Mining.besideLiquid(block) then
        return "liquid"
    end

    return nil
end

function Mining.reach()
    return math.max(8, Mining.maxDistance() - Config.mineReachMargin)
end

function Mining.inRange(character, block)
    local root = character.PrimaryPart
    if not root then
        return false
    end
    return (block.Position - root.Position).Magnitude <= Mining.reach()
end

function Mining.mine(character, block)
    local reason = Mining.why(block)
    if reason then
        logWarn(("skip %s: %s"):format(block.Name, reason))
        return false
    end

    if not Mining.inRange(character, block) then
        logWarn("out of range " .. block.Name)
        return false
    end

    local position = block:GetAttribute(Game.attrMinePosition)
    local blockEvent = ReplicatedStorage:FindFirstChild(Config.blockEvent)
    local minedEvent = ReplicatedStorage:FindFirstChild(Config.minedEvent)
    if not position or not blockEvent or not minedEvent then
        logWarn("remotes not found")
        return false
    end

    local waitTime = Mining.waitTime(block)
    local preSwing = Mining.preSwingDelay()
    local swing = Mining.swingDelay()

    logPrint(("mine %s (%s) base=%.2f wait=%.2f pre=%.2f swing=%.2f"):format(
        block.Name,
        tostring(typeOf(block)),
        Mining.baseMineTime,
        waitTime,
        preSwing,
        swing
    ))

    task.wait(preSwing)

    if not block.Parent then
        return false
    end

    blockEvent:FireServer(block.Name, { dug = true })

    task.wait(swing)
    task.wait(waitTime)

    if not block.Parent then
        return true
    end

    minedEvent:FireServer({ blockName = vec3ToString(position) })

    local deadline = os.clock() + Config.mineRejectGrace
    while block.Parent and os.clock() < deadline do
        task.wait(0.02)
    end

    if block.Parent then
        blockEvent:FireServer(vec3ToString(position), { dug = false })
        logWarn(("server rejected %s type=%s base=%.2f wait=%.3f"):format(
            block.Name,
            tostring(typeOf(block)),
            Mining.baseMineTime,
            waitTime
        ))
        return false
    end

    return true
end

---------------------------------------------------------------------------
-- Ores
---------------------------------------------------------------------------

local Ores = {}

local namesCache
local ignored = {}

function Ores.price(name)
    local info = resourceInfo(name)
    return info and info.BasePrice or 0
end

function Ores.names()
    if namesCache then
        return namesCache
    end

    local names = {}

    if Game.Resources then
        for name, info in pairs(Game.Resources) do
            if type(info) == "table" and info.Natural then
                table.insert(names, name)
            end
        end
    end

    table.sort(names, function(a, b)
        return Ores.price(a) > Ores.price(b)
    end)

    namesCache = names
    return names
end

function Ores.bindSelection(selection, names)
    Ores.selection = selection
    Ores.namesList = names
end

local selectionCache = { time = 0 }

function Ores.selectedSet()
    local selection = Ores.selection
    if not selection then
        return nil
    end

    local indices = selection.getSelected() or {}
    local keyParts = {}

    for _, index in ipairs(indices) do
        table.insert(keyParts, tostring(index))
    end

    local key = table.concat(keyParts, ",")
    local now = os.clock()

    if selectionCache.set and selectionCache.key == key and now - selectionCache.time < 0.5 then
        return selectionCache.set
    end

    local set = {}

    for _, index in ipairs(indices) do
        local name = Ores.namesList[index]
        if name then
            set[name] = true
        end
    end

    selectionCache.set = set
    selectionCache.key = key
    selectionCache.time = now
    return set
end

function Ores.isSelected(name)
    local set = Ores.selectedSet()
    if not set then
        return true
    end

    return set[name] == true
end

local scanCache = {}

-- Scans only the block cells around the player instead of every child of Workspace.Mine.
function Ores.nearest(position, radius)
    local limit = radius or Config.oreRange
    local center = Blocks.toBlock(position)
    local now = os.clock()

    if scanCache.cell == center and now - scanCache.time < 0.3
        and (scanCache.best == nil or scanCache.best.Parent) then
        return scanCache.best
    end

    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return nil
    end

    local reach = math.ceil(limit / 7)
    local selected = Ores.selectedSet()
    local best, bestScore

    for dx = -reach, reach do
        for dy = -reach, reach do
            for dz = -reach, reach do
                local cell = center + Vector3.new(dx, dy, dz)
                local block = mine:FindFirstChild(vec3ToString(cell))

                if block then
                    local untilIgnore = ignored[block]
                    local distance = (block.Position - position).Magnitude

                    if distance <= limit and (not untilIgnore or untilIgnore <= now) then
                        local name = typeOf(block)

                        if name and (not selected or selected[name]) and Mining.valid(block) == nil then
                            local score = Ores.price(name) * 1000 - distance

                            if not bestScore or score > bestScore then
                                best, bestScore = block, score
                            end
                        end
                    end
                end
            end
        end
    end

    scanCache.time = now
    scanCache.cell = center
    scanCache.best = best
    return best
end

function Ores.ignore(block)
    ignored[block] = os.clock() + 5
    scanCache.time = 0
    scanCache.best = nil
end

function Ores.count()
    local set = Ores.selectedSet()
    if not set then
        return #Ores.names()
    end

    local total = 0

    for _ in pairs(set) do
        total += 1
    end

    return total
end

---------------------------------------------------------------------------
-- Loot (workspace.TargetFilter/{BlockName}_Drop)
---------------------------------------------------------------------------

local Loot = {
    pending = {},
    pendingSet = {},
    lastSync = 0,
}

function Loot.container()
    return workspace:FindFirstChild("TargetFilter") or workspace:FindFirstChild("Drops")
end

local partCache = setmetatable({}, { __mode = "k" })
local ownerCache = setmetatable({}, { __mode = "k" })

function Loot.part(drop)
    local cached = partCache[drop]
    if cached and cached.Parent then
        return cached
    end

    local part

    if drop:IsA("BasePart") then
        part = drop
    else
        for _, child in ipairs(drop:GetChildren()) do
            if child:IsA("BasePart") then
                part = child
                break
            end
        end

        part = part or drop:FindFirstChildWhichIsA("BasePart", true)
    end

    partCache[drop] = part
    return part
end

function Loot.playerValue(drop)
    local cached = ownerCache[drop]
    if cached ~= nil then
        return cached
    end

    local dropScript = drop:FindFirstChild("DropScript", true)
    local playerValue = dropScript and dropScript:FindFirstChild("Player")
    local value = playerValue and playerValue.Value

    if value ~= nil then
        ownerCache[drop] = value
    end

    return value
end

function Loot.mine(drop)
    local value = Loot.playerValue(drop)
    if value == nil then
        return false
    end

    local player = Players.LocalPlayer
    return value == player
        or value == player.Name
        or value == player.UserId
        or tostring(value) == tostring(player)
end

function Loot.name(drop)
    return (tostring(drop.Name):gsub("_Drop$", ""))
end

function Loot.count()
    return #Loot.pending
end

function Loot.sync(force)
    if not force and os.clock() - Loot.lastSync < Config.lootSyncInterval then
        return
    end
    Loot.lastSync = os.clock()

    local container = Loot.container()
    if not container then
        Loot.pending = {}
        Loot.pendingSet = {}
        return
    end

    local seen = {}

    for _, drop in ipairs(container:GetChildren()) do
        if (drop:IsA("Model") or drop:IsA("BasePart")) and Loot.part(drop) and Loot.mine(drop) then
            if Ores.isSelected(Loot.name(drop)) then
                seen[drop] = true
                if not Loot.pendingSet[drop] then
                    Loot.pendingSet[drop] = true
                    table.insert(Loot.pending, drop)
                end
            end
        end
    end

    for index = #Loot.pending, 1, -1 do
        local drop = Loot.pending[index]
        if not drop.Parent or not seen[drop] then
            Loot.pendingSet[drop] = nil
            table.remove(Loot.pending, index)
        end
    end
end

function Loot.remove(drop)
    if Loot.pendingSet[drop] then
        Loot.pendingSet[drop] = nil
        local index = table.find(Loot.pending, drop)
        if index then
            table.remove(Loot.pending, index)
        end
    end
end

-- Loot has priority over mining: teleports straight to every own selected drop,
-- waits for the touch, then returns. No radius limit, no grouping.
function Loot.collectAll(character)
    Loot.sync(true)

    local root = character.PrimaryPart
    if not root then
        return 0
    end

    table.sort(Loot.pending, function(a, b)
        return Ores.price(Loot.name(a)) > Ores.price(Loot.name(b))
    end)

    local picked = 0
    local index = 1

    while index <= #Loot.pending do
        local drop = Loot.pending[index]

        if not drop.Parent then
            Loot.remove(drop)
        else
            local part = Loot.part(drop)

            if part then
                Movement.jump(character, part.Position)
                task.wait(Config.lootDwell)
            end

            if not drop.Parent then
                Loot.remove(drop)
                picked += 1
            else
                index += 1
            end
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

-- Escape for the dig-straight-down case: the block under the bot is one we refuse
-- to dig (liquid neighbour, Oil/Lava/Grass/Void, someone else's Dug). Pick the
-- richest neighbouring column whose own cell is empty and whose floor is diggable,
-- so the next down-dig has a different block under it.
local function stepAside(character, root)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return
    end

    local cell = Blocks.toBlock(root.Position)
    local best, bestPrice

    for _, offset in pairs(blockOffsets) do
        if offset.Y == 0 then
            local side = cell + Vector3.new(offset.X, 0, offset.Z)
            local floor = mine:FindFirstChild(vec3ToString(side + Vector3.new(0, 1, 0)))

            if floor
                and Mining.why(floor) == nil
                and not mine:FindFirstChild(vec3ToString(side)) then
                local price = Ores.price(typeOf(floor) or "")

                if not best or price > bestPrice then
                    best, bestPrice = side, price
                end
            end
        end
    end

    if not best then
        logWarn("down-block undiggable, no side escape")
        task.wait(1)
        return
    end

    local world = Blocks.worldOf(best)
    logPrint(("step aside -> %s"):format(vec3ToString(best)))
    Movement.jump(character, Vector3.new(world.X, root.Position.Y, world.Z))
end

local FarmMode = Mode.new("Farm", function(self)
    local character = Character.get()
    if not self.enabled then
        return
    end

    if not character.PrimaryPart then
        return
    end

    -- 1. Loot first: teleport to every own drop immediately.
    Loot.sync(true)

    if Loot.count() > 0 then
        Loot.collectAll(character)
    end

    -- Do not fire BlockEvent in the same tick as any teleport.
    if Movement.lastMoveAt then
        local elapsed = os.clock() - Movement.lastMoveAt

        if elapsed < Config.moveCooldown then
            task.wait(Config.moveCooldown - elapsed)
        end
    end

    if not self.enabled then
        return
    end

    local root = character.PrimaryPart

    local function mine(block)
        if not block or not block.Parent then
            return false
        end

        if not Mining.inRange(character, block) then
            return false
        end

        if not Mining.prepare(character) then
            logWarn("no pickaxe")
            return false
        end

        logPrint(("mine %s (%s)"):format(block.Name, tostring(typeOf(block))))

        Movement.hold(character)
        local ok, result = pcall(Mining.mine, character, block)
        Movement.releaseHold()

        if not ok or not result then
            return false
        end

        task.wait(Config.lootSpawnWait)
        return true
    end

    -- 2. On the surface: reuse an existing shaft and keep moving until the character
    -- really stands over its mouth.
    local cell = Blocks.toBlock(root.Position)

    if cell.Y < Config.surfaceDepth then
        local shaft = Surface.choose(root.Position)

        if shaft then
            if cell.X ~= shaft.cell.X or cell.Z ~= shaft.cell.Z then
                local mouth = Vector3.new(shaft.cell.X, cell.Y, shaft.cell.Z)
                local field = workspace:FindFirstChild(Config.mineName)

                -- The cached mouth can be stale: only jump when that cell is really empty.
                if not field or not field:FindFirstChild(vec3ToString(mouth)) then
                    Movement.jump(character, Blocks.worldOf(mouth))
                    return
                end

                Surface.drop(mouth)
            else
                local below = Blocks.below(root.Position)

                if below then
                    if mine(below) then
                        Movement.waitLanded(character)
                        return
                    end

                    Ores.ignore(below)

                    -- A floor we are never allowed to dig makes this pit a dead end: drop it
                    -- so the next tick aims at another one instead of idling at this mouth.
                    local reason = Mining.why(below)

                    if reason then
                        logWarn(("pit %s unusable: %s"):format(vec3ToString(shaft.cell), reason))
                        Surface.drop(shaft.cell)
                    end

                    return
                end

                -- Nothing under the feet: falling into the shaft is progress, standing on
                -- geometry that is not a mine block is a dead end.
                local humanoid = character:FindFirstChildOfClass("Humanoid")

                if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                    Surface.drop(shaft.cell)
                end

                Movement.waitLanded(character)
                return
            end
        end
    end

    -- 3. Mine the best selected block already in reach. No movement.
    local ore = Ores.nearest(root.Position, Mining.reach())

    if ore then
        if not mine(ore) then
            Ores.ignore(ore)
        end
        return
    end

    -- 4. Nothing reachable: dig straight down, one block at a time.
    local below = Blocks.below(root.Position)

    if not below then
        Movement.waitLanded(character)
        return
    end

    if mine(below) then
        Movement.waitLanded(character)
        return
    end

    if below.Parent and Mining.why(below) then
        stepAside(character, root)
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

function Ui.stats()
    local character = Character.get()
    local pickaxe = Character.getPickaxe(character)
    local detected = pickaxe and Mining.detect(pickaxe)
    local info = detected and detected.pickaxeInfo
    local handle, handleName, handleSource = Mining.handleInfo(pickaxe)
    local player = Players.LocalPlayer

    local selected = Ores.count()

    return {
        pickaxe = ("%s | %s | tier %s | base %.2fs (%s)"):format(
            pickaxe and pickaxe.Name or "none",
            tostring(Mining.pickaxeName or "?"),
            tostring(info and info.Tier or "?"),
            Mining.baseMineTime,
            tostring(Mining.baseSource or "?")
        ),
        handle = ("%s (%s) | speed %s | move %s | luck %s | double %s"):format(
            tostring(handleName or "?"),
            tostring(handleSource or "?"),
            tostring(handle and handle.SpeedModifier or 0),
            tostring(handle and handle.MoveSpeedModifier or 0),
            tostring(handle and handle.LuckModifier or 0),
            tostring(handle and handle.DoubleDropChanceModifier or 0)
        ),
        player = ("world %s | toolspeed %s | luck %s | double %s"):format(
            tostring(player:GetAttribute(Game.attrWorldId)),
            tostring(player:GetAttribute("ToolSpeedModifier")),
            tostring(player:GetAttribute("Luck")),
            tostring(player:GetAttribute("DoubleDropChance"))
        ),
        state = ("ores %d | loot %d | depth %s | mine %s"):format(
            selected,
            Loot.count(),
            tostring(Blocks.toBlock(character.PrimaryPart.Position).Y),
            workspace:FindFirstChild(Config.mineName) and "ok" or "missing"
        ),
    }
end

function Ui.printStats()
    local stats = Ui.stats()
    print("[em2] pickaxe: " .. stats.pickaxe)
    print("[em2] handle: " .. stats.handle)
    print("[em2] player: " .. stats.player)
    print("[em2] state: " .. stats.state)
end

function Ui.create()
    local library = Ui.load()
    local window = library.init("nazar mining 2", "v1.1.0", "NM2_MAIN")

    local main, _ = window:AddTab("Main", "артем сын ебланки")

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

    local debugTab = window:AddTab("Debug", "stats and logs")
    local statsPanel = debugTab:AddSeperator("Stats")

    local pickaxeInput = statsPanel:AddTextInput({ title = "Pickaxe" })
    local handleInput = statsPanel:AddTextInput({ title = "Handle" })
    local playerInput = statsPanel:AddTextInput({ title = "Player" })
    local stateInput = statsPanel:AddTextInput({ title = "State" })

    local logPanel = debugTab:AddSeperator("Logs")
    logPanel:AddToggle({
        title = "Verbose logs",
        desc = "print ore reasons and mining steps",
        callback = function(state)
            Log.enabled = state
        end,
    })

    logPanel:AddButton({
        title = "Print stats",
        callback = function()
            Ui.printStats()
        end,
    })

    task.spawn(function()
        while true do
            task.wait(2)

            local ok = pcall(function()
                local stats = Ui.stats()
                pickaxeInput.setText(stats.pickaxe)
                handleInput.setText(stats.handle)
                playerInput.setText(stats.player)
                stateInput.setText(stats.state)
            end)

            if not ok then
                break
            end
        end
    end)

    modeDropdown.setSelected(1)

    return window
end

---------------------------------------------------------------------------
-- Log view
---------------------------------------------------------------------------

local LogView = {}

function LogView.create()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "NM2_Logs"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "LogFrame"
    frame.Size = UDim2.fromOffset(520, 150)
    frame.Position = UDim2.new(0, 10, 1, -160)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 16)
    title.Position = UDim2.fromOffset(6, 4)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(150, 200, 150)
    title.Text = "NM2 logs"
    title.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, -26)
    label.Position = UDim2.fromOffset(6, 20)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Bottom
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = ""
    label.Parent = frame

    local function render(lines)
        label.Text = table.concat(lines, "\n")
    end

    Log.render = render
    render(Log.lines)

    return gui
end

---------------------------------------------------------------------------
-- GUI toggle button
---------------------------------------------------------------------------

function Ui.toggleButton(window)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "NM2_Toggle"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(52, 24)
    button.Position = UDim2.new(0, 10, 0, 36)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 12
    button.TextColor3 = Color3.fromRGB(230, 230, 230)
    button.Text = "Hide"
    button.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    button.Activated:Connect(function()
        local visible = window:ToggleGUI()
        button.Text = visible and "Hide" or "Show"
    end)

    return gui
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

LogView.create()

local ok, window = pcall(Ui.create)
if ok and window then
    Ui.toggleButton(window)
else
    warn("[main] ui failed: " .. tostring(window))
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

    local detected = pickaxe and Mining.detect(pickaxe)
    local handle, handleName, handleSource = Mining.handleInfo(pickaxe)
    print(("[main] player world=%s toolspeed=%s pickaxe=%s base=%s (%s) handle=%s (%s)"):format(
        tostring(Players.LocalPlayer:GetAttribute(Game.attrWorldId)),
        tostring(Players.LocalPlayer:GetAttribute("ToolSpeedModifier")),
        tostring(detected and detected.pickaxeName),
        tostring(Mining.baseMineTime),
        tostring(Mining.baseSource),
        tostring(handleName),
        tostring(handleSource)
    ))
    print("[main] tool attributes: " .. Mining.describe(pickaxe))
    if handle then
        print(("[main] handle speed=%s luck=%s double=%s"):format(
            tostring(handle.SpeedModifier),
            tostring(handle.LuckModifier),
            tostring(handle.DoubleDropChanceModifier)
        ))
    end

    print("[main] F1 farm, F2 mushrooms")
end)

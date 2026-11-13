local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

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
    maxRejects = 5,
    sideSearchRadius = 10,

    surfaceDepth = 2,
    surfaceScanRadius = 6,
    surfaceMaxDepth = 10,
    surfaceMinDepth = 2,
    surfaceProbeDepth = 6,
    surfaceStarMin = 8,
    fieldCenter = Vector3.new(89.5, 7998.5, -21.5),
    fieldRadius = 14,
    emptyMineLift = 20,
    emptyMineWait = 2,
    teleportLift = 3.5,
    liquidStuckCount = 4,
    liquidSearchRange = 16,
    moveBuffer = 0.1,
    moveSettleTime = 0.25,
    moveSettleEpsilon = 0.2,

    lootDwell = 0.12,
    lootSpawnWait = 0.3,
    lootSyncInterval = 0.4,

    sellRemote = "SellResourceFunction",
    sellCapacity = 200,
    sellCooldown = 1,
    sellAnchor = Vector3.new(78, 8013, -219),
    surfaceRemote = "TeleportToSurfaceFunction",
    surfaceTeleportWait = 0.5,
    sellHoldBefore = 2,
    sellHoldAfter = 1,

    blockEvent = "BlockEvent",
    minedEvent = "BlockMinedEvent",
    pickaxeRemote = "UpdatePickaxe",
    defaultMineTime = 4,
}

---------------------------------------------------------------------------
-- Settings (executor standard: writefile/readfile/isfile/makefolder + JSON)
---------------------------------------------------------------------------

local Settings = {
    path = "nm2/settings.json",
    fallbackPath = "nm2_settings.json",
    data = {},
    loaded = false,
}

local function settingsReady()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

function Settings.load()
    if Settings.loaded then
        return Settings.data
    end

    Settings.loaded = true

    if not settingsReady() then
        return Settings.data
    end

    local source = Settings.path
    local existsOk, exists = pcall(isfile, source)

    if not existsOk or not exists then
        source = Settings.fallbackPath
        existsOk, exists = pcall(isfile, source)
    end

    if not existsOk or not exists then
        return Settings.data
    end

    local readOk, text = pcall(readfile, source)
    if not readOk or type(text) ~= "string" or text == "" then
        return Settings.data
    end

    Settings.lastJson = text

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(text)
    end)

    if decodeOk and type(decoded) == "table" then
        Settings.data = decoded
    end

    return Settings.data
end

function Settings.get(key, fallback)
    local value = Settings.load()[key]
    if value == nil then
        return fallback
    end
    return value
end

function Settings.persist()
    if not settingsReady() then
        return
    end

    local okEncode, text = pcall(function()
        return HttpService:JSONEncode(Settings.data)
    end)

    if not okEncode or text == Settings.lastJson then
        return
    end

    Settings.lastJson = text

    local okWrite = pcall(function()
        if type(makefolder) == "function" then
            pcall(makefolder, "nm2")
        end
        writefile(Settings.path, text)
    end)

    if not okWrite then
        pcall(writefile, Settings.fallbackPath, text)
    end
end

function Settings.set(key, value)
    Settings.load()
    Settings.data[key] = value
    Settings.persist()
end

-- List of option indexes (selection), always a table of numbers.
function Settings.indices(key, fallback)
    local value = Settings.get(key)
    if type(value) ~= "table" then
        return fallback
    end

    local list = {}

    for _, index in ipairs(value) do
        if type(index) == "number" then
            table.insert(list, index)
        end
    end

    return list
end

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

    -- Kill leftover velocity before the root is unanchored, otherwise the
    -- character keeps tween momentum and tumbles on landing.
    local root = Movement.root or Movement.holdRoot

    if root and root.Parent then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
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

        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        Character.platformStand(character, false)
        task.wait(Config.moveBuffer)
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

    local finished = false
    local connection = tween.Completed:Connect(function()
        finished = true
    end)

    tween:Play()

    local deadline = os.clock() + duration + 1
    while not finished and Movement.tween == tween and os.clock() < deadline do
        task.wait(0.03)
    end
    connection:Disconnect()

    local reached = (root.Position - position).Magnitude <= Config.moveStopDistance + 3

    -- Stay anchored at the destination for a short buffer before physics resumes.
    if Movement.tween == tween then
        task.wait(Config.moveBuffer)
        Movement.release()
    end

    if not reached and root.Parent then
        character:PivotTo(CFrame.new(position))
    end

    Movement.lastMoveAt = os.clock()
    Movement.settle(character)
end

-- Single movement path for every teleport in the script (loot, surface, pits,
-- step aside, auto sell). `Movement.to` decides how to move:
--   Config.instantMove == true  -> PivotTo immediately;
--   Config.instantMove == false -> Linear tween at Config.tweenSpeed,
--                                  then settle.
function Movement.jump(character, position, speed)
    Movement.to(character, position, speed)
end

---------------------------------------------------------------------------
-- Blocks (world <-> block coordinates)
---------------------------------------------------------------------------

local Blocks = {}

local BASE_X = 61.5
local BASE_Z = -56.5
local BASE_ALTITUDE = 7998.5

Blocks.offset = Vector3.new(0, 0, 0)
Blocks.calibrated = false
Blocks.lastCalibrate = 0

local function rawBlock(position)
    return Vector3.new(
        math.floor((position.X - BASE_X) / 7 + 0.5),
        -math.floor((position.Y - BASE_ALTITUDE) / 7 + 0.5),
        math.floor((position.Z - BASE_Z) / 7 + 0.5)
    )
end

local function rawWorld(cell)
    return Vector3.new(
        BASE_X + 7 * cell.X,
        BASE_ALTITUDE - 7 * cell.Y,
        BASE_Z + 7 * cell.Z
    )
end

function Blocks.toBlock(position)
    return rawBlock(position) + Blocks.offset
end

function Blocks.worldOf(cell)
    return rawWorld(cell - Blocks.offset)
end

-- Block names are built from the `MinePosition` attribute, which may be shifted
-- from the world formula by a constant. One full children pass at the field
-- centre measures that shift once; after that every name lookup is exact.
function Blocks.calibrate()
    if Blocks.calibrated then
        return
    end

    if os.clock() - Blocks.lastCalibrate < 5 then
        return
    end

    Blocks.lastCalibrate = os.clock()

    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return
    end

    local firstOffset, firstDistance
    local secondOffset, secondDistance

    for _, block in ipairs(mine:GetChildren()) do
        local minePosition = block:GetAttribute(Game.attrMinePosition)

        if minePosition then
            local offset = minePosition - rawBlock(block.Position)
            local distance = (block.Position - Config.fieldCenter).Magnitude

            if not firstDistance or distance < firstDistance then
                secondOffset, secondDistance = firstOffset, firstDistance
                firstOffset, firstDistance = offset, distance
            elseif not secondDistance or distance < secondDistance then
                secondOffset, secondDistance = offset, distance
            end
        end
    end

    if not firstOffset then
        return
    end

    -- Validate on the second nearest block: a per-part pivot quirk would give a
    -- different offset there, so only accept a stable one.
    if secondOffset and secondOffset ~= firstOffset then
        logWarn("block offset not stable, keeping zero")
        Blocks.calibrated = true
        return
    end

    Blocks.offset = firstOffset
    Blocks.calibrated = true
    logPrint(("blocks offset %s"):format(tostring(Blocks.offset)))
end

-- Centre of an empty cell: the root lands inside the same cell whose floor was
-- validated, not on a cell boundary that can round to a neighbour.
function Blocks.standPoint(cell)
    return Blocks.worldOf(cell) + Vector3.new(0, 0.5, 0)
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
-- Surface pits
---------------------------------------------------------------------------

local Surface = {}

-- Eight horizontal directions used to probe the sides of a pit/target cell.
Surface.dirs = {
    Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    Vector3.new(1, 0, 1), Vector3.new(1, 0, -1),
    Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1),
}

-- Depth of an open column: number of empty cells from topY down to the first
-- solid block. nil means no floor inside surfaceMaxDepth, i.e. outside the mine.
function Surface.depth(mine, x, z, topY)
    for depth = 0, Config.surfaceMaxDepth - 1 do
        local y = topY + depth
        if mine:FindFirstChild(vec3ToString(Vector3.new(x, y, z))) then
            return depth
        end
    end

    return nil
end

function Surface.atField(position)
    local center = Config.fieldCenter
    local dx = position.X - center.X
    local dz = position.Z - center.Z
    return dx * dx + dz * dz <= Config.fieldRadius * Config.fieldRadius
end

-- 8 side "star" probes at the floor level: in every direction walk outward up
-- to surfaceProbeDepth blocks until a solid mine block is met. A cell is inside
-- the mine only when every one of the 8 rays hits.
function Surface.star(mine, cell, floorY)
    local hits = 0

    for _, dir in ipairs(Surface.dirs) do
        for step = 1, Config.surfaceProbeDepth do
            local side = Vector3.new(
                cell.X + dir.X * step,
                floorY,
                cell.Z + dir.Z * step
            )

            if mine:FindFirstChild(vec3ToString(side)) then
                hits += 1
                break
            end
        end
    end

    return hits
end

-- A pit cell is safe only when it is empty, has a solid floor and all 8 star
-- rays hit mine blocks. This rejects map edges, floating columns and open holes
-- that are not surrounded by generated terrain.
function Surface.safe(mine, cell, depth)
    if mine:FindFirstChild(vec3ToString(cell)) then
        return false
    end

    local floorY = cell.Y + depth

    if not mine:FindFirstChild(vec3ToString(Vector3.new(cell.X, floorY, cell.Z))) then
        return false
    end

    local hits = Surface.star(mine, cell, floorY)
    return hits >= Config.surfaceStarMin, hits
end

-- Deepest safe pit around `center` on layer `topY`. Collects depth candidates
-- first, then runs the expensive 8-ray star check only until the first valid
-- one (deepest, then nearest). One implementation for surface entry and reset.
function Surface.scan(mine, center, topY, minDepth)
    local candidates = {}
    local radius = Config.surfaceScanRadius

    for dx = -radius, radius do
        for dz = -radius, radius do
            local cell = Vector3.new(center.X + dx, topY, center.Z + dz)
            local depth = Surface.depth(mine, cell.X, cell.Z, topY)

            if depth and depth >= minDepth then
                table.insert(candidates, {
                    cell = cell,
                    depth = depth,
                    distance = dx * dx + dz * dz,
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.depth ~= b.depth then
            return a.depth > b.depth
        end
        return a.distance < b.distance
    end)

    for _, candidate in ipairs(candidates) do
        local ok, hits = Surface.safe(mine, candidate.cell, candidate.depth)

        if ok then
            logPrint(("pit %s depth=%d star=%d"):format(
                vec3ToString(candidate.cell), candidate.depth, hits))
            return candidate.cell
        end
    end

    return nil
end

-- Cell to stand in before dropping down, on the player's own layer.
function Surface.find(position)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return nil
    end

    Blocks.calibrate()

    local cell = Blocks.toBlock(position)
    return Surface.scan(mine, cell, cell.Y, Config.surfaceMinDepth)
end

-- Reset target after a rejection streak: the same scan on the fixed surface
-- layer around the field centre, so it can never leave the generated mine.
function Surface.resetPoint()
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return nil
    end

    local cell = Surface.scan(mine, Blocks.toBlock(Config.fieldCenter), -1, 1)
    if not cell then
        return nil
    end

    return Blocks.worldOf(cell) + Vector3.new(0, Config.teleportLift, 0)
end

---------------------------------------------------------------------------
-- Mining
---------------------------------------------------------------------------

local Mining = {
    baseMineTime = Config.defaultMineTime,
    rejects = 0,
    resetRequested = false,
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
        Mining.rejects = 0
        return true
    end

    minedEvent:FireServer({ blockName = vec3ToString(position) })

    local deadline = os.clock() + Config.mineRejectGrace
    while block.Parent and os.clock() < deadline do
        task.wait(0.02)
    end

    if block.Parent then
        blockEvent:FireServer(vec3ToString(position), { dug = false })
        Mining.rejects += 1

        logWarn(("server rejected %s type=%s base=%.2f wait=%.3f streak=%d"):format(
            block.Name,
            tostring(typeOf(block)),
            Mining.baseMineTime,
            waitTime,
            Mining.rejects
        ))

        if Mining.rejects >= Config.maxRejects then
            Mining.resetRequested = true
            logWarn(("%d rejects in a row, requesting surface reset"):format(Mining.rejects))
        end

        return false
    end

    Mining.rejects = 0
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
    local candidates = {}

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
                            table.insert(candidates, {
                                block = block,
                                score = Ores.price(name) * 1000 - distance,
                            })
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)

    -- Mining.valid is cheap but does not know about liquids: ask Mining.why
    -- lazily, and only for the sorted candidates until one really passes.
    local best

    for _, candidate in ipairs(candidates) do
        if candidate.block.Parent and Mining.why(candidate.block) == nil then
            best = candidate.block
            break
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

-- Drop the cached scan cell/target and all temporary ignore timers.
function Ores.clearCache()
    scanCache.time = 0
    scanCache.cell = nil
    scanCache.best = nil
    ignored = {}
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
-- Inventory (client-side resource counts)
---------------------------------------------------------------------------

-- Resource counts live in the client module `InventoriesClient`, loaded by
-- `PlayerScriptLoader` (see docs/game/instructions/getinventory.lua). Backpack
-- children are tools only and LocalPlayer attributes do not carry resources.
local Inventory = {
    client = nil,
    lastTry = 0,
    lastError = nil,
}

-- Log each distinct failure once instead of every 5 s retry.
local function inventoryWarn(text)
    if Inventory.lastError ~= text then
        Inventory.lastError = text
        logWarn(text)
    end
end

function Inventory.getClient()
    if Inventory.client then
        return Inventory.client
    end

    if os.clock() - Inventory.lastTry < 5 then
        return nil
    end
    Inventory.lastTry = os.clock()

    local loader = loadModule("Modules", "PlayerScriptLoader")
    if not loader then
        inventoryWarn("inventory: PlayerScriptLoader not found")
        return nil
    end

    local ok, scripts = pcall(function()
        return loader:WaitForPlayerScripts()
    end)
    if not ok or not scripts then
        inventoryWarn("inventory: WaitForPlayerScripts failed: " .. tostring(scripts))
        return nil
    end

    local modules = scripts:FindFirstChild("Modules")
    local module = modules and modules:FindFirstChild("InventoriesClient")
    if not module then
        inventoryWarn("inventory: PlayerScripts.Modules.InventoriesClient not found")
        return nil
    end

    local okModule, client = pcall(require, module)
    if not okModule or type(client) ~= "table" then
        inventoryWarn("inventory: require InventoriesClient failed: " .. tostring(client))
        return nil
    end

    Inventory.client = client
    Inventory.lastError = nil
    logPrint("inventory: InventoriesClient ready")
    return client
end

function Inventory.get()
    local client = Inventory.getClient()
    if not client then
        return nil
    end

    local ok, inventory = pcall(function()
        return client.GetInventory()
    end)
    if not ok then
        return nil
    end

    return inventory
end

-- nil when the inventory module is not loaded yet, so callers can fall back.
function Inventory.count(name)
    local inventory = Inventory.get()
    local resources = inventory and inventory.Resources
    if not resources then
        return nil
    end

    local value = resources[name]
    return type(value) == "number" and value or 0
end

function Inventory.usage()
    local inventory = Inventory.get()
    if inventory
        and type(inventory.CurrentSize) == "number"
        and type(inventory.MaxSize) == "number" then
        return inventory.CurrentSize, inventory.MaxSize
    end

    return nil
end

---------------------------------------------------------------------------
-- Auto sell (ReplicatedStorage.SellResourceFunction)
---------------------------------------------------------------------------

local Sell = {
    enabled = false,
    busy = false,
    selection = nil,
    namesList = nil,
    lastRun = 0,
}

-- Sellable resources: mined ores (Natural) plus mushrooms (MushroomResource).
-- Mushrooms have BasePrice but neither Natural nor AppearsInShop, so the farm
-- ore list does not contain them; without this they can never be selected.
function Sell.names()
    local names = {}

    if Game.Resources then
        for name, info in pairs(Game.Resources) do
            if type(info) == "table"
                and (info.Natural or info.MushroomResource)
                and info.BasePrice
                and not info.Unobtainable then
                table.insert(names, name)
            end
        end
    end

    table.sort(names, function(a, b)
        return Ores.price(a) > Ores.price(b)
    end)

    return names
end

function Sell.bindSelection(selection, names)
    Sell.selection = selection
    Sell.namesList = names
end

function Sell.selectedSet()
    local set = {}
    if not Sell.selection then
        return set
    end

    for _, index in ipairs(Sell.selection.getSelected() or {}) do
        local name = Sell.namesList[index]
        if name then
            set[name] = true
        end
    end

    return set
end

-- Stacks are item instances in the player's Backpack; the size is the
-- ATTR_ITEM_COUNT attribute (see Modules.Inventory.Backpack).
local attrItemCount = (Game.Constants and Game.Constants.ATTR_ITEM_COUNT) or "ItemCount"

-- InventoriesClient first (real resource counts), then Backpack tool stacks,
-- then a LocalPlayer attribute of the same name.
function Sell.count(name)
    local amount = Inventory.count(name)
    if amount ~= nil then
        return amount
    end

    local backpack = Players.LocalPlayer:FindFirstChild("Backpack")
    local total = 0

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == name then
                local value = item:GetAttribute(attrItemCount)

                if type(value) == "number" then
                    total += value
                end
            end
        end
    end

    if total > 0 then
        return total
    end

    local value = Players.LocalPlayer:GetAttribute(name)
    return type(value) == "number" and value or 0
end

-- used, capacity, source. Source tells where the numbers came from:
--   "client" — InventoriesClient.GetInventory() CurrentSize/MaxSize;
--   "gui"    — PlayerGui.Inventory.ToggleButton.InventoryUsed text "used / max";
--   "sum"    — sum of per-resource counts against Config.sellCapacity.
function Sell.usage()
    local used, capacity = Inventory.usage()
    if used and capacity then
        return used, capacity, "client"
    end

    local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
    local inventory = playerGui and playerGui:FindFirstChild("Inventory")
    local toggle = inventory and inventory:FindFirstChild("ToggleButton")
    local label = toggle and toggle:FindFirstChild("InventoryUsed")

    if label then
        local numbers = {}
        for number in label.Text:gmatch("%d+") do
            table.insert(numbers, tonumber(number))
        end
        if #numbers >= 2 then
            return numbers[1], numbers[2], "gui"
        end
    end

    local total = 0
    for _, name in ipairs(Ores.names()) do
        total += Sell.count(name)
    end
    return total, Config.sellCapacity, "sum"
end

function Sell.isFull()
    local used, capacity = Sell.usage()
    return capacity > 0 and used >= capacity
end

function Sell.selectedCount()
    local count = 0
    for _ in pairs(Sell.selectedSet()) do
        count += 1
    end
    return count
end

-- Throttled diagnostics: same noise level not repeated more than every 10 s.
function Sell.diag(key, text)
    local now = os.clock()

    if Sell.lastDiagKey == key and now - (Sell.lastDiag or 0) < 10 then
        return
    end

    Sell.lastDiagKey = key
    Sell.lastDiag = now
    logPrint(text)
end

-- Selling must go through ReplicatedStorage.TeleportToSurfaceFunction: the server
-- moves the player to the surface and only then accepts the sale. Client-side
-- movement is kept as a fallback when the remote is missing.
function Sell.toSurface(character)
    local root = character and character.PrimaryPart
    if not root then
        return false
    end

    local remote = ReplicatedStorage:FindFirstChild(Config.surfaceRemote)

    if remote then
        local ok, err = pcall(function()
            remote:InvokeServer()
        end)

        if ok then
            logPrint("autosell: called " .. Config.surfaceRemote)
        else
            logWarn(("autosell: %s failed: %s"):format(Config.surfaceRemote, tostring(err)))
        end

        task.wait(Config.surfaceTeleportWait)
        Movement.waitLanded(character, Config.surfaceTeleportWait)
        return true
    end

    logWarn("autosell: " .. Config.surfaceRemote .. " not found, moving client-side")
    Movement.jump(character, Config.sellAnchor)
    return true
end

-- Anchor the root where TeleportToSurfaceFunction put the character. No manual
-- repositioning: the server already places the player at the accepted point.
function Sell.holdForSale(character)
    local root = character and character.PrimaryPart
    if not root then
        return false
    end

    Movement.hold(character)
    return true
end

-- Independent watcher entry point: compares used vs max and runs the sell when
-- full. Works even when no mode is running. Every skip reason is logged.
function Sell.try(origin)
    local used, capacity, source = Sell.usage()

    if not capacity or capacity <= 0 then
        Sell.diag("nocap", ("autosell %s: no capacity used=%s src=%s"):format(
            origin, tostring(used), tostring(source)))
        return 0
    end

    if used < capacity then
        Sell.diag("notfull", ("autosell %s: not full used=%d/%d src=%s"):format(
            origin, used, capacity, tostring(source)))
        return 0
    end

    if os.clock() - Sell.lastRun < Config.sellCooldown then
        return 0
    end

    -- Never teleport out of an active BlockEvent/BlockMinedEvent window.
    if Movement.holdRoot then
        Sell.diag("busy", ("autosell %s: mining in progress, retry later"):format(origin))
        return 0
    end

    logPrint(("autosell trigger %s used=%d/%d src=%s enabled=%s"):format(
        origin, used, capacity, tostring(source), tostring(Sell.enabled)))

    if not Sell.enabled then
        return Sell.run(false, origin)
    end

    local character = Character.get()
    Sell.busy = true

    local ok, sold = pcall(function()
        if not Sell.toSurface(character) then
            Sell.diag("nosurface", "autosell: no character to move to the surface")
            return 0
        end

        -- Hold the surface position: sellHoldBefore seconds before the sale, the
        -- whole sale, then sellHoldAfter seconds after the last remote.
        if not Sell.holdForSale(character) then
            Sell.diag("nosurface", "autosell: no root to anchor for the sale")
            return 0
        end

        task.wait(Config.sellHoldBefore)
        local value = Sell.run(false, origin)
        task.wait(Config.sellHoldAfter)
        Movement.releaseHold()
        return value
    end)

    Movement.releaseHold()
    Sell.busy = false

    if not ok then
        error(sold)
    end

    return sold
end

function Sell.run(force, origin)
    if not force then
        if not Sell.enabled then
            Sell.diag("off", ("autosell %s: toggle off, sell skipped"):format(tostring(origin)))
            return 0
        end
        if not Sell.isFull() then
            return 0
        end
        if os.clock() - Sell.lastRun < Config.sellCooldown then
            return 0
        end
    end
    Sell.lastRun = os.clock()

    local remote = ReplicatedStorage:FindFirstChild(Config.sellRemote)
    if not remote then
        logWarn("sell remote not found")
        return 0
    end

    local selected = Sell.selectedSet()
    local sold = 0
    local used, capacity, source = Sell.usage()
    local nSelected = Sell.selectedCount()

    local candidates, units = 0, 0

    for _, name in ipairs(Sell.namesList or {}) do
        if selected[name] then
            local count = Sell.count(name)
            if count > 0 then
                candidates += 1
                units += count
            end
        end
    end

    logPrint(("sell run (%s) names=%d selected=%d with=%d units=%d used=%d/%d src=%s"):format(
        tostring(origin or (force and "manual") or "auto"),
        #(Sell.namesList or {}), nSelected, candidates, units,
        used, capacity, tostring(source)))

    if source ~= "client" then
        logWarn("sell: inventory source=" .. tostring(source) .. ", per-resource counts may be 0")
    end

    if nSelected == 0 then
        logWarn("autosell: no resources selected")
    elseif candidates == 0 then
        logWarn("autosell: selected resources have zero count")
    end

    for _, name in ipairs(Sell.namesList or {}) do
        if selected[name] then
            local count = Sell.count(name)
            if count > 0 then
                local ok, result = pcall(function()
                    return remote:InvokeServer(name, count)
                end)

                if not ok then
                    logWarn(("sell error %s: %s"):format(name, tostring(result)))
                elseif result == false then
                    -- The remote answered, so the name or the count is wrong.
                    logWarn(("sell refused %s x%d"):format(name, count))
                else
                    sold += count
                    logPrint(("sold %s x%d -> %s"):format(name, count, tostring(result)))
                end
            end
        end
    end

    return sold
end

-- "Sell now" button: forced run, works with a partially filled backpack, with
-- the Auto sell toggle off, and from inside the mine (it surfaces first).
function Sell.manual()
    local character = Character.get()
    Sell.busy = true

    local ok, sold = pcall(function()
        Sell.toSurface(character)
        Sell.holdForSale(character)
        task.wait(Config.sellHoldBefore)
        local value = Sell.run(true, "manual")
        task.wait(Config.sellHoldAfter)
        Movement.releaseHold()
        return value
    end)

    Movement.releaseHold()
    Sell.busy = false

    if not ok then
        error(sold)
    end

    return sold
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
-- Caller must run Loot.sync(true) first (Farm does it right before).
function Loot.collectAll(character)
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
                -- Root sits ~3.5 studs above the drop so the body is not embedded
                -- in the floor, which made the character tumble after the jump.
                Movement.jump(character, part.Position + Vector3.new(0, Config.teleportLift, 0))
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

-- Number of horizontal neighbours of `cell` that are liquid (Oil/Lava), and the
-- total checked. The block below is skipped, same as IsBlockBesideLiquid.
local function liquidNeighbours(mine, cell)
    local liquid, total = 0, 0

    for _, offset in pairs(blockOffsets) do
        if offset.Y ~= 1 then
            total += 1
            local neighbour = mine:FindFirstChild(vec3ToString(cell + offset))
            local info = neighbour and resourceInfo(typeOf(neighbour))

            if info and info.LiquidResource then
                liquid += 1
            end
        end
    end

    return liquid, total
end

-- Fully stuck in liquid: almost every horizontal neighbour is Oil/Lava.
local function stuckInLiquid(mine, cell)
    local liquid, total = liquidNeighbours(mine, cell)
    return total > 0 and liquid >= Config.liquidStuckCount
end

-- Liquid escape: the bot cannot dig the block under it and cannot step aside.
-- Look one block above the stuck cell, then walk a random horizontal direction
-- until a mineable block is found. Blocks at the liquid level and below are never
-- mined, only the one above the liquid. Teleport on top of it and let Farm dig
-- that block next tick.
local function escapeLiquid(character, root)
    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return false
    end

    local cell = Blocks.toBlock(root.Position)
    if not stuckInLiquid(mine, cell) then
        return false
    end

    local up = cell + Vector3.new(0, -1, 0)

    local directions = {
        Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
        Vector3.new(1, 0, 1), Vector3.new(1, 0, -1),
        Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1),
    }

    for index = #directions, 2, -1 do
        local swap = math.random(index)
        directions[index], directions[swap] = directions[swap], directions[index]
    end

    -- Distance outer, directions inner: take the nearest mineable block instead
    -- of the first direction that happens to hit far away.
    for distance = 1, Config.liquidSearchRange do
        for _, direction in ipairs(directions) do
            local target = up + direction * distance
            local block = mine:FindFirstChild(vec3ToString(target))

            if block and Mining.why(block) == nil then
                local stand = target + Vector3.new(0, -1, 0)

                if not mine:FindFirstChild(vec3ToString(stand)) then
                    logPrint(("liquid escape -> %s (%s)"):format(
                        vec3ToString(target), tostring(typeOf(block))))

                    Movement.jump(character, Blocks.standPoint(stand))
                    return true
                end
            end
        end
    end

    logWarn("liquid escape: no mineable block above the liquid")
    return false
end

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

    -- Selection-independent: escape may use any adjacent resource, selected or
    -- not. `dy` = 0 stays on the current layer, `dy = -1` moves one block UP
    -- (the floor below that cell is the current-layer side block). Never down.
    local function bestAt(radius, dy)
        local best, bestPrice

        for dx = -radius, radius do
            for dz = -radius, radius do
                if math.max(math.abs(dx), math.abs(dz)) == radius and not (dx == 0 and dz == 0) then
                    local stand = cell + Vector3.new(dx, dy, dz)

                    if not mine:FindFirstChild(vec3ToString(stand)) then
                        local floor = mine:FindFirstChild(vec3ToString(stand + Vector3.new(0, 1, 0)))

                        if floor and Mining.why(floor) == nil then
                            local price = Ores.price(typeOf(floor) or "")

                            if not best or price > bestPrice then
                                best, bestPrice = stand, price
                            end
                        end
                    end
                end
            end
        end

        return best
    end

    for radius = 1, Config.sideSearchRadius do
        local best = bestAt(radius, 0)
        local up = false

        if not best then
            best = bestAt(radius, -1)
            up = best ~= nil
        end

        if best then
            logPrint(("step aside r=%d %s-> %s"):format(
                radius, up and "up " or "", vec3ToString(best)))

            -- Cell centre, so Blocks.below() afterwards still points at the
            -- validated floor and not at a boundary-rounded neighbour.
            Movement.jump(character, Blocks.standPoint(best))
            return
        end
    end

    logWarn(("down-block undiggable, no side escape within %d"):format(
        Config.sideSearchRadius))
    task.wait(1)
end

local FarmMode = Mode.new("Farm", function(self)
    local character = Character.get()
    if not self.enabled then
        return
    end

    -- Auto sell owns the character while it travels to the surface.
    if Sell.busy then
        return
    end

    if not character.PrimaryPart then
        return
    end

    -- Too many server rejections in a row: leave the shaft and clear stale state.
    if Mining.resetRequested then
        Mining.resetRequested = false
        Mining.rejects = 0

        -- Clear cached block mapping and ore scan state before choosing a target.
        Blocks.calibrated = false
        Blocks.lastCalibrate = 0
        Blocks.offset = Vector3.zero
        Ores.clearCache()
        Blocks.calibrate()

        local point = Surface.resetPoint()

        if point then
            logWarn(("mining reset: teleport to %s, caches cleared"):format(
                tostring(point)))
            Movement.jump(character, point)
            Movement.waitLanded(character, Config.emptyMineWait)
        else
            logWarn("mining reset: no safe point inside the mine, staying put")
        end

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

    Blocks.calibrate()

    -- Empty field: nothing to dig and no ground under it. Raise once and anchor,
    -- otherwise every tick teleports up and falls back.
    local mineModel = workspace:FindFirstChild(Config.mineName)

    if mineModel and #mineModel:GetChildren() == 0 then
        local safe = Vector3.new(
            Config.fieldCenter.X,
            Config.fieldCenter.Y + Config.emptyMineLift,
            Config.fieldCenter.Z
        )

        if (safe - root.Position).Magnitude > 4 then
            Movement.jump(character, safe)
            logPrint("mine empty, raised above the field")
        end

        Movement.hold(character)
        task.wait(Config.emptyMineWait)
        return
    end

    Movement.releaseHold()

    -- 2. On the surface: move to the field centre first, then reuse the deepest pit.
    local cell = Blocks.toBlock(root.Position)

    if cell.Y < Config.surfaceDepth then
        if not Surface.atField(root.Position) then
            logPrint("surface: move to field centre")
            Movement.jump(character, Config.fieldCenter + Vector3.new(0, Config.teleportLift, 0))
            return
        end

        local pit = Surface.find(root.Position)

        if pit then
            if cell.X ~= pit.X or cell.Z ~= pit.Z then
                local mine = workspace:FindFirstChild(Config.mineName)
                local mouth = Vector3.new(pit.X, cell.Y, pit.Z)

                -- Only jump into a mouth that is really empty.
                if mine and not mine:FindFirstChild(vec3ToString(mouth)) then
                    Movement.jump(character, Blocks.worldOf(mouth) + Vector3.new(0, Config.teleportLift, 0))
                    return
                end
            else
                local below = Blocks.below(root.Position)

                if below then
                    if mine(below) then
                        Movement.waitLanded(character)
                    else
                        Ores.ignore(below)
                    end
                    return
                end

                Movement.waitLanded(character)
                return
            end
        end
    end

    local below = Blocks.below(root.Position)
    local belowReason = below and Mining.why(below)

    -- Liquid-adjacent (or otherwise blocked) floor: this block can never be
    -- broken, and mining anything below the current layer would only dig into
    -- the same liquid pocket. Ignore the ore selection and escape sideways/up.
    if belowReason == "liquid" or belowReason == "blocked" then
        logWarn(("floor blocked (%s), forcing side escape"):format(tostring(belowReason)))

        if escapeLiquid(character, root) then
            return
        end

        stepAside(character, root)
        return
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
    if not below then
        -- Fell into a liquid pocket with no floor: climb out one block up.
        if escapeLiquid(character, root) then
            return
        end

        Movement.waitLanded(character)
        return
    end

    if mine(below) then
        Movement.waitLanded(character)
        return
    end

    if below.Parent and Mining.why(below) then
        if escapeLiquid(character, root) then
            return
        end

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

    if Sell.busy then
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

    local savedMode = math.clamp(tonumber(Settings.get("mode", 1)) or 1, 1, #Modes.list)
    local savedEnabled = Settings.get("enabled", false) == true
    local savedInstant = Settings.get("instantMove", Config.instantMove) == true
    local savedTween = tonumber(Settings.get("tweenSpeed", Config.tweenSpeed)) or Config.tweenSpeed
    local savedVerbose = Settings.get("verboseLogs", Log.enabled) == true
    local savedNoRender = Settings.get("noRender", false) == true
    local savedSellEnabled = Settings.get("sellEnabled", Sell.enabled) == true

    Config.instantMove = savedInstant
    Config.tweenSpeed = savedTween
    Log.enabled = savedVerbose
    Sell.enabled = savedSellEnabled

    local main, _ = window:AddTab("Main", "назар прайм v2")

    local modePanel = main:AddSeperator("Mode")
    local enabled = savedEnabled

    local modeDropdown
    modeDropdown = modePanel:AddDropdown({
        title = "Category",
        options = { "Farm", "Mushrooms" },
        callback = function(index)
            Settings.set("mode", index)

            local mode = Modes.list[index]
            Modes.select(mode)
            if enabled and mode then
                Modes.enable(mode)
            end
        end,
    })

    modePanel:AddToggle({
        title = "Enabled",
        checked = savedEnabled,
        callback = function(state)
            enabled = state
            Settings.set("enabled", state)

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
        checked = savedInstant,
        callback = function(state)
            Config.instantMove = state
            Settings.set("instantMove", state)
        end,
    })

    movePanel:AddSlider({
        title = "Tween speed",
        values = { min = 20, max = 400, default = savedTween, round = 1 },
        callback = function(value)
            Config.tweenSpeed = value
            Settings.set("tweenSpeed", value)
        end,
    })

    local orePanel = main:AddSeperator("Farm ores")
    local names = Ores.names()
    local defaults = {}

    for index, name in ipairs(names) do
        table.insert(defaults, index)
    end

    local savedOres = Settings.indices("ores", defaults)
    local selection = orePanel:AddSelection({
        title = "Ores",
        options = names,
        default = savedOres,
    })

    selection.setSelected(savedOres)
    Ores.bindSelection(selection, names)

    local sellTab = window:AddTab("Auto sell", "sell resources when the backpack is full")
    local sellPanel = sellTab:AddSeperator("Auto sell")

    sellPanel:AddToggle({
        title = "Enabled",
        desc = "sell selected resources when the backpack is full",
        checked = savedSellEnabled,
        callback = function(state)
            Sell.enabled = state
            Settings.set("sellEnabled", state)
            logPrint("autosell toggle " .. (state and "on" or "off"))
        end,
    })

    local sellNames = Sell.names()
    local savedSell = Settings.indices("sellSelected", {})
    local sellSelection = sellPanel:AddSelection({
        title = "Resources to sell",
        options = sellNames,
        default = savedSell,
    })

    sellSelection.setSelected(savedSell)
    Sell.bindSelection(sellSelection, sellNames)

    sellPanel:AddButton({
        title = "Sell now",
        callback = function()
            logPrint("manual sell total " .. Sell.manual())
        end,
    })

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
        checked = savedVerbose,
        callback = function(state)
            Log.enabled = state
            Settings.set("verboseLogs", state)
        end,
    })

    logPanel:AddToggle({
        title = "Disable 3D render",
        desc = "RunService:Set3dRenderingEnabled(false)",
        checked = savedNoRender,
        callback = function(state)
            Settings.set("noRender", state)

            pcall(function()
                RunService:Set3dRenderingEnabled(not state)
            end)
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

                -- Selections have no change callback in uilib: persist them here.
                -- Settings.persist skips the write when the JSON is unchanged.
                Settings.set("ores", selection.getSelected() or {})
                Settings.set("sellSelected", sellSelection.getSelected() or {})
            end)

            if not ok then
                break
            end
        end
    end)

    modeDropdown.setSelected(savedMode)

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

-- Restore the saved render state before the UI is built.
if Settings.get("noRender", false) == true then
    pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
end

LogView.create()

local ok, window = pcall(Ui.create)
if ok and window then
    Ui.toggleButton(window)
else
    warn("[main] ui failed: " .. tostring(window))
end

-- Auto sell must work even when no mode is running: check every second.
task.spawn(function()
    while true do
        local ok, err = pcall(Sell.try, "watch")
        if not ok then
            logWarn("autosell watch error: " .. tostring(err))
        end
        task.wait(1)
    end
end)

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

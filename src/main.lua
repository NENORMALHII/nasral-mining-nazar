local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    loopDelay = 0.05,
    logRenderInterval = 0.25,

    instantMove = false,
    tweenSpeed = 120,
    moveStopDistance = 2.5,

    mineWaitForServer = 1.5,

    mineSafetyBase = 0.05,
    mineSafetyPingMult = 0.5,
    mineJitterMin = 0.02,
    mineJitterMax = 0.07,
    minePreSwingMin = 0.02,
    minePreSwingMax = 0.06,
    minePenaltyStep = 0.12,
    minePenaltyMax = 0.5,
    minePenaltyDecay = 0.02,
    minePenaltyDecayEvery = 3,
    mineRejectGrace = 0.6,

    mushroomDelay = 0.35,
    mushroomIgnore = 5,

    mineName = "Mine",
    oreRange = 21,

    rejoinDelay = 2,
    rejoinAttachTries = 60,
    antiAfkInterval = 240,

    autoloadEvent = "LoadGameEvent",
    autoloadLoadedAttr = "FullyLoaded",
    autoloadProfileAttr = "Profile",
    autoloadDelay = 1,
    autoloadTries = 10,

    mineReachMargin = 4,
    moveCooldown = 0.5,
    maxRejects = 5,

    -- Escape planner (Dijkstra over block cells).
    planRadius = 7,
    planClearance = 3,
    planHop = 0.3,
    planUpCost = 4,
    planMaxNodes = 4000,
    planRetry = 5,

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
    moveBuffer = 0.1,
    moveSettleTime = 0.25,
    moveSettleEpsilon = 0.2,

    lootDwell = 0.12,
    lootOwnerDelay = 0.2,
    oreScanTtl = 4,
    oreScanMove = 3.5,
    slowScanWarn = 0.008,
    frameWarn = 0.12,

    sellRemote = "SellResourceFunction",
    sellCapacity = 200,
    sellCooldown = 1,
    sellAnchor = Vector3.new(78, 8013, -219),
    surfaceRemote = "TeleportToSurfaceFunction",
    surfaceTeleportWait = 0.5,
    sellSurfaceWait = 2,
    sellItemDelay = 0.1,
    sellHoldBefore = 2,
    sellHoldAfter = 1,

    -- Forge (docs/game/protocol/forge.md). Server checks are unverified: the
    -- client protocol and the ore table are confirmed, nothing else.
    forgeName = "Forge",
    forgeUpdateRemote = "ForgeUpdateEvent",
    forgeToggleRemote = "ToggleForgeEvent",
    forgeOpenWait = 1,
    forgeStateWait = 1.5,
    forgeActionWait = 0.35,
    forgeOpenBuffer = 0.2,
    forgeSettle = 0.3,
    forgeMaxFuelUnits = 10,

    blockEvent = "BlockEvent",
    minedEvent = "BlockMinedEvent",
    pickaxeRemote = "UpdatePickaxe",
    defaultMineTime = 4,
}

---------------------------------------------------------------------------
-- Settings (executor standard: writefile/readfile/isfile/makefolder + JSON)
--
-- A typed registry: every saved option is one `Settings.define` entry, and the
-- UI only calls `Settings.read(key)` / `Settings.write(key, value)`. Adding an
-- option never touches the file format code.
--
-- kinds:
--   bool   - true/false
--   number - number, clamped to `min`/`max`, optional `round` (1 = integer)
--   names  - array of resource names (selections); `default = "all"` means every
--            entry of the current option list
--
-- `apply` is the restore hook: `Settings.restore()` calls it once per key before
-- the UI is built, so no option needs its own bootstrap block.
---------------------------------------------------------------------------

local Settings = {
    path = "nm2/settings.json",
    fallbackPath = "nm2_settings.json",
    data = {},
    loaded = false,
    defs = {},
    bound = {},
}

-- `isfile` is optional: many executors only ship `readfile`, which errors on a
-- missing file, so the read itself is the existence check.
local function settingsReady()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function readText(path)
    local ok, text = pcall(readfile, path)

    if ok and type(text) == "string" and text ~= "" then
        return text
    end

    return nil
end

local function fileExists(path)
    if type(isfile) ~= "function" then
        return true
    end

    local ok, exists = pcall(isfile, path)
    return ok and exists
end

function Settings.load()
    if Settings.loaded then
        return Settings.data
    end

    Settings.loaded = true

    if not settingsReady() then
        return Settings.data
    end

    local text

    if fileExists(Settings.path) then
        text = readText(Settings.path)
    end

    if not text and fileExists(Settings.fallbackPath) then
        text = readText(Settings.fallbackPath)
    end

    if not text then
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

function Settings.persist()
    if not settingsReady() then
        return
    end

    -- Only registered keys are written: a stale `enabled`/`noRender` from an old
    -- build is dropped instead of lingering in the file as if it were saved.
    local snapshot = {}

    for key in pairs(Settings.defs) do
        local value = Settings.data[key]

        if value ~= nil then
            snapshot[key] = value
        end
    end

    local okEncode, text = pcall(function()
        return HttpService:JSONEncode(snapshot)
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

---------------------------------------------------------------------------
-- Typed registry
---------------------------------------------------------------------------

local normalizers = {}

function normalizers.bool(spec, value)
    return value == true
end

function normalizers.number(spec, value)
    local number = tonumber(value)

    if not number then
        return spec.default
    end

    if spec.min then
        number = math.max(spec.min, number)
    end

    if spec.max then
        number = math.min(spec.max, number)
    end

    if spec.round then
        number = math.floor(number * spec.round + 0.5) / spec.round
    end

    return number
end

function normalizers.names(spec, value)
    local out = {}

    if type(value) ~= "table" then
        return out
    end

    for _, name in ipairs(value) do
        if type(name) == "string" then
            table.insert(out, name)
        end
    end

    return out
end

function Settings.define(key, spec)
    spec.key = key
    spec.kind = spec.kind or "bool"
    Settings.defs[key] = spec
    return spec
end

function Settings.normalize(key, value)
    local spec = Settings.defs[key]
    if not spec then
        return value
    end

    local normalize = normalizers[spec.kind] or normalizers.bool
    return normalize(spec, value)
end

-- Value used when the file has no entry. `"all"`/`"none"` selections resolve to
-- an empty list here: the concrete entries are the current option list, which is
-- only known by `Settings.selection`.
function Settings.fallback(key)
    local spec = Settings.defs[key]
    if not spec then
        return nil
    end

    if spec.kind == "names" then
        return {}
    end

    return spec.default
end

function Settings.read(key)
    Settings.load()

    local value = Settings.data[key]

    if value == nil then
        return Settings.fallback(key)
    end

    return Settings.normalize(key, value)
end

function Settings.write(key, value)
    Settings.load()

    local normalized = Settings.normalize(key, value)
    Settings.data[key] = normalized
    Settings.persist()

    local spec = Settings.defs[key]

    if spec and spec.apply then
        pcall(spec.apply, normalized)
    end

    return normalized
end

-- Restore every `apply` hook before the UI exists.
function Settings.restore()
    for key, spec in pairs(Settings.defs) do
        if spec.apply then
            pcall(spec.apply, Settings.read(key))
        end
    end
end

---------------------------------------------------------------------------
-- Selections (widgets work with indexes, the file stores resource names)
---------------------------------------------------------------------------

function Settings.indices(key, fallback)
    local value = Settings.load()[key]

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

-- Saved indexes were written against an older resource table: drop the ones that
-- no longer exist instead of restoring a selection that maps to nothing.
function Settings.clampIndices(list, count)
    local out = {}

    for _, index in ipairs(list) do
        index = math.floor(tonumber(index) or 0)

        if index >= 1 and index <= count then
            table.insert(out, index)
        end
    end

    return out
end

-- Stored names -> indexes in the current option list.
function Settings.indexList(names, saved)
    if type(saved) ~= "table" then
        return {}
    end

    local positions = {}

    for index, name in ipairs(names) do
        positions[name] = index
    end

    local indexes = {}

    for _, name in ipairs(saved) do
        local index = type(name) == "string" and positions[name]

        if index then
            table.insert(indexes, index)
        end
    end

    return indexes
end

-- Widget indexes -> names for saving.
function Settings.nameList(names, indexes)
    local out = {}

    for _, index in ipairs(indexes or {}) do
        local name = names[index]

        if name then
            table.insert(out, name)
        end
    end

    return out
end

function Settings.defaultIndices(key, names)
    local spec = Settings.defs[key]

    if spec and spec.default == "all" then
        local all = {}

        for index = 1, #names do
            table.insert(all, index)
        end

        return all
    end

    return {}
end

-- Index list for a selection widget.
-- New format: names under `key`. Old format: indexes under `legacyKey`.
-- If a saved list exists but nothing matches any more, the option default wins.
function Settings.selection(key, legacyKey, names)
    local fallback = Settings.defaultIndices(key, names)
    local saved = Settings.load()[key]

    if type(saved) == "table" then
        local indexes = Settings.indexList(names, saved)

        if #indexes == 0 and #saved > 0 then
            return fallback
        end

        return indexes
    end

    local legacy = legacyKey and Settings.indices(legacyKey, nil)

    if legacy then
        local indexes = Settings.clampIndices(legacy, #names)

        if #indexes == 0 and #legacy > 0 then
            return fallback
        end

        return indexes
    end

    return fallback
end

-- Register a selection widget for the polling writer. uilib has no change
-- callback, so `Settings.flushSelections` (called from a timer) saves whatever
-- the widget currently holds; `Settings.persist` skips unchanged JSON.
function Settings.bindSelection(key, names, widget)
    table.insert(Settings.bound, {
        key = key,
        names = names,
        widget = widget,
        version = widget.getVersion and widget.getVersion() or nil,
    })
end

function Settings.flushSelections()
    Settings.load()

    for _, entry in ipairs(Settings.bound) do
        local version = entry.widget.getVersion and entry.widget.getVersion() or nil

        -- Nothing toggled since the last flush: skip the widget walk and the
        -- JSON encode. Four bound lists used to re-save on every timer tick.
        if version == nil or version ~= entry.version then
            entry.version = version

            local indexes = entry.widget.getSelected()

            if indexes then
                local names = Settings.nameList(entry.names, indexes)
                local saved = Settings.data[entry.key]

                if type(saved) ~= "table" or #saved ~= #names then
                    Settings.write(entry.key, names)
                else
                    for index = 1, #names do
                        if saved[index] ~= names[index] then
                            Settings.write(entry.key, names)
                            break
                        end
                    end
                end
            end
        end
    end
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
    dirty = false,
}

local function joinArgs(...)
    local parts = {}

    for index = 1, select("#", ...) do
        table.insert(parts, tostring(select(index, ...)))
    end

    return table.concat(parts, " ")
end

-- `os.date` per line allocates; the log panel only shows seconds, so one
-- formatting pass per second is enough.
local function clockText()
    local second = os.time()

    if Log.clockSecond ~= second then
        Log.clockSecond = second
        Log.clockText = os.date("%H:%M:%S", second)
    end

    return Log.clockText
end

-- Rendering is deferred: `pushLog` only appends and sets a flag, so a burst of
-- lines (one per block) cannot force a TextLabel relayout in the mining path.
-- `Log.flush` runs on its own timer from the bootstrap block.
local function pushLog(text)
    table.insert(Log.lines, clockText() .. "  " .. text)

    while #Log.lines > Log.maxLines do
        table.remove(Log.lines, 1)
    end

    Log.dirty = true
end

function Log.flush()
    if not Log.dirty then
        return
    end

    Log.dirty = false

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
-- Log view state
---------------------------------------------------------------------------
--
-- Declared early so `Ui.create`'s "Logs window" toggle can reference it; the
-- window itself is built in `LogView.create` once the UI helpers exist.

local LogView = {
    enabled = true,
    window = nil,
    gui = nil,
    main = nil,
    scroll = nil,
    label = nil,
    button = nil,
    collapsed = false,
    width = 420,
    height = 176,
}

---------------------------------------------------------------------------
-- Scheduler (one timer thread for periodic jobs)
---------------------------------------------------------------------------

-- The log flush, settings flush, sell watcher and stats readout each used to
-- own a `while true do task.wait(x) end` thread. With 0.25/0.5/1/3 s periods
-- those wakeups drift onto the same frame, so one frame did all four and the
-- next did nothing. One loop with per-job deadlines spreads them out and keeps
-- the same intervals; the start phase offsets them by a frame or two.
local Scheduler = {
    jobs = {},
    started = false,
}

function Scheduler.every(interval, fn)
    table.insert(Scheduler.jobs, {
        every = interval,
        fn = fn,
        next = os.clock() + interval + #Scheduler.jobs * 0.13,
    })
end

function Scheduler.start()
    if Scheduler.started then
        return
    end

    Scheduler.started = true

    task.spawn(function()
        while true do
            local now = os.clock()

            for _, job in ipairs(Scheduler.jobs) do
                if now >= job.next then
                    job.next = now + job.every

                    local ok, err = pcall(job.fn)
                    if not ok then
                        logWarn("scheduler: " .. tostring(err))
                    end
                end
            end

            task.wait(0.05)
        end
    end)
end

---------------------------------------------------------------------------
-- Frame watchdog
---------------------------------------------------------------------------
--
-- A stall is visible as a long gap between Heartbeats. `Watchdog.mark` is set by
-- the expensive non-yielding operations (ore scan, plan build, liquid set,
-- block index); the next slow frame reports which one preceded it, so a frame
-- drop can be attributed instead of guessed.

local Watchdog = { label = "startup", last = os.clock() }

function Watchdog.mark(label)
    Watchdog.label = label
end

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    local delta = now - Watchdog.last
    Watchdog.last = now

    if delta >= Config.frameWarn then
        logWarn(("frame %.0f ms after %s"):format(delta * 1000, Watchdog.label))
    end
end)

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

-- Liquid neighbours: every block offset except the one deeper (`DOWN` is
-- `(0, 1, 0)`). A fixed array keeps the per-block check off `pairs`.
local liquidOffsets = {}

for _, offset in pairs(blockOffsets) do
    if offset.Y ~= 1 then
        table.insert(liquidOffsets, offset)
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function xyzToString(x, y, z)
    return ("%d,%d,%d"):format(x, y, z)
end

local function vec3ToString(position)
    return xyzToString(position.X, position.Y, position.Z)
end

-- `Type` is a child StringValue that does not change for a live block, but it
-- was looked up on every validity check, ore-scan candidate and planner edge.
-- Weak keys keep removed blocks out of the cache.
local typeCache = setmetatable({}, { __mode = "k" })

local function typeOf(block)
    local cached = typeCache[block]

    if cached ~= nil then
        return cached or nil
    end

    local typeValue = block:FindFirstChild("Type")
    local name = typeValue and typeValue.Value or block:GetAttribute("Resource")

    typeCache[block] = name or false
    return name
end

-- The player's world id is read by every validity check and by the liquid
-- rebuild. One cached string, refreshed only when the attribute changes.
local playerWorldValue

local function playerWorld()
    if playerWorldValue ~= nil then
        return playerWorldValue
    end

    local player = Players.LocalPlayer
    if not player then
        return nil
    end

    playerWorldValue = tostring(player:GetAttribute(Game.attrWorldId))

    player:GetAttributeChangedSignal(Game.attrWorldId):Connect(function()
        playerWorldValue = tostring(player:GetAttribute(Game.attrWorldId))
    end)

    return playerWorldValue
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
            local started = os.clock()
            local ok, err = pcall(self.step, self)
            if not ok then
                logWarn(self.name .. " error: " .. tostring(err))
            end

            -- A step that mined/was teleported already burned its time: do not
            -- add another full `loopDelay` on top. Only idle ticks sleep.
            local spent = os.clock() - started

            if spent < Config.loopDelay then
                task.wait(Config.loopDelay - spent)
            else
                task.wait()
            end
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

    -- CharacterAdded never fires for a character that already exists, and at
    -- auto-start the model can be present before its PrimaryPart replicates.
    while not character or not character.PrimaryPart do
        task.wait(0.2)
        character = player.Character
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

-- Direct assignment: a valid BasePart never errors on `Anchored`, so the old
-- `pcall(function() ... end)` allocated a closure on every hold/release (twice
-- per block) for nothing.
local function safeAnchor(root, state)
    if root and root.Parent then
        root.Anchored = state
    end
end

function Movement.release()
    local tween = Movement.tween

    if tween then
        pcall(tween.Cancel, tween)
        Movement.tween = nil
    end

    -- Kill leftover velocity before the root is unanchored, otherwise the
    -- character keeps tween momentum and tumbles on landing.
    local root = Movement.root or Movement.holdRoot

    if root and root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
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

-- True while a jump owns the character. Time-bounded: if a movement thread
-- errors out after setting the flag, the flag must not block selling forever
-- (a tween is capped at 5 s plus the settle buffer).
function Movement.moving()
    return Movement.busy == true and os.clock() - (Movement.busyAt or 0) < 8
end

function Movement.settle(character)
    local root = character and character.PrimaryPart
    if not root then
        return
    end

    local deadline = os.clock() + Config.moveSettleTime
    local epsilonSq = Config.moveSettleEpsilon * Config.moveSettleEpsilon
    local last = root.Position
    local stable = 0

    while os.clock() < deadline do
        task.wait()

        local position = root.Position
        local dx = position.X - last.X
        local dy = position.Y - last.Y
        local dz = position.Z - last.Z

        if dx * dx + dy * dy + dz * dz <= epsilonSq then
            stable += 1
        else
            stable = 0
        end

        last = position

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
        task.wait()
    end
end

function Movement.to(character, position, speed)
    local root = character.PrimaryPart
    if not root then
        return
    end

    -- A jump owns the character until it settles: `Sell.try` checks this so a
    -- surface teleport cannot start in the middle of a tween.
    Movement.busy = true
    Movement.busyAt = os.clock()
    Movement.release()

    if (position - root.Position).Magnitude < Config.moveStopDistance then
        Movement.settle(character)
        Movement.busy = false
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
        Movement.busy = false
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
        task.wait(0.05)
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
    Movement.busy = false
end

-- Single movement path for every teleport in the script (loot, surface, pits,
-- plan steps, auto sell). `Movement.to` decides how to move:
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
Blocks.modelCache = nil

-- Single cached handle to `Workspace.Mine`. The mining loop asked for it several
-- times per tick (calibrate, below, liquid set, ore scan, plan, farm reset);
-- a cached instance removes those name lookups. Re-resolved only when the
-- cached instance leaves the DataModel.
function Blocks.model()
    local mine = Blocks.modelCache

    if mine and mine.Parent then
        return mine
    end

    mine = workspace:FindFirstChild(Config.mineName)
    Blocks.modelCache = mine
    return mine
end

-- Roblox `FindFirstChild` walks the container's children; with tens of thousands
-- of blocks one 343-cell ore scan (or one plan step) becomes millions of name
-- comparisons and drops frames. A name -> instance index, kept in sync through
-- ChildAdded/ChildRemoved, turns every cell lookup into one hash hit.
local blockIndex = { mine = nil, map = {}, state = { count = 0 } }

local function indexBind(mine)
    Watchdog.mark("block index")

    -- Built in locals and published only after the fill: a half-built map must
    -- never be visible to another coroutine. Handlers are connected first so a
    -- block added while the children list is being read is kept, and the count
    -- stays exact for the same reason.
    local map = {}
    local state = { count = 0 }
    local started = os.clock()

    mine.ChildAdded:Connect(function(child)
        if map[child.Name] == nil then
            state.count += 1
        end
        map[child.Name] = child
    end)

    mine.ChildRemoved:Connect(function(child)
        if map[child.Name] == child then
            map[child.Name] = nil
            state.count -= 1
        end
    end)

    local children = mine:GetChildren()

    -- No yield inside the fill: the loop is plain table assignments (cheaper
    -- than the attribute passes), and publishing the map atomically means no
    -- other coroutine can observe a half-built index.
    for index = 1, #children do
        local block = children[index]

        if map[block.Name] == nil then
            state.count += 1
        end

        map[block.Name] = block
    end

    blockIndex.map = map
    blockIndex.state = state
    blockIndex.mine = mine

    logPrint(("block index %d blocks %.0f ms"):format(
        #children, (os.clock() - started) * 1000))
end

-- Block at a cell name (`"x,y,z"`), or nil. The first call builds the index.
function Blocks.at(name)
    local map = Blocks.map()
    return map and map[name]
end

-- Number of blocks in the index. Same source as `Blocks.at`, so an empty-mine
-- check is one field read instead of a `FindFirstChildWhichIsA` child walk.
function Blocks.count()
    if not Blocks.map() then
        return 0
    end

    return blockIndex.state.count
end

-- Raw index for tight loops (ore scan, planner): resolve once, hash many times.
function Blocks.map()
    local mine = Blocks.model()

    if not mine then
        return nil
    end

    if blockIndex.mine ~= mine then
        indexBind(mine)
    end

    return blockIndex.map
end

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
    Watchdog.mark("calibrate")

    local mine = Blocks.model()
    if not mine then
        return
    end

    local firstOffset, firstDistance
    local secondOffset, secondDistance
    local index = 0

    for _, block in ipairs(mine:GetChildren()) do
        local minePosition = block:GetAttribute(Game.attrMinePosition)

        if minePosition then
            local offset = minePosition - rawBlock(block.Position)
            local px = block.Position.X - Config.fieldCenter.X
            local py = block.Position.Y - Config.fieldCenter.Y
            local pz = block.Position.Z - Config.fieldCenter.Z
            local distance = px * px + py * py + pz * pz

            if not firstDistance or distance < firstDistance then
                secondOffset, secondDistance = firstOffset, firstDistance
                firstOffset, firstDistance = offset, distance
            elseif not secondDistance or distance < secondDistance then
                secondOffset, secondDistance = offset, distance
            end
        end

        -- Tens of thousands of children: yield in chunks so the field scan does
        -- not stall the frame for the whole pass.
        index = index + 1
        if index % 4000 == 0 then
            task.wait()
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
    -- `Blocks.at` already resolves the model and map; the extra `model` check
    -- here only added a function call to the per-tick path.
    local cell = Blocks.toBlock(worldPosition)

    return Blocks.at(xyzToString(cell.X, cell.Y + 1, cell.Z))
end

-- Cached set of liquid (Oil/Lava) block names, rebuilt on world change or after
-- a reset. One pass over the mine turns every "is this block beside liquid"
-- question into a handful of hash lookups instead of `FindFirstChild` calls.
Blocks.liquids = nil
Blocks.liquidsWorld = nil
Blocks.liquidStamp = 0

function Blocks.invalidateLiquids()
    Blocks.liquids = nil
    Blocks.liquidsWorld = nil
    Blocks.liquidStamp = (Blocks.liquidStamp or 0) + 1
end

function Blocks.liquidSet()
    Watchdog.mark("liquid set")
    local world = playerWorld()

    if Blocks.liquids and Blocks.liquidsWorld == world then
        return Blocks.liquids
    end

    local mine = Blocks.model()
    if not mine then
        return nil
    end

    local set = {}

    for index, block in ipairs(mine:GetChildren()) do
        local position = block:GetAttribute(Game.attrMinePosition)
        local info = position and resourceInfo(typeOf(block))

        if info and info.LiquidResource then
            set[vec3ToString(position)] = true
        end

        if index % 4000 == 0 then
            task.wait()
        end
    end

    Blocks.liquids = set
    Blocks.liquidsWorld = world
    Blocks.liquidStamp = (Blocks.liquidStamp or 0) + 1
    return set
end

-- True when any neighbour of `cell` except the one below is liquid: such a block
-- cannot be broken. `blockOffsets.DOWN` is `(0, 1, 0)`, i.e. deeper.
-- `liquids` lets the planner resolve the set once per build instead of once per
-- candidate block.
function Blocks.liquidNeighbour(cell, liquids)
    liquids = liquids or Blocks.liquidSet()
    if not liquids then
        return false
    end

    for _, offset in ipairs(liquidOffsets) do
        local key = xyzToString(
            cell.X + offset.X,
            cell.Y + offset.Y,
            cell.Z + offset.Z
        )

        if liquids[key] then
            return true
        end
    end

    return false
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
        if Blocks.at(xyzToString(x, topY + depth, z)) then
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
    local dirs = Surface.dirs

    for index = 1, #dirs do
        local dir = dirs[index]

        for step = 1, Config.surfaceProbeDepth do
            if Blocks.at(xyzToString(
                cell.X + dir.X * step,
                floorY,
                cell.Z + dir.Z * step
            )) then
                hits += 1
                break
            end
        end

        -- Even if every remaining ray hits, the cell cannot reach the minimum.
        -- Stopping here is the same verdict with fewer hashes.
        if hits + (#dirs - index) < Config.surfaceStarMin then
            return hits
        end
    end

    return hits
end

-- A pit cell is safe only when it is empty, has a solid floor and all 8 star
-- rays hit mine blocks. This rejects map edges, floating columns and open holes
-- that are not surrounded by generated terrain.
function Surface.safe(mine, cell, depth)
    if Blocks.at(xyzToString(cell.X, cell.Y, cell.Z)) then
        return false
    end

    local floorY = cell.Y + depth

    if not Blocks.at(xyzToString(cell.X, floorY, cell.Z)) then
        return false
    end

    local hits = Surface.star(mine, cell, floorY)
    return hits >= Config.surfaceStarMin, hits
end

local function pitOrder(a, b)
    if a.depth ~= b.depth then
        return a.depth > b.depth
    end
    return a.distance < b.distance
end

local function scanPit(mine, center, topY, minDepth)
    Watchdog.mark("surface scan")
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

    table.sort(candidates, pitOrder)

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

-- The scan is a full 13x13x10 cube pass and ran on every surface tick until a
-- pit was chosen. The cell, layer and minimum depth fully determine the answer,
-- so it is kept for a second (`Surface.resetPoint` uses a different layer).
local pitCache = { done = false, time = 0, value = nil }

function Surface.scan(mine, center, topY, minDepth)
    local now = os.clock()

    if pitCache.done
        and now - pitCache.time < 1
        and pitCache.x == center.X
        and pitCache.y == center.Y
        and pitCache.z == center.Z
        and pitCache.topY == topY
        and pitCache.minDepth == minDepth then
        return pitCache.value
    end

    local value = scanPit(mine, center, topY, minDepth)

    pitCache.done = true
    pitCache.time = now
    pitCache.x, pitCache.y, pitCache.z = center.X, center.Y, center.Z
    pitCache.topY = topY
    pitCache.minDepth = minDepth
    pitCache.value = value

    return value
end

-- Cell to stand in before dropping down, on the player's own layer. `cell` is
-- the caller's already-computed block cell, so it is not rebuilt.
function Surface.find(position, cell)
    local mine = Blocks.model()
    if not mine then
        return nil
    end

    Blocks.calibrate()

    cell = cell or Blocks.toBlock(position)
    return Surface.scan(mine, cell, cell.Y, Config.surfaceMinDepth)
end

-- Reset target after a rejection streak: the same scan on the fixed surface
-- layer around the field centre, so it can never leave the generated mine.
function Surface.resetPoint()
    local mine = Blocks.model()
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
    successes = 0,
    penalty = 0,
    resetRequested = false,
}

local BLOCKED = { Oil = true, Lava = true, Grass = true, Void = true }

-- Per-block liquid answer, invalidated by `Blocks.liquidStamp`.
local liquidCache = setmetatable({}, { __mode = "k" })

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

    local cached = detectCache[pickaxe]
    local now = os.clock()

    -- Tool attribute upgrades land mid-session, but not every block: rebuilding
    -- the signature on every mine is wasted work. One check per second is enough
    -- to notice a pickaxe change before it matters.
    if cached and now - (cached.checkedAt or 0) < 1 then
        return cached
    end

    local sig = signature(pickaxe)

    if cached and cached.signature == sig then
        cached.checkedAt = now
        return cached
    end

    local info, pickaxeName, pickaxeSource = resolvePickaxe(pickaxe)
    local handleName, handleSource = resolveHandle(pickaxe)

    local result = {
        signature = sig,
        checkedAt = now,
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
    -- Fast path: the same pickaxe is already equipped and rebound. Avoids the
    -- backpack scan, humanoid lookup and signature check on every block.
    local equipped = character:FindFirstChildWhichIsA("Tool")

    if equipped and equipped == Mining.pickaxe and Mining.rebound and equipped.Parent == character then
        return equipped
    end

    local pickaxe = equipped and isPickaxe(equipped) and equipped or Character.getPickaxe(character)
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
        Mining.reachCache = nil
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
        Mining.refreshReach()

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

-- `ToolSpeedModifier` changes only when the tool or an upgrade changes, but
-- `mineTime` reads it once per planner edge (thousands per build). Cached and
-- refreshed on change; the formula itself keeps the original operation order.
local toolSpeedValue

local function toolSpeed()
    if toolSpeedValue ~= nil then
        return toolSpeedValue
    end

    local player = Players.LocalPlayer
    if not player then
        return 0
    end

    toolSpeedValue = player:GetAttribute("ToolSpeedModifier") or 0

    player:GetAttributeChangedSignal("ToolSpeedModifier"):Connect(function()
        toolSpeedValue = player:GetAttribute("ToolSpeedModifier") or 0
    end)

    return toolSpeedValue
end

function Mining.mineTime(block)
    local info = resourceInfo(typeOf(block))
    local modifier = info and info.MineTimeModifier or 1
    local speed = toolSpeed()

    return math.max(Mining.baseMineTime * ((100 - speed) / 100) * modifier, 0.1)
end

function Mining.waitTime(block)
    local ping = Ping.sample()

    local baseMine = Mining.mineTime(block)
    local jitter = math.random() * (Config.mineJitterMax - Config.mineJitterMin) + Config.mineJitterMin

    -- Adaptive buffer: the base margin is small, `Mining.penalty` grows only
    -- after a server rejection and decays after successful breaks. A rejected
    -- block costs `mineRejectGrace` plus a retry, so one reject is more
    -- expensive than the margin lost across many fast breaks.
    local safety = Config.mineSafetyBase + ping * Config.mineSafetyPingMult + Mining.penalty

    return baseMine + safety + jitter
end

function Mining.preSwingDelay()
    return math.random() * (Config.minePreSwingMax - Config.minePreSwingMin) + Config.minePreSwingMin
end

-- Server accepted the break. Reset the streak and shrink the extra margin.
function Mining.confirm()
    Mining.rejects = 0
    Mining.successes = Mining.successes + 1

    if Mining.penalty > 0 and Mining.successes % Config.minePenaltyDecayEvery == 0 then
        Mining.penalty = math.max(0, Mining.penalty - Config.minePenaltyDecay)
    end
end

-- Server rejected the break (block still there after BlockMinedEvent). Grow the
-- margin so the retry cannot undershoot the same way again.
function Mining.punish()
    Mining.successes = 0
    Mining.penalty = math.min(Config.minePenaltyMax, Mining.penalty + Config.minePenaltyStep)
end

function Mining.maxDistance()
    local maxDistance = Mining.pickaxe and Mining.pickaxe:FindFirstChild("MaxDistance")
    return maxDistance and maxDistance.Value or 25
end

function Mining.besideLiquid(block, liquids)
    local position = block:GetAttribute(Game.attrMinePosition)
    if not position then
        return false
    end

    -- The liquid set is static per world, so the 6 neighbour lookups (each one
    -- a formatted string) are worth caching per block. The planner asks this
    -- question thousands of times per plan and passes its resolved set in.
    local stamp = Blocks.liquidStamp
    local cached = liquidCache[block]

    if cached and cached.stamp == stamp then
        return cached.value
    end

    local value = Blocks.liquidNeighbour(position, liquids)
    liquidCache[block] = { stamp = stamp, value = value }
    return value
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
    if tostring(world) ~= playerWorld() then
        return "world"
    end

    local dug = block:FindFirstChild("Dug")
    if dug and dug.Value ~= "" and dug.Value ~= Players.LocalPlayer.Name then
        return "dug"
    end

    return nil
end

-- Same block is asked repeatedly per tick (`FarmMode` floor check, `Mining.mine`,
-- the planner). Valid reasons only change when the world/liquid set changes or
-- another player claims the block, so a short per-block cache removes the
-- repeated attribute reads.
local whyCache = setmetatable({}, { __mode = "k" })

function Mining.why(block)
    local stamp = Blocks.liquidStamp
    local cached = whyCache[block]
    local now = os.clock()

    if cached and cached.stamp == stamp and now - cached.at < 0.3 then
        return cached.reason
    end

    local reason = Mining.valid(block)

    if not reason and Mining.besideLiquid(block) then
        reason = "liquid"
    end

    whyCache[block] = { stamp = stamp, at = now, reason = reason }
    return reason
end

-- Reach is fixed for the equipped pickaxe; reading `Pick.MaxDistance` through
-- `FindFirstChild` on every range check was wasted work.
function Mining.refreshReach()
    Mining.reachCache = math.max(8, Mining.maxDistance() - Config.mineReachMargin)
    return Mining.reachCache
end

function Mining.reach()
    return Mining.reachCache or Mining.refreshReach()
end

function Mining.inRange(character, block)
    local root = character.PrimaryPart
    if not root then
        return false
    end

    local reach = Mining.reach()
    local position = block.Position
    local dx = position.X - root.Position.X
    local dy = position.Y - root.Position.Y
    local dz = position.Z - root.Position.Z

    return dx * dx + dy * dy + dz * dz <= reach * reach
end

-- The two mining remotes never move; cache them instead of two
-- `FindFirstChild` calls per block.
function Mining.remotes()
    local blockEvent = Mining.blockEventRemote
    local minedEvent = Mining.minedEventRemote

    if blockEvent and blockEvent.Parent and minedEvent and minedEvent.Parent then
        return blockEvent, minedEvent
    end

    Mining.blockEventRemote = ReplicatedStorage:FindFirstChild(Config.blockEvent)
    Mining.minedEventRemote = ReplicatedStorage:FindFirstChild(Config.minedEvent)
    return Mining.blockEventRemote, Mining.minedEventRemote
end

function Mining.mine(character, block)
    Watchdog.mark("mine")
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
    local blockEvent, minedEvent = Mining.remotes()
    if not position or not blockEvent or not minedEvent then
        logWarn("remotes not found")
        return false
    end

    local waitTime = Mining.waitTime(block)
    local preSwing = Mining.preSwingDelay()

    logPrint(("mine %s (%s) base=%.2f wait=%.2f pre=%.2f penalty=%.2f"):format(
        block.Name,
        tostring(typeOf(block)),
        Mining.baseMineTime,
        waitTime,
        preSwing,
        Mining.penalty
    ))

    task.wait(preSwing)

    if not block.Parent then
        return false
    end

    blockEvent:FireServer(block.Name, { dug = true })

    -- Everything after BlockEvent counts against the server's mine time, so the
    -- old post-event "swing" delay was pure dead time and is gone: the human
    -- variance lives in `preSwing` before the claim instead.
    task.wait(waitTime)

    if not block.Parent then
        Mining.confirm()
        return true
    end

    minedEvent:FireServer({ blockName = vec3ToString(position) })

    local deadline = os.clock() + Config.mineRejectGrace
    while block.Parent and os.clock() < deadline do
        task.wait(0.05)
    end

    if block.Parent then
        blockEvent:FireServer(vec3ToString(position), { dug = false })
        Mining.rejects += 1
        Mining.punish()

        logWarn(("server rejected %s type=%s base=%.2f wait=%.3f streak=%d penalty=%.2f"):format(
            block.Name,
            tostring(typeOf(block)),
            Mining.baseMineTime,
            waitTime,
            Mining.rejects,
            Mining.penalty
        ))

        if Mining.rejects >= Config.maxRejects then
            Mining.resetRequested = true
            logWarn(("%d rejects in a row, requesting surface reset"):format(Mining.rejects))
        end

        return false
    end

    Mining.confirm()
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

    -- Deterministic order: equal prices fall back to the name, so the catalogue
    -- index of a resource does not change between sessions.
    table.sort(names, function(a, b)
        local priceA, priceB = Ores.price(a), Ores.price(b)

        if priceA == priceB then
            return a < b
        end

        return priceA > priceB
    end)

    namesCache = names
    return names
end

function Ores.bindSelection(selection, names)
    Ores.selection = selection
    Ores.namesList = names
end

local selectionCache = { version = -1 }

function Ores.selectedSet()
    local selection = Ores.selection
    if not selection then
        return nil
    end

    -- The widget counts its own changes, so the name set is rebuilt only when
    -- the user actually toggles an ore. The old version rebuilt it (and a key
    -- string) every 0.5 s, once per tick on the mining path.
    local version = selection.getVersion and selection.getVersion() or -1

    if selectionCache.set and selectionCache.selection == selection
        and selectionCache.version == version then
        return selectionCache.set
    end

    local set = {}

    for _, index in ipairs(selection.getSelected() or {}) do
        local name = Ores.namesList[index]
        if name then
            set[name] = true
        end
    end

    selectionCache.set = set
    selectionCache.selection = selection
    selectionCache.version = version
    return set
end

function Ores.isSelected(name)
    local set = Ores.selectedSet()
    if not set then
        return true
    end

    return set[name] == true
end

local scanCache = {
    time = 0,
    cell = nil,
    origin = nil,
    candidates = nil,
    index = 1,
}

local function byScore(a, b)
    return a.score > b.score
end

-- Squared-distance test: `(a - b).Magnitude` allocates a Vector3 per call, and
-- the ore scan runs it for every block in the cube.
local function withinRange(blockPosition, position, limitSq)
    local dx = blockPosition.X - position.X
    local dy = blockPosition.Y - position.Y
    local dz = blockPosition.Z - position.Z

    return dx * dx + dy * dy + dz * dz <= limitSq
end

-- Next usable entry of the cached candidate list: block still exists, still
-- selected, still in range, still ignored-free and still passes the expensive
-- `Mining.why`. A cached list is not invalidated by a broken block: the cursor
-- simply walks past it, so the common "one ore after another" case does no cube
-- scan at all.
local function scanCandidates(position, limitSq, selected)
    local candidates = scanCache.candidates

    if not candidates then
        return nil
    end

    local now = os.clock()

    while scanCache.index <= #candidates do
        local block = candidates[scanCache.index]
        scanCache.index = scanCache.index + 1

        if block.Parent then
            local name = typeOf(block)
            local untilIgnore = ignored[block]

            if name
                and (not selected or selected[name])
                and (not untilIgnore or untilIgnore <= now)
                and withinRange(block.Position, position, limitSq)
                and Mining.why(block) == nil then
                return block
            end
        end
    end

    return nil
end

-- Scans only the block cells around the player instead of every child of
-- Workspace.Mine. The sorted list is kept for `Config.oreScanTtl` while the
-- player stays in the same cell, so target acquisition after a break is a
-- cursor step, not another 343-cell pass. The TTL is a backstop: the list is
-- not rebuilt while it still has candidates and the root has not moved more
-- than `Config.oreScanMove` since the scan.
function Ores.nearest(position, radius)
    Watchdog.mark("ore scan")
    local limit = radius or Config.oreRange
    local limitSq = limit * limit
    local center = Blocks.toBlock(position)
    local now = os.clock()
    local selected = Ores.selectedSet()

    local movedSq = math.huge
    local origin = scanCache.origin

    if origin then
        local mx = position.X - origin.X
        local my = position.Y - origin.Y
        local mz = position.Z - origin.Z
        movedSq = mx * mx + my * my + mz * mz
    end

    if scanCache.cell == center
        and now - scanCache.time <= Config.oreScanTtl
        and movedSq <= Config.oreScanMove * Config.oreScanMove then
        return scanCandidates(position, limitSq, selected)
    end

    local map = Blocks.map()

    if not map then
        return nil
    end

    local reach = math.ceil(limit / 7)
    local found = {}
    local started = os.clock()

    for dx = -reach, reach do
        for dy = -reach, reach do
            for dz = -reach, reach do
                local block = map[xyzToString(center.X + dx, center.Y + dy, center.Z + dz)]

                if block then
                    local untilIgnore = ignored[block]

                    if not untilIgnore or untilIgnore <= now then
                        local blockPosition = block.Position
                        local px = blockPosition.X - position.X
                        local py = blockPosition.Y - position.Y
                        local pz = blockPosition.Z - position.Z
                        local distanceSq = px * px + py * py + pz * pz

                        if distanceSq <= limitSq then
                            local name = typeOf(block)

                            if name and (not selected or selected[name]) then
                                table.insert(found, {
                                    block = block,
                                    -- Squared distance orders equal-price ores
                                    -- exactly like sqrt did; the price term
                                    -- stays dominant (distance is < 1e3).
                                    score = Ores.price(name) * 1e6 - distanceSq,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(found, byScore)

    local candidates = {}

    for _, candidate in ipairs(found) do
        table.insert(candidates, candidate.block)
    end

    scanCache.time = now
    scanCache.cell = center
    scanCache.origin = position
    scanCache.candidates = candidates
    scanCache.index = 1

    -- Diagnostic: a full scan is the only per-break work with a variable cost.
    -- If this ever reports, the cell cube or the index is the frame-drop source.
    local spent = os.clock() - started

    if spent >= Config.slowScanWarn then
        logWarn(("ore scan %d found, %d cells %.1f ms"):format(
            #found, (reach * 2 + 1) ^ 3, spent * 1000))
    end

    -- Mining.valid is cheap but does not know about liquids: ask Mining.why
    -- lazily, and only until one candidate really passes.
    return scanCandidates(position, limitSq, selected)
end

-- Do not throw away the sorted list: the ignored block is skipped by
-- `scanCandidates`, and the next-best ore is already in the cache.
function Ores.ignore(block)
    ignored[block] = os.clock() + 5
end

-- Drop the cached scan cell/candidates and all temporary ignore timers.
function Ores.clearCache()
    scanCache.time = 0
    scanCache.cell = nil
    scanCache.origin = nil
    scanCache.candidates = nil
    scanCache.index = 1
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
    cached = nil,
    cachedAt = 0,
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

    -- `GetInventory()` builds a new table on every call. The sell run asks for
    -- one count per selected resource and the watcher once per second, so a
    -- short cache removes dozens of table builds per sell.
    local now = os.clock()

    if Inventory.cached and now - Inventory.cachedAt < 0.25 then
        return Inventory.cached
    end

    local ok, inventory = pcall(client.GetInventory, client)
    if not ok then
        return nil
    end

    Inventory.cached = inventory
    Inventory.cachedAt = now
    return inventory
end

-- Drop the snapshot after anything that changes the inventory (a forge action,
-- a sale). Without this, a count read within 0.25 s of the change still sees the
-- old table and the sell can skip freshly taken bars.
function Inventory.invalidate()
    Inventory.cached = nil
    Inventory.cachedAt = 0
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
-- Forge (workspace.Forge)
---------------------------------------------------------------------------
--
-- Surface sequence: take the melted result, put one selected ore into the
-- input, add enough selected fuel for that ore, then the caller sells.
-- Protocol: docs/game/protocol/forge.md. Only the client protocol and the ore
-- table are confirmed; every server-side check is unknown, so each action is a
-- single remote call with a state wait, never a blind loop.

local Forge = {
    enabled = false,
    bound = false,
    state = nil,
    source = nil,
    opened = false,
    openedByService = false,
    inputSelection = nil,
    inputList = nil,
    fuelSelection = nil,
    fuelList = nil,
}

-- Fallbacks when ForgeHelper / FuelData cannot be required. Values from
-- docs/game/protocol/forge.md.
Forge.oreList = {
    "Copper Ore", "Iron Ore", "Silver Ore", "Gold Ore",
    "Promethium Ore", "Mithril Ore", "Malachite Ore", "Azurite Ore",
}

Forge.fuelFallback = { "Coal", "Log", "Plank", "Oil Barrel", "Lava Barrel", "Ignis" }

Forge.smeltFallback = {
    ["Copper Ore"] = 40,
    ["Iron Ore"] = 60,
    ["Silver Ore"] = 40,
    ["Gold Ore"] = 50,
    ["Promethium Ore"] = 60,
    ["Mithril Ore"] = 80,
    ["Malachite Ore"] = 80,
    ["Azurite Ore"] = 80,
}

Forge.burnFallback = {
    Coal = 70,
    Log = 30,
    Plank = 30,
    ["Oil Barrel"] = 100,
    ["Lava Barrel"] = 130,
    Ignis = 110,
}

local function forgePart()
    return workspace:FindFirstChild(Config.forgeName)
end

local function requireChild(parent, name)
    local module = parent and parent:FindFirstChild(name)

    if not module then
        return nil
    end

    local ok, value = pcall(require, module)
    if ok and type(value) == "table" then
        return value
    end

    return nil
end

function Forge.helperModule()
    if not Forge.helper then
        Forge.helper = requireChild(forgePart(), "ForgeHelper")
    end

    return Forge.helper
end

function Forge.fuelModule()
    if not Forge.fuelData then
        local scripts = ReplicatedStorage:FindFirstChild("Scripts")
        Forge.fuelData = requireChild(scripts, "FuelData")
    end

    return Forge.fuelData
end

-- Sale value of one smelted bar. Bars carry `Multiplier` but no `BasePrice`,
-- so it is the ore price times the bar multiplier. Falls back to the ore price
-- when the result is not in the catalogue.
function Forge.oreValue(name)
    local result = Forge.result(name)
    local bar = result and resourceInfo(result)
    local multiplier = bar and bar.Multiplier or 1

    return Ores.price(name) * multiplier
end

-- Highest-value ore first: the forge input takes one ore type and the UI order
-- is the priority order, so the list is sorted by bar value (ties by name, for a
-- stable order between sessions). Cached: the UI maps saved names to indexes
-- against this table, and it must not change after the widget is built.
function Forge.oreNames()
    if Forge.oreNamesCache then
        return Forge.oreNamesCache
    end

    local names = {}

    for _, name in ipairs(Forge.oreList) do
        table.insert(names, name)
    end

    table.sort(names, function(a, b)
        local valueA, valueB = Forge.oreValue(a), Forge.oreValue(b)

        if valueA == valueB then
            return a < b
        end

        return valueA > valueB
    end)

    Forge.oreNamesCache = names
    return names
end

function Forge.fuelNames()
    if Forge.fuelNamesCache then
        return Forge.fuelNamesCache
    end

    local names = {}
    local data = Forge.fuelModule()

    if data and type(data.GetAllFuels) == "function" then
        local ok, list = pcall(data.GetAllFuels, data)

        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                table.insert(names, name)
            end
        end
    end

    if #names == 0 then
        for _, name in ipairs(Forge.fuelFallback) do
            table.insert(names, name)
        end
    end

    Forge.fuelNamesCache = names
    return names
end

function Forge.smeltTime(name)
    local helper = Forge.helperModule()

    if helper and type(helper.GetOreData) == "function" then
        local ok, data = pcall(helper.GetOreData, helper, name)

        if ok and type(data) == "table" and type(data.SmeltTime) == "number" then
            return data.SmeltTime
        end
    end

    return Forge.smeltFallback[name] or 0
end

function Forge.result(name)
    local helper = Forge.helperModule()

    if helper and type(helper.GetOreData) == "function" then
        local ok, data = pcall(helper.GetOreData, helper, name)

        if ok and type(data) == "table" and type(data.Result) == "string" then
            return data.Result
        end
    end

    -- Fallback for the documented ore table: `Copper Ore` -> `Copper Bar`.
    return (name:gsub("Ore$", "Bar"))
end

function Forge.burnTime(name)
    local data = Forge.fuelModule()

    if data and type(data.GetFuelData) == "function" then
        local ok, fuel = pcall(data.GetFuelData, data, name)

        if ok and type(fuel) == "table" and type(fuel.BurnTime) == "number" then
            return fuel.BurnTime
        end
    end

    return Forge.burnFallback[name] or 30
end

function Forge.bindInput(selection, names)
    Forge.inputSelection = selection
    Forge.inputList = names
end

function Forge.bindFuel(selection, names)
    Forge.fuelSelection = selection
    Forge.fuelList = names
end

function Forge.selectedNames(selection, list)
    local names = {}

    if not selection then
        return names
    end

    for _, index in ipairs(selection.getSelected() or {}) do
        local name = list[index]

        if name then
            table.insert(names, name)
        end
    end

    return names
end

-- One listener for the state the server broadcasts on every change, plus the
-- open notification the forge GUI receives.
function Forge.bind()
    if Forge.bound then
        return
    end

    Forge.bound = true

    task.spawn(function()
        local part = workspace:WaitForChild(Config.forgeName, 30)

        if not part then
            logWarn("forge: workspace." .. Config.forgeName .. " not found")
            return
        end

        local update = part:WaitForChild(Config.forgeUpdateRemote, 30)

        if update then
            update.OnClientEvent:Connect(function(payload)
                if type(payload) ~= "table" then
                    return
                end

                if type(payload.PlayerForgeData) == "table" then
                    Forge.state = payload.PlayerForgeData
                end

                if type(payload.SourceData) == "table" then
                    Forge.source = payload.SourceData
                end
            end)
        else
            logWarn("forge: " .. Config.forgeUpdateRemote .. " not found")
        end

        local toggle = part:WaitForChild(Config.forgeToggleRemote, 30)

        if toggle then
            toggle.OnClientEvent:Connect(function()
                Forge.opened = true
            end)
        end
    end)
end

function Forge.inputAmount()
    local input = Forge.state and Forge.state.Input

    return (input and input.Amount) or 0, (input and input.Type) or ""
end

function Forge.outputAmount()
    local output = Forge.state and Forge.state.Output

    return (output and output.Amount) or 0
end

function Forge.fuelRemaining()
    local fuel = Forge.source and Forge.source.Fuel

    return (fuel and fuel.BurnTimeRemaining) or 0
end

function Forge.waitState(predicate, timeout)
    local deadline = os.clock() + (timeout or Config.forgeStateWait)

    while os.clock() < deadline do
        local ok, done = pcall(predicate)

        if ok and done then
            return true
        end

        task.wait(0.05)
    end

    return false
end

-- Fires `Interact.InteractEvent` like the surface prompt does, and waits for the
-- server to open the forge. A missing answer is not fatal: the update remotes are
-- fired anyway and the server decides.
function Forge.enter(part)
    if Forge.opened then
        return false
    end

    local config = part:FindFirstChild("Interact")
    local remote = config and config:FindFirstChild("InteractEvent")

    if not remote then
        logPrint("forge: Interact.InteractEvent not found, firing remotes directly")
        return false
    end

    local ok, err = pcall(function()
        remote:FireServer()
    end)

    if not ok then
        logWarn("forge: interact failed: " .. tostring(err))
        return false
    end

    local opened = Forge.waitState(function()
        return Forge.opened
    end, Config.forgeOpenWait)

    -- The update remotes are fired immediately after this returns: give the
    -- server a moment to register the open state even when the client event was
    -- missed or arrived late.
    task.wait(Config.forgeOpenBuffer)

    if opened then
        Forge.openedByService = true
        return true
    end

    logWarn("forge: no open event after interact, continuing")
    return false
end

-- Same local cleanup the real CloseButton handler does, so the forge GUI does
-- not stay on screen after an automated visit.
function Forge.leave(part)
    if not Forge.openedByService then
        return
    end

    local toggle = part:FindFirstChild(Config.forgeToggleRemote)

    if toggle then
        pcall(function()
            toggle:FireServer()
        end)
    end

    pcall(function()
        local player = Players.LocalPlayer
        local playerGui = player:FindFirstChild("PlayerGui")
        local gui = playerGui and playerGui:FindFirstChild(Config.forgeName)
        local container = gui and gui:FindFirstChild("Container")

        if container then
            container.Visible = false
        end

        player:SetAttribute("BackpackVisible", true)
    end)

    Forge.opened = false
    Forge.openedByService = false
end

function Forge.takeResult(update)
    local amount = Forge.outputAmount()
    local used, capacity = Inventory.usage()

    -- The real client refuses TakeResult when the inventory is full.
    if used and capacity and used >= capacity then
        logWarn("forge: inventory full, result not taken")
        return 0
    end

    update:FireServer("TakeResult")

    -- The remote is fire-and-forget: wait one step before reading state, and
    -- always give the server time to move the result even when the client
    -- believes the output is empty.
    task.wait(Config.forgeActionWait)

    if amount > 0 then
        Forge.waitState(function()
            return Forge.outputAmount() ~= amount
        end)
    end

    -- The inventory changed (or may have): the next count must not come from
    -- the pre-take snapshot.
    Inventory.invalidate()

    return amount
end

-- One ore type per visit: the forge input holds a single type while it melts.
-- Returns the amount in the input and its name, so fuel can be sized for it.
function Forge.addInput(update)
    local amount, inputType = Forge.inputAmount()

    if amount > 0 then
        return amount, inputType
    end

    for _, name in ipairs(Forge.selectedNames(Forge.inputSelection, Forge.inputList)) do
        local count = Inventory.count(name) or 0

        if count > 0 then
            update:FireServer("AddInput", { name, count })

            -- Fire-and-forget remote: one step before reading state, then wait
            -- for the server to report the queued amount.
            task.wait(Config.forgeActionWait)

            Forge.waitState(function()
                return Forge.inputAmount() > 0
            end)

            Inventory.invalidate()

            local queued, queuedType = Forge.inputAmount()

            if queued > 0 then
                return queued, queuedType ~= "" and queuedType or name
            end

            -- No state at all yet: the server may still have accepted the ore.
            if Forge.state == nil then
                return count, name
            end

            logWarn("forge: input not accepted for " .. name)
            return 0, nil
        end
    end

    return 0, nil
end

function Forge.addFuel(update, oreName, inputCount)
    if not oreName or inputCount <= 0 then
        return 0
    end

    local needed = Forge.smeltTime(oreName) * inputCount
    local burn = Forge.fuelRemaining()

    if burn >= needed then
        return 0
    end

    for _, name in ipairs(Forge.selectedNames(Forge.fuelSelection, Forge.fuelList)) do
        local count = Inventory.count(name) or 0
        local perUnit = Forge.burnTime(name)

        if count > 0 and perUnit > 0 then
            local units = math.ceil((needed - burn) / perUnit)

            units = math.min(units, count, Config.forgeMaxFuelUnits)

            for _ = 1, units do
                if Forge.fuelRemaining() >= needed then
                    break
                end

                update:FireServer("AddFuel", name)
                task.wait(Config.forgeActionWait)
            end

            -- Fuel came out of the inventory: the next count must be fresh.
            Inventory.invalidate()

            logPrint(("forge: fuel %s x%d covers %ds of %ds"):format(
                name, units, units * perUnit, needed))
            return units
        end
    end

    logWarn("forge: no selected fuel in inventory")
    return 0
end

-- Take result -> add input -> add fuel. The caller sells after this.
function Forge.service(origin, force)
    Watchdog.mark("forge")
    if not force and not Forge.enabled then
        return false
    end

    local part = forgePart()

    if not part then
        logWarn("forge: workspace." .. Config.forgeName .. " not found")
        return false
    end

    local update = part:FindFirstChild(Config.forgeUpdateRemote)

    if not update then
        logWarn("forge: " .. Config.forgeUpdateRemote .. " not found")
        return false
    end

    local opened = Forge.enter(part)
    local taken, added, oreName, fueled = 0, 0, nil, 0

    local ok, err = pcall(function()
        taken = Forge.takeResult(update)
        added, oreName = Forge.addInput(update)
        fueled = Forge.addFuel(update, oreName, added)
    end)

    -- Let the last remote land before the forge is closed and the caller sells.
    if ok then
        task.wait(Config.forgeSettle)
    end

    if opened then
        Forge.leave(part)
    end

    if not ok then
        logWarn("forge: " .. tostring(err))
        return false
    end

    logPrint(("forge %s: took %d, input %s x%d, fuel %d"):format(
        tostring(origin), taken, tostring(oreName or "-"), added, fueled))

    return true
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

-- Sellable resources are split into three lists: mined ores (`Natural`),
-- mushrooms (`MushroomResource`; they have BasePrice but neither Natural nor
-- AppearsInShop, so the farm ore list does not contain them) and smelted bars.
--
-- Smelted bars are the forge results of the known ores (`Copper Ore` ->
-- `Copper Bar`, ...). `NotPurchasable` alone is not enough: Diamond, Obsidian,
-- Ignis and Hellstone are NotPurchasable and still mined ores, and
-- `ChildResources` also covers lumber (`Oak Plank`, `Oak Stick`).
function Sell.smeltedSet()
    if Sell.smeltedCache then
        return Sell.smeltedCache
    end

    local set = {}

    for _, ore in ipairs(Forge.oreNames()) do
        local result = Forge.result(ore)

        if result and Game.Resources and Game.Resources[result] then
            set[result] = true
        end
    end

    Sell.smeltedCache = set
    return set
end

local function sortByPrice(names)
    -- Same deterministic order as `Ores.names`: price, then name.
    table.sort(names, function(a, b)
        local priceA, priceB = Ores.price(a), Ores.price(b)

        if priceA == priceB then
            return a < b
        end

        return priceA > priceB
    end)

    return names
end

-- Sell list split for the UI: Ores, Mushrooms, Smelted. `Sell.names()` is the
-- flat version of the same lists, in this order, so the saved `sellNames` key
-- and every selection index keep working.
function Sell.groups()
    if Sell.groupsCache then
        return Sell.groupsCache
    end

    local smelted = Sell.smeltedSet()
    local groups = {
        { title = "Ores", names = {} },
        { title = "Mushrooms", names = {} },
        { title = "Smelted", names = {} },
    }

    if Game.Resources then
        for name, info in pairs(Game.Resources) do
            if type(info) == "table" and not info.Unobtainable then
                if smelted[name] then
                    table.insert(groups[3].names, name)
                elseif info.MushroomResource and info.BasePrice then
                    table.insert(groups[2].names, name)
                elseif info.Natural and info.BasePrice then
                    table.insert(groups[1].names, name)
                end
            end
        end
    end

    for _, group in ipairs(groups) do
        sortByPrice(group.names)
    end

    -- The resource catalogue is static after load, so the three sorted groups
    -- are built once instead of on every `Sell.names()` / UI section call.
    Sell.groupsCache = groups
    return groups
end

function Sell.names()
    local names = {}

    for _, group in ipairs(Sell.groups()) do
        for _, name in ipairs(group.names) do
            table.insert(names, name)
        end
    end

    return names
end

function Sell.bindSelection(selection, names)
    Sell.selection = selection
    Sell.namesList = names
end

local sellSetCache = { selection = nil, version = -1, set = nil }

function Sell.selectedSet()
    local selection = Sell.selection

    if not selection then
        return {}
    end

    local version = selection.getVersion and selection.getVersion() or -1
    local cache = sellSetCache

    -- Rebuilt only when the user toggles a resource, like `Ores.selectedSet`.
    if cache.set and cache.selection == selection and cache.version == version then
        return cache.set
    end

    local set = {}

    for _, index in ipairs(selection.getSelected() or {}) do
        local name = Sell.namesList[index]
        if name then
            set[name] = true
        end
    end

    cache.selection = selection
    cache.version = version
    cache.set = set
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

-- The surface teleport is a server-side move: `InvokeServer` returning does not
-- mean the character is already up. Wait for the block layer to be at surface
-- level before the caller anchors the root, otherwise the anchor can freeze the
-- character mid-fall or still inside the mine.
function Sell.waitSurfaced(character)
    local root = character and character.PrimaryPart
    if not root then
        return false
    end

    local deadline = os.clock() + Config.sellSurfaceWait

    while os.clock() < deadline do
        if Blocks.toBlock(root.Position).Y < Config.surfaceDepth then
            return true
        end

        task.wait(0.05)
    end

    return false
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

        if not Sell.waitSurfaced(character) then
            Sell.diag("surface", "autosell: still below the surface after " .. Config.surfaceRemote)
        end

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
    -- A manual sell or a forge trip already owns the character.
    if Sell.busy then
        return 0
    end

    -- Never start a sell while a jump/tween is in flight or a block is claimed.
    -- This check used to run after the inventory read, so every tick of a long
    -- mine time built an inventory snapshot for a sell that was then skipped.
    if Movement.moving() or Movement.holdRoot then
        Sell.diag("busy", ("autosell %s: mining in progress, retry later"):format(origin))
        return 0
    end

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

    logPrint(("autosell trigger %s used=%d/%d src=%s enabled=%s"):format(
        origin, used, capacity, tostring(source), tostring(Sell.enabled)))

    if not Sell.enabled then
        return Sell.run(false, origin)
    end

    -- Take the busy flag before `Character.get()`: that call can yield on a
    -- respawn, and a second watcher tick must not start another surface trip.
    Sell.busy = true

    local character = Character.get()

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

        -- Forge first, sale second: take bars, refill input and fuel while the
        -- root is already anchored on the surface.
        pcall(Forge.service, origin)

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
    Watchdog.mark("sell")
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

    -- Forge actions and the surface teleport run right before this: read counts
    -- from a fresh inventory, not from a snapshot taken before they finished.
    Inventory.invalidate()

    local selected = Sell.selectedSet()
    local sold = 0
    local used, capacity, source = Sell.usage()
    local nSelected = Sell.selectedCount()

    local candidates, units = 0, 0

    -- One count per selected resource: the sell loop below used to repeat every
    -- `Sell.count` call, and each one walks the inventory / backpack fallback.
    local sellList = {}

    for _, name in ipairs(Sell.namesList or {}) do
        if selected[name] then
            local count = Sell.count(name)
            if count > 0 then
                candidates += 1
                units += count
                table.insert(sellList, { name = name, count = count })
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

    for _, entry in ipairs(sellList) do
        local name, count = entry.name, entry.count
        local ok, result = pcall(remote.InvokeServer, remote, name, count)

        if not ok then
            logWarn(("sell error %s: %s"):format(name, tostring(result)))
        elseif result == false then
            -- The remote answered, so the name or the count is wrong.
            logWarn(("sell refused %s x%d"):format(name, count))
        else
            sold += count
            logPrint(("sold %s x%d -> %s"):format(name, count, tostring(result)))
        end

        -- One remote per resource: a small gap keeps the server's inventory
        -- update from racing the next call.
        task.wait(Config.sellItemDelay)
    end

    return sold
end

-- "Sell now" button: forced run, works with a partially filled backpack, with
-- the Auto sell toggle off, and from inside the mine (it surfaces first).
function Sell.manual()
    -- A second click (or the watcher) must not run a sell on top of this one.
    if Sell.busy then
        return 0
    end

    -- A jump/tween anchors and pivots the root; a surface teleport in the
    -- middle of it would be undone by the movement thread.
    if Movement.moving() then
        return 0
    end

    -- See `Sell.try`: take the flag before the (possibly yielding) lookup.
    Sell.busy = true

    local character = Character.get()

    local ok, sold = pcall(function()
        Sell.toSurface(character)
        Sell.holdForSale(character)
        task.wait(Config.sellHoldBefore)
        pcall(Forge.service, "manual")
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

-- Surface trip for the forge alone ("Service now"): no sale afterwards, used
-- when auto sell is off or the backpack is not full.
function Forge.trip(origin)
    if Sell.busy or Movement.moving() then
        return false
    end

    -- See `Sell.try`: take the flag before the (possibly yielding) lookup.
    Sell.busy = true

    local character = Character.get()

    local ok, serviced = pcall(function()
        if not Sell.toSurface(character) then
            return false
        end

        if not Sell.holdForSale(character) then
            return false
        end

        task.wait(Config.sellHoldBefore)
        local value = Forge.service(origin, true)
        task.wait(Config.sellHoldAfter)
        Movement.releaseHold()
        return value
    end)

    Movement.releaseHold()
    Sell.busy = false

    if not ok then
        error(serviced)
    end

    return serviced
end

---------------------------------------------------------------------------
-- Loot (workspace.TargetFilter/{BlockName}_Drop)
---------------------------------------------------------------------------

local Loot = {
    pending = {},
    pendingSet = {},
    containerCache = nil,
    bound = nil,
    retryPending = false,
}

function Loot.container()
    local container = Loot.containerCache

    if container and container.Parent then
        return container
    end

    container = workspace:FindFirstChild("TargetFilter") or workspace:FindFirstChild("Drops")
    Loot.containerCache = container
    return container
end

local partCache = setmetatable({}, { __mode = "k" })
local ownerCache = setmetatable({}, { __mode = "k" })
local nameCache = setmetatable({}, { __mode = "k" })

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
    local cached = nameCache[drop]

    if cached then
        return cached
    end

    cached = (tostring(drop.Name):gsub("_Drop$", ""))
    nameCache[drop] = cached
    return cached
end

function Loot.count()
    return #Loot.pending
end

-- Event-driven. The old per-tick scan walked every drop in `TargetFilter` every
-- 0.4 s (other players' drops included) and each entry did a recursive
-- `FindFirstChild("DropScript", true)`. Drops are now offered once on
-- ChildAdded, re-checked once after `lootOwnerDelay` because `DropScript.Player`
-- can replicate a frame later, and removed on ChildRemoved.
function Loot.bind()
    local container = Loot.container()

    if not container or Loot.bound == container then
        return
    end

    Loot.bound = container

    container.ChildAdded:Connect(function(drop)
        Loot.offer(drop)
    end)

    container.ChildRemoved:Connect(function(drop)
        Loot.remove(drop)
    end)

    -- Catch drops that already exist when the container appears.
    for _, drop in ipairs(container:GetChildren()) do
        Loot.offer(drop)
    end
end

function Loot.add(drop)
    if Loot.pendingSet[drop] or not drop.Parent then
        return false
    end

    if not Loot.part(drop) or not Loot.mine(drop) then
        return false
    end

    if not Ores.isSelected(Loot.name(drop)) then
        return false
    end

    Loot.pendingSet[drop] = true
    table.insert(Loot.pending, drop)
    return true
end

-- One delayed sweep for all drops whose owner attribute had not replicated yet,
-- instead of one `task.delay` closure per drop (a burst of breaks or a join used
-- to schedule them all onto the same frame).
function Loot.retryOwners()
    if Loot.retryPending then
        return
    end

    Loot.retryPending = true

    task.delay(Config.lootOwnerDelay, function()
        Loot.retryPending = false

        local container = Loot.container()
        if not container then
            return
        end

        for _, drop in ipairs(container:GetChildren()) do
            Loot.add(drop)
        end
    end)
end

function Loot.offer(drop)
    if not (drop:IsA("Model") or drop:IsA("BasePart")) then
        return
    end

    if Loot.add(drop) then
        return
    end

    -- Only re-check when the owner is still unknown; a foreign or unselected
    -- drop does not need a second look.
    if Loot.playerValue(drop) == nil then
        Loot.retryOwners()
    end
end

function Loot.clear()
    if #Loot.pending > 0 then
        table.clear(Loot.pending)
        table.clear(Loot.pendingSet)
    end
end

-- Kept for the Farm step: binds the container on first sight and drops the
-- pending list when the container is gone.
function Loot.sync()
    Loot.bind()

    if not Loot.containerCache then
        Loot.clear()
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
-- Drops are pushed by `Loot.bind` (ChildAdded) and picked up on the next tick.
local function lootOrder(a, b)
    return Ores.price(Loot.name(a)) > Ores.price(Loot.name(b))
end

function Loot.collectAll(character)
    Watchdog.mark("loot")
    local root = character.PrimaryPart
    if not root then
        return 0
    end

    table.sort(Loot.pending, lootOrder)

    local picked = 0
    local index = 1

    while index <= #Loot.pending do
        -- A watcher sell started between two drops owns the character now.
        if Sell.busy then
            break
        end

        local drop = Loot.pending[index]

        if not drop.Parent or not Ores.isSelected(Loot.name(drop)) then
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

-- `workspace:GetChildren()` returns a fresh copy of every child, and it used to
-- run on every Mushroom tick (20/s). The node list is now refreshed at most
-- once per second and pruned in place.
local nodeCache = { time = 0, list = {} }
local nodeSet = setmetatable({}, { __mode = "k" })

-- Node -> BoundingBox. The two child lookups ran per node per tick.
local boxCache = setmetatable({}, { __mode = "k" })

local function harvestables()
    local now = os.clock()
    local list = nodeCache.list

    if now - nodeCache.time < 1 then
        return list
    end

    nodeCache.time = now

    for index = #list, 1, -1 do
        local node = list[index]

        if not node.Parent then
            nodeSet[node] = nil
            table.remove(list, index)
        end
    end

    for _, node in ipairs(workspace:GetChildren()) do
        if node.Name == "HarvestableNode" and not nodeSet[node] then
            nodeSet[node] = true
            table.insert(list, node)
        end
    end

    return list
end

function MushroomNode.nearest(position)
    local best, bestDistance
    local now = os.clock()

    for _, node in ipairs(harvestables()) do
        local untilIgnore = mushroomIgnored[node]
        if not untilIgnore or untilIgnore <= now then
            local box = boxCache[node]

            if box and not box.Parent then
                boxCache[node] = nil
                box = nil
            end

            if not box then
                local model = node:FindFirstChildWhichIsA("Model")
                box = model and model:FindFirstChild("BoundingBox")

                if box then
                    boxCache[node] = box
                end
            end

            if box and box:FindFirstChild("Interact") then
                local dx = box.Position.X - position.X
                local dy = box.Position.Y - position.Y
                local dz = box.Position.Z - position.Z
                local distance = dx * dx + dy * dy + dz * dz

                if not bestDistance or distance < bestDistance then
                    best, bestDistance = box, distance
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

-- Escape planner
--
-- The bot can only dig what is in reach, but it can teleport anywhere. Escaping a
-- liquid pocket therefore is a grid pathfinding problem, not a "find a free cell"
-- problem: in a one-cell shaft surrounded by solid rock there is no free cell to
-- teleport to, the bot has to dig one.
--
-- Node   = cell the bot stands in.
-- Edge   = one of the 6 neighbours. An empty cell above is cheap; a solid diggable
--          block costs its mine time; liquid, bedrock, foreign `Dug`, blocked
--          types and liquid-adjacent blocks are impassable.
-- Goal   = cell with `Config.planClearance` diggable blocks in a row below it.
--
-- Dijkstra with early exit inside a `planRadius` box. The ore selection is
-- ignored: escape may use any resource.

local Plan = {
    current = nil,
}

local CELL_UP = Vector3.new(0, -1, 0)
local CELL_DOWN = Vector3.new(0, 1, 0)

local PLAN_MOVES = {
    Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
    Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
    CELL_UP, CELL_DOWN,
}

-- Planner keys are packed relative cell offsets, not "x,y,z" strings: one
-- integer add per edge instead of a `string.format`. `planRadius` bounds every
-- relative coordinate; the offset leaves room for the clearance depth below a
-- goal cell, and the strides keep each axis in its own digit.
local KEY_OFFSET = 16
local KEY_Y = 32
local KEY_X = 1024

local function keyOf(dx, dy, dz)
    return (dx + KEY_OFFSET) * KEY_X + (dy + KEY_OFFSET) * KEY_Y + (dz + KEY_OFFSET)
end

local START_KEY = keyOf(0, 0, 0)

local function heapPush(heap, node)
    local index = #heap + 1
    heap[index] = node

    while index > 1 do
        local parent = math.floor(index / 2)

        if heap[parent].cost <= heap[index].cost then
            break
        end

        heap[parent], heap[index] = heap[index], heap[parent]
        index = parent
    end
end

local function heapPop(heap)
    local count = #heap
    if count == 0 then
        return nil
    end

    local first = heap[1]
    heap[1] = heap[count]
    heap[count] = nil
    count = count - 1

    local index = 1

    while true do
        local left, right = index * 2, index * 2 + 1
        local smallest = index

        if left <= count and heap[left].cost < heap[smallest].cost then
            smallest = left
        end

        if right <= count and heap[right].cost < heap[smallest].cost then
            smallest = right
        end

        if smallest == index then
            break
        end

        heap[smallest], heap[index] = heap[index], heap[smallest]
        index = smallest
    end

    return first
end

-- Cheapest test first: the cached liquid set, then the attribute checks.
local function diggable(block, liquids)
    if not block or not block.Parent then
        return false
    end

    if Mining.besideLiquid(block, liquids) then
        return false
    end

    return Mining.valid(block) == nil
end

-- The column below `cell` must allow a few clean down-digs, otherwise the plan
-- would stop next to the same liquid pocket. An empty cell is fine, but the first
-- floor under it has to be there.
function Plan.clear(mine, cell)
    for depth = 1, Config.planClearance do
        local block = Blocks.at(vec3ToString(cell + CELL_DOWN * depth))

        if not block then
            return depth > 1
        end

        if not diggable(block) then
            return false
        end
    end

    return true
end

function Plan.reset()
    Plan.current = nil
end

-- No route for the same cell within `planRetry` seconds: do not request a
-- surface reset every tick. The world may change (other players dig), so retry.
function Plan.failedRecently(cell)
    if not Plan.failKey or Plan.failKey ~= vec3ToString(cell) then
        return false
    end

    return os.clock() - Plan.failTime < Config.planRetry
end

function Plan.noteFailure(cell)
    Plan.failKey = vec3ToString(cell)
    Plan.failTime = os.clock()
end

function Plan.build(start)
    Watchdog.mark("plan build")
    local mine = Blocks.model()
    if not mine then
        return nil
    end

    local radius = Config.planRadius
    local startKey = START_KEY
    local cells = { [startKey] = start }
    local costs = { [startKey] = 0 }
    local parents = {}

    -- `false` means "cell looked up and empty"; nil means "not looked up yet".
    local blocks = {}
    local digs = {}
    local heap = {}

    -- Resolved once for the whole build instead of once per candidate block.
    local liquids = Blocks.liquidSet()

    -- Same check as `Plan.clear`, but it shares the `blocks` / `digs` caches:
    -- a cell inspected as a goal and as an edge is read once per build. The
    -- cell below `key` is `key + KEY_Y` (Y is the middle stride).
    local function clear(key, cell)
        for depth = 1, Config.planClearance do
            local blockKey = key + KEY_Y * depth
            local block = blocks[blockKey]

            if block == nil then
                block = Blocks.at(xyzToString(cell.X, cell.Y + depth, cell.Z)) or false
                blocks[blockKey] = block
            end

            if not block then
                return depth > 1
            end

            local dig = digs[blockKey]

            if dig == nil then
                dig = diggable(block, liquids)
                digs[blockKey] = dig
            end

            if not dig then
                return false
            end
        end

        return true
    end

    heapPush(heap, { cost = 0, key = startKey })

    local pops = 0

    while true do
        local node = heapPop(heap)

        if not node then
            return nil
        end

        pops = pops + 1

        if pops > Config.planMaxNodes then
            logWarn("plan: node cap reached")
            return nil
        end

        if pops % 500 == 0 then
            task.wait()
        end

        local key = node.key

        if node.cost <= costs[key] then
            local cell = cells[key]

            if key ~= startKey and clear(key, cell) then
                -- The path mines its own cells, so a goal sitting right on top of
                -- the route has no floor left once the route is dug. Reject it.
                local belowKey = key + KEY_Y
                local chain = {}
                local walk = key
                local minedBelow = false

                while walk ~= startKey do
                    if walk == belowKey then
                        minedBelow = true
                    end

                    chain[#chain + 1] = cells[walk]
                    walk = parents[walk]
                end

                if not minedBelow then
                    local count = #chain

                    for index = 1, math.floor(count / 2) do
                        local mirror = count + 1 - index
                        chain[index], chain[mirror] = chain[mirror], chain[index]
                    end

                    return chain, node.cost
                end
            end

            for _, move in ipairs(PLAN_MOVES) do
                local nextCell = cell + move
                local delta = nextCell - start

                if math.abs(delta.X) <= radius
                    and math.abs(delta.Y) <= radius
                    and math.abs(delta.Z) <= radius then
                    local nextKey = keyOf(delta.X, delta.Y, delta.Z)
                    local block = blocks[nextKey]

                    if block == nil then
                        block = Blocks.at(xyzToString(nextCell.X, nextCell.Y, nextCell.Z)) or false
                        blocks[nextKey] = block
                    end

                    local step

                    if block then
                        -- Dig the block and stand in the freed cell. `diggable`
                        -- is cached per cell: a node is examined from up to 6
                        -- parents and it reads attributes.
                        local dig = digs[nextKey]

                        if dig == nil then
                            dig = diggable(block, liquids)
                            digs[nextKey] = dig
                        end

                        if dig then
                            step = Mining.mineTime(block) + Config.planHop
                        end
                    elseif move == CELL_UP then
                        -- Own shaft: climb, but climbing back costs a down-dig later.
                        step = Config.planHop + Config.planUpCost
                    end

                    if step then
                        local total = node.cost + step

                        if not costs[nextKey] or total < costs[nextKey] then
                            costs[nextKey] = total
                            parents[nextKey] = key
                            cells[nextKey] = nextCell
                            heapPush(heap, { cost = total, key = nextKey })
                        end
                    end
                end
            end
        end
    end
end

-- One dig per tick. `mineBlock(character, block)` is Farm's own mining wrapper;
-- it returns true only when the block is really gone.
function Plan.run(character, root, mineBlock)
    Watchdog.mark("plan")
    local cell = Blocks.toBlock(root.Position)
    local plan = Plan.current

    -- Loot, the server or a fall moved the bot: rebuild from the real cell.
    if plan and plan.expected ~= cell then
        Plan.reset()
        plan = nil
    end

    if not plan then
        local path, cost = Plan.build(cell)

        if not path or #path == 0 then
            logWarn(("plan: no route from %s"):format(vec3ToString(cell)))
            return false
        end

        plan = { path = path, index = 1, expected = cell, fails = 0 }
        Plan.current = plan
        Plan.failKey = nil

        logPrint(("plan: %d steps %.1fs -> %s"):format(
            #path, cost, vec3ToString(path[#path])))
    end

    local mine = Blocks.model()
    if not mine then
        Plan.reset()
        return false
    end

    -- Empty steps are the bot's own shaft. It cannot stay there: gravity drops it
    -- back down a one-cell shaft, so climbing only works as part of the next dig.
    -- Remember the climb and mine the next solid cell from that height.
    local climb
    local target, block

    while plan.index <= #plan.path do
        target = plan.path[plan.index]
        block = Blocks.at(vec3ToString(target))

        if block then
            break
        end

        climb = target
        target, block = nil, nil
        plan.index = plan.index + 1
    end

    if not target then
        Plan.reset()
        logPrint("plan: nothing left to dig")
        return true
    end

    if climb then
        -- Climb only when the dig needs the height: a teleport in the same tick
        -- as BlockEvent is what `Config.moveCooldown` normally avoids.
        if not Mining.inRange(character, block) then
            Movement.jump(character, Blocks.standPoint(climb))
        end
    end

    if not mineBlock(character, block) then
        plan.fails = plan.fails + 1

        if plan.fails >= 2 then
            Plan.reset()
        end

        return true
    end

    Movement.jump(character, Blocks.standPoint(target))
    plan.expected = target
    plan.index = plan.index + 1

    if plan.index > #plan.path then
        Plan.reset()
        logPrint("plan: done")
    end

    return true
end

-- Root hold + pickaxe prepare + timing for one block. Hoisted out of the Farm
-- step so the old nested `mine` closure is not re-allocated every tick.
local function mineTarget(character, block)
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

    Movement.hold(character)
    local ok, result = pcall(Mining.mine, character, block)
    Movement.releaseHold()

    return ok and result == true
end

-- Same answer as `FindFirstChildWhichIsA("BasePart") == nil`, but O(1): the
-- block index already tracks every child of the mine and its exact count.
local function mineEmpty(mine)
    return Blocks.count() == 0
end

-- Preventive floor check is three `FindFirstChild` lookups plus string builds.
-- Blocks only change when something mines them, so once per 0.25 s per cell is
-- enough and keeps the per-tick path allocation-free.
local clearCheck = { cell = nil, time = 0, value = true }

local function columnClear(mine, cell)
    local now = os.clock()

    if clearCheck.cell == cell and now - clearCheck.time < 0.25 then
        return clearCheck.value
    end

    clearCheck.cell = cell
    clearCheck.time = now
    clearCheck.value = Plan.clear(mine, cell)
    return clearCheck.value
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
        Blocks.invalidateLiquids()
        Plan.reset()
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
    Loot.sync()

    if Loot.count() > 0 then
        Loot.collectAll(character)
    end

    -- The watcher can take the character while the loot loop is between drops.
    if Sell.busy then
        return
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

    Blocks.calibrate()

    -- Empty field: nothing to dig and no ground under it. Raise once and anchor,
    -- otherwise every tick teleports up and falls back.
    local mineModel = Blocks.model()

    if mineModel and mineEmpty(mineModel) then
        local safe = Vector3.new(
            Config.fieldCenter.X,
            Config.fieldCenter.Y + Config.emptyMineLift,
            Config.fieldCenter.Z
        )

        local dx = safe.X - root.Position.X
        local dy = safe.Y - root.Position.Y
        local dz = safe.Z - root.Position.Z

        if dx * dx + dy * dy + dz * dz > 16 then
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

        local pit = Surface.find(root.Position, cell)

        if pit then
            if cell.X ~= pit.X or cell.Z ~= pit.Z then
                local mine = Blocks.model()
                local mouth = Vector3.new(pit.X, cell.Y, pit.Z)

                -- Only jump into a mouth that is really empty.
                if mine and not Blocks.at(vec3ToString(mouth)) then
                    Movement.jump(character, Blocks.worldOf(mouth) + Vector3.new(0, Config.teleportLift, 0))
                    return
                end
            else
                local below = Blocks.below(root.Position)

                if below then
                    if mineTarget(character, below) then
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

    -- No floor under the feet: the bot is falling. Let physics finish before
    -- planning, otherwise every fall tick would rebuild a plan.
    if not below then
        Plan.reset()
        Movement.waitLanded(character)
        return
    end

    -- Escape planning. A route is built when:
    --   * a plan is already running,
    --   * the floor cannot be dug (liquid neighbour, blocked type, foreign Dug),
    --   * or the next `planClearance` blocks under this column are not clean
    --     (preventive: move away before sitting in a liquid pocket).
    -- The planner ignores the ore selection and digs its own tunnel: the bot sits
    -- in a one-cell shaft, so there is usually no free cell to teleport into.
    local needPlan = Plan.current ~= nil

    if not needPlan and mineModel then
        if belowReason ~= nil or not columnClear(mineModel, cell) then
            needPlan = true

            if belowReason then
                logWarn(("floor blocked (%s), planning route"):format(tostring(belowReason)))
            end
        end
    end

    if needPlan then
        if Plan.run(character, root, mineTarget) then
            return
        end

        if Plan.failedRecently(cell) then
            logWarn("plan: still no route, waiting")
            task.wait(1)
            return
        end

        Plan.noteFailure(cell)
        logWarn("plan: no route, requesting surface reset")
        Plan.reset()
        Mining.resetRequested = true
        return
    end

    -- 3. Mine the best selected block already in reach. No movement.
    local ore = Ores.nearest(root.Position, Mining.reach())

    if ore then
        if not mineTarget(character, ore) then
            Ores.ignore(ore)
        end
        return
    end

    -- 4. Nothing reachable: dig straight down, one block at a time.
    if mineTarget(character, below) then
        Movement.waitLanded(character)
        return
    end

    if below.Parent and Mining.why(below) then
        -- Rejected between the plan check and the swing: escalate next tick.
        Plan.reset()
        logWarn("down-block undiggable, planning route")
    end
end, function()
    Plan.reset()
    Movement.cancel()
    Ores.clearCache()
end)

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
-- Auto rejoin
---------------------------------------------------------------------------

-- Roblox shows the disconnect dialog as
-- `CoreGui.RobloxPromptGui.promptOverlay.ErrorPrompt`. When the option is on the
-- bot teleports back to the same place instead of sitting on the error screen.
--
-- Executors are never expected to be graceful here: the game is already gone, so
-- the teleport is retried on a timer until the client actually leaves.

local Rejoin = {
    enabled = false,
    attached = false,
    busy = false,
}

function Rejoin.teleport()
    local ok = pcall(function()
        TeleportService:Teleport(game.PlaceId)
    end)

    if ok then
        return true
    end

    -- Client `Teleport` is rate limited and some executors block it;
    -- `TeleportAsync` with the local player is the fallback.
    return pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, { Players.LocalPlayer })
    end)
end

function Rejoin.leave(reason)
    if Rejoin.busy then
        return
    end

    Rejoin.busy = true
    logWarn(("auto rejoin: %s, teleporting to place %d"):format(
        tostring(reason), game.PlaceId))

    task.spawn(function()
        -- Same loop as the classic snippet: keep asking for a teleport until the
        -- client unloads the place.
        while Rejoin.enabled do
            Rejoin.teleport()
            task.wait(Config.rejoinDelay)
        end

        Rejoin.busy = false
    end)
end

function Rejoin.watch()
    if Rejoin.attached then
        return
    end

    Rejoin.attached = true

    task.spawn(function()
        local okGui, coreGui = pcall(function()
            return game:GetService("CoreGui")
        end)

        if not okGui or not coreGui then
            Rejoin.attached = false
            logWarn("auto rejoin: CoreGui unavailable")
            return
        end

        -- The prompt GUI can appear a little after the script runs, but do not
        -- wait forever: leave the toggle able to re-arm.
        local prompt

        for _ = 1, Config.rejoinAttachTries do
            prompt = coreGui:FindFirstChild("RobloxPromptGui")

            if prompt then
                break
            end

            task.wait(1)
        end

        if not prompt then
            Rejoin.attached = false
            logWarn("auto rejoin: RobloxPromptGui not found")
            return
        end

        local overlay = prompt:FindFirstChild("promptOverlay") or prompt:WaitForChild("promptOverlay", 10)

        if not overlay then
            Rejoin.attached = false
            logWarn("auto rejoin: promptOverlay not found")
            return
        end

        local function check(child)
            if child.Name ~= "ErrorPrompt" then
                return
            end

            if not Rejoin.enabled then
                return
            end

            Rejoin.leave("disconnect prompt")
        end

        overlay.ChildAdded:Connect(check)

        -- The prompt can already be on screen when the option is turned on.
        local existing = overlay:FindFirstChild("ErrorPrompt")
        if existing then
            check(existing)
        end
    end)
end

function Rejoin.set(enabled)
    Rejoin.enabled = enabled == true

    if Rejoin.enabled then
        Rejoin.watch()
    end
end

---------------------------------------------------------------------------
-- Auto load
---------------------------------------------------------------------------

-- Before `FullyLoaded` turns true the game waits for a save slot click. With the
-- option on the bot answers with `LoadGameEvent(slot)` itself, so an auto rejoin
-- lands in the chosen save instead of the menu.
--
-- The tries are capped: if the attribute is missing or renamed, the bot must not
-- keep reloading a world that is already running.

local AutoLoad = {
    enabled = false,
    busy = false,
    slot = 1,
    slots = { "1", "2", "3" },
}

function AutoLoad.state()
    local ok, loaded, profile = pcall(function()
        local player = Players.LocalPlayer
        return player:GetAttribute(Config.autoloadLoadedAttr), player:GetAttribute(Config.autoloadProfileAttr)
    end)

    if not ok then
        return nil, nil
    end

    return loaded, profile
end

function AutoLoad.fire()
    return pcall(function()
        ReplicatedStorage:WaitForChild(Config.autoloadEvent, 5):FireServer(AutoLoad.slot)
    end)
end

-- The intro camera loop is a coroutine inside the Intro LocalScript and its
-- stop flag is a script upvalue, so only destroying the whole Intro ScreenGui
-- ends it. Camera restore mirrors the game's own PrepareForGame:
-- subject = Humanoid, type = Custom.
function AutoLoad.cleanup()
    return pcall(function()
        local player = Players.LocalPlayer
        local playerGui = player:FindFirstChild("PlayerGui")

        if playerGui then
            local intro = playerGui:FindFirstChild("Intro")

            if intro then
                intro:Destroy()
                logPrint("autoload: Intro removed")
            end

            local darkness = playerGui:FindFirstChild("Darkness")

            if darkness then
                darkness:Destroy()
                logPrint("autoload: Darkness removed")
            end

            local loadingScreen = playerGui:FindFirstChild("LoadingScreen")
            local frame = loadingScreen and loadingScreen:FindFirstChild("Frame")

            if frame then
                frame.BackgroundTransparency = 1
            end
        end

        local camera = workspace.CurrentCamera

        if camera then
            camera.CameraType = Enum.CameraType.Custom
        end

        local deadline = os.clock() + 10
        local character = player.Character

        while not character and os.clock() < deadline do
            task.wait(0.2)
            character = player.Character
        end

        if character and camera then
            local humanoid = character:WaitForChild("Humanoid", 5)

            if humanoid then
                camera.CameraSubject = humanoid
            end
        end
    end)
end

function AutoLoad.watch()
    if AutoLoad.busy then
        return
    end

    AutoLoad.busy = true

    task.spawn(function()
        for _ = 1, Config.autoloadTries do
            if not AutoLoad.enabled then
                break
            end

            local loaded, profile = AutoLoad.state()

            if loaded == true then
                logPrint(("autoload: loaded, slot %s"):format(tostring(profile)))
                break
            end

            logPrint(("autoload: firing slot %d (loaded=%s)"):format(AutoLoad.slot, tostring(loaded)))

            if AutoLoad.fire() then
                AutoLoad.cleanup()
            end

            task.wait(Config.autoloadDelay)
        end

        AutoLoad.busy = false
    end)
end

function AutoLoad.set(enabled)
    AutoLoad.enabled = enabled == true

    if AutoLoad.enabled then
        AutoLoad.watch()
    end
end

---------------------------------------------------------------------------
-- Anti-AFK
---------------------------------------------------------------------------
--
-- Roblox disconnects a client after 20 minutes without user input; bot
-- movement and FireServer calls do not count. Two layers, the same shape as
-- Infinite Yield's `antiafk`:
--   1. drop the client's own `Player.Idled` handlers through the executor
--      `getconnections` API, so the inactivity prompt never starts;
--   2. feed a real virtual input event on `Idled` and on a 4-minute timer.
--
-- Layer 1 is local-client only: a game-side AFK check that counts replicated
-- actions cannot be fooled from the client.

local AntiAfk = {
    enabled = true,
    bound = false,
    presses = 0,
    last = 0,
}

-- `VirtualInputManager` is not a published service, but executors let scripts
-- create it; Infinite Yield uses `Instance.new("VirtualInputManager")` and
-- `SendMouseButtonEvent` for the same reset. A real mouse event at (0, 0) is the
-- strongest reset because it goes through the input pipeline.
local function virtualMouse()
    return pcall(function()
        local manager = Instance.new("VirtualInputManager")
        manager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        manager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        manager:Destroy()
    end)
end

local function virtualClick()
    if virtualMouse() then
        return true
    end

    local virtualUser = game:FindService("VirtualUser")

    if virtualUser then
        local ok = pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.zero)
        end)

        if ok then
            return true
        end
    end

    local ok = pcall(function()
        local input = game:GetService("VirtualInputManager")
        input:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        input:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)

    if ok then
        return true
    end

    if type(keypress) == "function" then
        local pressed = pcall(keypress, 0x20)

        if pressed then
            task.wait(0.05)

            if type(keyrelease) == "function" then
                pcall(keyrelease, 0x20)
            end

            return true
        end
    end

    return false
end

-- Disconnect the handlers the client installed on `Idled`. This is what
-- actually removes the 20-minute disconnect instead of only resetting the
-- timer; the synthetic input below is the fallback when `getconnections` is
-- unavailable or a handler is attached again later.
function AntiAfk.silence()
    if type(getconnections) ~= "function" then
        return 0
    end

    local ok, connections = pcall(getconnections, Players.LocalPlayer.Idled)

    if not ok or type(connections) ~= "table" then
        return 0
    end

    local removed = 0

    for _, connection in ipairs(connections) do
        pcall(function() connection:Disable() end)
        pcall(function() connection:Disconnect() end)
        removed = removed + 1
    end

    if removed > 0 then
        logPrint(("anti-afk: disabled %d Idled handler(s)"):format(removed))
    end

    return removed
end

function AntiAfk.press(reason)
    if not AntiAfk.enabled then
        return false
    end

    local now = os.clock()

    if now - AntiAfk.last < 1 then
        return false
    end

    AntiAfk.last = now
    local pressed = virtualClick()

    if not pressed then
        if not AntiAfk.warned then
            AntiAfk.warned = true
            logWarn("anti-afk: no virtual input available, idle kick still possible")
        end

        return false
    end

    AntiAfk.presses = AntiAfk.presses + 1

    if AntiAfk.presses == 1 or AntiAfk.presses % 10 == 0 then
        logPrint(("anti-afk: input %d (%s)"):format(AntiAfk.presses, tostring(reason)))
    end

    return true
end

function AntiAfk.bind()
    if AntiAfk.bound then
        return
    end

    AntiAfk.bound = true
    AntiAfk.silence()

    task.spawn(function()
        -- CoreScripts can install their `Idled` handler a few seconds after the
        -- first script runs: silence once more, then keep our own handler.
        task.wait(3)
        AntiAfk.silence()

        pcall(function()
            AntiAfk.connection = Players.LocalPlayer.Idled:Connect(function()
                AntiAfk.press("idled")
            end)
        end)
    end)

    task.spawn(function()
        while true do
            task.wait(Config.antiAfkInterval)

            if AntiAfk.enabled then
                AntiAfk.press("timer")
            end
        end
    end)
end

-- Saved toggle. Enabling binds the handlers once; disabling only stops the
-- synthetic input and the timer press. The `Idled` handlers removed by
-- `silence` stay removed (an executor cannot restore them) — see
-- `docs/game/instructions/anti-afk.md`.
function AntiAfk.set(enabled)
    AntiAfk.enabled = enabled == true

    if AntiAfk.enabled then
        AntiAfk.bind()
    end
end

---------------------------------------------------------------------------
-- Saved options
---------------------------------------------------------------------------

-- Everything the bot remembers between executions. One line per option: the
-- registry handles validation, defaults and the restore hook, the UI only calls
-- `Settings.read(key)` and `Settings.write(key, value)`.
--
-- Deliberately NOT saved: `Disable 3D render`. It is a per-session switch the
-- user sets by hand.

Settings.define("mode", {
    kind = "number", min = 1, max = #Modes.list, round = 1, default = 1,
})

Settings.define("farmEnabled", {
    kind = "bool", default = false,
})

Settings.define("instantMove", {
    kind = "bool", default = Config.instantMove,
    apply = function(value) Config.instantMove = value end,
})

Settings.define("tweenSpeed", {
    kind = "number", min = 20, max = 400, round = 1, default = Config.tweenSpeed,
    apply = function(value) Config.tweenSpeed = value end,
})

Settings.define("oreNames", {
    kind = "names", default = "all",
})

Settings.define("sellEnabled", {
    kind = "bool", default = Sell.enabled,
    apply = function(value) Sell.enabled = value end,
})

Settings.define("sellNames", {
    kind = "names", default = "none",
})

Settings.define("forgeEnabled", {
    kind = "bool", default = false,
    apply = function(value) Forge.enabled = value end,
})

Settings.define("forgeOres", {
    kind = "names", default = "none",
})

Settings.define("forgeFuels", {
    kind = "names", default = "none",
})

Settings.define("verboseLogs", {
    kind = "bool", default = Log.enabled,
    apply = function(value) Log.enabled = value end,
})

Settings.define("autoRejoin", {
    kind = "bool", default = false,
    apply = function(value) Rejoin.set(value) end,
})

Settings.define("autoloadSlot", {
    kind = "number", min = 1, max = #AutoLoad.slots, round = 1, default = AutoLoad.slot,
    apply = function(value) AutoLoad.slot = value end,
})

Settings.define("autoloadEnabled", {
    kind = "bool", default = false,
    apply = function(value) AutoLoad.set(value) end,
})

Settings.define("logsWindow", {
    kind = "bool", default = true,
})

Settings.define("antiAfk", {
    kind = "bool", default = true,
    apply = function(value) AntiAfk.set(value) end,
})

---------------------------------------------------------------------------
-- Render cover
---------------------------------------------------------------------------

-- Black full-screen frame shown while 3D rendering is off. Max int DisplayOrder
-- and ZIndex put it above every other ScreenGui. The frame is not Active so
-- input still reaches the UI toggle underneath.
local RenderCover = { gui = nil }

function RenderCover.set(visible)
    if visible then
        if not RenderCover.gui then
            local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

            local gui = Instance.new("ScreenGui")
            gui.Name = "NM2_RenderCover"
            gui.ResetOnSpawn = false
            gui.IgnoreGuiInset = true
            gui.DisplayOrder = 2147483647
            gui.Parent = playerGui

            local frame = Instance.new("Frame")
            frame.Name = "Cover"
            frame.Size = UDim2.fromScale(1, 1)
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frame.BorderSizePixel = 0
            frame.ZIndex = 2147483647
            frame.Parent = gui

            RenderCover.gui = gui
        end

        RenderCover.gui.Enabled = true
    elseif RenderCover.gui then
        RenderCover.gui.Enabled = false
    end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local Ui = {}

-- Venyx UI: `library.new(title)`, then `page:addSection`, then
-- `section:addToggle/addButton/addSlider/addDropdown/addTextbox/addKeybind`.
-- There is no multi-select widget, so `Ui.selection` builds one from toggles.
function Ui.load()
    if type(readfile) == "function" then
        for _, path in ipairs({ "vendor/uilib/source.lua", "vendor\\uilib\\source.lua" }) do
            local okRead, source = pcall(readfile, path)

            if okRead and type(source) == "string" and source ~= "" then
                local ok, library = pcall(function()
                    return loadstring(source)()
                end)
                if ok and type(library) == "table" then
                    return library
                end
            end
        end
    end
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/GreenDeno/Venyx-UI-Library/main/source.lua"))()
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
            Blocks.model() and "ok" or "missing"
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

-- Venyx has no Selection widget: a selection is one toggle per entry. The
-- adapter keeps the `getSelected()`/`setSelected()` interface used by
-- `Ores`/`Sell` and by `Settings.bindSelection`, with indexes into `names`.
function Ui.selection(names, indexes)
    local selected = {}
    local widget = { version = 0 }

    function widget.setSelected(index, state)
        index = math.floor(tonumber(index) or 0)

        if names[index] then
            local value = state == true or nil

            if selected[index] ~= value then
                selected[index] = value
                widget.version = widget.version + 1
            end
        end
    end

    function widget.getVersion()
        return widget.version
    end

    function widget.getSelected()
        local list = {}

        for index = 1, #names do
            if selected[index] then
                table.insert(list, index)
            end
        end

        return list
    end

    -- Toggles are created with the saved state; `addToggle` does not fire its
    -- callback for the default value, so restoring never writes the file.
    function widget.add(section, index)
        local name = names[index]

        if not name then
            return
        end

        section:addToggle(name, selected[index] == true, function(state)
            widget.setSelected(index, state)
        end)
    end

    function widget.build(section)
        for index = 1, #names do
            widget.add(section, index)

            -- Each toggle is several new instances; a large ore list built in
            -- one frame is the biggest startup spike in the script.
            if index % 20 == 0 then
                task.wait()
            end
        end
    end

    for _, index in ipairs(indexes or {}) do
        widget.setSelected(index, true)
    end

    return widget
end

---------------------------------------------------------------------------
-- UI adaptation (mobile size, scrollable tabs, titlebar collapse)
---------------------------------------------------------------------------

local UI_WIDTH = 511
local UI_HEIGHT = 428
local UI_TITLE = 38

local function viewportSize()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize

    if not size or size.X <= 0 or size.Y <= 0 then
        return Vector2.new(1280, 720)
    end

    return size
end

-- uilib's `DraggingEnabled` is mouse-only. Touch needs the same translation
-- (drag origin + delta in offsets), used by both the main window and the log
-- window. The main window keeps its mobile-only call: on PC its position is
-- still scale-based until `layout()` runs.
function Ui.enableTouchDrag(main, topbar)
    local dragging, dragStart, dragOrigin

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        dragging = true
        dragStart = input.Position
        dragOrigin = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        main.Position = UDim2.fromOffset(
            dragOrigin.X.Offset + delta.X,
            dragOrigin.Y.Offset + delta.Y
        )
    end)
end

-- uilib hardcodes a 511x428 window at `(0.25, 0)` (off-screen on a phone),
-- gives the tab strip a fixed 314 px canvas without a scrollbar, and hides the
-- window only through a keybind. `Ui.adapt` keeps the widget tree and changes
-- only layout and the collapse behaviour.
function Ui.adapt(window)
    local main = window.container.Main
    local topbar = main.TopBar
    local pagesPanel = main.Pages
    local tabs = pagesPanel.Pages_Container
    local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    -- Tab strip: AutomaticCanvasSize follows the UIListLayout, so every page
    -- stays reachable and touch-drag scrolls the list.
    tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabs.ScrollBarThickness = 3
    tabs.ScrollBarImageColor3 = Color3.fromRGB(14, 14, 14)
    tabs.ScrollingEnabled = true

    -- Page content: same automatic canvas, so long sections scroll on a short
    -- screen instead of being cut at the library's fixed canvas height.
    for _, page in ipairs(window.pages) do
        local container = page.container

        container.AutomaticCanvasSize = Enum.AutomaticSize.Y
        container.CanvasSize = UDim2.new(0, 0, 0, 0)
        container.ScrollBarThickness = 3
        container.ScrollBarImageColor3 = Color3.fromRGB(14, 14, 14)
        container.ScrollingEnabled = true

        local resize = page.Resize

        -- The library sets the bar transparency to `size > height`, i.e. hides
        -- the bar exactly when the page can scroll.
        page.Resize = function(self, scroll)
            resize(self, scroll)
            self.container.ScrollBarImageTransparency =
                self.container.AbsoluteCanvasSize.Y > self.container.AbsoluteSize.Y and 0 or 1
        end
    end

    topbar.Title.Size = UDim2.new(1, -74, 0, 16)

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "Collapse"
    closeButton.AnchorPoint = Vector2.new(1, 0.5)
    closeButton.Position = UDim2.new(1, -6, 0.5, 0)
    closeButton.Size = UDim2.fromOffset(28, 28)
    closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    closeButton.BorderSizePixel = 0
    closeButton.AutoButtonColor = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "-"
    closeButton.ZIndex = 6
    closeButton.Parent = topbar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = closeButton

    local collapsed = false
    local placed = false
    local tabsWidth = 126

    local function layout()
        local viewport = viewportSize()
        local height = math.max(220, math.min(UI_HEIGHT, viewport.Y - 16))

        if not mobile then
            main.Size = UDim2.fromOffset(UI_WIDTH, collapsed and UI_TITLE or UI_HEIGHT)
            return
        end

        local width = math.max(240, math.min(UI_WIDTH, viewport.X - 16))
        tabsWidth = math.clamp(math.floor(width * 0.3), 116, 126)

        pagesPanel.Size = UDim2.new(0, tabsWidth, 1, -UI_TITLE)

        for _, page in ipairs(window.pages) do
            page.container.Position = UDim2.fromOffset(tabsWidth + 8, UI_TITLE + 8)
            page.container.Size = UDim2.new(1, -(tabsWidth + 16), 1, -(UI_TITLE + 18))
        end

        main.Size = UDim2.fromOffset(width, collapsed and UI_TITLE or height)

        if not placed then
            placed = true
            main.Position = UDim2.fromOffset(
                math.floor((viewport.X - width) / 2),
                math.floor((viewport.Y - height) / 2)
            )
        else
            local current = main.Position

            main.Position = UDim2.fromOffset(
                math.clamp(current.X.Offset, 0, math.max(0, viewport.X - width)),
                math.clamp(current.Y.Offset, 0, math.max(0, viewport.Y - (collapsed and UI_TITLE or height)))
            )
        end
    end

    local function setCollapsed(state)
        collapsed = state == true
        main.ClipsDescendants = collapsed
        closeButton.Text = collapsed and "+" or "-"

        for _, page in ipairs(window.pages) do
            page.container.Visible = not collapsed and window.focusedPage == page
        end

        layout()
    end

    -- Replaces `library:toggle` (keybind only): the body collapses to the
    -- titlebar, and the titlebar button restores it.
    window.toggle = function()
        setCollapsed(not collapsed)
    end

    closeButton.MouseButton1Click:Connect(function()
        setCollapsed(not collapsed)
    end)

    if mobile then
        Ui.enableTouchDrag(main, topbar)
    end

    local camera = workspace.CurrentCamera

    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            pcall(layout)
        end)
    end

    layout()
end

function Ui.create()
    local library = Ui.load()
    local window = library.new("nazar mining 2")

    local savedMode = Settings.read("mode")
    local savedEnabled = Settings.read("farmEnabled")
    local savedInstant = Settings.read("instantMove")
    local savedTween = Settings.read("tweenSpeed")
    local savedVerbose = Settings.read("verboseLogs")
    local savedRejoin = Settings.read("autoRejoin")
    local savedSellEnabled = Settings.read("sellEnabled")
    local savedForge = Settings.read("forgeEnabled")
    local savedAutoload = Settings.read("autoloadEnabled")
    local savedAutoloadSlot = Settings.read("autoloadSlot")

    local modeNames = {}

    for _, mode in ipairs(Modes.list) do
        table.insert(modeNames, mode.name)
    end

    savedMode = math.clamp(math.floor(tonumber(savedMode) or 1), 1, #modeNames)

    -- `noRender` is a session switch: never restored. Venyx dropdowns do not
    -- fire their callback when the label is restored, so the saved mode is
    -- started explicitly at the end of this function.
    local enabled = savedEnabled

    local main = window:addPage("Main")
    local modeSection = main:addSection("Mode")

    local modeDropdown
    modeDropdown = modeSection:addDropdown("Category", modeNames, function(value)
        for index, name in ipairs(modeNames) do
            if name == value then
                Settings.write("mode", index)
                Modes.select(Modes.list[index])

                if enabled then
                    Modes.enable(Modes.list[index])
                end

                return
            end
        end
    end)

    -- The search box doubles as the label of the picked entry.
    modeDropdown.Search.TextBox.Text = modeNames[savedMode]

    modeSection:addToggle("Enabled", savedEnabled, function(state)
        enabled = state
        Settings.write("farmEnabled", state)

        if state then
            Modes.enable(Modes.active)
        else
            for _, mode in ipairs(Modes.list) do
                mode:stop()
            end
        end
    end)

    local moveSection = main:addSection("Movement")

    moveSection:addToggle("Instant move", savedInstant, function(state)
        Settings.write("instantMove", state)
    end)

    moveSection:addSlider("Tween speed", savedTween, 20, 400, function(value)
        Settings.write("tweenSpeed", value)
    end)

    local oreSection = main:addSection("Farm ores")
    local names = Ores.names()
    local oreWidget = Ui.selection(names, Settings.selection("oreNames", "ores", names))

    oreWidget.build(oreSection)
    Ores.bindSelection(oreWidget, names)
    Settings.bindSelection("oreNames", names, oreWidget)

    local uiSection = main:addSection("UI")

    uiSection:addKeybind("Menu key", Enum.KeyCode.RightControl, function()
        window:toggle()
    end)

    local sellPage = window:addPage("Auto sell")
    local sellSection = sellPage:addSection("Auto sell")

    sellSection:addToggle("Enabled", savedSellEnabled, function(state)
        Settings.write("sellEnabled", state)
        logPrint("autosell toggle " .. (state and "on" or "off"))
    end)

    sellSection:addButton("Sell now", function()
        task.spawn(function()
            local ok, sold = pcall(Sell.manual)

            if ok then
                logPrint("manual sell total " .. tostring(sold))
            else
                logWarn("manual sell error: " .. tostring(sold))
            end
        end)
    end)

    local sellNames = Sell.names()
    local sellWidget = Ui.selection(
        sellNames,
        Settings.selection("sellNames", "sellSelected", sellNames)
    )

    Sell.bindSelection(sellWidget, sellNames)
    Settings.bindSelection("sellNames", sellNames, sellWidget)

    -- One section per category: Ores, Mushrooms, Smelted. All of them write the
    -- same `sellNames` key through the one widget.
    local sellIndex = {}

    for index, name in ipairs(sellNames) do
        sellIndex[name] = index
    end

    local built = 0

    for _, group in ipairs(Sell.groups()) do
        if #group.names > 0 then
            local section = sellPage:addSection(group.title)

            for _, name in ipairs(group.names) do
                local index = sellIndex[name]

                if index then
                    sellWidget.add(section, index)
                    built += 1

                    -- Startup builds every toggle in one frame otherwise.
                    if built % 20 == 0 then
                        task.wait()
                    end
                end
            end
        end
    end

    local forgePage = window:addPage("Forge")
    local forgeSection = forgePage:addSection("Forge")

    forgeSection:addToggle("Service on surface", savedForge, function(state)
        Settings.write("forgeEnabled", state)
        logPrint("forge service " .. (state and "on" or "off"))
    end)

    forgeSection:addButton("Service now", function()
        task.spawn(function()
            local ok, serviced = pcall(Forge.trip, "manual")

            if ok then
                logPrint("forge trip " .. tostring(serviced))
            else
                logWarn("forge trip error: " .. tostring(serviced))
            end
        end)
    end)

    local forgeOres = Forge.oreNames()
    local forgeOreWidget = Ui.selection(forgeOres, Settings.selection("forgeOres", nil, forgeOres))
    local forgeOreSection = forgePage:addSection("Ores to smelt")

    forgeOreWidget.build(forgeOreSection)
    Forge.bindInput(forgeOreWidget, forgeOres)
    Settings.bindSelection("forgeOres", forgeOres, forgeOreWidget)

    local forgeFuels = Forge.fuelNames()
    local forgeFuelWidget = Ui.selection(forgeFuels, Settings.selection("forgeFuels", nil, forgeFuels))
    local forgeFuelSection = forgePage:addSection("Fuel")

    forgeFuelWidget.build(forgeFuelSection)
    Forge.bindFuel(forgeFuelWidget, forgeFuels)
    Settings.bindSelection("forgeFuels", forgeFuels, forgeFuelWidget)

    local sessionPage = window:addPage("Session")
    local rejoinSection = sessionPage:addSection("Auto rejoin")

    rejoinSection:addToggle("Auto rejoin", savedRejoin, function(state)
        Settings.write("autoRejoin", state)
        logPrint("auto rejoin " .. (state and "on" or "off"))
    end)

    local loadSection = sessionPage:addSection("Auto load")
    local slotDropdown
    slotDropdown = loadSection:addDropdown("Save slot", AutoLoad.slots, function(value)
        Settings.write("autoloadSlot", value)
    end)

    slotDropdown.Search.TextBox.Text = tostring(savedAutoloadSlot)

    loadSection:addToggle("Autoload", savedAutoload, function(state)
        Settings.write("autoloadEnabled", state)
        logPrint("autoload " .. (state and "on" or "off"))
    end)

    local afkSection = sessionPage:addSection("Anti AFK")

    afkSection:addToggle("Anti AFK", Settings.read("antiAfk"), function(state)
        Settings.write("antiAfk", state)
        logPrint("anti-afk " .. (state and "on" or "off"))
    end)

    local debugPage = window:addPage("Debug")
    local statsSection = debugPage:addSection("Stats")

    local pickaxeInput = statsSection:addTextbox("Pickaxe")
    local handleInput = statsSection:addTextbox("Handle")
    local playerInput = statsSection:addTextbox("Player")
    local stateInput = statsSection:addTextbox("State")

    -- The library flashes a textbox whenever its text changes; 1% image
    -- transparency keeps the readout from pulsing on every refresh.
    for _, input in ipairs({ pickaxeInput, handleInput, playerInput, stateInput }) do
        input.Button.ImageTransparency = 0.01
    end

    local logSection = debugPage:addSection("Logs")

    logSection:addToggle("Logs window", Settings.read("logsWindow"), function(state)
        LogView.setEnabled(state)
        Settings.write("logsWindow", state)
    end)

    logSection:addToggle("Verbose logs", savedVerbose, function(state)
        Log.enabled = state
        Settings.write("verboseLogs", state)
    end)

    logSection:addToggle("Disable 3D render", false, function(state)
        -- Per-session switch: deliberately not saved.
        pcall(function()
            RunService:Set3dRenderingEnabled(not state)
        end)
        RenderCover.set(state)
    end)

    logSection:addButton("Print stats", function()
        task.spawn(Ui.printStats)
    end)

    -- Selection toggles write through `Settings.bindSelection`, which is polled
    -- by the scheduler. Separate job from the stats readout: a failing stat must
    -- never stop the options from being saved. `Settings.persist` skips
    -- unchanged JSON.
    Scheduler.every(0.5, Settings.flushSelections)

    local statFailures = 0
    local statsStopped = false

    Scheduler.every(3, function()
        -- Cosmetic only: keep retrying a few times, then stop spamming.
        if statsStopped then
            return
        end

        local ok = pcall(function()
            local stats = Ui.stats()
            statsSection:updateTextbox(pickaxeInput, nil, stats.pickaxe)
            statsSection:updateTextbox(handleInput, nil, stats.handle)
            statsSection:updateTextbox(playerInput, nil, stats.player)
            statsSection:updateTextbox(stateInput, nil, stats.state)
        end)

        if ok then
            statFailures = 0
        else
            statFailures = statFailures + 1

            if statFailures >= 5 then
                statsStopped = true
            end
        end
    end)

    Modes.select(Modes.list[savedMode])

    if enabled then
        Modes.enable(Modes.list[savedMode])
    end

    -- Venyx hides every page until one is selected.
    task.spawn(function()
        local ok, err = pcall(function()
            window:SelectPage(window.pages[1], true)
        end)

        if not ok then
            logWarn("ui page select failed: " .. tostring(err))
        end
    end)

    -- Cosmetic only: a failed adaptation must never remove the window.
    local adapted, adaptError = pcall(Ui.adapt, window)

    if not adapted then
        logWarn("ui adapt failed: " .. tostring(adaptError))
    end

    return window
end

---------------------------------------------------------------------------
-- Log view (uilib window)
---------------------------------------------------------------------------
--
-- Same library instance shape as the main window, but a separate `Ui.load()`
-- execution: each library instance owns its own `utility` keybind table, so the
-- second window cannot reset or double-fire the main window's menu keybind.

function LogView.render(lines)
    if not LogView.enabled or not LogView.label then
        return
    end

    LogView.label.Text = table.concat(lines, "\n")

    -- `CanvasPosition` is clamped to the canvas, so a huge Y means "bottom".
    if LogView.scroll then
        LogView.scroll.CanvasPosition = Vector2.new(0, 1e6)
    end
end

function LogView.setEnabled(enabled)
    LogView.enabled = enabled == true

    if LogView.gui then
        LogView.gui.Enabled = LogView.enabled
    end

    if LogView.enabled then
        LogView.render(Log.lines)
    end
end

function LogView.setCollapsed(state)
    local main = LogView.main
    if not main then
        return
    end

    LogView.collapsed = state == true
    main.ClipsDescendants = LogView.collapsed
    main.Size = UDim2.fromOffset(
        LogView.width,
        LogView.collapsed and UI_TITLE or LogView.height
    )

    if LogView.scroll then
        LogView.scroll.Visible = not LogView.collapsed
    end

    if LogView.button then
        LogView.button.Text = LogView.collapsed and "+" or "-"
    end
end

function LogView.create()
    if LogView.window then
        return LogView.gui
    end

    local library = Ui.load()
    local window = library.new("nm2 logs")
    local main = window.container.Main
    local topbar = main.TopBar
    local viewport = viewportSize()
    local width = math.max(240, math.min(520, viewport.X - 20))

    -- No pages: the window body is the log itself, so the library's tab column
    -- is removed instead of leaving an empty sidebar.
    main.Pages.Visible = false
    main.Size = UDim2.fromOffset(width, LogView.height)
    main.Position = UDim2.fromOffset(10, math.max(10, viewport.Y - LogView.height - 10))
    main.ClipsDescendants = false

    topbar.Title.Size = UDim2.new(1, -74, 0, 16)

    local button = Instance.new("TextButton")
    button.Name = "Collapse"
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -6, 0.5, 0)
    button.Size = UDim2.fromOffset(28, 28)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamBold
    button.TextSize = 16
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "-"
    button.ZIndex = 6
    button.Parent = topbar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = button

    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = "LogScroll"
    scroll.Parent = main
    scroll.Position = UDim2.fromOffset(8, UI_TITLE + 8)
    scroll.Size = UDim2.new(1, -16, 1, -(UI_TITLE + 14))
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(14, 14, 14)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollingEnabled = true
    scroll.ZIndex = 2

    local label = Instance.new("TextLabel")
    label.Name = "LogText"
    label.Parent = scroll
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -6, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.Text = ""
    label.ZIndex = 2

    LogView.window = window
    LogView.gui = window.container
    LogView.main = main
    LogView.scroll = scroll
    LogView.label = label
    LogView.button = button
    LogView.width = width

    button.MouseButton1Click:Connect(function()
        LogView.setCollapsed(not LogView.collapsed)
    end)

    -- Mouse drag comes from `library.new`; touch needs the same translation.
    Ui.enableTouchDrag(main, topbar)

    Log.render = LogView.render
    Log.dirty = false
    LogView.render(Log.lines)
    LogView.setEnabled(Settings.read("logsWindow"))

    return LogView.gui
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

-- Apply every saved option (movement method, tween speed, logs, auto sell, auto
-- rejoin, auto load) before the UI is built. Options with an `apply` hook live in the
-- registry, so this is the only restore call in the script.
Settings.restore()

Forge.bind()

local logOk, logErr = pcall(LogView.create)
if not logOk then
    warn("[main] logs failed: " .. tostring(logErr))
end

-- Deferred log rendering: one TextLabel write per interval, not per line. Runs
-- outside `Ui.create` so the panel still updates if the window fails to build.
Scheduler.every(Config.logRenderInterval, Log.flush)

local ok, window = pcall(Ui.create)
if not ok or not window then
    warn("[main] ui failed: " .. tostring(window))
end

-- Auto sell must work even when no mode is running: check every second.
Scheduler.every(1, function()
    local ok, err = pcall(Sell.try, "watch")
    if not ok then
        logWarn("autosell watch error: " .. tostring(err))
    end
end)

Scheduler.start()

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
    local mine = Blocks.model()
    local count = Blocks.count()
    local sample

    if mine then
        local map = Blocks.map()

        for _, block in pairs(map or {}) do
            sample = block
            break
        end
    end

    print(("[main] mine=%s blocks=%d pickaxe=%s ores=%d"):format(
        mine and "yes" or "no",
        count,
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

    print("[main] F1 farm, F2 mushrooms, RightControl menu")
end)

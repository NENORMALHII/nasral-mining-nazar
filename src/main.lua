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

    mineTimeSafety = 0.18,
    mineJitterMin = 0.05,
    mineJitterMax = 0.15,
    minePreSwingMin = 0.04,
    minePreSwingMax = 0.12,
    mineSwingMin = 0.02,
    mineSwingMax = 0.08,
    mineRejectGrace = 0.6,

    mushroomDelay = 0.35,
    mushroomIgnore = 5,

    mineName = "Mine",
    oreRange = 160,
    oreCacheTime = 2,
    depthWeight = 8,
    shaftDig = true,
    lootDwell = 0.12,
    lootAttempts = 2,
    lootSpawnWait = 0.35,
    lootSyncInterval = 0.5,

    surfaceY = -1,
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

local function escapePattern(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
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
    { "Material", "Pickaxe", "PickaxeType", "ToolType", "ToolClass" }
)

Mining.handleAttrs = attrList(
    Game.Constants and Game.Constants.ATTR_TOOL_WOOD_MATERIAL,
    { "WoodMaterial", "Handle", "Wood" }
)

local function attributeEntries(pickaxe, names)
    local entries = {}

    for _, name in ipairs(names) do
        local value = pickaxe:GetAttribute(name)
        if value ~= nil then
            table.insert(entries, { name = name, value = value })
        end
    end

    return entries
end

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

local function findChildPath(root, names)
    local current = root

    for _, name in ipairs(names) do
        if not current then
            return nil
        end
        current = current:FindFirstChild(name)
    end

    return current
end

local function tooltipModules()
    local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
    if not scripts then
        return {}
    end

    local modules = {}

    for _, path in ipairs({
        { "Modules", "Gui", "TooltipBuilder" },
        { "Modules", "Gui", "Backpack", "Tooltip" },
        { "Modules", "Gui", "NativeTooltip" },
    }) do
        local module = findChildPath(scripts, path)
        if module and module:IsA("ModuleScript") then
            table.insert(modules, module)
        end
    end

    return modules
end

local function textOf(instance)
    local ok, text = pcall(function()
        return instance.Text
    end)

    if ok and type(text) == "string" and text ~= "" then
        return text
    end

    ok, text = pcall(function()
        return instance.ContentText
    end)

    if ok and type(text) == "string" and text ~= "" then
        return text
    end

    return nil
end

local function collectText(value, out, depth)
    if depth > 8 or #out > 120 then
        return
    end

    local kind = typeof(value)

    if kind == "string" then
        if value ~= "" then
            table.insert(out, value)
        end
        return
    end

    if kind == "number" then
        table.insert(out, tostring(value))
        return
    end

    if kind == "Instance" then
        local text = textOf(value)
        if text then
            table.insert(out, text)
        end

        if value:IsA("GuiObject") then
            for _, descendant in ipairs(value:GetDescendants()) do
                local childText = textOf(descendant)
                if childText then
                    table.insert(out, childText)
                end
            end
        end
        return
    end

    if kind == "table" then
        for key, item in pairs(value) do
            if type(key) == "string" then
                table.insert(out, key)
            end
            collectText(item, out, depth + 1)
        end
    end
end

local function tooltipText(pickaxe)
    local chunks = {}

    pcall(function()
        local toolTip = pickaxe.ToolTip
        if type(toolTip) == "string" and toolTip ~= "" then
            table.insert(chunks, toolTip)
        end
    end)

    pcall(function()
        for _, module in ipairs(tooltipModules()) do
            local ok, built = pcall(require, module)
            if not ok or type(built) ~= "table" then
                continue
            end

            for key, fn in pairs(built) do
                if type(fn) ~= "function" or type(key) ~= "string" then
                    continue
                end

                local lower = key:lower()
                if not (lower:find("build") or lower:find("content") or lower:find("lines")) then
                    continue
                end

                local okCall, result = pcall(fn, pickaxe)
                if not okCall or result == nil then
                    okCall, result = pcall(fn, pickaxe, 1)
                end
                if not okCall or result == nil then
                    okCall, result = pcall(fn, { Tool = pickaxe }, 1)
                end

                if okCall and result ~= nil then
                    collectText(result, chunks, 0)
                end
            end
        end
    end)

    pcall(function()
        local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not gui then
            return
        end

        for _, object in ipairs(gui:GetDescendants()) do
            if object.Name == "Tooltip" and object:IsA("GuiObject") and object.Visible then
                for _, descendant in ipairs(object:GetDescendants()) do
                    local text = textOf(descendant)
                    if text then
                        table.insert(chunks, text)
                    end
                end
            end
        end
    end)

    return table.concat(chunks, "\n")
end

local function pickaxeFromText(text)
    if not Game.Pickaxes or text == "" then
        return nil
    end

    local lower = text:lower()

    for key in pairs(Game.Pickaxes) do
        if lower:find(key:lower(), 1, true) then
            return key
        end
    end

    return nil
end

local function handleFromText(text)
    if not Game.Handles or text == "" then
        return nil
    end

    local lower = text:lower()

    for key in pairs(Game.Pickaxes or {}) do
        lower = lower:gsub(escapePattern(key:lower()), "")
    end

    for key in pairs(Game.Handles) do
        local needle = key:lower()
        if lower:find(needle .. " handle", 1, true)
            or lower:find("handle " .. needle, 1, true)
            or lower:find(needle .. " wood", 1, true)
            or lower:find("wood " .. needle, 1, true) then
            return key
        end
    end

    for key in pairs(Game.Handles) do
        local pattern = "%f[%a]" .. escapePattern(key:lower()) .. "%f[%A]"
        if lower:find(pattern) then
            return key
        end
    end

    return nil
end

local function resolvePickaxe(pickaxe, text)
    local entries = attributeEntries(pickaxe, Mining.pickaxeAttrs)
    table.insert(entries, { name = "Name", value = pickaxe.Name })

    for _, entry in ipairs(entries) do
        local key = matchTable(Game.Pickaxes, entry.value)
        if key then
            return Game.Pickaxes[key], key, entry.name
        end
    end

    local head = headPart(pickaxe)
    if head and Game.Pickaxes then
        for key, info in pairs(Game.Pickaxes) do
            if info.Material == head.Material and colorMatches(info.Color, head.Color) then
                return info, key, "head"
            end
        end
    end

    local textKey = pickaxeFromText(text)
    if textKey then
        return Game.Pickaxes[textKey], textKey, "tooltip"
    end

    return nil
end

local function resolveHandle(pickaxe, text)
    for _, entry in ipairs(attributeEntries(pickaxe, Mining.handleAttrs)) do
        local key = matchTable(Game.Handles, entry.value)
        if key then
            return key, entry.name
        end
    end

    local textKey = handleFromText(text)
    if textKey then
        return textKey, "tooltip"
    end

    local handlePart = pickaxe:FindFirstChild("Handle")
    if handlePart and handlePart:IsA("BasePart") and Game.Handles then
        for key, info in pairs(Game.Handles) do
            if colorMatches(info.Color, handlePart.Color) then
                if info.Material == nil or info.Material == handlePart.Material then
                    return key, "handle-part"
                end
            end
        end
    end

    return nil
end

local detectCache = setmetatable({}, { __mode = "k" })

function Mining.signature(pickaxe)
    local parts = { pickaxe.Name }
    local attributes = pickaxe:GetAttributes()
    local keys = {}

    for key in pairs(attributes) do
        table.insert(keys, key)
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        table.insert(parts, key .. "=" .. tostring(attributes[key]))
    end

    return table.concat(parts, "|")
end

function Mining.detect(pickaxe)
    if not pickaxe then
        return nil
    end

    local signature = Mining.signature(pickaxe)
    local cached = detectCache[pickaxe]

    if cached and cached.signature == signature then
        return cached
    end

    local result = {
        signature = signature,
        tooltip = tooltipText(pickaxe),
    }

    result.pickaxeInfo, result.pickaxeName, result.pickaxeSource = resolvePickaxe(pickaxe, result.tooltip)
    result.handleName, result.handleSource = resolveHandle(pickaxe, result.tooltip)

    detectCache[pickaxe] = result
    return result
end

function Mining.handleInfo(pickaxe)
    local detected = Mining.detect(pickaxe)
    if not detected then
        return nil
    end

    local name = detected.handleName
    if name and Game.Handles and Game.Handles[name] then
        return Game.Handles[name], name, detected.handleSource
    end

    return nil, name, detected.handleSource
end

function Mining.describe(pickaxe)
    if not pickaxe then
        return "none"
    end

    local parts = {}
    local attributes = pickaxe:GetAttributes()
    local keys = {}

    for key in pairs(attributes) do
        table.insert(keys, key)
    end

    table.sort(keys)

    for _, key in ipairs(keys) do
        table.insert(parts, key .. "=" .. tostring(attributes[key]))
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

function Mining.waitServerBase()
    local deadline = os.clock() + 0.5

    while os.clock() < deadline do
        if type(Mining.serverBase) == "number" and Mining.serverBase > 0 then
            return true
        end
        RunService.Heartbeat:Wait()
    end

    return false
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

    if toolChanged then
        Mining.waitServerBase()
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

    local jitter = math.random() * (Config.mineJitterMax - Config.mineJitterMin) + Config.mineJitterMin
    local baseWait = Mining.mineTime(block) + Config.mineTimeSafety + ping + jitter
    return baseWait
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

    local blocked = { Oil = true, Lava = true, Grass = true, Void = true }
    if blocked[name] then
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

    local modifier = resourceInfo(typeOf(block))
    modifier = modifier and modifier.MineTimeModifier or 1
    local waitTime = Mining.waitTime(block)
    local preSwing = Mining.preSwingDelay()
    local swing = Mining.swingDelay()
    logPrint(("mine %s type=%s base=%.2f toolspeed=%s mod=%.2f wait=%.2f preSwing=%.2f swing=%.2f"):format(
        block.Name,
        tostring(typeOf(block)),
        Mining.baseMineTime,
        tostring(Players.LocalPlayer:GetAttribute("ToolSpeedModifier")),
        modifier,
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
        task.wait(0.03)
    end

    if block.Parent then
        blockEvent:FireServer(vec3ToString(position), { dug = false })
        logWarn("server rejected " .. block.Name .. " (" .. tostring(typeOf(block)) .. ")")
        return false
    end

    return true
end

---------------------------------------------------------------------------
-- Ores
---------------------------------------------------------------------------

local Ores = {}

local cache = {}
local cacheTime = 0
local lastWarning = 0
local ignored = {}
local namesCache
local selectionKey

function Ores.price(name)
    local info = resourceInfo(name)
    if info and info.BasePrice then
        return info.BasePrice
    end
    return 0
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
    Ores.invalidate()
end

function Ores.isSelected(name)
    local selection = Ores.selection
    if not selection then
        return true
    end

    local indices = selection.getSelected()
    if #indices == 0 then
        return false
    end

    for _, index in ipairs(indices) do
        if Ores.namesList[index] == name then
            return true
        end
    end

    return false
end

function Ores.checkSelection()
    local selection = Ores.selection
    if not selection then
        return
    end

    local indices = selection.getSelected()
    local parts = {}

    for _, index in ipairs(indices) do
        table.insert(parts, tostring(index))
    end

    table.sort(parts)
    local key = table.concat(parts, ",")

    if key ~= selectionKey then
        selectionKey = key
        Ores.invalidate()
    end
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
        local reason = Mining.valid(block)

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

        if (not untilIgnore or untilIgnore <= now) and block.Parent then
            local name = typeOf(block)

            if name and Ores.isSelected(name) and Mining.valid(block) == nil then
                local distance = (block.Position - position).Magnitude

                if distance <= Config.oreRange then
                    local blockPosition = block:GetAttribute(Game.attrMinePosition)
                    local price = Ores.price(name)
                    local depth = blockPosition and math.max(0, blockPosition.Y - playerBlock.Y) or 0
                    local score = price
                        + depth * Config.depthWeight
                        + Predictor.hash(blockPosition or block.Position) / 1000

                    if not best or score > bestScore then
                        best, bestDistance, bestScore = block, distance, score
                    end
                end
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

function Loot.playerValue(drop)
    local dropScript = drop:FindFirstChild("DropScript", true)
    local playerValue = dropScript and dropScript:FindFirstChild("Player")
    return playerValue and playerValue.Value
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

local function tryPickup(character, drop)
    for _ = 1, 3 do
        if not drop.Parent then
            return true
        end

        local part = Loot.part(drop)
        if not part or not part.Parent then
            return not drop.Parent
        end

        Movement.to(character, part.Position)
        RunService.Heartbeat:Wait()
        RunService.Heartbeat:Wait()
        task.wait(Config.lootDwell)

        if not drop.Parent then
            return true
        end

        task.wait(0.1)
    end

    return not drop.Parent
end

function Loot.collectAll(character)
    Loot.sync()

    if #Loot.pending == 0 then
        return 0
    end

    table.sort(Loot.pending, function(a, b)
        return Ores.price(Loot.name(a)) > Ores.price(Loot.name(b))
    end)

    local picked = 0

    for index = #Loot.pending, 1, -1 do
        local drop = Loot.pending[index]
        if not drop.Parent then
            Loot.remove(drop)
        elseif tryPickup(character, drop) then
            Loot.remove(drop)
            picked += 1
        end
    end

    Loot.sync()

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

    Ores.checkSelection()

    Loot.sync(true)

    if Loot.count() > 0 then
        for _ = 1, 3 do
            Loot.collectAll(character)
            if Loot.count() == 0 then
                break
            end
            task.wait(0.05)
        end

        if Loot.count() > 0 then
            logPrint("waiting for loot " .. Loot.count())
            task.wait(0.05)
            return
        end
    end

    local function mineBlock(block, label)
        if not block or not block.Parent then
            return false
        end
        if not Mining.prepare(character) then
            logWarn("no pickaxe")
            return false
        end

        logPrint(label .. " " .. block.Name .. " (" .. tostring(typeOf(block)) .. ")")

        Movement.to(character, block.Position)

        if not self.enabled then
            return false
        end

        Movement.hold(character)
        local ok, result = pcall(Mining.mine, character, block)
        Movement.releaseHold()

        if ok and result then
            Ores.invalidate()
            task.wait(Config.lootSpawnWait)
            Loot.sync(true)
            Loot.collectAll(character)
            return true
        end

        return false
    end

    if Config.surfaceDig and Mining.surface(character) then
        mineBlock(Predictor.blockBelow(root.Position), "surface")
        return
    end

    local shaftBlock = Predictor.blockBelow(root.Position)
    if shaftBlock and not Ores.isSelected(typeOf(shaftBlock) or "") then
        mineBlock(shaftBlock, "clear path")
        return
    end

    local ore = Ores.nearest(root.Position)
    if ore then
        if not mineBlock(ore, "target") then
            Ores.ignore(ore)
        end
        return
    end

    if Config.shaftDig then
        mineBlock(shaftBlock, "dig down")
    else
        task.wait(0.1)
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

    local selected = 0
    for _, name in ipairs(Ores.names()) do
        if Ores.isSelected(name) then
            selected += 1
        end
    end

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
            tostring(Predictor.toBlock(character.PrimaryPart.Position).Y),
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
    local info = detected and detected.pickaxeInfo
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

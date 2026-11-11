local Players = game:GetService("Players")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    mushroomDelay = 0.5,
    digDelay = 1.3,
    searchDistance = 12,
    digRemote = "UpdatePickaxe",
    digArg = "instance",

    mineName = "Mine",
    minOreValue = 100,
    oreRange = 500,
    oreSpeed = 40,
    oreStopDistance = 4,
    oreCacheTime = 1,

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
        ["Mithril Ore"] = 300,
        ["Promethium Ore"] = 300,
        ["Malachite Ore"] = 550,
        ["Azurite Ore"] = 550,
    },
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
    if tool:FindFirstChild(Config.digRemote) then
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

function Character.equipPickaxe(character)
    local pickaxe = Character.getPickaxe(character)
    if not pickaxe then
        return nil
    end
    if pickaxe.Parent ~= character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return nil
        end
        humanoid:EquipTool(pickaxe)
    end
    return pickaxe
end

function Character.face(character, position)
    local root = character.PrimaryPart
    if root then
        character:PivotTo(CFrame.lookAt(root.Position, position))
    end
end

function Character.platformStand(character, state)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = state
    end
end

---------------------------------------------------------------------------
-- Physics
---------------------------------------------------------------------------

local Physics = {}

function Physics.attach(root)
    local attachment = Instance.new("Attachment")
    attachment.Name = "OreRunnerAttachment"
    attachment.Parent = root

    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "OreRunnerVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    velocity.VectorVelocity = Vector3.zero
    velocity.Parent = attachment

    return velocity, attachment
end

function Physics.release(velocity, attachment)
    if velocity then
        velocity:Destroy()
    end
    if attachment then
        attachment:Destroy()
    end
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
    return workspace:Raycast(root.Position, Vector3.new(0, -Config.searchDistance, 0), rayParams)
end

---------------------------------------------------------------------------
-- Ores
---------------------------------------------------------------------------

local Ores = {}

local cache = {}
local cacheTime = 0
local ignored = {}

local function isAlive(block)
    if not block.Parent then
        return false
    end
    local dug = block:FindFirstChild("Dug")
    if dug and dug.Value ~= "" then
        return false
    end
    return true
end

local function valueOf(block)
    local resource = block:GetAttribute("Resource")
    if resource then
        return Config.orePrices[resource] or 0
    end
    local typeValue = block:FindFirstChild("Type")
    if not typeValue then
        return 0
    end
    return Config.orePrices[typeValue.Value] or 0
end

function Ores.refresh()
    cache = {}
    cacheTime = os.clock()

    local mine = workspace:FindFirstChild(Config.mineName)
    if not mine then
        return
    end

    for _, block in ipairs(mine:GetChildren()) do
        if valueOf(block) >= Config.minOreValue and isAlive(block) then
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
        if untilIgnore and untilIgnore > now then
            continue
        end
        if isAlive(block) then
            local distance = (block.Position - position).Magnitude
            if distance <= Config.oreRange and (not bestDistance or distance < bestDistance) then
                best, bestDistance = block, distance
            end
        end
    end

    return best, bestDistance
end

function Ores.ignore(block)
    ignored[block] = os.clock() + 5
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

    character:PivotTo(box:GetPivot())
    task.wait(Config.mushroomDelay)

    if not Mushrooms.enabled then
        return
    end
    interact.InteractEvent:FireServer()
end)

---------------------------------------------------------------------------
-- Digger (manager)
---------------------------------------------------------------------------

local Digger

Digger = Manager.new(function()
    local character = Character.get()
    if not Digger.enabled then
        return
    end

    local hit = Target.blockBelow(character)
    if not hit then
        task.wait(0.3)
        return
    end

    local pickaxe = Character.equipPickaxe(character)
    if not pickaxe then
        warn("[autodig] no pickaxe")
        task.wait(0.5)
        return
    end

    local remote = pickaxe:FindFirstChild(Config.digRemote)
    if not remote then
        warn("[autodig] no " .. Config.digRemote)
        task.wait(0.5)
        return
    end

    local maxDistance = pickaxe:FindFirstChild("MaxDistance")
    if maxDistance and (hit.Position - character.PrimaryPart.Position).Magnitude > maxDistance.Value then
        task.wait(0.3)
        return
    end

    Character.face(character, hit.Position)
    task.wait(0.1)

    if Config.digArg == "position" then
        remote:FireServer(hit.Position)
    else
        remote:FireServer(hit.Instance)
    end

    task.wait(Config.digDelay)
end)

---------------------------------------------------------------------------
-- Ore-runner (manager)
---------------------------------------------------------------------------

local OreRunner

local function releaseMover()
    Physics.release(OreRunner.velocity, OreRunner.attachment)
    OreRunner.velocity = nil
    OreRunner.attachment = nil

    local character = Players.LocalPlayer.Character
    Character.platformStand(character, false)
end

local function ensureMover(character)
    local root = character.PrimaryPart
    if OreRunner.attachment and OreRunner.attachment.Parent == root and OreRunner.velocity then
        return OreRunner.velocity
    end

    releaseMover()
    OreRunner.velocity, OreRunner.attachment = Physics.attach(root)
    return OreRunner.velocity
end

OreRunner = Manager.new(function()
    local character = Character.get()
    if not OreRunner.enabled then
        return
    end

    local root = character.PrimaryPart
    if not root then
        return
    end

    local velocity = ensureMover(character)
    local target = Ores.nearest(root.Position)

    if not target then
        velocity.VectorVelocity = Vector3.zero
        task.wait(0.5)
        return
    end

    Character.platformStand(character, true)

    local delta = target.Position - root.Position
    if delta.Magnitude <= Config.oreStopDistance then
        velocity.VectorVelocity = Vector3.zero
        Ores.ignore(target)
        task.wait(0.2)
        return
    end

    velocity.VectorVelocity = delta.Unit * Config.oreSpeed
end, releaseMover)

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local Ui = {}

function Ui.load()
    if type(readfile) == "function" and type(isfile) == "function" then
        for _, path in ipairs({ "uilib/source.lua", "uilib\\source.lua" }) do
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
    local section = main:AddSeperator("Teleport / Dig")

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
        desc = "teleport to HarvestableNode and fire Interact",
        instance = Mushrooms,
    },
    {
        title = "Auto-dig",
        desc = "dig block below through the pickaxe remote",
        instance = Digger,
    },
    {
        title = "Ore-runner",
        desc = "fly to the nearest valuable ore with LinearVelocity",
        instance = OreRunner,
    },
})

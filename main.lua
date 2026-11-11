local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

---------------------------------------------------------------------------
-- Config
---------------------------------------------------------------------------

local Config = {
    mushroomDelay = 0.5,
    digDelay = 1.3,
    searchDistance = 12,
    mushroomHotkey = Enum.KeyCode.F1,
    digHotkey = Enum.KeyCode.F2,
}

---------------------------------------------------------------------------
-- Manager
---------------------------------------------------------------------------

local Manager = {}

function Manager.new(step)
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
        manager.enabled = false
        manager.token += 1
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
    return tool:IsA("Tool") and tool.Name:lower():find("pickaxe") ~= nil
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

    Character.face(character, hit.Position)
    task.wait(0.1)
    pickaxe:Activate()
    task.wait(Config.digDelay)
end)

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local Ui = {}

local ON_COLOR = Color3.fromRGB(120, 220, 120)
local OFF_COLOR = Color3.fromRGB(220, 220, 220)
local ON_BUTTON = Color3.fromRGB(150, 50, 50)
local OFF_BUTTON = Color3.fromRGB(60, 60, 60)

local function refreshRow(row)
    if row.manager.enabled then
        row.status.Text = row.name .. ": ON"
        row.status.TextColor3 = ON_COLOR
        row.button.Text = "Stop"
        row.button.BackgroundColor3 = ON_BUTTON
    else
        row.status.Text = row.name .. ": OFF"
        row.status.TextColor3 = OFF_COLOR
        row.button.Text = "Start"
        row.button.BackgroundColor3 = OFF_BUTTON
    end
end

function Ui.create(rows)
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "MainGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(190, 12 + #rows * 52)
    frame.Position = UDim2.new(0, 20, 0.5, -frame.Size.Y.Offset // 2)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    for index, row in ipairs(rows) do
        local top = 6 + (index - 1) * 52

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -16, 0, 18)
        status.Position = UDim2.fromOffset(8, top)
        status.BackgroundTransparency = 1
        status.Font = Enum.Font.GothamMedium
        status.TextSize = 13
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Parent = frame
        row.status = status

        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -16, 0, 26)
        button.Position = UDim2.fromOffset(8, top + 20)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = 14
        button.TextColor3 = Color3.fromRGB(240, 240, 240)
        button.Parent = frame
        row.button = button

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = button

        button.Activated:Connect(function()
            row.manager.toggle()
            refreshRow(row)
        end)

        refreshRow(row)
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        for _, row in ipairs(rows) do
            if input.KeyCode == row.hotkey then
                row.manager.toggle()
                refreshRow(row)
            end
        end
    end)

    return gui
end

Ui.create({
    {
        name = "Mushrooms",
        manager = Mushrooms,
        hotkey = Config.mushroomHotkey,
    },
    {
        name = "Auto-dig",
        manager = Digger,
        hotkey = Config.digHotkey,
    },
})

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local STEP_DELAY = 0.5
local HOTKEY = Enum.KeyCode.F1

local Manager = {
    enabled = false,
    token = 0,
}

---------------------------------------------------------------------------
-- Manager
---------------------------------------------------------------------------

local function findTarget()
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

local function getCharacter()
    local player = Players.LocalPlayer
    local character = player.Character
    if not character or not character.PrimaryPart then
        character = player.CharacterAdded:Wait()
    end
    return character
end

function Manager.step()
    local model = findTarget()
    if not model then
        warn("no mushies")
        return
    end

    local box = model.BoundingBox
    local interact = box:FindFirstChild("Interact")
    if not interact then
        return
    end

    local character = getCharacter()
    character:PivotTo(box:GetPivot())

    task.wait(STEP_DELAY)

    if not Manager.enabled then
        return
    end
    interact.InteractEvent:FireServer()
end

function Manager.start()
    if Manager.enabled then
        return
    end

    Manager.enabled = true
    Manager.token += 1
    local token = Manager.token

    task.spawn(function()
        while Manager.enabled and Manager.token == token do
            local ok, err = pcall(Manager.step)
            if not ok then
                warn("[mushrooms] " .. tostring(err))
            end
            task.wait(0.1)
        end
    end)
end

function Manager.stop()
    Manager.enabled = false
    Manager.token += 1
end

function Manager.toggle()
    if Manager.enabled then
        Manager.stop()
    else
        Manager.start()
    end
    return Manager.enabled
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local ON_COLOR = Color3.fromRGB(120, 220, 120)
local OFF_COLOR = Color3.fromRGB(220, 220, 220)
local ON_BUTTON = Color3.fromRGB(150, 50, 50)
local OFF_BUTTON = Color3.fromRGB(60, 60, 60)

local function createUi()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "MushroomTeleportGui"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(180, 68)
    frame.Position = UDim2.new(0, 20, 0.5, -34)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -16, 0, 20)
    status.Position = UDim2.fromOffset(8, 6)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 13
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = OFF_COLOR
    status.Text = "Mushrooms: OFF"
    status.Parent = frame

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -16, 0, 28)
    button.Position = UDim2.fromOffset(8, 30)
    button.BackgroundColor3 = OFF_BUTTON
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.TextColor3 = Color3.fromRGB(240, 240, 240)
    button.Text = "Start"
    button.Parent = frame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = button

    local function refresh()
        if Manager.enabled then
            status.Text = "Mushrooms: ON"
            status.TextColor3 = ON_COLOR
            button.Text = "Stop"
            button.BackgroundColor3 = ON_BUTTON
        else
            status.Text = "Mushrooms: OFF"
            status.TextColor3 = OFF_COLOR
            button.Text = "Start"
            button.BackgroundColor3 = OFF_BUTTON
        end
    end

    button.Activated:Connect(function()
        Manager.toggle()
        refresh()
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == HOTKEY then
            Manager.toggle()
            refresh()
        end
    end)

    return gui, refresh
end

createUi()

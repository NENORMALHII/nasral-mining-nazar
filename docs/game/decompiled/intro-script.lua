-- Script Path: game:GetService("Players").homel_entity.PlayerGui.Intro.Intro
-- Took 0.26s to decompile.
-- Executor: Delta (1.0.745.1142)

-- Decompiled using ByteFall
-- discord.gg/pHTnqmmWzk
local contentProvider = game:GetService("ContentProvider")
local runService = game:GetService("RunService")
local dialogs = require(game.ReplicatedStorage.Modules.Gui.Dialogs)
local commonUtils = require(game.ReplicatedStorage.Modules.CommonUtils)
local clientSettings = require(game.ReplicatedStorage.Modules.ClientSettings)
local v6 = require(game.ReplicatedStorage.Modules.PlayerScriptLoader):WaitForPlayerScripts()
local cornerButtons = require(v6.Modules.Gui.CornerButtons)
local enums = require(game.ReplicatedStorage.Modules.Enums)
local musicPlayer = require(v6.Modules.MusicPlayer)
local textUtils = require(game.ReplicatedStorage.Modules.TextUtils)
local updateLog = require(game.ReplicatedStorage.Modules.UpdateLog)
local axes = require(game.ReplicatedStorage.Scripts.Axes)
local pickaxes = require(game.ReplicatedStorage.Modules.Tools.Pickaxes)
local halloween2024Client = require(game.ReplicatedStorage.Seasonal.Halloween2024.Halloween2024Client)
local LocalPlayer = game.Players.LocalPlayer
local u16 = true

local function camera()
    u16 = false

    local CurrentCamera = game.Workspace.CurrentCamera
    local CamPos1Position = game.Workspace.CamPos1.Position
    local CamTarget1Position = game.Workspace.CamTarget1.Position

    CurrentCamera.CameraType = Enum.CameraType.Scriptable
    CurrentCamera.CoordinateFrame = CFrame.new(CamPos1Position, CamTarget1Position)

    local state = 1

    while true do
        if state == 1 then
            state = 2
        elseif state == 2 then
            local CamPos1Position2 = game.Workspace.CamPos1.Position
            local vectorValue = Vector3.new(0, 0, 0)

            for _ = 1, 500 do
                vectorValue += Vector3.new(-0.1, 0, 0)

                local cFrame = CFrame.new(CamPos1Position2 + vectorValue, CamTarget1Position)

                CurrentCamera.CoordinateFrame = cFrame
                runService.RenderStepped:Wait()

                if not u16 then
                    continue
                end

                return
            end

            CamPos1Position2 = game.Workspace.CamPos4.Position

            local CamTarget2Position = game.Workspace.CamTarget2.Position

            vectorValue = Vector3.new(0, 0, 0)

            for _ = 1, 500 do
                vectorValue += Vector3.new(0, 0, -0.1)

                local cFrame2 = CFrame.new(CamPos1Position2 + vectorValue, CamTarget2Position)

                CurrentCamera.CoordinateFrame = cFrame2
                runService.RenderStepped:Wait()

                if not u16 then
                    continue
                end

                return
            end

            CamPos1Position2 = game.Workspace.CamPos2.Position
            CamTarget1Position = game.Workspace.CamTarget1.Position
            vectorValue = Vector3.new(0, 0, 0)

            for _ = 1, 400 do
                vectorValue += Vector3.new(0.1, 0, 0)

                local cFrame3 = CFrame.new(CamPos1Position2 + vectorValue, CamTarget1Position)

                CurrentCamera.CoordinateFrame = cFrame3
                runService.RenderStepped:Wait()

                if not u16 then
                    continue
                end

                return
            end

            CamPos1Position2 = game.Workspace.CamPos3.Position
            vectorValue = Vector3.new(0, 0, 0)

            for _ = 1, 500 do
                vectorValue += Vector3.new(0.05, 0, -0.1)

                local cFrame4 = CFrame.new(CamPos1Position2 + vectorValue, CamTarget1Position)

                CurrentCamera.CoordinateFrame = cFrame4
                runService.RenderStepped:Wait()

                if not u16 then
                    continue
                end

                return
            end

            state = 3
        elseif state == 3 then
            state = 1
        else
            break
        end
    end
end

local v18 = coroutine.create(camera)
local overlay = script.Parent:WaitForChild("Overlay")
local mainMenu = overlay.MainMenu
local settings = overlay.Settings
local profileSelect = overlay.ProfileSelect
local updates = overlay.Updates
local credits = overlay.Credits
local confirmNewGame = overlay.ConfirmNewGame
local v26 = halloween2024Client:IsLive() and overlay.IntroHalloween or overlay.IntroMusic

game.ReplicatedStorage.IntroPlayerDataEvent.OnClientEvent:Connect(function(p1, p2)
    print("Received IntroPlayerDataEvent", p1)

    if p1 == enums.GameIntroEvent.LOADING then
        mainMenu.Buttons.Visible = false
        mainMenu.Status.Visible = true
        mainMenu.Status.Text = "Loading player data..."
    elseif p1 == enums.GameIntroEvent.LOADED then
        mainMenu.Buttons.Visible = true
        mainMenu.Status.Visible = false
        print("Recieved profile data: ", game:GetService("HttpService"):JSONEncode(p2))

        for iterFirst, iterSecond in p2 do
            local profileSelectButtons = profileSelect.Buttons
            local s1 = "Profile" .. iterFirst
            local foundChild = profileSelectButtons:FindFirstChild(s1)
            foundChild.Text = ""
            foundChild.Info.Visible = true
            foundChild.Info.Money.Visible = true

            local money = foundChild.Info.Money

            s1 = "$" .. iterSecond.Money
            money.Text = s1
            foundChild.Info.Pickaxe.Visible = true
            foundChild.Info.Pickaxe.Text = iterSecond.Pickaxe
            foundChild.Info.Pickaxe.TextColor3 = commonUtils:ToColor3(pickaxes[iterSecond.Pickaxe].Color)
            foundChild.Info.Axe.Visible = true
            foundChild.Info.Axe.Text = iterSecond.Axe
            foundChild.Info.Axe.TextColor3 = commonUtils:ToColor3(axes[iterSecond.Axe].Color)
        end
    elseif p1 == enums.GameIntroEvent.SINGLE_SOURCE_MIGRATION then
        mainMenu.Buttons.Visible = false
        mainMenu.Status.Visible = true
        mainMenu.Status.Text = "Migrating data to new save file format..."
    elseif p1 == enums.GameIntroEvent.ERROR then
        mainMenu.Buttons.Visible = false
        mainMenu.Status.Visible = true
        mainMenu.Status.Text = "Failed to load player data - please try again"
        mainMenu.Status.TextColor3 = textUtils.ERROR
    else
        print("Unknown GameIntroEvent: " .. tostring(p1))
    end
end)
script.Parent.Enabled = true
mainMenu.Buttons.Visible = false
print("Hiding buttons")
mainMenu.Position = UDim2.new(0.5, 0, 1.5, 0)
contentProvider:Preload(v26.SoundId)
script.Parent.StartIntroEvent.Event:Wait()
game.ReplicatedStorage.IntroPlayerDataEvent:FireServer()
v26:Play()
coroutine.resume(v18)

function PrepareForGame(p1, p2)
    mainMenu:TweenPosition(UDim2.new(0.5, 0, 1.5, 0), "In", "Quad", 0.75, true, function()
        mainMenu.Visible = false
    end)
    overlay.Visible = true

    for i = 1, 0, -0.05 do
        overlay.BackgroundTransparency = i
        wait()
    end

    overlay.BackgroundTransparency = 0
    u16 = true
    wait(2)

    for i = v26.Volume, 0, -0.1 do
        v26.Volume = i
        wait(0.1)
    end

    v26:Stop()
    p1:FireServer(p2)

    local v5 = LocalPlayer.CharacterAdded:Wait()

    game.Workspace.CurrentCamera.CameraSubject = v5:WaitForChild("Humanoid")
    game.Workspace.CurrentCamera.CameraType = "Custom"
    wait(1)

    for i = 0, 1, 0.05 do
        overlay.BackgroundTransparency = i
        wait()
    end

    overlay.Visible = false

    if clientSettings:Get("GameMusic") then
        musicPlayer:Enable()
    end
end

require(game.ReplicatedStorage.Util)

local s1 = "Load"

wait(2)
mainMenu.Visible = true
mainMenu:TweenPosition(UDim2.new(0.5, 0, 0.5, 0), "Out", "Quad", 0.75)

local u28 = nil

mainMenu.Buttons.NewGame.MouseButton1Click:connect(function()
    local foundChild = profileSelect.Buttons:FindFirstChild("Profile" .. 1)
    foundChild.AutoButtonColor = true
    foundChild.Active = true
    foundChild = profileSelect.Buttons:FindFirstChild("Profile" .. 2)
    foundChild.AutoButtonColor = true
    foundChild.Active = true
    foundChild = profileSelect.Buttons:FindFirstChild("Profile" .. 3)
    foundChild.AutoButtonColor = true
    foundChild.Active = true
    s1 = "New"
    profileSelect.Title.Text = "Start New Game"
    profileSelect.Visible = true
    mainMenu.Visible = false
end)
mainMenu.Buttons.LoadGame.MouseButton1Click:connect(function()
    for i = 1, 3 do
        local foundChild = profileSelect.Buttons:FindFirstChild("Profile" .. i)
        foundChild.AutoButtonColor = foundChild.Text ~= "[Empty]"
        foundChild.Active = foundChild.Text ~= "[Empty]"
    end

    s1 = "Load"
    profileSelect.Title.Text = "Load Saved Game"
    profileSelect.Visible = true
    mainMenu.Visible = false
end)

for i = 1, 3 do
    local foundChild = profileSelect.Buttons:FindFirstChild("Profile" .. i)
    foundChild.MouseButton1Click:connect(function()
        if s1 == "Load" and foundChild.Active then
            profileSelect.Visible = false
            foundChild.Active = false
            PrepareForGame(game.ReplicatedStorage.LoadGameEvent, i)
        elseif s1 == "New" and foundChild.Text ~= "[Empty]" then
            profileSelect.Visible = false

            local t1 = {
                [dialogs.OPTION_DIALOG_TEXT] = textUtils:Color(
                    "Are you sure you want to start a new game? This will delete all of your saved progress on this profile.",
                    textUtils.ERROR
                )
            }
            t1[dialogs.OPTION_POSITIVE_BUTTON_COUNTDOWN] = 5
            dialogs:ShowBasicDialog(t1):andThen(function(p1)
                if p1 == dialogs.RESULT_NEGATIVE_BUTTON then
                    profileSelect.Visible = true
                elseif p1 == dialogs.RESULT_POSITIVE_BUTTON then
                    PrepareForGame(game.ReplicatedStorage.NewGameEvent, i)
                end
            end)
        elseif s1 == "New" and foundChild.Text == "[Empty]" then
            profileSelect.Visible = false
            PrepareForGame(game.ReplicatedStorage.NewGameEvent, i)
        end
    end)
end

local v31 = cornerButtons:Add(5000, "settings", "Settings")
v31:SetVisible(false)
v31.Activated:Connect(function()
    if LocalPlayer.GuiEnabled.Value then
        LocalPlayer.GuiEnabled.Value = false
        overlay.Visible = true
        credits.Visible = false
        settings.Visible = true
    end
end)
task.spawn(function()
    local guiEnabled = LocalPlayer:WaitForChild("GuiEnabled")

    v31:SetVisible(true)
    guiEnabled.Changed:Connect(function(p1)
        v31:SetVisible(p1)
    end)
end)
settings.CloseButton.Activated:connect(function()
    settings.Visible = false

    if not LocalPlayer:FindFirstChild("FullyLoaded") then
        mainMenu.Visible = true
    else
        LocalPlayer.GuiEnabled.Value = true
        v31:SetVisible(true)
        overlay.Visible = false
    end
end)
settings.CloseButton.MouseEnter:Connect(function()
    settings.CloseButton.TextColor3 = Color3.new(1, 0, 0)
end)
settings.CloseButton.MouseLeave:Connect(function()
    settings.CloseButton.TextColor3 = Color3.fromRGB(130, 130, 130)
end)
settings.Buttons.Changelog.Activated:Connect(function()
    LocalPlayer.GuiEnabled.Value = true
    v31:SetVisible(true)
    overlay.Visible = false
    require(LocalPlayer.PlayerGui.UpdateLog.UpdateLogGui):ShowLog(updateLog:GetMostRecentUpdate())
end)
settings.Buttons.Credits.Activated:Connect(function()
    settings.Visible = false
    credits.Visible = true
end)
credits.CloseButton.Activated:connect(function()
    credits.Visible = false

    if not LocalPlayer:FindFirstChild("FullyLoaded") then
        mainMenu.Visible = true
    else
        LocalPlayer.GuiEnabled.Value = true
        v31:SetVisible(true)
        overlay.Visible = false
    end
end)
credits.CloseButton.MouseEnter:Connect(function()
    credits.CloseButton.TextColor3 = Color3.new(1, 0, 0)
end)
credits.CloseButton.MouseLeave:Connect(function()
    credits.CloseButton.TextColor3 = Color3.fromRGB(130, 130, 130)
end)

local u32 = confirmNewGame.NoButton.MouseButton1Click:connect(function()
    confirmNewGame.Visible = false
    mainMenu.Visible = true
end)

u28 = confirmNewGame.YesButton.MouseButton1Click:connect(function()
    confirmNewGame:TweenPosition(UDim2.new(0.5, 0, 1.5, 0), "Out", "Quad", 0.75, true)
    u32:disconnect()
    u28:disconnect()
    PrepareForGame(game.ReplicatedStorage.NewGameEvent)
end)
profileSelect.Back.MouseButton1Click:connect(function()
    profileSelect.Visible = false
    mainMenu.Visible = true
end)
updates.Back.MouseButton1Click:connect(function()
    mainMenu.Visible = true
    updates.Visible = false
end)

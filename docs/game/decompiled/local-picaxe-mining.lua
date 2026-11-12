-- Script Path: game:GetService("Workspace").homel_entity.Pick.MineScript
-- Took 0.05s to decompile.
-- Executor: Delta (1.0.745.1142)

-- The script is located inside Character.Pick
local v_u_1 = game:GetService("UserInputService")
local v_u_2 = game:GetService("RunService")
local v_u_3 = require(game.ReplicatedFirst.Assets)
require(game.ReplicatedStorage.Modules.Mining.BlockStates)
local v_u_4 = require(game.ReplicatedStorage.Modules.ClientSettings)
local v_u_5 = require(game.ReplicatedStorage.Colors.ColorScript)
local v6 = require(game.ReplicatedStorage.Modules.PlayerScriptLoader):WaitForPlayerScripts()
local v_u_7 = require(game.ReplicatedStorage.Modules.Constants)
local v_u_8 = require(v6.Modules.PlatformService)
local v_u_9 = require(v6.Modules.EffectsClient)
local v_u_10 = require(game.ReplicatedStorage.Modules.Effects.BlockBreakingEffect)
local v_u_11 = require(v6.Modules.GuiEnabledState)
local v_u_12 = require(game.ReplicatedStorage.Modules.ToolStatusGui)
local v_u_13 = require(game.ReplicatedStorage.Modules.TextUtils)
local v_u_14 = require(game.ReplicatedStorage.Modules.CommonUtils)
local v15 = require(game.ReplicatedStorage.Lib.Maid)
local v_u_16 = require(game.ReplicatedStorage.Modules.CollisionGroups)
local v_u_17 = require(game.ReplicatedStorage.Modules.Resources)
local v_u_18 = require(game.ReplicatedFirst.Util)
local v_u_19 = require(game.ReplicatedStorage.Modules.Logger).new()
local v_u_20 = {
    ["Oil"] = true,
    ["Lava"] = true,
    ["Grass"] = true,
    ["Void"] = true
}
local v_u_21 = script.Parent
local v_u_22 = game.ReplicatedStorage.BlockEvent
local v_u_23 = game.ReplicatedStorage.BlockMinedEvent
local v_u_24 = game:GetService("Players").LocalPlayer
local v_u_25 = workspace.CurrentCamera
local v_u_26 = false
local v_u_27 = v_u_21:WaitForChild("MaxDistance").Value
local v_u_28 = false
local v_u_29 = nil
local v_u_30 = nil
local v_u_31 = false
local v_u_32 = nil
local v_u_33 = nil
local v_u_34 = nil
local v_u_35 = v15.new()
local v_u_36 = 10
local v_u_37 = nil
local v_u_38 = nil
script.Parent.UpdatePickaxe.OnClientEvent:connect(function(p39)
    -- upvalues: (copy) v_u_19, (ref) v_u_36
    local v40 = v_u_19
    local v41 = p39.BaseMineTime
    v40:debug("Updated pickaxe, mineTime = %s", (tostring(v41)))
    v_u_36 = p39.BaseMineTime
end)
function IsMining() -- name: IsMining
    -- upvalues: (ref) v_u_33
    return v_u_33 ~= nil
end
function IsBlockBesideLiquid(p42) -- name: IsBlockBesideLiquid
    -- upvalues: (copy) v_u_18, (copy) v_u_17
    for _, v43 in pairs(v_u_18.POSITIONS) do
        if v43.y == 1 then
            continue
        end
        local v44 = game.Workspace.Mine:FindFirstChild(v_u_18:vec3_tostring(p42 + v43))
        if not (v44 and (v44:FindFirstChild("Type") and v_u_17[v44.Type.Value].LiquidResource)) then
            continue
        end
        return true, v44.Type.Value
    end
    return false, ""
end
function ShowError(p45) -- name: ShowError
    -- upvalues: (ref) v_u_32, (ref) v_u_33
    v_u_32:SetText(p45)
    v_u_32:StopProgressBar()
    v_u_33 = nil
end
function StartMining() -- name: StartMining
    -- upvalues: (copy) v_u_8, (copy) v_u_11, (ref) v_u_33, (ref) v_u_32, (copy) v_u_13, (copy) v_u_7, (copy) v_u_24, (ref) v_u_26, (ref) v_u_34, (ref) v_u_38, (ref) v_u_36, (copy) v_u_17, (ref) v_u_37, (copy) v_u_5, (copy) v_u_22, (copy) v_u_9, (copy) v_u_10, (copy) v_u_4
    if v_u_8:IsMobile() and not v_u_11:IsGuiEnabled() then
        return
    else
        local v46 = GetTargetMineableBlock()
        if v46 then
            v_u_33 = v46:GetAttribute("MinePosition")
            v_u_32:SetVisible(true)
            if v46.Type.Value == "Bedrock" or v46:GetAttribute("IsBedrock") == true then
                ShowError(v_u_13:Color(("You cannot mine %s!"):format(v46.Type.Value), v_u_13.ERROR))
                return
            elseif v46:GetAttribute(v_u_7.ATTR_WORLD_ID) == v_u_24:GetAttribute(v_u_7.ATTR_WORLD_ID) then
                if v_u_26 then
                    v_u_34.Adornee = v46
                end
                if v46.Dug.Value == v_u_24.Name or v46.Dug.Value == "" then
                    local v47, v48 = IsBlockBesideLiquid(v_u_33)
                    if v47 then
                        ShowError(v_u_13:Color(("You can\'t let the %s spill!"):format(v48), v_u_13.ERROR))
                    else
                        local v49 = v46.Type.Value
                        local v50 = v_u_36 * ((100 - (v_u_24:GetAttribute("ToolSpeedModifier") or 0)) / 100) * (not v_u_17[v49].MineTimeModifier and 1 or v_u_17[v49].MineTimeModifier)
                        v_u_37 = v50
                        local v51 = v_u_5:GetResourceColor(v46.Type.Value)
                        v_u_22:FireServer(v46.Name, {
                            ["dug"] = true
                        })
                        v_u_9:StartEffect(v_u_10.Id, v_u_33, v50)
                        v_u_32:SetText(v_u_13:Color(("Mining %s"):format(v46.Type.Value), v51))
                        v_u_32:StartProgressBar(v50, v51)
                        if not v_u_38.IsPlaying and v_u_4:Get("ToolAnimations") then
                            v_u_38:Play()
                            local v52 = v_u_38
                            local v53 = v_u_36 * ((100 - (v_u_24:GetAttribute("ToolSpeedModifier") or 0)) / 100) - 0.3
                            v52:AdjustSpeed(1 - math.max(v53, 0) / 3.5 + 1)
                        end
                    end
                else
                    ShowError(v_u_13:Color("Someone else is mining that!", v_u_13.ERROR))
                    v_u_38:Stop(0.3)
                    return
                end
            else
                ShowError(v_u_13:Color("You\'re not allowed to mine this", v_u_13.ERROR))
                return
            end
        else
            return
        end
    end
end
function OnActivated(p54) -- name: OnActivated
    -- upvalues: (ref) v_u_28, (ref) v_u_29
    v_u_28 = true
    v_u_29 = p54
    StartMining()
end
function OnDeactivated() -- name: OnDeactivated
    -- upvalues: (ref) v_u_28, (ref) v_u_33, (copy) v_u_22, (copy) v_u_18, (copy) v_u_9, (copy) v_u_10, (ref) v_u_26, (ref) v_u_34, (ref) v_u_32, (ref) v_u_38
    v_u_28 = false
    if v_u_33 then
        v_u_22:FireServer(v_u_18:vec3_tostring(v_u_33), {
            ["dug"] = false
        })
        v_u_9:StopEffect(v_u_10.Id, v_u_33)
        v_u_33 = nil
    end
    if v_u_26 then
        v_u_34.Adornee = nil
    end
    v_u_32:StopProgressBar()
    v_u_32:SetVisible(false)
    v_u_38:Stop(0.3)
end
function OnFinishMining() -- name: OnFinishMining
    -- upvalues: (copy) v_u_23, (copy) v_u_18, (ref) v_u_33
    v_u_23:FireServer({
        ["blockName"] = v_u_18:vec3_tostring(v_u_33)
    })
end
function GetTargetMineableBlock() -- name: GetTargetMineableBlock
    -- upvalues: (ref) v_u_29, (copy) v_u_14, (copy) v_u_24, (copy) v_u_27, (copy) v_u_20
    if v_u_29 == nil then
        return nil
    else
        local v55 = v_u_14:RaycastFromScreenPoint(v_u_29, 100)
        if v55 == nil or (v55.Parent ~= workspace.Mine or not (v_u_14:IsPlayerWithinRange(v_u_24, v55, v_u_27) and v55:GetAttribute("MinePosition"))) then
            return nil
        else
            local v56 = v55:FindFirstChild("Type")
            if v56 then
                if v_u_20[v56.Value] then
                    return nil
                else
                    return v55
                end
            else
                return nil
            end
        end
    end
end
function OptimimisticallyDestroyBlock(p57) -- name: OptimimisticallyDestroyBlock
    -- upvalues: (copy) v_u_18, (copy) v_u_19
    local v58 = workspace.Mine:FindFirstChild(v_u_18:vec3_tostring(p57))
    if v58 ~= nil then
        for _, v59 in pairs(v_u_18.POSITIONS) do
            local v60 = p57 + v59
            if workspace.Mine:FindFirstChild(v_u_18:vec3_tostring(v60)) ~= nil then
                continue
            end
            return
        end
        v_u_19:debug("Optimistically destroying block at %s", (tostring(p57)))
        v58:Destroy()
    end
end
function OnTick() -- name: OnTick
    -- upvalues: (ref) v_u_31, (ref) v_u_26, (ref) v_u_34, (ref) v_u_30, (copy) v_u_7, (ref) v_u_33, (copy) v_u_9, (copy) v_u_10, (copy) v_u_22, (copy) v_u_18, (ref) v_u_32, (ref) v_u_38, (ref) v_u_28
    if v_u_31 then
        local v61 = GetTargetMineableBlock()
        if not v_u_26 then
            v_u_34.Adornee = v61
            v_u_30.Icon = v61 and v_u_7.MouseIcon.HAND or v_u_7.MouseIcon.DEFAULT
        end
        if IsMining() and (not v61 or v_u_33 ~= v61:GetAttribute("MinePosition")) then
            v_u_9:StopEffect(v_u_10.Id, v_u_33)
            v_u_22:FireServer(v_u_18:vec3_tostring(v_u_33), {
                ["dug"] = false
            })
            v_u_33 = nil
            v_u_32:StopProgressBar()
            v_u_32:SetVisible(false)
            task.delay(0.75, function()
                -- upvalues: (ref) v_u_38
                if not IsMining() then
                    v_u_38:Stop(0.3)
                end
            end)
        end
        if not v61 and v_u_26 then
            v_u_28 = false
            v_u_34.Adornee = nil
        end
        if not IsMining() and v_u_28 then
            if v61 then
                StartMining()
                return
            end
            v_u_32:StopProgressBar()
            v_u_32:SetVisible(false)
        end
    end
end
v_u_21.Equipped:Connect(function(p62)
    -- upvalues: (ref) v_u_26, (copy) v_u_8, (copy) v_u_14, (copy) v_u_21, (copy) v_u_16, (ref) v_u_31, (ref) v_u_30, (ref) v_u_38, (copy) v_u_3, (copy) v_u_24, (copy) v_u_19, (copy) v_u_35, (ref) v_u_32, (copy) v_u_12, (ref) v_u_34, (copy) v_u_25, (copy) v_u_1, (ref) v_u_29, (copy) v_u_7, (ref) v_u_28, (copy) v_u_2
    v_u_26 = v_u_8:IsMobile()
    v_u_14:SetModelCollisionGroup(v_u_21, v_u_16.CHARACTERS)
    v_u_31 = true
    v_u_30 = p62
    if v_u_38 == nil then
        local v63 = v_u_3.Animations.MINING
        local v64 = Instance.new("Animation")
        v64.AnimationId = "rbxassetid://" .. v63
        v64.Name = "Mining"
        v64.Parent = v_u_21
        local v65 = v_u_24.Character.Humanoid.Animator:LoadAnimation(v64)
        v65.Looped = true
        v_u_19:debug("Loaded animation %d", v63)
        v_u_38 = v65
    end
    v_u_35:GiveTask(v_u_38:GetMarkerReachedSignal("Hit"):Connect(function()
        -- upvalues: (ref) v_u_21
        v_u_21.Hit.PlaybackSpeed = 0.95 + math.random() * 0.1
        v_u_21.Hit:Play()
    end))
    v_u_32 = v_u_12.new("PickaxeStatusGui", false)
    v_u_32.Completed:Connect(OnFinishMining)
    v_u_35:GiveTask(v_u_32)
    v_u_34 = Instance.new("SelectionBox")
    v_u_34.Parent = v_u_25
    v_u_34.Name = "PickaxeSelectionBox"
    v_u_34.Color3 = Color3.fromRGB(60, 60, 60)
    v_u_34.LineThickness = 0.1
    v_u_35:GiveTask(v_u_34)
    if not v_u_26 then
        local v66 = v_u_1:GetMouseLocation()
        local v67 = v66.X
        local v68 = v66.Y
        v_u_29 = Vector3.new(v67, v68)
        v_u_30.Icon = v_u_7.MouseIcon.DEFAULT
    end
    v_u_35:GiveTask(v_u_1.InputBegan:Connect(function(p69, p70)
        if not p70 then
            if p69.UserInputType == Enum.UserInputType.MouseButton1 or p69.UserInputType == Enum.UserInputType.Touch then
                OnActivated(p69.Position)
            end
        end
    end))
    v_u_35:GiveTask(v_u_1.InputChanged:Connect(function(p71, p72)
        -- upvalues: (ref) v_u_28, (ref) v_u_29
        if p72 then
            OnDeactivated()
        elseif p71.UserInputType == Enum.UserInputType.MouseMovement or v_u_28 and p71.UserInputType == Enum.UserInputType.Touch then
            v_u_29 = p71.Position
        end
    end))
    v_u_35:GiveTask(v_u_1.InputEnded:Connect(function(p73, _)
        if p73.UserInputType == Enum.UserInputType.MouseButton1 or p73.UserInputType == Enum.UserInputType.Touch then
            OnDeactivated()
        end
    end))
    v_u_35:GiveTask(v_u_1.TouchPinch:Connect(function(_, _, _, _, _)
        OnDeactivated()
    end))
    v_u_35:GiveTask(game:GetService("GuiService").MenuOpened:Connect(function()
        print("MenuOpened")
    end))
    v_u_35:GiveTask(v_u_1.WindowFocusReleased:Connect(function()
        print("WindowFocusReleased")
    end))
    v_u_35:GiveTask(v_u_2.Stepped:Connect(function()
        -- upvalues: (ref) v_u_31
        if v_u_31 then
            OnTick()
        end
    end))
end)
v_u_21.Unequipped:Connect(function()
    -- upvalues: (ref) v_u_31, (ref) v_u_30, (copy) v_u_35
    OnDeactivated()
    v_u_31 = false
    v_u_30 = nil
    v_u_35:DoCleaning()
end)

-- Script Path: game:GetService("Players").Currentare.PlayerGui.Forge.Container.Content.ForgeClient
-- Took 0.02s to decompile.
-- Executor: Lynx (0.747)

local Parent = script.Parent
local ColorScript_m = require(game.ReplicatedStorage.Colors.ColorScript)
local Util_m = require(game.ReplicatedStorage.Util)
local CommonUtils_m = require(game.ReplicatedStorage.Modules.CommonUtils)
local _ = require(game.ReplicatedStorage.Scripts:WaitForChild("FuelData"))
local UserInputService = game:GetService("UserInputService")
local Constants_m = require(game.ReplicatedStorage.Modules.Constants)
local Forge = game.Workspace.Forge
local ForgeHelper_m = require(Forge.ForgeHelper)
local InputTooltip = Parent.Parent.Parent.InputTooltip
local FuelTooltip = Parent.Parent.Parent.FuelTooltip
local v2 = ""
local OutputTooltip = Parent.Parent.Parent.OutputTooltip
local t = {}
Parent.Parent.Visible = false

for _, child in pairs(Parent.InputFrame:GetChildren()) do
    if child:IsA("ImageButton") then
        child.MouseButton1Click:connect(function() -- line: 23
            -- upvalues:
            --  [1] child (copy)
            --  [2] Forge (copy)
            --  [3] UserInputService (copy)
            --  [4] InputTooltip (copy)

            local Inv = _G.inv

            if Inv.Resources[child.Name] > 0 then
                local ForgeUpdateEvent = Forge.ForgeUpdateEvent
                local Name = child.Name
                local v4 = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and Inv.Resources[child.Name] or 1
                ForgeUpdateEvent:FireServer("AddInput", { Name, v4 })
                InputTooltip.Visible = false
            end
        end)
        child.MouseEnter:connect(function(x: number, y: number) -- line: 31
            -- upvalues:
            --  [1] InputTooltip (copy)
            --  [2] child (copy)
            --  [3] ColorScript_m (copy)
            --  [4] ForgeHelper_m (copy)
            --  [5] v2 (ref)

            InputTooltip.Visible = true
            InputTooltip.Position = UDim2.new(0, x + 20, 0, y - 15)
            InputTooltip.NameLabel.Text = child.Name
            InputTooltip.NameLabel.TextColor3 = ColorScript_m:GetResourceColor(child.Name)
            InputTooltip.MeltingPoint.Text = ForgeHelper_m:GetOreData(child.Name).MeltingPoint .. " C"
            InputTooltip.MeltingPoint.TextColor3 = ForgeHelper_m:GetTemperatureColor(
                ForgeHelper_m:GetOreData(child.Name).MeltingPoint
            )
            v2 = "Button"
        end)
        child.MouseLeave:connect(function() -- line: 41
            -- upvalues:
            --  [1] InputTooltip (copy)

            InputTooltip.Visible = false
        end)
        child.MouseMoved:connect(function(x_1: number, y_1: number) -- line: 45
            -- upvalues:
            --  [1] InputTooltip (copy)

            InputTooltip.Position = UDim2.new(0, x_1 + 20, 0, y_1 - 15)
        end)
    end
end

Parent.InputFrame.Input.MouseEnter:connect(function(x_2: number, y_2: number) -- line: 51
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] InputTooltip (copy)
    --  [3] t (ref)
    --  [4] ColorScript_m (copy)
    --  [5] ForgeHelper_m (copy)
    --  [6] v2 (ref)

    if not Parent.InputFrame.Input.Visible then
        return
    end

    InputTooltip.Visible = true
    InputTooltip.Position = UDim2.new(0, x_2 + 20, 0, y_2 - 15)
    InputTooltip.NameLabel.Text = t.Input.Type
    InputTooltip.NameLabel.TextColor3 = ColorScript_m:GetResourceColor(t.Input.Type)
    InputTooltip.MeltingPoint.Text = ForgeHelper_m:GetOreData(t.Input.Type).MeltingPoint .. " C"
    InputTooltip.MeltingPoint.TextColor3 = ForgeHelper_m:GetTemperatureColor(
        ForgeHelper_m:GetOreData(t.Input.Type).MeltingPoint
    )
    v2 = "Input"
end)
Parent.InputFrame.Input.MouseMoved:connect(function(x_3: number, y_3: number) -- line: 61
    -- upvalues:
    --  [1] InputTooltip (copy)

    InputTooltip.Position = UDim2.new(0, x_3 + 20, 0, y_3 - 15)
end)
Parent.InputFrame.Input.MouseLeave:connect(function() -- line: 64
    -- upvalues:
    --  [1] InputTooltip (copy)

    InputTooltip.Visible = false
end)
Parent.OutputFrame.Result.MouseEnter:connect(function(x_4: number, y_4: number) -- line: 68
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] OutputTooltip (copy)
    --  [3] t (ref)
    --  [4] ColorScript_m (copy)

    if not Parent.OutputFrame.Result.Visible then
        return
    end

    OutputTooltip.Visible = true
    OutputTooltip.Position = UDim2.new(0, x_4 + 20, 0, y_4 - 15)
    OutputTooltip.NameLabel.Text = t.Output.Type
    OutputTooltip.NameLabel.TextColor3 = ColorScript_m:GetResourceColor(t.Output.Type)
end)
Parent.OutputFrame.Result.MouseMoved:connect(function(x_5: number, y_5: number) -- line: 75
    -- upvalues:
    --  [1] OutputTooltip (copy)

    OutputTooltip.Position = UDim2.new(0, x_5 + 20, 0, y_5 - 15)
end)
Parent.OutputFrame.Result.MouseLeave:connect(function() -- line: 78
    -- upvalues:
    --  [1] OutputTooltip (copy)

    OutputTooltip.Visible = false
end)

function UpdateProductionBars(arg13) -- line: 83
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] ColorScript_m (copy)

    for _, child_1 in pairs(Parent.ProductionBarFrame:GetChildren()) do
        local num = tonumber(child_1.Name:sub(#child_1.Name))
        local v15 = arg13.Input.ProductionBars[num]

        if num <= arg13.Input.BarCount then
            local Next = child_1:FindFirstChild("Next")

            if Next then
                Next:Destroy()
            end

            child_1.Purchase.Visible = false
            child_1.Visible = true

            if arg13.Input.Type ~= "" then
                child_1.Bar.BackgroundColor3 = ColorScript_m:GetResourceColor(arg13.Input.Type)
                child_1.Bar.Size = UDim2.new(v15.Current / v15.Total, 0, 1, 0)
            else
                child_1.Bar.BackgroundColor3 = Color3.new(0, 0, 0)
                child_1.Bar.Size = UDim2.new(0, 0, 1, 0)
            end
        elseif num == arg13.Input.BarCount + 1 then
            if not child_1:FindFirstChild("Next") then
                Instance.new("StringValue", child_1).Name = "Next"
            end

            child_1.Visible = true
        else
            child_1.Visible = false
        end
    end
end

function UpdateOutputFrame(arg14) -- line: 117
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] Util_m (copy)
    --  [3] OutputTooltip (copy)

    local OutputFrame = Parent.OutputFrame
    local Result = OutputFrame.Result
    Result.Visible = if arg14.Output.Type == "" then false else arg14.Output.Amount > 0
    OutputFrame.Result.Amount.Text = arg14.Output.Amount

    if arg14.Output.Type ~= "" then
        OutputFrame.Result.Image = Util_m:GetMineralIcon(arg14.Output.Type)

        return
    end

    OutputTooltip.Visible = false
end

function UpdateInputFrame(arg15) -- line: 128
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] ForgeHelper_m (copy)
    --  [3] Util_m (copy)
    --  [4] v2 (ref)
    --  [5] InputTooltip (copy)

    local InputFrame = Parent.InputFrame
    local Inv_1 = _G.inv

    if not Inv_1 then
        return
    end

    if arg15.Input.Amount == 0 then
        for _, val in pairs(InputFrame:GetChildren()) do
            if val:IsA("ImageButton") then
                val.Visible = if Inv_1.Resources[val.Name] > 0 then if ForgeHelper_m:GetOreData(
                    val.Name
                ).Result ~= arg15.Output.Type then arg15.Output.Type == "" else true else false
            end
        end
    else
        for _, val_1 in pairs(InputFrame:GetChildren()) do
            if val_1:IsA("ImageButton") then
                local v18 = if val_1.Name ~= arg15.Input.Type then false else Inv_1.Resources[val_1.Name] > 0
                val_1.Visible = v18
            end
        end
    end

    if arg15.Input.Type ~= "" then
        InputFrame.Input.Image = Util_m:GetMineralIcon(arg15.Input.Type)
    elseif v2 == "Input" then
        InputTooltip.Visible = false
    end

    local Input_1 = InputFrame.Input
    Input_1.Visible = arg15.Input.Amount > 0
    InputFrame.Input.Amount.Text = arg15.Input.Amount
end

function UpdateFuelFrame(arg16) -- line: 156
    -- upvalues:
    --  [1] Parent (copy)

    local _ = _G.inv
    local FuelFrame = Parent.FuelFrame
    FuelFrame.Update:Fire(arg16)
    FuelFrame.Current.Visible = arg16.Amount > 0 and true
    FuelFrame.Current.Amount.Text = arg16.Amount
    local v22 = arg16.BurnTimeRemaining / arg16.TotalBurnTime
    FuelFrame.BurnFrame.Bar.Size = UDim2.new(1, 0, v22, 0)
    FuelFrame.BurnFrame.Bar.Position = UDim2.new(0, 0, 1 - v22, 0)
end

function UpdateTemperatureFrame(arg17) -- line: 169
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] ForgeHelper_m (copy)

    local TempFrame = Parent.TempFrame
    local v23 = (arg17.Temperature - arg17.MinTemperature) / (arg17.MaxTemperature - arg17.MinTemperature)
    TempFrame.Bar.Size = UDim2.new(1, 0, v23, 0)
    TempFrame.Bar.Position = UDim2.new(0, 0, 1 - v23, 0)
    TempFrame.TempLabel.Text = arg17.Temperature .. " C"
    local v24 = ForgeHelper_m:GetTemperatureColor(arg17.Temperature)
    TempFrame.Bar.BackgroundColor3 = v24
    TempFrame.TempLabel.TextColor3 = v24
end

Forge.ForgeUpdateEvent.OnClientEvent:connect(function(arguments) -- line: 182
    -- upvalues:
    --  [1] t (ref)

    t = arguments.PlayerForgeData
    UpdateProductionBars(arguments.PlayerForgeData)
    UpdateFuelFrame(arguments.SourceData)
    UpdateTemperatureFrame(arguments.SourceData)
    UpdateInputFrame(arguments.PlayerForgeData)
    UpdateOutputFrame(arguments.PlayerForgeData)
end)
Parent.OutputFrame.Result.MouseButton1Click:connect(function() -- line: 201
    -- upvalues:
    --  [1] Forge (copy)
    --  [2] OutputTooltip (copy)

    local Inv_3 = _G.inv

    if Inv_3.CurrentSize == Inv_3.MaxSize then
        print("INVENTORY IS FULL")

        return
    end

    Forge.ForgeUpdateEvent:FireServer("TakeResult")
    OutputTooltip.Visible = false
end)
Parent.ProductionBarFrame.ProductionBar_2.Purchase.Text = ("Increase Production [$%i]"):format(
    ForgeHelper_m.ProductionBar2Cost
)
Parent.ProductionBarFrame.ProductionBar_2.Purchase.MouseButton1Click:connect(function() -- line: 227
    -- upvalues:
    --  [1] ForgeHelper_m (copy)
    --  [2] Forge (copy)

    if game.Players.LocalPlayer.leaderstats.Money.Value >= ForgeHelper_m.ProductionBar2Cost then
        Forge.ForgeUpdateEvent:FireServer("BuyProductionBar")
    end
end)
Parent.ProductionBarFrame.ProductionBar_3.Purchase.MouseButton1Click:connect(function() -- line: 232
    -- upvalues:
    --  [1] CommonUtils_m (copy)
    --  [2] Constants_m (copy)
    --  [3] Forge (copy)

    if not CommonUtils_m:IsDevPlace() then
        game:GetService("MarketplaceService"):PromptProductPurchase(
            game.Players.LocalPlayer,
            Constants_m.DevProducts.THIRD_PRODUCTION_BAR
        )

        return
    end

    Forge.ForgeUpdateEvent:FireServer("BuyProductionBar")
end)
Parent.ProductionBarFrame.ProductionBar_4.Purchase.MouseButton1Click:connect(function() -- line: 241
    -- upvalues:
    --  [1] CommonUtils_m (copy)
    --  [2] Constants_m (copy)
    --  [3] Forge (copy)

    if not CommonUtils_m:IsDevPlace() then
        game:GetService("MarketplaceService"):PromptProductPurchase(
            game.Players.LocalPlayer,
            Constants_m.DevProducts.FOURTH_PRODUCTION_BAR
        )

        return
    end

    Forge.ForgeUpdateEvent:FireServer("BuyProductionBar")
end)
Forge.ToggleForgeEvent.OnClientEvent:connect(function() -- line: 250
    -- upvalues:
    --  [1] Parent (copy)
    --  [2] t (ref)

    Parent.Parent.CloseButton.TextColor3 = Color3.new(
        0.8117647058823529,
        0.8117647058823529,
        0.8117647058823529
    )
    game.Players.LocalPlayer:SetAttribute("BackpackVisible", false)
    Parent.FuelFrame.Update:Fire(t)
    Parent.Parent.Visible = true
end)
Parent.Parent.CloseButton.MouseButton1Click:connect(function() -- line: 257
    -- upvalues:
    --  [1] Forge (copy)
    --  [2] Parent (copy)
    --  [3] InputTooltip (copy)
    --  [4] OutputTooltip (copy)
    --  [5] FuelTooltip (copy)

    Forge.ToggleForgeEvent:FireServer()
    game.Players.LocalPlayer:SetAttribute("BackpackVisible", true)
    Parent.Parent.Visible = false
    InputTooltip.Visible = false
    OutputTooltip.Visible = false
    FuelTooltip.Visible = false
end)

if not CommonUtils_m:IsDevPlace() then
    coroutine.resume(coroutine.create(function() -- line: 269
        -- upvalues:
        --  [1] Constants_m (copy)
        --  [2] Parent (copy)

        local MarketplaceService_2 = game:GetService("MarketplaceService"):GetProductInfo(
            Constants_m.DevProducts.THIRD_PRODUCTION_BAR,
            Enum.InfoType.Product
        )
        Parent.ProductionBarFrame.ProductionBar_3.Purchase.Text = ("Increase Production [%i R$]"):format(
            MarketplaceService_2.PriceInRobux
        )
        local MarketplaceService_3 = game:GetService("MarketplaceService"):GetProductInfo(
            Constants_m.DevProducts.FOURTH_PRODUCTION_BAR,
            Enum.InfoType.Product
        )
        Parent.ProductionBarFrame.ProductionBar_4.Purchase.Text = ("Increase Production [%i R$]"):format(
            MarketplaceService_3.PriceInRobux
        )
    end))
else
    Parent.ProductionBarFrame.ProductionBar_3.Purchase.Text = "Increase Production [FREE]"
    Parent.ProductionBarFrame.ProductionBar_4.Purchase.Text = "Increase Production [FREE]"
end

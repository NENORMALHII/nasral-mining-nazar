local Players = game:GetService("Players")

local function _a()
    local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
    local targetModel
    for _, node in ipairs(workspace:GetChildren()) do
        if node.Name == "HarvestableNode" then
            local model = node:FindFirstChildWhichIsA("Model")
            if model then
                targetModel = model
                break
            end
        end
    end

    if not targetModel then
        warn("no mushies")
        return
    end

    print(targetModel)
    character:PivotTo(targetModel.BoundingBox:GetPivot(CFrame))
    task.wait(0.5)
    targetModel.BoundingBox.Interact.InteractEvent:FireServer()
end

_a()

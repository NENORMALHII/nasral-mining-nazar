local Players = game:GetService("Players")

local function findPickaxe()
    local player = Players.LocalPlayer
    local containers = { player.Character, player:FindFirstChild("Backpack") }
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") and item:FindFirstChild("UpdatePickaxe") then
                    return item
                end
            end
        end
    end
    return nil
end

local function describe(value)
    if typeof(value) == "Instance" then
        return ("%s [%s] %s"):format(value.Name, value.ClassName, value:GetFullName())
    end
    return ("%s %s"):format(typeof(value), tostring(value))
end

local pickaxe = findPickaxe()
if not pickaxe then
    warn("[probe] pickaxe not found")
    return
end

local remote = pickaxe:WaitForChild("UpdatePickaxe")
local maxDistance = pickaxe:FindFirstChild("MaxDistance")

print("[probe] tool:", pickaxe:GetFullName())
print("[probe] remote:", remote:GetFullName())
if maxDistance then
    print("[probe] MaxDistance:", maxDistance.Value)
end

---------------------------------------------------------------------------
-- Decompile client script if executor supports it
---------------------------------------------------------------------------

local mineScript = pickaxe:FindFirstChild("MineScript")
if mineScript and type(getscriptbytecode) == "function" and type(decompile) == "function" then
    local ok, source = pcall(function()
        return decompile(getscriptbytecode(mineScript))
    end)
    if ok and type(source) == "string" then
        print("[probe] MineScript source:")
        print(source)
    else
        warn("[probe] decompile failed")
    end
end

---------------------------------------------------------------------------
-- Log UpdatePickaxe calls while player mines manually
---------------------------------------------------------------------------

if type(hookmetamethod) ~= "function" then
    warn("[probe] hookmetamethod not available, cannot log remote args")
    return
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if self == remote and method == "FireServer" then
        print("[probe] UpdatePickaxe:FireServer")
        local args = { ... }
        print("[probe] arg count:", #args)
        for index, value in ipairs(args) do
            print("[probe] arg", index, describe(value))
        end
    end
    return oldNamecall(self, ...)
end)

print("[probe] ready, mine one block manually")

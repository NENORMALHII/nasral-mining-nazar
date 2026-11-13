local PlayerScriptLoader = require(game:GetService("ReplicatedStorage").Modules.PlayerScriptLoader)
local v1 = PlayerScriptLoader:WaitForPlayerScripts()
local InventoriesClient = require(v1.Modules.InventoriesClient)

local inv2 = InventoriesClient.GetInventory()

print(inv2.CurrentSize, inv2.MaxSize)
for name, count in pairs(inv2.Resources) do
    if count > 0 then
        print(name, count)
    end
end
-- this script gets all resources in the player's inventory and parses through them

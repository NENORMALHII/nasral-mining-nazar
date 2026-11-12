-- when player inventory is full you need to sell resources and then return back to mining

local Event = game:GetService("ReplicatedStorage").SellResourceFunction -- this remote function sells chosen resource from your inventory.
Event:InvokeServer(
    "Dirt",
    1
)

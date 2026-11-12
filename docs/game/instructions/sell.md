# Selling resources

When the inventory is full, sell resources and return to mining.

```lua
local Event = game:GetService("ReplicatedStorage").SellResourceFunction
Event:InvokeServer("Dirt", 1)
```

`SellResourceFunction` sells the chosen resource from the player's inventory.

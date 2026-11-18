Smelting (Forge) — findings from live inspection:

Location: Workspace.Forge. Remotes: ForgeUpdateEvent, ToggleForgeEvent, Interact.InteractEvent.

Flow:
1. Player on surface, InteractEvent fires.
3. Client fires: ForgeUpdateEvent:FireServer("AddInput", { oreName, count }).
   - count = 1 normally; if LeftShift held, count = full stack of that ore in inventory.
4. Client pre-check: _G.inv.Resources[oreName] > 0. Client-side only.
5. Server smelts ore over SmeltTime seconds, outputs Result bar.

Ore data (from Workspace.Forge.ForgeHelper):
- Copper Ore: MeltingPoint 1085, SmeltTime 40, Result Copper Bar
- Iron Ore: 1438, 60, Iron Bar
- Silver Ore: 962, 40, Silver Bar
- Gold Ore: 1064, 50, Gold Bar
- Promethium Ore: 1042, 60, Promethium Bar
- Mithril Ore: 1800, 80, Mithril Bar
- Malachite Ore: 1085 (Studio: 20), 80 (Studio: 5), Malachite Bar
- Azurite Ore: 1085 (Studio: 20), 80 (Studio: 5), Azurite Bar

Other: ProductionBar2Cost = 4000 (second production bar upgrade). FuelData module required by client; fuel likely needed, unverified. Bars are NotPurchasable, AppearsInShop false.

Limits: server scripts hidden. Exact server checks (inventory decrement, fuel, temperature, range) not confirmed. Only client protocol and ore table verified.



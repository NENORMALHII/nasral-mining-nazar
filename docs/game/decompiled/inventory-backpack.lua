-- Script Path: game:GetService("ReplicatedStorage").Modules.Inventory.Backpack
-- Took 0.04s to decompile.
-- Executor: Delta (1.0.745.1142)

local v_u_1 = game:GetService("RunService")
local v_u_2 = require(game.ReplicatedStorage.Lib.Maid)
local v_u_3 = require(game.ReplicatedStorage.Modules.Constants)
local v_u_4 = require(game.ReplicatedStorage.Modules.Enums)
require(script.Parent.Types)
local v_u_5 = require(game.ReplicatedStorage.Lib.Signal)
local v_u_6 = require(game.ReplicatedStorage.Modules.Logger).sidedNew(script.Name)
local v_u_7 = {
    v_u_3.ATTR_ITEM_COUNT,
    v_u_3.ATTR_TOOL_MATERIAL,
    v_u_3.ATTR_TOOL_WOOD_MATERIAL,
    v_u_3.ATTR_TOOL_RESOURCE_TYPE
}
local v_u_8 = {}
v_u_8.__index = v_u_8
function v_u_8.new(p9) -- name: new
    -- upvalues: (copy) v_u_2, (copy) v_u_8, (copy) v_u_5
    local v10 = {
        ["player"] = nil,
        ["slots"] = nil,
        ["firstEmptySlot"] = 1,
        ["numSlots"] = 26,
        ["toolToSlotIds"] = nil,
        ["equippedTool"] = nil,
        ["baseTools"] = nil,
        ["maid"] = nil,
        ["player"] = p9,
        ["slots"] = {},
        ["toolToSlotIds"] = {},
        ["baseTools"] = {},
        ["maid"] = v_u_2.new()
    }
    local v11 = v_u_8
    local v_u_12 = setmetatable(v10, v11)
    v_u_12.Changed = v_u_5.new()
    v_u_12.maid:GiveTask(v_u_12.Changed)
    v_u_12.ToolAdded = v_u_5.new()
    v_u_12.maid:GiveTask(v_u_12.ToolAdded)
    v_u_12.ToolEquipped = v_u_5.new()
    v_u_12.maid:GiveTask(v_u_12.ToolEquipped)
    v_u_12.ToolUnquipped = v_u_5.new()
    v_u_12.maid:GiveTask(v_u_12.ToolUnquipped)
    v_u_12.ToolHandleChanged = v_u_5.new()
    v_u_12.maid:GiveTask(v_u_12.ToolHandleChanged)
    v_u_12:_ListenToBackpack(v_u_12.player.Backpack)
    v_u_12.maid:GiveTask(v_u_12.player.ChildAdded:Connect(function(p13)
        -- upvalues: (copy) v_u_12
        if p13:IsA("Backpack") then
            v_u_12:_ListenToBackpack(p13)
        end
    end))
    return v_u_12
end
function v_u_8.GetItem(p14, p15) -- name: GetItem
    return p14.slots[p15]
end
function v_u_8.Iterator(p16) -- name: Iterator
    return p16:_iterator(0, p16.numSlots)
end
function v_u_8.HotbarIterator(p17) -- name: HotbarIterator
    return p17:_iterator(0, 8)
end
function v_u_8.BackpackIterator(p18) -- name: BackpackIterator
    return p18:_iterator(8, p18.numSlots)
end
function v_u_8._iterator(p_u_19, p20, p_u_21) -- name: _iterator
    local v_u_22 = p20
    return function()
        -- upvalues: (ref) v_u_22, (copy) p_u_21, (copy) p_u_19
        if v_u_22 == p_u_21 then
            return nil
        end
        v_u_22 = v_u_22 + 1
        return v_u_22, p_u_19.slots[v_u_22]
    end
end
function v_u_8.GetSize(p23) -- name: GetSize
    return p23.numSlots
end
function v_u_8.GetBackpackSize(p24) -- name: GetBackpackSize
    return p24.numSlots - 8
end
function v_u_8.GetEquippedTool(p25) -- name: GetEquippedTool
    return p25.equippedTool
end
function v_u_8.Destroy(p26) -- name: Destroy
    p26.maid:DoCleaning()
    p26.player = nil
    setmetatable(p26, nil)
end
function v_u_8.GetBaseTool(p27, p28) -- name: GetBaseTool
    if not p27.baseTools[p28] then
        error("Could not find base tool with name " .. p28, 2)
    end
    return p27.baseTools[p28]
end
function v_u_8.OnToolAdded(p_u_29, p_u_30) -- name: OnToolAdded
    -- upvalues: (copy) v_u_4, (copy) v_u_7, (copy) v_u_1, (copy) v_u_6, (copy) v_u_3
    if p_u_30:IsA("Tool") and not p_u_29.toolToSlotIds[p_u_30] then
        local v31 = p_u_29.slots[p_u_29.firstEmptySlot] == nil
        assert(v31, "Slot at firstEmptySlot is not empty!")
        p_u_30.CanBeDropped = false
        if p_u_30.Name == "Axe" or p_u_30.Name == "Pick" then
            p_u_29.baseTools[p_u_30.Name] = p_u_30
        end
        local v32 = p_u_29.firstEmptySlot
        local v_u_33 = {
            ["Type"] = v_u_4.ItemType.Tool,
            ["Tool"] = p_u_30
        }
        p_u_29.slots[v32] = v_u_33
        p_u_29.toolToSlotIds[p_u_30] = v32
        p_u_29.firstEmptySlot = FindFirstEmptyIndex(p_u_29.slots, p_u_29.firstEmptySlot)
        if p_u_29.firstEmptySlot > p_u_29.numSlots then
            p_u_29.numSlots = p_u_29.firstEmptySlot
        end
        for _, v_u_34 in pairs(v_u_7) do
            if p_u_30:GetAttribute(v_u_34) == nil then
                continue
            end
            if v_u_1:IsServer() then
                v_u_6:debug("Listening for %s changes for %s", v_u_34, p_u_30.Name)
            end
            p_u_30:GetAttributeChangedSignal(v_u_34):Connect(function()
                -- upvalues: (copy) p_u_29, (copy) p_u_30, (copy) v_u_34, (ref) v_u_3
                p_u_29.Changed:Fire(p_u_29.toolToSlotIds[p_u_30])
                if v_u_34 == v_u_3.ATTR_TOOL_WOOD_MATERIAL then
                    p_u_29.ToolHandleChanged:Fire(p_u_30)
                end
            end)
        end
        p_u_29.ToolAdded:Fire(p_u_30)
        p_u_29.Changed:Fire()
        v_u_6:debug("Tool %s added in slot %d", p_u_30.Name, v32)
        p_u_29.maid:GiveTask(p_u_30.Destroying:Connect(function()
            -- upvalues: (copy) p_u_29, (copy) p_u_30, (ref) v_u_6
            local v35 = p_u_29.toolToSlotIds[p_u_30]
            v_u_6:debug("Tool %s destroyed in slot %d", p_u_30.Name, v35)
            p_u_29.slots[v35] = nil
            p_u_29.toolToSlotIds[p_u_30] = nil
            if v35 < p_u_29.firstEmptySlot then
                p_u_29.firstEmptySlot = v35
            end
            if p_u_29.equippedTool == p_u_30 then
                p_u_29.equippedTool = nil
            end
            p_u_29.Changed:Fire()
        end))
        p_u_29.maid:GiveTask(p_u_30.AncestryChanged:Connect(function()
            -- upvalues: (copy) p_u_30, (copy) p_u_29, (ref) v_u_6, (copy) v_u_33
            if p_u_30:IsDescendantOf(game) and (p_u_29.toolToSlotIds[p_u_30] and p_u_30.Parent ~= nil) then
                if p_u_30.Parent:IsA("Model") then
                    p_u_29.equippedTool = p_u_30
                    v_u_6:debug("Tool %s equipped", p_u_30.Name)
                    p_u_29.ToolEquipped:Fire(v_u_33.Tool)
                    return
                end
                if p_u_30.Parent:IsA("Backpack") and p_u_29.equippedTool == p_u_30 then
                    v_u_6:debug("Tool %s unequipped", p_u_30.Name)
                    p_u_29.equippedTool = nil
                    p_u_29.Changed:Fire()
                    p_u_29.ToolUnquipped:Fire(p_u_30)
                end
            end
        end))
    end
end
function v_u_8.EquipItem(p36, p37) -- name: EquipItem
    -- upvalues: (copy) v_u_6, (copy) v_u_4
    local v38
    if p37 > 0 then
        v38 = p37 <= p36.numSlots
    else
        v38 = false
    end
    local v39 = "Invalid slot index: " .. p37
    assert(v38, v39)
    local v40 = p36.slots[p37]
    if v40 then
        if v40.Type == v_u_4.ItemType.Tool and v40.Tool ~= nil then
            if p36.equippedTool == v40.Tool then
                p36:UnequipCurrentItem(true)
            else
                p36:UnequipCurrentItem(false)
                v40.Tool.Parent = p36.player.Character
                p36.Changed:Fire()
            end
        else
            return
        end
    else
        v_u_6:debug("Attempted to equip empty slot %d ", p37)
        return
    end
end
function v_u_8.UnequipCurrentItem(p41, p42) -- name: UnequipCurrentItem
    if p41.equippedTool then
        p41.equippedTool.Parent = p41.player.Backpack
        if p42 then
            p41.Changed:Fire()
        end
    end
end
function v_u_8.SwapItems(p43, p44, p45) -- name: SwapItems
    -- upvalues: (copy) v_u_6, (copy) v_u_4
    local v46
    if p44 > 0 then
        v46 = p44 <= p43.numSlots
    else
        v46 = false
    end
    local v47 = "Invalid 1st slot index: " .. p44
    assert(v46, v47)
    local v48
    if p45 > 0 then
        v48 = p45 <= p43.numSlots
    else
        v48 = false
    end
    local v49 = "Invalid 2nd slot index: " .. p45
    assert(v48, v49)
    v_u_6:debug("Swapping slots %d and %d", p44, p45)
    if p44 ~= p45 then
        local v50 = p43.slots[p44]
        local v51 = p43.slots[p45]
        p43.slots[p44] = v51
        p43.slots[p45] = v50
        if v50 and v50.Type == v_u_4.ItemType.Tool then
            p43.toolToSlotIds[v50.Tool] = p45
        end
        if v51 and v51.Type == v_u_4.ItemType.Tool then
            p43.toolToSlotIds[v51.Tool] = p44
        end
        p43.firstEmptySlot = FindFirstEmptyIndex(p43.slots, 1)
        p43.Changed:Fire()
    end
end
function v_u_8._ListenToBackpack(p_u_52, p53) -- name: _ListenToBackpack
    for _, v54 in pairs(p53:GetChildren()) do
        p_u_52:OnToolAdded(v54)
    end
    p_u_52.maid:GiveTask(p53.ChildAdded:Connect(function(p55)
        -- upvalues: (copy) p_u_52
        p_u_52:OnToolAdded(p55)
    end))
end
function v_u_8.GetDebugInfo(p56) -- name: GetDebugInfo
    local v57 = {}
    for v58, v59 in pairs(p56.slots) do
        local v60 = v59.Tool
        v57[v58] = tostring(v60)
    end
    local v61 = {}
    for v62, v63 in pairs(p56.toolToSlotIds) do
        v61[tostring(v62)] = v63
    end
    local v64 = {
        ["player"] = p56.player.Name,
        ["numSlots"] = p56.numSlots,
        ["firstEmptySlot"] = p56.firstEmptySlot
    }
    local v65 = p56.equippedTool
    v64.equippedTool = tostring(v65)
    v64.slots = v57
    v64.toolToSlotIds = v61
    return v64
end
function FindFirstEmptyIndex(p66, p67) -- name: FindFirstEmptyIndex
    local v68 = p67 > 0
    assert(v68, "startIndex must be a positive integer")
    while p66[p67] do
        p67 = p67 + 1
    end
    return p67
end
return v_u_8

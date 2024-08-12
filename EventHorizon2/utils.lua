local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
--

local clone = function(t)
    local new = {}
    local i, v = next(t, nil) -- i is an index of t, v = t[i]
    while i do
        new[i] = v
        i, v = next(t, i)
    end
    return new
end

local isTableEmpty = function(table)
    return type(next(table)) == "nil"
end

local equipSlots = {
    ["ChestSlot"] = 5,
    ["FeetSlot"] = 8,
    ["Finger0Slot"] = 11,
    ["Finger1Slot"] = 12,
    ["HandsSlot"] = 10,
    ["HeadSlot"] = 1,
    ["LegsSlot"] = 7,
    ["MainHandSlot"] = 16,
    ["NeckSlot"] = 2,
    ["SecondaryHandSlot"] = 17,
    ["ShirtSlot"] = 4,
    ["ShoulderSlot"] = 3,
    ["TabardSlot"] = 19,
    ["Trinket0Slot"] = 13,
    ["Trinket1Slot"] = 14,
    ["WaistSlot"] = 6,
    ["WristSlot"] = 9,
}

-- Since Blizzard doesn't provide the ability to look up a slot name from a slotID...
local getSlotName = function(slot)
    for k, v in pairs(equipSlots) do
        if v == slot then return k end
    end
end

export("Utils", {
    clone = clone,
    isTableEmpty = isTableEmpty,
    getSlotName = getSlotName,
})

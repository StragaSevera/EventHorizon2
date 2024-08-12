local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
--

local frames = {
    config = {},    -- validated barframe config entries - format = ns.frames.config[i] = {barconfig}
    frames = {},    -- all loaded barframes
    active = {},    -- refs to barframes currently collecting information (matches talent spec)
    shown = {},     -- refs to barframes currently visible to the player (matches stance)
    mouseover = {}, -- refs to barframes requiring mouseover target information
}

local SpellFrame = {}

local EventHorizonFrame = CreateFrame('Frame', 'EventHorizonFrame', UIParent)
local frame2 = CreateFrame('Frame')
local frame3 = CreateFrame('Frame')

export("Frames", {
    frames = frames,
    SpellFrame = SpellFrame,
    EventHorizonFrame = EventHorizonFrame,
    frame2 = frame2,
    frame3 = frame3,
})
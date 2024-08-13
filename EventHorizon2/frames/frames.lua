local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
local drawOrder = EHZ.drawOrder
local state = EHZ.State.state
local settings = EHZ.State.settings
local colors = EHZ.Config.colors
--

local frames = {
    config = {},    -- validated barframe config entries - format = ns.frames.config[i] = {barconfig}
    list = {},      -- all loaded barframes
    active = {},    -- refs to barframes currently collecting information (matches talent spec)
    shown = {},     -- refs to barframes currently visible to the player (matches stance)
    mouseover = {}, -- refs to barframes requiring mouseover target information
}

local SpellFrame = {}

local EventHorizonFrame = CreateFrame('Frame', 'EventHorizonFrame', UIParent)
local MainFrame = CreateFrame('Frame', nil, EventHorizonFrame)
local frame2 = CreateFrame('Frame')
local frame3 = CreateFrame('Frame')

local function createNowIndicator()
    local nowIndicator = MainFrame:CreateTexture(nil, 'ARTWORK', nil, drawOrder.nowI)
    nowIndicator:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
    nowIndicator:SetPoint('TOPLEFT', MainFrame, 'TOPLEFT', settings.nowleft, 0)
    nowIndicator:SetWidth(state.onepixelwide)
    nowIndicator:SetColorTexture(unpack(colors.nowLine))
    if settings.blendModes.nowLine and type(settings.blendModes.nowLine) == 'string' then
        nowIndicator:SetBlendMode(settings.blendModes.nowLine)
    end
    return nowIndicator
end

local function createGcd()
    local gcd = MainFrame:CreateTexture(nil, 'ARTWORK', nil, drawOrder.gcd)
    gcd:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
    gcd:SetPoint('TOP', MainFrame, 'TOP')
    gcd:Hide()

    if settings.gcdStyle == 'line' then
        gcd:SetWidth(state.onepixelwide)
    else
        gcd:SetPoint('LEFT', MainFrame, 'LEFT', settings.nowleft, 0)
    end

    local gcdColor = colors.gcdColor or { .5, .5, .5, .3 }
    gcd:SetColorTexture(unpack(gcdColor))
    if settings.blendModes.gcdColor and type(settings.blendModes.gcdColor) == 'string' then
        gcd:SetBlendMode(settings.blendModes.gcdColor)
    end
    return gcd
end

local function InitFrames()
    MainFrame:init()

    -- Create the indicator for the current time.
    -- Bugfix: When the UI scale is at a very low setting, textures with a width of 1
    -- were not visible in some resolutions.
    local effectiveScale = MainFrame:GetEffectiveScale()
    if effectiveScale then
        state.onepixelwide = 1 / effectiveScale
    end

    frames.list.nowIndicator = createNowIndicator()
    if state.gcdSpellName and settings.gcdStyle then
        frames.list.gcd = createGcd()
    end
end

export("Frames", {
    frames = frames,
    SpellFrame = SpellFrame,
    EventHorizonFrame = EventHorizonFrame,
    MainFrame = MainFrame,
    frame2 = frame2,
    frame3 = frame3,
    InitFrames = InitFrames,
})

local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
local clone = EHZ.Utils.clone
local config = EHZ.Config.config
local layouts = EHZ.Config.layouts
local colors = EHZ.Config.colors
local exemptColors = EHZ.exemptColors

local CLASSCOLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
--

local state = {
    onepixelwide = 1,
    visibleFrame = true,
    numframes = 0,
    buff = {},
    debuff = {},
}

local settings = {}

local function InitSettings()
    table.wipe(settings)

    -- self:InitializeClass() -- Set config values in class modules

    settings.past = -math.abs(config.past or -3)               -- We really don't want config.past to be positive, so negative absolute values work great here.
    settings.future = math.abs(config.future or 9)
    settings.barheight = config.height or 18
    settings.barwidth = config.width or 150
    settings.barspacing = config.spacing or 0
    settings.scale = 1 / (settings.future - settings.past)
    settings.bartexture = config.bartexture or 'Interface\\Addons\\EventHorizon\\Smooth'
    settings.texturedbars = config.texturedbars
    settings.texturealpha = config.texturealphamultiplier or 1
    settings.classburn = config.classburn or 0.7
    settings.classalpha = config.classalpha or 0.3
    settings.castLine = config.castLine and
        ((type(config.castLine) == 'number' and config.castLine) or config.castLine == true and 0) or nil
    settings.nowleft = -settings.past / (settings.future - settings.past) * settings.barwidth - 0.5 +
        (config.hideIcons and 0 or config.height)

    settings.stackFont = config.stackFont
    settings.stackFontSize = config.stackFontSize
    settings.stackFontColor = config.stackFontColor == true and { 1, 1, 1, 1 } or config.stackFontColor or { 1, 1, 1, 1 }
    settings.stackFontShadow = config.stackFontShadow == true and { 0, 0, 0, 0.5 } or config.stackFontShadow or
    { 0, 0, 0, 0.5 }
    settings.stackFontShadowOffset = config.stackFontShadowOffset == true and { 1, -1 } or config.stackFontShadowOffset or
        { 1, -1 }

    settings.classColor = clone(CLASSCOLORS[select(2, UnitClass('player'))])
    local classColor = settings.classColor

    for colorid, color in pairs(colors) do
        if color[1] == true then
            if color[2] then
                colors[colorid] = { classColor.r * color[2], classColor.g * color[2], classColor.b *
                color[2], color[3] or settings.classalpha } -- For really bad reasons, this took a very long time to get right...
            else
                colors[colorid] = { classColor.r, classColor.g, classColor.b, settings.classalpha }
            end
        end
    end

    if settings.texturedbars then
        for colorid, color in pairs(colors) do
            if color[4] and not (exemptColors[colorid]) then
                color[4] = settings.texturealpha * color[4]
            end
        end
    end

    layouts.frameline = {
        top = 0,
        bottom = 1,
    }
    local default = layouts.default
    for typeid, layout in pairs(layouts) do
        if typeid ~= 'default' then
            for k, v in pairs(default) do
                if layout[k] == nil then
                    layout[k] = v
                end
            end
        end
        layout.texcoords = { 0, 1, layout.top, layout.bottom }
    end

    -- If we didn't override something in settings,
    -- return the data from config
    setmetatable(settings, {
        __index = config
    })

        -- ns:ModuleEvent('ApplyConfig')
end

export("State", {
    state = state,
    settings = settings,
    InitSettings = InitSettings,
})
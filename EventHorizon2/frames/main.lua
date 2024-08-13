local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
local importDelayed = EHZ.importDelayed
-- TODO: Find a way to move mainframe init here
local MainFrame = EHZ.Frames.MainFrame
local EventHandler = EHZ.Events.EventHandler
local settings = EHZ.State.settings
local colors = EHZ.Config.colors

local db, dbg; importDelayed(EHZ.Database.dbEntity, function(...) db, dbg = ... end)
--

-- Create the main and spell frames.
MainFrame:SetHeight(1)
MainFrame.numframes = 0
MainFrame.framebyspell = {}
MainFrame:SetScript('OnEvent', EventHandler)
MainFrame:SetScale(settings.scale or 1)

-- MainFrame.CLEU_OtherInterestingSpell = mainFrame_CLEU_OtherInterestingSpell
-- MainFrame.UPDATE_SHAPESHIFT_FORM = mainFrame_UPDATE_SHAPESHIFT_FORM
-- MainFrame.SPELL_UPDATE_COOLDOWN = mainFrame_SPELL_UPDATE_COOLDOWN
-- MainFrame.COMBAT_LOG_EVENT_UNFILTERED = mainFrame_COMBAT_LOG_EVENT_UNFILTERED
-- MainFrame.UPDATE_SHAPESHIFT_FORMS = mainFrame_UPDATE_SHAPESHIFT_FORM
-- MainFrame.PLAYER_TALENT_UPDATE = CheckTalents
-- MainFrame.ACTIVE_TALENT_GROUP_CHANGED = CheckTalents
-- MainFrame.TRAIT_CONFIG_UPDATED = CheckTalents
-- MainFrame.PLAYER_LEVEL_UP = CheckTalents
-- MainFrame.PLAYER_TARGET_CHANGED = mainFrame_PLAYER_TARGET_CHANGED
-- MainFrame.UNIT_AURA = mainFrame_UNIT_AURA
-- MainFrame.PLAYER_TOTEM_UPDATE = mainFrame_PLAYER_TOTEM_UPDATE
-- MainFrame.PLAYER_ENTERING_WORLD = mainFrame_PLAYER_ENTERING_WORLD

function MainFrame:init()
    self:SetWidth(settings.barwidth + (settings.hideIcons and 0 or settings.height))

    self:setupStyleFrame()
    self:setupAnchor()
end

-- Spawns or hides backdrop frame.
function MainFrame:setupStyleFrame()
    if settings.backdrop then
        if not (self.styleframe) then self.styleframe = CreateFrame('Frame', nil, MainFrame, "BackdropTemplate") end
    else
        if self.styleframe then self.styleframe:Hide() end
        return
    end

    local styleframe = self.styleframe
    local stylebg = settings.bg or 'Interface\\ChatFrame\\ChatFrameBackground'
    local styleborder = settings.border or 'Interface\\Tooltips\\UI-Tooltip-Border'
    local stylebgcolor = colors.bgcolor or { 0, 0, 0, 0.6 }
    local stylebordercolor = colors.bordercolor or { 1, 1, 1, 1 }
    local styleinset = settings.inset or { top = 2, bottom = 2, left = 2, right = 2 }
    local stylepadding = settings.padding or 3
    local styleedge = settings.edgesize or 8

    styleframe:SetFrameStrata('BACKGROUND')
    styleframe:SetPoint('TOPRIGHT', MainFrame, 'TOPRIGHT', stylepadding, stylepadding)
    styleframe:SetPoint('BOTTOMLEFT', MainFrame, 'BOTTOMLEFT', -stylepadding, -stylepadding)
    styleframe:SetBackdrop({
        bgFile = stylebg,
        edgeFile = styleborder,
        tileSize = 0,
        edgeSize = styleedge,
        insets = styleinset,
    })
    styleframe:SetBackdropColor(unpack(stylebgcolor))
    styleframe:SetBackdropBorderColor(unpack(stylebordercolor))
end


function MainFrame:anchor()
    local anchor = settings.anchor or { 'TOPRIGHT', 'EventHorizonHandle', 'BOTTOMRIGHT' }
    local hasAnchor = anchor[2] == 'EventHorizonHandle'
    return hasAnchor, anchor
end

local EventHorizonHandle

function MainFrame:setupAnchor()
    local hasAnchor, anchor = self:anchor()
    if hasAnchor then
        debug("Creating handle!")
        -- Create the handle to reposition the frame.
        EventHorizonHandle = CreateFrame('Frame', 'EventHorizonHandle', MainFrame)
        EventHorizonHandle:SetFrameStrata('HIGH')
        EventHorizonHandle:SetWidth(10)
        EventHorizonHandle:SetHeight(5)
        EventHorizonHandle:EnableMouse(true)
        EventHorizonHandle:SetClampedToScreen(true)
        EventHorizonHandle:RegisterForDrag('LeftButton')
        EventHorizonHandle:SetScript('OnDragStart', function(handle, _) handle:StartMoving() end)
        EventHorizonHandle:SetScript('OnDragStop', function(handle)
            handle:StopMovingOrSizing()
            local a, b, c, d, e = handle:GetPoint(1)
            if type(b) == 'frame' then
                b = b:GetName()
            end
            db.point = { a, b, c, d, e }
        end)
        EventHorizonHandle:SetMovable(true)

        self:SetPoint(unpack(anchor))
        self:SetHandlePoint(db.point)

        EventHorizonHandle.tex = EventHorizonHandle:CreateTexture(nil, 'ARTWORK', nil, 7)
        EventHorizonHandle.tex:SetAllPoints()
        EventHorizonHandle:SetScript('OnEnter', function(frame) frame.tex:SetColorTexture(1, 1, 1, 1) end)
        EventHorizonHandle:SetScript('OnLeave', function(frame) frame.tex:SetColorTexture(1, 1, 1, 0.1) end)
        EventHorizonHandle.tex:SetColorTexture(1, 1, 1, 0.1)

        if db.isLocked then
            EventHorizonHandle:Hide()
        end
    end

    self:SetPoint(unpack(anchor))
end

function MainFrame:SetHandlePoint(point)
    EventHorizonHandle:SetPoint(unpack(point))
end

function MainFrame:SwitchLock()
    if EventHorizonHandle:IsShown() then
        EventHorizonHandle:Hide()
        db.isLocked = true
    else
        EventHorizonHandle:Show()
        db.isLocked = false
    end
    return db.isLocked
end
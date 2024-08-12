local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
local importDelayed = EHZ.importDelayed
local vars = EHZ.vars
local clone = EHZ.Utils.clone
local EventHandler = EHZ.Events.EventHandler
local InitDB = EHZ.Database.InitDB
local db, dbg; importDelayed(EHZ.Database.dbEntity, function(...) db, dbg = ... end)
--

local frame = CreateFrame('Frame')
frame.isReady = false

frame:SetScript('OnEvent', EventHandler)
frame:RegisterEvent('PLAYER_LOGIN')

frame.PLAYER_ALIVE = function(self)
    debug("Player is alive!")
    -- TODO
    -- self:SetScript('OnUpdate', UpdateMouseover)
    -- frame2:SetScript('OnEvent', EventHandler)
    -- for k, v in pairs(reloadEvents) do
    --     frame2:RegisterEvent(k)
    --     frame2[k] = loginCheck
    -- end
    if not (frame.isReady) then
        Initialize()
    else
        -- TODO
        -- LoadModules()
    end
    self:UnregisterEvent('PLAYER_ALIVE')
end

frame.PLAYER_LOGIN = function(self)
    local spec = GetSpecialization()
    -- local talents = GetTalentInfo(1)
    if spec then
        debug("Player logged in!")
        self:UnregisterEvent('PLAYER_LOGIN')
        -- TODO
        -- self:SetScript('OnUpdate', UpdateMouseover)
        -- frame2:SetScript('OnEvent', EventHandler)
        -- for k, v in pairs(reloadEvents) do
        --     frame2:RegisterEvent(k)
        --     frame2[k] = loginCheck
        -- end
        if not (frame.isReady) then
            Initialize()
        else
            -- TODO
            -- LoadModules()
        end
    else
        self:UnregisterEvent('PLAYER_LOGIN')
        self:RegisterEvent('PLAYER_ALIVE')
    end
end

function Load()
    if frame.isReady then return end
    frame.isReady = true
    self:CheckRequirements()
    self:LoadModules()

    debug("frames shown " .. #self.frames.shown)
    if #self.frames.shown < 1 then
        ns:DisplayEmptyFrameTip()
    else
        ns.mainFrame:Show()
    end
end

--[[
Should only be called after the DB is loaded and spell and talent information is available.
--]]
function Initialize()
    debug("Initializing...")
    InitDB()

    debug('GetTalentInfo(1,1)', GetTalentInfo(1, 1))
    vars.playerguid = UnitGUID('player')

    vars.buff.player = {}

    if not self:LoadClassModule() then
        return
    end

    self:ApplyConfig()

    if self.config.showTrinketBars and self.config.showTrinketBars == true then
        self:NewSpell({ slotID = 13 })
        self:NewSpell({ slotID = 14 })
    end

    local sfi = self.config.hideIcons
    MainFrame:SetWidth(vars.barwidth + (sfi and 0 or self.config.height))

    self:SetupStyleFrame() -- Spawn backdrop frame.

    -- Create the indicator for the current time.
    -- Bugfix: When the UI scale is at a very low setting, textures with a width of 1
    -- were not visible in some resolutions.
    local effectiveScale = MainFrame:GetEffectiveScale()
    if effectiveScale then
        vars.onepixelwide = 1 / effectiveScale
    end
    --nowI = CreateFrame('Frame',nil,mainFrame)
    --nowI:SetFrameLevel(20)
    ns.frames.nowIndicator = MainFrame:CreateTexture(nil, 'ARTWORK', nil, draworder.nowI)

    ns.frames.nowIndicator:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
    ns.frames.nowIndicator:SetPoint('TOPLEFT', MainFrame, 'TOPLEFT', vars.nowleft, 0)
    ns.frames.nowIndicator:SetWidth(vars.onepixelwide)
    ns.frames.nowIndicator:SetColorTexture(unpack(self.colors.nowLine))
    if self.config.blendModes.nowLine and type(self.config.blendModes.nowLine) == 'string' then
        ns.frames.nowIndicator:SetBlendMode(self.config.blendModes.nowLine)
    end

    local anchor = self.config.anchor or { 'TOPRIGHT', 'EventHorizonHandle', 'BOTTOMRIGHT' }
    if anchor[2] == 'EventHorizonHandle' then
        -- Create the handle to reposition the frame.
        handle = CreateFrame('Frame', 'EventHorizonHandle', MainFrame)
        handle:SetFrameStrata('HIGH')
        handle:SetWidth(10)
        handle:SetHeight(5)
        handle:EnableMouse(true)
        handle:SetClampedToScreen(1)
        handle:RegisterForDrag('LeftButton')
        handle:SetScript('OnDragStart', function(handle, button) handle:StartMoving() end)
        handle:SetScript('OnDragStop', function(handle)
            handle:StopMovingOrSizing()
            local a, b, c, d, e = handle:GetPoint(1)
            if type(b) == 'frame' then
                b = b:GetName()
            end
            EventHorizon2DB.point = { a, b, c, d, e }
        end)
        handle:SetMovable(true)

        MainFrame:SetPoint(unpack(anchor))
        handle:SetPoint(unpack(EventHorizon2DB.point))

        handle.tex = handle:CreateTexture(nil, 'ARTWORK', nil, 7)
        handle.tex:SetAllPoints()
        handle:SetScript('OnEnter', function(frame) frame.tex:SetColorTexture(1, 1, 1, 1) end)
        handle:SetScript('OnLeave', function(frame) frame.tex:SetColorTexture(1, 1, 1, 0.1) end)
        handle.tex:SetColorTexture(1, 1, 1, 0.1)

        if EventHorizon2DB.isLocked then
            handle:Hide()
        end
    end

    vars.gcdSpellName = self.config.gcdSpellID and (GetSpellInfo(self.config.gcdSpellID))
    if vars.gcdSpellName and self.config.gcdStyle then
        -- Create the GCD indicator, register cooldown event.
        ns.frames.gcd = MainFrame:CreateTexture(nil, 'ARTWORK', nil, draworder.gcd)
        ns.frames.gcd:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
        ns.frames.gcd:SetPoint('TOP', MainFrame, 'TOP')
        ns.frames.gcd:Hide()

        if self.config.gcdStyle == 'line' then
            ns.frames.gcd:SetWidth(vars.onepixelwide)
        else
            ns.frames.gcd:SetPoint('LEFT', MainFrame, 'LEFT', vars.nowleft, 0)
        end

        local gcdColor = self.colors.gcdColor or { .5, .5, .5, .3 }
        ns.frames.gcd:SetColorTexture(unpack(gcdColor))
        if self.config.blendModes.gcdColor and type(self.config.blendModes.gcdColor) == 'string' then
            ns.frames.gcd:SetBlendMode(self.config.blendModes.gcdColor)
        end
    end

    if not (ns.config.hastedSpellID and type(ns.config.hastedSpellID) == 'table') then
        vars.useOldHaste = true
    end

    if ns.config.nonAffectingHaste then
        if type(ns.config.nonAffectingHaste[1]) == 'number' then
            ns.config.nonAffectingHaste = { ns.config.nonAffectingHaste }
        end
    end

    MainFrame:SetPoint(unpack(anchor))

    SLASH_EVENTHORIZON1 = '/eventhorizon'
    SLASH_EVENTHORIZON2 = '/ehz'
    SlashCmdList['EVENTHORIZON'] = function(msg)
        local cmd = string.lower(msg)
        local toggle = not (msg) or cmd == ''

        if cmd == 'help' then
            print('Use "/eventhorizon" or "/ehz" to show or hide EventHorizon.')
            print('To enable or disable a module, use "/ehz ModuleName". For example, "/ehz redshift".')
            print('To see a list of currently installed modules and visible bars, use "/ehz status".')
            if anchor[2] == 'EventHorizonHandle' then
                print('  EventHorizon is currently ' .. (EventHorizon2DB.isLocked and 'locked.' or 'movable.'))
                print('  To ' .. (EventHorizon2DB.isLocked and 'unlock ' or 'lock ') .. 'EventHorizon, use "/ehz lock".')
                print('  If you are unable see or move EventHorizon, use "/ehz reset".')
            end
        elseif cmd == 'status' then
            print('Installed plugins:')
            for i in pairs(self.modules) do print('  ' .. i) end
            print('Visible bars:')
            for i, v in pairs(self.frames.shown) do print('  ' .. v.spellname) end
        elseif cmd == 'talents' then
            print('Detected talents:')
            for tid, ta in pairs(vars.currentTalents) do
                print('  ' ..
                    ta .. ' in ' .. tid .. ' (' .. select(1, GetSpellInfo(tid)) .. ')')
            end
        elseif cmd == 'reset' then
            if anchor[2] == 'EventHorizonHandle' then
                print('Resetting EventHorizon\'s position.')
                EventHorizonHandle:SetPoint(unpack(self.defaultDB.point))
                self:CheckTalents()
            else
                print "The frame is otherwise anchored. Adjust config.anchor in [my]config.lua to move EventHorizon."
            end
        elseif cmd == 'lock' then
            if anchor[2] == 'EventHorizonHandle' then
                if EventHorizonHandle:IsShown() then
                    EventHorizonHandle:Hide()
                    EventHorizon2DB.isLocked = true
                else
                    EventHorizonHandle:Show()
                    EventHorizon2DB.isLocked = nil
                end
                print("The frame is now " .. (EventHorizon2DB.isLocked and 'locked.' or 'unlocked.'))
            else
                print "The frame is otherwise anchored. Adjust config.anchor in [my]config.lua to move EventHorizon."
            end
        elseif self.modules[cmd] then
            self:ToggleModule(string.lower(msg))
            print(string.lower(msg) ..
                ' has been turned ' .. ((self.modules[string.lower(msg)].isActive == true) and 'ON' or 'OFF') .. '.')
        elseif toggle then
            if self.isActive then
                print('Deactivating. Use "/ehz help" to see what else you can do.')
                self:Deactivate()
                MainFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
            else
                print('Activating. Use "/ehz help" to see what else you can do.')
                print('Will be hidden automatically if there\' no active bars')
                self:Activate()
                self:CheckTalents()
            end
        else
            print(
                'Invalid command. Use "/ehz" alone to show or hide EventHorizon, or "/ehz help" to see a list of commands.')
        end
        EventHorizon2DB.isActive = self.isActive
    end

    ns.isActive = EventHorizon2DB.isActive
    if not EventHorizon2DB.isActive then
        self:Deactivate()
        MainFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
    end


    -- Display helpful error message if there was a problem loading the class config
    debug("config: " .. #self.frames.config)
    if #self.frames.config < 1 then
        StaticPopup_Show("EH_EmptyConfig")
    end

    ns.mainFrame:Hide() -- Hide EH until the config loads
    ns:Load()
end

export("Frames.Lifecycle", {
    LifecycleFrame = frame,
})

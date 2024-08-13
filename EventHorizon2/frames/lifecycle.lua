local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
local importDelayed = EHZ.importDelayed
local state = EHZ.State.state
local settings = EHZ.State.setting
local InitState = EHZ.State.InitState
local clone = EHZ.Utils.clone
local EventHandler = EHZ.Events.EventHandler
local InitDB = EHZ.Database.InitDB
local defaultDB = EHZ.Database.defaultDB
local InitFrames = EHZ.Frames.InitFrames
local MainFrame = EHZ.Frames.MainFrame

local db, dbg; importDelayed(EHZ.Database.dbEntity, function(...) db, dbg = ... end)
local currentProfile; importDelayed(EHZ.Database.currentProfileEntity, function(...) currentProfile = ... end)

local GetSpellInfo = C_Spell.GetSpellInfo
--
local Init, SetupSlashCommands
local frame = CreateFrame('Frame')
frame.isReady = false

frame:SetScript('OnEvent', EventHandler)
frame:RegisterEvent('PLAYER_LOGIN')

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
            Init()
        else
            -- TODO
            -- LoadModules()
        end
    else
        self:UnregisterEvent('PLAYER_LOGIN')
        self:RegisterEvent('PLAYER_ALIVE')
    end
end

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
        Init()
    else
        -- TODO
        -- LoadModules()
    end
    self:UnregisterEvent('PLAYER_ALIVE')
end


--[[
Should only be called after the DB is loaded and spell and talent information is available.
--]]
Init = function()
    debug("Initializing...")
    InitDB()

    -- debug('GetTalentInfo(1, 1, 1)', GetTalentInfo(1, 1, 1))

    state.playerguid = UnitGUID('player')
    state.buff.player = {}

    --[[
    if not self:LoadClassModule() then
        return
    end
    ]]

    InitState()

    -- TODO: Add trinkets
    -- if config.showTrinketBars and config.showTrinketBars == true then
    --     self:NewSpell({ slotID = 13 })
    --     self:NewSpell({ slotID = 14 })
    -- end

    InitFrames()

    SetupSlashCommands()

    if not db.isActive then
        -- TODO: Activation
        -- self:Deactivate()
        -- MainFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
    end


    -- Display helpful error message if there was a problem loading the class config
    -- debug("config: " .. #self.frames.config)
    -- if #self.frames.config < 1 then
    --     StaticPopup_Show("EH_EmptyConfig")
    -- end

    -- ns.mainFrame:Hide() -- Hide EH until the config loads
    -- ns:Load()
end

local function Load()
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

SetupSlashCommands = function()
    SLASH_EVENTHORIZON1 = '/eventhorizon'
    SLASH_EVENTHORIZON2 = '/ehz'
    SlashCmdList['EVENTHORIZON'] = function(msg)
        local cmd = string.lower(msg)
        local toggle = not (msg) or cmd == ''

        if cmd == 'help' then
            print('Use "/eventhorizon" or "/ehz" to show or hide EventHorizon 2.')
            print(
            'To enable or disable a module, use "/ehz ModuleName". For example, "/ehz redshift". TODO: Does not work now')
            print('To see a list of currently installed modules and visible bars, use "/ehz status".')
            print('To see a list of currently detected talents, use "/ehz status".')
            if MainFrame:anchor() then
                print('  EventHorizon is currently ' .. (db.isLocked and 'locked.' or 'movable.'))
                print('  To ' .. (db.isLocked and 'unlock ' or 'lock ') .. 'EventHorizon, use "/ehz lock".')
                print('  If you are unable see or move EventHorizon, use "/ehz reset".')
            end
        elseif cmd == 'status' then
            -- TODO
            print("Yep, doesn't work")
            -- print('Installed plugins:')
            -- for i in pairs(self.modules) do print('  ' .. i) end
            -- print('Visible bars:')
            -- for i, v in pairs(self.frames.shown) do print('  ' .. v.spellname) end
        elseif cmd == 'talents' then
            print('Detected talents:')
            -- TODO: Add talent detection
            for tid, ta in pairs(state.currentTalents) do
                print('  ' ..
                    ta .. ' in ' .. tid .. ' (' .. select(1, GetSpellInfo(tid)) .. ')')
            end
        elseif cmd == 'reset' then
            if MainFrame:anchor() then
                print("Resetting EventHorizon's position.")
                MainFrame:SetHandlePoint(defaultDB.point)
                -- TODO: Add talents
                -- self:CheckTalents()
            else
                print "The frame is otherwise anchored. Adjust config.anchor in [my]config.lua to move EventHorizon."
            end
        elseif cmd == 'lock' then
            if MainFrame:anchor() then
                local state = MainFrame:SwitchLock()
                print("The frame is now " .. state and "locked." or "unlocked.")
            else
                print "The frame is otherwise anchored. Adjust config.anchor in [my]config.lua to move EventHorizon."
            end
            -- TODO: Add toggling of modules
            -- elseif self.modules[cmd] then
            --     self:ToggleModule(string.lower(msg))
            --     print(string.lower(msg) ..
            --         ' has been turned ' .. ((self.modules[string.lower(msg)].isActive == true) and 'ON' or 'OFF') .. '.')
        elseif toggle then
            if db.isActive then
                print('Deactivating. Use "/ehz help" to see what else you can do.')
                -- TODO: Add activation and deactivation
                -- self:Deactivate()
                -- MainFrame:UnregisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
            else
                print('Activating. Use "/ehz help" to see what else you can do.')
                print('Will be hidden automatically if there\' no active bars')
                -- self:Activate()
                -- self:CheckTalents()
            end
        else
            print(
                'Invalid command. Use "/ehz" alone to show or hide EventHorizon, or "/ehz help" to see a list of commands.')
        end
    end
end

export("Frames.Lifecycle", {
    LifecycleFrame = frame,
})

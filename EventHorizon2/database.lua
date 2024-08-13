local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local dump = EHZ.dump
local export = EHZ.export
local exportDelayed = EHZ.exportDelayed
local playerName = EHZ.playerName
local clone = EHZ.Utils.clone
local isTableEmpty = EHZ.Utils.isTableEmpty
--

local db, dbg
local dbEntity = {}
local exportDB

local currentProfile
local currentProfileEntity = {}
local exportProfile

local defaultDB = {
    point = { 'CENTER', 'UIParent', 'CENTER' },
    isActive = true,
    version = 1,
}

local defaultDBG = {
    profiles = {
        default = {},
    },
    itemInfo = {},
    profileNamePerChar = {},
    defaultProfileName = 'default',
    version = 1,
}

-- Debug function. Global, to be able to /run EHZDebugResetDB()
function EHZDebugResetDB()
    debug("RESETTING DB!!!")
    if EventHorizon2DB then table.wipe(EventHorizon2DB) end
    if EventHorizon2DBG then table.wipe(EventHorizon2DBG) end
end

local function InitDB()
    if not EventHorizon2DB or isTableEmpty(EventHorizon2DB) then EventHorizon2DB = clone(defaultDB) end
    local reset = false
    -- Upgrade DB.
    if EventHorizon2DB and not EventHorizon2DB.version then
        EventHorizon2DB.version = 0
    end
    if EventHorizon2DB.version ~= defaultDB.version then
        reset = true
        table.wipe(EventHorizon2DB)
        EventHorizon2DB = clone(defaultDB)
    end
    db = EventHorizon2DB

    if not EventHorizon2DBG or isTableEmpty(EventHorizon2DBG) then EventHorizon2DBG = clone(defaultDBG) end
    -- Upgrade DB.
    if EventHorizon2DBG and not EventHorizon2DBG.version then
        EventHorizon2DBG.version = 0
    end
    if EventHorizon2DBG.version ~= defaultDBG.version then
        reset = true
        table.wipe(EventHorizon2DBG)
        EventHorizon2DBG = clone(defaultDBG)
    end
    dbg = EventHorizon2DBG
    exportDB()
    
    -- If profile doesn't exist, set it to the default.
    dbg.profileNamePerChar[playerName] = dbg.profileNamePerChar[playerName] or dbg.defaultProfileName
    local profileName = dbg.profileNamePerChar[playerName]
    
    dbg.profiles[profileName] = dbg.profiles[profileName] or {}
    currentProfile = dbg.profiles[profileName]

    if reset then
        print('Your savedvariables have been reset due to potential conflicts with older versions.')
    end

    exportProfile()
end

exportDB = exportDelayed(dbEntity, function() return db, dbg end)
exportProfile = exportDelayed(currentProfileEntity, function() return currentProfile end)

export("Database", {
    InitDB = InitDB,
    dbEntity = dbEntity,
    currentProfileEntity = currentProfileEntity
})

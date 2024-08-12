local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export

local mainFrameEvents = {
    ['COMBAT_LOG_EVENT_UNFILTERED'] = true,
    ['PLAYER_TALENT_UPDATE'] = true,
    ['ACTIVE_TALENT_GROUP_CHANGED'] = true,
    ['TRAIT_CONFIG_UPDATED'] = true,
    ['UPDATE_SHAPESHIFT_FORM'] = true,
    ['UPDATE_SHAPESHIFT_FORMS'] = true,
    ['SPELL_UPDATE_COOLDOWN'] = true,
    ['PLAYER_LEVEL_UP'] = true,
    ['PLAYER_TARGET_CHANGED'] = true,
    ['UNIT_AURA'] = true,
    ['PLAYER_TOTEM_UPDATE'] = true,
    ['PLAYER_ENTERING_WORLD'] = true,
}

local reloadEvents = {
    ['PLAYER_REGEN_DISABLED'] = true,
    ['PLAYER_REGEN_ENABLED'] = true,
    ['ZONE_CHANGED_NEW_AREA'] = true,
    ['ZONE_CHANGED_INDOORS'] = true,
    ['LFG_LOCK_INFO_RECEIVED'] = true,
    ['PLAYER_TALENT_UPDATE'] = true,
    ['ACTIVE_TALENT_GROUP_CHANGED'] = true,
    ['TRAIT_CONFIG_UPDATED'] = true,
    ['PLAYER_ENTERING_WORLD'] = true,
}

local tickevents = {
    ['SPELL_PERIODIC_DAMAGE'] = true,
    ['SPELL_PERIODIC_HEAL'] = true,
    ['SPELL_PERIODIC_ENERGIZE'] = true,
    ['SPELL_PERIODIC_DRAIN'] = true,
    ['SPELL_PERIODIC_LEACH'] = true,
    ['SPELL_DAMAGE'] = true,
    ['SPELL_HEAL'] = true,
    --['SPELL_AURA_APPLIED'] = true,
}

-- Dispatch event to method of the event's name.
local function EventHandler(self, event, ...)
    local eventFunction = self[event]
    if eventFunction then
        if event == 'COMBAT_LOG_EVENT' or event == 'COMBAT_LOG_EVENT_UNFILTERED' then
            return eventFunction(self, CombatLogGetCurrentEventInfo())
        end
        eventFunction(self, ...)
        EHZ.debug("Catched event: ", event)
        -- TODO: Find out what it is
        -- ns:ModuleEvent(event,...)
    end
end

export("Events", {
    mainFrameEvents = mainFrameEvents,
    reloadEvents = reloadEvents,
    tickevents = tickevents,
    EventHandler = EventHandler,
})

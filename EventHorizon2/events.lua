local _, EHZ = ...

local debug = EHZ.debug

-- Dispatch event to method of the event's name.
local function EventHandler(self, event, ...)
    local eventFunction = self[event]
    if eventFunction then
        if event == 'COMBAT_LOG_EVENT' or event == 'COMBAT_LOG_EVENT_UNFILTERED' then
            return eventFunction(self, CombatLogGetCurrentEventInfo())
        end
        eventFunction(self, ...)
        EHZ.debug("ns:ModuleEvent(event,...)")
        -- TODO: Find out what it is
        -- ns:ModuleEvent(event,...)
    end
end

EHZ.Events = {
    EventHandler = EventHandler
}

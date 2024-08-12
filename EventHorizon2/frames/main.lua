local _, EHZ = ...

-- Imports
local debug = EHZ.debug
local export = EHZ.export
local EventHorizonFrame = EHZ.Frames.EventHorizonFrame
local EventHandler = EHZ.Events.EventHandler
local config = EHZ.config

local MainFrame = CreateFrame('Frame', nil, EventHorizonFrame)

-- Create the main and spell frames.
MainFrame:SetHeight(1)
MainFrame.numframes = 0
MainFrame.framebyspell = {}
MainFrame:SetScript('OnEvent', EventHandler)
MainFrame:SetScale(config.scale or 1)

MainFrame.CLEU_OtherInterestingSpell = mainFrame_CLEU_OtherInterestingSpell
MainFrame.UPDATE_SHAPESHIFT_FORM = mainFrame_UPDATE_SHAPESHIFT_FORM
MainFrame.SPELL_UPDATE_COOLDOWN = mainFrame_SPELL_UPDATE_COOLDOWN
MainFrame.COMBAT_LOG_EVENT_UNFILTERED = mainFrame_COMBAT_LOG_EVENT_UNFILTERED
MainFrame.UPDATE_SHAPESHIFT_FORMS = mainFrame_UPDATE_SHAPESHIFT_FORM
MainFrame.PLAYER_TALENT_UPDATE = CheckTalents
MainFrame.ACTIVE_TALENT_GROUP_CHANGED = CheckTalents
MainFrame.TRAIT_CONFIG_UPDATED = CheckTalents
MainFrame.PLAYER_LEVEL_UP = CheckTalents
MainFrame.PLAYER_TARGET_CHANGED = mainFrame_PLAYER_TARGET_CHANGED
MainFrame.UNIT_AURA = mainFrame_UNIT_AURA
MainFrame.PLAYER_TOTEM_UPDATE = mainFrame_PLAYER_TOTEM_UPDATE
MainFrame.PLAYER_ENTERING_WORLD = mainFrame_PLAYER_ENTERING_WORLD

export("Frames.Main", {
    MainFrame = MainFrame
})

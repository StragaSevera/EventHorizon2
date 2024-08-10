local _, EHZ = ...

local DEBUG = true
local spellIDsEnabled = DEBUG
local class = select(2, UnitClass('player'))
local playerName = UnitName('player') .. ' - ' .. GetRealmName()

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
  profilePerChar = {},
  defaultProfile = 'default',
  version = 14,
}

local db = {
  point = { 'CENTER', 'UIParent', 'CENTER' },
  isActive = true,
  version = 1,
}

local frames = {
  config = {},    -- validated barframe config entries - format = ns.frames.config[i] = {barconfig}
  frames = {},    -- all loaded barframes
  active = {},    -- refs to barframes currently collecting information (matches talent spec)
  shown = {},     -- refs to barframes currently visible to the player (matches stance)
  mouseover = {}, -- refs to barframes requiring mouseover target information
}

local defaultconfig = {
  showTrinketBars = {
    default = true,
    boolean = true,
    name = 'Show Trinket Bars',
    desc = 'When enabled, displays trinkets in addition to spells and abilities.',
  },
  castLine = {
    default = true,
    boolean = true,
    number = true,
    name = 'End-of-Cast Line',
    desc = 'When enabled, adds a vertical line which marks the end of any spellcast in progress.',
  },
  gcdStyle = {
    default = 'line',
    valid = { 'line', 'bar', false },
    name = 'Global Cooldown Style',
    desc =
    'When set to Line, a vertical line will mark the end of the current GCD. \n When set to Bar, a textured bar is used instead. \n Can also be disabled to neither track or display the GCD.',
  },

  enableRedshift = {
    default = false,
    boolean = true,
    name = 'Enable Redshift',
    desc = 'An optional module which hides Axis untless certain conditions, such as combat or targeting, are met.',
  },
  Redshift = {
    name = 'Redshift States',
    desc = 'Conditions for the Redshift Module to show Axis.',
    sub = {
      showCombat = {
        default = true,
        boolean = true,
        name = 'Show in Combat',
        desc = 'When enabled, displays Axis when in combat.',
      },
      showHarm = {
        default = true,
        boolean = true,
        name = 'Show Harmful Units',
        desc = 'When enabled, displays Axis when an attackable unit is targeted.',
      },
      showHelp = {
        default = false,
        boolean = true,
        name = 'Show Helpful Units',
        desc = 'When enabled, displays Axis when a friendly unit is targeted.',
      },
      showBoss = {
        default = true,
        boolean = true,
        name = 'Show on Boss',
        desc = 'When enabled, displays Axis when a boss-level unit is targeted.',
      },
      showFocus = {
        default = false,
        boolean = true,
        name = 'Show on Focus',
        desc = 'When enabled, displays Axis when you have a focus target.'
      },
      hideVehicle = {
        default = true,
        boolean = true,
        name = 'Hide in Vehicle',
        desc = 'When enabled, HIDES Axis when using a vehicle with its own actionbar.',
      },
      hideVitals = {
        default = true,
        boolean = true,
        name = 'Hide Vitals',
        desc = 'When enabled, the Vitals display is hidden whenever Axis is hidden.',
      },
    },
  },
  Lines = {
    default = false,
    boolean = true,
    table = true,
    name = 'Static Lines',
    desc = 'When enabled, enables the Lines Module.',
  },
  LinesColor = {
    default = { 1, 1, 1, 0.5 },
    table = true,
    name = 'Static Line Colors',
    desc = 'The color of any static lines being displayed by the Lines Axis Module.'
  },

  anchor = {
    default = { "TOPRIGHT", "EventHorizonHandle", "BOTTOMRIGHT" },
    table = true,
    name = 'Anchor Position',
    desc = "Axis' Handle Information",
  },
  width = {
    default = 150,
    number = true,
    name = 'Bar Width',
    desc = 'Set the width of shown bars. Icons add to the actual width of the window.'
  },
  height = {
    default = 18,
    number = true,
    name = 'Bar Height',
    desc = 'Set the height of each individual bar. Also sets the width of icons.',
  },
  spacing = {
    default = 0,
    number = true,
    name = 'Bar Spacing',
    desc = 'Set the spacing between each shown bar.',
  },
  staticheight = {
    default = false,
    number = true,
    boolean = true,
    name = 'Static Height',
    desc =
    'When set, Axis will resize its bars to fit this height. \n When disabled, Axis will grow or shrink depending on the number of shown bars.'
  },
  hideIcons = {
    default = false,
    boolean = true,
    name = 'Hide Bar Icons',
    desc = 'When enabled, Icons are not shown, however stack-text is still shown.',
  },

  past = {
    default = -3,
    number = true,
    name = 'Past Time',
    desc = 'How many seconds in the past for Axis to display.',
  },
  future = {
    default = 12,
    number = true,
    name = 'Future Time',
    desc = 'How many seconds in the future for Axis to display.'
  },

  texturedbars = {
    default = true,
    boolean = true,
    name = 'Textured Bars',
    desc =
    'When enabled, Axis displays textured bars according to the Bar Texture option. \n When disabled, Axis displays the bars as a solid color.',
  },

  bartexture = {
    default = "Interface\\Addons\\EventHorizon\\Smooth",
    string = true,
    name = 'Bar Texture',
    desc = 'Set the texture to use for each bar.',
  },
  texturealphamultiplier = {
    default = 2,
    number = true,
    name = 'Texture Alpha-Multiplier',
    desc = 'This option directly influences the opacity of textured bars to account for varying degrees of visibility.'
  },

  backdrop = {
    default = true,
    boolean = true,
    name = 'Show Backdrop',
    desc = 'When enabled, Axis displays the backdrop.',
  },
  padding = {
    default = 3,
    number = true,
    name = 'Backdrop Padding',
    desc = 'Set the padding between the backdrop and bar edges.'
  },
  bg = {
    default = "Interface\\ChatFrame\\ChatFrameBackground",
    string = true,
    name = 'Backdrop Texture',
    desc = 'Set the texture to use for the backdrop.',
  },
  border = {
    default = "Interface\\Tooltips\\UI-Tooltip-Border",
    string = true,
    name = 'Backdrop Border Texture',
    desc = 'Set the texture to use for the backdrop border.',
  },
  edgesize = {
    default = 8,
    number = true,
    name = 'Backdrop Edge Size',
    desc = 'Set the thickness of the backdrop border.',
  },
  inset = {
    default = { top = 2, bottom = 2, left = 2, right = 2 },
    table = true,
    name = 'Backdrop Insets',
    desc = 'Trim the backdrop texture to account for its border.',
  },

  stackFont = {
    default = false,
    boolean = true,
    string = true,
    name = 'Stack Text Font',
    desc = 'Sets the font of the stack text shown on bar icons.',
  },
  stackFontSize = {
    default = false,
    boolean = true,
    number = true,
    name = 'Stack Text Size',
    desc = 'Set the size of the stack text shown on bar icons.',
  },
  stackFontOutline = {
    default = false,
    valid = { 'OUTLINE', 'THICKOUTLINE', 'MONOCHROME', false },
    name = 'Stack Text Outline',
    desc = 'Set the outline of the stack text shown on bar icons.',
  },
  stackFontColor = {
    default = false,
    table = true,
    name = 'Stack Text Color',
    desc = 'Sets the color of the stack text shown on bar icons.',
  },
  stackFontShadow = {
    default = false,
    table = true,
    boolean = true,
    name = 'Stack Text Shadow',
    desc =
    'Apply a shadow effect to the stack text shown on bar icons. \n This option adjusts the shadow color and can be left at default for black.',
  },
  stackFontShadowOffset = {
    default = false,
    table = true,
    boolean = true,
    name = 'Stack Text Shadow Offset',
    desc = 'Set the offset of the stack text shadow.',
  },
  stackOnRight = {
    default = false,
    boolean = true,
    name = 'Stack Text on Right',
    desc =
    'When enabled the stack text is displayed on the right-hand side of the bars. \n When disabled, stack text is shown on the left side, as default.',
  },
}

local defaultcolors = {
  sent = { true, class == 'PRIEST' and 0.7 or 1, 1 },
  tick = { true, class == 'PRIEST' and 0.7 or 1, 1 },
  casting = { 0, 1, 0.2, 0.25 },
  castLine = { 0, 1, 0.2, 0.3 },
  cooldown = { 0.6, 0.8, 1, 0.3 },
  debuffmine = { true, class == 'PRIEST' and 0.7 or 1, 0.3 },
  debuff = { true, 0.5, 0.3 },
  playerbuff = { true, class == 'PRIEST' and 0.7 or 1, 0.3 },
  nowLine = { 1, 1, 1, 0.3 },
  bgcolor = { 0, 0, 0, 0.6 },
  bordercolor = { 1, 1, 1, 1 },
  gcdColor = { 1, 1, 1, 0.5 },
  timerAfterCast = { true, class == 'PRIEST' and 0.7 or 1, 0.3 },
}

local defaultlayouts = {
  tick = {
    top = 0,
    bottom = 0.2,
  },
  smalldebuff = {
    top = 0.2,
    bottom = 0.35,
  },
  cantcast = {
    top = 0.35,
    bottom = 1,
  },
  default = {
    top = 0.2,
    bottom = 1,
  },
}

local config = { Redshift = {}, blendModes = {} }
local layouts = {}
local colors = {}

local otherIDs = {} -- combatlog events either not directly tied to bars, or using spells other than bar.spellID
local modules = {}  -- storage for loaded modules - format = module = modules[string.lower(moduleName)] = {namespace}

local vars = {      -- storage for widely used vars/math/etc - format = vars[var] = val
  config = {},
  onepixelwide = 1,
  visibleFrame = true,
  numframes = 0,
  buff = {},
  debuff = {},
}

local drawOrder = {
  default = -8,
  cooldown = -7,
  debuff = -6,
  playerbuff = -5,
  debuffmine = -4,
  casting = -3,
  sent = -2,
  tick = -1,
  channeltick = 0,
  now = 1,
  gcd = 2,
  timerAfterCast = 3,
  nowI = 7,
}

local SpellFrame = {}

local EventHorizonFrame = CreateFrame('Frame', 'EventHorizonFrame', UIParent)
local mainFrame = CreateFrame('Frame', nil, EventHorizonFrame)
local frame = CreateFrame('Frame')
local frame2 = CreateFrame('Frame')
local frame3 = CreateFrame('Frame')

local auraids = {
  tick = true,
  cantcast = true,
  debuff = true,
  playerbuff = true,
  debuffmine = true,
}

local exemptColors = {
  default = true,
  sent = true,
  tick = true,
  channeltick = true,
  castLine = true,
  nowLine = true,
  bgcolor = true,
  bordercolor = true,
  gcdColor = true,
}

local equipSlots = {
  ["ChestSlot"] = 5,
  ["FeetSlot"] = 8,
  ["Finger0Slot"] = 11,
  ["Finger1Slot"] = 12,
  ["HandsSlot"] = 10,
  ["HeadSlot"] = 1,
  ["LegsSlot"] = 7,
  ["MainHandSlot"] = 16,
  ["NeckSlot"] = 2,
  ["SecondaryHandSlot"] = 17,
  ["ShirtSlot"] = 4,
  ["ShoulderSlot"] = 3,
  ["TabardSlot"] = 19,
  ["Trinket0Slot"] = 13,
  ["Trinket1Slot"] = 14,
  ["WaistSlot"] = 6,
  ["WristSlot"] = 9,
}

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

local function debug(...)
  if DEBUG then
    print("EHZ DEBUG | ", ...)
  end
end

local function appendTable(dest, src)
  for k, v in pairs(src) do
    dest[k] = v
  end
  return dest
end

local function export(exports)
  appendTable(EHZ, exports)
end

local Clone = function(t)
  local new = {}
  local i, v = next(t, nil) -- i is an index of t, v = t[i]
  while i do
    new[i] = v
    i, v = next(t, i)
  end
  return new
end

print("EventHorizon started!")

-- My goal is to make inter-module dependencies explicit.
-- This is cumbersome and SHOULD be, because it indicates
-- that Init module does too much and needs to be split up or refactored
export({
  DEBUG = DEBUG,
  spellIDsEnabled = spellIDsEnabled,
  class = class,
  playerName = playerName,
  defaultDB = defaultDB,
  defaultDBG = defaultDBG,
  db = db,
  frames = frames,
  defaultconfig = defaultconfig,
  defaultcolors = defaultcolors,
  defaultlayouts = defaultlayouts,
  config = config,
  layouts = layouts,
  colors = colors,
  otherIDs = otherIDs,
  modules = modules,
  vars = vars,
  drawOrder = drawOrder,
  SpellFrame = SpellFrame,
  EventHorizonFrame = EventHorizonFrame,
  mainFrame = mainFrame,
  frame = frame,
  frame2 = frame2,
  frame3 = frame3,
  auraids = auraids,
  exemptColors = exemptColors,
  equipSlots = equipSlots,
  mainFrameEvents = mainFrameEvents,
  reloadEvents = reloadEvents,
  tickevents = tickevents,
  debug = debug,
  appendTable = appendTable,
  export = export,
  Clone = Clone,
})

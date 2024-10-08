local _, EHZ = ...

-- TODO: Remove after refactoring
EventHorizon = EHZ
local ns = EHZ

-- Imports
local debug = EHZ.debug
local spellIDsEnabled = EHZ.spellIDsEnabled
local class = EHZ.class
local playerName = EHZ.playerMame
local vars = EHZ.vars
local drawOrder = EHZ.drawOrder

local SpellFrame = EHZ.Frames.SpellFrame
local EventHorizonFrame = EHZ.Frames.EventHorizonFrame
local MainFrame = EHZ.Frames.MainFrame
local frame = EHZ.Frames.frame
local frame2 = EHZ.Frames.frame2
local frame3 = EHZ.Frames.frame3
local auraids = EHZ.auraids
local exemptColors = EHZ.exemptColors
local getSlotName = EHZ.getSlotName

local mainFrameEvents = EHZ.mainFrameEvents
local reloadEvents = EHZ.reloadEvents
local tickevents = EHZ.tickevents
local EventHandler = EHZ.Events.EventHandler

local UnitDebuff = C_UnitAuras.GetBuffDataByIndex
local UnitBuff = C_UnitAuras.GetDebuffDataByIndex
--

-- Frames to be created on demand
local handle

local mainFrame_PLAYER_TOTEM_UPDATE = function(self, slot)
    for i, spellframe in pairs(ns.frames.frames) do
        if spellframe.totem then
            spellframe:PLAYER_TOTEM_UPDATE(slot)
            -- Totem Mastery doesn't populate immediately, so we delay.
            C_Timer.After(0.1, function() spellframe:PLAYER_TOTEM_UPDATE(slot) end)
        end
    end
end

local mainFrame_UNIT_AURA = function(self, unit)
    if vars.buff[unit] then
        table.wipe(vars.buff[unit])
        for i = 1, 50 do
            local name, icon, count, _, duration, expirationTime, source, _, _, spellID = UnitBuff(unit, i)
            --print(name,icon,count,duration,expirationTime,source,spellID)
            if not (name and spellID) then break end
            table.insert(vars.buff[unit], {
                name = name,
                icon = icon,
                count = count,
                duration = duration,
                expirationTime = expirationTime,
                source = source,
                spellID = spellID,
            })
        end
    end
    if vars.debuff[unit] then
        table.wipe(vars.debuff[unit])
        for i = 1, 100 do
            local name, icon, count, _, duration, expirationTime, source, _, _, spellID = UnitDebuff(unit, i)
            if not (name and spellID) then break end
            table.insert(vars.debuff[unit], {
                name = name,
                icon = icon,
                count = count,
                duration = duration,
                expirationTime = expirationTime,
                source = source,
                spellID = spellID,
            })
        end
    end
    for i, spellframe in pairs(ns.frames.frames) do
        if (spellframe.auraunit and spellframe.auraunit == unit) then
            spellframe:UNIT_AURA(unit)
        end
    end
end

local GetAura = function(self)
    local s = self.isType == 'playerbuff' and 'buff' or 'debuff'
    local a = vars[s][self.auraunit]
    if not a then return end
    if type(self.auraname) == 'table' then
        for k, aura in pairs(a) do
            for i = 1, #self.auraname do
                if (aura.name == self.auraname[i]) and (aura.source == 'player' or self.unique) and (not (self.uniqueID) or self.uniqueID == aura.spellID) then
                    if aura.expirationTime == 0 and aura.duration == 0 then
                        aura.duration = 86400 -- Pretend it's actually gonna last a full day. Probably long enough
                        aura.expirationTime = GetTime() + aura.duration
                    end
                    return aura.name, aura.icon, aura.count, aura.duration, aura.expirationTime, aura.source,
                        aura.spellID
                end
            end
        end
    else
        for k, aura in pairs(a) do
            if (aura.name == self.auraname) and (aura.source == 'player' or self.unique) and (not (self.uniqueID) or self.uniqueID == aura.spellID) then
                if aura.expirationTime == 0 and aura.duration == 0 then
                    aura.duration = 86400 -- Pretend it's actually gonna last a full day. Probably long enough
                    aura.expirationTime = GetTime() + aura.duration
                end
                return aura.name, aura.icon, aura.count, aura.duration, aura.expirationTime, aura.source, aura.spellID
            end
        end
    end
end

ns.GetAura = function(self, auralist, auratype, unit)
    if not auratype and unit then return error('Invalid arg in EventHorizon:GetAura(self,auralist,auratype,unit)') end
    local a = vars[auratype][unit]
    if not a then return end
    if type(auralist) == 'table' then
        for k, aura in pairs(a) do
            for i = 1, #auralist do
                local t = type(auralist[i])
                if (t == 'string' and aura.name or t == 'number' and aura.spellID) == auralist[i] then
                    if aura.expirationTime == 0 and aura.duration == 0 then
                        aura.duration = 86400 -- Pretend it's actually gonna last a full day. Probably long enough
                        aura.expirationTime = GetTime() + aura.duration
                    end
                    return aura.name, aura.icon, aura.count, aura.duration, aura.expirationTime, aura.source,
                        aura.spellID
                end
            end
        end
    else
        for k, aura in pairs(a) do
            local t = type(auralist)
            if (t == 'string' and aura.name or t == 'number' and aura.spellID) == auralist then
                if aura.expirationTime == 0 and aura.duration == 0 then
                    aura.duration = 86400 -- Pretend it's actually gonna last a full day. Probably long enough
                    aura.expirationTime = GetTime() + aura.duration
                end
                return aura.name, aura.icon, aura.count, aura.duration, aura.expirationTime, aura.source, aura.spellID
            end
        end
    end
end

-- SpellFrame - All spell bar frames inherit from this class.

--Indicators represent a point or range of time. There are different types. The type determines the color and position.
local typeparent = {}

local SpellFrame_SetStacks = function(self, count)
    if type(count) == "number" and (count > 0) then
        self.stacks:SetFormattedText('%d', count)
    else
        self.stacks:SetText()
    end
end

local SpellFrame_NotInteresting = function(self, unitid, spellname)
    return unitid ~= 'player' or spellname ~= self.spellname
end

-- FindItemInfo:
local SpellFrame_FindItemInfo = function(self, slotID)
    local itemID = self.itemID or GetInventoryItemID('player', slotID or self.slotID)
    if itemID then
        local dbI = EventHorizonDBG.itemInfo[itemID]
        if dbI and (dbI.name and dbI.tex) then
            return itemID, dbI.name, dbI.tex
        else
            local name, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemID)
            if (name and tex) then
                EventHorizonDBG.itemInfo[itemID] = { name = name, tex = tex }
                return itemID, name, tex
            end
        end
    end
end

local SpellFrame_AddIndicator = function(self, typeid, layoutid, time, usetexture, top, bottom)
    local indicator
    local parent = typeparent[typeid]

    if not parent then
        parent = {}
        parent.unused = {}
        typeparent[typeid] = parent
        --if DEBUG and typeid=='tick'  then parent.numchildren=0 end--]]
    end

    if #parent.unused > 0 then
        indicator = tremove(parent.unused)
        indicator:ClearAllPoints()
        indicator.start = nil
        indicator.stop = nil
        indicator.happened = nil
        -- if DEBUG and typeid=='tick'  then debug('reusing indicator',indicator.frameindex) end--]]
    else
        indicator = MainFrame:CreateTexture(nil, 'ARTWORK', nil, draworder[typeid])
        indicator.parent = parent
        -- if DEBUG and typeid=='tick' then parent.numchildren=parent.numchildren+1 indicator.frameindex=parent.numchildren debug('adding indicator',indicator.frameindex) end--]]
    end

    indicator:Hide()
    indicator:SetWidth(vars.onepixelwide)

    indicator.typeid = typeid
    indicator.layoutid = layoutid
    indicator.time = time
    indicator.usetexture = usetexture
    indicator.top = top
    indicator.bottom = bottom

    self:StyleIndicator(indicator)

    tinsert(self.indicators, indicator)
    debug("SpellFrame_AddIndicator", indicator, self.indicators[#self.indicators])
    return indicator
end

local SpellFrame_StyleIndicator = function(self, indicator)
    local parent = typeparent[indicator.typeid]
    local custom_bar_texture

    if self.bartexture and (indicator.usetexture or not exemptColors[indicator.typeid]) then
        custom_bar_texture = self.bartexture
    end

    -- Layout
    local layouts = ns.layouts
    local layout = layouts[indicator.layoutid] or layouts.default
    local color = ns:getColor(self, indicator.typeid) or ns.colors.default

    local topOffset, bottomOffset = -layout.top * vars.barheight, -layout.bottom * vars.barheight
    local parentFrame = self

    if layoutid == 'frameline' then -- frameline layout is fullheight of the mainFrame
        color = indicator.typeid == 'sent' and ns:getColor(self, 'castLine') or ns:getColor(self, indicator.typeid)
        topOffset = 0
        bottomOffset = 0
        parentFrame = ns.mainFrame
    elseif indicator.top and indicator.bottom then -- custom top/bottom
        topOffset = -indicator.top * vars.barheight
        bottomOffset = -indicator.bottom * vars.barheight
    end

    indicator:SetPoint('TOP', parentFrame, 'TOP', 0, topOffset)
    indicator:SetPoint('BOTTOM', parentFrame, 'TOP', 0, bottomOffset)

    if indicator.usetexture then
        indicator:SetTexture(custom_bar_texture or vars.bartexture)
        indicator:SetTexCoord(unpack(layout.texcoords))
    else
        indicator:SetColorTexture(1, 1, 1, 1)
    end

    indicator:SetVertexColor(unpack(color))

    if ns.config.blendModes[indicator.typeid] and type(ns.config.blendModes[indicator.typeid]) == 'string' then
        indicator:SetBlendMode(ns.config.blendModes[indicator.typeid])
    end
end

local SpellFrame_AddSegment = function(self, typeid, layoutid, start, stop, start2, top, bottom)
    if stop < start then return end
    local indicator = self:AddIndicator(typeid, layoutid, start, vars.texturedbars, top, bottom)
    indicator.time = nil
    indicator.start = start
    indicator.stop = stop
    -- debug("SpellFrame_AddSegment", indicator, indicator.start, indicator.stop, indicator.time)
    return indicator
end

local SpellFrame_Remove = function(self, indicator)
    -- debug("SpellFrame_Remove", indicator)
    if type(indicator) == 'number' then
        local index, indicator = indicator, self.indicators[indicator]
        indicator:Hide()
        --if DEBUG and indicator.typeid=='tick' then debug('deleting',indicator.frameindex) end--]]
        tinsert(indicator.parent.unused, tremove(self.indicators, index))
    else
        for index = 1, #self.indicators do
            if self.indicators[index] == indicator then
                indicator:Hide()
                --if DEBUG and indicator.typeid=='tick' then debug('deleting',indicator.frameindex) end--]]
                tinsert(indicator.parent.unused, tremove(self.indicators, index))
                break
            end
        end
    end
end

local SpellFrame_OnUpdate = function(self, elapsed)
    local now = GetTime()
    local diff = now + vars.past

    -- spellframe.nexttick is used to schedule the creation of predicted ticks as soon as they scroll past now+future.
    local nexttick = self.nexttick
    if nexttick and nexttick <= now + vars.future then
        if nexttick <= self.lasttick then
            self:AddIndicator('tick', 'tick', nexttick)
            self.latesttick = nexttick
            self.nexttick = nexttick + (self.dotMod or self.dot)
        else
            self.nexttick = nil
        end
    end
    for k = #self.indicators, 1, -1 do
        local indicator = self.indicators[k]
        local time = indicator.time
        if time then
            -- Example:
            -- [-------|------->--------]
            -- past    now     time     future
            -- now=795, time=800, past=-3, then time is time-now-past after past.
            local p = (time - diff) * vars.scale
            local remove = p < 0 or (time <= now and indicator.typeid == 'tick' and not indicator.happened)
            if remove then
                -- debug("OnUpdate - remove", indicator, indicator.time, indicator.start, indicator.stop)
                indicator:Hide()
                --if DEBUG and indicator.typeid=='tick' then debug('deleting',indicator.frameindex) end--]]
                tinsert(indicator.parent.unused, tremove(self.indicators, k))
            elseif p <= 1 then
                -- debug("OnUpdate - p<=1", indicator, indicator.time, indicator.start, indicator.stop)
                indicator:SetPoint('LEFT', self, 'LEFT', p * vars.barwidth, 0)
                indicator:Show()
            end
        else
            local start, stop = indicator.start, indicator.stop
            local p1 = (start - diff) * vars.scale
            local p2 = (stop - diff) * vars.scale
            if p2 < 0 then
                -- debug("OnUpdate - p2<0")
                indicator:Hide()
                --if DEBUG and indicator.typeid=='tick' then debug('deleting',indicator.frameindex) end--]]
                tinsert(indicator.parent.unused, tremove(self.indicators, k))
            elseif 1 < p1 then
                -- debug("OnUpdate - p1>1")
                indicator:Hide()
            else
                indicator:Show()
                indicator:SetPoint('LEFT', self, 'LEFT', 0 <= p1 and p1 * vars.barwidth or 0, 0)
                indicator:SetPoint('RIGHT', self, 'LEFT', p2 <= 1 and p2 * vars.barwidth + 1 or vars.barwidth, 0)
            end
        end
    end
end

local SpellFrame_UNIT_SPELLCAST_SENT = function(self, unitid, target, castGuid, spellID)
    local spellname = GetSpellInfo(spellID)
    if ((self.cast and not (self.cast[spellname])) or (spellname ~= self.spellname)) or unitid ~= 'player' then return end
    local now = GetTime()
    self:AddIndicator('sent', 'default', now)
end

local Cast_Start = function(self, unitid, castGUID, spellID)
    local name, _, icon = GetSpellInfo(spellID)
    local unitid, spellname, spellrank = unitid, name, -1
    if not (self.cast[spellname]) or unitid ~= 'player' then return end
    local _, _, _, startTime, endTime, _ = self.cast[spellname].func(unitid)
    if not (startTime and endTime) then return end

    startTime, endTime = startTime / 1000, endTime / 1000
    self.casting = self:AddSegment('casting', 'default', startTime, endTime)

    self.lastcast = name
    if not (self.keepIcon) then
        self.icon:SetTexture(icon)
    end

    if vars.castLine and (endTime - startTime > vars.castLine) then
        self.castLine = self:AddIndicator('sent', 'frameline', endTime)
    end

    local numhits = self.cast[spellname].numhits and self.cast[spellname].numhits ~= true and
        self.cast[spellname].numhits
    if numhits then
        local casttime = endTime - startTime
        local tick = casttime / numhits
        if numhits and numhits ~= true then
            for i = 1, numhits do
                self:AddIndicator('channeltick', 'channeltick', startTime + i * tick)
            end
        end
    end
end

local Cast_Update = function(self, unitid, castGUID, spellID)
    --debug('UNIT_SPELLCAST_CHANNEL_UPDATE',unitid, spellname, spellrank)
    local name, _, icon = GetSpellInfo(spellID)
    local unitid, spellname, spellrank = unitid, name, -1
    if not (self.cast[spellname]) or unitid ~= 'player' then return end
    local _, _, _, startTime, endTime, _ = self.cast[spellname].func(unitid)
    if not (startTime and endTime) then return end
    startTime, endTime = startTime / 1000, endTime / 1000
    if self.casting then
        self.casting.stop = endTime
        if vars.castLine and self.castLine then
            self.castLine.time = endTime
        end
    end
    self:RemoveChannelTicksAfter(endTime)
end

local Cast_Stop = function(self, unitid, castGUID, spellID)
    local name, _, icon = GetSpellInfo(spellID)
    local unitid, spellname, spellrank = unitid, name, -1

    if not (self.cast[spellname]) or unitid ~= 'player' then return end
    local now = GetTime()
    if self.casting then
        self.casting.stop = now
        if vars.castLine and self.castLine then
            self.castLine.time = now
        end
        self.casting = nil
    end
    self:RemoveChannelTicksAfter(now)
end

local SpellFrame_PLAYER_TOTEM_UPDATE = function(self, slot)
    if not (self.totem) then return end
    local tUp, tName, tStart, tDuration, tIcon = GetTotemInfo(slot)
    if not tUp or tName ~= GetSpellInfo(self.totem) then return end

    local now = GetTime()

    local name, icon, count, duration, expirationTime, source, spellID = tName, tIcon, 1, tDuration, tStart + tDuration,
        "player", tID
    local addnew

    if name then
        start = now

        if icon and not (self.cast or self.slotID or self.keepIcon) then self.icon:SetTexture(icon) end

        if self.aurasegment and (self.aurasegment.lastunit == "player") then
            -- The aura is currently displayed
            if expirationTime ~= self.aurasegment.stop then
                if self.alwaysrefresh and not self.cast then -- alwaysrefresh = buff. Cast + buff - HoT = BAD. Buffs with cast time and no HoT component are treated much differently.
                    if self.dot then                         -- ...check to see if it's a HoT. If so, it's treated as a DoT.
                        self.aurasegment.stop = start - 0.2
                        if self.cast and self.useSmalldebuff then
                            self.cantcast.stop = start - 0.2
                        end
                        self:RemoveTicksAfter(start)
                        addnew = true
                    else
                        -- If it's a buff with no cast time or HoT component, no special handling needed, move along.
                        self.aurasegment.stop = expirationTime
                    end
                else
                    -- The aura was replaced.
                    self.aurasegment.stop = start - 0.2
                    if self.cast and self.useSmalldebuff then
                        self.cantcast.stop = start - 0.2
                    end
                    self:RemoveTicksAfter(start)
                    addnew = true
                end
                if self.internalcooldown and type(self.internalcooldown) == 'number' then
                    local stop = now + self.internalcooldown
                    if start > stop then
                        start = now
                    end
                    self:AddSegment('cooldown', 'cooldown', start, stop)
                end
            end
        else
            addnew = true
            if self.internalcooldown and type(self.internalcooldown) == 'number' then
                local stop = now + self.internalcooldown
                if start > stop then
                    start = now
                end
                self:AddSegment('cooldown', 'cooldown', start, stop)
            end
        end
        self:SetStacks(1)
    else
        if self.aurasegment then
            if math.abs(self.aurasegment.stop - now) > 0.3 then
                self.aurasegment.stop = now
                if self.cast and self.useSmalldebuff then
                    self.cantcast.stop = now - 0.2
                end
            end
            self:RemoveTicksAfter(now)
            self.aurasegment = nil
            self:SetStacks()
        end
    end
    self:UpdateTotem(addnew, source, now, start, expirationTime, duration, name)
end

local SpellFrame_UNIT_AURA = function(self, unitid)
    if unitid ~= self.auraunit then return end
    if not (self.spellname and self.auraname) then return end

    local name, icon, count, duration, expirationTime, source, spellID = GetAura(self, unitid)
    --print(name, icon, count, duration, expirationTime, source, spellID)
    local afflicted = name and (self.unique or source == 'player') and (not self.minstacks or count >= self.minstacks)
    local addnew
    local now = GetTime()
    local start
    local targ = UnitName(self.auraunit)

    if self.uniqueID and self.uniqueID ~= spellID then
        return
    end

    --[[
  if self.aurasegment and expirationTime == 0 and duration == 0 then  -- Timeless aura, bar exists (Overkill)
    for i = #self.indicators,1,-1 do
      self:Remove(i)
    end
    self.aurasegment = nil
    self.nexttick = nil
    self.stacks:SetText()
    return
  end

  if expirationTime == 0 then
    return
  end
  ]]

    if afflicted then
        start = expirationTime - duration
        if icon and not (self.cast or self.slotID or self.keepIcon) then self.icon:SetTexture(icon) end
        if self.aurasegment and (self.aurasegment.lastunit == targ) then
            -- The aura is currently displayed
            if expirationTime ~= self.aurasegment.stop then
                if self.alwaysrefresh and not self.cast then -- alwaysrefresh = buff. Cast + buff - HoT = BAD. Buffs with cast time and no HoT component are treated much differently.
                    if self.dot then                         -- ...check to see if it's a HoT. If so, it's treated as a DoT.
                        self.aurasegment.stop = start - 0.2
                        if self.cast and self.useSmalldebuff then
                            self.cantcast.stop = start - 0.2
                        end
                        self:RemoveTicksAfter(start)
                        addnew = true
                    else
                        -- If it's a buff with no cast time or HoT component, no special handling needed, move along.
                        self.aurasegment.stop = expirationTime
                    end
                else
                    -- The aura was replaced.
                    self.aurasegment.stop = start - 0.2
                    if self.cast and self.useSmalldebuff then
                        self.cantcast.stop = start - 0.2
                    end
                    self:RemoveTicksAfter(start)
                    addnew = true
                end
                if self.internalcooldown and type(self.internalcooldown) == 'number' then
                    local stop = now + self.internalcooldown
                    if start > stop then
                        start = now
                    end
                    self:AddSegment('cooldown', 'cooldown', start, stop)
                end
            end
        else
            addnew = true
            if self.internalcooldown and type(self.internalcooldown) == 'number' then
                local stop = now + self.internalcooldown
                if start > stop then
                    start = now
                end
                self:AddSegment('cooldown', 'cooldown', start, stop)
            end
        end
        self:SetStacks(count)
    else
        if self.aurasegment then
            if math.abs(self.aurasegment.stop - now) > 0.3 then
                self.aurasegment.stop = now
                if self.cast and self.useSmalldebuff then
                    self.cantcast.stop = now - 0.2
                end
            end
            self:RemoveTicksAfter(now)
            self.aurasegment = nil
            self:SetStacks()
        end
    end
    self:UpdateDoT(addnew, source, now, start, expirationTime, duration, name)
end

local mainFrame_PLAYER_TARGET_CHANGED = function(self)
    local exists = UnitExists('target')
    local dead
    if exists then
        dead = UnitIsDead('target')
    end
    for i, spellframe in pairs(ns.frames.frames) do
        if spellframe.auraunit == 'target' then
            if spellframe.aurasegment then
                for i = #spellframe.indicators, 1, -1 do
                    local ind = spellframe.indicators[i]
                    if auraids[ind.typeid] then
                        spellframe:Remove(i)
                    end
                end
                spellframe.aurasegment = nil
                spellframe.targetdebuff = nil
                spellframe.nexttick = nil
                spellframe.recenttick = nil
                spellframe:SetStacks()
            end

            if spellframe.refreshable then
                if exists then
                    if dead then
                        spellframe.debuffs[UnitGUID('target')] = nil
                    else
                        spellframe.targetdebuff = spellframe.debuffs[UnitGUID('target')]
                    end
                end
            end
        end
    end

    if UnitExists('target') then
        self:UNIT_AURA('target')
    end
end

local SpellFrame_RemoveTicksAfter = function(self, min)
    local indicators = self.indicators
    for i = #indicators, 1, -1 do
        local ind = indicators[i]
        if (ind.typeid == 'tick') and ind.time > min then
            self:Remove(i)
        end
    end
    --print('removing ticks after',min)
    self.nexttick = nil
end

local SpellFrame_RemoveChannelTicksAfter = function(self, min)
    local indicators = self.indicators
    for i = #indicators, 1, -1 do
        local ind = indicators[i]
        if ind.typeid == 'channeltick' and ind.time > min then
            self:Remove(i)
        end
    end
    self.nextchanneltick = nil
end

local mainFrame_CLEU_OtherInterestingSpell = function(self, time, event, hideCaster, srcguid, srcname, srcflags, destguid,
                                                      destname, destflags, spellid, spellname)
    local now = GetTime()

    if ns.otherIDs[spellname] then
        local id = ns.otherIDs[spellname]
        local bf = ns.frames.frames
        if event == 'SPELL_DAMAGE' and id.isChannel then
            for i in pairs(bf) do
                if bf[i].cast and bf[i].cast[spellname] then
                    local tick = bf[i]:AddIndicator('tick', 'tick', now)
                    tick.happened = true
                    break
                end
            end
        elseif event == 'SPELL_CAST_SUCCESS' and id.isTimer then
            for i in pairs(bf) do
                local showTimer = false
                local timerAfterCast = bf[i].timerAfterCast
                if timerAfterCast then
                    if type(timerAfterCast[1]) == "number" and timerAfterCast[1] == spellid then
                        showTimer = true
                    elseif type(timerAfterCast[1]) == "table" then
                        for _, value in pairs(timerAfterCast[1]) do
                            if value == spellid then
                                showTimer = true
                                break
                            end
                        end
                    end
                    if showTimer then
                        local now = GetTime()
                        if bf[i].timersegment and bf[i].timersegment.stop > now then
                            bf[i].timersegment.stop = now + timerAfterCast[2]
                        else
                            bf[i].timersegment = bf[i]:AddSegment('timerAfterCast', 'timerAfterCast', now,
                                now + timerAfterCast[2])
                        end
                        break
                    end
                end
            end
        end
    end
end

local AddTicks = {}
AddTicks.stop = function(self, now, fresh)
    local nexttick = self.start
    while nexttick <= self.stop + 0.1 do
        if now + vars.future < nexttick then
            self.nexttick = nexttick
            self.lasttick = self.stop
            break
        end
        if now + vars.past <= nexttick then
            self:AddIndicator('tick', 'tick', nexttick)
            self.latesttick = nexttick
        end
        nexttick = nexttick + (self.dotMod or self.dot)
    end
end

AddTicks.start = function(self, now)
    local nexttick = now + (self.dotMod or self.dot)
    while nexttick <= (self.stop + 0.2) do
        if now + vars.future < nexttick then
            -- The next tick is not visible yet.
            self.nexttick = nexttick
            self.lasttick = self.stop
            break
        end
        if now + vars.past <= nexttick then
            local tick = self:AddIndicator('tick', 'tick', nexttick)
            self.latesttick = nexttick
        end
        nexttick = nexttick + (self.dotMod or self.dot)
    end
end

local SpellFrame_COMBAT_LOG_EVENT_UNFILTERED = function(...)
    local self, timestamp, event, hideCaster, srcguid, srcname, srcflags, destguid, destname, destflags, spellid, spellname = ...
    local now = GetTime()

    if event == 'SPELL_CAST_SUCCESS' then
        --debug('SPELL_CAST_SUCCESS',destguid)
        self.castsuccess[destguid] = now
    elseif tickevents[event] then
        local isInvalid = not (self.dot) and
            (self.cast and self.cast[spellname] and not (self.cast[spellname].numhits)) -- filter out cast+channel bars
        if isInvalid then return end
        if UnitGUID(self.auraunit or 'target') == destguid then
            local tick = self:AddIndicator('tick', 'tick', now)
            tick.happened = true
            if (self.dot and (self.stop and self.stop ~= nil)) then
                if self.isHasted and self.ticks then
                    self.dotMod = self.ticks.last and (now - self.ticks.last) or self.dot
                    self.dotMod = self.dotMod > self.dot and self.dot or self.dotMod
                    self.ticks.last = now
                end
                self:RemoveTicksAfter(now) -- Reconstruct ticks from spellframe info
                local nexttick = now + (self.dotMod or self.dot)
                self.nexttick = nil
                self.recenttick = now
                while nexttick <= (self.stop + 0.2) do -- Account for lag
                    if now + vars.future < nexttick then
                        -- The next tick is not visible yet.
                        self.nexttick = nexttick
                        self.lasttick = self.stop
                        break
                    end
                    if now + vars.past <= nexttick then
                        -- The next tick is visible.
                        local tick = self:AddIndicator('tick', 'tick', nexttick)
                        if nexttick <= now then
                            tick.happened = true
                        end
                        self.latesttick = nexttick
                    end
                    nexttick = nexttick + (self.dotMod or self.dot)
                end
            end
        end
    end
end

local SpellFrame_UNIT_AURA_refreshable = function(self, unitid)
    if unitid ~= self.auraunit then return end
    if not (self.auraname and self.spellname) then return end
    local name, icon, count, duration, expirationTime, source, spellID = GetAura(self, unitid)
    local afflicted = name and (self.unique or source == 'player') and (not self.minstacks or count >= self.minstacks)
    local addnew, refresh
    local now = GetTime()
    local guid = UnitGUID(self.auraunit or 'target')
    --print(name,source,self.spellname,self.auraname)
    -- First find out if the debuff was refreshed.

    --[[ if self.aurasegment and expirationTime == 0 and duration == 0 then  -- Timeless aura, bar exists (Overkill)
    for i = #self.indicators,1,-1 do
      self:Remove(i)
    end
    self.aurasegment = nil
    self.nexttick = nil
    self.stacks:SetText()
    return
  end ]]

    --[[ if expirationTime == 0 then
    return
  end ]]

    if afflicted then
        start = expirationTime - duration
        if icon and not (self.cast or self.slotID or self.keepIcon) then self.icon:SetTexture(icon) end
        if self.targetdebuff then
            if self.targetdebuff.stop == expirationTime then
                start = self.targetdebuff.start
            else
                -- Check for refresh.
                if start < self.targetdebuff.stop then
                    local totalduration = self.targetdebuff.stop - self.targetdebuff.start
                    local lasttick = self.targetdebuff.stop - math.fmod(totalduration, self.dotMod or self.dot)
                    local success = self.castsuccess[guid]
                    local not_recast = true -- Poisons are never actually recast, so we default to true here, because success will always be nil.
                    if success then
                        not_recast = math.abs(success - start) > 0.5
                    end
                    if not_recast and start < lasttick then
                        -- The current debuff was refreshed.
                        start = self.targetdebuff.start
                        refresh = true
                    end
                end
            end
        end
        if self.aurasegment then
            if expirationTime ~= self.aurasegment.stop and not refresh then
                -- The current debuff was replaced.
                self.aurasegment.stop = start - 0.2
                self:RemoveTicksAfter(start)

                --debug('replaced')
                addnew = true
            end
        else
            addnew = true
        end
        self:SetStacks(count)
    else
        if self.aurasegment then
            if math.abs(self.aurasegment.stop - now) > 0.3 then
                -- The current debuff ended.
                self.aurasegment.stop = now
                if self.cantcast then
                    self.cantcast.stop = now
                end
            end
            self:RemoveTicksAfter(now)
            self.aurasegment = nil
            self.cantcast = nil
            self.targetdebuff = nil
            self.recenttick = nil
            self:SetStacks()
        end
    end
    self:UpdateDoT(addnew, source, now, start, expirationTime, duration, name, refresh, guid)
end

local SpellFrame_UpdateDoT = function(self, addnew, source, now, start, expirationTime, duration, name, refresh, guid)
    local addticks
    local isHasted
    local checkDoT = self.auranamePrimary or name
    local isPrimary = checkDoT == name or nil
    self.start, self.stop, self.duration = start, expirationTime, duration

    local targ = UnitName(self.auraunit)
    if addnew then
        --debug('addnew', start, expirationTime)
        local typeid = (source == 'player' and self.isType) or (source ~= 'player' and 'debuff')
        if self.cast and self.useSmalldebuff then
            self.aurasegment = self:AddSegment(typeid, 'smalldebuff', start, expirationTime)

            local hastedcasttime = select(7, GetSpellInfo(self.lastcast or self.spellname)) / 1000
            self.cantcast = self:AddSegment(typeid, 'cantcast', start, expirationTime - hastedcasttime)

            --local pandemic_duration = duration*0.3
            --self.cantcast = self:AddSegment(typeid, 'cantcast', start, expirationTime - pandemic_duration
            --self.cantcast.pandemic_duration = pandemic_duration

            self.aurasegment.lastunit = targ
        else
            self.aurasegment = self:AddSegment(typeid, 'default', start, expirationTime)
            self.aurasegment.lastunit = targ
        end
        -- Add visible ticks.
        if self.dot and isPrimary then
            addticks = start
        end
        if self.debuffs then
            -- Refreshable only.
            self.targetdebuff = { start = start, stop = expirationTime }
            self.debuffs[guid] = self.targetdebuff
        end
        self.recenttick = now
    elseif refresh then
        -- debug('refresh', start, expirationTime)
        -- Note: refresh requires afflicted and self.targetdebuff. Also, afflicted and not self.debuff implies addnew.
        -- So we can get here only if afflicted and self.debuff and self.targetdebuff.
        self.aurasegment.stop = expirationTime
        self.targetdebuff.stop = expirationTime
        if self.cantcast then
            self.cantcast.start = start
            self.cantcast.stop = expirationTime - select(7, GetSpellInfo(self.lastcast or self.spellname)) / 1000
        end
        if self.latesttick then
            addticks = self.latesttick
        end
    end
    if addticks then
        addticks = self.recenttick or addticks
        local nexttick = addticks + (self.dotMod or self.dot)
        self.nexttick = nil

        if self.hasted then
            isHasted = true
        end

        if isHasted and self.expectedTicks then -- Using expectedTicks
            self.dotMod = (expirationTime - start) / self.expectedTicks
        elseif isHasted then
            local bct = ns.config.hastedSpellID[2]
            local hct = select(7, GetSpellInfo(ns.config.hastedSpellID[1])) / 1000
            self.dotMod = self.dot * (hct / bct)
            --[[    if ns.config.nonAffectingHaste then
        for i,nah in ipairs(ns.config.nonAffectingHaste) do
          local name,_,_,_,_,source = ns:GetAura(nah[1],'buff','player')
          if name and (source == 'player') then
            self.dotMod = self.dotMod * nah[2]
          end
        end
      end--]]
        end
        self:RemoveTicksAfter(now)
        --self:AddTicks(now)

        if self.hasted then
            isHasted = true
        end

        if isHasted and self.ticks then -- Tick-process haste handling
            self.ticks.last = self.ticks.last or now
            self.dotMod = self.dotMod and self.dotMod or self.dot
            if (self.dotMod > self.dot) or (self.dotMod < 1.5) then self.dotMod = self.dot end
            self.isHasted = true
        elseif isHasted and self.expectedTicks then -- Using expectedTicks
            self.dotMod = (expirationTime - start) / self.expectedTicks
        end

        while nexttick <= (self.stop + 0.2) do -- Account for lag
            if now + vars.future < nexttick then
                -- The next tick is not visible yet.
                self.nexttick = nexttick
                self.lasttick = self.stop
                break
            end
            if now + vars.past <= nexttick then
                -- The next tick is visible.
                local tick = self:AddIndicator('tick', 'tick', nexttick)
                if nexttick <= now then
                    tick.happened = true
                end
                self.latesttick = nexttick
            end
            nexttick = nexttick + (self.dotMod or self.dot)
        end
    end
end

local SpellFrame_UpdateTotem = function(self, addnew, source, now, start, expirationTime, duration, name, refresh, guid)
    local addticks
    local isHasted
    local checkDoT = self.auranamePrimary or name
    local isPrimary = checkDoT == name or nil
    self.start, self.stop, self.duration = start, expirationTime, duration

    local targ = "player"
    if addnew then
        --debug('addnew', start, expirationTime)
        local typeid = (source == 'player' and self.isType) or (source ~= 'player' and 'debuff')
        if self.cast and self.useSmalldebuff then
            self.aurasegment = self:AddSegment(typeid, 'smalldebuff', start, expirationTime)

            local hastedcasttime = select(7, GetSpellInfo(self.lastcast or self.spellname)) / 1000
            self.cantcast = self:AddSegment(typeid, 'cantcast', start, expirationTime - hastedcasttime)

            --local pandemic_duration = duration*0.3
            --self.cantcast = self:AddSegment(typeid, 'cantcast', start, expirationTime - pandemic_duration
            --self.cantcast.pandemic_duration = pandemic_duration

            self.aurasegment.lastunit = targ
        else
            self.aurasegment = self:AddSegment(typeid, 'default', start, expirationTime)
            self.aurasegment.lastunit = targ
        end
        -- Add visible ticks.
        if self.dot and isPrimary then
            addticks = start
        end
        if self.debuffs then
            -- Refreshable only.
            self.targetdebuff = { start = start, stop = expirationTime }
            self.debuffs[guid] = self.targetdebuff
        end
        self.recenttick = now
    elseif refresh then
        -- debug('refresh', start, expirationTime)
        -- Note: refresh requires afflicted and self.targetdebuff. Also, afflicted and not self.debuff implies addnew.
        -- So we can get here only if afflicted and self.debuff and self.targetdebuff.
        self.aurasegment.stop = expirationTime
        self.targetdebuff.stop = expirationTime
        if self.cantcast then
            self.cantcast.start = start
            self.cantcast.stop = expirationTime - select(7, GetSpellInfo(self.lastcast or self.spellname)) / 1000
        end
        if self.latesttick then
            addticks = self.latesttick
        end
    end
    if addticks then
        addticks = self.recenttick or addticks
        local nexttick = addticks + (self.dotMod or self.dot)
        self.nexttick = nil

        if self.hasted then
            isHasted = true
        end

        if isHasted and self.expectedTicks then -- Using expectedTicks
            self.dotMod = (expirationTime - start) / self.expectedTicks
        elseif isHasted then
            local bct = ns.config.hastedSpellID[2]
            local hct = select(7, GetSpellInfo(ns.config.hastedSpellID[1])) / 1000
            self.dotMod = self.dot * (hct / bct)
            --[[    if ns.config.nonAffectingHaste then
        for i,nah in ipairs(ns.config.nonAffectingHaste) do
          local name,_,_,_,_,source = ns:GetAura(nah[1],'buff','player')
          if name and (source == 'player') then
            self.dotMod = self.dotMod * nah[2]
          end
        end
      end--]]
        end
        self:RemoveTicksAfter(now)
        --self:AddTicks(now)

        if self.hasted then
            isHasted = true
        end

        if isHasted and self.ticks then -- Tick-process haste handling
            self.ticks.last = self.ticks.last or now
            self.dotMod = self.dotMod and self.dotMod or self.dot
            if (self.dotMod > self.dot) or (self.dotMod < 1.5) then self.dotMod = self.dot end
            self.isHasted = true
        elseif isHasted and self.expectedTicks then -- Using expectedTicks
            self.dotMod = (expirationTime - start) / self.expectedTicks
        end

        while nexttick <= (self.stop + 0.2) do -- Account for lag
            if now + vars.future < nexttick then
                -- The next tick is not visible yet.
                self.nexttick = nexttick
                self.lasttick = self.stop
                break
            end
            if now + vars.past <= nexttick then
                -- The next tick is visible.
                local tick = self:AddIndicator('tick', 'tick', nexttick)
                if nexttick <= now then
                    tick.happened = true
                end
                self.latesttick = nexttick
            end
            nexttick = nexttick + (self.dotMod or self.dot)
        end
    end
end

local SpellFrame_PLAYER_REGEN_ENABLED = function(self)
    local thresh = GetTime() - 10
    local remove = {}
    for guid, data in pairs(self.debuffs) do
        if data.stop < thresh then
            tinsert(remove, guid)
        end
    end
    for _, guid in ipairs(remove) do
        --debug('removing',guid,self.spellname)
        self.debuffs[guid] = nil
    end
end

local SpellFrame_SPELL_UPDATE_CHARGES = function(self)
    if not self.rechargeTable then return end

    local current, max, startTime, duration, unknown = GetSpellCharges(self.rechargeTable.spellID)
    local displayMax = math.min(self.rechargeTable.maxDisplayCount or max, max)
    local now = GetTime()
    self.rechargeIndicators = self.rechargeIndicators or {}

    -- We want to show an indicator for each charge that ends when _that_ charge is available

    -- Since current is the number of charges currently available, all of the charge indicators in this loop
    -- are available and so should be removed
    for charge = 1, current do
        local chargeIndicator = self.rechargeIndicators[charge]
        if chargeIndicator then
            --  debug("removing indicator", "charge", charge, "current", current, "displayMax", displayMax)
            -- nponoBegHuk: the "for" section of the code below doesn't address the issue when charges "magically" appear due to procs/talents.
            self.rechargeIndicators[charge].stop = math.min(now, self.rechargeIndicators[charge].stop)
            -- nponoBegHuk: The indicator is gone from the table but will live in our memories. And on the screen. P.S.: Please feel free to delete my dumb comments.
            self.rechargeIndicators[charge] = nil
        end
    end

    -- These all need to have indicators, or the indicators need to be updated to match new values
    for charge = current + 1, displayMax do
        local chargeIndicator = self.rechargeIndicators[charge]

        local chargeStart = startTime
        local chargeStop = startTime + duration * (charge - current)
        -- debug("chargeStop", chargeStop)

        if chargeIndicator then
            -- debug("updating indicator", "charge", charge, "current", current, "displayMax", displayMax, "chargeStart", chargeStart, "chargeStop", chargeStop)
            -- UpdateCharges event will set the start time of the higher-order charge to be chargeStop - duration
            -- Thus, in order to preserve continuity in the past, we want to disallow updating the start time to a newer value
            -- nponoBegHuk: past is past and it does not need to be changed. Not sure when this is needed. Please elaborate. Disabling for now.
            -- chargeIndicator.start = math.min(chargeStart, chargeIndicator.start)
            chargeIndicator.stop = chargeStop
        else -- We need to make one
            -- Want largest charge on bottom
            local topPercent = (charge - 1) / displayMax
            local bottomPercent = charge / displayMax
            -- nponoBegHuk: once again, changing the past and disobeying second law of thermodynamics is not what I would want to meddle with.
            self.rechargeIndicators[charge] = self:AddSegment('recharge', 'recharge', math.max(now, chargeStart),
                chargeStop, nil, topPercent, bottomPercent)
            --  debug("adding indicator", "charge", charge, "current", current, "displayMax", displayMax, "chargeStart", chargeStart, "chargeStop", chargeStop, "topPercent", topPercent, "bottomPercent", bottomPercent, "indicatorTime", self.rechargeIndicators[charge].time, "indicatorStart", self.rechargeIndicators[charge].start, "indicatorStop", self.rechargeIndicators[charge].stop)
        end
    end

    -- Set the stacks on the icon to be the current number of charges
    --  self:SetStacks(current)
end

local SpellFrame_UNIT_SPELL_HASTE = SpellFrame_SPELL_UPDATE_CHARGES

local SpellFrame_SPELL_UPDATE_COOLDOWN = function(self)
    --  print(self.spellname,self.cooldownID,'SPELL_UPDATE_COOLDOWN')
    if self.slotID and self.cooldownID and not (self.spellname) then -- item is equipped but has none of the needed info, so rescan it.
        return self:PLAYER_EQUIPMENT_CHANGED(self.slotID)
    end
    if not (self.cooldownID or self.spellname) then return end

    local start = 0
    local duration = 0
    local enabled
    local ready

    if self.cooldownTable then -- we choose the one with the longer CD (This is mostly for sfiend/mindbender bar)
        for i, cooldown in pairs(self.cooldownTable) do
            start2, duration2, enabled2 = self.CooldownFunction(cooldown)
            if start2 + duration2 > start + duration then
                --print(cooldown, "better", start2+duration2, start+duration)
                start = start2
                duration = duration2
                enabled = enabled2
                ready = (enabled == 1 and start ~= 0 and duration) and start + duration
            end
        end
    else
        start, duration, enabled = self.CooldownFunction(self.cooldownID or self.spellname)
        ready = enabled == 1 and start ~= 0 and duration and start + duration
    end
    --print(start, duration, enabled, ready)
    local _, gcdDuration = GetSpellCooldown(ns.config.gcdSpellID)
    if ready and duration > gcdDuration then
        -- The spell is on cooldown, but not just because of the GCD.
        if self.cooldown ~= ready then     -- The CD has changed since last check
            if not (self.coolingdown) then -- No CD bar exists.
                self.coolingdown = self:AddSegment('cooldown', self.smallCooldown and 'smallCooldown' or 'cooldown',
                    start, ready)
            elseif self.coolingdown.stop and self.coolingdown.stop ~= ready then -- cd exists but has changed
                -- nponoBegHuk: if you want a good story about changing past, watch Steins;Gate.
                -- self.coolingdown.start = start
                self.coolingdown.stop = ready
            end
            self.cooldown = ready
        end
    else
        if self.coolingdown then
            -- Spell is off cooldown or cd expires during GCD window
            local now = GetTime()
            -- See when the cooldown is ready. If the spell is currently on GCD, check the GCD end; otherwise check now.
            if self.cooldown > (ready or now) then
                -- The cooldown ended earlier.
                self.coolingdown.stop = now
            end
            self.coolingdown = nil
        end
        self.cooldown = nil
    end
end

local SpellFrame_PLAYER_EQUIPMENT_CHANGED = function(self, slot, equipped)
    if not (slot or self.slotID) or (self.slotID ~= slot) then return end

    for i = #self.indicators, 1, -1 do
        self:Remove(i)
    end

    self.aurasegment = nil
    self.nexttick = nil
    self:SetStacks()

    self.cooldown = nil
    self.coolingdown = nil
    self.playerbuff = nil
    self.spellname = nil
    self.auraname = nil
    self.internalcooldown = true

    local itemID, name, tex = self:FindItemInfo()
    self.cooldownID = itemID

    if (itemID and name and tex) and not (ns.trinkets.blacklist[name]) then
        self.spellname = name
        self.icon:SetTexture(tex)

        self.stance = true -- Always show

        if ns.trinkets[name] then
            if type(ns.trinkets[name]) == 'number' then
                self.playerbuff = ns.trinkets[name]
            elseif type(ns.trinkets[name]) == 'table' then
                self.playerbuff = ns.trinkets[name][1]
                self.internalcooldown = ns.trinkets[name][2]
            end
        elseif self.slotID == 10 then
            self.playerbuff = 54758 -- Engy gloves
        elseif self.slotID == 8 then
            self.playerbuff = 54861 -- Nitro Boosts
        end

        if type(self.playerbuff) == 'number' then
            self.auraname = (GetSpellInfo(self.playerbuff))
        elseif type(self.playerbuff) == 'table' then
            self.auraname = {}
            self.auranamePrimary = (GetSpellInfo(self.playerbuff[1]))
            for i, id in ipairs(self.playerbuff) do
                tinsert(self.auraname, (GetSpellInfo(id)))
            end
            self.AuraFunction = UnitBuffUnique
        else
            self.auraname = self.spellname
        end
        self:SPELL_UPDATE_COOLDOWN()
    else
        self.stance = 50 -- More efficient than other methods of hiding the bar.
        self.icon:SetColorTexture(0, 0, 0, 0)
    end

    -- Throttle equipment checks to every 2 seconds. This should decrease overall cpu load while making equipment checks more reliable on beta/ptr.
    --  vars.EQCframes = vars.EQCframes or {}
    --  table.insert(vars.EQCframes,self)
    --print('equipment update - slot '..self.slotID)
    if not (vars.currentEQcheck) then
        frame2.elapsed = 0
        vars.currentEQcheck = true
        frame2:SetScript('OnUpdate', function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 2 then
                MainFrame:UPDATE_SHAPESHIFT_FORM()
                --[[  for i,v in ipairs(vars.EQCframes) do
          v:SPELL_UPDATE_COOLDOWN()
        end  ]] --
                vars.currentEQcheck = nil
                --    vars.EQCframes = nil
                --print('equipment check onupdate complete and cleared')
                self:SetScript('OnUpdate', nil)
            end
        end)
    end
end

--[[
Things get ugly again here.
UNIT_AURA does not fire for mouseover units, so we need to emulate it.
UPDATE_MOUSEOVER_UNIT does not fire when a mouseover unit is cleared, so we need to emulate that as well.
The UMU check is unthrottled by necessity. UNIT_AURA doesn't really need to be run more than 10 times per second, so it gets throttled to save cycles.
]] --
local TTL, TSLU = 0.15, 0
local UpdateMouseover = function(self, elapsed)
    TSLU = TSLU + elapsed
    if not (UnitExists('mouseover')) then
        ns:CheckMouseover()
        frame:SetScript('OnUpdate', nil)
    else
        if (TSLU >= TTL) then
            MainFrame:UNIT_AURA('mouseover')
            TSLU = 0
        end
    end
end

local SpellFrame_UPDATE_MOUSEOVER_UNIT = function(self)
    --print("UPDATE_MOUSEOVER_UNIT")
    if UnitExists('mouseover') then
        vars.isMouseover = true
        self.auraunit = 'mouseover'
    else
        vars.isMouseover = nil
        self.auraunit = self.baseunit
    end
    frame:SetScript('OnUpdate', UpdateMouseover)

    if self.aurasegment then
        for i = #self.indicators, 1, -1 do
            local ind = self.indicators[i]
            if auraids[ind.typeid] then
                self:Remove(i)
            end
        end
        self.aurasegment = nil
        self.nexttick = nil
        self:SetStacks()
    end

    if self.refreshable then
        if UnitExists(self.auraunit) then
            local guid = UnitGUID(self.auraunit)
            if UnitIsDead(self.auraunit) then
                self.debuffs[guid] = nil
            else
                self.targetdebuff = self.debuffs[guid]
                --if self.targetdebuff then debug(self.spellname, 'have old') end
                MainFrame:UNIT_AURA(self.auraunit)
                --if self.aurasegment then debug(self.spellname, 'added new') end
            end
        end
    elseif UnitExists(self.auraunit) then
        MainFrame:UNIT_AURA(self.auraunit)
    end
end

-- A SpellFrame is active (i.e. listening to events) iff the talent requirements are met.
-- The table EventHorizon.frames.active contains all the active frames.
-- If the stance requirement is not met, the frame is hidden, but still active.
local SpellFrame_Deactivate = function(self)
    if not self.isActive then return end
    --debug('unregistering events for', self.spellname)
    self:UnregisterAllEvents()
    if self.interestingCLEU then
        local activeFrame = nil
        for _, frame in ipairs(ns.frames.active) do
            if frame.spellname == self.spellname then
                activeFrame = frame
                break
            end
        end
        if not activeFrame then
            MainFrame.framebyspell[self.spellname] = nil
        end
    end
    self:Hide()
    for index = #self.indicators, 1, -1 do
        self:Remove(index)
    end
    self.isActive = nil
end

local SpellFrame_Activate = function(self)
    if self.isActive then return end
    --debug('registering events for', self.spellname)
    for event in pairs(self.interestingEvent) do
        -- debug("Registering Event", event)
        self:RegisterEvent(event)
    end
    if self.interestingCLEU and self.spellname then
        debug(self.spellname)
        MainFrame.framebyspell[self.spellname] = self
    end

    self:Show()
    self.isActive = true
end

local timer = 0
local checkInProgress
function ns:CheckTalents()
    --print('CheckTalents')
    if not self.isReady or checkInProgress then return end
    checkInProgress = true
    frame3:SetScript('OnUpdate', function(f, elapsed)
        timer = timer + elapsed
        if timer >= 2 then
            timer = 0
            checkInProgress = nil
            ns:CheckRequirements()
            f:SetScript('OnUpdate', nil)
        end
    end)
end

function ns:SetFrameDimensions()
    local left, right, top, bottom = 0.07, 0.93, 0.07, 0.93
    local barheight2 = self.config.height
    local modHeight = self.config.height

    local sfn = type(self.config.staticframes) == 'number' and self.config.staticframes or 0
    local sfi = self.config.hideIcons == true
    if (#ns.frames.shown >= sfn) and type(self.config.staticheight) == 'number' then
        MainFrame:SetHeight(self.config.staticheight)
        vars.barheight = (self.config.staticheight - (vars.barspacing * (vars.numframes - 1))) / vars.numframes
        modHeight = vars.barheight
        local ratio = vars.barheight / barheight2
        ratio = math.abs((1 - (1 / ratio)) / 2) -- Yes, this was a bitch to figure out.
        if vars.barheight > barheight2 then     -- icon is taller than it is wide
            left = left + ratio
            right = right - ratio
        else
            top = top + ratio
            bottom = bottom - ratio
        end
    else
        vars.barheight = barheight2
        MainFrame:SetHeight(vars.numframes * (vars.barheight + vars.barspacing) - vars.barspacing)
    end

    vars.nowleft = -vars.past / (vars.future - vars.past) * vars.barwidth - 0.5 +
        (ns.config.hideIcons and 0 or ns.config.height)
    if ns.frames.nowIndicator then
        ns.frames.nowIndicator:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
        ns.frames.nowIndicator:SetPoint('TOPLEFT', MainFrame, 'TOPLEFT', vars.nowleft, 0)
        ns.frames.nowIndicator:SetWidth(vars.onepixelwide)
        ns.frames.nowIndicator:SetColorTexture(unpack(self.colors.nowLine))
    end

    for i, spellframe in ipairs(ns.frames.shown) do
        --spellframe:ClearAllPoints()
        spellframe:SetHeight(vars.barheight)
        spellframe:SetWidth(vars.barwidth)

        spellframe.icon:ClearAllPoints()
        spellframe:SetPoint('RIGHT', MainFrame, 'RIGHT')
        if i == 1 then
            spellframe:SetPoint('TOPLEFT', MainFrame, 'TOPLEFT', sfi and 0 or barheight2, 0)
        else
            spellframe:SetPoint('TOPLEFT', ns.frames.shown[i - 1], 'BOTTOMLEFT', 0, -vars.barspacing)
        end
        if not (sfi) then
            spellframe.icon:SetPoint('TOPRIGHT', spellframe, 'TOPLEFT')
            spellframe.icon:SetWidth(barheight2)
            spellframe.icon:SetHeight(modHeight)
            spellframe.icon:SetTexCoord(left, right, top, bottom)
        end

        for i, indicator in ipairs(spellframe.indicators) do
            spellframe:StyleIndicator(indicator)
        end
    end
end

--[[
function ns:AddCheckedTalent(tab,index)
  local required = true
  for k,v in ipairs(self.talents) do
    if (v[1] == tab) and (v[2] == index) then
      required = nil
    end
  end
  if required then
    table.insert(self.talents,{tab,index})
  end
end
]]

function ns:CheckRequirements()
    if not ns.isReady then return end

    table.wipe(self.frames.active)
    table.wipe(self.frames.mouseover)
    --print('checkrequirements')
    --print(GetTime())

    EventHorizonDB.charInfo = EventHorizonDB.charInfo or {}
    local cc = EventHorizonDB.charInfo

    vars.activeTree = GetSpecialization() or 0
    vars.activeTalentGroup = GetActiveSpecGroup('player')
    vars.currentLevel = UnitLevel('player')

    --print("activeTree: "..vars.activeTree)
    --print("activeTalentGroup: "..vars.activeTalentGroup)
    --print("activeLevel: "..vars.currentLevel)

    vars.currentTalents = {};

    if Dragonflight then
        local configId = C_ClassTalents.GetActiveConfigID()
        if configId then
            local configInfo = C_Traits.GetConfigInfo(configId)
            for _, treeId in ipairs(configInfo.treeIDs) do
                local nodes = C_Traits.GetTreeNodes(treeId)
                for _, nodeId in ipairs(nodes) do
                    local node = C_Traits.GetNodeInfo(configId, nodeId)
                    if node and node.ID ~= 0 then
                        for _, talentId in ipairs(node.entryIDsWithCommittedRanks) do
                            local entryInfo = C_Traits.GetEntryInfo(configId, talentId)
                            local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            --	        print("tId="..talentId, "sId="..definitionInfo.spellID, select(1,GetSpellInfo(definitionInfo.spellID)).." rank "..node.currentRank)
                            vars.currentTalents[definitionInfo.spellID] = node.currentRank
                        end
                    end
                end
            end
        end
    else
        for i = 1, GetNumTalents() do
            local nameTalent, icon, tier, column, active = GetTalentInfo(i);
            vars.currentTalents[i] = active;
        end
    end

    for i, config in ipairs(self.frames.config) do
        local rS = config.requiredTree
        local rL = config.requiredLevel or 1
        local rT = config.requiredTalent
        local nRT = config.requiredTalentUnselected

        local haveSpecReq = true
        local haveTalentReq = true
        local haveTalentRequiredUnselected = true
        local haveLevelReq = rL <= vars.currentLevel

        if rS then
            haveSpecReq = nil
            if type(rS) == 'number' then
                rS = { rS }
            end
            --print(config.spellID,rS)
            for i, spec in ipairs(rS) do
                --print("    ", spec, vars.activeTree)
                if spec == vars.activeTree then
                    haveSpecReq = true
                end
            end
        end

        -- All talents must be active for it to work
        if rT then
            if type(rT) == 'number' then
                rT = { rT }
            end
            --nameTalent, icon, tier, column, active = GetTalentInfo(rT);
            for i, talent in ipairs(rT) do
                --print(talent..' check')
                haveTalentReq = haveTalentReq and vars.currentTalents[talent]
            end
        end

        --print("nRT Check:", nRT, vars.currentTalents[nRT])
        if nRT then
            if vars.currentTalents[nRT] then
                haveTalentRequiredUnselected = nil
            end
        end


        -- Check if there already is a frame
        local spellframe = self.frames.frames[i]
        local frameExists = spellframe ~= nil

        --print(haveSpecReq, haveLevelReq, haveTalentReq, haveTalentRequiredUnselected)

        if haveSpecReq and haveLevelReq and haveTalentReq and haveTalentRequiredUnselected then
            --print('adding bar')
            if frameExists then
                spellframe:Activate()
            else
                spellframe = self:CreateSpellBar(config)
                self.frames.frames[i] = spellframe
            end
            table.insert(self.frames.active, spellframe)

            if spellframe.usemouseover then
                table.insert(self.frames.mouseover, spellframe)
            end

            if type(config.cooldown) == "table" then -- We need to update the spellID again
                spellframe.cooldownTable = config.cooldown
            end
        else
            if frameExists then
                spellframe:Deactivate()
            end
        end
    end

    local activate = #self.frames.active > 0
    self:Activate(activate)
    if activate then
        MainFrame:UPDATE_SHAPESHIFT_FORM()
    else
        ns:DisplayEmptyFrameTip()
    end

    ns:ModuleEvent('CheckTalents')
end

local mainFrame_UPDATE_SHAPESHIFT_FORM = function(self)
    local stance = GetShapeshiftForm()
    -- On PLAYER_LOGIN, GetShapeshiftForm() sometimes returns a bogus value (2 on a priest with 1 form). Ignored for Warlocks and cached information.
    if not (stance) or (GetNumShapeshiftForms() and class ~= 'WARLOCK' and stance > GetNumShapeshiftForms()) then return end
    MainFrame:SetHeight(1)
    table.wipe(ns.frames.shown)

    EventHorizonDB.charInfo.stance = stance
    vars.numframes = 0

    for i, spellframe in ipairs(ns.frames.active) do
        local shown = spellframe:IsShown()

        if spellframe.stance then
            shown = false
            if type(spellframe.stance) == 'table' then
                shown = false
                for i in ipairs(spellframe.stance) do
                    if spellframe.stance[i] == stance then
                        shown = true
                    end
                end
            elseif spellframe.stance == true then
                shown = true
            elseif spellframe.stance == stance and not shown then
                shown = true
            elseif spellframe.stance and spellframe.stance ~= stance and shown then
                shown = false
            end
        end

        if spellframe.notstance then
            shown = true
            if spellframe.notstance and type(spellframe.notstance) == 'table' then
                for i in ipairs(spellframe.notstance) do
                    if spellframe.notstance[i] == stance then
                        shown = false
                    end
                end
            elseif spellframe.notstance == stance then
                shown = false
            end
        end

        if shown then
            spellframe:Show()
            vars.numframes = vars.numframes + 1
            table.insert(ns.frames.shown, spellframe)
        else
            spellframe:Hide()
            for i, indicator in ipairs(spellframe.indicators) do
                indicator:Hide()
            end
        end
    end

    if vars.numframes > 0 then
        ns:SetFrameDimensions()
        if (EventHorizonDB.redshift) and (ns.modules.redshift.isReady and EventHorizonDB.redshift.isActive == true) then
            ns.modules.redshift:Check()
        elseif ns.isActive and vars.visibleFrame then
            MainFrame:Show()
        end
    else
        MainFrame:Hide()
    end

    return true
end

function ns:CheckMouseover()
    for i, spellframe in ipairs(self.frames.mouseover) do
        spellframe:UPDATE_MOUSEOVER_UNIT()
    end
end

-- GCD indicator
local mainFrame_SPELL_UPDATE_COOLDOWN = function(self)
    if ns.frames.gcd then
        local start, duration = GetSpellCooldown(vars.gcdSpellName)
        local sfi = ns.config.hideIcons
        --print(start,duration)
        if start and duration and duration > 0 then
            vars.gcdend = start + duration
            MainFrame:SetScript('OnUpdate', function(self, elapsed)
                if vars.gcdend then
                    local now = GetTime()
                    if vars.gcdend <= now then
                        vars.gcdend = nil
                        ns.frames.gcd:Hide()
                    else
                        local diff = now + vars.past
                        local p = (vars.gcdend - diff) * vars.scale
                        if p <= 1 then
                            ns.frames.gcd:SetPoint('RIGHT', self, 'RIGHT', (p - 1) * vars.barwidth + vars.onepixelwide, 0)
                            ns.frames.gcd:Show()
                        end
                    end
                end
            end)
        else
            vars.gcdend = nil
            ns.frames.gcd:Hide()
            MainFrame:SetScript('OnUpdate', nil)
        end
    end
end

-- Dispatch the CLEU.
local mainFrame_COMBAT_LOG_EVENT_UNFILTERED = function(...)
    local self, time, event, hideCaster, srcguid, srcname, srcflags, srcraidflags, destguid, destname, destflags, destraidflags, spellid, spellname = ...
    if srcguid ~= vars.playerguid or event:sub(1, 5) ~= 'SPELL' then return end
    local spellframe = self.framebyspell[spellname]
    if ns.otherIDs[spellname] then
        MainFrame:CLEU_OtherInterestingSpell(time, event, hideCaster, srcguid, srcname, srcflags, destguid, destname,
            destflags, spellid, spellname)
    end
    if spellframe then
        if spellframe.interestingCLEU[event] then
            spellframe:COMBAT_LOG_EVENT_UNFILTERED(time, event, hideCaster, srcguid, srcname, srcflags, destguid,
                destname, destflags, spellid, spellname)
        end
    end
end

function ns:LoadClassModule()
    local class = select(2, UnitClass('player'))

    class = class:sub(1, 1) .. class:sub(2):lower() -- 'WARLOCK' -> 'Warlock'

    local name, _, _, enabled, loadable = GetAddOnInfo('EventHorizon_' .. class)

    DisableAddOn('EventHorizon_Redshift')
    DisableAddOn('EventHorizon_Lines')

    if not loadable then return end

    local loaded, reason = LoadAddOn(name)
    if loaded and self.InitializeClass then
        return true
    end
end

--[[
spellid: number, rank doesn't matter
abbrev: string
config: table
{
  cast = <boolean>,
  channeled = <boolean>,
  numhits = <number of hits per channel>,
  cooldown = <boolean>,
  debuff = <boolean>,
  dot = <tick interval in s, requires debuff>,
  refreshable = <boolean>,
}
--]]
function ns:NewSpell(config)
    local spellid = config.spellID or config.itemID or config.slotID
    if type(spellid) ~= 'number' then
        return
    end

    table.insert(self.frames.config, config)
end

function ns:newSpell(config) -- New class config to old class config
    local n = {}
    local c = config

    n.spellID = (type(config.debuff) == "table" and (type(config.debuff[1]) == "table" and config.debuff[1][1] or config.debuff[1]) or config.debuff) or
        (type(config.cast) == "table" and config.cast[1] or config.cast) or
        (type(config.cooldown) == "table" and config.cooldown[1] or config.cooldown) or (config.recharge) or
        (type(config.playerbuff) == "table" and (type(config.playerbuff[1]) == "table" and config.playerbuff[1][1] or config.playerbuff[1]) or config.playerbuff) or
        EventHorizon.config.gcdSpellID

    n.itemID = c.itemID
    n.slotID = c.slotID
    n.cast = c.cast
    n.channeled = c.channel or c.channeled
    n.cooldown = c.cooldown
    n.recharge = c.recharge
    n.rechargeMaxDisplayCount = c.rechargeMaxDisplayCount
    n.timerAfterCast = c.timerAfterCast
    n.refreshable = c.refreshable == false and false or true

    if type(c.debuff) == "table" then
        if type(c.debuff[1]) == "table" then
            n.dot = c.debuff[1][2]
            n.debuff = {}
            for i, debuff in ipairs(c.debuff) do
                table.insert(n.debuff, debuff[1])
            end
        else
            n.debuff = c.debuff[1]
            n.dot = c.debuff[2]
        end
    elseif c.debuff then
        n.debuff = c.debuff
    end



    if type(c.playerbuff) == "table" and not n.debuff then
        if type(c.playerbuff[1]) == "table" then
            n.dot = c.playerbuff[1][2]
            n.playerbuff = {}
            for i, spell in ipairs(c.playerbuff) do
                table.insert(n.playerbuff, spell[1])
            end
        else
            n.playerbuff = c.playerbuff[1]
            n.dot = c.playerbuff[2]
        end
    else
        n.playerbuff = c.playerbuff
    end

    if n.dot == 0 then
        n.dot = nil
    end

    if class == "HUNTER" or class == "ROGUE" or class == "WARRIOR" or class == "DEATHKNIGHT" or class == "DEATH_KNIGHT" or class == "MONK" then
        n.hasted = false
    elseif class == "PRIEST" or class == "MAGE" or class == "WARLOCK" or class == "PALADIN" or class == "SHAMAN" then
        n.hasted = true
    else
        if GetSpecialization() == 1 then --Balance Druid
            n.hasted = true
        else
            n.hasted = false
        end
    end

    if c.hasted == true or c.hasted == false then -- overwrite default. Ex: Doom for warlocks doesn't benefit from haste
        n.hasted = c.hasted
    end

    n.recast = c.recast
    n.minstacks = c.minstacks
    n.internalcooldown = c.internalcooldown
    n.unique = c.unique
    n.keepIcon = c.keepIcon
    n.icon = c.icon
    n.smallCooldown = c.smallCooldown

    n.requiredTree = c.requiredTree
    n.requiredLevel = c.requiredLevel
    n.requiredTalent = c.requiredTalent
    n.requiredTalentUnselected = c.requiredTalentUnselected
    n.requiredArtifactTalent = c.requiredArtifactTalent

    n.stance = c.stance
    n.auraunit = c.unitaura
    n.auraunit = c.auraunit

    n.totem = c.totem

    n.bartexture = c.bartexture
    n.barcolors = c.barcolors

    --  print("Debuff is type", type(config.debuff), "and has 1st value of", select(1,config.debuff))
    debug("Adding", n.spellID, n.debuff, n.cast, n.dot, n.cooldown)
    ns:NewSpell(n)
end

--Set spellframe attributes separately from bar creation. Helps keep things tidy and all, y'know?
local function SetSpellAttributes(spellframe, config)
    local slotname, spellname, tex, _
    local interestingEvent = {}
    local interestingCLEU = {}
    local otherids = ns.otherIDs

    if config.spellID then
        spellname, _, tex = GetSpellInfo(config.spellID)
    elseif config.itemID then
        spellname, _, _, _, _, _, _, _, _, tex, _ = GetItemInfo(config.itemID)
    elseif config.slotID then
        slotname = getSlotName(config.slotID)
        spellframe.slotID = config.slotID
        spellframe.slotName = slotname
        local itemID = GetInventoryItemID('player', config.slotID)
        if itemID then
            spellname, _, _, _, _, _, _, _, _, tex, _ = GetItemInfo(itemID)
        else
            spellname = slotName
            tex = nil
        end
    end
    --debug('creating frame for ',spellname)
    spellframe.spellname = spellname

    -- Create and set the spell icon.
    if config.icon then
        local t = type(config.icon)
        if t == 'number' then
            if config.spellID then
                _, _, tex = GetSpellInfo(config.icon)
            elseif config.itemID then
                tex = select(10, GetItemInfo(config.icon))
            end
        elseif t == 'string' then
            tex = config.icon
        end
        config.keepIcon = true
    end

    spellframe.iconTexture = tex

    interestingEvent['UNIT_SPELLCAST_SENT'] = true
    if config.timerAfterCast then
        local timerAfterCast = config.timerAfterCast
        spellframe.castsuccess = {}
        spellframe.timerAfterCast = timerAfterCast

        local sn = GetSpellInfo(config.channeled)
        if type(timerAfterCast[1]) == "number" then
            local sn = GetSpellInfo(timerAfterCast[1])
            otherids[sn] = { isTimer = true }
        elseif type(timerAfterCast[1]) == "table" then
            for _, value in pairs(timerAfterCast[1]) do
                local sn = GetSpellInfo(value)
                otherids[sn] = { isTimer = true }
            end
        end
    end

    if config.itemID or config.slotID then
        spellframe.cooldown = true -- Not getting out of this one. It's an item, what else do you watch?
        spellframe.cooldownTable = type(config.cooldown) == "table" and config.cooldown or nil
        spellframe.cooldownID = config.itemID
        spellframe.CooldownFunction = GetItemCooldown
        interestingEvent['SPELL_UPDATE_COOLDOWN'] = true
        interestingEvent['BAG_UPDATE_COOLDOWN'] = true
        if config.slotID then
            config.playerbuff = true
            config.internalcooldown = true -- Failsafe
            interestingEvent['PLAYER_EQUIPMENT_CHANGED'] = true
        end
    end

    if config.cast or config.channeled then
        spellframe.cast = {}
        if config.channeled then
            -- Register for the CLEU tick event.
            interestingCLEU.SPELL_DAMAGE = true
            -- Register event functions
            interestingEvent['UNIT_SPELLCAST_CHANNEL_START'] = true
            interestingEvent['UNIT_SPELLCAST_CHANNEL_STOP'] = true
            interestingEvent['UNIT_SPELLCAST_CHANNEL_UPDATE'] = true
            local tcc = type(config.channeled)
            if config.channeled == true then          -- defaults
                spellframe.cast[spellname] = {
                    numhits = config.numhits or true, -- use numhits as an indicator that the cast is channeled and not to change smalldebuff, or something.
                    func = UnitChannelInfo,
                    id = config.spellID,
                }
            elseif tcc == 'number' then
                local sn = GetSpellInfo(config.channeled)
                spellframe.cast[sn] = {
                    numhits = config.numhits or true, -- use numhits as an indicator that the cast is channeled and not to change smalldebuff, or something.
                    func = UnitChannelInfo,
                    id = config.channeled,
                }
                otherids[sn] = { isChannel = true }
            elseif tcc == 'table' then
                local channel = type(config.channeled[1]) == 'table' and config.channeled or { config.channeled }
                for _, v in ipairs(channel) do
                    local sn = GetSpellInfo(v[1])
                    spellframe.cast[sn] = {
                        numhits = v[2] or config.numhits or true,
                        func = UnitChannelInfo,
                        id = v[1],
                    }
                    otherids[sn] = { isChannel = true }
                end
            end
        end
        if config.cast then
            interestingEvent['UNIT_SPELLCAST_START'] = true
            interestingEvent['UNIT_SPELLCAST_STOP'] = true
            interestingEvent['UNIT_SPELLCAST_DELAYED'] = true
            spellframe.useSmalldebuff = config.recast
            if ((config.debuff or config.playerbuff) and type(config.debuff or config.playerbuff) == 'boolean') then
                spellframe.useSmalldebuff = true
            end
            if config.cast == true then
                spellframe.cast[spellname] = {
                    func = UnitCastingInfo,
                    id = config.spellID
                }
            else
                config.cast = type(config.cast) == 'table' and config.cast or { config.cast }
                for _, id in ipairs(config.cast) do
                    spellframe.cast[GetSpellInfo(id)] = {
                        func = UnitCastingInfo,
                        id = id
                    }
                end
            end
        end
    end

    if config.cooldown then
        if type(config.cooldown) == 'number' then
            spellframe.cooldownID = config.cooldown
            spellframe.cooldown = true
            spellframe.cooldownTable = nil
        elseif type(config.cooldown) == 'table' then -- If the second spellID entered is actually usable, then use that otherwise use the other
            spellframe.cooldownID = true
            spellframe.cooldownTable = config.cooldown
            spellframe.cooldown = true
        else -- /shrug
            spellframe.cooldown = config.cooldown
            spellframe.cooldownTable = nil
        end
        spellframe.CooldownFunction = GetSpellCooldown
        interestingEvent['SPELL_UPDATE_COOLDOWN'] = true
    elseif config.recharge then
        -- Handles tracking of spells with charges
        local maxCharges = config.rechargeMaxDisplayCount
        if not maxCharges or type(maxCharges) ~= "number" or maxCharges < 1 then
            maxCharges = false
        end
        spellframe.rechargeTable = {
            spellID = config.recharge,
            maxDisplayCount = config.rechargeMaxDisplayCount
        }
        interestingEvent['SPELL_UPDATE_CHARGES'] = true
        interestingEvent['UNIT_SPELL_HASTE'] = true
    end

    if config.debuff then
        spellframe.isType = 'debuffmine'
        spellframe.AuraFunction = UnitDebuff
        spellframe.auraunit = config.auraunit or 'target'
        vars.debuff[spellframe.auraunit] = {}
        if spellframe.auraunit == 'mouseover' then
            interestingEvent['UPDATE_MOUSEOVER_UNIT'] = true
            spellframe.usemouseover = true
            spellframe.baseunit = config.baseunit or 'target'
        end
        local tcd = type(config.debuff)
        if tcd == 'number' then
            spellframe.auraname = (GetSpellInfo(config.debuff))
        elseif tcd == 'table' then
            spellframe.auranamePrimary = (GetSpellInfo(config.spellID))
            spellframe.auraname = {}
            for i, id in ipairs(config.debuff) do
                tinsert(spellframe.auraname, (GetSpellInfo(id)))
            end
            spellframe.AuraFunction = UnitDebuffUnique
        else
            spellframe.auraname = spellname
        end
        --    interestingEvent['UNIT_AURA'] = true
        --    interestingEvent['PLAYER_TARGET_CHANGED'] = true
        if config.dot then
            spellframe.dot = config.dot
            interestingCLEU.SPELL_PERIODIC_DAMAGE = true
            spellframe.AddTicks = AddTicks.stop
            if config.refreshable then
                spellframe.refreshable = true
                spellframe.UNIT_AURA = SpellFrame.UNIT_AURA_refreshable
                --        spellframe.PLAYER_TARGET_CHANGED = SpellFrame.PLAYER_TARGET_CHANGED_refreshable
                interestingEvent['PLAYER_REGEN_ENABLED'] = true
                interestingCLEU.SPELL_CAST_SUCCESS = true
                spellframe.debuffs = {}
                spellframe.castsuccess = {}
            end
        end
    elseif config.playerbuff then
        spellframe.isType = 'playerbuff'
        spellframe.AuraFunction = UnitBuff
        spellframe.auraunit = config.auraunit or 'player'
        vars.buff[spellframe.auraunit] = {}
        if config.auraunit then
            --      interestingEvent['PLAYER_TARGET_CHANGED'] = true
        end
        if spellframe.auraunit == 'mouseover' then
            interestingEvent['UPDATE_MOUSEOVER_UNIT'] = true
            spellframe.usemouseover = true
            spellframe.baseunit = config.baseunit or 'target'
        end
        spellframe.alwaysrefresh = true
        --    interestingEvent['UNIT_AURA'] = true
        local tcp = type(config.playerbuff)
        if tcp == 'number' then
            spellframe.auraname = (GetSpellInfo(config.playerbuff))
        elseif tcp == 'table' then
            spellframe.auraname = {}
            spellframe.auranamePrimary = (GetSpellInfo(config.spellID))
            for i, id in ipairs(config.playerbuff) do
                tinsert(spellframe.auraname, (GetSpellInfo(id)))
            end
            spellframe.AuraFunction = UnitBuffUnique
        else
            spellframe.auraname = spellname
        end

        if config.dot then -- Register for periodic effect intervals.
            spellframe.dot = config.dot
            spellframe.AddTicks = AddTicks.stop
            interestingCLEU.SPELL_PERIODIC_HEAL = true
            if config.refreshable then
                spellframe.refreshable = true
                spellframe.UNIT_AURA = SpellFrame.UNIT_AURA_refreshable
                --        spellframe.PLAYER_TARGET_CHANGED = SpellFrame.PLAYER_TARGET_CHANGED_refreshable
                interestingEvent['PLAYER_REGEN_ENABLED'] = true
                interestingCLEU.SPELL_CAST_SUCCESS = true
                spellframe.debuffs = {}
                spellframe.castsuccess = {}
            end
        end
    elseif config.totem then
        spellframe.totem = config.totem
        spellframe.isType = 'playerbuff'
        spellframe.auraunit = config.auraunit or 'player'
        spellframe.AuraFunction = 'GetTotemInfo'
        vars.buff[spellframe.auraunit] = {}
        spellframe.alwaysrefresh = true
        spellframe.auraname = GetSpellInfo(config.totem)
    end


    if config.cleu or config.event then -- Register custom CLEU events.
        if config.event then            -- Optional alias for the forgetful.
            config.cleu = config.event
        end
        local cleu = type(config.cleu)
        if cleu == 'string' then -- Single event
            interestingCLEU[config.cleu] = true
        elseif cleu == 'table' then
            for i in pairs(config.cleu) do -- Multiple events
                interestingCLEU[config.cleu[i]] = true
            end
        end
    end

    spellframe.hasted = config.hasted
    spellframe.minstacks = config.minstacks
    spellframe.stance = config.stance
    spellframe.notstance = config.notstance
    spellframe.internalcooldown = config.internalcooldown
    spellframe.bartexture = config.bartexture
    spellframe.barcolors = config.barcolors or {}
    spellframe.unique = config.unique
    spellframe.uniqueID = config.uniqueID
    spellframe.keepIcon = config.keepIcon
    spellframe.smallCooldown = config.smallCooldown

    spellframe.interestingCLEU = interestingCLEU
    return interestingEvent
end

function ns:getColor(config, typeid)
    debug("getColor", config, typeid, config.barcolors[typeid] and typeid or "default color")
    return config.barcolors[typeid] or self.colors[typeid]
end

function ns:CreateSpellBar(config)
    local slotname, spellname, tex, _

    local spellframe = CreateFrame('Frame', nil, MainFrame)
    MainFrame.numframes = MainFrame.numframes + 1

    spellframe.interestingEvent = SetSpellAttributes(spellframe, config)

    -- Create the bar.
    spellframe.indicators = {}
    if ns.config.barbg then
        spellframe:SetBackdrop { bgFile = vars.bartexture }
        spellframe:SetBackdropColor(unpack(self:getColor(spellframe, "barbgcolor")))
    end

    spellframe.icon = spellframe:CreateTexture(nil, 'BORDER')
    spellframe.icon:SetTexture(spellframe.iconTexture)

    spellframe.stacks = spellframe:CreateFontString(nil, 'OVERLAY')
    if vars.stackFont then
        spellframe.stacks:SetFont(vars.stackFont, vars.stackFontSize)
        if vars.stackFontShadow then
            spellframe.stacks:SetShadowColor(unpack(vars.stackFontShadow))
            spellframe.stacks:SetShadowOffset(unpack(vars.stackFontShadowOffset))
        end
    else
        spellframe.stacks:SetFontObject('NumberFontNormalSmall')
    end
    spellframe.stacks:SetVertexColor(unpack(vars.stackFontColor))

    for k, v in pairs(SpellFrame) do
        if not spellframe[k] then spellframe[k] = v end
    end

    spellframe:SetScript('OnEvent', EventHandler)
    spellframe:SetScript('OnUpdate', spellframe.OnUpdate)

    local sfi = self.config.hideIcons
    local sor = self.config.stackOnRight
    -- Layout
    spellframe.stacks:SetPoint((sfi and not (sor)) and 'BOTTOMLEFT' or 'BOTTOMRIGHT',
        (sfi or sor) and spellframe or spellframe.icon, (sfi and not (sor)) and 'BOTTOMLEFT' or 'BOTTOMRIGHT')
    spellframe.stacks:SetJustifyH(sor and 'LEFT' or 'RIGHT')

    spellframe:Activate()

    if config.slotID then
        spellframe:PLAYER_EQUIPMENT_CHANGED(config.slotID) -- Initialize trinkets and such if needed.
    end

    return spellframe
end

function ns:LoadModules()
    for i, module in pairs(self.modules) do
        if not EventHorizonDB[i] then EventHorizonDB[i] = { isActive = true } end
        if (EventHorizonDB[i] and EventHorizonDB[i].isActive == true) or module.alwaysLoad then
            if not (self.modules[i].Enable) then self.modules[i].Enable = function() end end
            if not (self.modules[i].Disable) then self.modules[i].Disable = function() end end
            self.modules[i]:Init()
            self.modules[i]:Enable()
            vars.modulesLoaded = true
        end
    end
end

function ns:ActivateModule(module, slash)
    if EventHorizonDB[module].isActive ~= true then
        self.modules[module].isActive = true
        EventHorizonDB[module].isActive = true
        if not (self.modules[module].isReady == true) then self.modules[module].Init() end
        self.modules[module].Enable(slash)
    end
end

function ns:DeactivateModule(module, slash)
    if EventHorizonDB[module].isActive == true then
        self.modules[module].isActive = false
        EventHorizonDB[module].isActive = false
        if not (self.modules[module].isReady == true) then self.modules[module].Init() end
        self.modules[module].Disable(slash)
    end
end

function ns:ToggleModule(module, slash)
    if EventHorizonDB[module].isActive ~= true then
        self:ActivateModule(module, slash)
    else
        self:DeactivateModule(module, slash)
    end
end

-- External event handler for modules, same rules as EH's event handler (passes self, extra args, event is presumed known)
function ns:ModuleEvent(event, ...)
    for i, module in pairs(self.modules) do
        local f = module[event]
        if f then
            f(module, ...)
        end
    end
end

function ns:Activate(...)
    local activate = select('#', ...) == 0 or ...
    --debug('Activate',activate, ...)
    if not activate then
        return self:Deactivate()
    end
    for k, v in pairs(mainFrameEvents) do
        MainFrame:RegisterEvent(k)
    end

    self.isActive = true
    vars.visibleFrame = true

    if (self.modules.redshift.isReady and EventHorizonDB.redshift.isActive == true) then
        self.modules.redshift:Check()
    else
        MainFrame:Show()
    end
end

function ns:Deactivate()
    if self.isActive == false then
        return
    end
    MainFrame:UnregisterAllEvents()
    MainFrame:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')

    MainFrame:Hide()

    self.isActive = false
end

-- We only want to show the empty frame tip if it's been more than
function ns:DisplayEmptyFrameTip()
    if EventHorizonDB.DisplayEmptyFrameTipLastShown == true then return end -- If true, then never show

    EventHorizonDB.DisplayEmptyFrameTipLastShown = EventHorizonDB.DisplayEmptyFrameTipLastShown or 0
    if time() > EventHorizonDB.DisplayEmptyFrameTipLastShown + (60 * 60 * 24 * 3) then -- Only show every couple days
        StaticPopup_Show("EH_DisplayEmptyFrameTip")
    end
end

function ns:UpdateConfig()
    if not (self.isReady) then return end
    self:ApplyConfig()

    MainFrame:SetScale(self.config.scale or 1)
    local effectiveScale = MainFrame:GetEffectiveScale()
    if effectiveScale then
        vars.onepixelwide = 1 / effectiveScale
    end

    self:SetupStyleFrame() -- Spawn backdrop frame.

    vars.nowleft = -vars.past / (vars.future - vars.past) * vars.barwidth - 0.5 +
        (ns.config.hideIcons and 0 or ns.config.height)
    --nowI:SetFrameLevel(20)
    ns.frames.nowIndicator:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
    ns.frames.nowIndicator:SetPoint('TOPLEFT', MainFrame, 'TOPLEFT', vars.nowleft, 0)
    ns.frames.nowIndicator:SetColorTexture(unpack(self.colors.nowLine))

    local anchor = self.config.anchor or { 'TOPRIGHT', 'EventHorizonHandle', 'BOTTOMRIGHT' }
    if anchor[2] == 'EventHorizonHandle' then
        -- Create the handle to reposition the frame.
        handle = handle or CreateFrame('Frame', 'EventHorizonHandle', MainFrame)
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
            EventHorizonDB.point = { a, b, c, d, e }
        end)
        handle:SetMovable(true)

        MainFrame:SetPoint(unpack(anchor))
        handle:SetPoint(unpack(EventHorizonDB.point))

        handle.tex = handle:CreateTexture(nil, 'BORDER')
        handle.tex:SetAllPoints()
        handle:SetScript('OnEnter', function(frame) frame.tex:SetColorTexture(1, 1, 1, 1) end)
        handle:SetScript('OnLeave', function(frame) frame.tex:SetColorTexture(1, 1, 1, 0.1) end)
        handle.tex:SetColorTexture(1, 1, 1, 0.1)
    end

    vars.gcdSpellName = self.config.gcdSpellID and (GetSpellInfo(self.config.gcdSpellID))
    if vars.gcdSpellName and self.config.gcdStyle then
        -- Create the GCD indicator, register cooldown event.
        ns.frames.gcd = MainFrame:CreateTexture('EventHorizonns.frames.gcd', 'BORDER')
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
    end

    MainFrame:SetPoint(unpack(anchor))
    self:SetFrameDimensions()
end

local loginCheck = function()
    if ns.isActive == true then
        ns:CheckTalents()

        for i, spellframe in pairs(ns.frames.shown) do
            if spellframe.slotID then spellframe:PLAYER_EQUIPMENT_CHANGED(spellframe.slotID) end
        end
    end
end

function ns:RegisterModule(module, namespace)
    if not (module and namespace) then
        print("Module registration failed. Usage: EventHorizon:RegisterModule(module,namespace)")
    end
    local module = string.lower(module)
    self.modules[module] = namespace
end

SpellFrame.NotInteresting = SpellFrame_NotInteresting
SpellFrame.AddSegment = SpellFrame_AddSegment
SpellFrame.AddIndicator = SpellFrame_AddIndicator
SpellFrame.StyleIndicator = SpellFrame_StyleIndicator
SpellFrame.Remove = SpellFrame_Remove
SpellFrame.RemoveTicksAfter = SpellFrame_RemoveTicksAfter
SpellFrame.RemoveChannelTicksAfter = SpellFrame_RemoveChannelTicksAfter
SpellFrame.OnUpdate = SpellFrame_OnUpdate
SpellFrame.UpdateDoT = SpellFrame_UpdateDoT
SpellFrame.UpdateTotem = SpellFrame_UpdateTotem
SpellFrame.Activate = SpellFrame_Activate
SpellFrame.Deactivate = SpellFrame_Deactivate
SpellFrame.FindItemInfo = SpellFrame_FindItemInfo
SpellFrame.SetStacks = SpellFrame_SetStacks

SpellFrame.UNIT_AURA = SpellFrame_UNIT_AURA
SpellFrame.UNIT_AURA_refreshable = SpellFrame_UNIT_AURA_refreshable
SpellFrame.COMBAT_LOG_EVENT_UNFILTERED = SpellFrame_COMBAT_LOG_EVENT_UNFILTERED
SpellFrame.UNIT_SPELLCAST_SENT = SpellFrame_UNIT_SPELLCAST_SENT
SpellFrame.UNIT_SPELLCAST_CHANNEL_START = Cast_Start
SpellFrame.UNIT_SPELLCAST_CHANNEL_UPDATE = Cast_Update
SpellFrame.UNIT_SPELLCAST_CHANNEL_STOP = Cast_Stop
SpellFrame.UNIT_SPELLCAST_START = Cast_Start
SpellFrame.UNIT_SPELLCAST_STOP = Cast_Stop
SpellFrame.UNIT_SPELLCAST_DELAYED = Cast_Update
--SpellFrame.PLAYER_TARGET_CHANGED = SpellFrame_PLAYER_TARGET_CHANGED
--SpellFrame.PLAYER_TARGET_CHANGED_refreshable = SpellFrame_PLAYER_TARGET_CHANGED_refreshable
SpellFrame.PLAYER_REGEN_ENABLED = SpellFrame_PLAYER_REGEN_ENABLED
SpellFrame.SPELL_UPDATE_COOLDOWN = SpellFrame_SPELL_UPDATE_COOLDOWN
SpellFrame.BAG_UPDATE_COOLDOWN = SpellFrame_SPELL_UPDATE_COOLDOWN
SpellFrame.SPELL_UPDATE_CHARGES = SpellFrame_SPELL_UPDATE_CHARGES
SpellFrame.UNIT_SPELL_HASTE = SpellFrame_UNIT_SPELL_HASTE
SpellFrame.PLAYER_EQUIPMENT_CHANGED = SpellFrame_PLAYER_EQUIPMENT_CHANGED
SpellFrame.UPDATE_MOUSEOVER_UNIT = SpellFrame_UPDATE_MOUSEOVER_UNIT
SpellFrame.PLAYER_TOTEM_UPDATE = SpellFrame_PLAYER_TOTEM_UPDATE


local Redshift = {}
Redshift.Check = function(self)
    if EventHorizonDB.redshift.isActive ~= true then
        return Redshift:Disable()
    end
    if not (Redshift.frame) then
        Redshift.frame = CreateFrame("FRAME", nil, UIParent)
        Redshift.frame:SetScript('OnEvent', EventHandler)
        for k, v in pairs(Redshift.Events) do
            if v then
                Redshift.frame:RegisterEvent(k)
                Redshift.frame[k] = Redshift.Check
            end
        end
    end

    local s = Redshift.states

    showState = nil

    local attackable = UnitCanAttack("player", "target")
    local targeting = UnitExists("target")
    local focusing = UnitExists("focus")
    local classify = UnitClassification("target")
    local dead = UnitIsDeadOrGhost("target")
    local vehicle = UnitHasVehicleUI("player")

    if (s.showCombat and UnitAffectingCombat("player")) then
        showState = true
    end

    if (s.showFocus and UnitExists("focus")) then
        showState = true
    end

    if targeting then
        if (s.showHelp and not attackable) and not dead then
            showState = true
        end
        if (s.showHarm and attackable) and not dead then
            showState = true
        end
        if (s.showBoss and classify == "worldboss") and not dead then
            showState = true
        end
    end

    if (s.hideVehicle and UnitHasVehicleUI("player")) then
        showState = nil
    end

    if showState then
        vars.visibleFrame = true
        MainFrame:Show()
        if EventHorizon_VitalsFrame and s.hideVitals then
            EventHorizon_VitalsFrame:Show()
        end
    else
        vars.visibleFrame = false
        MainFrame:Hide()
        if EventHorizon_VitalsFrame and s.hideVitals then
            EventHorizon_VitalsFrame:Hide()
        end
    end
end

Redshift.Init = function()
    local settingsChanged = EventHorizonDB.redshift.lastConfig ~= ns.config.enableRedshift
    EventHorizonDB.redshift.lastConfig = ns.config.enableRedshift

    if settingsChanged then
        local ends = ns.config.enableRedshift and 'enabled' or 'disabled'
        local settingsString = "Redshift has been " ..
            ends ..
            " via config.lua. Ingame settings have been adjusted to match. Use /ehz redshift to enable or disable Redshift as needed."
        EventHorizonDB.redshift.isActive = ns.config.enableRedshift
    end

    local db = EventHorizonDB.redshift.isActive
    if not (db) then return end

    Redshift.states = {}
    Redshift.Events = {
        ["PLAYER_REGEN_DISABLED"] = true,
        ["PLAYER_REGEN_ENABLED"] = true,
        ["PLAYER_TARGET_CHANGED"] = true,
        ["PLAYER_GAINS_VEHICLE_DATA"] = true,
        ["PLAYER_LOSES_VEHICLE_DATA"] = true,
        ["UNIT_ENTERED_VEHICLE"] = true,
        ["UNIT_EXITED_VEHICLE"] = true,
        ["UNIT_ENTERING_VEHICLE"] = true,
        ["UNIT_EXITING_VEHICLE"] = true,
        ["VEHICLE_PASSENGERS_CHANGED"] = true,
    }

    for k, v in pairs(ns.config.Redshift) do
        if v then
            Redshift.states[k] = true
        end
    end

    if (EventHorizonDB.redshift.isActive == true) then Redshift:Check() end
    Redshift.isReady = true
end

Redshift.Enable = function(slash)
    if EventHorizonDB.redshift.isActive and not (Redshift.isReady) then
        Redshift:Init()
        Redshift:Check()
    elseif EventHorizonDB.redshift.isActive then
        Redshift:Check()
    end
    if Redshift.frame then Redshift.frame:SetScript('OnEvent', EventHandler) end
end

Redshift.Disable = function(slash)
    vars.visibleFrame = true
    if Redshift.frame then Redshift.frame:SetScript('OnEvent', nil) end
    if ns.isActive == true then MainFrame:Show() end
end

local Lines = {}
Lines.CreateLines = function()
    if Lines.frame then return end
    local c = ns.config.Lines
    local db = EventHorizonDB.lines.isActive == true
    if not (c and db) then
        return
    elseif type(c) == 'number' then
        c = { c } -- Turn numbers into delicious tables.
    elseif type(c) ~= 'table' then
        return    -- Turn away everything else.
    end

    Lines.frame = CreateFrame('Frame', nil, UIParent)
    Lines.line = {}

    local multicolor
    local color = ns.config.LinesColor
    if color and type(color) == 'table' then
        if type(color[1]) == 'table' then
            multicolor = true -- trying not to further complicate things
            for i, v in ipairs(c) do
                if not (color[i]) then
                    color[i] = color[i - 1] -- if we have more lines than colors, we need moar colors
                end
            end
        end
    else
        color = { 1, 1, 1, 0.5 }
    end

    local now = -vars.past / (vars.future - vars.past) * vars.barwidth - 0.5 + vars.barheight
    local pps = (vars.barwidth + vars.barheight - now) / vars.future

    for i = 1, #c do
        local seconds = c[i]
        local position = now + (pps * seconds)
        Lines.line[i] = MainFrame:CreateTexture(nil, "OVERLAY")
        Lines.line[i]:SetPoint('TOPLEFT', MainFrame, 'TOPLEFT', position, 0)
        if multicolor then
            Lines.line[i]:SetColorTexture(unpack(color[i]))
        else
            Lines.line[i]:SetColorTexture(unpack(color))
        end
        Lines.line[i]:SetWidth(vars.onepixelwide)
        Lines.line[i]:SetPoint('BOTTOM', MainFrame, 'BOTTOM')
    end

    Lines.Enable = function()
        for i = 1, #Lines.line do
            Lines.line[i]:Show()
        end
    end

    Lines.Disable = function()
        for i = 1, #Lines.line do
            Lines.line[i]:Hide()
        end
    end
end

Lines.Init = function()
    Lines.CreateLines()
    Lines.isReady = true
end

ns:RegisterModule('lines', Lines)
ns:RegisterModule('redshift', Redshift)
--ns:RegisterModule('pulse',Pulse)

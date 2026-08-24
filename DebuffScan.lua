-- Per-unit aura scan. UNIT_AURA updates one unit; no full-raid OnUpdate scan.

DispellerCoA = DispellerCoA or {}

local UnitExists = UnitExists
local UnitIsVisible = UnitIsVisible
local UnitIsUnit = UnitIsUnit
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local IsSpellInRange = IsSpellInRange
local GetSpellCooldown = GetSpellCooldown
local GetTime = GetTime
local strlower = string.lower

local bleedCache = {}
local bleedTip
local bleedUnknownBudget = 0

local function NameLooksBleed(lower)
    return lower:find("bleed", 1, true) ~= nil
end

local function NameMaybeBleed(lower)
    return lower:find("wound", 1, true)
        or lower:find("gash", 1, true)
        or lower:find("blood", 1, true)
        or lower:find("cut", 1, true)
        or lower:find("tear", 1, true)
end

local function TooltipSaysBleed(unit, index)
    if not bleedTip then
        bleedTip = CreateFrame("GameTooltip", "DispellerCoABleedTip", nil, "GameTooltipTemplate")
        bleedTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    bleedTip:SetOwner(UIParent, "ANCHOR_NONE")
    bleedTip:ClearLines()
    DispellerCoA.BlankTooltipLines(bleedTip)
    DispellerCoA.PatchTooltipGetText(bleedTip)
    local oldEH = geterrorhandler()
    seterrorhandler(function() end)
    pcall(bleedTip.SetUnitDebuff, bleedTip, unit, index)
    seterrorhandler(oldEH)
    DispellerCoA.PatchTooltipGetText(bleedTip)
    local i
    for i = 1, bleedTip:NumLines() do
        local fs = _G["DispellerCoABleedTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            text = strlower(text)
            if text:find("bleed", 1, true) then
                return true
            end
        end
    end
    return false
end

-- Cheap bleed test. Tooltip is used at most once per ScanUnit, and only for
-- untyped names that look like wounds. Result is cached by aura name.
function DispellerCoA.IsBleedDebuff(name, spellId, debuffType, unit, index)
    local bleedTypes = DispellerCoA.C.BLEED_TYPES
    if debuffType and bleedTypes and bleedTypes[debuffType] then
        return true
    end
    if not name then
        return false
    end
    local cached = bleedCache[name]
    if cached ~= nil then
        return cached
    end
    local lower = strlower(name)
    if NameLooksBleed(lower) then
        bleedCache[name] = true
        return true
    end
    if bleedUnknownBudget > 0 and unit and index and NameMaybeBleed(lower) then
        bleedUnknownBudget = bleedUnknownBudget - 1
        local yes = TooltipSaysBleed(unit, index)
        bleedCache[name] = yes
        return yes
    end
    return false
end

local function IsPlayerUnit(unit)
    return unit == "player" or unit == DispellerCoA.playerUnit or UnitIsUnit(unit, "player")
end

local C = nil
local status = {}
DispellerCoA.unitStatus = status

local afflictedCount = 0
local lastAfflictedCount = 0

local function EnsureC()
    if not C then
        C = DispellerCoA.C
    end
    return C
end

local function GetStatus(unit)
    local s = status[unit]
    if not s then
        s = {
            unit = unit,
            state = "MISSING",
            types = {},
            clickType = nil,
            clickSlot = 0,
            icon = nil,
            inRange = false,
            onCD = false,
            guid = nil,
        }
        status[unit] = s
    end
    return s
end

local function ClearTypes(s)
    local t = s.types
    local i
    for i = #t, 1, -1 do
        t[i] = nil
    end
end

function DispellerCoA.ScanUnit(unit)
    local C = EnsureC()
    local s = GetStatus(unit)
    local prevClick = s.clickType
    local prevState = s.state

    if not UnitExists(unit) then
        s.state = C.STATUS.MISSING
        s.clickType = nil
        s.clickSlot = 0
        s.icon = nil
        s.inRange = false
        s.guid = nil
        ClearTypes(s)
        return s, prevState ~= s.state or prevClick ~= s.clickType
    end

    s.guid = UnitGUID(unit)
    if DispellerCoA.IsBlacklisted(s.guid) then
        s.state = C.STATUS.BLACKLISTED
        s.clickType = nil
        s.clickSlot = 0
        ClearTypes(s)
        return s, prevState ~= s.state
    end

    if not UnitIsVisible(unit) then
        s.state = C.STATUS.FAR
        s.clickType = nil
        s.clickSlot = 0
        s.inRange = false
        ClearTypes(s)
        return s, prevState ~= s.state
    end

    ClearTypes(s)
    s.icon = nil
    local found = s.types
    local db = DispellerCoA.db
    local isPlayer = IsPlayerUnit(unit)
    local canType = {}
    local t
    for t = 1, #C.TYPES do
        local typ = C.TYPES[t]
        local can = false
        if db.typeEnabled[typ] then
            local slot
            for slot = 1, #C.CLICK_SLOTS do
                local spell = DispellerCoA.ResolvedClickSpell(slot, isPlayer)
                if DispellerCoA.SpellCoversType(spell, typ) then
                    can = true
                    break
                end
            end
        end
        canType[typ] = can
    end
    local wantBleed = canType.Bleed
    bleedUnknownBudget = wantBleed and 1 or 0
    local i
    for i = 1, C.MAX_DEBUFFS do
        local name, _, icon, _, debuffType, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then
            break
        end
        local typ = debuffType
        if (not typ or not C.TYPE_SET[typ]) and wantBleed and DispellerCoA.IsBleedDebuff(name, spellId, debuffType, unit, i) then
            typ = "Bleed"
        end
        if typ and C.TYPE_SET[typ] and canType[typ] then
            found[#found + 1] = typ
            if not s.icon then
                s.icon = icon
            end
        end
    end

    local clickType, clickSlot, spell = DispellerCoA.PickClick(unit, found)
    s.clickType = clickType
    s.clickSlot = clickSlot or 0

    if clickType then
        if spell and spell.selfOnly then
            s.inRange = true
        else
            local rng = spell and IsSpellInRange(spell.name, unit)
            s.inRange = rng == 1
        end
        if spell then
            local start, duration = GetSpellCooldown(spell.name)
            s.onCD = duration and duration > 1.4 and (start + duration) > GetTime()
        else
            s.onCD = false
        end
        s.state = C.STATUS.AFFLICTED
    else
        s.inRange = true
        s.onCD = false
        s.state = C.STATUS.CLEAR
    end

    return s, prevState ~= s.state or prevClick ~= s.clickType
end

function DispellerCoA.ScanRoster()
    local list = DispellerCoA.roster
    local n = #list
    local afflicted = 0
    local i
    for i = 1, n do
        local s = DispellerCoA.ScanUnit(list[i].unit)
        if s.state == DispellerCoA.C.STATUS.AFFLICTED then
            afflicted = afflicted + 1
        end
    end
    lastAfflictedCount = afflictedCount
    afflictedCount = afflicted
    DispellerCoA.afflictedCount = afflicted
    return afflicted, lastAfflictedCount
end

function DispellerCoA.RecountAfflicted()
    local list = DispellerCoA.roster
    local afflicted = 0
    local i
    for i = 1, #list do
        local s = status[list[i].unit]
        if s and s.state == DispellerCoA.C.STATUS.AFFLICTED then
            afflicted = afflicted + 1
        end
    end
    lastAfflictedCount = afflictedCount
    afflictedCount = afflicted
    DispellerCoA.afflictedCount = afflicted
    return afflicted, lastAfflictedCount
end

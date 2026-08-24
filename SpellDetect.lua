-- Spellbook scan. Runs only on login / debounced SPELLS_CHANGED.
-- Tooltip parse is last-resort and cached for the session.

DispellerCoA = DispellerCoA or {}

local GetNumSpellTabs = GetNumSpellTabs
local GetSpellTabInfo = GetSpellTabInfo
local GetSpellName = GetSpellName
local GetSpellLink = GetSpellLink
local GetSpellInfo = GetSpellInfo
local UnitIsUnit = UnitIsUnit
local BOOKTYPE_SPELL = BOOKTYPE_SPELL

local TYPE_WORD = {
    Magic = "magic",
    Curse = "curse",
    Poison = "poison",
    Disease = "disease",
    Bleed = "bleed",
}

local tooltipCache = {}
local tip
local patchedGetText = {}

-- Ascension GameTooltipMods indexes line:GetText() with no nil check.
function DispellerCoA.BlankTooltipLines(t)
    local name = t and t:GetName()
    if not name then
        return
    end
    local i
    for i = 1, 40 do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        if not left and not right then
            break
        end
        if left then
            left:SetText("")
        end
        if right then
            right:SetText("")
        end
    end
end

local function NilSafeGetText(fs)
    if not fs or patchedGetText[fs] then
        return
    end
    patchedGetText[fs] = true
    local orig = fs.GetText
    fs.GetText = function(self)
        return orig(self) or ""
    end
end

function DispellerCoA.PatchTooltipGetText(t)
    local name = t and t:GetName()
    if not name then
        return
    end
    local i
    for i = 1, 40 do
        NilSafeGetText(_G[name .. "TextLeft" .. i])
        NilSafeGetText(_G[name .. "TextRight" .. i])
    end
end

local function EnsureTip()
    if tip then
        return tip
    end
    tip = CreateFrame("GameTooltip", "DispellerCoAScanTip", nil, "GameTooltipTemplate")
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    DispellerCoA.PatchTooltipGetText(tip)
    return tip
end

local function SafeSpellDescription(id)
    if not id then
        return nil
    end
    local ok, desc
    if C_Spell and C_Spell.GetSpellDescription then
        ok, desc = pcall(C_Spell.GetSpellDescription, id)
        if ok and type(desc) == "string" and desc ~= "" then
            return desc
        end
    end
    if GetSpellDescription then
        ok, desc = pcall(GetSpellDescription, id)
        if ok and type(desc) == "string" and desc ~= "" then
            return desc
        end
    end
    return nil
end

local function NameLooksCleanse(name)
    if not name then
        return false
    end
    local n = name:lower()
    return n:find("dispel", 1, true)
        or n:find("cleanse", 1, true)
        or n:find("purif", 1, true)
        or n:find("cure", 1, true)
        or n:find("abolish", 1, true)
        or n:find("stoneform", 1, true)
        or n:find("rebuke", 1, true)
        or n:find("remove", 1, true)
        or n:find("purge", 1, true)
end

local tipParts = {}

local function TooltipText()
    local t = EnsureTip()
    local n = t:NumLines()
    local used = 0
    local i
    for i = 1, n do
        local fs = _G["DispellerCoAScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text ~= "" then
            used = used + 1
            tipParts[used] = text
        end
    end
    for i = #tipParts, used + 1, -1 do
        tipParts[i] = nil
    end
    return table.concat(tipParts, "\n"):lower()
end

-- SetSpell on a hidden GameTooltip trips Ascension GameTooltipMods (nil lineText).
-- Prefer GetSpellDescription; only SetSpell for names that look like cleanses.
local function ScanTooltipText(slot)
    local t = EnsureTip()
    t:SetOwner(UIParent, "ANCHOR_NONE")
    t:ClearLines()
    DispellerCoA.BlankTooltipLines(t)
    DispellerCoA.PatchTooltipGetText(t)
    local oldEH = geterrorhandler()
    seterrorhandler(function() end)
    pcall(t.SetSpell, t, slot, BOOKTYPE_SPELL)
    seterrorhandler(oldEH)
    DispellerCoA.PatchTooltipGetText(t)
    return TooltipText()
end

local function ParseTooltip(slot, name, id)
    local cacheKey = id or name or slot
    local cached = tooltipCache[cacheKey]
    if cached ~= nil then
        return cached ~= false and cached or false
    end
    local text
    local desc = SafeSpellDescription(id)
    if desc then
        text = desc:lower()
    elseif NameLooksCleanse(name) then
        text = ScanTooltipText(slot)
    else
        tooltipCache[cacheKey] = false
        return false
    end
    if not text or text == "" then
        tooltipCache[cacheKey] = false
        return false
    end

    -- Skip offensive-only purges. Self-only bleed/poison/disease removers (Stoneform) are kept.
    local hasEnemy = text:find("enemy", 1, true)
    local hasFriend = text:find("friend", 1, true) or text:find("ally", 1, true)
    if hasEnemy and not hasFriend then
        tooltipCache[cacheKey] = false
        return false
    end
    local selfOnly = (text:find("yourself", 1, true) ~= nil or text:find("self only", 1, true) ~= nil) and not hasFriend

    local looksDispel = text:find("dispel", 1, true)
        or text:find("remov", 1, true)
        or text:find("cleanse", 1, true)
        or text:find("purif", 1, true)
        or text:find("cure", 1, true)
    if not looksDispel then
        tooltipCache[cacheKey] = false
        return false
    end
    if text:find("interrupt", 1, true) and not (text:find("dispel", 1, true) or text:find("cleanse", 1, true) or text:find("purif", 1, true)) then
        tooltipCache[cacheKey] = false
        return false
    end

    local types = {}
    local k, word
    for k, word in pairs(TYPE_WORD) do
        if text:find(word, 1, true) then
            types[#types + 1] = k
        end
    end
    if #types == 0 then
        tooltipCache[cacheKey] = false
        return false
    end

    if selfOnly then
        local okSelf = false
        local t
        for t = 1, #types do
            if types[t] == "Bleed" or types[t] == "Poison" or types[t] == "Disease" then
                okSelf = true
                break
            end
        end
        if not okSelf then
            tooltipCache[cacheKey] = false
            return false
        end
    end

    local entry = {
        types = types,
        isHoT = text:find("every", 1, true) ~= nil,
        fromTooltip = true,
        selfOnly = selfOnly,
    }
    tooltipCache[cacheKey] = entry
    return entry
end

local function Score(entry)
    local n = entry.types and #entry.types or 0
    local score = n * 10
    if not entry.isHoT then
        score = score + 3
    end
    if entry.selfOnly then
        score = score - 20
    end
    return score
end

function DispellerCoA.DetectCures()
    local db = DispellerCoA.db
    local known = {}
    local byType = {}

    local tabs = GetNumSpellTabs()
    local tab
    for tab = 1, tabs do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        local slot
        for slot = offset + 1, offset + numSpells do
            local name = GetSpellName(slot, BOOKTYPE_SPELL)
            if name then
                local link = GetSpellLink(slot, BOOKTYPE_SPELL)
                local id = link and tonumber(link:match("spell:(%d+)"))
                local cat = (id and DispellerCoA.CatalogById[id]) or DispellerCoA.CatalogByName[name]
                local parsed = cat
                if not parsed then
                    parsed = ParseTooltip(slot, name, id)
                end
                if parsed and parsed.types then
                    known[#known + 1] = {
                        id = id,
                        name = name,
                        types = parsed.types,
                        isHoT = parsed.isHoT,
                        fromTooltip = parsed.fromTooltip,
                        selfOnly = parsed.selfOnly,
                    }
                end
            end
        end
    end

    local i, t
    for i = 1, #known do
        local spell = known[i]
        for t = 1, #spell.types do
            local typ = spell.types[t]
            local cur = byType[typ]
            if not cur or Score(spell) > Score(cur) then
                byType[typ] = spell
            end
        end
    end

    if db and db.overrides then
        for t = 1, #DispellerCoA.C.TYPES do
            local typ = DispellerCoA.C.TYPES[t]
            local over = db.overrides[typ]
            if over and over ~= "" then
                local infoName = GetSpellInfo(over)
                if infoName then
                    byType[typ] = {
                        name = infoName,
                        types = { typ },
                        override = true,
                    }
                end
            end
        end
    end

    DispellerCoA.knownSpells = known
    DispellerCoA.cures = byType
    return byType, known
end

function DispellerCoA.CanCureAnything()
    local cures = DispellerCoA.cures
    if not cures then
        return false
    end
    local i
    for i = 1, #DispellerCoA.C.TYPES do
        if cures[DispellerCoA.C.TYPES[i]] then
            return true
        end
    end
    return false
end

local enabledBuf = {}

function DispellerCoA.EnabledCureTypes()
    local db = DispellerCoA.db
    local write = 0
    if not db or not db.typeOrder then
        local i
        for i = #enabledBuf, 1, -1 do
            enabledBuf[i] = nil
        end
        return enabledBuf
    end
    local order = db.typeOrder
    local i
    for i = 1, #order do
        local typ = order[i]
        if db.typeEnabled[typ] and DispellerCoA.cures[typ] then
            write = write + 1
            enabledBuf[write] = typ
        end
    end
    for i = #enabledBuf, write + 1, -1 do
        enabledBuf[i] = nil
    end
    return enabledBuf
end

-- Auto maps each click to a fixed type slot (Magic=1, Curse=2, ...) so a
-- multi-type cleanse like Rebuke does not steal Poison/Disease onto Left.
function DispellerCoA.AutoTypeForSlot(slot)
    local db = DispellerCoA.db
    if not db or not db.typeOrder then
        return nil
    end
    local typ = db.typeOrder[slot]
    if not typ then
        return nil
    end
    if db.typeEnabled and not db.typeEnabled[typ] then
        return nil
    end
    if not (DispellerCoA.cures and DispellerCoA.cures[typ]) then
        return nil
    end
    return typ
end

function DispellerCoA.GetClickBind(slot)
    local binds = DispellerCoA.db and DispellerCoA.db.clickBinds
    local key = binds and binds[slot]
    if not key or key == "" then
        return "auto"
    end
    return key
end

function DispellerCoA.SetClickBind(slot, key)
    local db = DispellerCoA.db
    if not db then
        return
    end
    if not db.clickBinds then
        db.clickBinds = { "auto", "auto", "auto", "auto", "auto" }
    end
    db.clickBinds[slot] = key or "auto"
end

function DispellerCoA.SpellBindKey(spell)
    if spell.id then
        return "id:" .. tostring(spell.id)
    end
    return "name:" .. (spell.name or "")
end

function DispellerCoA.SpellBindLabel(spell)
    local L = DispellerCoA.L
    local types = spell.types and table.concat(spell.types, ", ") or ""
    local extra = ""
    if spell.selfOnly then
        extra = L.DUMP_SELF
    end
    if types ~= "" then
        return spell.name .. " - " .. types .. extra
    end
    return (spell.name or "?") .. extra
end

function DispellerCoA.DetectedSpellChoices()
    local out = {}
    local seen = {}
    local known = DispellerCoA.knownSpells or {}
    local i
    for i = 1, #known do
        local spell = known[i]
        local key = DispellerCoA.SpellBindKey(spell)
        if key ~= "name:" and not seen[key] then
            seen[key] = true
            out[#out + 1] = spell
        end
    end
    return out
end

function DispellerCoA.FindBoundSpell(key)
    if type(key) ~= "string" or key == "auto" or key == "none" then
        return nil
    end
    local id = tonumber(key:match("^id:(%d+)$"))
    local nameKey = key:match("^name:(.+)$")
    local known = DispellerCoA.knownSpells
    local i
    if known then
        for i = 1, #known do
            local spell = known[i]
            if id and spell.id == id then
                return spell
            end
            if nameKey and spell.name == nameKey then
                return spell
            end
        end
    end
    local cat
    if id then
        cat = DispellerCoA.CatalogById[id]
    elseif nameKey then
        cat = DispellerCoA.CatalogByName[nameKey]
    end
    if cat then
        local infoName = (id and GetSpellInfo(id)) or cat.name
        if infoName then
            return {
                id = cat.id or id,
                name = infoName,
                types = cat.types,
                selfOnly = cat.selfOnly,
            }
        end
    end
    if id then
        local infoName = GetSpellInfo(id)
        if infoName then
            return { id = id, name = infoName, types = {} }
        end
    end
    if nameKey then
        return { name = nameKey, types = {} }
    end
    return nil
end

function DispellerCoA.SpellCoversType(spell, typ)
    if not spell or not typ then
        return false
    end
    if spell.types then
        local i
        for i = 1, #spell.types do
            if spell.types[i] == typ then
                return true
            end
        end
    end
    local designated = DispellerCoA.cures and DispellerCoA.cures[typ]
    if designated and spell.name and designated.name == spell.name then
        return true
    end
    return false
end

function DispellerCoA.ResolvedClickSpell(slot, isPlayer)
    local key = DispellerCoA.GetClickBind(slot)
    if key == "none" then
        return nil
    end
    local spell
    if key == "auto" then
        local typ = DispellerCoA.AutoTypeForSlot(slot)
        spell = typ and DispellerCoA.cures and DispellerCoA.cures[typ]
    else
        spell = DispellerCoA.FindBoundSpell(key)
    end
    if not spell or not spell.name then
        return nil
    end
    if spell.selfOnly and not isPlayer then
        return nil
    end
    return spell
end

function DispellerCoA.PickClick(unit, foundTypes)
    if not foundTypes or #foundTypes == 0 then
        return nil, 0, nil
    end
    local isPlayer = unit == "player" or unit == DispellerCoA.playerUnit or UnitIsUnit(unit, "player")
    local order = DispellerCoA.db.typeOrder
    local slots = DispellerCoA.C.CLICK_SLOTS
    local o, f, slot
    for o = 1, #order do
        local typ = order[o]
        local present = false
        for f = 1, #foundTypes do
            if foundTypes[f] == typ then
                present = true
                break
            end
        end
        if present then
            for slot = 1, #slots do
                if DispellerCoA.GetClickBind(slot) == "auto" and DispellerCoA.AutoTypeForSlot(slot) == typ then
                    local spell = DispellerCoA.ResolvedClickSpell(slot, isPlayer)
                    if spell then
                        return typ, slot, spell
                    end
                end
            end
            for slot = 1, #slots do
                if DispellerCoA.GetClickBind(slot) ~= "auto" then
                    local spell = DispellerCoA.ResolvedClickSpell(slot, isPlayer)
                    if DispellerCoA.SpellCoversType(spell, typ) then
                        return typ, slot, spell
                    end
                end
            end
            for slot = 1, #slots do
                local spell = DispellerCoA.ResolvedClickSpell(slot, isPlayer)
                if DispellerCoA.SpellCoversType(spell, typ) then
                    return typ, slot, spell
                end
            end
        end
    end
    return nil, 0, nil
end

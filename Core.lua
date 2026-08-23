DispellerCoA = DispellerCoA or {}

local addon = CreateFrame("Frame", "DispellerCoAEventFrame")
local L

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDispeller_CoA:|r " .. msg)
end

local function MergeDefaults(dst, src)
    local k, v
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                MergeDefaults(dst[k], v)
            else
                dst[k] = v
            end
        elseif type(v) == "table" and type(dst[k]) == "table" then
            MergeDefaults(dst[k], v)
        end
    end
end

local function CharKey()
    return (GetRealmName() or "Realm") .. "-" .. (UnitName("player") or "Player")
end

function DispellerCoA.InitDB()
    DispellerCoADB = DispellerCoADB or {}
    DispellerCoADB.char = DispellerCoADB.char or {}
    local key = CharKey()
    if not DispellerCoADB.char[key] then
        DispellerCoADB.char[key] = DispellerCoA.DefaultDB()
    else
        MergeDefaults(DispellerCoADB.char[key], DispellerCoA.DefaultDB())
    end
    DispellerCoA.db = DispellerCoADB.char[key]
    DispellerCoA.charKey = key
    local db = DispellerCoA.db
    if db.typeEnabled.Bleed == nil then
        db.typeEnabled.Bleed = true
    end
    local hasBleed = false
    local i
    for i = 1, #db.typeOrder do
        if db.typeOrder[i] == "Bleed" then
            hasBleed = true
            break
        end
    end
    if not hasBleed then
        db.typeOrder[#db.typeOrder + 1] = "Bleed"
    end
    if not db.clickBinds then
        db.clickBinds = { "auto", "auto", "auto", "auto", "auto" }
    else
        local slot
        for slot = 1, 5 do
            if not db.clickBinds[slot] or db.clickBinds[slot] == "" then
                db.clickBinds[slot] = "auto"
            end
        end
    end
end

local function AfterScan(playSound)
    local n, prev = DispellerCoA.RecountAfflicted()
    if playSound and DispellerCoA.db.playSound and n > prev then
        PlaySoundFile(DispellerCoA.C.SOUND_AFFLICTED)
    end
    DispellerCoA.UpdateLiveList()
end

function DispellerCoA.FullRefresh(fromSpells)
    DispellerCoA._enabledTypes = DispellerCoA.EnabledCureTypes()
    DispellerCoA.RebuildRoster()
    local n, prev = DispellerCoA.ScanRoster()
    if fromSpells and not DispellerCoA.CanCureAnything() then
        if not DispellerCoA.warnedNoCures then
            Print(L.NO_CURES)
            DispellerCoA.warnedNoCures = true
        end
        DispellerCoA.HideMUFs()
    else
        DispellerCoA.warnedNoCures = false
        DispellerCoA.LayoutMUFs()
    end
    if DispellerCoA.db.playSound and n > prev then
        PlaySoundFile(DispellerCoA.C.SOUND_AFFLICTED)
    end
    DispellerCoA.UpdateLiveList()
end

function DispellerCoA.OnSpellsReady()
    DispellerCoA.DetectCures()
    local loc, token = UnitClass("player")
    DispellerCoA.lastClass = loc
    DispellerCoA.lastClassToken = token
    DispellerCoA.FullRefresh(true)
end

local debounce = CreateFrame("Frame")
debounce:Hide()
debounce.t = 0
debounce:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t >= 0.4 then
        self:Hide()
        self.t = 0
        DispellerCoA.OnSpellsReady()
    end
end)

local function QueueSpellDetect()
    debounce.t = 0
    debounce:Show()
end

local function ResolveAuraUnit(unit)
    if DispellerCoA.unitIndex[unit] then
        return unit
    end
    if unit == "player" and DispellerCoA.playerUnit and DispellerCoA.unitIndex[DispellerCoA.playerUnit] then
        return DispellerCoA.playerUnit
    end
    return nil
end

local rosterEvents = {
    PLAYER_ENTERING_WORLD = true,
    PARTY_MEMBERS_CHANGED = true,
    RAID_ROSTER_UPDATE = true,
    PLAYER_FOCUS_CHANGED = true,
    UNIT_PET = true,
}

local rosterDebounce = CreateFrame("Frame")
rosterDebounce:Hide()
rosterDebounce.t = 0
rosterDebounce:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t >= 0.15 then
        self:Hide()
        self.t = 0
        if DispellerCoA.db then
            DispellerCoA.FullRefresh(false)
        end
    end
end)

local function QueueRoster()
    rosterDebounce.t = 0
    rosterDebounce:Show()
end

addon:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= "Dispeller_CoA" then
            return
        end
        L = DispellerCoA.L
        DispellerCoA.InitDB()
        DispellerCoA.CreateMUFs()
        DispellerCoA.CreateOptions()
        if IsLoggedIn() then
            DispellerCoA.OnSpellsReady()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        DispellerCoA.OnSpellsReady()
        return
    end

    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_TALENT_UPDATE" or event == "CHARACTER_POINTS_CHANGED" then
        QueueSpellDetect()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if DispellerCoA.needLayout or DispellerCoA.needHide or DispellerCoA.needClickMap then
            if DispellerCoA.needClickMap then
                DispellerCoA.RefreshClickMaps()
            end
            DispellerCoA.LayoutMUFs()
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit = ResolveAuraUnit(...)
        if not unit then
            return
        end
        local _, changed = DispellerCoA.ScanUnit(unit)
        if changed then
            local idx = DispellerCoA.unitIndex[unit]
            if idx then
                DispellerCoA.PaintMUF(idx)
            end
            AfterScan(true)
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub = ...
        if sub ~= "SPELL_CAST_FAILED" then
            return
        end
        local sourceGUID = select(3, ...)
        if sourceGUID ~= UnitGUID("player") then
            return
        end
        local failedType = select(12, ...)
        if type(failedType) ~= "string" then
            return
        end
        local low = failedType:lower()
        if not (low:find("sight", 1, true) or low:find("immune", 1, true) or low:find("line", 1, true)) then
            return
        end
        local target = DispellerCoA.lastClickGUID or select(6, ...) or UnitGUID("target")
        if target and target ~= "" then
            DispellerCoA.BlacklistGUID(target)
            PlaySoundFile(DispellerCoA.C.SOUND_FAILED)
            local unit = ResolveAuraUnit("target")
            if not unit then
                -- target may be a roster unit under raidN
                local i
                for i = 1, #DispellerCoA.roster do
                    if DispellerCoA.roster[i].guid == target then
                        unit = DispellerCoA.roster[i].unit
                        break
                    end
                end
            end
            if unit then
                DispellerCoA.ScanUnit(unit)
                local idx = DispellerCoA.unitIndex[unit]
                if idx then
                    DispellerCoA.PaintMUF(idx)
                end
                AfterScan(false)
            end
        end
        return
    end

    if rosterEvents[event] then
        if not DispellerCoA.db then
            return
        end
        if event == "UNIT_PET" and not DispellerCoA.db.showPets then
            return
        end
        QueueRoster()
    end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("SPELLS_CHANGED")
addon:RegisterEvent("LEARNED_SPELL_IN_TAB")
addon:RegisterEvent("PLAYER_TALENT_UPDATE")
addon:RegisterEvent("CHARACTER_POINTS_CHANGED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")
addon:RegisterEvent("UNIT_AURA")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PARTY_MEMBERS_CHANGED")
addon:RegisterEvent("RAID_ROSTER_UPDATE")
addon:RegisterEvent("PLAYER_FOCUS_CHANGED")
addon:RegisterEvent("UNIT_PET")

local function Dump()
    L = L or DispellerCoA.L
    Print(L.DUMP_HEADER)
    Print(L.DUMP_CLASS:format(tostring(DispellerCoA.lastClass), tostring(DispellerCoA.lastClassToken)))
    local i
    for i = 1, #DispellerCoA.C.TYPES do
        local typ = DispellerCoA.C.TYPES[i]
        local spell = DispellerCoA.cures and DispellerCoA.cures[typ]
        if spell then
            local extra = ""
            if spell.override then
                extra = extra .. L.DUMP_OVERRIDE
            end
            if spell.isHoT then
                extra = extra .. L.DUMP_HOT
            end
            if spell.selfOnly then
                extra = extra .. L.DUMP_SELF
            end
            Print(L.DUMP_CURE:format(typ, spell.name, tostring(spell.id or "-"), extra))
        else
            Print("  " .. typ .. " =>" .. L.DUMP_NONE)
        end
    end
    Print("known spells: " .. tostring(DispellerCoA.knownSpells and #DispellerCoA.knownSpells or 0))
    Print("roster: " .. tostring(#DispellerCoA.roster))
end

local function ListNames(which)
    local list = DispellerCoA.db[which]
    if #list == 0 then
        Print(L.LIST_EMPTY:format(which))
        return
    end
    Print(L.LIST_HEADER:format(which))
    local i
    for i = 1, #list do
        Print("  " .. list[i])
    end
end

local function NameFromArg(arg)
    if arg and arg ~= "" then
        return arg
    end
    if UnitExists("target") then
        return UnitName("target")
    end
    return nil
end

SLASH_DISPELLERCOA1 = "/dcoa"
SLASH_DISPELLERCOA2 = "/dispeller"
SlashCmdList.DISPELLERCOA = function(msg)
    L = L or DispellerCoA.L
    msg = msg or ""
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    if cmd == "" or cmd == "options" or cmd == "opt" or cmd == "config" then
        DispellerCoA.OpenOptions()
    elseif cmd == "show" then
        DispellerCoA.db.enabled = true
        DispellerCoA.FullRefresh(false)
    elseif cmd == "hide" then
        DispellerCoA.db.enabled = false
        DispellerCoA.HideMUFs()
        DispellerCoA.UpdateLiveList()
    elseif cmd == "reset" then
        local d = DispellerCoA.DefaultDB()
        DispellerCoA.db.point, DispellerCoA.db.relPoint = d.point, d.relPoint
        DispellerCoA.db.x, DispellerCoA.db.y = d.x, d.y
        DispellerCoA.db.livePoint, DispellerCoA.db.liveRelPoint = d.livePoint, d.liveRelPoint
        DispellerCoA.db.liveX, DispellerCoA.db.liveY = d.liveX, d.liveY
        DispellerCoA.LayoutMUFs()
        DispellerCoA.UpdateLiveList()
        Print(L.RESET)
    elseif cmd == "dump" then
        Dump()
    elseif cmd == "prio" then
        if rest == "list" then
            ListNames("prio")
            return
        end
        local name = NameFromArg(rest)
        if not name then
            Print(L.NEED_TARGET)
            return
        end
        local result = DispellerCoA.ToggleList("prio", name)
        Print((result == "added" and L.ADDED_PRIO or L.REMOVED_PRIO):format(name))
        DispellerCoA.FullRefresh(false)
    elseif cmd == "skip" then
        if rest == "list" then
            ListNames("skip")
            return
        end
        local name = NameFromArg(rest)
        if not name then
            Print(L.NEED_TARGET)
            return
        end
        local result = DispellerCoA.ToggleList("skip", name)
        Print((result == "added" and L.ADDED_SKIP or L.REMOVED_SKIP):format(name))
        DispellerCoA.FullRefresh(false)
    else
        Print(L.USAGE)
    end
end

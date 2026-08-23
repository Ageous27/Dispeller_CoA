DispellerCoA = DispellerCoA or {}

local addon = CreateFrame("Frame", "DispellerCoAEventFrame")
local L

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDispeller_CoA:|r " .. msg)
end

local function CopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    local k, v
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyTable(v)
        else
            dst[k] = v
        end
    end
    return dst
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

function DispellerCoA.ServerName()
    local realm = GetRealmName() or "Realm"
    realm = string.gsub(realm, "%s*%-%s*Conquest of Azeroth", "")
    realm = string.gsub(realm, "Conquest of Azeroth", "")
    realm = string.gsub(realm, "^%s+", "")
    realm = string.gsub(realm, "%s+$", "")
    if realm == "" then
        realm = "Realm"
    end
    return realm
end

function DispellerCoA.DefaultProfileName()
    return DispellerCoA.ServerName() .. " - " .. (UnitName("player") or "Player")
end

function DispellerCoA.CleanProfileLabel(text)
    if type(text) ~= "string" then
        return text
    end
    text = string.gsub(text, "%s*%-%s*Conquest of Azeroth", "")
    text = string.gsub(text, "Conquest of Azeroth%s*%-%s*", "")
    text = string.gsub(text, "Conquest of Azeroth", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.gsub(text, "%s+", " ")
    local server, character = string.match(text, "^(.-)%-([^%-]+)$")
    if server and character then
        server = string.gsub(server, "^%s+", "")
        server = string.gsub(server, "%s+$", "")
        character = string.gsub(character, "^%s+", "")
        character = string.gsub(character, "%s+$", "")
        if server ~= "" and character ~= "" then
            text = server .. " - " .. character
        end
    end
    return text
end

function DispellerCoA.CharKey()
    return DispellerCoA.DefaultProfileName()
end

function DispellerCoA.SanitizeProfileName(name)
    if type(name) ~= "string" then
        return nil
    end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" then
        return nil
    end
    if string.len(name) > 64 then
        name = string.sub(name, 1, 64)
    end
    return name
end

function DispellerCoA.SanitizeProfile(db)
    if not db then
        return
    end
    if db.typeEnabled and db.typeEnabled.Bleed == nil then
        db.typeEnabled.Bleed = true
    end
    if db.typeOrder then
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

function DispellerCoA.ProfileNames()
    local names = {}
    local name
    local profiles = DispellerCoADB and DispellerCoADB.profiles
    if profiles then
        for name in pairs(profiles) do
            names[#names + 1] = name
        end
        table.sort(names)
    end
    return names
end

function DispellerCoA.UniqueProfileName(base)
    base = DispellerCoA.SanitizeProfileName(base) or "Default"
    local profiles = DispellerCoADB.profiles
    if not profiles or not profiles[base] then
        return base
    end
    local i = 2
    while profiles[base .. " " .. tostring(i)] do
        i = i + 1
    end
    return base .. " " .. tostring(i)
end

function DispellerCoA.CharsUsingProfile(name)
    local list = {}
    local key, pname
    local keys = DispellerCoADB and DispellerCoADB.profileKeys
    if keys then
        for key, pname in pairs(keys) do
            if pname == name then
                list[#list + 1] = key
            end
        end
        table.sort(list)
    end
    return list
end

local function BindProfile(name)
    local db = DispellerCoADB.profiles[name]
    if not db then
        return false
    end
    MergeDefaults(db, DispellerCoA.DefaultDB())
    DispellerCoA.SanitizeProfile(db)
    DispellerCoA.db = db
    DispellerCoA.profileName = name
    DispellerCoADB.profileKeys[DispellerCoA.charKey] = name
    return true
end

local function ApplyProfile()
    if DispellerCoA.DetectCures then
        DispellerCoA.DetectCures()
    end
    if DispellerCoA.FullRefresh then
        DispellerCoA.FullRefresh(false)
    end
end

local function IsPrefixName(short, long)
    if type(short) ~= "string" or type(long) ~= "string" then
        return false
    end
    if string.len(short) >= string.len(long) then
        return false
    end
    return string.sub(long, 1, string.len(short)) == short
end

local function RetargetProfile(oldName, newName)
    if not oldName or not newName or oldName == newName then
        return
    end
    newName = DispellerCoA.SanitizeProfileName(newName) or newName
    if DispellerCoADB.profiles[oldName] and not DispellerCoADB.profiles[newName] then
        DispellerCoADB.profiles[newName] = DispellerCoADB.profiles[oldName]
        DispellerCoADB.profiles[oldName] = nil
    end
    local k, v
    for k, v in pairs(DispellerCoADB.profileKeys) do
        if v == oldName then
            DispellerCoADB.profileKeys[k] = newName
        end
    end
    local stillUsed = false
    for k, v in pairs(DispellerCoADB.profileKeys) do
        if v == oldName then
            stillUsed = true
            break
        end
    end
    if not stillUsed then
        DispellerCoADB.profiles[oldName] = nil
    end
end

local function BareProfileName(name)
    if type(name) ~= "string" then
        return name
    end
    return string.gsub(name, " %d+$", "")
end

local function ShouldRepairName(current, wanted)
    if type(current) ~= "string" or type(wanted) ~= "string" or current == wanted then
        return false
    end
    if string.find(current, "Conquest of Azeroth", 1, true) then
        return true
    end
    local bare = BareProfileName(current)
    if IsPrefixName(bare, wanted) then
        return true
    end
    local mashed = string.gsub(wanted, " %- ", "-")
    if current == mashed or IsPrefixName(bare, mashed) then
        return true
    end
    return false
end

function DispellerCoA.InitProfiles()
    DispellerCoADB = DispellerCoADB or {}
    DispellerCoADB.profiles = DispellerCoADB.profiles or {}
    DispellerCoADB.profileKeys = DispellerCoADB.profileKeys or {}

    local key = DispellerCoA.CharKey()
    DispellerCoA.charKey = key

    local player = UnitName("player") or "Player"
    local realm = GetRealmName() or "Realm"
    local oldKeys = {
        realm .. "-" .. player,
        realm .. " - " .. player,
        DispellerCoA.ServerName() .. "-" .. player,
    }
    local oi
    for oi = 1, #oldKeys do
        local oldKey = oldKeys[oi]
        if oldKey ~= key and DispellerCoADB.profileKeys[oldKey] then
            if not DispellerCoADB.profileKeys[key] then
                DispellerCoADB.profileKeys[key] = DispellerCoADB.profileKeys[oldKey]
            end
            DispellerCoADB.profileKeys[oldKey] = nil
        end
    end

    if DispellerCoADB.char then
        local charKey, data
        for charKey, data in pairs(DispellerCoADB.char) do
            if type(data) == "table" then
                local name = DispellerCoA.UniqueProfileName(DispellerCoA.CleanProfileLabel(charKey))
                DispellerCoADB.profiles[name] = data
                DispellerCoADB.profileKeys[charKey] = name
            elseif type(data) == "string" then
                DispellerCoADB.profileKeys[charKey] = DispellerCoA.CleanProfileLabel(data)
            end
        end
        DispellerCoADB.char = nil
    end

    local oldName, _
    local toClean = {}
    for oldName, _ in pairs(DispellerCoADB.profiles) do
        if string.find(oldName, "Conquest of Azeroth", 1, true) then
            toClean[#toClean + 1] = oldName
        end
    end
    local ci
    for ci = 1, #toClean do
        oldName = toClean[ci]
        local newName = DispellerCoA.CleanProfileLabel(oldName)
        if newName ~= oldName then
            RetargetProfile(oldName, newName)
        end
    end

    local keyJobs = {}
    local charKey, pname
    for charKey, pname in pairs(DispellerCoADB.profileKeys) do
        local cleaned = DispellerCoA.CleanProfileLabel(charKey)
        if cleaned and cleaned ~= charKey then
            keyJobs[#keyJobs + 1] = { old = charKey, new = cleaned, pname = pname }
        end
    end
    local ki
    for ki = 1, #keyJobs do
        local job = keyJobs[ki]
        if not DispellerCoADB.profileKeys[job.new] then
            DispellerCoADB.profileKeys[job.new] = job.pname
        end
        if job.old ~= DispellerCoA.charKey then
            DispellerCoADB.profileKeys[job.old] = nil
        end
    end

    local nameJobs = {}
    for charKey, pname in pairs(DispellerCoADB.profileKeys) do
        local wantedName = DispellerCoA.CleanProfileLabel(charKey)
        if ShouldRepairName(pname, wantedName) then
            nameJobs[#nameJobs + 1] = { old = pname, new = wantedName }
        end
    end
    local ni
    for ni = 1, #nameJobs do
        RetargetProfile(nameJobs[ni].old, nameJobs[ni].new)
    end

    local wanted = DispellerCoA.DefaultProfileName()
    local name = DispellerCoADB.profileKeys[key]
    if not name or not DispellerCoADB.profiles[name] then
        name = wanted
        if not DispellerCoADB.profiles[name] then
            name = DispellerCoA.UniqueProfileName(wanted)
            DispellerCoADB.profiles[name] = DispellerCoA.DefaultDB()
        end
        DispellerCoADB.profileKeys[key] = name
    end

    if name ~= wanted then
        local auto = (name == player)
            or (string.find(name, "Conquest of Azeroth", 1, true) ~= nil)
            or (name == realm .. "-" .. player)
            or (name == realm .. " - " .. player)
            or (name == DispellerCoA.ServerName() .. "-" .. player)
            or IsPrefixName(BareProfileName(name), wanted)
        if auto then
            RetargetProfile(name, wanted)
            name = wanted
        end
    end

    BindProfile(name)
end

function DispellerCoA.SelectProfile(name)
    local L = DispellerCoA.L
    if not BindProfile(name) then
        Print(L.PROFILE_MISSING:format(tostring(name)))
        return false
    end
    ApplyProfile()
    Print(L.PROFILE_SELECTED:format(name))
    return true
end

function DispellerCoA.NewProfile(name, copyCurrent)
    local L = DispellerCoA.L
    name = DispellerCoA.SanitizeProfileName(name)
    if not name then
        Print(L.PROFILE_NEED_NAME)
        return false
    end
    if DispellerCoADB.profiles[name] then
        Print(L.PROFILE_EXISTS:format(name))
        return false
    end
    if copyCurrent and DispellerCoA.db then
        DispellerCoADB.profiles[name] = CopyTable(DispellerCoA.db)
    else
        DispellerCoADB.profiles[name] = DispellerCoA.DefaultDB()
    end
    return DispellerCoA.SelectProfile(name)
end

function DispellerCoA.RenameProfile(newName, silent)
    local L = DispellerCoA.L
    local old = DispellerCoA.profileName
    newName = DispellerCoA.SanitizeProfileName(newName)
    if not newName then
        Print(L.PROFILE_NEED_NAME)
        return false
    end
    if not old or not DispellerCoADB.profiles[old] then
        return false
    end
    if newName == old then
        return true
    end
    if DispellerCoADB.profiles[newName] then
        Print(L.PROFILE_EXISTS:format(newName))
        return false
    end
    DispellerCoADB.profiles[newName] = DispellerCoADB.profiles[old]
    DispellerCoADB.profiles[old] = nil
    local k, v
    for k, v in pairs(DispellerCoADB.profileKeys) do
        if v == old then
            DispellerCoADB.profileKeys[k] = newName
        end
    end
    DispellerCoA.profileName = newName
    if not silent then
        Print(L.PROFILE_RENAMED:format(old, newName))
    end
    return true
end

function DispellerCoA.CopyProfileFrom(fromName)
    local L = DispellerCoA.L
    local dest = DispellerCoA.profileName
    local src = DispellerCoADB.profiles[fromName]
    if not dest or not src then
        Print(L.PROFILE_MISSING:format(tostring(fromName)))
        return false
    end
    if fromName == dest then
        return true
    end
    DispellerCoADB.profiles[dest] = CopyTable(src)
    BindProfile(dest)
    ApplyProfile()
    Print(L.PROFILE_COPIED:format(fromName, dest))
    return true
end

function DispellerCoA.ResetProfile()
    local L = DispellerCoA.L
    local name = DispellerCoA.profileName
    if not name then
        return false
    end
    DispellerCoADB.profiles[name] = DispellerCoA.DefaultDB()
    BindProfile(name)
    ApplyProfile()
    Print(L.PROFILE_RESET:format(name))
    return true
end

function DispellerCoA.DeleteProfile(name)
    local L = DispellerCoA.L
    name = DispellerCoA.SanitizeProfileName(name) or name
    if not name or not DispellerCoADB.profiles[name] then
        Print(L.PROFILE_MISSING:format(tostring(name)))
        return false
    end
    local names = DispellerCoA.ProfileNames()
    if #names <= 1 then
        Print(L.PROFILE_LAST)
        return false
    end
    local fallback
    local i
    for i = 1, #names do
        if names[i] ~= name then
            fallback = names[i]
            break
        end
    end
    if not fallback then
        Print(L.PROFILE_LAST)
        return false
    end
    local switch = name == DispellerCoA.profileName
    local k, v
    for k, v in pairs(DispellerCoADB.profileKeys) do
        if v == name then
            DispellerCoADB.profileKeys[k] = fallback
        end
    end
    DispellerCoADB.profiles[name] = nil
    Print(L.PROFILE_DELETED:format(name))
    if switch then
        BindProfile(fallback)
        ApplyProfile()
        Print(L.PROFILE_SELECTED:format(fallback))
    end
    return true
end

function DispellerCoA.InitDB()
    DispellerCoA.InitProfiles()
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
    elseif cmd == "profiles" or cmd == "profile" then
        DispellerCoA.OpenProfileOptions()
    else
        Print(L.USAGE)
    end
end

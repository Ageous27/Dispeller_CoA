-- Rebuilds only on party/raid/focus/pet events. Hot paths read the cached array.

DispellerCoA = DispellerCoA or {}

local UnitExists = UnitExists
local UnitName = UnitName
local UnitGUID = UnitGUID
local GetNumRaidMembers = GetNumRaidMembers
local GetNumPartyMembers = GetNumPartyMembers
local GetRaidRosterInfo = GetRaidRosterInfo

local roster = {}
local unitIndex = {}
local scratch = {}

DispellerCoA.roster = roster
DispellerCoA.unitIndex = unitIndex

local function Trim(n)
    local i
    for i = #roster, n + 1, -1 do
        roster[i] = nil
    end
end

function DispellerCoA.RebuildRoster()
    wipe(unitIndex)
    local saved = roster
    local write = 0
    local function Add(unit, isPet, isFocus)
        if not UnitExists(unit) then
            return
        end
        local name = UnitName(unit)
        if not name or DispellerCoA.IsSkipped(name) then
            return
        end
        if unitIndex[unit] then
            return
        end
        write = write + 1
        local row = saved[write]
        if not row then
            row = {}
            saved[write] = row
        end
        row.unit = unit
        row.name = name
        row.guid = UnitGUID(unit)
        row.isPet = isPet or false
        row.isFocus = isFocus or false
        row.prio = DispellerCoA.PrioIndex(name)
        unitIndex[unit] = write
    end

    local nraid = GetNumRaidMembers()
    if nraid > 0 then
        local myGroup = 1
        local myIndex
        local r
        for r = 1, nraid do
            local name, _, subgroup = GetRaidRosterInfo(r)
            if name and name == UnitName("player") then
                myGroup = subgroup or 1
                myIndex = r
                break
            end
        end

        if myIndex then
            DispellerCoA.playerUnit = "raid" .. myIndex
            Add(DispellerCoA.playerUnit, false, false)
        else
            DispellerCoA.playerUnit = "player"
            Add("player", false, false)
        end

        local scratchN = 0
        for r = 1, nraid do
            if r ~= myIndex then
                local name, _, subgroup = GetRaidRosterInfo(r)
                if name then
                    subgroup = subgroup or 1
                    local order
                    if subgroup == myGroup then
                        order = 0
                    elseif subgroup > myGroup then
                        order = subgroup
                    else
                        order = 8 + subgroup
                    end
                    scratchN = scratchN + 1
                    local row = scratch[scratchN]
                    if not row then
                        row = {}
                        scratch[scratchN] = row
                    end
                    row.r, row.order, row.prio, row.name, row.p = r, order, DispellerCoA.PrioIndex(name), name, nil
                end
            end
        end
        for i = #scratch, scratchN + 1, -1 do
            scratch[i] = nil
        end
        table.sort(scratch, function(a, b)
            if a.prio ~= b.prio then
                return a.prio < b.prio
            end
            if a.order ~= b.order then
                return a.order < b.order
            end
            return a.r < b.r
        end)
        for i = 1, #scratch do
            Add("raid" .. scratch[i].r, false, false)
        end

        if DispellerCoA.db.showPets then
            Add("pet", true, false)
            for r = 1, nraid do
                Add("raidpet" .. r, true, false)
            end
        end
    else
        DispellerCoA.playerUnit = "player"
        Add("player", false, false)
        local nparty = GetNumPartyMembers()
        local p
        local scratchN = 0
        for p = 1, nparty do
            local unit = "party" .. p
            local name = UnitName(unit)
            if name then
                scratchN = scratchN + 1
                local row = scratch[scratchN]
                if not row then
                    row = {}
                    scratch[scratchN] = row
                end
                row.p, row.prio, row.name, row.r, row.order = p, DispellerCoA.PrioIndex(name), name, nil, nil
            end
        end
        for i = #scratch, scratchN + 1, -1 do
            scratch[i] = nil
        end
        table.sort(scratch, function(a, b)
            if a.prio ~= b.prio then
                return a.prio < b.prio
            end
            return a.p < b.p
        end)
        for i = 1, #scratch do
            Add("party" .. scratch[i].p, false, false)
        end
        if DispellerCoA.db.showPets then
            Add("pet", true, false)
            for p = 1, nparty do
                Add("partypet" .. p, true, false)
            end
        end
    end

    if UnitExists("focus") then
        Add("focus", false, true)
    end

    Trim(write)
    DispellerCoA.rosterDirty = false
    return roster
end

DispellerCoA = DispellerCoA or {}

local strlower = string.lower

local function Norm(name)
    if not name or name == "" then
        return nil
    end
    return strlower(name)
end

local function ListHas(list, name)
    name = Norm(name)
    if not name then
        return false
    end
    local i
    for i = 1, #list do
        if list[i] == name then
            return true, i
        end
    end
    return false
end

function DispellerCoA.IsSkipped(name)
    return ListHas(DispellerCoA.db.skip, name)
end

function DispellerCoA.IsPrio(name)
    return ListHas(DispellerCoA.db.prio, name)
end

function DispellerCoA.PrioIndex(name)
    local ok, i = ListHas(DispellerCoA.db.prio, name)
    if ok then
        return i
    end
    return 1000
end

local function Add(list, name)
    name = Norm(name)
    if not name then
        return false
    end
    if ListHas(list, name) then
        return false
    end
    list[#list + 1] = name
    return true
end

local function Remove(list, name)
    local ok, i = ListHas(list, name)
    if not ok then
        return false
    end
    table.remove(list, i)
    return true
end

function DispellerCoA.AddPrio(name)
    return Add(DispellerCoA.db.prio, name)
end

function DispellerCoA.RemovePrio(name)
    return Remove(DispellerCoA.db.prio, name)
end

function DispellerCoA.AddSkip(name)
    return Add(DispellerCoA.db.skip, name)
end

function DispellerCoA.RemoveSkip(name)
    return Remove(DispellerCoA.db.skip, name)
end

function DispellerCoA.ToggleList(which, name)
    local list = DispellerCoA.db[which]
    if ListHas(list, name) then
        Remove(list, name)
        return "removed"
    end
    Add(list, name)
    return "added"
end

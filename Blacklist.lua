DispellerCoA = DispellerCoA or {}

local GetTime = GetTime
local blacklist = {}
local count = 0

function DispellerCoA.BlacklistGUID(guid)
    if not guid then
        return
    end
    local untilTime = GetTime() + (DispellerCoA.db.blacklistSeconds or 8)
    if not blacklist[guid] then
        count = count + 1
    end
    blacklist[guid] = untilTime
end

function DispellerCoA.IsBlacklisted(guid)
    if not guid or count == 0 then
        return false
    end
    local untilTime = blacklist[guid]
    if not untilTime then
        return false
    end
    if untilTime <= GetTime() then
        blacklist[guid] = nil
        count = count - 1
        return false
    end
    return true
end

function DispellerCoA.ClearBlacklist()
    wipe(blacklist)
    count = 0
end

function DispellerCoA.BlacklistCount()
    return count
end

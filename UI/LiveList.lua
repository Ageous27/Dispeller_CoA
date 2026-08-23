-- Compact afflicted strip. Rebuilds text only when the afflicted set changes.

DispellerCoA = DispellerCoA or {}

local CreateFrame = CreateFrame
local UnitName = UnitName

local rows = {}
local lastKey = ""
local MAX_ROWS = 10

local function EnsureFrame()
    local f = DispellerCoA_LiveList
    if f then
        return f
    end
    f = CreateFrame("Frame", "DispellerCoA_LiveList", UIParent)
    f:SetWidth(180)
    f:SetHeight(16)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("MEDIUM")
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.35)
    f.bg = bg
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() and not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        local db = DispellerCoA.db
        db.livePoint, db.liveRelPoint, db.liveX, db.liveY = point, rel, x, y
    end)
    local i
    for i = 1, MAX_ROWS do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -2 - (i - 1) * 12)
        fs:SetJustifyH("LEFT")
        fs:Hide()
        rows[i] = fs
    end
    return f
end

function DispellerCoA.UpdateLiveList()
    local f = EnsureFrame()
    local db = DispellerCoA.db
    if not db.showLiveList or not db.enabled then
        f:Hide()
        lastKey = ""
        return
    end

    f:ClearAllPoints()
    f:SetPoint(db.livePoint or "CENTER", UIParent, db.liveRelPoint or "CENTER", db.liveX or 180, db.liveY or -80)

    local list = DispellerCoA.roster
    local parts = {}
    local shown = 0
    local i
    for i = 1, #list do
        local unit = list[i].unit
        local s = DispellerCoA.unitStatus[unit]
        if s and s.state == DispellerCoA.C.STATUS.AFFLICTED then
            shown = shown + 1
            if shown <= MAX_ROWS then
                parts[shown] = (UnitName(unit) or unit) .. ":" .. (s.clickType or "?")
            end
        end
    end

    local key = table.concat(parts, "|")
    if key == lastKey and f:IsShown() then
        return
    end
    lastKey = key

    if shown == 0 then
        f:Hide()
        return
    end

    local n = shown
    if n > MAX_ROWS then
        n = MAX_ROWS
    end
    f:SetHeight(4 + n * 12)
    for i = 1, MAX_ROWS do
        if i <= n then
            rows[i]:SetText(parts[i])
            rows[i]:Show()
        elseif rows[i]:IsShown() then
            rows[i]:Hide()
        end
    end
    f:Show()
end

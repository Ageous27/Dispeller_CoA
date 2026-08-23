-- Precreated secure buttons. Attributes written only when they change and only out of combat.

DispellerCoA = DispellerCoA or {}

local InCombatLockdown = InCombatLockdown
local UnitName = UnitName
local CreateFrame = CreateFrame

local buttons = {}
local COLS = 5
local pulseElapsed = 0
local PULSE = 0.18

local function SetAttr(btn, key, value)
    if btn._attr[key] ~= value then
        btn:SetAttribute(key, value)
        btn._attr[key] = value
    end
end

local function SetColor(btn, r, g, b, a)
    local c = btn._color
    if c[1] == r and c[2] == g and c[3] == b and c[4] == a then
        return
    end
    c[1], c[2], c[3], c[4] = r, g, b, a
    if btn.bg then
        -- Solid color on ARTWORK so the dark border cannot mute it.
        btn.bg:SetTexture(r, g, b)
        btn.bg:SetVertexColor(1, 1, 1, a)
    end
end

local function EnsureTextures(btn)
    if not btn.bg then
        local bg = btn:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints()
        bg:SetTexture(1, 1, 1)
        btn.bg = bg
    else
        btn.bg:SetDrawLayer("ARTWORK")
        btn.bg:SetTexture(1, 1, 1)
    end
    if not btn.border then
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetTexture(1, 1, 1)
        border:SetVertexColor(0.05, 0.05, 0.05, 0.90)
        btn.border = border
    end
    if not btn.cd then
        local cd = btn:CreateTexture(nil, "OVERLAY")
        cd:SetWidth(8)
        cd:SetHeight(8)
        cd:SetPoint("CENTER")
        cd:SetTexture(1, 1, 1)
        cd:SetVertexColor(0, 0, 0, 0.55)
        cd:Hide()
        btn.cd = cd
    else
        btn.cd:SetTexture(1, 1, 1)
        btn.cd:SetVertexColor(0, 0, 0, 0.55)
    end
end

local function ApplyClickMap(btn)
    local slots = DispellerCoA.C.CLICK_SLOTS
    local unit = btn.unit
    local isPlayer = unit and (unit == "player" or unit == DispellerCoA.playerUnit)
    local i
    for i = 1, #slots do
        local slot = slots[i]
        local prefix = slot.mod
        local n = slot.button
        local spell = DispellerCoA.ResolvedClickSpell(i, isPlayer)
        if spell then
            SetAttr(btn, prefix .. "type" .. n, "spell")
            SetAttr(btn, prefix .. "spell" .. n, spell.name)
        else
            SetAttr(btn, prefix .. "type" .. n, nil)
            SetAttr(btn, prefix .. "spell" .. n, nil)
        end
    end
    SetAttr(btn, "type3", "target")
    SetAttr(btn, "ctrl-type3", "focus")
end

function DispellerCoA.CreateMUFs()
    local parent = DispellerCoA_MUFContainer
    local max = DispellerCoA.C.MAX_MUFS
    local i
    for i = 1, max do
        local btn = CreateFrame("Button", "DispellerCoAMUF" .. i, parent, "SecureActionButtonTemplate")
        btn:SetWidth(20)
        btn:SetHeight(20)
        btn:RegisterForClicks("AnyUp")
        btn:EnableMouse(true)
        btn._attr = {}
        btn._color = { -1, -1, -1, -1 }
        EnsureTextures(btn)
        btn:Hide()
        btn:SetScript("OnEnter", function(self)
            if not self.unit then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local name = UnitName(self.unit) or self.unit
            local s = DispellerCoA.unitStatus[self.unit]
            if s and s.clickType then
                GameTooltip:SetText(name .. "  " .. s.clickType, 1, 1, 1)
            else
                GameTooltip:SetText(name, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:SetScript("PreClick", function(self)
            if self.unit then
                DispellerCoA.lastClickGUID = UnitGUID(self.unit)
            end
        end)
        buttons[i] = btn
    end
    DispellerCoA.mufs = buttons

    local handle = DispellerCoA_MUFHandle
    local handleBg = _G["DispellerCoA_MUFHandleBg"]
    if handleBg then
        handleBg:SetTexture(1, 1, 1)
        handleBg:SetVertexColor(0.06, 0.06, 0.06, 0.95)
    end
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsAltKeyDown() and not InCombatLockdown() then
            parent:StartMoving()
        end
    end)
    handle:SetScript("OnMouseUp", function()
        parent:StopMovingOrSizing()
        local point, _, rel, x, y = parent:GetPoint()
        local db = DispellerCoA.db
        db.point, db.relPoint, db.x, db.y = point, rel, x, y
    end)

    parent:SetScript("OnUpdate", function(_, elapsed)
        if (DispellerCoA.afflictedCount or 0) == 0 then
            pulseElapsed = 0
            return
        end
        pulseElapsed = pulseElapsed + elapsed
        if pulseElapsed < PULSE then
            return
        end
        pulseElapsed = 0
        DispellerCoA.PulseMUFs()
    end)
end

function DispellerCoA.LayoutMUFs()
    if InCombatLockdown() then
        DispellerCoA.needLayout = true
        return
    end
    local db = DispellerCoA.db
    local parent = DispellerCoA_MUFContainer
    if not db.enabled or not DispellerCoA.CanCureAnything() then
        parent:Hide()
        return
    end

    parent:ClearAllPoints()
    parent:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 180, db.y or 80)

    local size = db.mufSize or 20
    local gap = db.mufSpacing or 2
    local maxShow = db.maxMUFs or 25
    local list = DispellerCoA.roster
    local n = #list
    if n > maxShow then
        n = maxShow
    end

    local rows = math.ceil(n / COLS)
    if rows < 1 then
        rows = 1
    end
    local cols = n
    if cols > COLS then
        cols = COLS
    end
    if cols < 1 then
        cols = 1
    end
    parent:SetWidth(cols * (size + gap) + 4)
    parent:SetHeight(rows * (size + gap) + 16)
    DispellerCoA_MUFHandle:SetWidth(size)
    DispellerCoA_MUFHandle:SetHeight(10)

    local i
    for i = 1, #buttons do
        local btn = buttons[i]
        if i <= n then
            local unit = list[i].unit
            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            btn:SetWidth(size)
            btn:SetHeight(size)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", col * (size + gap), -12 - row * (size + gap))
            btn.unit = unit
            SetAttr(btn, "unit", unit)
            ApplyClickMap(btn)
            btn:Show()
        else
            btn.unit = nil
            SetAttr(btn, "unit", nil)
            btn:Hide()
        end
    end
    parent:Show()
    DispellerCoA.needLayout = false
    DispellerCoA.ApplyMUFOpacity()
    DispellerCoA.PaintMUFs()
end

local function IdleAlpha()
    local pct = DispellerCoA.db and DispellerCoA.db.mufOpacity or 80
    if pct < 15 then
        pct = 15
    elseif pct > 100 then
        pct = 100
    end
    return pct / 100
end

function DispellerCoA.ApplyMUFOpacity()
    DispellerCoA.PaintMUFs()
end

function DispellerCoA.RefreshClickMaps()
    if InCombatLockdown() then
        DispellerCoA.needClickMap = true
        return
    end
    local i
    for i = 1, #buttons do
        if buttons[i]:IsShown() then
            ApplyClickMap(buttons[i])
        end
    end
    DispellerCoA.needClickMap = false
end

local function ColorFor(s)
    local C = DispellerCoA.C
    if s.state == C.STATUS.MISSING then
        return C.COLOR_GONE[1], C.COLOR_GONE[2], C.COLOR_GONE[3], 0.55
    end
    if s.state == C.STATUS.BLACKLISTED then
        return C.COLOR_BLACK[1], C.COLOR_BLACK[2], C.COLOR_BLACK[3], 0.90
    end
    if s.state == C.STATUS.FAR then
        return C.COLOR_FAR[1], C.COLOR_FAR[2], C.COLOR_FAR[3], 0.45
    end
    if s.state == C.STATUS.AFFLICTED then
        local pal = C.CLICK_COLORS[s.clickSlot] or C.CLICK_COLORS[1]
        return pal[1], pal[2], pal[3], 1
    end
    return C.COLOR_CLEAR[1], C.COLOR_CLEAR[2], C.COLOR_CLEAR[3], 0.80
end

function DispellerCoA.PaintMUF(i)
    local btn = buttons[i]
    if not btn or not btn:IsShown() or not btn.unit then
        return
    end
    local s = DispellerCoA.unitStatus[btn.unit]
    local r, g, b, a
    if s then
        r, g, b, a = ColorFor(s)
    else
        local C = DispellerCoA.C
        r, g, b, a = C.COLOR_CLEAR[1], C.COLOR_CLEAR[2], C.COLOR_CLEAR[3], 0.80
    end
    SetColor(btn, r, g, b, a)
    if s and s.state == DispellerCoA.C.STATUS.AFFLICTED then
        btn:SetAlpha(1)
    else
        btn:SetAlpha(IdleAlpha())
    end
    if btn.cd then
        if s and s.onCD then
            if not btn.cd:IsShown() then
                btn.cd:Show()
            end
        elseif btn.cd:IsShown() then
            btn.cd:Hide()
        end
    end
end

function DispellerCoA.PaintMUFs()
    local i
    for i = 1, #buttons do
        if buttons[i]:IsShown() then
            DispellerCoA.PaintMUF(i)
        end
    end
end

function DispellerCoA.PulseMUFs()
    local list = DispellerCoA.roster
    local i
    for i = 1, #list do
        local unit = list[i].unit
        local s = DispellerCoA.unitStatus[unit]
        if s and s.state == DispellerCoA.C.STATUS.AFFLICTED then
            DispellerCoA.ScanUnit(unit)
            DispellerCoA.PaintMUF(i)
        end
    end
end

function DispellerCoA.HideMUFs()
    if InCombatLockdown() then
        DispellerCoA.needHide = true
        return
    end
    DispellerCoA_MUFContainer:Hide()
end

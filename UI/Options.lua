DispellerCoA = DispellerCoA or {}

local function Refresh()
    DispellerCoA._enabledTypes = DispellerCoA.EnabledCureTypes()
    DispellerCoA.RebuildRoster()
    DispellerCoA.ScanRoster()
    DispellerCoA.LayoutMUFs()
    DispellerCoA.UpdateLiveList()
end

local optIndex = 0
local function NextName(prefix)
    optIndex = optIndex + 1
    return "DispellerCoAOpt" .. prefix .. optIndex
end

local function Check(parent, label, getter, setter, y)
    local cb = CreateFrame("CheckButton", NextName("CB"), parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnShow", function(self)
        self:SetChecked(getter())
    end)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        Refresh()
    end)
    return cb
end

local function Slider(parent, label, minV, maxV, step, getter, setter, y, skipRefresh)
    local s = CreateFrame("Slider", NextName("SL"), parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", 24, y)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetWidth(200)
    _G[s:GetName() .. "Text"]:SetText(label)
    _G[s:GetName() .. "Low"]:SetText(tostring(minV))
    _G[s:GetName() .. "High"]:SetText(tostring(maxV))
    s:SetScript("OnShow", function(self)
        self:SetValue(getter())
    end)
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        if getter() ~= value then
            setter(value)
            if not skipRefresh then
                Refresh()
            end
        end
    end)
    return s
end

function DispellerCoA.CreateOptions()
    local L = DispellerCoA.L
    local panel = CreateFrame("Frame", "DispellerCoAOptions", UIParent)
    panel.name = "Dispeller_CoA"
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.ADDON)

    Check(panel, L.ENABLE, function()
        return DispellerCoA.db.enabled
    end, function(v)
        DispellerCoA.db.enabled = v
    end, -44)

    Check(panel, L.SHOW_PETS, function()
        return DispellerCoA.db.showPets
    end, function(v)
        DispellerCoA.db.showPets = v
    end, -72)

    Check(panel, L.SHOW_LIVE, function()
        return DispellerCoA.db.showLiveList
    end, function(v)
        DispellerCoA.db.showLiveList = v
    end, -100)

    Check(panel, L.PLAY_SOUND, function()
        return DispellerCoA.db.playSound
    end, function(v)
        DispellerCoA.db.playSound = v
    end, -128)

    Slider(panel, L.BLACKLIST, 2, 30, 1, function()
        return DispellerCoA.db.blacklistSeconds
    end, function(v)
        DispellerCoA.db.blacklistSeconds = v
    end, -176)

    Slider(panel, L.MUF_SIZE, 12, 36, 1, function()
        return DispellerCoA.db.mufSize
    end, function(v)
        DispellerCoA.db.mufSize = v
    end, -224)

    Slider(panel, L.MUF_OPACITY, 15, 100, 5, function()
        return DispellerCoA.db.mufOpacity or 80
    end, function(v)
        DispellerCoA.db.mufOpacity = v
        DispellerCoA.ApplyMUFOpacity()
    end, -272, true)

    Slider(panel, L.MUF_SPACING, 0, 8, 1, function()
        return DispellerCoA.db.mufSpacing
    end, function(v)
        DispellerCoA.db.mufSpacing = v
    end, -320)

    Slider(panel, L.MAX_MUFS, 5, 40, 1, function()
        return DispellerCoA.db.maxMUFs
    end, function(v)
        DispellerCoA.db.maxMUFs = v
    end, -368)

    local typeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", 16, -408)
    typeLabel:SetText(L.ENABLED_TYPES)

    local types = DispellerCoA.C.TYPES
    local i
    for i = 1, #types do
        local typ = types[i]
        Check(panel, typ, function()
            return DispellerCoA.db.typeEnabled[typ]
        end, function(v)
            DispellerCoA.db.typeEnabled[typ] = v
        end, -420 - (i * 24))
    end

    local orderY = -572
    local orderLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    orderLabel:SetPoint("TOPLEFT", 16, orderY)
    orderLabel:SetText(L.TYPE_ORDER)

    local orderFS = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    orderFS:SetPoint("TOPLEFT", 16, orderY - 20)

    local function DrawOrder()
        orderFS:SetText(table.concat(DispellerCoA.db.typeOrder, "  >  "))
    end
    panel:SetScript("OnShow", DrawOrder)

    local up = CreateFrame("Button", NextName("Btn"), panel, "UIPanelButtonTemplate")
    up:SetWidth(60)
    up:SetHeight(22)
    up:SetPoint("TOPLEFT", 16, orderY - 44)
    up:SetText(L.MOVE_UP)
    up:SetScript("OnClick", function()
        local o = DispellerCoA.db.typeOrder
        if o[1] then
            local last = table.remove(o)
            table.insert(o, 1, last)
            DrawOrder()
            Refresh()
        end
    end)

    local down = CreateFrame("Button", NextName("Btn"), panel, "UIPanelButtonTemplate")
    down:SetWidth(70)
    down:SetHeight(22)
    down:SetPoint("LEFT", up, "RIGHT", 8, 0)
    down:SetText(L.MOVE_DOWN)
    down:SetScript("OnClick", function()
        local o = DispellerCoA.db.typeOrder
        if o[1] then
            local first = table.remove(o, 1)
            o[#o + 1] = first
            DrawOrder()
            Refresh()
        end
    end)

    InterfaceOptions_AddCategory(panel)
    DispellerCoA.optionsPanel = panel
    DispellerCoA.CreateClickOptions(panel)
end

local CLICK_LABELS = {
    "CLICK_LEFT",
    "CLICK_RIGHT",
    "CLICK_SHIFT_LEFT",
    "CLICK_SHIFT_RIGHT",
    "CLICK_CTRL_LEFT",
}

function DispellerCoA.ClickBindText(slot)
    local L = DispellerCoA.L
    local key = DispellerCoA.GetClickBind(slot)
    if key == "none" then
        return L.CLICK_NONE
    end
    if key ~= "auto" then
        local spell = DispellerCoA.FindBoundSpell(key)
        if spell and spell.name then
            return spell.name
        end
        return L.CLICK_MISSING
    end
    local typ = DispellerCoA.AutoTypeForSlot(slot)
    local spell = typ and DispellerCoA.cures and DispellerCoA.cures[typ]
    if spell and spell.name then
        return L.CLICK_AUTO_SPELL:format(spell.name)
    end
    return L.CLICK_AUTO_NONE
end

local function RefreshClicks()
    DispellerCoA._enabledTypes = DispellerCoA.EnabledCureTypes()
    DispellerCoA.RefreshClickMaps()
    DispellerCoA.ScanRoster()
    DispellerCoA.PaintMUFs()
    DispellerCoA.UpdateLiveList()
end

function DispellerCoA.CreateClickOptions(parentPanel)
    local L = DispellerCoA.L
    local child = CreateFrame("Frame", "DispellerCoAClickOptions", UIParent)
    child.name = L.CLICKS
    child.parent = parentPanel.name
    child:Hide()

    local title = child:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L.CLICKS)

    local help = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 16, -40)
    help:SetPoint("RIGHT", child, "RIGHT", -16, 0)
    help:SetJustifyH("LEFT")
    help:SetText(L.CLICKS_HELP)

    local fixed = child:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fixed:SetPoint("TOPLEFT", 16, -68)
    fixed:SetText(L.CLICK_FIXED)

    local dropdowns = {}
    local i
    for i = 1, #CLICK_LABELS do
        local slot = i
        local y = -88 - ((i - 1) * 36)
        local label = child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 16, y)
        label:SetWidth(110)
        label:SetJustifyH("LEFT")
        label:SetText(L[CLICK_LABELS[i]])

        local dd = CreateFrame("Frame", "DispellerCoAClickDD" .. i, child, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", 120, y + 8)
        dd.slot = slot
        UIDropDownMenu_SetWidth(dd, 220)
        UIDropDownMenu_JustifyText(dd, "LEFT")
        dropdowns[i] = dd

        local function InitMenu()
            local info = UIDropDownMenu_CreateInfo()
            info.text = L.CLICK_AUTO
            info.value = "auto"
            info.func = function()
                DispellerCoA.SetClickBind(slot, "auto")
                UIDropDownMenu_SetText(dd, DispellerCoA.ClickBindText(slot))
                RefreshClicks()
            end
            info.checked = DispellerCoA.GetClickBind(slot) == "auto"
            UIDropDownMenu_AddButton(info)

            info = UIDropDownMenu_CreateInfo()
            info.text = L.CLICK_NONE
            info.value = "none"
            info.func = function()
                DispellerCoA.SetClickBind(slot, "none")
                UIDropDownMenu_SetText(dd, DispellerCoA.ClickBindText(slot))
                RefreshClicks()
            end
            info.checked = DispellerCoA.GetClickBind(slot) == "none"
            UIDropDownMenu_AddButton(info)

            local choices = DispellerCoA.DetectedSpellChoices()
            local c
            for c = 1, #choices do
                local spell = choices[c]
                local key = DispellerCoA.SpellBindKey(spell)
                info = UIDropDownMenu_CreateInfo()
                info.text = DispellerCoA.SpellBindLabel(spell)
                info.value = key
                info.func = function()
                    DispellerCoA.SetClickBind(slot, key)
                    UIDropDownMenu_SetText(dd, DispellerCoA.ClickBindText(slot))
                    RefreshClicks()
                end
                info.checked = DispellerCoA.GetClickBind(slot) == key
                UIDropDownMenu_AddButton(info)
            end
        end
        dd.rebuild = InitMenu
        UIDropDownMenu_Initialize(dd, InitMenu)
    end

    local reset = CreateFrame("Button", NextName("Btn"), child, "UIPanelButtonTemplate")
    reset:SetWidth(120)
    reset:SetHeight(22)
    reset:SetPoint("TOPLEFT", 16, -276)
    reset:SetText(L.CLICK_RESET)
    reset:SetScript("OnClick", function()
        local slot
        for slot = 1, 5 do
            DispellerCoA.SetClickBind(slot, "auto")
        end
        child.refresh()
        RefreshClicks()
    end)

    local detLabel = child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detLabel:SetPoint("TOPLEFT", 16, -312)
    detLabel:SetText(L.CLICK_DETECTED)

    local detFS = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detFS:SetPoint("TOPLEFT", 16, -332)
    detFS:SetPoint("RIGHT", child, "RIGHT", -16, 0)
    detFS:SetJustifyH("LEFT")

    function child.refresh()
        local slot
        for slot = 1, #dropdowns do
            UIDropDownMenu_Initialize(dropdowns[slot], dropdowns[slot].rebuild)
            UIDropDownMenu_SetText(dropdowns[slot], DispellerCoA.ClickBindText(slot))
        end
        local choices = DispellerCoA.DetectedSpellChoices()
        if #choices == 0 then
            detFS:SetText(L.CLICK_NO_SPELLS)
        else
            local lines = {}
            local c
            for c = 1, #choices do
                lines[c] = "  " .. DispellerCoA.SpellBindLabel(choices[c])
            end
            detFS:SetText(table.concat(lines, "\n"))
        end
    end

    child:SetScript("OnShow", child.refresh)

    InterfaceOptions_AddCategory(child)
    DispellerCoA.clickOptionsPanel = child
end

function DispellerCoA.OpenOptions()
    InterfaceOptionsFrame_OpenToCategory("Dispeller_CoA")
end

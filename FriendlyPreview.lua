-- BattleMender - detached friendly preview controls.
--
-- This file intentionally wraps the existing Defensives preview renderer rather
-- than reimplementing friendly plate artwork. The renderer remains the single
-- source of truth; this module only gives it a draggable host/control surface.

BattleMender = BattleMender or {}
local BM = BattleMender
local CFG = BM.CFG or {}
local Defensives = BM.Defensives

if not Defensives then return end

local LegacyShowPreview = Defensives.ShowPreview
local LegacyHidePreview = Defensives.HidePreview
local LegacyUpdatePreview = Defensives.UpdatePreview

if type(LegacyShowPreview) ~= "function"
    or type(LegacyHidePreview) ~= "function"
    or type(LegacyUpdatePreview) ~= "function"
then
    return
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local PREVIEW_WINDOW_NAME = "BattleMenderFriendlyPreviewWindow"
local window
local syncingControls = false

local CLASS_ORDER = {
    { id = 1,  file = "WARRIOR",      name = "Warrior" },
    { id = 2,  file = "PALADIN",      name = "Paladin" },
    { id = 3,  file = "HUNTER",       name = "Hunter" },
    { id = 4,  file = "ROGUE",        name = "Rogue" },
    { id = 5,  file = "PRIEST",       name = "Priest" },
    { id = 6,  file = "DEATHKNIGHT",  name = "Death Knight" },
    { id = 7,  file = "SHAMAN",       name = "Shaman" },
    { id = 8,  file = "MAGE",         name = "Mage" },
    { id = 9,  file = "WARLOCK",      name = "Warlock" },
    { id = 10, file = "MONK",         name = "Monk" },
    { id = 11, file = "DRUID",        name = "Druid" },
    { id = 12, file = "DEMONHUNTER",  name = "Demon Hunter" },
    { id = 13, file = "EVOKER",       name = "Evoker" },
}

local CLASS_BY_FILE = {}
for index, info in ipairs(CLASS_ORDER) do
    CLASS_BY_FILE[info.file] = index
    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[info.file] then
        info.name = LOCALIZED_CLASS_NAMES_MALE[info.file]
    end
end

local AURA_ORDER = { "NONE", "MAJOR", "IMMUNITY", "BOTH" }
local AURA_LABELS = {
    NONE = "None",
    MAJOR = "Major Defensive",
    IMMUNITY = "Immunity",
    BOTH = "Major + Immunity",
}

local OBJECTIVE_ORDER = {
    "NONE",
    "FLAG_HORDE", "FLAG_ALLIANCE", "FLAG_NEUTRAL",
    "ORB_BLUE", "ORB_GREEN", "ORB_ORANGE", "ORB_PURPLE",
    "CART_HORDE", "CART_ALLIANCE",
    "BOUNTY_HORDE", "BOUNTY_ALLIANCE",
}
local OBJECTIVE_LABELS = {
    NONE = "None",
    FLAG_HORDE = "Horde Flag",
    FLAG_ALLIANCE = "Alliance Flag",
    FLAG_NEUTRAL = "Neutral Flag",
    ORB_BLUE = "Blue Orb",
    ORB_GREEN = "Green Orb",
    ORB_ORANGE = "Orange Orb",
    ORB_PURPLE = "Purple Orb",
    CART_HORDE = "Horde Cart",
    CART_ALLIANCE = "Alliance Cart",
    BOUNTY_HORDE = "Horde Bounty",
    BOUNTY_ALLIANCE = "Alliance Bounty",
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function NotifyOptionsChanged()
    if not LibStub then return end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry and registry.NotifyChange then
        pcall(registry.NotifyChange, registry, "BattleMender")
    end
end

local function SavePreviewState()
    if BM.SaveDB then BM.SaveDB() end
    NotifyOptionsChanged()
end

local function GetSpecializationCount(classID)
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        local ok, count = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
        if ok and type(count) == "number" then return count end
    end
    if GetNumSpecializationsForClassID then
        local ok, count = pcall(GetNumSpecializationsForClassID, classID)
        if ok and type(count) == "number" then return count end
    end
    return 0
end

local function GetClassSpecs(classInfo)
    local out = {}
    if not classInfo then return out end

    local count = GetSpecializationCount(classInfo.id)
    for index = 1, count do
        local id, name, _, icon, role
        if GetSpecializationInfoForClassID then
            local ok
            ok, id, name, _, icon, role = pcall(GetSpecializationInfoForClassID, classInfo.id, index)
            if not ok then id = nil end
        end

        if not id and C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            local ok
            ok, id, name, _, icon, role = pcall(
                C_SpecializationInfo.GetSpecializationInfo,
                index, false, false, nil, nil, nil, classInfo.id
            )
            if not ok then id = nil end
        end

        if type(id) == "number" and id > 0 then
            out[#out + 1] = {
                id = id,
                name = name or ("Spec " .. tostring(id)),
                icon = icon,
                role = role or "DAMAGER",
            }
        end
    end

    return out
end

local function GetSelectedClassIndex()
    local file = tostring(CFG.friendlyTestClass or "")
    local index = CLASS_BY_FILE[file]
    if index then return index end

    local specID = tonumber(CFG.friendlyTestSpecID)
    if specID and C_SpecializationInfo and C_SpecializationInfo.GetClassIDFromSpecID then
        local ok, classID = pcall(C_SpecializationInfo.GetClassIDFromSpecID, specID)
        if ok and classID then
            for i, info in ipairs(CLASS_ORDER) do
                if info.id == classID then return i end
            end
        end
    end

    return 1
end

local function GetSelectedSpec(classInfo)
    local specs = GetClassSpecs(classInfo)
    local selectedID = tonumber(CFG.friendlyTestSpecID)
    for index, spec in ipairs(specs) do
        if spec.id == selectedID then
            return specs, index, spec
        end
    end
    return specs, (#specs > 0 and 1 or nil), specs[1]
end

local function SetPreviewClass(classIndex, preserveRole)
    local info = CLASS_ORDER[classIndex]
    if not info then return end

    local oldRole
    if preserveRole then
        local oldClass = CLASS_ORDER[GetSelectedClassIndex()]
        local _, _, oldSpec = GetSelectedSpec(oldClass)
        oldRole = oldSpec and oldSpec.role
    end

    local specs = GetClassSpecs(info)
    local chosen = specs[1]
    if oldRole then
        for _, spec in ipairs(specs) do
            if spec.role == oldRole then
                chosen = spec
                break
            end
        end
    end

    CFG.friendlyTestClass = info.file
    if chosen then CFG.friendlyTestSpecID = chosen.id end
end

local function StepPreviewClass(delta)
    local count = #CLASS_ORDER
    local current = GetSelectedClassIndex()
    local nextIndex = ((current - 1 + delta) % count) + 1
    SetPreviewClass(nextIndex, true)
end

local function StepPreviewSpec(delta)
    local classInfo = CLASS_ORDER[GetSelectedClassIndex()]
    local specs, index = GetSelectedSpec(classInfo)
    if #specs == 0 then return end
    index = index or 1
    local nextIndex = ((index - 1 + delta) % #specs) + 1
    CFG.friendlyTestClass = classInfo.file
    CFG.friendlyTestSpecID = specs[nextIndex].id
end

local function StepValue(order, current, delta)
    local currentIndex = 1
    for index, key in ipairs(order) do
        if key == current then
            currentIndex = index
            break
        end
    end
    return order[((currentIndex - 1 + delta) % #order) + 1]
end

local function CreateBorder(frame, alpha)
    local borderAlpha = alpha or 0.85
    local function edge(point1, point2, horizontal)
        local tex = frame:CreateTexture(nil, "BORDER")
        tex:SetColorTexture(0.55, 1.0, 0.0, borderAlpha)
        tex:SetPoint(point1)
        tex:SetPoint(point2)
        if horizontal then tex:SetHeight(1) else tex:SetWidth(1) end
        return tex
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
end

local function CreateText(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(text or "")
    return fs
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 28, 22)
    button:SetText(text)
    return button
end

local function CreateCheck(parent, label)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local text = CreateText(parent, label, "GameFontHighlightSmall")
    text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.BMLabel = text
    return check
end

local function SetCheckEnabled(check, enabled)
    if not check then return end
    check:SetEnabled(enabled)
    if check.BMLabel then
        local value = enabled and 0.9 or 0.45
        check.BMLabel:SetTextColor(value, value, value, 1)
    end
end

local function RestoreWindowPosition(frame)
    frame:ClearAllPoints()
    local point = tostring(CFG.friendlyPreviewWindowPoint or "CENTER")
    local x = tonumber(CFG.friendlyPreviewWindowX) or 360
    local y = tonumber(CFG.friendlyPreviewWindowY) or 20
    frame:SetPoint(point, UIParent, point, x, y)
end

local function StoreWindowPosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    point = point or relativePoint or "CENTER"
    CFG.friendlyPreviewWindowPoint = point
    CFG.friendlyPreviewWindowX = x or 0
    CFG.friendlyPreviewWindowY = y or 0
    SavePreviewState()
end

local function SyncLegacyPreviewPosition()
    if not window or not window:IsShown() or not window.stage then return end
    local stageX, stageY = window.stage:GetCenter()
    local uiX, uiY = UIParent:GetCenter()
    if not stageX or not stageY or not uiX or not uiY then return end

    CFG.friendlyTestAnchorPoint = "CENTER"
    CFG.friendlyTestXOffset = stageX - uiX
    CFG.friendlyTestYOffset = stageY - uiY - 12
end

local function UpdateWindowControls()
    if not window then return end
    syncingControls = true

    local classInfo = CLASS_ORDER[GetSelectedClassIndex()]
    local _, _, spec = GetSelectedSpec(classInfo)
    if spec and CFG.friendlyTestSpecID ~= spec.id then CFG.friendlyTestSpecID = spec.id end
    if classInfo and CFG.friendlyTestClass ~= classInfo.file then CFG.friendlyTestClass = classInfo.file end

    window.classValue:SetText(classInfo and classInfo.name or "Unknown")
    if spec then
        local roleLabel = spec.role == "HEALER" and "Healer" or (spec.role == "TANK" and "Tank" or "Damage")
        window.specValue:SetText(spec.name)
        window.role:SetText("Role: " .. roleLabel)
    else
        window.specValue:SetText("Unavailable")
        window.role:SetText("Role: Unknown")
    end

    local health = math.floor(Clamp(CFG.friendlyTestHealthPercent or 62, 0, 100) + 0.5)
    window.healthSlider:SetValue(health)
    window.healthValue:SetText(tostring(health) .. "%")
    window.los:SetChecked(CFG.friendlyTestLOS == true)
    window.affiliate:SetChecked(CFG.friendlyTestAffiliate == true)
    window.cc:SetChecked(CFG.friendlyTestHealerControl == true)

    local aura = tostring(CFG.friendlyPreviewAura or "NONE"):upper()
    local objective = tostring(CFG.friendlyPreviewObjective or "NONE"):upper()
    window.auraValue:SetText(AURA_LABELS[aura] or aura)
    window.objectiveValue:SetText(OBJECTIVE_LABELS[objective] or objective)

    local healer = spec and spec.role == "HEALER"
    window.cc:SetShown(healer)
    window.cc.BMLabel:SetShown(healer)
    if healer then
        local enabled = CFG.healerCrossEnabled == true and CFG.healerControlEnabled == true
        SetCheckEnabled(window.cc, enabled)
        if enabled then
            window.healerStatus:SetText("Healer presentation active")
            window.healerStatus:SetTextColor(0.60, 1.0, 0.45, 1)
        elseif CFG.healerCrossEnabled ~= true then
            window.healerStatus:SetText("Healer Cross is disabled in Friendly Plates > Healer Appearance")
            window.healerStatus:SetTextColor(1.0, 0.72, 0.25, 1)
        else
            window.healerStatus:SetText("CC / Silence Badge is disabled in Healer Appearance")
            window.healerStatus:SetTextColor(1.0, 0.72, 0.25, 1)
        end
    else
        window.healerStatus:SetText("Non-healer preview: normal friendly spec plate")
        window.healerStatus:SetTextColor(0.72, 0.76, 0.80, 1)
    end
    window.healerStatus:Show()

    syncingControls = false
end

local function RefreshPreview()
    SyncLegacyPreviewPosition()
    LegacyUpdatePreview()
    UpdateWindowControls()
end

local function EnsureWindow()
    if window then return window end
    if InCombatLockdown and InCombatLockdown() then return nil end

    local root = CreateFrame("Frame", PREVIEW_WINDOW_NAME, UIParent)
    root:SetSize(430, 455)
    root:SetFrameStrata("DIALOG")
    root:SetFrameLevel(200)
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)

    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0.015, 0.018, 0.020, 0.98)
    bg:SetAllPoints()
    CreateBorder(root, 0.90)

    local titleBar = CreateFrame("Frame", nil, root)
    titleBar:SetPoint("TOPLEFT", root, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    local titleBG = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBG:SetTexture(WHITE)
    titleBG:SetVertexColor(0.035, 0.040, 0.043, 1)
    titleBG:SetAllPoints()

    local title = CreateText(titleBar, "BATTLE|cff9cff00MENDER|r  Friendly Preview", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)

    local close = CreateFrame("Button", nil, root, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", root, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() Defensives.HidePreview() end)

    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() root:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        root:StopMovingOrSizing()
        StoreWindowPosition(root)
        SyncLegacyPreviewPosition()
        LegacyUpdatePreview()
    end)

    local stage = CreateFrame("Frame", nil, root)
    stage:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -40)
    stage:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -40)
    stage:SetHeight(168)
    local stageBG = stage:CreateTexture(nil, "BACKGROUND")
    stageBG:SetTexture(WHITE)
    stageBG:SetVertexColor(0.005, 0.007, 0.008, 0.88)
    stageBG:SetAllPoints()
    CreateBorder(stage, 0.25)

    local stageLabel = CreateText(stage, "Preview", "GameFontHighlightSmall")
    stageLabel:SetPoint("TOPLEFT", stage, "TOPLEFT", 8, -6)
    stageLabel:SetTextColor(0.55, 1.0, 0.0, 1)

    local controls = CreateFrame("Frame", nil, root)
    controls:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -10)
    controls:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -12, 12)

    local function rowLabel(text, y)
        local label = CreateText(controls, text, "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", controls, "TOPLEFT", 2, y)
        label:SetWidth(54)
        label:SetJustifyH("LEFT")
        return label
    end

    rowLabel("Class", -2)
    local classPrev = CreateButton(controls, "<", 28)
    classPrev:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, 2)
    local classValue = CreateButton(controls, "Warrior", 210)
    classValue:SetPoint("LEFT", classPrev, "RIGHT", 4, 0)
    classValue:Disable()
    local classNext = CreateButton(controls, ">", 28)
    classNext:SetPoint("LEFT", classValue, "RIGHT", 4, 0)

    rowLabel("Spec", -32)
    local specPrev = CreateButton(controls, "<", 28)
    specPrev:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, -28)
    local specValue = CreateButton(controls, "Spec", 210)
    specValue:SetPoint("LEFT", specPrev, "RIGHT", 4, 0)
    specValue:Disable()
    local specNext = CreateButton(controls, ">", 28)
    specNext:SetPoint("LEFT", specValue, "RIGHT", 4, 0)

    local role = CreateText(controls, "Role: Damage", "GameFontDisableSmall")
    role:SetPoint("LEFT", specNext, "RIGHT", 8, 0)
    role:SetWidth(82)
    role:SetJustifyH("LEFT")

    rowLabel("Health", -64)
    local healthSlider = CreateFrame("Slider", "BattleMenderFriendlyPreviewHealthSlider", controls, "OptionsSliderTemplate")
    healthSlider:SetPoint("TOPLEFT", controls, "TOPLEFT", 66, -62)
    healthSlider:SetSize(235, 16)
    healthSlider:SetMinMaxValues(0, 100)
    healthSlider:SetValueStep(1)
    if healthSlider.SetObeyStepOnDrag then healthSlider:SetObeyStepOnDrag(true) end
    local sliderName = healthSlider:GetName()
    if sliderName then
        local low = _G[sliderName .. "Low"]
        local high = _G[sliderName .. "High"]
        local text = _G[sliderName .. "Text"]
        if low then low:SetText("") end
        if high then high:SetText("") end
        if text then text:SetText("") end
    end
    local healthValue = CreateText(controls, "62%", "GameFontHighlightSmall")
    healthValue:SetPoint("LEFT", healthSlider, "RIGHT", 10, 0)
    healthValue:SetWidth(42)
    healthValue:SetJustifyH("RIGHT")

    local los = CreateCheck(controls, "LoS / Faded")
    los:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, -87)
    local affiliate = CreateCheck(controls, "Affiliate")
    affiliate:SetPoint("LEFT", los, "RIGHT", 120, 0)
    local cc = CreateCheck(controls, "CC / Silence")
    cc:SetPoint("LEFT", affiliate, "RIGHT", 95, 0)

    rowLabel("Aura", -122)
    local auraPrev = CreateButton(controls, "<", 28)
    auraPrev:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, -118)
    local auraValue = CreateButton(controls, "None", 210)
    auraValue:SetPoint("LEFT", auraPrev, "RIGHT", 4, 0)
    auraValue:Disable()
    local auraNext = CreateButton(controls, ">", 28)
    auraNext:SetPoint("LEFT", auraValue, "RIGHT", 4, 0)

    rowLabel("Objective", -152)
    local objectivePrev = CreateButton(controls, "<", 28)
    objectivePrev:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, -148)
    local objectiveValue = CreateButton(controls, "None", 210)
    objectiveValue:SetPoint("LEFT", objectivePrev, "RIGHT", 4, 0)
    objectiveValue:Disable()
    local objectiveNext = CreateButton(controls, ">", 28)
    objectiveNext:SetPoint("LEFT", objectiveValue, "RIGHT", 4, 0)

    local healerStatus = CreateText(controls, "", "GameFontDisableSmall")
    healerStatus:SetPoint("TOPLEFT", controls, "TOPLEFT", 60, -181)
    healerStatus:SetPoint("RIGHT", controls, "RIGHT", -4, 0)
    healerStatus:SetJustifyH("LEFT")

    local reset = CreateButton(controls, "Reset Preview", 110)
    reset:SetPoint("BOTTOMLEFT", controls, "BOTTOMLEFT", 60, 0)
    local healerPreset = CreateButton(controls, "Healer", 80)
    healerPreset:SetPoint("LEFT", reset, "RIGHT", 6, 0)
    local dpsPreset = CreateButton(controls, "DPS", 80)
    dpsPreset:SetPoint("LEFT", healerPreset, "RIGHT", 6, 0)

    root.stage = stage
    root.classValue = classValue
    root.specValue = specValue
    root.role = role
    root.healthSlider = healthSlider
    root.healthValue = healthValue
    root.los = los
    root.affiliate = affiliate
    root.cc = cc
    root.auraValue = auraValue
    root.objectiveValue = objectiveValue
    root.healerStatus = healerStatus

    local function stateChanged()
        RefreshPreview()
        SavePreviewState()
    end

    classPrev:SetScript("OnClick", function() StepPreviewClass(-1); stateChanged() end)
    classNext:SetScript("OnClick", function() StepPreviewClass(1); stateChanged() end)
    specPrev:SetScript("OnClick", function() StepPreviewSpec(-1); stateChanged() end)
    specNext:SetScript("OnClick", function() StepPreviewSpec(1); stateChanged() end)

    healthSlider:SetScript("OnValueChanged", function(_, value)
        if syncingControls then return end
        value = math.floor(Clamp(value, 0, 100) + 0.5)
        CFG.friendlyTestHealthPercent = value
        healthValue:SetText(tostring(value) .. "%")
        RefreshPreview()
    end)
    healthSlider:SetScript("OnMouseUp", SavePreviewState)

    los:SetScript("OnClick", function(self)
        if syncingControls then return end
        CFG.friendlyTestLOS = self:GetChecked() == true
        stateChanged()
    end)
    affiliate:SetScript("OnClick", function(self)
        if syncingControls then return end
        CFG.friendlyTestAffiliate = self:GetChecked() == true
        stateChanged()
    end)
    cc:SetScript("OnClick", function(self)
        if syncingControls then return end
        CFG.friendlyTestHealerControl = self:GetChecked() == true
        stateChanged()
    end)

    auraPrev:SetScript("OnClick", function()
        CFG.friendlyPreviewAura = StepValue(AURA_ORDER, tostring(CFG.friendlyPreviewAura or "NONE"):upper(), -1)
        stateChanged()
    end)
    auraNext:SetScript("OnClick", function()
        CFG.friendlyPreviewAura = StepValue(AURA_ORDER, tostring(CFG.friendlyPreviewAura or "NONE"):upper(), 1)
        stateChanged()
    end)
    objectivePrev:SetScript("OnClick", function()
        CFG.friendlyPreviewObjective = StepValue(OBJECTIVE_ORDER, tostring(CFG.friendlyPreviewObjective or "NONE"):upper(), -1)
        stateChanged()
    end)
    objectiveNext:SetScript("OnClick", function()
        CFG.friendlyPreviewObjective = StepValue(OBJECTIVE_ORDER, tostring(CFG.friendlyPreviewObjective or "NONE"):upper(), 1)
        stateChanged()
    end)

    reset:SetScript("OnClick", function()
        CFG.friendlyTestHealthPercent = 62
        CFG.friendlyTestLOS = false
        CFG.friendlyPreviewAura = "NONE"
        CFG.friendlyPreviewObjective = "NONE"
        CFG.friendlyTestAffiliate = false
        CFG.friendlyTestHealerControl = false
        stateChanged()
    end)
    healerPreset:SetScript("OnClick", function()
        CFG.friendlyTestClass = "PALADIN"
        CFG.friendlyTestSpecID = 65
        CFG.friendlyTestHealthPercent = 62
        CFG.friendlyTestLOS = false
        CFG.friendlyPreviewAura = "NONE"
        CFG.friendlyPreviewObjective = "NONE"
        CFG.friendlyTestAffiliate = false
        CFG.friendlyTestHealerControl = false
        stateChanged()
    end)
    dpsPreset:SetScript("OnClick", function()
        CFG.friendlyTestClass = "WARRIOR"
        CFG.friendlyTestSpecID = 71
        CFG.friendlyTestHealthPercent = 62
        CFG.friendlyTestLOS = false
        CFG.friendlyPreviewAura = "NONE"
        CFG.friendlyPreviewObjective = "NONE"
        CFG.friendlyTestAffiliate = false
        CFG.friendlyTestHealerControl = false
        stateChanged()
    end)

    root:SetScript("OnShow", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if root:IsShown() then
                    SyncLegacyPreviewPosition()
                    LegacyUpdatePreview()
                    UpdateWindowControls()
                end
            end)
        end
    end)

    RestoreWindowPosition(root)
    window = root
    return root
end

function Defensives.ShowPreview(kind)
    if InCombatLockdown and InCombatLockdown() then return end
    local root = EnsureWindow()
    if not root then return end

    root:Show()
    LegacyShowPreview(kind or "CURRENT")
    SyncLegacyPreviewPosition()
    LegacyUpdatePreview()
    UpdateWindowControls()
end

function Defensives.UpdatePreview()
    if CFG.friendlyTestMode ~= true then
        LegacyUpdatePreview()
        if window then window:Hide() end
        return
    end

    if not window then
        local root = EnsureWindow()
        if not root then
            LegacyUpdatePreview()
            return
        end
        root:Show()
    end

    RefreshPreview()
end

function Defensives.HidePreview()
    LegacyHidePreview()
    if window then window:Hide() end
    NotifyOptionsChanged()
end

BM.FriendlyPreview = BM.FriendlyPreview or {}
BM.FriendlyPreview.Show = function(kind) Defensives.ShowPreview(kind) end
BM.FriendlyPreview.Hide = function() Defensives.HidePreview() end
BM.FriendlyPreview.Refresh = function() Defensives.UpdatePreview() end

local function PatchOptionsRegistration()
    if not LibStub then return end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if not registry or not registry.tables or registry.BMPreviewOptionsWrapped then return end

    local original = registry.tables["BattleMender"]
    if type(original) ~= "function" then return end

    registry.BMPreviewOptionsWrapped = true
    registry.tables["BattleMender"] = function(uiType, uiName, errlvl)
        local options = original(uiType, uiName, errlvl)
        local friendly = options and options.args and options.args.normal
        local args = friendly and friendly.args
        if not args then return options end

        local preview = args.preview
        if preview and preview.args then
            preview.name = "Preview"
            if preview.args.info then
                preview.args.info.name = "Opens a detached draggable Friendly Preview. Plate state, spec/role selection, LoS, aura/objective simulation, affiliate state, and healer CC simulation are controlled directly in the preview window."
            end
            if preview.args.show then
                preview.args.show.name = "Open Friendly Preview"
                preview.args.show.desc = "Open the detached Friendly Preview control window."
            end
            preview.args.hide = nil
            preview.args.state = nil
            preview.args.features = nil
            preview.args.position = nil
        end

        local healers = args.healers and args.healers.args
        if healers then
            if healers.preview then
                healers.preview.name = "Open Healer Preview"
                healers.preview.desc = "Opens the shared Friendly Preview on a healer spec. Preview-state controls are in the detached preview window."
            end

            local background = healers.background and healers.background.args
            if background and background.colorMode then
                background.colorMode.values = { CLASS = "Healer Class", CUSTOM = "Custom" }
                background.colorMode.desc = "Healer Class uses the friendly healer's class color. Custom uses the RGB color below."
            end
            if background and background.note then
                background.note.name = "Healer Class is the default healthy background. Missing health still uses the normal Friendly Health damaged color, with the separate damaged-cross color above it."
            end

            local control = healers.control and healers.control.args
            if control and control.colorMode then
                control.colorMode.values = { CLASS = "Healer Class", CUSTOM = "Custom" }
                control.colorMode.desc = "Healer Class uses the friendly healer's class color. It never uses your class or the CC caster's class."
            end
            if control and control.note then
                control.note.name = "Healer Class is the default accent. Live CC is separated into this badge so healer health remains readable."
            end
        end

        local affiliates = args.affiliates and args.affiliates.args
        local badge = affiliates and affiliates.badge and affiliates.badge.args
        if badge and badge.preview then
            badge.preview.name = "Open Affiliate Preview"
            badge.preview.desc = "Opens the shared Friendly Preview with Affiliate enabled."
        end

        return options
    end

    registry:NotifyChange("BattleMender")
end

PatchOptionsRegistration()
if C_Timer and C_Timer.After then C_Timer.After(0, PatchOptionsRegistration) end

-- BattleMender - native 12.1 friendly defensive displays.
-- Blizzard_AuraContainer owns aura matching, visibility and duration. This
-- module only supplies BattleMender-owned placement and artwork.

BattleMender = BattleMender or {}

local BM = BattleMender
local CFG = BM.CFG
local Defensives = BM.Defensives or {}
BM.Defensives = Defensives

local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DAMAGED_CIRCLE_MASK = "Interface\\AddOns\\BattleMender\\Textures\\Circle_White.tga"
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local IMMUNITY_RING = "Interface\\AddOns\\BattleMender\\Textures\\Immunity_Ring.tga"
local OBJECTIVE_GLOW = "Interface\\AddOns\\BattleMender\\Textures\\Circle_Halo_2.tga"
local OBJECTIVE_PREVIEW_INFO = {
    NONE = nil,
    FLAG_HORDE = { atlas = "nameplates-icon-flag-horde", r = 1.00, g = 0.25, b = 0.25, label = "Horde Flag" },
    FLAG_ALLIANCE = { atlas = "nameplates-icon-flag-alliance", r = 0.26, g = 0.60, b = 1.00, label = "Alliance Flag" },
    FLAG_NEUTRAL = { atlas = "nameplates-icon-flag-neutral", r = 1.00, g = 0.86, b = 0.26, label = "Neutral Flag" },
    ORB_BLUE = { atlas = "nameplates-icon-orb-blue", r = 0.30, g = 0.75, b = 1.00, label = "Blue Orb" },
    ORB_GREEN = { atlas = "nameplates-icon-orb-green", r = 0.28, g = 1.00, b = 0.40, label = "Green Orb" },
    ORB_ORANGE = { atlas = "nameplates-icon-orb-orange", r = 1.00, g = 0.62, b = 0.14, label = "Orange Orb" },
    ORB_PURPLE = { atlas = "nameplates-icon-orb-purple", r = 0.86, g = 0.42, b = 1.00, label = "Purple Orb" },
    CART_HORDE = { atlas = "nameplates-icon-cart-horde", r = 1.00, g = 0.25, b = 0.25, label = "Horde Cart" },
    CART_ALLIANCE = { atlas = "nameplates-icon-cart-alliance", r = 0.26, g = 0.60, b = 1.00, label = "Alliance Cart" },
    BOUNTY_HORDE = { atlas = "nameplates-icon-bounty-horde", r = 1.00, g = 0.25, b = 0.25, label = "Horde Bounty" },
    BOUNTY_ALLIANCE = { atlas = "nameplates-icon-bounty-alliance", r = 0.26, g = 0.60, b = 1.00, label = "Alliance Bounty" },
}

local BORDER_TEXTURES = {
    THIN = "Interface\\AddOns\\BattleMender\\Textures\\Ring_10px.tga",
    NORMAL = "Interface\\AddOns\\BattleMender\\Textures\\Ring_20px.tga",
    METAL = "Interface\\AddOns\\BattleMender\\Textures\\Ring_30px.tga",
    COGWHEEL = "Interface\\AddOns\\BattleMender\\Textures\\defensive_cogwheel.tga",
}

local BORDER_FIT = { THIN = 0.964, NORMAL = 1, METAL = 1.036, COGWHEEL = 1 }
local DISPLAY_BY_FRAME = setmetatable({}, { __mode = "k" })
local BUTTON_REGIONS = setmetatable({}, { __mode = "k" })
local PENDING_PLATES = setmetatable({}, { __mode = "k" })
local previewFrame
local settingsRefreshPending
local apiUnavailableReported

Defensives.DisplayByFrame = DISPLAY_BY_FRAME

-- The include lists deliberately contain only specific helpful auras. Blizzard
-- performs all unit-aura access and does not expose the aura payload here.
local PERSONAL_MAJOR = {
    [48707]=true, [48792]=true, [55233]=true, [49028]=true, -- Death Knight
    [198589]=true, [187827]=true, -- Demon Hunter
    [22812]=true, [61336]=true, -- Druid
    [363916]=true, [374348]=true, [370960]=true, -- Evoker
    [264735]=true, -- Hunter
    [342246]=true, [110960]=true, [55342]=true, [414658]=true, -- Mage
    [115203]=true, [243435]=true, [122783]=true, [122278]=true, [122470]=true, -- Monk
    [498]=true, [31850]=true, [86659]=true, [184662]=true, -- Paladin
    [47585]=true, -- Priest
    [5277]=true, [31224]=true, [1966]=true, -- Rogue
    [108271]=true, -- Shaman
    [104773]=true, [108416]=true, [212295]=true, -- Warlock
    [871]=true, [118038]=true, [184364]=true, [23920]=true, [12975]=true, -- Warrior
}

local EXTERNAL_MAJOR = {
    DEATHKNIGHT = { [51052]=true },
    DEMONHUNTER = { [196718]=true },
    SHAMAN = { [98008]=true },
    WARRIOR = { [97462]=true },
    PALADIN = { [6940]=true, [31821]=true },
    HUNTER = { [53480]=true },
    DRUID = { [102342]=true },
    EVOKER = { [357170]=true },
    MONK = { [116849]=true },
    PRIEST = { [33206]=true, [47788]=true, [62618]=true, [81782]=true },
}
local EXTERNAL_ORDER = { "DEATHKNIGHT", "DEMONHUNTER", "SHAMAN", "WARRIOR", "PALADIN", "HUNTER", "DRUID", "EVOKER", "MONK", "PRIEST" }
local IMMUNITIES = { [642]=true, [45438]=true, [1022]=true, [204018]=true, [186265]=true, [196555]=true, [409293]=true }

-- PvP objective-carrier auras. These are intentionally handled by Blizzard's
-- AuraContainer rather than direct UNIT_AURA payload inspection: on Retail 12.1
-- the managed container can safely choose the matching aura and populate its icon.
-- The legacy WSG IDs remain for compatibility with battleground variants that
-- still expose the older carrier spell IDs.
local PVP_OBJECTIVE_HELPFUL = {
    [23333]=true,  -- Horde / Warsong Flag (legacy)
    [23335]=true,  -- Alliance / Silverwing Flag (legacy)
    [156618]=true, -- Horde Flag
    [156621]=true, -- Alliance Flag
    [34976]=true,  -- Netherstorm Flag (Eye of the Storm)
    [434339]=true, -- Deephaul Crystal
}

local PVP_OBJECTIVE_HARMFUL = {
    [121164]=true, -- Temple of Kotmogu: Orb of Power
    [121175]=true,
    [121176]=true,
    [121177]=true,
}

Defensives.PersonalMajorSpellIDs = PERSONAL_MAJOR
Defensives.ExternalMajorSpellIDsByClass = EXTERNAL_MAJOR
Defensives.ImmunitySpellIDs = IMMUNITIES
Defensives.PvPObjectiveHelpfulSpellIDs = PVP_OBJECTIVE_HELPFUL
Defensives.PvPObjectiveHarmfulSpellIDs = PVP_OBJECTIVE_HARMFUL

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function GetIconSize()
    return math.max(12, tonumber(CFG.iconSize) or 45)
end

-- AuraContainer AuraButtons can become forbidden after Blizzard associates
-- restricted PvP aura state with them. Combat lockdown alone is not a sufficient
-- guard: the object can remain forbidden while the player is temporarily out of
-- combat. Never mutate a managed AuraButton once Blizzard marks it forbidden.
local function IsForbiddenObject(object)
    if not object or type(object.IsForbidden) ~= "function" then return false end
    local ok, forbidden = pcall(object.IsForbidden, object)
    return ok and forbidden == true
end

local function IsManagedAuraLayoutRestricted()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    -- AuraContainer children can remain forbidden under PvP-match restrictions
    -- even while the player is not personally in combat. IsForbidden() is not a
    -- sufficient preflight for every managed AuraButton method, so never run a
    -- global re-anchor/resize pass while inside an arena or battleground.
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "arena" or instanceType == "pvp") then
        return true
    end

    if C_PvP and type(C_PvP.IsMatchActive) == "function" then
        local ok, active = pcall(C_PvP.IsMatchActive)
        if ok and active == true then
            return true
        end
    end

    return false
end

local function GetClassColor(classFile)
    local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classFile]
    return color and color.r or 1, color and color.g or 1, color and color.b or 1
end

local function GetFriendlyClass(unit)
    return BM.GetFriendlyClassFile and BM.GetFriendlyClassFile(unit) or nil
end

local function GetBorderColor(regions)
    local mode = tostring(CFG.majorDefensiveBorderColorMode or "AUTO"):upper()
    if mode == "WHITE" then return 1, 1, 1 end
    if mode == "CUSTOM" then
        return Clamp(CFG.majorDefensiveCustomR, 0, 1), Clamp(CFG.majorDefensiveCustomG, 0, 1), Clamp(CFG.majorDefensiveCustomB, 0, 1)
    end
    return GetClassColor(regions.sourceClass or GetFriendlyClass(regions.context and regions.context.unit))
end

local function AuraAPIAvailable()
    return AuraContainerSortMethod ~= nil
        and AuraContainerSortDirection ~= nil
        and CustomAuraContainerSlotDefaultOptions ~= nil
end

Defensives.IsAuraAPIAvailable = AuraAPIAvailable

local function EnsureAuraAPI()
    if AuraAPIAvailable() then return true end
    if InCombatLockdown and InCombatLockdown() then return false end

    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loader then pcall(loader, "Blizzard_AuraContainer") end
    if AuraAPIAvailable() then return true end

    if CFG.debug and not apiUnavailableReported then
        apiUnavailableReported = true
        print("|cff33ff99BattleMender:|r 12.1 AuraContainer is unavailable; defensive displays are inactive.")
    end
    return false
end

local function CreatePulse(texture)
    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local up = group:CreateAnimation("Alpha")
    up:SetOrder(1)
    up:SetSmoothing("IN_OUT")
    local down = group:CreateAnimation("Alpha")
    down:SetOrder(2)
    down:SetSmoothing("IN_OUT")
    return group, up, down
end

local function ConfigurePulse(regions, enabled)
    local animation = regions.pulseAnimation
    if not animation then return end
    animation:Stop()
    if not enabled then
        regions.glow:SetAlpha(0)
        return
    end
    local maximum = Clamp(CFG.immunityGlowAlpha or 0.42, 0, 1)
    local minimum = maximum * 0.28
    local duration = Clamp(CFG.immunityGlowSpeed or 0.9, 0.15, 2.5)
    regions.pulseUp:SetFromAlpha(minimum)
    regions.pulseUp:SetToAlpha(maximum)
    regions.pulseUp:SetDuration(duration)
    regions.pulseDown:SetFromAlpha(maximum)
    regions.pulseDown:SetToAlpha(minimum)
    regions.pulseDown:SetDuration(duration)
    regions.glow:SetAlpha(minimum)
    animation:Play()
end

local function ApplyMajorSettings(button, regions)
    if IsForbiddenObject(button) then return false end

    local size = math.max(12, math.floor(GetIconSize() * Clamp(CFG.majorDefensiveBadgeScale or .72, .35, 1.4) + .5))
    local radians = math.rad((tonumber(CFG.majorDefensiveAngle) or 42) % 360)
    local distance = GetIconSize() * Clamp(CFG.majorDefensiveDistanceScale or .53, 0, 1.5)
    local enabled = CFG.defensiveDisplayEnabled ~= false and CFG.majorDefensiveEnabled ~= false
    local inFront = tostring(CFG.majorDefensiveLayer or "BEHIND"):upper() == "FRONT"
    local textureKey = tostring(CFG.majorDefensiveBorderTexture or "NORMAL"):upper()
    local texture = BORDER_TEXTURES[textureKey]

    button:ClearAllPoints()
    button:SetPoint("CENTER", button:GetParent(), "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
    button:SetSize(size, size)
    button:SetFrameLevel(inFront and 340 or 319)

    regions.icon:SetAllPoints(button)
    regions.iconMask:SetAllPoints(button)
    regions.icon:SetAlpha(enabled and 1 or 0)
    regions.backplate:SetPoint("CENTER", button, "CENTER")
    regions.backplate:SetSize(size * 1.08, size * 1.08)
    regions.backplateMask:SetAllPoints(regions.backplate)
    regions.backplate:SetAlpha(enabled and texture and math.min(.92, Clamp(CFG.majorDefensiveBorderAlpha or 1, 0, 1)) or 0)

    local borderSize = math.max(size, math.floor(size * Clamp(CFG.majorDefensiveBorderScale or 1.18, .9, 1.8) * (BORDER_FIT[textureKey] or 1) + .5))
    local r, g, b = GetBorderColor(regions)
    regions.border:SetPoint("CENTER", button, "CENTER")
    regions.border:SetSize(borderSize, borderSize)
    regions.border:SetTexture(texture)
    regions.border:SetVertexColor(r, g, b, 1)
    regions.border:SetAlpha(enabled and texture and Clamp(CFG.majorDefensiveBorderAlpha or 1, 0, 1) or 0)
    return true
end

local function ApplyImmunitySettings(button, regions)
    if IsForbiddenObject(button) then return false end

    local size = math.floor(GetIconSize() * Clamp(CFG.immunityIconScale or 1, .7, 1.4) + .5)
    local enabled = CFG.defensiveDisplayEnabled ~= false and CFG.immunityDisplayEnabled ~= false
    local inset = math.max(0, math.floor(((size * Clamp(CFG.immunityRingScale or 1.18, 1, 1.6)) - size) * .5 + .5))
    button:SetSize(size, size)
    button:ClearAllPoints()
    button:SetPoint("CENTER", button:GetParent(), "CENTER")
    button:SetFrameLevel(344)
    regions.icon:SetAllPoints(button)
    regions.iconMask:SetAllPoints(button)
    regions.icon:SetAlpha(enabled and CFG.immunityReplaceSpecIcon ~= false and 1 or 0)
    for _, region in ipairs({ regions.ring, regions.cooldown }) do
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", button, "TOPLEFT", -inset, inset)
        region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", inset, -inset)
    end
    regions.ring:SetAlpha(enabled and Clamp(CFG.immunityRingAlpha or .92, 0, 1) or 0)
    regions.cooldown:SetAlpha(enabled and CFG.immunityCooldownSwipe ~= false and Clamp(CFG.immunityCooldownRingAlpha or .92, 0, 1) or 0)
    regions.glow:ClearAllPoints()
    regions.glow:SetPoint("TOPLEFT", button, "TOPLEFT", -inset - 2, inset + 2)
    regions.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", inset + 2, -inset - 2)
    ConfigurePulse(regions, enabled and CFG.immunityGlowEnabled ~= false)
    return true
end

local function CreateMajorRegions(button, context, sourceClass, registered)
    local backplate = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    backplate:SetTexture(WHITE_TEXTURE)
    backplate:SetVertexColor(.01, .01, .015, 1)
    local backplateMask = button:CreateMaskTexture(nil, "BACKGROUND")
    backplateMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    backplate:AddMaskTexture(backplateMask)
    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetTexCoord(.06, .94, .06, .94)
    local iconMask = button:CreateMaskTexture(nil, "ARTWORK")
    iconMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(iconMask)
    local border = button:CreateTexture(nil, "OVERLAY", nil, 5)
    if registered and button.SetIcon then button:SetIcon(icon) end
    return { kind="MAJOR", context=context, sourceClass=sourceClass, backplate=backplate, backplateMask=backplateMask, icon=icon, iconMask=iconMask, border=border }
end

local function CreateImmunityRegions(button, registered)
    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetTexCoord(.06, .94, .06, .94)
    local iconMask = button:CreateMaskTexture(nil, "ARTWORK")
    iconMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    icon:AddMaskTexture(iconMask)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetDrawEdge(false); cooldown:SetDrawBling(false); cooldown:SetHideCountdownNumbers(true)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(IMMUNITY_RING) end
    cooldown:SetSwipeColor(1, .68, .12, 1)
    local ring = button:CreateTexture(nil, "OVERLAY", nil, 5)
    ring:SetTexture(IMMUNITY_RING, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring:SetVertexColor(.9, .93, .98, 1)
    local glow = button:CreateTexture(nil, "OVERLAY", nil, 6)
    glow:SetTexture(IMMUNITY_RING, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    glow:SetVertexColor(1, .82, .3, 1); glow:SetBlendMode("ADD")
    local pulseAnimation, pulseUp, pulseDown = CreatePulse(glow)
    if registered then
        if button.SetIcon then button:SetIcon(icon) end
        if button.SetDurationCooldown then button:SetDurationCooldown(cooldown) end
    end
    return { kind="IMMUNITY", icon=icon, iconMask=iconMask, cooldown=cooldown, ring=ring, glow=glow, pulseAnimation=pulseAnimation, pulseUp=pulseUp, pulseDown=pulseDown }
end

local function MajorInitializer(context, sourceClass)
    return function(button)
        button:SetFrameStrata("TOOLTIP"); button:EnableMouse(false)
        local regions = CreateMajorRegions(button, context, sourceClass, true)
        BUTTON_REGIONS[button] = regions
        ApplyMajorSettings(button, regions)
    end
end

local function ImmunityInitializer(button)
    button:SetFrameStrata("TOOLTIP"); button:EnableMouse(false)
    local regions = CreateImmunityRegions(button, true)
    BUTTON_REGIONS[button] = regions
    ApplyImmunitySettings(button, regions)
end

-- Objective AuraButtons must remain completely Blizzard-managed after their
-- initializeFrame callback. Do not register them in BUTTON_REGIONS, attach
-- scripts, poll visibility, or mutate their child regions later. Their normal
-- AuraButton visibility is the secret-safe objective-presence signal.
local function ObjectiveInitializer(kind)
    return function(button)
        button:SetFrameStrata("TOOLTIP")
        button:EnableMouse(false)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT")
        button:SetPoint("BOTTOMRIGHT", button:GetParent(), "BOTTOMRIGHT")

        local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
        icon:SetAllPoints(button)
        icon:SetTexCoord(.04, .96, .04, .96)
        icon:SetBlendMode(kind == "DAMAGE" and (CFG.damageIconBlendMode or "BLEND") or "BLEND")

        if kind == "DAMAGE" then
            icon:SetVertexColor(CFG.damageIconR or 1, CFG.damageIconG or .02, CFG.damageIconB or .02, 1)
        else
            icon:SetVertexColor(1, 1, 1, 1)
        end
        icon:SetAlpha(1)

        local mask = button:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture(kind == "DAMAGE" and DAMAGED_CIRCLE_MASK or CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(button)
        icon:AddMaskTexture(mask)

        if button.SetIcon then button:SetIcon(icon) end
    end
end

local function IsBattlegroundContext()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end

local function ForEachContainer(display, callback)
    if not display then return end
    for _, container in ipairs({ display.major, display.immunity, display.objectiveDamage, display.objectiveHealth }) do
        if container then callback(container) end
    end
end

local function SetObjectiveHostsShown(display, shown)
    if not display then return end
    if display.objectiveClip then display.objectiveClip:SetShown(shown) end
    if display.objectiveHealthHost then display.objectiveHealthHost:SetShown(shown) end
    if display.objectiveDamage then display.objectiveDamage:SetAlpha(CFG.damageIconAlpha or 1) end
    if display.objectiveHealth then display.objectiveHealth:SetAlpha(CFG.specIconAlpha or 1) end
end

local function DisableDisplay(display)
    if not display then return end
    ForEachContainer(display, function(container)
        pcall(container.SetEnabled, container, false)
        container:Hide()
    end)
    SetObjectiveHostsShown(display, false)
    if display.anchor then display.anchor:Hide() end
    display.unit = nil
    if display.context then display.context.unit = nil end
end

local function IsAllowed(unit, frame)
    local wantsManagedAuras = CFG.defensiveDisplayEnabled ~= false
    return wantsManagedAuras and CFG.enabled ~= false and not BM.IsSleeping
        and unit and UnitExists(unit) and BM.IsFriendlyPlayer and BM.IsFriendlyPlayer(unit)
        and (not BM.GetState or not BM.GetState(frame) or BM.GetState(frame).active ~= false)
end

local function EnsureAnchor(plate, frame)
    local display = DISPLAY_BY_FRAME[frame]
    local anchor = display and display.anchor
    if anchor then return anchor end
    if InCombatLockdown and InCombatLockdown() then PENDING_PLATES[plate] = true; return nil end
    anchor = CreateFrame("Frame", nil, plate)
    anchor:SetIgnoreParentAlpha(true); anchor:SetFrameStrata("TOOLTIP"); anchor:SetFrameLevel(317); anchor:EnableMouse(false)
    return anchor
end

local function PositionAnchor(anchor, plate, frame)
    if not anchor or InCombatLockdown and InCombatLockdown() then return false end
    if anchor:GetParent() ~= plate then anchor:SetParent(plate) end
    local visual = BM.GetVisualAnchorFrame and BM.GetVisualAnchorFrame(frame, plate) or frame
    anchor:ClearAllPoints()
    anchor:SetPoint(CFG.anchorPoint or "CENTER", visual, CFG.anchorPoint or "CENTER", tonumber(CFG.anchorX) or 0, tonumber(CFG.anchorY) or 0)
    anchor:SetSize(GetIconSize(), GetIconSize())
    anchor:Show()
    return true
end

local function CreateContainer(anchor, level)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end
    container:SetIgnoreParentAlpha(true); container:SetFrameStrata("TOOLTIP"); container:SetFrameLevel(level)
    container:SetPoint("CENTER", anchor, "CENTER"); container:SetSize(1, 1)
    return container
end

local function CreateObjectiveContainer(parent, level)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end
    container:SetIgnoreParentAlpha(true)
    container:SetFrameStrata("TOOLTIP")
    container:SetFrameLevel(level)
    container:SetAllPoints(parent)
    return container
end

local function CreateObjectiveHealthHost(plate, frame, anchor)
    local overlay = BM.GetOverlay and BM.GetOverlay(frame)
    local healthTexture = overlay and overlay.healthOverlayTexture
    if not healthTexture then return nil, nil end

    -- The clip follows the StatusBar's rendered fill texture. The full-size host
    -- remains aligned to the normal icon anchor, so only the current-health
    -- portion of the objective icon is visible, matching the existing spec art.
    local clip = CreateFrame("Frame", nil, plate)
    clip:SetIgnoreParentAlpha(true)
    clip:SetFrameStrata("TOOLTIP")
    clip:SetFrameLevel(331)
    clip:EnableMouse(false)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    clip:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMLEFT")
    clip:SetPoint("TOPRIGHT", healthTexture, "TOPRIGHT")

    local host = CreateFrame("Frame", nil, clip)
    host:SetIgnoreParentAlpha(true)
    host:SetFrameStrata("TOOLTIP")
    host:SetFrameLevel(332)
    host:EnableMouse(false)
    host:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    host:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    clip:Show()
    host:Show()
    return clip, host
end

local function AddSlot(container, name, filter, ids, initializer)
    return pcall(container.AddAuraSlot, container, name, filter or "HELPFUL", {
        candidateFilters = { includeSpellIDs = ids },
        sortMethod = AuraContainerSortMethod.BigDefensive or AuraContainerSortMethod.Expiration or AuraContainerSortMethod.Default,
        sortDirection = AuraContainerSortDirection.Normal,
        initializeFrame = initializer,
    })
end

local function AddObjectiveSlots(container, suffix, initializer)
    return AddSlot(container, "BattleMenderPvPObjectiveHelpful" .. suffix, "HELPFUL", PVP_OBJECTIVE_HELPFUL, initializer)
        and AddSlot(container, "BattleMenderPvPObjectiveHarmful" .. suffix, "HARMFUL", PVP_OBJECTIVE_HARMFUL, initializer)
end

-- The native loss-of-control API does not expose a safely readable control
-- type for ordinary friendly players in current Retail. Keep the warning on a
-- strict public spell allow-list instead: hard loss-of-control effects plus
-- silences only. Never inspect or hook the managed AuraButton after creation.
local HEALER_CONTROL_CATEGORIES = { stun=true, incapacitate=true, disorient=true, silence=true }
local healerControlSpellIDs
local function GetHealerControlSpellIDs()
    if healerControlSpellIDs then return healerControlSpellIDs end
    local library = LibStub and LibStub("DRList-1.0", true)
    if not library then return nil end
    local ids = { [78675]=true } -- Solar Beam: silence without diminishing returns.
    for spellID, category in pairs(library:GetSpells()) do
        if type(category) == "table" then
            for _, entry in ipairs(category) do
                if HEALER_CONTROL_CATEGORIES[entry] then ids[spellID] = true end
            end
        elseif HEALER_CONTROL_CATEGORIES[category] then
            ids[spellID] = true
        end
    end
    healerControlSpellIDs = ids
    return ids
end

-- AuraContainer spell-ID candidate filters can fail open when Blizzard cannot
-- safely evaluate unit identity. For this warning a false positive is much
-- worse than a missed indicator, so suppress it unless the healer is a safely
-- assistable unit. This keeps random debuffs / soft CC from ever becoming the
-- CC badge through an unavailable identity gate.
local function CanSafelyFilterHealerControl(unit)
    if not unit or not UnitCanAssist then return false end
    local ok, canAssist = pcall(UnitCanAssist, "player", unit)
    if not ok or (BM.IsSecretValue and BM.IsSecretValue(canAssist)) then
        return false
    end
    return canAssist == true
end

local function DisableHealerControl(overlay)
    if not overlay then return end
    if overlay.healerControlHost then overlay.healerControlHost:Hide() end
    local control = overlay.healerControl
    if control and not (InCombatLockdown and InCombatLockdown()) then
        control.container:SetEnabled(false)
        control.container:Hide()
        control.unit = nil
    end
end

local function HealerControlInitializer(button)
    button:EnableMouse(false)
    button:SetIgnoreParentAlpha(false)
    button:SetFrameStrata("TOOLTIP")
    button:SetFrameLevel(339)
    button:ClearAllPoints()
    button:SetAllPoints(button:GetParent())

    local backplate = button:CreateTexture(nil, "BACKGROUND", nil, 0)
    backplate:SetTexture(WHITE_TEXTURE)
    backplate:SetVertexColor(.01, .01, .015, .92)
    backplate:SetAllPoints(button)
    local backMask = button:CreateMaskTexture(nil, "BACKGROUND")
    backMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    backMask:SetAllPoints(button)
    backplate:AddMaskTexture(backMask)

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetAllPoints(button)
    icon:SetTexCoord(.06, .94, .06, .94)
    local iconMask = button:CreateMaskTexture(nil, "ARTWORK")
    iconMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    iconMask:SetAllPoints(button)
    icon:AddMaskTexture(iconMask)
    if button.SetIcon then button:SetIcon(icon) end

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if button.SetDurationCooldown then button:SetDurationCooldown(cooldown) end

    local r, g, b = CFG.healerControlR or 1, CFG.healerControlG or .65, CFG.healerControlB or .06
    local border = button:CreateTexture(nil, "OVERLAY", nil, 5)
    border:SetTexture(BORDER_TEXTURES.NORMAL)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    border:SetVertexColor(r, g, b, 1)

    local glow = button:CreateTexture(nil, "OVERLAY", nil, 4)
    glow:SetTexture(BORDER_TEXTURES.NORMAL)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -5, 5)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 5, -5)
    glow:SetVertexColor(r, g, b, 1)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(.32)
end

local function UpdateHealerControl(plate, frame, unit)
    local overlay = frame and BM.GetOverlay and BM.GetOverlay(frame)
    if not overlay then return end
    local allowed = CFG.enabled ~= false and not BM.IsSleeping
        and CFG.healerControlEnabled == true and overlay.healerActive == true
        and CFG.specIconEnabled ~= false and BM.IsFriendlyPlayer(unit)
        and CanSafelyFilterHealerControl(unit)
    if not allowed then
        DisableHealerControl(overlay)
        return
    end

    local control = overlay.healerControl
    if InCombatLockdown and InCombatLockdown() then
        PENDING_PLATES[plate] = true
        -- A container bound to another token must never color this occupant.
        overlay.healerControlHost:SetShown(control ~= nil and control.unit == unit)
        return
    end

    if not EnsureAuraAPI() then overlay.healerControlHost:Hide(); return end
    local ids = GetHealerControlSpellIDs()
    if not ids then overlay.healerControlHost:Hide(); return end
    local r, g, b = CFG.healerControlR, CFG.healerControlG, CFG.healerControlB
    local needsArt = not control or control.r ~= r or control.g ~= g or control.b ~= b
    if needsArt then
        if control and IsManagedAuraLayoutRestricted() then
            -- Existing restricted buttons keep their initial art until leaving
            -- the match. Do not attempt to recolor their forbidden regions.
            settingsRefreshPending = true
        else
            local container = CreateObjectiveContainer(overlay.healerControlHost, 338)
            if not container then return end
            container:SetIgnoreParentAlpha(false)
            container:EnableMouse(false)
            container:SetEnabled(false)
            container:Hide()
            -- CROWD_CONTROL is defense-in-depth. The spell allow-list remains
            -- authoritative and narrows Blizzard's broad CC bucket to hard CC
            -- and silence only (no roots, slows, knockbacks, or school lockouts).
            -- The managed AuraButton supplies the actual CC/silence spell icon
            -- and duration; BattleMender only provides circular badge artwork.
            local added = AddSlot(container, "BattleMenderHealerControl", "HARMFUL|CROWD_CONTROL", ids, HealerControlInitializer)
            if not added then container:SetEnabled(false); container:Hide(); return end
            DisableHealerControl(overlay)
            control = { container=container, r=r, g=g, b=b }
            overlay.healerControl = control
        end
    end

    if control.unit ~= unit then
        control.container:SetUnit(unit)
        control.unit = unit
        control.container:SetEnabled(true)
        control.container:Show()
        control.container:UpdateAllAuras()
    end
    overlay.healerControlHost:Show()
end

local function BuildDisplay(plate, frame, unit)
    if not EnsureAuraAPI() then return nil end
    local anchor = EnsureAnchor(plate, frame)
    if not anchor then return nil end
    PositionAnchor(anchor, plate, frame)

    local major, immunity = CreateContainer(anchor, 318), CreateContainer(anchor, 342)
    local objectiveDamage = CreateObjectiveContainer(anchor, 321)
    if not major or not immunity or not objectiveDamage then return nil end

    local objectiveClip, objectiveHealthHost = CreateObjectiveHealthHost(plate, frame, anchor)
    local objectiveHealth = CreateObjectiveContainer(objectiveHealthHost or anchor, 332)
    if not objectiveHealth then return nil end

    local context = { plate=plate, frame=frame, unit=unit }
    if not AddSlot(major, "BattleMenderMajorPersonal", "HELPFUL", PERSONAL_MAJOR, MajorInitializer(context)) then return nil end
    for _, classFile in ipairs(EXTERNAL_ORDER) do
        if not AddSlot(major, "BattleMenderMajorExternal" .. classFile, "HELPFUL", EXTERNAL_MAJOR[classFile], MajorInitializer(context, classFile)) then return nil end
    end
    if not AddSlot(immunity, "BattleMenderImmunity", "HELPFUL", IMMUNITIES, ImmunityInitializer) then return nil end
    if not AddObjectiveSlots(objectiveDamage, "Damage", ObjectiveInitializer("DAMAGE")) then return nil end
    if not AddObjectiveSlots(objectiveHealth, "Health", ObjectiveInitializer("HEALTH")) then return nil end

    for _, container in ipairs({ major, immunity, objectiveDamage, objectiveHealth }) do
        if not pcall(container.SetUnit, container, unit) then return nil end
    end

    local display = {
        anchor=anchor, major=major, immunity=immunity,
        objectiveDamage=objectiveDamage, objectiveHealth=objectiveHealth,
        objectiveClip=objectiveClip, objectiveHealthHost=objectiveHealthHost,
        plate=plate, frame=frame, unit=unit, context=context,
    }
    DISPLAY_BY_FRAME[frame] = display

    local objectiveEnabled = false
    for _, container in ipairs({ major, immunity }) do
        container:SetEnabled(true); container:Show(); container:UpdateAllAuras()
    end
    for _, container in ipairs({ objectiveDamage, objectiveHealth }) do
        container:SetEnabled(objectiveEnabled)
        container:SetShown(objectiveEnabled)
        if objectiveEnabled then container:UpdateAllAuras() end
    end
    SetObjectiveHostsShown(display, objectiveEnabled)
    return display
end

function Defensives.ClearFrame(frame)
    DisableHealerControl(frame and BM.GetOverlay and BM.GetOverlay(frame))
    local display = frame and DISPLAY_BY_FRAME[frame]
    if InCombatLockdown and InCombatLockdown() then
        if display and display.plate then PENDING_PLATES[display.plate] = true end
        return
    end
    DisableDisplay(display)
end

function Defensives.UpdatePlate(plate)
    if not plate then return end
    local frame = BM.GetVisualFrame and BM.GetVisualFrame(plate)
    local unit = frame and BM.ResolvePlateUnit and BM.ResolvePlateUnit(plate, frame)
    local display = frame and DISPLAY_BY_FRAME[frame]
    UpdateHealerControl(plate, frame, unit)
    if not frame or not IsAllowed(unit, frame) then
        if InCombatLockdown and InCombatLockdown() then
            if display and display.plate then PENDING_PLATES[display.plate] = true end
        else
            DisableDisplay(display)
        end
        return
    end

    -- AuraContainer configuration and unit assignment can perform protected
    -- work. Keep an already-active display in Blizzard's hands during combat,
    -- then apply any recycled-plate or settings transition afterwards.
    if InCombatLockdown and InCombatLockdown() then
        if not display or display.unit ~= unit then PENDING_PLATES[plate] = true end
        return
    end

    if not display then display = BuildDisplay(plate, frame, unit) end
    if not display then return end
    display.plate = plate
    if not PositionAnchor(display.anchor, plate, frame) then PENDING_PLATES[plate] = true end
    if display.unit ~= unit then
        local unitUpdated = true
        ForEachContainer(display, function(container)
            if unitUpdated and not pcall(container.SetUnit, container, unit) then unitUpdated = false end
        end)
        if not unitUpdated then PENDING_PLATES[plate] = true; return end
        display.unit = unit; display.context.unit = unit
    end

    for _, container in ipairs({ display.major, display.immunity }) do
        container:Show(); pcall(container.SetEnabled, container, true); pcall(container.UpdateAllAuras, container)
    end

    local objectiveEnabled = false
    SetObjectiveHostsShown(display, objectiveEnabled)
    for _, container in ipairs({ display.objectiveDamage, display.objectiveHealth }) do
        if container then
            pcall(container.SetEnabled, container, objectiveEnabled)
            container:SetShown(objectiveEnabled)
            if objectiveEnabled then pcall(container.UpdateAllAuras, container) end
        end
    end
end

function Defensives.ApplySettings()
    if IsManagedAuraLayoutRestricted() then
        settingsRefreshPending = true
        if previewFrame and previewFrame:IsShown() then Defensives.UpdatePreview() end
        return false
    end
    settingsRefreshPending = false
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
    if plates then
        for _, plate in ipairs(plates) do
            local frame = BM.GetVisualFrame(plate)
            UpdateHealerControl(plate, frame, frame and BM.ResolvePlateUnit(plate, frame))
        end
    end
    for frame, display in pairs(DISPLAY_BY_FRAME) do
        PositionAnchor(display.anchor, display.plate, frame)
        SetObjectiveHostsShown(display, false)
    end
    for button, regions in pairs(BUTTON_REGIONS) do
        -- Do not treat a forbidden AuraButton as an addon-owned settings target.
        -- Its initial geometry/art remains valid and Blizzard continues to own its
        -- aura visibility. A future plate/button initialization will use the latest
        -- settings without risking a forbidden-object mutation here.
        if IsForbiddenObject(button) then
            BUTTON_REGIONS[button] = nil
        elseif regions.kind == "MAJOR" then
            ApplyMajorSettings(button, regions)
        else
            ApplyImmunitySettings(button, regions)
        end
    end
    if previewFrame and previewFrame:IsShown() then Defensives.UpdatePreview() end
    return true
end

function Defensives.RefreshAll()
    local plates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
    if plates then for _, plate in ipairs(plates) do Defensives.UpdatePlate(plate) end end
end

function Defensives.Initialize()
    if not (InCombatLockdown and InCombatLockdown()) then
        EnsureAuraAPI()
    end
end

function Defensives.OnCombatEnded()
    -- Initial warning setup/unit binding can resume out of combat, including
    -- inside PvP. Existing forbidden warning artwork is still left untouched.
    for plate in pairs(PENDING_PLATES) do
        local frame = BM.GetVisualFrame(plate)
        UpdateHealerControl(plate, frame, frame and BM.ResolvePlateUnit(plate, frame))
    end
    if IsManagedAuraLayoutRestricted() then return end
    for plate in pairs(PENDING_PLATES) do PENDING_PLATES[plate] = nil; Defensives.UpdatePlate(plate) end
    if settingsRefreshPending then Defensives.ApplySettings() end
end

local function GetPreviewTexture()
    local configured = tonumber(CFG.friendlyTestSpecID)
    if configured and BM.GetCustomSpecTexture then
        local texture = BM.GetCustomSpecTexture(configured)
        if texture then return texture end
    end

    local index = GetSpecialization and GetSpecialization()
    local specID = index and GetSpecializationInfo and GetSpecializationInfo(index)
    return specID and BM.GetCustomSpecTexture and BM.GetCustomSpecTexture(specID) or 134400
end

local function GetPreviewClassFile()
    local configured = tostring(CFG.friendlyTestClass or "")
    if configured ~= "" and (RAID_CLASS_COLORS and RAID_CLASS_COLORS[configured]) then
        return configured
    end
    return GetFriendlyClass("player") or "WARRIOR"
end

local function GetPreviewObjectiveInfo()
    return OBJECTIVE_PREVIEW_INFO[tostring(CFG.friendlyPreviewObjective or "NONE"):upper()]
end

local function StopObjectivePreviewAnimations(root)
    if not root then return end
    for _, texture in ipairs({ root.objectiveIcon, root.objectiveGlow }) do
        if texture and texture.BMPulse then
            texture.BMPulse:Stop()
        end
    end
end

local function ConfigureObjectivePreviewPulse(texture, enabled, minAlpha, maxAlpha, duration)
    if not texture then return end

    if not texture.BMPulse then
        local group = texture:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        local up = group:CreateAnimation("Alpha")
        up:SetOrder(1); up:SetSmoothing("IN_OUT")
        local down = group:CreateAnimation("Alpha")
        down:SetOrder(2); down:SetSmoothing("IN_OUT")
        texture.BMPulse, texture.BMPulseUp, texture.BMPulseDown = group, up, down
    end

    texture.BMPulse:Stop()
    if not enabled then
        texture:SetAlpha(maxAlpha)
        return
    end

    texture.BMPulseUp:SetFromAlpha(minAlpha); texture.BMPulseUp:SetToAlpha(maxAlpha); texture.BMPulseUp:SetDuration(duration)
    texture.BMPulseDown:SetFromAlpha(maxAlpha); texture.BMPulseDown:SetToAlpha(minAlpha); texture.BMPulseDown:SetDuration(duration)
    texture:SetAlpha(minAlpha)
    texture.BMPulse:Play()
end

local function ApplyObjectivePreviewSettings(root)
    if not root or not root.objective then return end

    local objectiveInfo = GetPreviewObjectiveInfo()
    if not objectiveInfo then
        StopObjectivePreviewAnimations(root)
        root.objective:Hide()
        return
    end

    local iconSize = GetIconSize()
    local size = math.max(12, math.floor(iconSize * Clamp(CFG.objectivesBadgeScale or .72, .35, 1.6) + .5))
    local radians = math.rad((tonumber(CFG.objectivesAngle) or 42) % 360)
    local distance = iconSize * Clamp(CFG.objectivesDistanceScale or .53, 0, 1.5)
    local inFront = tostring(CFG.objectivesLayer or "BEHIND"):upper() == "FRONT"
    local textureKey = tostring(CFG.objectivesBorderTexture or "COGWHEEL"):upper()
    local borderTexture = BORDER_TEXTURES[textureKey]
    local borderSize = math.max(size, math.floor(size * Clamp(CFG.objectivesBorderScale or 1.18, .9, 1.8) * (BORDER_FIT[textureKey] or 1) + .5))

    root.objective:ClearAllPoints()
    root.objective:SetPoint("CENTER", root.anchor, "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
    root.objective:SetSize(size, size)
    root.objective:SetFrameLevel(inFront and 540 or 499)

    root.objectiveBackplate:ClearAllPoints()
    root.objectiveBackplate:SetPoint("CENTER", root.objective, "CENTER")
    root.objectiveBackplate:SetSize(size * 1.08, size * 1.08)
    root.objectiveBackplate:SetAlpha(.82)

    root.objectiveIcon:ClearAllPoints()
    root.objectiveIcon:SetPoint("TOPLEFT", root.objective, "TOPLEFT")
    root.objectiveIcon:SetPoint("BOTTOMRIGHT", root.objective, "BOTTOMRIGHT")
    if root.objectiveIcon.SetAtlas then
        pcall(root.objectiveIcon.SetAtlas, root.objectiveIcon, objectiveInfo.atlas, false)
    end

    if borderTexture then
        local mode = tostring(CFG.objectivesBorderColorMode or "AUTO"):upper()
        local r, g, b
        if mode == "WHITE" then
            r, g, b = 1, 1, 1
        elseif mode == "CUSTOM" then
            r, g, b = Clamp(CFG.objectivesCustomR or .3, 0, 1), Clamp(CFG.objectivesCustomG or .72, 0, 1), Clamp(CFG.objectivesCustomB or 1, 0, 1)
        else
            r, g, b = GetClassColor(GetPreviewClassFile())
        end
        root.objectiveBorder:ClearAllPoints()
        root.objectiveBorder:SetPoint("CENTER", root.objective, "CENTER")
        root.objectiveBorder:SetSize(borderSize, borderSize)
        root.objectiveBorder:SetTexture(borderTexture)
        root.objectiveBorder:SetVertexColor(r, g, b, 1)
        root.objectiveBorder:SetAlpha(Clamp(CFG.objectivesBorderAlpha or 1, 0, 1))
        root.objectiveBorder:Show()
    else
        root.objectiveBorder:Hide()
    end

    local pulseEnabled = CFG.objectivesPulse ~= false
    ConfigureObjectivePreviewPulse(root.objectiveIcon, pulseEnabled, .82, 1, Clamp(CFG.objectivesPulseSpeed or .9, .15, 2.5))

    if CFG.objectivesGlowEnabled ~= false then
        local glowAlpha = Clamp(CFG.objectivesGlowAlpha or .46, 0, 1)
        local glowScale = Clamp(CFG.objectivesGlowScale or 2.25, 1, 3)
        root.objectiveGlow:ClearAllPoints()
        root.objectiveGlow:SetPoint("CENTER", root.objective, "CENTER")
        root.objectiveGlow:SetSize(size * glowScale, size * glowScale)
        root.objectiveGlow:SetTexture(OBJECTIVE_GLOW)
        root.objectiveGlow:SetVertexColor(objectiveInfo.r, objectiveInfo.g, objectiveInfo.b, 1)
        root.objectiveGlow:Show()
        ConfigureObjectivePreviewPulse(root.objectiveGlow, pulseEnabled, glowAlpha * .28, glowAlpha, Clamp(CFG.objectivesGlowSpeed or .9, .15, 2.5))
    else
        if root.objectiveGlow.BMPulse then root.objectiveGlow.BMPulse:Stop() end
        root.objectiveGlow:Hide(); root.objectiveGlow:SetAlpha(0)
    end

    root.objective:Show()
end

local function EnsurePreview()
    if previewFrame or InCombatLockdown and InCombatLockdown() then return previewFrame end

    local root = CreateFrame("Frame", nil, UIParent)
    root:SetSize(240, 210)
    root:SetFrameStrata("TOOLTIP")
    root:EnableMouse(false)

    local anchor = CreateFrame("Frame", nil, root)
    anchor:SetPoint("CENTER", root, "CENTER", 0, 12)
    anchor:SetSize(100, 100)
    anchor:SetFrameStrata("TOOLTIP")
    anchor:SetFrameLevel(500)

    -- Missing-health layer. The full-color layer below is clipped from the
    -- bottom upward by the configured Preview Health percentage.
    local damagedBase = root:CreateTexture(nil, "ARTWORK", nil, 1)
    damagedBase:SetPoint("CENTER", anchor)
    damagedBase:SetSize(100, 100)
    damagedBase:SetTexCoord(.04, .96, .04, .96)
    local damagedMask = root:CreateMaskTexture(nil, "ARTWORK")
    damagedMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    damagedMask:SetAllPoints(damagedBase)
    damagedBase:AddMaskTexture(damagedMask)

    local healerDamagedCross = root:CreateTexture(nil, "ARTWORK", nil, 2)
    healerDamagedCross:SetPoint("CENTER", anchor, "CENTER")
    healerDamagedCross:Hide()

    local healthClip = CreateFrame("Frame", nil, root)
    healthClip:SetPoint("BOTTOM", anchor, "BOTTOM")
    healthClip:SetSize(100, 60)
    healthClip:SetFrameStrata("TOOLTIP")
    healthClip:SetFrameLevel(502)
    if healthClip.SetClipsChildren then healthClip:SetClipsChildren(true) end
    healthClip:EnableMouse(false)

    local healthArt = CreateFrame("Frame", nil, healthClip)
    healthArt:SetFrameLevel(503)
    healthArt:EnableMouse(false)
    healthArt:SetAllPoints(anchor)
    local healthIcon = healthArt:CreateTexture(nil, "ARTWORK", nil, 1)
    healthIcon:SetAllPoints()
    healthIcon:SetTexCoord(.04, .96, .04, .96)
    local healthMask = healthArt:CreateMaskTexture()
    healthMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    healthMask:SetAllPoints(healthArt)
    healthIcon:AddMaskTexture(healthMask)

    local healerHealthyCross = healthArt:CreateTexture(nil, "ARTWORK", nil, 2)
    healerHealthyCross:SetPoint("CENTER", healthArt, "CENTER")
    healerHealthyCross:Hide()

    local healerCCBadge = CreateFrame("Frame", nil, anchor)
    healerCCBadge:SetFrameStrata("TOOLTIP")
    healerCCBadge:SetFrameLevel(506)
    healerCCBadge:EnableMouse(false)
    healerCCBadge:Hide()
    local healerCCBack = healerCCBadge:CreateTexture(nil, "BACKGROUND", nil, 0)
    healerCCBack:SetTexture(WHITE_TEXTURE); healerCCBack:SetVertexColor(.01, .01, .015, .92); healerCCBack:SetAllPoints()
    local healerCCBackMask = healerCCBadge:CreateMaskTexture(); healerCCBackMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); healerCCBackMask:SetAllPoints(); healerCCBack:AddMaskTexture(healerCCBackMask)
    local healerCCIcon = healerCCBadge:CreateTexture(nil, "ARTWORK", nil, 1)
    healerCCIcon:SetAllPoints(); healerCCIcon:SetTexCoord(.06, .94, .06, .94)
    local healerCCIconMask = healerCCBadge:CreateMaskTexture(); healerCCIconMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); healerCCIconMask:SetAllPoints(); healerCCIcon:AddMaskTexture(healerCCIconMask)
    local healerCCBorder = healerCCBadge:CreateTexture(nil, "OVERLAY", nil, 5); healerCCBorder:SetTexture(BORDER_TEXTURES.NORMAL)
    local healerCCGlow = healerCCBadge:CreateTexture(nil, "OVERLAY", nil, 4); healerCCGlow:SetTexture(BORDER_TEXTURES.NORMAL); healerCCGlow:SetBlendMode("ADD"); healerCCGlow:SetAlpha(.32)

    local classRing = root:CreateTexture(nil, "OVERLAY", nil, 5)
    classRing:SetPoint("CENTER", anchor)

    local major = CreateFrame("Frame", nil, anchor); major:SetFrameStrata("TOOLTIP")
    local majorRegions = CreateMajorRegions(major, { unit="player" }, "EVOKER", false)
    local immunity = CreateFrame("Frame", nil, anchor); immunity:SetFrameStrata("TOOLTIP")
    local immunityRegions = CreateImmunityRegions(immunity, false)

    local objective = CreateFrame("Frame", nil, anchor); objective:SetFrameStrata("TOOLTIP"); objective:Hide()
    local objectiveBackplate = objective:CreateTexture(nil, "BACKGROUND", nil, 0); objectiveBackplate:SetTexture(WHITE_TEXTURE); objectiveBackplate:SetVertexColor(0, 0, 0, 1)
    local objectiveIcon = objective:CreateTexture(nil, "ARTWORK", nil, 1)
    local objectiveMask = objective:CreateMaskTexture(); objectiveMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"); objectiveMask:SetAllPoints(objective)
    objectiveBackplate:AddMaskTexture(objectiveMask); objectiveIcon:AddMaskTexture(objectiveMask)
    local objectiveBorder = objective:CreateTexture(nil, "OVERLAY", nil, 3)
    local objectiveGlow = objective:CreateTexture(nil, "OVERLAY", nil, 4); objectiveGlow:SetBlendMode("ADD"); objectiveGlow:Hide()

    root.label = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    root.label:SetPoint("TOP", anchor, "BOTTOM", 0, -18)
    root.label:SetText("Friendly Preview")

    root.anchor = anchor
    root.damagedBase, root.damagedMask = damagedBase, damagedMask
    root.healerDamagedCross = healerDamagedCross
    root.healthClip, root.healthIcon, root.healthMask = healthClip, healthIcon, healthMask
    root.healthArt = healthArt
    root.healerHealthyCross = healerHealthyCross
    root.healerCCBadge, root.healerCCBack, root.healerCCIcon = healerCCBadge, healerCCBack, healerCCIcon
    root.healerCCBorder, root.healerCCGlow = healerCCBorder, healerCCGlow
    root.classRing = classRing
    root.major, root.majorRegions = major, majorRegions
    root.immunity, root.immunityRegions = immunity, immunityRegions
    root.objective, root.objectiveBackplate, root.objectiveIcon, root.objectiveBorder, root.objectiveGlow = objective, objectiveBackplate, objectiveIcon, objectiveBorder, objectiveGlow

    previewFrame = root
    return root
end

function Defensives.UpdatePreview()
    local root = previewFrame
    if not root then return end

    if CFG.friendlyTestMode ~= true then
        StopObjectivePreviewAnimations(root)
        root:Hide()
        return
    end

    local anchorPoint = CFG.friendlyTestAnchorPoint or "CENTER"
    root:ClearAllPoints()
    root:SetPoint(anchorPoint, UIParent, anchorPoint, tonumber(CFG.friendlyTestXOffset) or 0, tonumber(CFG.friendlyTestYOffset) or 120)

    local size = GetIconSize()
    local faded = CFG.friendlyTestLOS == true
    local healthPercent = Clamp(CFG.friendlyTestHealthPercent or 62, 0, 100)
    local texture = GetPreviewTexture()
    local healer = CFG.healerCrossEnabled == true and BM.IsHealerUnit(nil, tonumber(CFG.friendlyTestSpecID))
    if healer then texture = BM.HealerBackgroundTexture end
    local texStart, texEnd = healer and 0 or .04, healer and 1 or .96

    root.anchor:SetSize(size, size)

    root.damagedBase:SetSize(size, size)
    root.damagedBase:SetTexture(texture)
    root.damagedBase:SetTexCoord(texStart, texEnd, texStart, texEnd)
    root.damagedBase:SetBlendMode(faded and (CFG.losDamageIconBlendMode or CFG.damageIconBlendMode or "BLEND") or (CFG.damageIconBlendMode or "BLEND"))
    root.damagedBase:SetVertexColor(CFG.damageIconR or 1, CFG.damageIconG or .02, CFG.damageIconB or .02, 1)
    root.damagedBase:SetAlpha(Clamp(faded and (CFG.losDamageIconAlpha or CFG.damageIconAlpha or 1) or (CFG.damageIconAlpha or 1), 0, 1))

    local fillHeight = size * (healthPercent / 100)
    local fillAnchor = CFG.healthOverlayReverseFill == true and "TOP" or "BOTTOM"
    root.healthClip:ClearAllPoints()
    root.healthClip:SetPoint(fillAnchor, root.anchor, fillAnchor)
    root.healthClip:SetSize(size, math.max(.1, fillHeight))
    root.healthIcon:SetTexture(texture)
    root.healthIcon:SetTexCoord(texStart, texEnd, texStart, texEnd)
    root.healthIcon:SetDesaturated(faded and CFG.losSpecIconDesaturate == true or CFG.specIconDesaturate == true)
    root.healthIcon:SetBlendMode(faded and (CFG.losSpecIconBlendMode or CFG.specIconBlendMode or "BLEND") or (CFG.specIconBlendMode or "BLEND"))
    root.healthIcon:SetVertexColor(1, 1, 1, 1)
    root.healthIcon:SetAlpha(Clamp(faded and (CFG.losSpecIconAlpha or CFG.specIconAlpha or 1) or (CFG.specIconAlpha or 1), 0, 1))
    root.healthClip:SetShown(healthPercent > 0 and CFG.specIconEnabled ~= false and CFG.healthEnable ~= false)

    local healerCrossAlpha = Clamp(faded and (CFG.losSpecIconAlpha or CFG.specIconAlpha or 1) or (CFG.specIconAlpha or 1), 0, 1)
    local healerCrossSize = size * (CFG.healerCrossScale or .9)
    if healer and CFG.specIconEnabled ~= false then
        root.healthIcon:SetVertexColor(BM.GetHealerBackgroundColor(nil, GetPreviewClassFile()))
        root.healthIcon:SetBlendMode("BLEND")

        root.healerDamagedCross:SetSize(healerCrossSize, healerCrossSize)
        BM.SetHealerCrossArt(root.healerDamagedCross, CFG.healthEnable ~= false)
        root.healerDamagedCross:SetAlpha(healerCrossAlpha)
        root.healerDamagedCross:Show()

        root.healerHealthyCross:SetSize(healerCrossSize, healerCrossSize)
        BM.SetHealerCrossArt(root.healerHealthyCross, false)
        root.healerHealthyCross:SetAlpha(healerCrossAlpha)
        root.healerHealthyCross:SetShown(CFG.healthEnable ~= false and healthPercent > 0)

        if CFG.healthEnable == false then
            root.damagedBase:SetVertexColor(BM.GetHealerBackgroundColor(nil, GetPreviewClassFile()))
            root.damagedBase:SetBlendMode("BLEND")
            root.damagedBase:SetAlpha(healerCrossAlpha)
        end
    else
        root.healerDamagedCross:Hide()
        root.healerHealthyCross:Hide()
    end

    local showCCBadge = healer and CFG.specIconEnabled ~= false and CFG.healerControlEnabled == true and CFG.friendlyTestHealerControl == true
    if showCCBadge then
        local badgeSize = math.max(12, math.floor(size * Clamp(CFG.healerControlBadgeScale or .64, .35, 1.4) + .5))
        local distance = size * Clamp(CFG.healerControlDistanceScale or .58, 0, 1.5)
        local radians = math.rad((tonumber(CFG.healerControlAngle) or 138) % 360)
        root.healerCCBadge:ClearAllPoints()
        root.healerCCBadge:SetPoint("CENTER", root.anchor, "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
        root.healerCCBadge:SetSize(badgeSize, badgeSize)
        root.healerCCIcon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(118) or 136071)
        root.healerCCBorder:ClearAllPoints(); root.healerCCBorder:SetPoint("TOPLEFT", root.healerCCBadge, "TOPLEFT", -3, 3); root.healerCCBorder:SetPoint("BOTTOMRIGHT", root.healerCCBadge, "BOTTOMRIGHT", 3, -3)
        root.healerCCGlow:ClearAllPoints(); root.healerCCGlow:SetPoint("TOPLEFT", root.healerCCBadge, "TOPLEFT", -5, 5); root.healerCCGlow:SetPoint("BOTTOMRIGHT", root.healerCCBadge, "BOTTOMRIGHT", 5, -5)
        local cr, cg, cb = CFG.healerControlR or 1, CFG.healerControlG or .65, CFG.healerControlB or .06
        root.healerCCBorder:SetVertexColor(cr, cg, cb, 1)
        root.healerCCGlow:SetVertexColor(cr, cg, cb, 1)
        root.healerCCBadge:Show()
    else
        root.healerCCBadge:Hide()
    end

    if CFG.ringEnabled == false then
        root.classRing:Hide()
    else
        local normalFile = CFG.ringTexture or "Ring_20px"
        local losFile = CFG.losRingTexture or "SAME"
        local file = faded and losFile ~= "SAME" and losFile or normalFile
        local fit = BM.GetFriendlyBorderFit and BM.GetFriendlyBorderFit(file) or 1.10
        local fineTune = tonumber(CFG.ringFineTune) or 1
        local textureFile = BM.GetFriendlyBorderTextureName and BM.GetFriendlyBorderTextureName(file) or file
        local ringSize = math.floor(size * fit * fineTune + .5)
        local r, g, b = GetClassColor(GetPreviewClassFile())
        root.classRing:SetSize(ringSize, ringSize)
        root.classRing:SetTexture("Interface\\AddOns\\BattleMender\\Textures\\" .. textureFile .. ".tga")
        root.classRing:SetVertexColor(r, g, b, 1)
        root.classRing:SetAlpha(Clamp(faded and (CFG.losRingAlpha or CFG.ringAlpha or 1) or (CFG.ringAlpha or 1), 0, 1))
        root.classRing:Show()
    end

    ApplyMajorSettings(root.major, root.majorRegions)
    ApplyImmunitySettings(root.immunity, root.immunityRegions)
    ApplyObjectivePreviewSettings(root)

    root.majorRegions.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(357170) or 134400)
    root.immunityRegions.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(642) or 134400)
    root.immunityRegions.cooldown:SetCooldown(GetTime(), 8)

    local aura = tostring(CFG.friendlyPreviewAura or "NONE"):upper()
    root.major:SetShown(aura == "MAJOR" or aura == "BOTH")
    root.immunity:SetShown(aura == "IMMUNITY" or aura == "BOTH")

    local objectiveInfo = GetPreviewObjectiveInfo()
    root.objective:SetShown(objectiveInfo ~= nil)
    if not objectiveInfo then StopObjectivePreviewAnimations(root) end

    local label = string.format("Friendly Preview  •  %d%% health", math.floor(healthPercent + .5))
    if faded then label = label .. "  •  LoS" end
    if healer and CFG.healerControlEnabled and CFG.friendlyTestHealerControl then label = label .. "  •  CC / Silence" end
    if objectiveInfo then label = label .. "  •  " .. objectiveInfo.label end
    if aura == "MAJOR" then label = label .. "  •  Major Aura"
    elseif aura == "IMMUNITY" then label = label .. "  •  Immunity"
    elseif aura == "BOTH" then label = label .. "  •  Major + Immunity" end
    root.label:SetText(label)
    root:Show()
end

function Defensives.ShowPreview(kind)
    if InCombatLockdown and InCombatLockdown() then return end
    local root = EnsurePreview()
    if not root then return end

    kind = tostring(kind or "CURRENT"):upper()
    if kind == "HEALER" then
        CFG.friendlyTestSpecID = 65
        CFG.friendlyTestClass = "PALADIN"
        CFG.friendlyPreviewObjective = "NONE"
        CFG.friendlyPreviewAura = "NONE"
        CFG.friendlyTestHealerControl = false
    elseif kind == "OBJECTIVE" then
        if tostring(CFG.friendlyPreviewObjective or "NONE"):upper() == "NONE" then
            CFG.friendlyPreviewObjective = "ORB_PURPLE"
        end
        CFG.friendlyPreviewAura = "NONE"
    elseif kind == "MAJOR" then
        CFG.friendlyPreviewAura = "MAJOR"
    elseif kind == "IMMUNITY" then
        CFG.friendlyPreviewAura = "IMMUNITY"
    elseif kind == "BOTH" then
        CFG.friendlyPreviewAura = "BOTH"
    end

    CFG.friendlyTestMode = true
    Defensives.UpdatePreview()
    root:Show()
end

function Defensives.HidePreview()
    CFG.friendlyTestMode = false
    CFG.friendlyTestHealerControl = false
    if previewFrame then
        StopObjectivePreviewAnimations(previewFrame)
        previewFrame:Hide()
    end
end

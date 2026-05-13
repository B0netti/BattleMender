-- BattleMender.lua
-- Stable baseline build
-- ElvUI independant
-- Wow 12.0.5

BattleMender = BattleMender or {}

local ADDON = CreateFrame("Frame", "BattleMenderFrame")
BattleMender.Frame = ADDON

local INIT_DONE = false


-------------------------------------------------
-- Tier 3 & 4 Prep: Caches, Dictionary, and Tooltip
-------------------------------------------------
BattleMender.SpecCache = BattleMender.SpecCache or {}
local SpecNamesToID = {}

-- Build the dynamic dictionary of all specs
local function BuildSpecDictionary()
    for classID = 1, 13 do
        for i = 1, 4 do
            local id, name = GetSpecializationInfoForClassID(classID, i)
            if id and name then
                -- Store by localized name (e.g., ["Holy"] = 65)
                SpecNamesToID[name] = id
            end
        end
    end
end
BuildSpecDictionary()

-- The hidden tooltip for scraping
local SCAN_TOOLTIP = CreateFrame("GameTooltip", "BattleMenderScanTooltip", nil, "GameTooltipTemplate")
SCAN_TOOLTIP:SetOwner(UIParent, "ANCHOR_NONE")

-------------------------------------------------
-- The Spec Engine (Tiers 1 - 4)
-------------------------------------------------
function BattleMender.GetUnitSpecID(unit, guid)
    if not guid then return nil end

    -- TIER 1: The Native Instants
    if UnitIsUnit(unit, "player") then
        local currentSpec = GetSpecialization()
        if currentSpec then
            return GetSpecializationInfo(currentSpec)
        end
    end

    if UnitInParty(unit) or UnitInRaid(unit) then
        local specID = GetInspectSpecialization(unit)
        if specID and specID > 0 then
            BattleMender.SpecCache[guid] = specID
            return specID
        end
    end

    -- TIER 2: The Hive Mind (Details! Cache)
    if _G.Details and _G.Details.cached_specs and _G.Details.cached_specs[guid] then
        local specID = _G.Details.cached_specs[guid]
        BattleMender.SpecCache[guid] = specID
        return specID
    end
    -- (Note: ElvUI's internal oUF spec tags are heavily shielded. Details! is your most reliable external cache).

    -- TIER 3: Local Memory
    if BattleMender.SpecCache[guid] then
        return BattleMender.SpecCache[guid]
    end

    -- TIER 4: The Tooltip Scrape
    SCAN_TOOLTIP:ClearLines()
    SCAN_TOOLTIP:SetUnit(unit)
    
    -- Scan the first few lines of the tooltip (usually line 2 or 3 holds "Level 70 Holy Paladin")
    for i = 2, math.min(4, SCAN_TOOLTIP:NumLines()) do
        local line = _G["BattleMenderScanTooltipTextLeft"..i]
        if line and line:GetText() then
            local text = line:GetText()
            for specName, specID in pairs(SpecNamesToID) do
                -- If the tooltip text contains the spec name
                if string.find(text, specName) then
                    BattleMender.SpecCache[guid] = specID
                    return specID
                end
            end
        end
    end

    -- If we made it here, we failed. Time for Tier 5.
    return nil
end

-------------------------------------------------
-- TIER 5: The Safety Net (Background Inspect)
-------------------------------------------------
BattleMender.InspectQueue = {}
local InspectEngine = CreateFrame("Frame")
InspectEngine:RegisterEvent("INSPECT_READY")

local currentInspectUnit = nil
local currentInspectGUID = nil
local timeSinceLastInspect = 0

-- Throttle the inspects to 1 per 1.5 seconds
InspectEngine:SetScript("OnUpdate", function(self, elapsed)
    if not currentInspectUnit and #BattleMender.InspectQueue > 0 then
        timeSinceLastInspect = timeSinceLastInspect + elapsed
        
        if timeSinceLastInspect > 1.5 then 
            local nextTarget = table.remove(BattleMender.InspectQueue, 1)
            
            if UnitExists(nextTarget.unit) and CanInspect(nextTarget.unit) then
                currentInspectUnit = nextTarget.unit
                currentInspectGUID = nextTarget.guid
                NotifyInspect(nextTarget.unit)
                timeSinceLastInspect = 0
            end
        end
    end
end)

-- Catch the result
InspectEngine:SetScript("OnEvent", function(self, event, guid)
    if event == "INSPECT_READY" and guid == currentInspectGUID then
        local specID = GetInspectSpecialization(currentInspectUnit)
        
        if specID and specID > 0 then
            BattleMender.SpecCache[guid] = specID
            -- Force a visual refresh now that we have the data!
            BattleMender.RefreshAll()
        end
        
        ClearInspectPlayer()
        currentInspectUnit = nil
        currentInspectGUID = nil
    end
end)

function BattleMender.QueueInspect(unit, guid)
    -- Prevent duplicate queuing
    for _, v in ipairs(BattleMender.InspectQueue) do
        if v.guid == guid then return end
    end
    table.insert(BattleMender.InspectQueue, {unit = unit, guid = guid})
end

-------------------------------------------------
-- Plate Cleaner Pipeline
-------------------------------------------------
function BattleMender.CleanPlate(frame)
    if not frame then return end
    
    local overlay = frame.BattleMender
    if overlay then
        if overlay.bg then overlay.bg:Hide() end
        if overlay.low then overlay.low:Hide() end
        if overlay.mid then overlay.mid:Hide() end
        if overlay.high then overlay.high:Hide() end
        if overlay.debugBox then overlay.debugBox:Hide() end
        
        -- Hide your custom health bar
        if overlay.healthBar then overlay.healthBar:Hide() end
    end
end

-------------------------------------------------
-- Saved Variables
-------------------------------------------------

BattleMenderDB = BattleMenderDB or {}

local defaults = {
    -- General
    enabled = true,
    debug = false,
    updateRate = 0.05,
    clickSize = 70,
    showClickbox = false,
	disableBGPortrait = false,

    -- Anchors & Positioning
    iconSize = 45,
    anchorMode = "TOP",
    anchorPoint = "CENTER",
    anchorX = 0,
    anchorY = 0,

    -- Base Icon
    iconTextureMode = "SOLID",
    iconAlpha = 0.85,
    iconDesaturate = false,
    iconUseClassColor = false,
    iconColorR = 0.84,
    iconColorG = 0.05,
    iconColorB = 0,

    -- Top Icon
    topIconEnable = true,
    topIconTextureMode = "SPEC",
    topIconAlpha = 1,
    topIconDesaturate = false,
    topIconUseClassColor = false,
    topIconColorR = 1,
    topIconColorG = 1,
    topIconColorB = 1,
    topIconBlendMode = "MOD",

    -- Border / Ring
    borderEnable = true,
    borderScale = 1.09,
    borderAlpha = 1,

    -- Normal Health
    healthEnable = true,
    healthTextureMode = "SOLID",
    healthAlpha = 1,
    healthBlendMode = "BLEND",
    healthUseClassColor = false,
    healthColorR = 1,
    healthColorG = 1,
    healthColorB = 1,
    healthCropIcons = false,
    healthReverseFill = false,

    -- Hover / Mouseover (General)
    hoverEnable = true,
    hoverSpeed = 0.85,
    hoverBrightness = 0.45,
    hoverGlowSize = 2.5,
    hoverGlowAlpha = 1,

    -- Hover / Mouseover (Top Icon)
    hoverTopEnable = true,
    hoverTopBrightness = 0.4,
    hoverTopFadeIn = 0,
    hoverTopFadeOut = 0.2,
    hoverTopBlend = "ADD",

    -- Hover / Mouseover (Ring)
    hoverRingEnable = true,
    hoverRingBrightness = 0.4,
    hoverRingFadeIn = 0.05,
    hoverRingFadeOut = 0.1,
    hoverRingBlend = "ADD",

    -- Normal Pulse Animation
    pulseEnable = true,
    pulseSpeed = 0.2,
    pulseIntensity = 0.35,
    pulseOverlayEnable = true,
    pulseOverlayTexture = "Circle_AlphaGradient_In",
    pulseOverlayBlend = "ADD",
    pulseOverlayAlpha = 1,
    
    -- Hover / Mouseover (HALO GLOW)
    haloGlowTexture = "Circle_Halo_1",
    haloGlowSizeScale = 2.9,
    haloGlowAlpha = 1,
    haloEnable = true,
    
    -- Line of Sight (LoS) - Base & Top Icons
    losIconAlpha = 1,
    losIconDesaturate = false,
    losTopIconAlpha = 1,
    losTopIconDesaturate = false,
    losTopIconBlendMode = "BLEND",

    -- Line of Sight (LoS) - Health & Border
    losHealthAlpha = 1,
    losHealthBlendMode = "ADD",
    losHealthUseClassColor = false,
    losHealthColorR = 0.07,
    losHealthColorG = 0.40,
    losHealthColorB = 0.42,
    losBorderAlpha = 1,

    -- Line of Sight (LoS) - Pulse Animation
    losPulseEnable = false,
    losPulseSpeed = 0.3,
    losPulseIntensity = 0.8,
    losPulseOverlayEnable = false,
    losPulseOverlayTexture = "Circle_AlphaGradient_In",
    losPulseOverlayBlend = "ADD",
    losPulseOverlayAlpha = 1,
}

local CFG = {}
BattleMender.CFG = CFG 

local TEXTURE_MODES = {
    { text = "Spec Icon",  value = "SPEC"  },
    { text = "Class Icon", value = "CLASS" },
    { text = "Solid",      value = "SOLID" },
}

local TOP_TEXTURE_MODES = {
    { text = "Spec Icon", value = "SPEC" },
    { text = "Solid",     value = "SOLID" },
    { text = "Disabled",  value = "NONE" },
}

local BLEND_MODES = {
    { text = "Normal",   value = "BLEND"   },
    { text = "Additive", value = "ADD"     },
    { text = "Multiply", value = "MOD"     },
    { text = "Raw",      value = "DISABLE" },
}

local PULSE_TEXTURES = {
    ["Circle_AlphaGradient_In"] = "Gradient In",
    ["Circle_AlphaGradient_Out"] = "Gradient Out",
    ["Circle_Smooth2"] = "Smooth 2",
}

local HALO_TEXTURES = {
    ["Circle_Halo_1"] = "Interface\\AddOns\\BattleMender\\Textures\\Circle_Halo_2.tga",
}

local ANCHOR_MODES = {
    { text = "Top",    value = "TOP"    },
    { text = "Center", value = "CENTER" },
}

-- Debug print  /run BattleMender.CFG.debug=true
local function Debug(...)
    if not CFG.debug then
        return
    end
    
    print("|cff33ff99BattleMender:|r", ...)
end

BattleMender.Debug = Debug

-------------------------------------------------
-- Config load/save
-------------------------------------------------

function BattleMender.LoadDB()
    for k,v in pairs(defaults) do
        if BattleMenderDB[k] == nil then
            BattleMenderDB[k] = v
        end
        CFG[k] = BattleMenderDB[k]
    end
end

function BattleMender.SaveDB()
    for k,v in pairs(CFG) do
        BattleMenderDB[k] = v
    end
end

function BattleMender.SaveRefresh()
    BattleMender.SaveDB()
    BattleMender.RefreshAll()
end

-------------------------------------------------
-- Helpers
-------------------------------------------------
--HELPER 
local function CopyOptions(src, extra)
    local out = {}

    for i, v in ipairs(src) do
        out[#out + 1] = v
    end

    if extra then
        for i, v in ipairs(extra) do
            out[#out + 1] = v
        end
    end

    return out
end

--HELPER For dropdown text
function BattleMender.GetOptionText(options, value)
    for _, opt in ipairs(options) do
        if opt.value == value then
            return opt.text
        end
    end
    return tostring(value)
end

-- Global sleep flag
BattleMender.IsSleeping = false

-- Detect restricted instances (Dungeons and Raids)
function BattleMender.UpdateInstanceStatus()
    local inInstance, instanceType = IsInInstance()
    
    -- "party" = 5-man dungeon, "raid" = raid instance
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        BattleMender.IsSleeping = true
    else
        BattleMender.IsSleeping = false
    end

    if BattleMender.IsSleeping then
        BattleMender.Debug("sleeping")
        SetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", 1) 
        SetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", 1) 
    end 
    
    -- NEW: Automated BG Portrait Toggler
    if CFG.disableBGPortrait and _G.ElvUI then
        local E = unpack(_G.ElvUI)
        local NP = E:GetModule("NamePlates")
        
        if inInstance and instanceType == "pvp" then
            -- Cache original user setting so we can restore it later
            if not BattleMender.BGPortraitCached then
                BattleMender.BGOriPortrait = E.db.nameplates.units.ENEMY_PLAYER.portrait.enable
                BattleMender.BGPortraitCached = true
            end
            -- Turn it off
            if E.db.nameplates.units.ENEMY_PLAYER.portrait.enable then
                E.db.nameplates.units.ENEMY_PLAYER.portrait.enable = false
                if NP then NP:ConfigureAll() end
            end
        elseif BattleMender.BGPortraitCached then
            -- Leaving BG, restore original setting
            E.db.nameplates.units.ENEMY_PLAYER.portrait.enable = BattleMender.BGOriPortrait
            BattleMender.BGPortraitCached = false
            if NP then NP:ConfigureAll() end
        end
    end
end

--HELPER 
local function IsFriendlyPlayer(unit)
    return unit
        and UnitExists(unit)
        and UnitIsPlayer(unit)
        and UnitIsFriend("player", unit)
end
--HELPER 
local function ClassColor(unit)
    local _, class = UnitClass(unit)
    local c = class and RAID_CLASS_COLORS[class]
    return c or NORMAL_FONT_COLOR
end
--HELPER 
local function ClassIcon(unit)
    local _, class = UnitClass(unit)
    if not class then return nil end

    return
        "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        CLASS_ICON_TCOORDS[class]
end
--HELPER 
local function GetVisualFrame(plate)
    if _G.ElvUI then
        local elv = _G["ElvNP_" .. plate:GetName()]
        if elv then return elv end
    end

    return plate.UnitFrame or plate
end
--HELPER 
local function GetHealthBar(frame)
    if frame.Health and frame.Health.SetOrientation then
        return frame.Health
    end

    if frame.healthBar and frame.healthBar.SetOrientation then
        return frame.healthBar
    end

    return nil
end

--HELPER Custom spec textures
local SPEC_PATH = "Interface\\AddOns\\BattleMender\\Textures\\Specs\\"

local function GetCustomSpecTexture(specID)
    if not specID then return nil end
    return SPEC_PATH .. specID .. ".tga"
end

--HELPER Consolidates duplicate anchor/positioning logic with Cache Guarding
local function PositionElement(element, parentFrame)
    local point = CFG.anchorPoint or "TOP"
    local x = CFG.anchorX or 0
    local y = CFG.anchorY or 0

    -- CACHE CHECK: If nothing changed, do NOT interrupt WoW's native rendering!
    if element.BMLastPoint == point and element.BMLastX == x and element.BMLastY == y and element.BMLastParent == parentFrame then
        return 
    end

    element:ClearAllPoints()
    element:SetPoint(point, parentFrame, point, x, y)

    -- Save state
    element.BMLastPoint = point
    element.BMLastX = x
    element.BMLastY = y
    element.BMLastParent = parentFrame
end

--HELPER Resolve texture + texcoords for overlays
local SPEC_FALLBACK_CLASS = {
    [62]="MAGE",[63]="MAGE",[64]="MAGE",
    [65]="PALADIN",[66]="PALADIN",[70]="PALADIN",
    [71]="WARRIOR",[72]="WARRIOR",[73]="WARRIOR",
    [102]="DRUID",[103]="DRUID",[104]="DRUID",[105]="DRUID",
    [250]="DEATHKNIGHT",[251]="DEATHKNIGHT",[252]="DEATHKNIGHT",
    [253]="HUNTER",[254]="HUNTER",[255]="HUNTER",
    [256]="PRIEST",[257]="PRIEST",[258]="PRIEST",
    [259]="ROGUE",[260]="ROGUE",[261]="ROGUE",
    [262]="SHAMAN",[263]="SHAMAN",[264]="SHAMAN",
    [265]="WARLOCK",[266]="WARLOCK",[267]="WARLOCK",
    [268]="MONK",[269]="MONK",[270]="MONK",
    [577]="DEMONHUNTER",[581]="DEMONHUNTER",
    [1467]="EVOKER",[1468]="EVOKER",[1473]="EVOKER",
}
--HELPER 
local function GetOverlayTexture(mode, unit, specID)

    if mode == "NONE" then
        return nil, nil
    end

    if mode == "SOLID" then
        return "Interface\\Buttons\\WHITE8X8", nil
    end

    if mode == "CLASS" then
        return ClassIcon(unit)
    end

    if mode == "SPEC" then
        if specID then
            local tex = GetCustomSpecTexture(specID)
            if tex then
                return tex, nil
            end
        end

        return nil, nil
    end

    return nil, nil
end

--HELPER Consolidates duplicate color-picking logic
local function GetOverlayColor(useClass, unit, defR, defG, defB)
    if useClass then
        local c = ClassColor(unit)
        return c.r, c.g, c.b
    end
    return defR or 1, defG or 1, defB or 1
end


--HELPER LoS Alpha
local function UpdateLOSVisuals(frame, overlay)
    return
end

--HELPER CREATE HOVER GLOW
local function CreateHoverGlow(parent)
    local glow = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetAllPoints()
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    glow:Hide()
    
    local ag = glow:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetSmoothing("IN_OUT")
    
    glow.anim = ag
    glow.fader = a1
    
    ag:SetScript("OnFinished", function(self)
        local tex = self:GetParent()
        tex:SetAlpha(self.targetAlpha)
        if self.targetAlpha == 0 then
            tex:Hide() -- Kills the light bleed entirely
        end
    end)
    
    return glow
end

local function FadeInGlow(tex, targetAlpha, duration)
    tex.anim:Stop()
    tex.anim.targetAlpha = targetAlpha
    tex:Show()
    
    if duration <= 0 then
        tex:SetAlpha(targetAlpha)
        return
    end
    
    tex:SetAlpha(0) -- CRITICAL: Prevents WoW from compounding base alpha
    tex.fader:SetFromAlpha(0)
    tex.fader:SetToAlpha(targetAlpha)
    tex.fader:SetDuration(duration)
    tex.anim:Play()
end

local function FadeOutGlow(tex, peakAlpha, duration)
    tex.anim:Stop()
    tex.anim.targetAlpha = 0
    
    if duration <= 0 then
        tex:SetAlpha(0)
        tex:Hide()
        return
    end
    
    tex:SetAlpha(0) -- CRITICAL: Prevents the mouse-out flash!
    tex.fader:SetFromAlpha(peakAlpha) 
    tex.fader:SetToAlpha(0)
    tex.fader:SetDuration(duration)
    tex.anim:Play()
end

-------------------------------------------------
-- Spec Inspector Engine & Hybrid Fetcher
-------------------------------------------------
BattleMender.SpecCache = {} 
local inspectQueue = {}
local lastInspectTime = 0
local INSPECT_DELAY = 1.5 

local InspectEngine = CreateFrame("Frame")

-- 1. The Queue Processor
InspectEngine:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if (now - lastInspectTime) > INSPECT_DELAY then
        if #inspectQueue > 0 then
            local unit = table.remove(inspectQueue, 1)
            
            if UnitExists(unit) and UnitIsPlayer(unit) and CanInspect(unit) then
                lastInspectTime = now
                NotifyInspect(unit) 
            end
        end
    end
end)

-- 2. The Server Response Listener
InspectEngine:RegisterEvent("INSPECT_READY")
InspectEngine:SetScript("OnEvent", function(self, event, guid)
    if event == "INSPECT_READY" then
        local specID = nil
        
        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
            local unit = nameplate.namePlateUnitToken
            if unit and UnitGUID(unit) == guid then
                specID = GetInspectSpecialization(unit)
                break
            end
        end
        
        if specID and specID > 0 then
            BattleMender.SpecCache[guid] = specID 
            ClearInspectPlayer() 
            if BattleMender.RefreshAll then BattleMender.RefreshAll() end
        end
    end
end)

-- 3. The Function to add a unit to the line
function BattleMender.QueueInspect(unit)
    local guid = UnitGUID(unit)
    if not guid or BattleMender.SpecCache[guid] then return end 
    
    for i = 1, #inspectQueue do
        if inspectQueue[i] == unit then return end 
    end
    table.insert(inspectQueue, unit)
end

-- 4. The Ultimate Hybrid Spec Fetcher
function BattleMender.GetSpecID(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end

    -- 1. Is it YOU? (Instant)
    if UnitIsUnit(unit, "player") then
        local specIndex = GetSpecialization()
        if specIndex then
            local specID = GetSpecializationInfo(specIndex)
            if specID then return specID end
        end
    end

    -- 2. Are they in your Party or Raid? (Instant, no queue needed!)
    if UnitInParty(unit) or UnitInRaid(unit) then
        local specID = GetInspectSpecialization(unit)
        if specID and specID > 0 then
            BattleMender.SpecCache[guid] = specID
            return specID
        end
    end

    -- 3. Try Details! 
    if _G.Details and _G.Details.cached_specs then
        local detailsSpec = _G.Details.cached_specs[guid]
        if detailsSpec then return detailsSpec end
    end

    -- 4. Try ElvUI (Crash-proof)
    if _G.ElvUI then
        local E = unpack(_G.ElvUI)
        if E and E.oUF and E.oUF.SpecCache then
            local elvSpec = E.oUF.SpecCache[guid]
            if elvSpec then return elvSpec end
        end
    end

    -- 5. Try Our Own Cache
    if BattleMender.SpecCache and BattleMender.SpecCache[guid] then
        return BattleMender.SpecCache[guid]
    end

    -- 6. We don't have it anywhere. Put them in our background queue.
    if BattleMender.QueueInspect then
        BattleMender.QueueInspect(unit)
    end

    return nil
end

-------------------------------------------------
-- options
-------------------------------------------------

BattleMender.Options = {
    TextureModes = CopyOptions(TEXTURE_MODES, {
        { text = "Disabled", value = "NONE" },
    }),

    TopTextureModes = TOP_TEXTURE_MODES,

    HealthTextureModes = {
        { text = "Solid", value = "SOLID" },
    },

    BlendModes = BLEND_MODES,
    HealthBlendModes = BLEND_MODES,
    AnchorModes = ANCHOR_MODES,

    PulseTextures = PULSE_TEXTURES,
}

-- Detect Instance Type and Role
function BattleMender.GetPlayerContext()
    local inInstance, instanceType = IsInInstance()
    local _, _, _, _, maxPlayers = GetInstanceInfo()
    
    local spec = GetSpecialization()
    local role = spec and GetSpecializationRole(spec) or "DAMAGER"
    
    local context = "DEFAULT"
    
    if inInstance then
        if instanceType == "pvp" then
            context = (maxPlayers == 40) and "EPIC_BG" or "BG"
        elseif instanceType == "arena" then
            context = "ARENA"
        end
    end
    
    return context, role
end

-- Example implementation of auto-applying defaults based on context
function BattleMender.ApplyContextDefaults()
    local context, role = BattleMender.GetPlayerContext()
    
    -- You can define differentiated defaults here based on the results
    if context == "ARENA" and role == "HEALER" then
        -- Apply Arena Healer specific CVars and Sizes
        CFG.iconSize = 60
        SetCVar("nameplateOverlapV", 0.8) -- Stacking CVar example
    elseif context == "EPIC_BG" then
        -- Make icons smaller for 40-man to reduce clutter
        CFG.iconSize = 35
    end
    
    BattleMender.SaveRefresh()
end

-------------------------------------------------
-- ENSURE Overlay
-------------------------------------------------
local function EnsureOverlay(frame)
    if frame.BattleMender then return frame.BattleMender end

    -- NEW: Independent Background frame specifically for the Halo to escape the pulse animation
    local bg = CreateFrame("Frame", nil, frame)
    bg:SetFrameStrata("TOOLTIP")
    bg:SetFrameLevel(315)
    
    local haloGlow = bg:CreateTexture(nil, "BACKGROUND", nil, -1)
    haloGlow:SetPoint("CENTER")
    haloGlow:SetBlendMode("ADD")
    haloGlow:SetAlpha(1)
    haloGlow:Hide()

    local low = CreateFrame("Frame", nil, frame)
    low:SetFrameStrata("TOOLTIP")
    low:SetFrameLevel(320)
    
    local icon = low:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetAllPoints()

    local mid = CreateFrame("Frame", nil, frame)
    mid:SetFrameStrata("TOOLTIP")
    mid:SetFrameLevel(330)
    local topIcon = mid:CreateTexture(nil, "ARTWORK", nil, 1)
    topIcon:SetAllPoints()

    local high = CreateFrame("Frame", nil, frame)
    high:SetFrameStrata("TOOLTIP")
    high:SetFrameLevel(335)
    local ring = high:CreateTexture(nil, "OVERLAY", nil, 5)
    ring:SetAllPoints()
    ring:SetTexture("Interface\\AddOns\\BattleMender\\textures\\Ring_20px.tga")

    -- Pulse Overlay Texture (Draws on top of the base icon)
    local pulseTex = low:CreateTexture(nil, "ARTWORK", nil, 2)
    pulseTex:SetAllPoints()
    pulseTex:Hide()

    -- MASK 1: Base Icon & Pulse Overlay
    local mask1 = low:CreateMaskTexture()
    mask1:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask1:SetAllPoints()
    icon:AddMaskTexture(mask1)
    pulseTex:AddMaskTexture(mask1) -- Kills square corners on the overlay!

    -- MASK 2: Top Icon & Top Glow
    local mask2 = mid:CreateMaskTexture()
    mask2:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask2:SetAllPoints()
    topIcon:AddMaskTexture(mask2)
    
    local topGlow = CreateHoverGlow(mid)
    topGlow:AddMaskTexture(mask2) -- Kills square corners on the overlay icon glow

    -- MASK 3: Ring Glow
    local mask3 = high:CreateMaskTexture()
    mask3:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask3:SetAllPoints()
    
    local ringGlow = CreateHoverGlow(high)
    ringGlow:AddMaskTexture(mask3) 

    -- DEBUG CLICKBOX VISUALIZER
    local debugBox = low:CreateTexture(nil, "BACKGROUND")
    debugBox:SetPoint("CENTER", frame, "CENTER") 
    debugBox:SetColorTexture(0, 1, 0, 0.3) -- 30% Opacity Neon Green
    debugBox:Hide()
	
	-- NEW: Independent Custom Health Bar
    local healthBar = CreateFrame("StatusBar", nil, bg)
    healthBar:SetFrameLevel(325)
    healthBar:SetOrientation("VERTICAL")
    healthBar:SetAllPoints(bg) -- Align precisely with your overlay sizes
    
    -- Sync directly from ElvUI's bar (No UnitHealth API calls!)
    healthBar:SetScript("OnUpdate", function(self)
        local nativeBar = GetHealthBar(frame)
        if nativeBar then
            local min, max = nativeBar:GetMinMaxValues()
            self:SetMinMaxValues(min, max)
            self:SetValue(nativeBar:GetValue() or 0)
        end
    end)

    frame.BattleMender = {
        bg = bg,
        low = low,
        pulseTex = pulseTex,
        mid = mid,
        high = high,
        icon = icon,
        topIcon = topIcon,
        ring = ring,
        topGlow = topGlow,
        ringGlow = ringGlow,
        haloGlow = haloGlow,
        debugBox = debugBox,
        healthBar = healthBar, -- NEW: Expose it in the overlay table
    }
	
    return frame.BattleMender
end

-------------------------------------------------
-- Restore health bar
-------------------------------------------------
local function RestoreBar(frame)
    local bar = GetHealthBar(frame)
    if not bar then return end

    -- THE FIX: The Strict Guard Clause
    -- If we never applied our vertical mask or custom settings to this bar, 
    -- it is a native ElvUI plate. DO NOT touch it, or we will crash ElvUI's renderer!
    if not bar.BMVerticalApplied and not bar.BMMask then 
        return 
    end

    -- 1. Strip custom textures and masks
    local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if tex then
        if bar.BMMask and tex.RemoveMaskTexture then
            pcall(tex.RemoveMaskTexture, tex, bar.BMMask)
        end
        tex:SetHorizTile(false)
        tex:SetVertTile(false)
        tex:SetBlendMode("BLEND")

        tex.BMSyncing = true 
        tex:SetAlpha(1)
        if tex.Show then tex:Show() end 
        tex.BMSyncing = false 
    end
    
    if bar.BMMask then 
        if bar.BMMask.Hide then bar.BMMask:Hide() end
        bar.BMMask = nil 
    end

    -- 2. Restore standard horizontal orientation
    if bar.SetOrientation then 
        pcall(bar.SetOrientation, bar, "HORIZONTAL") 
    end
    
    -- 3. Clear addon state flags so our color hooks ignore this frame
    bar.BMLockedR = nil
    bar.BMLockedG = nil
    bar.BMLockedB = nil
    bar.BMLockedAlpha = nil
    bar.BMVerticalApplied = nil -- Marks the bar as completely clean

    -- 4. Restore hidden background elements rigorously
    for _, key in ipairs({"bg", "bgTexture", "Background", "background", "backdrop", "BG"}) do
        local obj = bar[key]
        if obj then
            if obj.SetAlpha then obj:SetAlpha(1) end
            if obj.Show then obj:Show() end 
        end
    end

    -- BRUTE FORCE FRAME VISIBILITY
    if bar.SetAlpha then bar:SetAlpha(1) end
    if bar.Show then bar:Show() end

    -- 5. Restore physical dimensions explicitly
    if bar.BMOriginalStateSaved then
        bar:ClearAllPoints()
        if bar.BMOriPoint then
            pcall(function() 
                bar:SetPoint(bar.BMOriPoint, bar.BMOriRelTo, bar.BMOriRelPoint, bar.BMOriX, bar.BMOriY) 
            end)
        end
        if bar.BMOriWidth and bar.BMOriHeight then
            bar:SetSize(bar.BMOriWidth, bar.BMOriHeight)
        end
    end

    -- 6. The Double-Tap API Failsafe
    if frame.UpdateAllElements then
        local targetUnit = frame.unit
        frame:UpdateAllElements("ForceUpdate")
        
        C_Timer.After(0.1, function()
            if frame and frame.unit == targetUnit and frame:IsVisible() then
                frame:UpdateAllElements("ForceUpdate")
                
                local finalCheck = GetHealthBar(frame)
                
                if finalCheck and UnitExists(targetUnit) and not UnitIsDead(targetUnit) then
                    if not finalCheck:IsShown() then finalCheck:Show() end
                    if finalCheck.SetAlpha then finalCheck:SetAlpha(1) end
                    
                    local finalTex = finalCheck.GetStatusBarTexture and finalCheck:GetStatusBarTexture()
                    if finalTex then
                        if not finalTex:IsShown() then finalTex:Show() end
                        if finalTex.SetAlpha then finalTex:SetAlpha(1) end
                    end
                end
            end
        end)
    end
end

-- Vertical health bar helpers
local function SetupHealthBarFrame(bar, frame, plate)
    local parent = GetVisualFrame(plate) or frame
    
    -- CACHE ORIGINAL STATE BEFORE MODIFYING
    if not bar.BMOriginalStateSaved then
        
        -- 1. Safely attempt to measure anchor points to avoid Restricted Region taint in combat
        local successPoint, p, rt, rp, x, y = pcall(function() return bar:GetPoint(1) end)
        if successPoint then
            bar.BMOriPoint = p
            bar.BMOriRelTo = rt
            bar.BMOriRelPoint = rp
            bar.BMOriX = x
            bar.BMOriY = y
        end

        -- 2. Safely attempt to measure size
        local successSize, w, h = pcall(function() return bar:GetSize() end)
        if successSize then
            bar.BMOriWidth = w
            bar.BMOriHeight = h
        end

        -- 3. Cache Strata, Texture, and the RELATIVE Frame Level
        bar.BMOriStrata = bar:GetFrameStrata()
        
        -- Store the offset difference so it survives WoW's recycling engine!
        local pLevel = parent:GetFrameLevel() or 1
        bar.BMOriLevelOffset = (bar:GetFrameLevel() or 1) - pLevel

        local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        if tex then
            bar.BMOriTexture = tex:GetTexture()
        end

        bar.BMOriginalStateSaved = true
    end

    if bar.SetOrientation then
        pcall(bar.SetOrientation, bar, "VERTICAL")
    end

    PositionElement(bar, parent)
    bar:SetSize(CFG.iconSize, CFG.iconSize)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(325)
end

local function ApplyHealthTexture(bar, frame)
    local mode = CFG.healthTextureMode or "SPEC"

    local texPath = GetOverlayTexture(
        mode,
        frame.unit,
        frame.specID
    )
    
    if mode == "SPEC" then
        mode = "SOLID"
    end 

    if texPath then
        bar:SetStatusBarTexture(texPath)

    elseif mode ~= "ELVUI" then
        -- fallback
        bar:SetStatusBarTexture(
            select(1, ClassIcon(frame.unit))
        )
    end

    local tex = bar:GetStatusBarTexture()
    if not tex then return nil end

    tex:SetHorizTile(false)
    tex:SetVertTile(true)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetAlpha(CFG.healthAlpha or 0.35)
    tex:SetBlendMode(CFG.healthBlendMode or "BLEND")
    tex:SetDrawLayer("ARTWORK", 6)

    return tex
end

local function ApplyHealthColor(tex, unit)
    local r, g, b = GetOverlayColor(
        CFG.healthUseClassColor,
        unit,
        CFG.healthColorR,
        CFG.healthColorG,
        CFG.healthColorB
    )

    tex:SetVertexColor(r, g, b, 1)
end

local function EnsureHealthMask(bar, tex)
    if not tex.AddMaskTexture then return end
    if bar.BMMask then return end

    local mask = bar:CreateMaskTexture()

    mask:SetTexture(
        "Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )

    mask:SetAllPoints()

    tex:AddMaskTexture(mask)

    bar.BMMask = mask
end

local function HideHealthBackgrounds(bar)
    for _, key in ipairs({
        "bg",
        "bgTexture",
        "Background",
        "background",
        "backdrop",
        "BG",
    }) do
        local obj = bar[key]

        if obj and obj.SetAlpha then
            obj:SetAlpha(0)
        end
    end
end

-------------------------------------------------
-- Apply circular health overlay
-------------------------------------------------
local function ApplyVerticalBar(frame, plate)
    local overlay = frame.BattleMender
    if not overlay or not overlay.healthBar then return end

    local nativeBar = GetHealthBar(frame)
    if not nativeBar then return end

    -- 1. Visually hide ElvUI's health bar securely
    if nativeBar.SetAlpha then
        nativeBar:SetAlpha(0)
    end

    -- 2. Dress up your custom vertical bar
    local mode = CFG.healthTextureMode or "SPEC"
    if mode == "SPEC" then mode = "SOLID" end

    local texPath = GetOverlayTexture(mode, frame.unit, frame.specID)
    if texPath then
        overlay.healthBar:SetStatusBarTexture(texPath)
    elseif mode ~= "ELVUI" then
        -- fallback
        overlay.healthBar:SetStatusBarTexture(select(1, ClassIcon(frame.unit)))
    end
    
    local tex = overlay.healthBar:GetStatusBarTexture()
    if tex then
        tex:SetHorizTile(false)
        tex:SetVertTile(true)
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetAlpha(CFG.healthAlpha or 0.35)
        tex:SetBlendMode(CFG.healthBlendMode or "BLEND")
        
        local r, g, b = GetOverlayColor(CFG.healthUseClassColor, frame.unit, CFG.healthColorR, CFG.healthColorG, CFG.healthColorB)
        overlay.healthBar:SetStatusBarColor(r, g, b, 1)
        
        -- Apply your custom mask to our custom bar securely
        EnsureHealthMask(overlay.healthBar, tex) 
    end

    overlay.healthBar:Show()
end

--Position holders
local function PrepareOverlayHolders(overlay, parent)
    local size = CFG.iconSize or 45

    -- halo background
    if overlay.bg then
        PositionElement(overlay.bg, parent)
        overlay.bg:SetSize(size, size)
        overlay.bg:SetAlpha(1)
        overlay.bg:Show()
    end

    -- base icon
    PositionElement(overlay.low, parent)
    overlay.low:SetSize(size, size)
    overlay.low:SetAlpha(1)

    -- top icon
    PositionElement(overlay.mid, parent)
    overlay.mid:SetSize(size, size)
    overlay.mid:SetAlpha(1)
end


-- Helper to grab LoS state with your existing hysteresis logic
local function GetLOSState(frame, overlay, plate)
    if not IsFriendlyPlayer(frame.unit) then return false end

    local alpha = plate and plate:GetAlpha() or 1
    local faded = overlay.BMLastLOS or false

    if faded then
        faded = alpha < 0.985
    else
        faded = alpha < 0.97
    end

    overlay.BMLastLOS = faded
    return faded
end

-----------------------------
-- Draw base icon
-----------------------------
local function UpdateBaseIcon(overlay, frame, unit, specID, faded)
    local mode = CFG.iconTextureMode or "SPEC"
    
    -- Config check: Use LoS alpha if faded
    local alpha = faded and (CFG.losIconAlpha or 0.8) or (CFG.iconAlpha or 0.42)

    if mode == "NONE" or alpha <= 0 then
        overlay.icon:SetTexture(nil)
        overlay.low:Hide()
        if overlay.low.pulseAnim then overlay.low.pulseAnim:Stop() end
        return nil, nil
    end

    local tex, coords = GetOverlayTexture(mode, unit, specID)
    if not tex then
        overlay.icon:SetTexture(nil)
        overlay.low:Hide()
        if overlay.low.pulseAnim then overlay.low.pulseAnim:Stop() end
        return nil, nil
    end

    overlay.low:Show()
    overlay.icon:SetTexture(tex)
    overlay.icon:SetTexCoord(
        coords and coords[1] or 0,
        coords and coords[2] or 1,
        coords and coords[3] or 0,
        coords and coords[4] or 1
    )

    local r,g,b = GetOverlayColor(
        CFG.iconUseClassColor,
        unit,
        CFG.iconColorR,
        CFG.iconColorG,
        CFG.iconColorB
    )

    -- PULSE ANIMATION SETUP
    if not overlay.low.pulseAnim then
        local ag = overlay.low:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetDuration(0.2)
        a1:SetSmoothing("IN_OUT")
        a1:SetOrder(1)
        
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetDuration(0.2)
        a2:SetSmoothing("IN_OUT")
        a2:SetOrder(2)
        
        overlay.low.pulseAnim = ag
        overlay.low.pulseAnim.a1 = a1
        overlay.low.pulseAnim.a2 = a2
    end

    local desaturate = faded and (CFG.losIconDesaturate == true) or (CFG.iconDesaturate == true)

    overlay.icon:SetDesaturated(desaturate)
    overlay.icon:SetVertexColor(r,g,b,1)
    overlay.icon:SetAlpha(alpha) -- RESTORED: Locks the icon to your exact config alpha

    -- ZERO-TAINT ANIMATION LOGIC (Animates the parent frame instead of the texture)
    local speed = faded and (CFG.losPulseSpeed or 0.8) or (CFG.pulseSpeed or 0.8)
    local intensity = faded and (CFG.losPulseIntensity or 0.3) or (CFG.pulseIntensity or 0.3)
    local doPulse = faded and (CFG.losPulseEnable == true) or (not faded and CFG.pulseEnable ~= false)

    overlay.low.pulseAnim.a1:SetDuration(speed)
    overlay.low.pulseAnim.a2:SetDuration(speed)

    if doPulse then
        -- Frame scales from 1.0 down to the dimming intensity multiplier
        overlay.low.pulseAnim.a1:SetFromAlpha(1)
        overlay.low.pulseAnim.a1:SetToAlpha(intensity) 
        overlay.low.pulseAnim.a2:SetFromAlpha(intensity)
        overlay.low.pulseAnim.a2:SetToAlpha(1)

        if not overlay.low.pulseAnim:IsPlaying() then
            overlay.low.pulseAnim:Play()
        end
    else
        if overlay.low.pulseAnim:IsPlaying() then
            overlay.low.pulseAnim:Stop()
        end
        overlay.low:SetAlpha(1) 
    end
    
    -- PULSE OVERLAY LAYER
    local overEnable = faded and (CFG.losPulseOverlayEnable == true) or (not faded and CFG.pulseOverlayEnable == true)

    if overEnable then
        local file = CFG.pulseOverlayTexture or "Circle_AlphaGradient_In"
        local blend = faded and (CFG.losPulseOverlayBlend or "ADD") or (CFG.pulseOverlayBlend or "ADD")
        local overAlpha = faded and (CFG.losPulseOverlayAlpha or 0.5) or (CFG.pulseOverlayAlpha or 0.5)

        overlay.pulseTex:SetTexture("Interface\\AddOns\\BattleMender\\Textures\\" .. file .. ".tga")
        overlay.pulseTex:SetBlendMode(blend)
        overlay.pulseTex:SetVertexColor(r, g, b, overAlpha) -- Matches base icon color perfectly
        overlay.pulseTex:Show()
    else
        overlay.pulseTex:Hide()
    end

    return tex, coords
end

------------------------------
-- Draw top icon
-------------------------------
local function UpdateTopIcon(overlay, unit, specID, faded)
    local mode = CFG.topIconTextureMode or "SPEC"
    
    -- Config check: Use LoS settings if faded
    local baseAlpha = faded and (CFG.losTopIconAlpha or 1) or (CFG.topIconAlpha or 0.10)
    local desaturate = faded and (CFG.losTopIconDesaturate == true) or (CFG.topIconDesaturate ~= false)
    local blend = faded and (CFG.losTopIconBlendMode or "BLEND") or (CFG.topIconBlendMode or "MOD")

    if mode == "NONE" or baseAlpha <= 0 or CFG.topIconEnable == false then
        overlay.mid:Hide()
        return
    end

    local tex, coords = GetOverlayTexture(mode, unit, specID)
    if not tex then
        overlay.mid:Hide()
        return
    end

    overlay.mid:Show()
    overlay.topIcon:SetTexture(tex)

    if coords then
        overlay.topIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    elseif mode == "SPEC" then
        overlay.topIcon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    else
        overlay.topIcon:SetTexCoord(0,1,0,1)
    end

    -- Respect the user's custom color settings regardless of LoS state
    local r, g, b = GetOverlayColor(
        CFG.topIconUseClassColor,
        unit,
        CFG.topIconColorR,
        CFG.topIconColorG,
        CFG.topIconColorB
    )
    
    overlay.topIcon:SetVertexColor(r,g,b,1)
    overlay.topIcon:SetDesaturated(desaturate)
    overlay.topIcon:SetBlendMode(blend)
    overlay.mid:SetAlpha(baseAlpha)
    overlay.topIcon:SetAlpha(1)
     
    -- Sync glow layer to match the top icon perfectly and safely
    overlay.topGlow:SetTexture(tex)
    if coords then
        overlay.topGlow:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    elseif mode == "SPEC" then
        overlay.topGlow:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    else
        overlay.topGlow:SetTexCoord(0,1,0,1)
    end
    overlay.topGlow:SetVertexColor(r, g, b, 1)  
	-- Apply the Spec or Class Icon
    if specID then
        -- WE HAVE A SPEC! (Tiers 1-4 Succeeded)
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        overlay.baseIconTexture:SetTexture(icon)
        
        -- Mask the native white border on spec icons
        overlay.baseIconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92) 
    else
        -- TIER 5 FALLBACK: Class Icon using Blizzard Spritesheet
        local _, classStr = UnitClass(unit)
        if classStr then
            overlay.baseIconTexture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            
            -- Pull the coordinates for this specific class from the spritesheet
            local coords = CLASS_ICON_TCOORDS[classStr] 
            if coords then
                overlay.baseIconTexture:SetTexCoord(unpack(coords))
            end
        end
        
        -- Silently queue them for a background inspect to fix this!
        if guid then
            BattleMender.QueueInspect(unit, guid)
        end
    end
end

-- Cleaned up redundant table declarations for ring fit
local BORDER_FIT_SCALES = {
    ["Ring_10px"] = 1.06,
    ["Ring_20px"] = 1.10,
    ["Ring_30px"] = 1.14,
    ["Ring_40px"] = 1.18,
}

-- Draw border / ring
local function UpdateRing(overlay, unit, parent, faded)
    if CFG.borderEnable == false then
        overlay.high:Hide()
        return
    end

    local file = CFG.borderTexture or "Ring_20px"
    local texPath = "Interface\\AddOns\\BattleMender\\Textures\\" .. file .. ".tga"

    overlay.high:Show()
    overlay.ring:SetTexture(texPath)
    overlay.ring:SetTexCoord(0,1,0,1)
    overlay.ring:SetBlendMode("BLEND")

    local c = ClassColor(unit)
    local a = CFG.borderAlpha or 1

    -- LoS Logic: Strong readable ring when out of sight
    if faded then
        a = 1 
    end
	
    overlay.ring:SetVertexColor(c.r, c.g, c.b, a)

    local iconSize = CFG.iconSize or 45
    local scale = CFG.borderScale or 1
    local fit = BORDER_FIT_SCALES[file] or 1.10
    local ringSize = iconSize * fit * scale
    
    -- CACHE CHECK for the Ring Anchor and Size
    if overlay.high.BMLastSize ~= ringSize or overlay.high.BMLastParent ~= overlay.low then
        overlay.high:ClearAllPoints()
        overlay.high:SetPoint("CENTER", overlay.low, "CENTER", 0, 0)
        overlay.high:SetSize(ringSize, ringSize)
        
        -- Save state
        overlay.high.BMLastSize = ringSize
        overlay.high.BMLastParent = overlay.low
    end
    
    -- Sync glow layer to match the ring perfectly
    overlay.ringGlow:SetTexture(texPath)
    overlay.ringGlow:SetVertexColor(c.r, c.g, c.b, a)
end

--sync health alpha
local function SyncHealthAlpha(frame)
    return
end

-- Update Health Colors dynamically
local function UpdateHealthVisuals(frame, faded)
    local bar = GetHealthBar(frame)
    if not bar then return end

    local alpha = faded and (CFG.losHealthAlpha or 0.35) or (CFG.healthAlpha or 0.35)
    local blend = faded and (CFG.losHealthBlendMode or "BLEND") or (CFG.healthBlendMode or "BLEND")

    local useClass = faded and CFG.losHealthUseClassColor or CFG.healthUseClassColor
    local cr = faded and (CFG.losHealthColorR or 1) or (CFG.healthColorR or 1)
    local cg = faded and (CFG.losHealthColorG or 0) or (CFG.healthColorG or 0)
    local cb = faded and (CFG.losHealthColorB or 0) or (CFG.healthColorB or 0)

    local r, g, b = GetOverlayColor(useClass, frame.unit, cr, cg, cb)

    -- 1. SAVE LOCK STATE (Our hooks will constantly read these values)
    bar.BMLockedR = r
    bar.BMLockedG = g
    bar.BMLockedB = b
    bar.BMLockedAlpha = alpha

    -- 2. SETUP FRAME-PERFECT HOOKS (Only runs once per bar to permanently lock it)
    if not bar.BMColorHooked then
        
        -- Intercept WoW trying to color the Status Bar Container
        hooksecurefunc(bar, "SetStatusBarColor", function(self)
            if self.BMLockedR then
                local t = self.GetStatusBarTexture and self:GetStatusBarTexture()
                if t and not t.BMSyncing then
                    t.BMSyncing = true
                    t:SetVertexColor(self.BMLockedR, self.BMLockedG, self.BMLockedB, self.BMLockedAlpha)
                    t.BMSyncing = false
                end
            end
        end)
        
        -- Intercept WoW trying to color the Texture explicitly
        local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        if tex and not tex.BMColorHooked then
            hooksecurefunc(tex, "SetVertexColor", function(self, txR, txG, txB)
                if self.BMSyncing then return end
                local pBar = self:GetParent()
                if pBar and pBar.BMLockedR then
                    -- If hijacked, snap it back instantly at 0ms latency!
                    if math.abs((txR or 0) - pBar.BMLockedR) > 0.01 or math.abs((txG or 0) - pBar.BMLockedG) > 0.01 then
                        self.BMSyncing = true
                        self:SetVertexColor(pBar.BMLockedR, pBar.BMLockedG, pBar.BMLockedB, pBar.BMLockedAlpha)
                        self.BMSyncing = false
                    end
                end
            end)
            tex.BMColorHooked = true
        end
        
        bar.BMColorHooked = true
    end

    -- 3. APPLY CURRENT FRAME
    local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if tex then
        -- Enforce underlying texture visibility 
        -- (ElvUI style filters sometimes hide the texture independently of the bar)
        if not tex:IsShown() then 
            tex:Show() 
        end
        
        tex:SetBlendMode(blend)
        tex.BMSyncing = true
        tex:SetVertexColor(r, g, b, alpha)
        tex.BMSyncing = false
    end
end

-- Trigger mouseover flash
local function UpdateHoverVisuals(frame, overlay)
    if not overlay then return end

    local isHover = UnitIsUnit(frame.unit, "mouseover")

    if isHover then
        local topPeak = CFG.hoverTopBrightness or 0.50
        local ringPeak = CFG.hoverRingBrightness or 0.50
        local haloPeak = CFG.haloGlowAlpha or 0.80
        
        -- 1. Initial Fade In
        if not overlay.BMIsHovering then
            overlay.BMIsHovering = true
            
            if CFG.hoverTopEnable then
                FadeInGlow(overlay.topGlow, topPeak, CFG.hoverTopFadeIn or 0.05)
            end
            
            if CFG.hoverRingEnable then
                FadeInGlow(overlay.ringGlow, ringPeak, CFG.hoverRingFadeIn or 0.05)
            end

            -- NEW: Static Halo Glow (No animation fade)
            if CFG.haloEnable and overlay.haloGlow then
                overlay.haloGlow:SetTexture(HALO_TEXTURES[CFG.haloGlowTexture] or HALO_TEXTURES["Circle_Halo_1"])
                overlay.haloGlow:SetSize(CFG.iconSize * (CFG.haloGlowSizeScale or 2.9), CFG.iconSize * (CFG.haloGlowSizeScale or 2.9))
                overlay.haloGlow:SetBlendMode("ADD")
                overlay.haloGlow:SetAlpha(haloPeak)
                overlay.haloGlow:Show()
            end
            
        -- 2. Live-Update (Applies slider changes instantly while hovering)
        else
            if CFG.hoverTopEnable and not overlay.topGlow.anim:IsPlaying() then
                overlay.topGlow.anim.targetAlpha = topPeak
                overlay.topGlow:SetAlpha(topPeak)
            end
            if CFG.hoverRingEnable and not overlay.ringGlow.anim:IsPlaying() then
                overlay.ringGlow.anim.targetAlpha = ringPeak
                overlay.ringGlow:SetAlpha(ringPeak)
            end
            if CFG.haloEnable and overlay.haloGlow then
                overlay.haloGlow:SetAlpha(haloPeak)
            end
        end
        
    -- 3. Fade Out (Forcefully clean up regardless of current settings)
    elseif not isHover and overlay.BMIsHovering then
        overlay.BMIsHovering = false
        
        FadeOutGlow(overlay.topGlow, CFG.hoverTopBrightness or 0.50, CFG.hoverTopFadeOut or 0.35)
        FadeOutGlow(overlay.ringGlow, CFG.hoverRingBrightness or 0.50, CFG.hoverRingFadeOut or 0.35)
        
        if overlay.haloGlow then
            overlay.haloGlow:Hide()
        end
    end
end

-- HELPER: Neutralize highlight objects safely
local function Neutralize(obj)
    if not obj then return end
    -- ONLY use Alpha. Do NOT use SetVertexColor, as it corrupts ElvUI's native threat colors!
    if obj.SetAlpha then pcall(obj.SetAlpha, obj, 0) end
end

-- Kills the native WoW / ElvUI square highlight boxes safely
local function KillBaseHighlights(frame)
    Neutralize(frame.selectionHighlight)
    Neutralize(frame.Highlight)
    Neutralize(frame.HoverHighlight)
    Neutralize(frame.FlashTexture)
    Neutralize(frame.TargetFlash)
    
    -- NEW: Assassinate Threat, Absorbs, and Heal Prediction Overlays!
    Neutralize(frame.aggroHighlight)
    Neutralize(frame.aggroHighlightAdditive)
    Neutralize(frame.aggroHighlightBase)
    Neutralize(frame.aggroFlash)
    Neutralize(frame.aggroHighlightMask)
    
    Neutralize(frame.myHealPrediction)
    Neutralize(frame.otherHealPrediction)
    Neutralize(frame.totalAbsorb)
    Neutralize(frame.totalAbsorbOverlay)
    Neutralize(frame.overAbsorbGlow)
    Neutralize(frame.overHealAbsorbGlow)
    Neutralize(frame.myHealAbsorb)
    Neutralize(frame.myHealAbsorbLeftShadow)
    Neutralize(frame.myHealAbsorbRightShadow)
end

-- HELPER: Restores highlight objects for enemy nameplates
local function Revive(obj)
    if not obj then return end
    -- ONLY restore Alpha. 
    if obj.SetAlpha then pcall(obj.SetAlpha, obj, 1) end
end

-- Restores native highlights when a plate is no longer a friendly BattleMender plate
local function RestoreBaseHighlights(frame)
    Revive(frame.selectionHighlight)
    Revive(frame.Highlight)
    Revive(frame.HoverHighlight)
    Revive(frame.FlashTexture)
    Revive(frame.TargetFlash)
    
    -- NEW: Give enemies their Absorbs, Predictions, and Flashes back!
    Revive(frame.aggroHighlight)
    Revive(frame.aggroHighlightAdditive)
    Revive(frame.aggroHighlightBase)
    Revive(frame.aggroFlash)
    Revive(frame.aggroHighlightMask)

    Revive(frame.myHealPrediction)
    Revive(frame.otherHealPrediction)
    Revive(frame.totalAbsorb)
    Revive(frame.totalAbsorbOverlay)
    Revive(frame.overAbsorbGlow)
    Revive(frame.overHealAbsorbGlow)
    Revive(frame.myHealAbsorb)
    Revive(frame.myHealAbsorbLeftShadow)
    Revive(frame.myHealAbsorbRightShadow)
end

-- Update overlay
local function UpdateOverlay(frame, plate)
    local overlay = EnsureOverlay(frame)
    local parent = GetVisualFrame(plate) or frame
    local unit = frame.unit

    if not unit then return end

    PrepareOverlayHolders(overlay, parent)

    --Toggle the debug box based on settings
    if CFG.showClickbox then
        local s = CFG.clickSize or 60
        overlay.debugBox:SetSize(s, s)
        overlay.debugBox:Show()
    else
        overlay.debugBox:Hide()
    end

    -- 1. Grab the LoS State first
    local isFaded = GetLOSState(frame, overlay, plate)

    ---------------------------------------------------------
    -- NEW TIERED SPEC RESOLVER ENGINE
    ---------------------------------------------------------
    local guid = UnitGUID(unit)
    -- Fire our Tiers 1-4 engine to get the ID
    local resolvedSpecID = BattleMender.GetUnitSpecID(unit, guid)
    
    -- Save it to the frame so everything else can use it
    frame.specID = resolvedSpecID
    ---------------------------------------------------------

    -- 2. Pass it downstream so components handle themselves
    -- (Notice we pass the 'guid' down to UpdateBaseIcon now too!)
    UpdateBaseIcon(overlay, frame, unit, frame.specID, isFaded, guid)
    UpdateTopIcon(overlay, unit, frame.specID, isFaded)
    UpdateRing(overlay, unit, parent, isFaded)
    
    -- 3. Update Health visual state
    UpdateHealthVisuals(frame, isFaded)
    
    -- 4. update hover & kill native square highlights
    KillBaseHighlights(frame)
    UpdateHoverVisuals(frame, overlay)
    
    -- 5. disabled for now
    SyncHealthAlpha(frame)  

    frame.BattleMenderModified = true
end

-------------------------------------------------
-- Helpers for plate state
-------------------------------------------------
local function HideOverlay(frame)
    local overlay = frame.BattleMender
    if not overlay then return end

    if overlay.bg then overlay.bg:Hide() end
    overlay.low:Hide()
    overlay.mid:Hide()
    overlay.high:Hide()
end

local function ClearFriendlyPlate(frame)
    if frame.BattleMenderModified then
        RestoreBar(frame)
        frame.BattleMenderModified = nil
    end

    -- WIPE ALL CACHES: Force total amnesia before the frame is recycled
    local bar = GetHealthBar(frame)
    if bar then
        bar.BMLockedR = nil
        bar.BMLastParent = nil
        bar.BMVerticalApplied = nil
        bar.BMOriginalStateSaved = nil -- CRITICAL: Delete the layout snapshot!
    end
    
    local overlay = frame.BattleMender
    if overlay then
        overlay.BMLastUnit = nil
        overlay.BMLastLOS = nil
        overlay.BMIsHovering = nil
        if overlay.bg then overlay.bg.BMLastParent = nil end
    end

    RestoreBaseHighlights(frame) 
    BattleMender.CleanPlate(frame) -- Safely hide our overlay
end

local function ApplyFriendlyPlate(frame, plate)
    local overlay = EnsureOverlay(frame)
    local unit = frame.unit
    
    -- RECYCLING CHECK: If WoW recycled this nameplate for a new unit, wipe the cache!
    if overlay.BMLastUnit ~= unit then
        overlay.BMLastLOS = nil
        overlay.BMLastUnit = unit
        overlay.BMIsHovering = nil

        -- WIPE CACHES so recycled plates rebuild completely
        if overlay.bg then overlay.bg.BMLastParent = nil end
        overlay.low.BMLastParent = nil
        overlay.mid.BMLastParent = nil
        overlay.high.BMLastParent = nil
        overlay.high.BMLastSize = nil
        
        local bar = GetHealthBar(frame)
        if bar then
            bar.BMLastParent = nil
            bar.BMVerticalApplied = nil -- Forces texture, mask, and backgrounds to re-apply!
        end
    end

    if CFG.healthEnable ~= false then
        ApplyVerticalBar(frame, plate)
    else
        RestoreBar(frame)
        frame.BattleMenderModified = nil
    end

    UpdateOverlay(frame, plate)
end

-------------------------------------------------
-- Apply to nameplate
-------------------------------------------------
local function ApplyToPlate(plate)
    if not plate then return end

    local frame = GetVisualFrame(plate)
    if not frame then return end

    local unit = frame.unit
    if not unit then
        ClearFriendlyPlate(frame)
        return
    end

    --The addon must be enabled, the unit must be friendly, AND we must be awake!
    local isFriendly = CFG.enabled and IsFriendlyPlayer(unit) and not BattleMender.IsSleeping

    if isFriendly then
        ApplyFriendlyPlate(frame, plate)
    else
        ClearFriendlyPlate(frame)
    end
end

-------------------------------------------------
-- Refresh
-------------------------------------------------

function BattleMender.RefreshAll()
    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end

    for _, plate in ipairs(plates) do
        ApplyToPlate(plate)
    end
    --Debug("cam", frame.unit, frame.isBehindCamera)
end

-------------------------------------------------
-- Clickbox
-------------------------------------------------
function BattleMender.SetFriendlyClickbox()

    local s = CFG.clickSize or 60

    if C_NamePlate.SetNamePlateFriendlySize then
        C_NamePlate.SetNamePlateFriendlySize(s, s)
    elseif C_NamePlate.SetNamePlateSize then
        C_NamePlate.SetNamePlateSize(s, s)
    end
end

-------------------------------------------------
-- OnUpdate
-------------------------------------------------
local elapsed = 0

ADDON:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt

    if elapsed >= (CFG.updateRate or 0.20) then
        elapsed = 0
        BattleMender.RefreshAll()
    end
end)


-------------------------------------------------
-- Compatibility Checks
-------------------------------------------------
local function CheckElvUIConflicts()
    -- Safely check if ElvUI is loaded and accessible
    if not _G.ElvUI then return end
    
    local E = unpack(_G.ElvUI)
    if not E or not E.db then return end

    -- Carefully navigate ElvUI's DB structure to avoid nil errors
    local np = E.db.nameplates
    if np and np.units and np.units.FRIENDLY_PLAYER and np.units.FRIENDLY_PLAYER.health then
        
        -- Check if Class Color is enabled for friendly plates
        if np.units.FRIENDLY_PLAYER.health.colorClass then
            
            -- Print a highly visible warning to the user
            local prefix = "|cff33ff99[BattleMender]|r "
            local warning = "|cffff0000WARNING:|r ElvUI's 'Class Color' for Friendly Nameplate Health is currently enabled. "
            local fix = "This will fight with BattleMender's custom vertical health bars. Please go to |cff00ccff/ec -> NamePlates -> Friendly Player -> Health|r and disable 'Class Color' for the best experience."
            
            print(prefix .. warning .. fix)
        end
    end
end

-- Robust Auto-Off for Clickbox
local function ForceDisableDebug()
    if CFG and CFG.showClickbox then
        CFG.showClickbox = false
        BattleMender.Debug("Hiding Debug Visuals.")
        BattleMender.RefreshAll()
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------
ADDON:SetScript("OnEvent", function(self, event, ...)

    -- 1. Heavy Engine Updates (Zone changes, Login, Spec changes)
    if event == "PLAYER_ENTERING_WORLD" then
        if not INIT_DONE then
            BattleMender.LoadDB()
            INIT_DONE = true

            if self.InitSettingsPanel then
                self:InitSettingsPanel()
            end
            
            if CheckElvUIConflicts then
                CheckElvUIConflicts()
            end
        end
        
        BattleMender.ApplyContextDefaults()
        BattleMender.SetFriendlyClickbox()
        BattleMender.UpdateInstanceStatus() -- Safely runs only once on login
    end
    
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if BattleMender.ApplyContextDefaults then 
            BattleMender.ApplyContextDefaults() 
        end
        BattleMender.UpdateInstanceStatus() -- Safely runs only when switching zones/BGs
    end
	
	-- 2. Nameplate Added Bouncer
	if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ... 
        if not unit then return end
        
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate then return end
        
        -- THE BOUNCER: Are they friendly?
        if IsFriendlyPlayer(unit) then
            local overlay = EnsureOverlay(nameplate)
            local iconTexture = overlay.topIcon 
            
            if iconTexture then
                iconTexture:Show() 
                
                -- FORCE the image to the front, and remove any solid white tints
                iconTexture:SetDrawLayer("ARTWORK", 7)
                iconTexture:SetVertexColor(1, 1, 1, 1) 
                
                local specID = BattleMender.GetSpecID(unit)
                
                if specID then
                    -- 1. Apply Official Spec Icon (Modern FileID)
                    local _, _, _, specIconFileID = GetSpecializationInfoByID(specID)
                    if specIconFileID then
                        -- If it was previously an Atlas, we must clear it before setting a Texture
                        iconTexture:SetAtlas(nil) 
                        iconTexture:SetTexture(specIconFileID)
                        iconTexture:SetTexCoord(0, 1, 0, 1) -- Full square
                    end
                else
                    -- 2. Modern Class Icon Fallback (The Atlas System)
                    local _, classToken = UnitClass(unit)
                    if classToken then
                        iconTexture:SetTexture(nil) -- Clear old textures
                        iconTexture:SetTexCoord(0, 1, 0, 1)
                        
                        -- Modern WoW dynamically grabs class icons from the hidden Atlas
                        iconTexture:SetAtlas("classicon-" .. string.lower(classToken))
                    end
                end
            end
            
        else
            -- NO: It's an enemy or NPC.
            -- SCRUB THE RECYCLED FRAME: Hide BattleMender
            if nameplate.BattleMender then
                if nameplate.BattleMender.bg then nameplate.BattleMender.bg:Hide() end
                if nameplate.BattleMender.low then nameplate.BattleMender.low:Hide() end
                if nameplate.BattleMender.mid then nameplate.BattleMender.mid:Hide() end
                if nameplate.BattleMender.high then nameplate.BattleMender.high:Hide() end
                if nameplate.BattleMender.healthBar then nameplate.BattleMender.healthBar:Hide() end
            end
            
            -- THE FIX: Restore the native ElvUI healthbar using your custom helpers!
            local visualFrame = GetVisualFrame(nameplate)
            local nativeBar = GetHealthBar(visualFrame)
            if nativeBar then
                if nativeBar.SetAlpha then nativeBar:SetAlpha(1) end
                if nativeBar.Show then nativeBar:Show() end
            end
            
            return 
        end
    end
	
	-- 3. Nameplate Removed Cleanup
	if event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if not unit then return end
        
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate then return end
        
        -- Hide all BattleMender custom art
        if nameplate.BattleMender then
            if nameplate.BattleMender.bg then nameplate.BattleMender.bg:Hide() end
            if nameplate.BattleMender.low then nameplate.BattleMender.low:Hide() end
            if nameplate.BattleMender.mid then nameplate.BattleMender.mid:Hide() end
            if nameplate.BattleMender.high then nameplate.BattleMender.high:Hide() end
            if nameplate.BattleMender.healthBar then nameplate.BattleMender.healthBar:Hide() end
        end
        
        -- RESTORE Base Nameplate Visibility
        nameplate:SetAlpha(1)
        nameplate:Show()
        
        if nameplate.UnitFrame then
            nameplate.UnitFrame:Show()
            nameplate.UnitFrame:SetAlpha(1)
        end
        
        -- THE FIX: Restore the native ElvUI healthbar (Just in case)
        local visualFrame = GetVisualFrame(nameplate)
        local nativeBar = GetHealthBar(visualFrame)
        if nativeBar then
            if nativeBar.SetAlpha then nativeBar:SetAlpha(1) end
            if nativeBar.Show then nativeBar:Show() end
        end
    end
    
    -- 4. Visual Refresh (Runs on target changes, mouseovers, combat starts, and plate additions)
    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "GROUP_ROSTER_UPDATE" then
        BattleMender.RefreshAll()
    end
end)

ADDON:RegisterEvent("PLAYER_ENTERING_WORLD")
ADDON:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ADDON:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ADDON:RegisterEvent("GROUP_ROSTER_UPDATE")
ADDON:RegisterEvent("PLAYER_TARGET_CHANGED")
ADDON:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ADDON:RegisterEvent("PLAYER_REGEN_DISABLED") -- Start of combat
ADDON:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ADDON:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
BattleMender = BattleMender or {}

local CFG = BattleMender.CFG
BattleMender._Overlays = BattleMender._Overlays or {}
local BM_OVERLAYS = BattleMender._Overlays

local HALO_TEXTURES = {
    ["Circle_Halo_1"] = "Interface\\AddOns\\BattleMender\\Textures\\Circle_Halo_2.tga",
}

local SPEC_PATH = "Interface\\AddOns\\BattleMender\\Textures\\Specs\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local HEALER_PATH = "Interface\\AddOns\\BattleMender\\Media\\Circles\\healer\\"
BattleMender.HealerBackgroundTexture = HEALER_PATH .. "backgrouind.tga"
BattleMender.HealerCrossTexture = HEALER_PATH .. "cross-runtime.tga"
local HEALER_SPECS = { [65]=true, [105]=true, [256]=true, [257]=true, [264]=true, [270]=true, [1468]=true }

function BattleMender.IsHealerUnit(unit, specID)
    -- Prefer the established spec resolver. Never infer role from class alone.
    if not BattleMender.IsSecretValue(specID) and type(specID) == "number" and specID > 0 then
        return HEALER_SPECS[specID] == true
    end
    local token = unit and BattleMender.GetFriendlyUnitToken(unit)
    if token and UnitGroupRolesAssigned then
        local role = UnitGroupRolesAssigned(token)
        if not BattleMender.IsSecretValue(role) then return role == "HEALER" end
    end
    return false
end

local function ResolveHealerTargetClassColor(unit, classFile)
    local color = classFile and RAID_CLASS_COLORS[classFile] or nil
    if not color and unit then
        local resolvedClass = BattleMender.GetFriendlyClassFile and BattleMender.GetFriendlyClassFile(unit)
        color = resolvedClass and RAID_CLASS_COLORS[resolvedClass] or nil
    end
    return color
end

function BattleMender.GetHealerBackgroundColor(unit, classFile)
    local r, g, b = CFG.healerBackgroundR, CFG.healerBackgroundG, CFG.healerBackgroundB
    local mode = tostring(CFG.healerBackgroundColorMode or (CFG.healerBackgroundUseClassColor and "CLASS" or "CUSTOM")):upper()
    if mode == "CLASS" then
        local color = ResolveHealerTargetClassColor(unit, classFile)
        if color then r, g, b = color.r, color.g, color.b end
    end
    local brightness = CFG.healerBackgroundBrightness or 1
    return (r or 1) * brightness, (g or 1) * brightness, (b or 1) * brightness
end

function BattleMender.GetHealerControlColor(unit, classFile)
    local mode = tostring(CFG.healerControlColorMode or "CLASS"):upper()
    if mode == "CLASS" then
        local color = ResolveHealerTargetClassColor(unit, classFile)
        if color then return color.r, color.g, color.b end
    end
    return CFG.healerControlR or 1, CFG.healerControlG or 0.65, CFG.healerControlB or 0.06
end

function BattleMender.SetHealerCrossArt(texture, damaged)
    if not texture then return end
    texture:SetTexture(BattleMender.HealerCrossTexture)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetBlendMode("BLEND")
    texture:SetVertexColor(
        damaged and CFG.healerDamageCrossR or CFG.healerCrossR,
        damaged and CFG.healerDamageCrossG or CFG.healerCrossG,
        damaged and CFG.healerDamageCrossB or CFG.healerCrossB, 1)
end

function BattleMender.HideHealerVisuals(overlay)
    if not overlay then return end
    overlay.healerActive = false
    if overlay.healerDamagedCross then overlay.healerDamagedCross:Hide() end
    if overlay.healerHealthyCross then overlay.healerHealthyCross:Hide() end
    if overlay.healerControlHost then overlay.healerControlHost:Hide() end
    if overlay.affiliateFrame then overlay.affiliateFrame:Hide() end
end
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DAMAGED_CIRCLE_MASK = "Interface\\AddOns\\BattleMender\\Textures\\Circle_White.tga"
local ACCENT_OVERLAY_TEXTURES = {
    ["Metal_Ring"] = true,
    ["Glass_Ring"] = true,
}

local ACCENT_TEXTURE_PATH = "Interface\\AddOns\\BattleMender\\Textures\\"

local ACCENT_TEXCOORD_INSETS = {
    Metal_Ring = 0.005,
    Glass_Ring = 0.012,
}

-- Blizzard exposes battleground objective carriers through UnitPvpClassification.
-- This is the same path used by current oUF/ElvUI PvP classification indicators
-- and remains usable when aura payloads/IDs are secret.
local PVP_OBJECTIVE_INFO = {}
do
    local classifications = Enum and Enum.PvPUnitClassification
    local function AddObjective(key, atlas, r, g, b)
        PVP_OBJECTIVE_INFO[key] = { atlas = atlas, r = r, g = g, b = b }
    end

    AddObjective((classifications and classifications.FlagCarrierHorde) or 0, "nameplates-icon-flag-horde", 1.00, 0.25, 0.25)
    AddObjective((classifications and classifications.FlagCarrierAlliance) or 1, "nameplates-icon-flag-alliance", 0.26, 0.60, 1.00)
    AddObjective((classifications and classifications.FlagCarrierNeutral) or 2, "nameplates-icon-flag-neutral", 1.00, 0.86, 0.26)
    AddObjective((classifications and classifications.CartRunnerHorde) or 3, "nameplates-icon-cart-horde", 1.00, 0.25, 0.25)
    AddObjective((classifications and classifications.CartRunnerAlliance) or 4, "nameplates-icon-cart-alliance", 0.26, 0.60, 1.00)
    AddObjective((classifications and classifications.AssassinHorde) or 5, "nameplates-icon-bounty-horde", 1.00, 0.25, 0.25)
    AddObjective((classifications and classifications.AssassinAlliance) or 6, "nameplates-icon-bounty-alliance", 0.26, 0.60, 1.00)
    AddObjective((classifications and classifications.OrbCarrierBlue) or 7, "nameplates-icon-orb-blue", 0.30, 0.75, 1.00)
    AddObjective((classifications and classifications.OrbCarrierGreen) or 8, "nameplates-icon-orb-green", 0.28, 1.00, 0.40)
    AddObjective((classifications and classifications.OrbCarrierOrange) or 9, "nameplates-icon-orb-orange", 1.00, 0.62, 0.14)
    AddObjective((classifications and classifications.OrbCarrierPurple) or 10, "nameplates-icon-orb-purple", 0.86, 0.42, 1.00)
end

local OBJECTIVE_BORDER_TEXTURES = {
    THIN = "Interface\\AddOns\\BattleMender\\Textures\\Ring_10px.tga",
    NORMAL = "Interface\\AddOns\\BattleMender\\Textures\\Ring_20px.tga",
    METAL = "Interface\\AddOns\\BattleMender\\Textures\\Ring_30px.tga",
    COGWHEEL = "Interface\\AddOns\\BattleMender\\Textures\\defensive_cogwheel.tga",
}

local OBJECTIVE_BORDER_FIT = { THIN = 0.964, NORMAL = 1, METAL = 1.036, COGWHEEL = 1.12 }

local function GetPvPObjectiveInfo(unit)
    if not unit or not UnitPvpClassification then return nil end

    local ok, atlas, r, g, b = pcall(function()
        local classification = UnitPvpClassification(unit)
        local info = classification and PVP_OBJECTIVE_INFO[classification]
        if not info then return nil end
        return info.atlas, info.r, info.g, info.b
    end)

    if ok and type(atlas) == "string" and atlas ~= "" then
        return atlas, r, g, b
    end

    return nil
end

-- Shared with the custom enemy provider so objective presentation uses the same
-- Blizzard classification source and the same flag/orb/cart colors as friendly
-- objective badges. Keep the secret-value handling inside the resolver above.
BattleMender.GetPvPObjectiveInfo = GetPvPObjectiveInfo

-------------------------------------------------
-- Texture helpers
-------------------------------------------------

function BattleMender.GetCustomSpecTexture(specID)
    if not specID then return nil end

    -- A failed GetInspectSpecialization call reports 0. Do not turn that into a
    -- missing specs/0.tga path, which the client renders as a blank white disk.
    local ok, usable = pcall(function()
        return type(specID) == "number" and specID > 0
    end)
    if not ok or usable ~= true then return nil end

    return SPEC_PATH .. specID .. ".tga"
end

function BattleMender.PositionElement(element, parentFrame)
    if not element or not parentFrame then return end

    local point = CFG.anchorPoint or "TOP"
    local x = CFG.anchorX or 0
    local y = CFG.anchorY or 0

    if element.BMLastPoint == point
        and element.BMLastX == x
        and element.BMLastY == y
        and element.BMLastParent == parentFrame
    then
        return
    end

    element:ClearAllPoints()
    element:SetPoint(point, parentFrame, point, x, y)

    element.BMLastPoint = point
    element.BMLastX = x
    element.BMLastY = y
    element.BMLastParent = parentFrame
end

function BattleMender.GetOverlayTexture(mode, unit, specID)
    if mode == "NONE" then
        return nil, nil
    end

    if mode == "SOLID" then
        return WHITE, nil
    end

    if mode == "CLASS" then
        return BattleMender.ClassIcon(unit)
    end

    if mode == "SPEC" then
        if specID then
            local tex = BattleMender.GetCustomSpecTexture(specID)
            if tex then return tex, nil end
        end

        -- 12.1 can withhold an inspect specialization for public city plates.
        -- The class is still safe to render, and is materially better than the
        -- white missing-texture fallback while we wait for a real spec result.
        return BattleMender.ClassIcon(unit)
    end

    return nil, nil
end

function BattleMender.GetOverlayColor(useClass, unit, defR, defG, defB)
    if useClass then
        local c = BattleMender.ClassColor(unit)
        return c.r, c.g, c.b
    end

    return defR or 1, defG or 1, defB or 1
end

local function ApplyTexCoords(texture, coords, specCrop)
    if not texture then return end

    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    elseif specCrop then
        texture:SetTexCoord(0.04, 0.96, 0.04, 0.96)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function GetSpecTexture(unit, specID)
    return BattleMender.GetOverlayTexture("SPEC", unit, specID)
end

local function GetPrimaryUnitArt(unit, specID)
    if CFG.healerCrossEnabled and BattleMender.IsHealerUnit(unit, specID) then
        return BattleMender.HealerBackgroundTexture, { 0, 1, 0, 1 }, false
    end
    local texture, coords = GetSpecTexture(unit, specID)
    return texture, coords, false
end

local function ApplyPrimaryArt(texture, art, coords, isAtlas, specCrop)
    if not texture or not art then return false end

    if isAtlas then
        if not texture.SetAtlas then return false end
        local ok = pcall(texture.SetAtlas, texture, art, false)
        return ok == true
    end

    texture:SetTexture(art)
    ApplyTexCoords(texture, coords, specCrop)
    return true
end

local function GetDamageColor()
    return
        CFG.damageIconR or CFG.iconColorR or 1,
        CFG.damageIconG or CFG.iconColorG or 0.02,
        CFG.damageIconB or CFG.iconColorB or 0.02
end

local function Clamp01(v)
    v = tonumber(v) or 0

    if v < 0 then
        return 0
    elseif v > 1 then
        return 1
    end

    return v
end

local function ClampNumber(v, minValue, maxValue, fallback)
    v = tonumber(v)
    if v == nil then return fallback end
    if minValue ~= nil and v < minValue then return minValue end
    if maxValue ~= nil and v > maxValue then return maxValue end
    return v
end

local function GetFrameEffectiveScale(frame)
    if not frame or type(frame.GetEffectiveScale) ~= "function" then
        return nil
    end

    local ok, scale = pcall(frame.GetEffectiveScale, frame)
    if ok then
        scale = tonumber(scale)
        if scale and scale > 0 then
            return scale
        end
    end

    return nil
end

local function ResolveFriendlyVisualScale(plate, parentFrame, unit)
    local scale = 1

    if CFG.friendlyVisualScaleLock ~= false then
        local uiScale = GetFrameEffectiveScale(UIParent) or 1
        local parentScale = GetFrameEffectiveScale(parentFrame) or GetFrameEffectiveScale(plate)

        if parentScale and parentScale > 0 then
            -- Child visuals inherit the native nameplate scale. Invert that scale so
            -- BattleMender's configured Icon Size remains stable on screen. Clamp the
            -- compensation so broken/temporary scale reads cannot explode the overlay.
            scale = ClampNumber(uiScale / parentScale, 0.35, 3.0, 1)
        end
    end

    -- Arena emphasis is independent of the optional native-scale compensation.
    -- It scales only BattleMender-owned visual frames; Core.lua applies the same
    -- multiplier to the secure friendly clickbox when an out-of-combat resize is safe.
    if BattleMender.IsArenaInstance and BattleMender.IsArenaInstance() then
        local arenaScale = ClampNumber(CFG.arenaFriendlyPlateScale, 1, 2, 1)
        scale = scale * arenaScale
    end

    -- Per-unit affiliate emphasis is visual-only. Blizzard's friendly clickbox
    -- geometry is global, so changing it here would enlarge every friendly unit.
    if unit and BattleMender.IsFriendlyAffiliate and BattleMender.IsFriendlyAffiliate(unit) then
        scale = scale * ClampNumber(CFG.affiliatePlateScale, 1, 1.5, 1)
    end

    return scale
end

function BattleMender.ApplyFriendlyVisualScale(frame, overlay, plate, parentFrame, unit)
    if not overlay then return 1 end

    local scale = ResolveFriendlyVisualScale(plate, parentFrame or frame, unit)

    if overlay.BMLastVisualScale == scale then
        return scale
    end

    overlay.BMLastVisualScale = scale

    local function setFrameScale(f)
        if f and type(f.SetScale) == "function" then
            f:SetScale(scale)
        end
    end

    setFrameScale(overlay.haloFrame)
    setFrameScale(overlay.damagedFrame)
    setFrameScale(overlay.specFrame)
    setFrameScale(overlay.ringFrame)
    setFrameScale(overlay.accentFrame)
    setFrameScale(overlay.objectiveFrame)
    setFrameScale(overlay.healthOverlay)
    setFrameScale(overlay.healthClipFrame)
    setFrameScale(overlay.healerControlHost)
    setFrameScale(overlay.affiliateFrame)

    return scale
end

function BattleMender.GetFriendlyVisualScale(frame, plate, unit)
    local parent = BattleMender.GetVisualFrame and BattleMender.GetVisualFrame(plate) or frame
    return ResolveFriendlyVisualScale(plate, parent, unit)
end

local function AutoCompensateHealthOverlayColor(r, g, b, alpha, blend, faded)
    -- Only compensate the LoS health overlay.
    if not faded then
        return r, g, b
    end

    -- Only compensate normal alpha blending.
    if (blend or "BLEND") ~= "BLEND" then
        return r, g, b
    end

    alpha = Clamp01(alpha or 1)

    if alpha <= 0.001 then
        return r, g, b
    end

    -- Approximate the red damaged layer underneath.
    local dr, dg, db = GetDamageColor()

    local damageAlpha = Clamp01(
        CFG.losDamageIconAlpha
        or CFG.damageIconAlpha
        or CFG.iconAlpha
        or 1
    )

    -- Background contribution after its own alpha.
    dr = dr * damageAlpha
    dg = dg * damageAlpha
    db = db * damageAlpha

    local invAlpha = 1 - alpha

    -- Reverse alpha blend:
    -- final = source * alpha + background * (1 - alpha)
    -- source = (final - background * (1 - alpha)) / alpha
    local outR = (r - dr * invAlpha) / alpha
    local outG = (g - dg * invAlpha) / alpha
    local outB = (b - db * invAlpha) / alpha

    return Clamp01(outR), Clamp01(outG), Clamp01(outB)
end
-------------------------------------------------
-- Hover glow helpers
-------------------------------------------------

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
            tex:Hide()
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

    tex:SetAlpha(0)
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

    tex:SetAlpha(0)
    tex.fader:SetFromAlpha(peakAlpha)
    tex.fader:SetToAlpha(0)
    tex.fader:SetDuration(duration)
    tex.anim:Play()
end

local function CreatePulseAnimation(texture)
    local group = texture:CreateAnimationGroup()
    group:SetLooping("REPEAT")

    local up = group:CreateAnimation("Alpha")
    up:SetOrder(1)
    up:SetSmoothing("IN_OUT")

    local down = group:CreateAnimation("Alpha")
    down:SetOrder(2)
    down:SetSmoothing("IN_OUT")

    texture.pulseAnim = group
    texture.pulseUp = up
    texture.pulseDown = down
    return group, up, down
end

local function ConfigurePulseAnimation(texture, enabled, minAlpha, maxAlpha, duration)
    if not texture or not texture.pulseAnim then return end

    texture.pulseAnim:Stop()

    if not enabled then
        texture:SetAlpha(maxAlpha or 1)
        return
    end

    minAlpha = ClampNumber(minAlpha, 0, 1, 0.2)
    maxAlpha = ClampNumber(maxAlpha, 0, 1, 1)
    duration = ClampNumber(duration, 0.15, 2.5, 0.9)

    texture.pulseUp:SetFromAlpha(minAlpha)
    texture.pulseUp:SetToAlpha(maxAlpha)
    texture.pulseUp:SetDuration(duration)
    texture.pulseDown:SetFromAlpha(maxAlpha)
    texture.pulseDown:SetToAlpha(minAlpha)
    texture.pulseDown:SetDuration(duration)
    texture:SetAlpha(minAlpha)
    texture.pulseAnim:Play()
end

-------------------------------------------------
-- Plate alpha sync
-------------------------------------------------
local function ApplyNameplateFadeAlpha(plate, overlay)
    if not plate or not overlay then return end

    local fadeAlpha = 1
    if plate.GetAlpha then
        fadeAlpha = plate:GetAlpha() or 1
    end

    if fadeAlpha < 0 then
        fadeAlpha = 0
    elseif fadeAlpha > 1 then
        fadeAlpha = 1
    end

    local faded = overlay.BMLastLOS == true

    -------------------------------------------------
    -- Damaged / missing-health spec icon
    -------------------------------------------------

    if overlay.damagedSpecIcon then
        local alpha = faded
            and (CFG.losDamageIconAlpha or CFG.damageIconAlpha or CFG.iconAlpha or 1)
            or  (CFG.damageIconAlpha or CFG.iconAlpha or 1)

        if overlay.healerActive and CFG.healthEnable == false then
            alpha = faded and (CFG.losSpecIconAlpha or 1) or (CFG.specIconAlpha or 1)
        end

        overlay.damagedSpecIcon:SetAlpha(faded and alpha or (alpha * fadeAlpha))
    end

    -------------------------------------------------
    -- Pulse overlay
    -------------------------------------------------

    if overlay.pulseOverlay then
        overlay.pulseOverlay:SetAlpha(fadeAlpha)
    end

    -------------------------------------------------
    -- Health-clipped visible spec icon
    --
    -- Important:
    -- healthSpecFrame uses SetIgnoreParentAlpha(true),
    -- so setting alpha on healthClipFrame does not reliably
    -- affect the visible icon.
    -------------------------------------------------

    if overlay.healthClipFrame then
        overlay.healthClipFrame:SetAlpha(1)
    end

    if overlay.healthSpecFrame then
        overlay.healthSpecFrame:SetAlpha(1)
    end

    if overlay.healthSpecIcon then
        local alpha = faded
            and (CFG.losSpecIconAlpha or CFG.specIconAlpha or 1)
            or  (CFG.specIconAlpha or 1)

        overlay.healthSpecIcon:SetAlpha(faded and alpha or (alpha * fadeAlpha))
    end

    -------------------------------------------------
    -- Hidden spec frame / glow owner
    -------------------------------------------------

    if overlay.specFrame then
        overlay.specFrame:SetAlpha(1)
    end

    if overlay.specIcon then
        overlay.specIcon:SetAlpha(0)
    end

    if overlay.healerActive then
        local alpha = faded and (CFG.losSpecIconAlpha or 1) or (CFG.specIconAlpha or 1)
        local finalAlpha = faded and alpha or alpha * fadeAlpha
        if overlay.healerDamagedCross then overlay.healerDamagedCross:SetAlpha(finalAlpha) end
        if overlay.healerHealthyCross then overlay.healerHealthyCross:SetAlpha(finalAlpha) end
        if overlay.healerControlHost then overlay.healerControlHost:SetAlpha(faded and 1 or fadeAlpha) end
        if overlay.affiliateFrame then overlay.affiliateFrame:SetAlpha(faded and 1 or fadeAlpha) end
    end

    -------------------------------------------------
    -- Class ring
    -------------------------------------------------

    if overlay.classRing then
        local alpha = faded
            and (CFG.losRingAlpha or CFG.ringAlpha or 1)
            or  (CFG.ringAlpha or 1)

        overlay.classRing:SetAlpha(faded and alpha or (alpha * fadeAlpha))
    end

    -------------------------------------------------
    -- Health overlay
    -------------------------------------------------

	if overlay.healthOverlay then
		overlay.healthOverlay:SetAlpha(faded and 1 or fadeAlpha)
	end

    if overlay.healthOverlayTexture then
        local alpha = faded
            and (CFG.losHealthOverlayAlpha or CFG.healthOverlayAlpha or 1)
            or  (CFG.healthOverlayAlpha or 1)

        overlay.healthOverlayTexture:SetAlpha(alpha)
    end

    -------------------------------------------------
    -- Hover / glow visuals
    -------------------------------------------------

    if overlay.haloGlow and overlay.haloGlow:IsShown() then
        local alpha = CFG.haloGlowAlpha or 1
        overlay.haloGlow:SetAlpha(alpha * fadeAlpha)
    end

    -- Hover glow animations own their texture alpha while fading. Writing
    -- SetAlpha here at the same time makes the glow flash to its peak and then
    -- disappear/restart when the Alpha animation evaluates on the next frame.
    if overlay.specGlow and overlay.specGlow:IsShown()
        and not (overlay.specGlow.anim and overlay.specGlow.anim:IsPlaying())
    then
        local alpha = CFG.specGlowBrightness or 1
        overlay.specGlow:SetAlpha(alpha * fadeAlpha)
    end

    if overlay.ringGlow and overlay.ringGlow:IsShown()
        and not (overlay.ringGlow.anim and overlay.ringGlow.anim:IsPlaying())
    then
        local alpha = CFG.ringGlowBrightness or 1
        overlay.ringGlow:SetAlpha(alpha * fadeAlpha)
    end
end

-------------------------------------------------
-- Overlay creation
-------------------------------------------------

function BattleMender.EnsureOverlay(frame)
    local existing = BM_OVERLAYS[frame]
    if existing then return existing end

    -------------------------------------------------
    -- Halo layer
    -------------------------------------------------

    local haloFrame = CreateFrame("Frame", nil, frame)
    haloFrame:SetIgnoreParentAlpha(true)
    haloFrame:SetFrameStrata("TOOLTIP")
    haloFrame:SetFrameLevel(315)

    local haloGlow = haloFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    haloGlow:SetPoint("CENTER")
    haloGlow:SetBlendMode("ADD")
    haloGlow:SetAlpha(1)
    haloGlow:Hide()

    -------------------------------------------------
	-- Damaged / missing-health layer
	-------------------------------------------------

	local damagedFrame = CreateFrame("Frame", nil, frame)
	damagedFrame:SetIgnoreParentAlpha(true)
	damagedFrame:SetFrameStrata("TOOLTIP")
	damagedFrame:SetFrameLevel(320)

	local damagedSpecIcon = damagedFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	damagedSpecIcon:SetAllPoints()
	damagedSpecIcon:Hide()

    -- Healer missing-health cross. It lives on the same full damaged layer as
    -- the red backing, while the healthy green cross is clipped above it by
    -- the normal health boundary.
    local healerDamagedCross = damagedFrame:CreateTexture(nil, "ARTWORK", nil, 3)
    healerDamagedCross:SetPoint("CENTER", damagedFrame, "CENTER")
    healerDamagedCross:Hide()

	local pulseOverlay = damagedFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	pulseOverlay:SetAllPoints()
	pulseOverlay:Hide()

    -- Diagnostic-only range label. It is BattleMender-owned and never receives
    -- secret values directly; Core converts only public UnitInRange results to
    -- one of the fixed state strings below.
	local mask1 = damagedFrame:CreateMaskTexture()
	mask1:SetTexture(
		DAMAGED_CIRCLE_MASK,
		"CLAMPTOBLACKADDITIVE",
		"CLAMPTOBLACKADDITIVE"
	)
	mask1:SetAllPoints()

	damagedSpecIcon:AddMaskTexture(mask1)
	pulseOverlay:AddMaskTexture(mask1)

    -------------------------------------------------
    -- Spec glow layer
    -- The visible full-color spec icon is health-clipped below.
    -- This hidden specIcon is retained only as a stable glow/mask owner.
    -------------------------------------------------

    local specFrame = CreateFrame("Frame", nil, frame)
    specFrame:SetIgnoreParentAlpha(true)
    specFrame:SetFrameStrata("TOOLTIP")
    specFrame:SetFrameLevel(330)

    local specIcon = specFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    specIcon:SetAllPoints()
    specIcon:SetAlpha(0)
    specIcon:Hide()

    local mask2 = specFrame:CreateMaskTexture()
    mask2:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask2:SetAllPoints()
    specIcon:AddMaskTexture(mask2)

    local specGlow = CreateHoverGlow(specFrame)
    specGlow:AddMaskTexture(mask2)

    -- Hard-CC / silence is intentionally separated from the healer center mass.
    -- Defensives.lua owns the managed aura button inside this addon-owned badge
    -- host; the host itself remains safe to position and scale at runtime.
    local healerControlHost = CreateFrame("Frame", nil, frame:GetParent() or frame)
    healerControlHost:SetIgnoreParentAlpha(true)
    healerControlHost:SetFrameStrata("TOOLTIP")
    healerControlHost:SetFrameLevel(338)
    healerControlHost:EnableMouse(false)
    healerControlHost:Hide()

    -- General affiliation badge. Bundled full-color star art is selected in
    -- Friendly Plates > Affiliates; the center glyph shows the highest-priority
    -- relationship.
    local affiliateFrame = CreateFrame("Frame", nil, frame:GetParent() or frame)
    affiliateFrame:SetIgnoreParentAlpha(true)
    affiliateFrame:SetFrameStrata("TOOLTIP")
    affiliateFrame:SetFrameLevel(337)
    affiliateFrame:EnableMouse(false)
    affiliateFrame:Hide()

    local affiliateStarOuter = affiliateFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    affiliateStarOuter:SetTexture(BattleMender.GetAffiliateBadgeTexture(CFG.affiliateBadgeTexture))
    affiliateStarOuter:SetTexCoord(0, 1, 0, 1)
    affiliateStarOuter:SetVertexColor(1, 1, 1, 1)
    affiliateStarOuter:SetPoint("CENTER")

    -- Retained as a hidden compatibility region for overlays created by this
    -- build; the supplied textures already contain their complete star finish.
    local affiliateStarInner = affiliateFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    affiliateStarInner:SetPoint("CENTER")
    affiliateStarInner:Hide()

    local affiliateText = affiliateFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    affiliateText:SetPoint("CENTER", affiliateFrame, "CENTER", 0, 0)
    affiliateText:SetJustifyH("CENTER")
    affiliateText:SetJustifyV("MIDDLE")
    affiliateText:SetTextColor(1, 0.92, 0.58, 1)

    -------------------------------------------------
    -- Ring layer
    -------------------------------------------------

    local ringFrame = CreateFrame("Frame", nil, frame)
    ringFrame:SetIgnoreParentAlpha(true)
    ringFrame:SetFrameStrata("TOOLTIP")
    ringFrame:SetFrameLevel(335)

    local classRing = ringFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    classRing:SetAllPoints()
    classRing:SetTexture("Interface\\AddOns\\BattleMender\\Textures\\Ring_20px.tga")

    local mask3 = ringFrame:CreateMaskTexture()
    mask3:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask3:SetAllPoints()

    local ringGlow = CreateHoverGlow(ringFrame)
    ringGlow:AddMaskTexture(mask3)
	
    -------------------------------------------------
    -- Accent Overlay layer
    -------------------------------------------------

    local accentFrame = CreateFrame("Frame", nil, frame)
    accentFrame:SetIgnoreParentAlpha(true)
    accentFrame:SetFrameStrata("TOOLTIP")
    accentFrame:SetFrameLevel(335)

	local accentOverlay = accentFrame:CreateTexture(nil, "OVERLAY", nil, 6)
	accentOverlay:SetAllPoints()
	accentOverlay:SetBlendMode("BLEND")
	accentOverlay:SetAlpha(CFG.accentOverlayAlpha or 1)

	if accentOverlay.SetSnapToPixelGrid then
		accentOverlay:SetSnapToPixelGrid(false)
	end

	if accentOverlay.SetTexelSnappingBias then
		accentOverlay:SetTexelSnappingBias(0)
	end

	accentOverlay:Hide()

    local accentMask = accentFrame:CreateMaskTexture()
    accentMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    accentMask:SetAllPoints()
    accentOverlay:AddMaskTexture(accentMask)

	local accentGlow = accentFrame:CreateTexture(nil, "OVERLAY", nil, 7)
	accentGlow:SetAllPoints()
	accentGlow:SetBlendMode("ADD")
	accentGlow:SetAlpha(0)
	accentGlow:Hide()
	accentGlow:AddMaskTexture(accentMask)

	local accentGlowAnim = accentGlow:CreateAnimationGroup()
	local accentGlowAlpha = accentGlowAnim:CreateAnimation("Alpha")
	accentGlowAlpha:SetSmoothing("IN_OUT")

	accentGlow.anim = accentGlowAnim
	accentGlow.fader = accentGlowAlpha

	accentGlowAnim:SetScript("OnFinished", function(self)
		local tex = self:GetParent()
		tex:SetAlpha(self.targetAlpha)
		if self.targetAlpha == 0 then
			tex:Hide()
		end
	end)

    -------------------------------------------------
    -- PvP objective badge
    -------------------------------------------------

    local objectiveFrame = CreateFrame("Frame", nil, frame)
    objectiveFrame:SetIgnoreParentAlpha(true)
    objectiveFrame:SetFrameStrata("TOOLTIP")
    objectiveFrame:SetFrameLevel(338)
    objectiveFrame:Hide()

    local objectiveBackplate = objectiveFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    objectiveBackplate:SetTexture(WHITE)
    objectiveBackplate:SetVertexColor(0, 0, 0, 1)
    objectiveBackplate:SetAllPoints()

    local objectiveIcon = objectiveFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    objectiveIcon:SetAllPoints()
    objectiveIcon:Hide()

    local objectiveMask = objectiveFrame:CreateMaskTexture()
    objectiveMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    objectiveMask:SetAllPoints()
    objectiveBackplate:AddMaskTexture(objectiveMask)
    objectiveIcon:AddMaskTexture(objectiveMask)

    local objectiveBorder = objectiveFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    objectiveBorder:SetAllPoints()
    objectiveBorder:Hide()

    local objectiveGlow = objectiveFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    objectiveGlow:SetBlendMode("ADD")
    objectiveGlow:SetAlpha(0)
    objectiveGlow:Hide()

    CreatePulseAnimation(objectiveIcon)
    CreatePulseAnimation(objectiveGlow)

    -------------------------------------------------
    -- Native hit-test target + debug clickbox
    -------------------------------------------------

    -- This is not an independent clickable button. Blizzard's outer NamePlate
    -- frame uses this BattleMender-owned region only as its hit-test geometry.
    -- Parenting it to damagedFrame keeps it aligned with the visible circular
    -- plate, including configured anchors and optional visual scale locking.
    local hitTestFrame = CreateFrame("Frame", nil, damagedFrame)
    hitTestFrame:SetPoint("CENTER", damagedFrame, "CENTER", 0, 0)
    hitTestFrame:SetSize(CFG.clickSize or 60, CFG.clickSize or 60)
    hitTestFrame:EnableMouse(false)
    hitTestFrame:Show()

    local debugBox = hitTestFrame:CreateTexture(nil, "BACKGROUND")
    debugBox:SetAllPoints(hitTestFrame)
    debugBox:SetColorTexture(0, 1, 0, 0.3)
    debugBox:Hide()

	local overlay = {
		haloFrame = haloFrame,
		damagedFrame = damagedFrame,
		specFrame = specFrame,
        healerDamagedCross = healerDamagedCross,
		healerControlHost = healerControlHost,
        affiliateFrame = affiliateFrame,
        affiliateStarInner = affiliateStarInner,
        affiliateStarOuter = affiliateStarOuter,
        affiliateText = affiliateText,
		ringFrame = ringFrame,
		accentFrame = accentFrame,
		objectiveFrame = objectiveFrame,

		haloGlow = haloGlow,
		damagedSpecIcon = damagedSpecIcon,
		pulseOverlay = pulseOverlay,
		specIcon = specIcon,
		specGlow = specGlow,
		classRing = classRing,
		ringGlow = ringGlow,
		accentOverlay = accentOverlay,
		accentGlow = accentGlow,
		objectiveBackplate = objectiveBackplate,
		objectiveIcon = objectiveIcon,
		objectiveBorder = objectiveBorder,
		objectiveGlow = objectiveGlow,
        hitTestFrame = hitTestFrame,
		debugBox = debugBox,
	}

    BM_OVERLAYS[frame] = overlay
    return overlay
end

function BattleMender.GetOverlay(frame)
    if not frame then return nil end
    return BM_OVERLAYS and BM_OVERLAYS[frame]
end

function BattleMender.BindFriendlyHitTest(frame, plate, overlay)
    if not frame or not plate or not overlay or not overlay.hitTestFrame then
        return false
    end

    local hitTestFrame = overlay.hitTestFrame
    local size = CFG.clickSize or 60

    if hitTestFrame.BMLastSize ~= size then
        hitTestFrame:SetSize(size, size)
        hitTestFrame.BMLastSize = size
    end

    if type(plate.ClearAllHitTestPoints) ~= "function"
        or type(plate.SetAllHitTestPoints) ~= "function"
    then
        return false
    end

    if CFG.friendlyClickthrough == true then
        hitTestFrame:Hide()
        if overlay.hitTestPlate ~= plate or overlay.hitTestClickthrough ~= true then
            local ok = pcall(function()
                plate:ClearAllHitTestPoints()
            end)
            if not ok then return false end
            overlay.hitTestPlate = plate
            overlay.hitTestClickthrough = true
        end
        BattleMender.FriendlyHitTestBindingApplied = true
        return true
    end

    hitTestFrame:Show()
    if overlay.hitTestPlate ~= plate or overlay.hitTestClickthrough ~= false then
        local ok = pcall(function()
            plate:ClearAllHitTestPoints()
            plate:SetAllHitTestPoints(hitTestFrame)
        end)

        if not ok then
            return false
        end

        overlay.hitTestPlate = plate
        overlay.hitTestClickthrough = false
    end

    BattleMender.FriendlyHitTestBindingApplied = true
    return true
end


function BattleMender.RestoreNativeHitTest(frame, overlay)
    overlay = overlay or (frame and BM_OVERLAYS[frame])
    if not overlay then return false end

    local plate = overlay.hitTestPlate
    overlay.hitTestPlate = nil
    overlay.hitTestClickthrough = nil

    if overlay.hitTestFrame then
        overlay.hitTestFrame:Hide()
        overlay.hitTestFrame.BMLastSize = nil
    end

    if not plate
        or type(plate.ClearAllHitTestPoints) ~= "function"
        or type(plate.SetAllHitTestPoints) ~= "function"
    then
        return false
    end

    local ok = pcall(function()
        plate:ClearAllHitTestPoints()
        if frame then
            plate:SetAllHitTestPoints(frame)
        end
    end)

    return ok
end

-------------------------------------------------
-- BattleMender-owned health overlay
-------------------------------------------------

local function EnsureBMHealthOverlay(frame, plate)
    local overlay = BattleMender.EnsureOverlay(frame)
    if overlay.healthOverlay then
        return overlay.healthOverlay, overlay.healthOverlayTexture
    end

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetIgnoreParentAlpha(true)
    health:SetFrameStrata("TOOLTIP")
    health:SetFrameLevel(325)
    health:SetOrientation("VERTICAL")
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    health:Hide()

    health:SetStatusBarTexture(WHITE)

    local tex = health:GetStatusBarTexture()
    tex:SetHorizTile(false)
    tex:SetVertTile(true)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetDrawLayer("ARTWORK", 6)

    if tex.AddMaskTexture then
        local mask = health:CreateMaskTexture()
        mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints()
        tex:AddMaskTexture(mask)
        health.BMMask = mask
    end

    local healthClipFrame = CreateFrame("Frame", nil, frame)
    healthClipFrame:SetIgnoreParentAlpha(true)
    healthClipFrame:SetFrameStrata("TOOLTIP")
    healthClipFrame:SetFrameLevel(326)

    if healthClipFrame.SetClipsChildren then
        healthClipFrame:SetClipsChildren(true)
    end

    healthClipFrame:Hide()

	-------------------------------------------------
	-- Full-color spec icon clipped by healthClipFrame
	-- healthClipFrame clips child FRAMES, so the icon
	-- must live inside healthSpecFrame, not directly
	-- on healthClipFrame.
	-------------------------------------------------

	local healthSpecFrame = CreateFrame("Frame", nil, healthClipFrame)
	healthSpecFrame:SetIgnoreParentAlpha(true)
	healthSpecFrame:SetFrameStrata("TOOLTIP")
	healthSpecFrame:SetFrameLevel(327)
	healthSpecFrame:Hide()

	local healthSpecIcon = healthSpecFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	healthSpecIcon:SetAllPoints()
	healthSpecIcon:SetBlendMode("MOD")
	healthSpecIcon:SetDesaturated(false)
	healthSpecIcon:SetVertexColor(1, 1, 1, 1)
	healthSpecIcon:SetAlpha(1)
	healthSpecIcon:Hide()

	local healthSpecMask = healthSpecFrame:CreateMaskTexture()
	healthSpecMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	healthSpecMask:SetAllPoints()

	healthSpecIcon:AddMaskTexture(healthSpecMask)

    -- Healthy healer cross is a child of the same clipped frame as the healthy
    -- background, so the health boundary cuts through both pieces identically.
    local healerHealthyCross = healthSpecFrame:CreateTexture(nil, "ARTWORK", nil, 2)
    healerHealthyCross:SetPoint("CENTER", healthSpecFrame, "CENTER")
    healerHealthyCross:Hide()

	overlay.healthOverlay = health
	overlay.healthOverlayTexture = tex
	overlay.healthClipFrame = healthClipFrame
	overlay.healthSpecFrame = healthSpecFrame
	overlay.healthSpecIcon = healthSpecIcon
	overlay.healthSpecMask = healthSpecMask
    overlay.healerHealthyCross = healerHealthyCross

    return health, tex
end

local function HideOverlayVisuals(overlay)
    if not overlay then return end
    BattleMender.HideHealerVisuals(overlay)

    if overlay.haloFrame then overlay.haloFrame:Hide() end
    if overlay.damagedFrame then overlay.damagedFrame:Hide() end
    if overlay.specFrame then overlay.specFrame:Hide() end
    if overlay.ringFrame then overlay.ringFrame:Hide() end
    if overlay.accentFrame then overlay.accentFrame:Hide() end
    if overlay.objectiveFrame then overlay.objectiveFrame:Hide() end

    if overlay.damagedSpecIcon then overlay.damagedSpecIcon:Hide() end
    if overlay.pulseOverlay then overlay.pulseOverlay:Hide() end

    if overlay.specIcon then overlay.specIcon:Hide() end
    if overlay.specGlow then overlay.specGlow:Hide() end

    if overlay.classRing then overlay.classRing:Hide() end
    if overlay.ringGlow then overlay.ringGlow:Hide() end
    if overlay.haloGlow then overlay.haloGlow:Hide() end

    if overlay.accentOverlay then
        overlay.accentOverlay:Hide()
        overlay.accentOverlay:SetAlpha(0)
    end

    if overlay.accentGlow then
        if overlay.accentGlow.anim then
            overlay.accentGlow.anim:Stop()
        end
        overlay.accentGlow:Hide()
        overlay.accentGlow:SetAlpha(0)
    end

    if overlay.objectiveIcon then
        if overlay.objectiveIcon.pulseAnim then overlay.objectiveIcon.pulseAnim:Stop() end
        overlay.objectiveIcon:Hide()
        overlay.objectiveIcon:SetAlpha(1)
    end
    if overlay.objectiveBorder then overlay.objectiveBorder:Hide() end
    if overlay.objectiveGlow then
        if overlay.objectiveGlow.pulseAnim then overlay.objectiveGlow.pulseAnim:Stop() end
        overlay.objectiveGlow:Hide()
        overlay.objectiveGlow:SetAlpha(0)
    end

    if overlay.healthOverlay then overlay.healthOverlay:Hide() end
    if overlay.healthClipFrame then overlay.healthClipFrame:Hide() end
    if overlay.healthSpecFrame then overlay.healthSpecFrame:Hide() end
    if overlay.healthSpecIcon then overlay.healthSpecIcon:Hide() end
    if overlay.healthSpecMask then overlay.healthSpecMask:Hide() end

    if overlay.hitTestFrame then overlay.hitTestFrame:Hide() end
    if overlay.debugBox then overlay.debugBox:Hide() end
end

function BattleMender.HideOverlayVisuals(frame)
    HideOverlayVisuals(frame and BM_OVERLAYS[frame])
end

function BattleMender.RestoreBar(frame)
    -- Used when a friendly plate is cleared or health overlay is disabled.
    -- Hiding all BattleMender-owned visuals prevents recycled plates from
    -- carrying stale spec textures onto NPC/enemy plates.
    BattleMender.HideOverlayVisuals(frame)
end

-------------------------------------------------
-- Health overlay application
-------------------------------------------------

local function SetupHealthBarFrame(bar, frame, plate)
    local parent = BattleMender.GetVisualFrame(plate) or frame
    local overlay = frame and BM_OVERLAYS[frame]
    local state = frame and BattleMender.GetState(frame)
    local unit = state and (state.unit or BattleMender.ResolvePlateUnit(plate, frame))

    if BattleMender.ApplyFriendlyVisualScale then
        BattleMender.ApplyFriendlyVisualScale(frame, overlay, plate, parent, unit)
    end

    if bar.SetOrientation then
        pcall(bar.SetOrientation, bar, "VERTICAL")
    end

    BattleMender.PositionElement(bar, parent)
    bar:SetSize(CFG.iconSize or 45, CFG.iconSize or 45)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(325)
end

function BattleMender.ApplyVerticalBar(frame, plate)
    if not frame then return end

	if CFG.healthEnable == false then
		HideHealthOverlay(BM_OVERLAYS[frame])
		return
	end

    local state = BattleMender.GetState(frame)
    local unit = state.unit or BattleMender.ResolvePlateUnit(plate, frame)
    if not unit then return end

    local bar, tex = EnsureBMHealthOverlay(frame, plate)
    if not bar or not tex then return end

	SetupHealthBarFrame(bar, frame, plate)

	-- Do not apply color here.
	if not tex.BMTextureInitialized then
		tex:SetHorizTile(false)
		tex:SetVertTile(true)
		tex:SetTexCoord(0, 1, 0, 1)
		tex:SetDrawLayer("ARTWORK", 6)
		tex.BMTextureInitialized = true
	end

    -- Do not compare these values. On modern WoW nameplates they may be secret
    -- numbers; passing them to StatusBar APIs is fine, arithmetic/comparison is not.
    local maxHealth = UnitHealthMax(unit)
    local health = UnitHealth(unit)
    pcall(bar.SetMinMaxValues, bar, 0, maxHealth)
    pcall(bar.SetValue, bar, health)

    if bar.SetReverseFill then
        bar:SetReverseFill(CFG.healthOverlayReverseFill == true)
    end
end

-------------------------------------------------
-- Positioning / LoS
-------------------------------------------------

local function PrepareOverlayHolders(overlay, parent)
    local size = CFG.iconSize or 45

    if overlay.haloFrame then
        BattleMender.PositionElement(overlay.haloFrame, parent)
        overlay.haloFrame:SetSize(size, size)
        overlay.haloFrame:SetAlpha(1)
        overlay.haloFrame:Show()
    end

    if overlay.damagedFrame then
        BattleMender.PositionElement(overlay.damagedFrame, parent)
        overlay.damagedFrame:SetSize(size, size)
        overlay.damagedFrame:SetAlpha(1)
        overlay.damagedFrame:Show()
    end

    if overlay.specFrame then
        BattleMender.PositionElement(overlay.specFrame, parent)
        overlay.specFrame:SetSize(size, size)
        overlay.specFrame:SetAlpha(1)
    end
end

local function GetLOSState(frame, overlay, plate)
    local state = BattleMender.GetState(frame)
    local unit = state.unit or BattleMender.ResolvePlateUnit(plate, frame)
    if not BattleMender.IsFriendlyPlayer(unit) then return false end

    local alpha = plate and plate:GetAlpha() or 1
    local current = overlay.BMLastLOS == true

    local raw
    if current then
        raw = alpha < 0.985
    else
        raw = alpha < 0.97
    end

    -- Prevent one-frame target/hover/selection alpha spikes from flipping LoS state.
    if raw ~= current then
        overlay.BMLOSChangeCount = (overlay.BMLOSChangeCount or 0) + 1

        if overlay.BMLOSChangeCount < 2 then
            return current
        end
    else
        overlay.BMLOSChangeCount = 0
    end

    overlay.BMLastLOS = raw
    return raw
end

-------------------------------------------------
-- Damaged layer / pulse
-------------------------------------------------
local function ConfigureDamagedSpecIcon(overlay, unit, specID, faded)
    if not overlay or not overlay.damagedSpecIcon then
        return nil, nil
    end

    local tex, coords, isAtlas = GetPrimaryUnitArt(unit, specID)

    local alpha = faded
        and (CFG.losDamageIconAlpha or CFG.damageIconAlpha or 1)
        or  (CFG.damageIconAlpha or 1)

    local blend = faded
        and (CFG.losDamageIconBlendMode or CFG.damageIconBlendMode or "BLEND")
        or  (CFG.damageIconBlendMode or "BLEND")


    overlay.damagedFrame:Show()
    overlay.damagedSpecIcon:Show()

    if tex and ApplyPrimaryArt(overlay.damagedSpecIcon, tex, coords, isAtlas, true) then
        -- Objective atlases keep Blizzard's atlas coordinates; normal spec art
        -- retains BattleMender's usual circular crop.
    else
        overlay.damagedSpecIcon:SetTexture(WHITE)
        overlay.damagedSpecIcon:SetTexCoord(0, 1, 0, 1)
    end

    overlay.damagedSpecIcon:SetDesaturated(false)
    overlay.damagedSpecIcon:SetBlendMode(blend)
    overlay.damagedSpecIcon:SetVertexColor(
        tex and (CFG.damageIconR or 1) or (CFG.damageIconFallbackR or CFG.damageIconR or 1),
        tex and (CFG.damageIconG or 0.02) or (CFG.damageIconFallbackG or CFG.damageIconG or 0.02),
        tex and (CFG.damageIconB or 0.02) or (CFG.damageIconFallbackB or CFG.damageIconB or 0.02),
        1
    )
    overlay.damagedSpecIcon:SetAlpha(alpha)

    if overlay.healerActive and CFG.specIconEnabled ~= false then
        local cross = overlay.healerDamagedCross
        local crossSize = (CFG.iconSize or 45) * (CFG.healerCrossScale or 0.9)
        if cross then
            cross:ClearAllPoints()
            cross:SetPoint("CENTER", overlay.damagedFrame, "CENTER")
            cross:SetSize(crossSize, crossSize)
            BattleMender.SetHealerCrossArt(cross, CFG.healthEnable ~= false)
            local crossAlpha = faded and (CFG.losSpecIconAlpha or 1) or (CFG.specIconAlpha or 1)
            cross:SetAlpha(crossAlpha)
            cross:Show()
        end

        if CFG.healthEnable == false then
            -- With the health system disabled, present the normal healthy
            -- black/green role art rather than the red/yellow damaged state.
            overlay.damagedSpecIcon:SetVertexColor(BattleMender.GetHealerBackgroundColor(unit))
            overlay.damagedSpecIcon:SetBlendMode("BLEND")
            overlay.damagedSpecIcon:SetAlpha(faded and (CFG.losSpecIconAlpha or 1) or (CFG.specIconAlpha or 1))
        end
    elseif overlay.healerDamagedCross then
        overlay.healerDamagedCross:Hide()
    end

    return tex, coords, isAtlas
end


local function UpdatePulseOverlay(overlay, faded)
	
    if not overlay or not overlay.damagedFrame then return end

    if not overlay.damagedFrame.pulseAnim then
        local ag = overlay.damagedFrame:CreateAnimationGroup()
        ag:SetLooping("REPEAT")

        local a1 = ag:CreateAnimation("Alpha")
        a1:SetDuration(0.2)
        a1:SetSmoothing("IN_OUT")
        a1:SetOrder(1)

        local a2 = ag:CreateAnimation("Alpha")
        a2:SetDuration(0.2)
        a2:SetSmoothing("IN_OUT")
        a2:SetOrder(2)

        overlay.damagedFrame.pulseAnim = ag
        overlay.damagedFrame.pulseAnim.a1 = a1
        overlay.damagedFrame.pulseAnim.a2 = a2
    end

    local pulseAnim = overlay.damagedFrame.pulseAnim

    local speed = CFG.pulseSpeed or 0.8
    local intensity = CFG.pulseIntensity or 0.3
    local doPulse = (not faded) and CFG.pulseEnable ~= false

    pulseAnim.a1:SetDuration(speed)
    pulseAnim.a2:SetDuration(speed)

    if doPulse then
        pulseAnim.a1:SetFromAlpha(1)
        pulseAnim.a1:SetToAlpha(intensity)
        pulseAnim.a2:SetFromAlpha(intensity)
        pulseAnim.a2:SetToAlpha(1)

        if not pulseAnim:IsPlaying() then
            pulseAnim:Play()
        end
    else
        if pulseAnim:IsPlaying() then
            pulseAnim:Stop()
        end

        overlay.damagedFrame:SetAlpha(1)
    end

    local enabled = (not faded) and CFG.pulseOverlayEnable == true
    if not enabled then
        overlay.pulseOverlay:Hide()
        return
    end

    local r, g, b = GetDamageColor()
    local file = CFG.pulseOverlayTexture or "Circle_AlphaGradient_In"
    local blend = CFG.pulseOverlayBlend or "ADD"
    local alpha = CFG.pulseOverlayAlpha or 0.5

    overlay.pulseOverlay:SetTexture("Interface\\AddOns\\BattleMender\\Textures\\" .. file .. ".tga")
    overlay.pulseOverlay:SetBlendMode(blend)
    overlay.pulseOverlay:SetVertexColor(r, g, b, alpha)
    --overlay.pulseOverlay:Show()
	overlay.pulseOverlay:Hide()
end

-------------------------------------------------
-- Health-clipped spec icon
-------------------------------------------------
local function UpdateHealthClippedSpecIcon(overlay, unit, tex, coords, isAtlas)
    if not overlay then return end
    if not overlay.healthOverlayTexture then return end
    if not overlay.healthClipFrame then return end
    if not overlay.healthSpecFrame then return end
    if not overlay.healthSpecIcon then return end
    if not tex then return end

    local clip = overlay.healthClipFrame
    local frame = overlay.healthSpecFrame
    local icon = overlay.healthSpecIcon
    local healthTex = overlay.healthOverlayTexture
    local size = CFG.iconSize or 45

    -------------------------------------------------
    -- Clip frame follows the visible health fill.
    -------------------------------------------------

    clip:ClearAllPoints()
    clip:SetPoint("BOTTOMLEFT", healthTex, "BOTTOMLEFT")
    clip:SetPoint("TOPRIGHT", healthTex, "TOPRIGHT")
    clip:Show()
	

    -------------------------------------------------
    -- Child frame is full icon-sized.
    -- It is clipped by healthClipFrame.
    -------------------------------------------------

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", overlay.damagedFrame, "CENTER", 0, 0)
    frame:SetSize(size, size)
    frame:Show()

    -------------------------------------------------
    -- Icon is circular-masked inside the child frame.
    -------------------------------------------------
	if not ApplyPrimaryArt(icon, tex, coords, isAtlas, true) then
		icon:Hide()
		return
	end

	local faded = overlay.BMLastLOS == true
	local desaturate = faded and (CFG.losSpecIconDesaturate == true) or (CFG.specIconDesaturate == true)

	icon:SetDesaturated(desaturate)
	if CFG.specIconUseClassColor == true then
		local classColor = BattleMender.ClassColor(unit)
		icon:SetVertexColor(classColor.r or 1, classColor.g or 1, classColor.b or 1, 1)
	else
		icon:SetVertexColor(1, 1, 1, 1)
	end
	local blend = faded
		and (CFG.losSpecIconBlendMode or CFG.specIconBlendMode or "BLEND")
		or  (CFG.specIconBlendMode or "BLEND")

	local alpha = faded
		and (CFG.losSpecIconAlpha or CFG.specIconAlpha or 1)
		or  (CFG.specIconAlpha or 1)

	icon:SetBlendMode(blend)
	icon:SetAlpha(alpha)
	if overlay.healerActive then
		icon:SetVertexColor(BattleMender.GetHealerBackgroundColor(unit))
		icon:SetBlendMode("BLEND")
	end
	icon:Show()

	if overlay.healthSpecMask then
		overlay.healthSpecMask:ClearAllPoints()
		overlay.healthSpecMask:SetAllPoints(frame)
		overlay.healthSpecMask:Show()
	end

    if overlay.healerHealthyCross then
        if overlay.healerActive then
            local crossSize = size * (CFG.healerCrossScale or 0.9)
            overlay.healerHealthyCross:ClearAllPoints()
            overlay.healerHealthyCross:SetPoint("CENTER", frame, "CENTER")
            overlay.healerHealthyCross:SetSize(crossSize, crossSize)
            BattleMender.SetHealerCrossArt(overlay.healerHealthyCross, false)
            overlay.healerHealthyCross:SetAlpha(alpha)
            overlay.healerHealthyCross:Show()
        else
            overlay.healerHealthyCross:Hide()
        end
    end
end

local function HideHealthOverlay(overlay)
    if not overlay then return end

    if overlay.healthOverlay then
        overlay.healthOverlay:Hide()
    end

    if overlay.healthClipFrame then
        overlay.healthClipFrame:Hide()
    end

    if overlay.healthSpecFrame then
        overlay.healthSpecFrame:Hide()
    end

    if overlay.healthSpecIcon then
        overlay.healthSpecIcon:Hide()
    end

    if overlay.healthSpecMask then
        overlay.healthSpecMask:Hide()
    end

    if overlay.healerHealthyCross then
        overlay.healerHealthyCross:Hide()
    end
end

local function UpdateSpecIcon(overlay, unit, specID, faded)
    -------------------------------------------------
    -- Always configure damaged/missing-health layer.
    -- This should NOT depend on specIconEnabled.
    -------------------------------------------------

    local tex, coords, isAtlas = ConfigureDamagedSpecIcon(overlay, unit, specID, faded)

    -------------------------------------------------
    -- Pulse overlay follows the damaged layer.
    -------------------------------------------------

    UpdatePulseOverlay(overlay, faded)

    -------------------------------------------------
    -- If no spec art exists, keep damaged fallback visible
    -- but hide the full-color health-clipped spec icon.
    -------------------------------------------------

    if not tex then
        HideHealthOverlay(overlay)

        if overlay.specFrame then overlay.specFrame:Hide() end
        if overlay.specGlow then overlay.specGlow:Hide() end
        if overlay.specIcon then overlay.specIcon:Hide() end

        return
    end

    -------------------------------------------------
    -- Full-color health-clipped spec icon.
    -- This is controlled by specIconEnabled AND healthEnable.
    -------------------------------------------------

    local alpha = faded
        and (CFG.losSpecIconAlpha or CFG.specIconAlpha or 1)
        or  (CFG.specIconAlpha or 1)

    if alpha <= 0 or CFG.specIconEnabled == false then
        HideHealthOverlay(overlay)

        if overlay.specFrame then overlay.specFrame:Hide() end
        if overlay.specGlow then overlay.specGlow:Hide() end
        if overlay.specIcon then overlay.specIcon:Hide() end

        return
    end

    -------------------------------------------------
    -- Spec frame / glow owner.
    -- This is independent of the health overlay.
    -------------------------------------------------

    if overlay.specFrame then
        overlay.specFrame:Show()
        overlay.specFrame:SetAlpha(alpha)
    end

    if overlay.specIcon then
        ApplyPrimaryArt(overlay.specIcon, tex, coords, isAtlas, true)
        overlay.specIcon:SetAlpha(0)
        overlay.specIcon:Hide()
    end

    -------------------------------------------------
    -- Full-color spec icon clipped to current health.
    -- Do not call this when health overlay is disabled,
    -- because the health overlay frames may not exist.
    -------------------------------------------------

    if CFG.healthEnable ~= false then
        UpdateHealthClippedSpecIcon(overlay, unit, tex, coords, isAtlas)
    else
        HideHealthOverlay(overlay)
    end

    -------------------------------------------------
    -- Hover glow texture.
    -------------------------------------------------

    if overlay.specGlow then
        ApplyPrimaryArt(overlay.specGlow, tex, coords, isAtlas, true)
        overlay.specGlow:SetVertexColor(1, 1, 1, 1)
        overlay.specGlow:ClearAllPoints()
        if overlay.healerActive then
            overlay.specGlow:SetTexture(BattleMender.HealerCrossTexture)
            overlay.specGlow:SetTexCoord(0, 1, 0, 1)
            overlay.specGlow:SetPoint("CENTER", overlay.specFrame, "CENTER")
            local crossSize = (CFG.iconSize or 45) * (CFG.healerCrossScale or 0.9)
            overlay.specGlow:SetSize(crossSize, crossSize)
        else
            overlay.specGlow:SetAllPoints(overlay.specFrame)
        end
    end
end

-------------------------------------------------
-- Ring
-------------------------------------------------

local function GetFriendlyBorderFit(file)
    if BattleMender.GetFriendlyBorderEffectiveFit then
        return BattleMender.GetFriendlyBorderEffectiveFit(file)
    elseif BattleMender.GetFriendlyBorderFit then
        return BattleMender.GetFriendlyBorderFit(file)
    end
    return 1.10
end

local function GetFriendlyBorderTextureName(file)
    if BattleMender.GetFriendlyBorderTextureName then
        return BattleMender.GetFriendlyBorderTextureName(file)
    end
    return file or "Ring_20px"
end

local function UpdateRing(overlay, unit, parent, faded)
    if not overlay or not overlay.ringFrame or not overlay.classRing then
        return
    end

    if CFG.ringEnabled == false then
        overlay.ringFrame:Hide()
        overlay.classRing:Hide()

        if overlay.ringGlow then
            overlay.ringGlow:Hide()
        end

        return
    end

    local normalFile = CFG.ringTexture or "Ring_20px"
    local losFile = CFG.losRingTexture or "SAME"
    local file = (faded and losFile ~= "SAME") and losFile or normalFile
    local textureFile = GetFriendlyBorderTextureName(file)
    local texPath = "Interface\\AddOns\\BattleMender\\Textures\\" .. textureFile .. ".tga"

    -------------------------------------------------
    -- Re-show both parent and child texture.
    -- This is necessary after ClearFriendlyPlate hides classRing.
    -------------------------------------------------

    overlay.ringFrame:Show()
    overlay.classRing:Show()


    overlay.classRing:SetTexture(texPath)
    overlay.classRing:SetTexCoord(0, 1, 0, 1)
    overlay.classRing:SetBlendMode("BLEND")

    local c = BattleMender.ClassColor(unit)
	local alpha = faded and (CFG.losRingAlpha or CFG.ringAlpha or 1) or (CFG.ringAlpha or 1)

	overlay.classRing:SetVertexColor(c.r, c.g, c.b, 1)
	overlay.classRing:SetAlpha(alpha)

    -------------------------------------------------
    -- Anchor ring to damagedFrame
    -------------------------------------------------

    local iconSize = CFG.iconSize or 45
    local fineTune = CFG.ringFineTune or 1
    local fit = GetFriendlyBorderFit(file)
    local ringSize = math.floor((iconSize * fit * fineTune) + 0.5)

    if overlay.ringFrame.BMLastSize ~= ringSize
        or overlay.ringFrame.BMLastParent ~= overlay.damagedFrame
        or overlay.ringFrame.BMLastRingFile ~= file
    then
        overlay.ringFrame:ClearAllPoints()
        overlay.ringFrame:SetPoint("CENTER", overlay.damagedFrame, "CENTER", 0, 0)
        overlay.ringFrame:SetSize(ringSize, ringSize)

        overlay.ringFrame.BMLastSize = ringSize
        overlay.ringFrame.BMLastParent = overlay.damagedFrame
        overlay.ringFrame.BMLastRingFile = file
    end

    overlay.classRing:SetScale(1)

    -------------------------------------------------
    -- Hover ring glow texture sync
    -------------------------------------------------

    if overlay.ringGlow then
        overlay.ringGlow:SetTexture(texPath)
        overlay.ringGlow:SetTexCoord(0, 1, 0, 1)
        overlay.ringGlow:SetVertexColor(c.r, c.g, c.b, alpha)
    end
end

-------------------------------------------------
-- Accent Overlay
-------------------------------------------------

local function GetAccentOverlayFile(faded)
    local normalFile = CFG.accentOverlayTexture or "Metal_Ring"
    local losFile = CFG.losAccentOverlayTexture or "SAME"

    if faded and losFile and losFile ~= "SAME" then
        return losFile
    end

    return normalFile
end

local function HideAccentOverlay(overlay)
    if not overlay then return end

    if overlay.accentFrame then
        overlay.accentFrame:Hide()
        overlay.accentFrame.BMLastSize = nil
        overlay.accentFrame.BMLastParent = nil
        overlay.accentFrame.BMLastFile = nil
    end

	if overlay.accentOverlay then
		overlay.accentOverlay:Hide()
		overlay.accentOverlay:SetAlpha(0)
		overlay.accentOverlay.BMLastTexturePath = nil
	end

	if overlay.accentGlow then
		if overlay.accentGlow.anim then
			overlay.accentGlow.anim:Stop()
		end

		overlay.accentGlow:Hide()
		overlay.accentGlow:SetAlpha(0)
	end
end

BattleMender.HideAccentOverlay = HideAccentOverlay

local function ApplyAccentTextureSampling(tex, file, texPath)
    if not tex or not file or not texPath then return end

    local inset = ACCENT_TEXCOORD_INSETS[file] or 0.005

    tex:SetTexture(
        texPath,
        "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE"
    )

    tex:SetTexCoord(
        inset,
        1 - inset,
        inset,
        1 - inset
    )

    if tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
    end

    if tex.SetTexelSnappingBias then
        tex:SetTexelSnappingBias(0)
    end
end

local function UpdateAccentOverlay(overlay, unit, faded)
    if not overlay or not overlay.accentFrame or not overlay.accentOverlay then
        return
    end

    if not unit
        or not UnitExists(unit)
        or not UnitIsPlayer(unit)
        or not UnitIsFriend("player", unit)
    then
        HideAccentOverlay(overlay)
        return
    end

    if CFG.accentOverlayEnabled ~= true then
        HideAccentOverlay(overlay)
        return
    end

    local file = GetAccentOverlayFile(faded)
	
	if file ~= "NONE" and not ACCENT_OVERLAY_TEXTURES[file] then
		file = "Metal_Ring"
	end

    if not file or file == "NONE" then
        HideAccentOverlay(overlay)
        return
    end

    local texPath = "Interface\\AddOns\\BattleMender\\Textures\\" .. file .. ".tga"

    local alpha = faded
        and (CFG.losAccentOverlayAlpha or CFG.accentOverlayAlpha or 1)
        or (CFG.accentOverlayAlpha or 1)

    local scale = faded
        and (CFG.losAccentOverlayScale or CFG.accentOverlayScale or 1)
        or (CFG.accentOverlayScale or 1)

    local blend = faded
        and (CFG.losAccentOverlayBlendMode or CFG.accentOverlayBlendMode or "BLEND")
        or (CFG.accentOverlayBlendMode or "BLEND")

    local useClass = faded
        and CFG.losAccentOverlayUseClassColor
        or CFG.accentOverlayUseClassColor

    local cr = faded
        and (CFG.losAccentOverlayColorR or CFG.accentOverlayColorR or 1)
        or (CFG.accentOverlayColorR or 1)

    local cg = faded
        and (CFG.losAccentOverlayColorG or CFG.accentOverlayColorG or 1)
        or (CFG.accentOverlayColorG or 1)

    local cb = faded
        and (CFG.losAccentOverlayColorB or CFG.accentOverlayColorB or 1)
        or (CFG.accentOverlayColorB or 1)

    local r, g, b = BattleMender.GetOverlayColor(useClass, unit, cr, cg, cb)

    local iconSize = CFG.iconSize or 45
    local accentSize = math.floor((iconSize * scale) + 0.5)

    local anchorFrame = overlay.ringFrame or overlay.specFrame or overlay.damagedFrame

    if not anchorFrame then
        HideAccentOverlay(overlay)
        return
    end

    if overlay.accentFrame.BMLastSize ~= accentSize
        or overlay.accentFrame.BMLastParent ~= anchorFrame
        or overlay.accentFrame.BMLastFile ~= file
    then
        overlay.accentFrame:ClearAllPoints()
        overlay.accentFrame:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
        overlay.accentFrame:SetSize(accentSize, accentSize)

        overlay.accentFrame.BMLastSize = accentSize
        overlay.accentFrame.BMLastParent = anchorFrame
        overlay.accentFrame.BMLastFile = file
    end

    overlay.accentFrame:Show()
    overlay.accentOverlay:Show()

	overlay.accentFrame:Show()
	overlay.accentOverlay:Show()

	if overlay.accentOverlay.BMLastTexturePath ~= texPath then
		ApplyAccentTextureSampling(overlay.accentOverlay, file, texPath)

		if overlay.accentGlow then
			ApplyAccentTextureSampling(overlay.accentGlow, file, texPath)
		end

		overlay.accentOverlay.BMLastTexturePath = texPath
	end

	overlay.accentOverlay:SetBlendMode(blend)
	overlay.accentOverlay:SetVertexColor(r, g, b, 1)
	overlay.accentOverlay:SetAlpha(alpha)

	if overlay.accentGlow then
		overlay.accentGlow:SetBlendMode("ADD")
		overlay.accentGlow:SetVertexColor(r, g, b, 1)
	end
end

local function HideHealthOverlay(overlay)
    if not overlay then return end

    if overlay.healthOverlay then overlay.healthOverlay:Hide() end
    if overlay.healthClipFrame then overlay.healthClipFrame:Hide() end
    if overlay.healthSpecFrame then overlay.healthSpecFrame:Hide() end
    if overlay.healthSpecIcon then overlay.healthSpecIcon:Hide() end
    if overlay.healthSpecMask then overlay.healthSpecMask:Hide() end
end

-------------------------------------------------
-- Health visuals
-------------------------------------------------
local function UpdateHealthVisuals(frame, faded)
    local overlay = frame and BM_OVERLAYS[frame]

	if CFG.healthEnable == false then
		HideHealthOverlay(BM_OVERLAYS[frame])
		return
	end

    local bar = overlay and overlay.healthOverlay
    if not bar then return end

    local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not tex then return end

    local alpha = faded and (CFG.losHealthOverlayAlpha or 0.35) or (CFG.healthOverlayAlpha or 1)
    local blend = faded and (CFG.losHealthOverlayBlendMode or "BLEND") or (CFG.healthOverlayBlendMode or "BLEND")

    local useClass, cr, cg, cb

    if faded then
        useClass = CFG.losHealthOverlayUseClassColor == true
        cr = CFG.losHealthOverlayColorR or 1
        cg = CFG.losHealthOverlayColorG or 0
        cb = CFG.losHealthOverlayColorB or 0
    else
        useClass = CFG.healthOverlayUseClassColor == true
        cr = CFG.healthOverlayColorR or 1
        cg = CFG.healthOverlayColorG or 1
        cb = CFG.healthOverlayColorB or 1
    end

    local state = BattleMender.GetState(frame)
    local unit = state.unit or BattleMender.ResolvePlateUnit(nil, frame)
	local r, g, b = BattleMender.GetOverlayColor(useClass, unit, cr, cg, cb)

	r, g, b = AutoCompensateHealthOverlayColor(r, g, b, alpha, blend, faded)

	tex:SetBlendMode(blend)

	-- Important: alpha goes in one place only.
	tex:SetVertexColor(r, g, b, 1)
	tex:SetAlpha(alpha)

    if unit then
        local maxHealth = UnitHealthMax(unit)
        local health = UnitHealth(unit)
        pcall(bar.SetMinMaxValues, bar, 0, maxHealth)
        pcall(bar.SetValue, bar, health)
    end

    -- Show only after the overlay is fully configured.
    if not bar:IsShown() then
        bar:Show()
    end
end

-------------------------------------------------
-- Hover visuals
-------------------------------------------------

local function UpdateHoverVisuals(frame, overlay)
    if not overlay then return end

    local state = BattleMender.GetState(frame)
    local unit = state.unit or BattleMender.ResolvePlateUnit(nil, frame)
    local isHover = unit and UnitIsUnit(unit, "mouseover")

    if isHover then
        local faded = overlay.BMLastLOS == true

        local specPeak = CFG.specGlowBrightness or 0.50
        local ringPeak = CFG.ringGlowBrightness or 0.50
        local haloPeak = CFG.haloGlowAlpha or 0.80

		local accentPeak = faded
			and (CFG.losAccentOverlayGlowBrightness or CFG.accentOverlayGlowBrightness or 0.45)
			or (CFG.accentOverlayGlowBrightness or 0.45)

		local accentFadeIn = faded
			and (CFG.losAccentOverlayGlowFadeIn or CFG.accentOverlayGlowFadeIn or 0.05)
			or (CFG.accentOverlayGlowFadeIn or 0.05)

		local accentGlowEnabled

		if faded and CFG.losAccentOverlayGlowEnabled ~= nil then
			accentGlowEnabled = CFG.losAccentOverlayGlowEnabled == true
		else
			accentGlowEnabled = CFG.accentOverlayGlowEnabled == true
		end	

        if not overlay.BMIsHovering then
            overlay.BMIsHovering = true

            if CFG.specGlowEnabled then
                FadeInGlow(overlay.specGlow, specPeak, CFG.specGlowFadeIn or 0.05)
            end
			
			if accentGlowEnabled and overlay.accentGlow and overlay.accentFrame and overlay.accentFrame:IsShown() then
				FadeInGlow(overlay.accentGlow, accentPeak, accentFadeIn)
			end

            if CFG.ringGlowEnabled then
                FadeInGlow(overlay.ringGlow, ringPeak, CFG.ringGlowFadeIn or 0.05)
            end
			
            if CFG.haloEnabled and overlay.haloGlow then
                overlay.haloGlow:SetTexture(HALO_TEXTURES["Circle_Halo_1"])
                overlay.haloGlow:SetSize(
                    (CFG.iconSize or 45) * (CFG.haloGlowSizeScale or 2.9),
                    (CFG.iconSize or 45) * (CFG.haloGlowSizeScale or 2.9)
                )
                overlay.haloGlow:SetBlendMode("ADD")
                overlay.haloGlow:SetAlpha(haloPeak)
                overlay.haloGlow:Show()
            end
        else
            if CFG.specGlowEnabled and not overlay.specGlow.anim:IsPlaying() then
                overlay.specGlow.anim.targetAlpha = specPeak
                overlay.specGlow:SetAlpha(specPeak)
            end

            if CFG.ringGlowEnabled and not overlay.ringGlow.anim:IsPlaying() then
                overlay.ringGlow.anim.targetAlpha = ringPeak
                overlay.ringGlow:SetAlpha(ringPeak)
            end
        end

    elseif not isHover and overlay.BMIsHovering then
        overlay.BMIsHovering = false

        FadeOutGlow(overlay.specGlow, CFG.specGlowBrightness or 0.50, CFG.specGlowFadeOut or 0.35)
        FadeOutGlow(overlay.ringGlow, CFG.ringGlowBrightness or 0.50, CFG.ringGlowFadeOut or 0.35)
		
        local faded = overlay.BMLastLOS == true

        local accentPeak = faded
            and (CFG.losAccentOverlayGlowBrightness or CFG.accentOverlayGlowBrightness or 0.45)
            or (CFG.accentOverlayGlowBrightness or 0.45)

        local accentFadeOut = faded
            and (CFG.losAccentOverlayGlowFadeOut or CFG.accentOverlayGlowFadeOut or 0.15)
            or (CFG.accentOverlayGlowFadeOut or 0.15)

        if overlay.accentGlow then
            FadeOutGlow(overlay.accentGlow, accentPeak, accentFadeOut)
        end

        if overlay.haloGlow then
            overlay.haloGlow:Hide()
        end
    end
end

-- UPDATE_MOUSEOVER_UNIT can fire rapidly while the cursor crosses nameplates.
-- Refresh only the friendly plate that lost hover and the one that gained it;
-- the normal LoS poll continues to refresh all other friendly visuals.
local LAST_FRIENDLY_HOVER_FRAME = nil

function BattleMender.RefreshFriendlyHoverState()
    local previous = LAST_FRIENDLY_HOVER_FRAME
    local currentFrame = nil

    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "mouseover")
        if ok and plate then
            local frame = BattleMender.GetVisualFrame and BattleMender.GetVisualFrame(plate)
            local state = frame and BattleMender._State and BattleMender._State[frame]
            if state and state.active then
                currentFrame = frame
            end
        end
    end

    if previous and previous ~= currentFrame then
        local overlay = BM_OVERLAYS and BM_OVERLAYS[previous]
        if overlay then
            UpdateHoverVisuals(previous, overlay)
        end
    end

    if currentFrame then
        local overlay = BM_OVERLAYS and BM_OVERLAYS[currentFrame]
        if overlay then
            UpdateHoverVisuals(currentFrame, overlay)
        end
    end

    LAST_FRIENDLY_HOVER_FRAME = currentFrame
end

local function GetObjectiveBorderColor(unit)
    local mode = tostring(CFG.objectivesBorderColorMode or "AUTO"):upper()
    if mode == "WHITE" then
        return 1, 1, 1
    elseif mode == "CUSTOM" then
        return Clamp01(CFG.objectivesCustomR or 1), Clamp01(CFG.objectivesCustomG or 1), Clamp01(CFG.objectivesCustomB or 1)
    end

    local c = BattleMender.ClassColor(unit)
    return c.r or 1, c.g or 1, c.b or 1
end

local function HideObjectiveBadge(overlay)
    if not overlay then return end
    if overlay.objectiveIcon then
        if overlay.objectiveIcon.pulseAnim then overlay.objectiveIcon.pulseAnim:Stop() end
        overlay.objectiveIcon:Hide()
        overlay.objectiveIcon:SetAlpha(1)
    end
    if overlay.objectiveBorder then overlay.objectiveBorder:Hide() end
    if overlay.objectiveGlow then
        if overlay.objectiveGlow.pulseAnim then overlay.objectiveGlow.pulseAnim:Stop() end
        overlay.objectiveGlow:Hide()
        overlay.objectiveGlow:SetAlpha(0)
    end
    if overlay.objectiveFrame then overlay.objectiveFrame:Hide() end
end

-- Plate recycling must be able to clear objective art before the recycled
-- Blizzard UnitFrame is assigned to another player. Keep the implementation here
-- so every cleanup path also stops the badge/glow pulse animations.
BattleMender.HideObjectiveBadge = HideObjectiveBadge

local function UpdateObjectiveBadge(overlay, unit, parent)
    if not overlay or not overlay.objectiveFrame or not parent then return end

    if CFG.objectivesEnabled == false then
        HideObjectiveBadge(overlay)
        return
    end

    local atlas, glowR, glowG, glowB = GetPvPObjectiveInfo(unit)
    if not atlas then
        HideObjectiveBadge(overlay)
        return
    end

    local iconSize = tonumber(CFG.iconSize) or 45
    local size = math.max(12, math.floor(iconSize * ClampNumber(CFG.objectivesBadgeScale, 0.35, 1.6, 0.72) + 0.5))
    local distance = iconSize * ClampNumber(CFG.objectivesDistanceScale, 0, 1.5, 0.53)
    local radians = math.rad((tonumber(CFG.objectivesAngle) or 42) % 360)
    local inFront = tostring(CFG.objectivesLayer or "BEHIND"):upper() == "FRONT"
    local borderKey = tostring(CFG.objectivesBorderTexture or "COGWHEEL"):upper()
    local borderTexture = OBJECTIVE_BORDER_TEXTURES[borderKey]
    local borderScale = ClampNumber(CFG.objectivesBorderScale, 0.9, 1.8, 1.18)
    local borderAlpha = Clamp01(CFG.objectivesBorderAlpha or 1)
    local borderSize = math.max(size, math.floor(size * borderScale * (OBJECTIVE_BORDER_FIT[borderKey] or 1) + 0.5))
    local borderR, borderG, borderB = GetObjectiveBorderColor(unit)

    overlay.objectiveFrame:ClearAllPoints()
    overlay.objectiveFrame:SetPoint("CENTER", parent, "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
    overlay.objectiveFrame:SetSize(size, size)
    overlay.objectiveFrame:SetFrameLevel(inFront and 340 or 319)
    overlay.objectiveFrame:Show()

    overlay.objectiveBackplate:ClearAllPoints()
    overlay.objectiveBackplate:SetPoint("CENTER", overlay.objectiveFrame, "CENTER")
    overlay.objectiveBackplate:SetSize(size * 1.08, size * 1.08)
    overlay.objectiveBackplate:SetAlpha(0.82)

    overlay.objectiveIcon:ClearAllPoints()
    overlay.objectiveIcon:SetPoint("TOPLEFT", overlay.objectiveFrame, "TOPLEFT", 0, 0)
    overlay.objectiveIcon:SetPoint("BOTTOMRIGHT", overlay.objectiveFrame, "BOTTOMRIGHT", 0, 0)
    pcall(overlay.objectiveIcon.SetAtlas, overlay.objectiveIcon, atlas, false)
    overlay.objectiveIcon:Show()

    if borderTexture and borderKey ~= "NONE" then
        overlay.objectiveBorder:ClearAllPoints()
        overlay.objectiveBorder:SetPoint("CENTER", overlay.objectiveFrame, "CENTER")
        overlay.objectiveBorder:SetSize(borderSize, borderSize)
        overlay.objectiveBorder:SetTexture(borderTexture)
        overlay.objectiveBorder:SetVertexColor(borderR, borderG, borderB, 1)
        overlay.objectiveBorder:SetAlpha(borderAlpha)
        overlay.objectiveBorder:Show()
    else
        overlay.objectiveBorder:Hide()
    end

    local pulseEnabled = CFG.objectivesPulse ~= false
    ConfigurePulseAnimation(overlay.objectiveIcon, pulseEnabled, 0.82, 1, ClampNumber(CFG.objectivesPulseSpeed, 0.15, 2.5, 0.9))

    if CFG.objectivesGlowEnabled ~= false then
        local glowScale = ClampNumber(CFG.objectivesGlowScale, 1.0, 3.0, 2.25)
        local glowAlpha = Clamp01(CFG.objectivesGlowAlpha or 0.46)
        overlay.objectiveGlow:ClearAllPoints()
        overlay.objectiveGlow:SetPoint("CENTER", overlay.objectiveFrame, "CENTER")
        overlay.objectiveGlow:SetSize(size * glowScale, size * glowScale)
        overlay.objectiveGlow:SetTexture(HALO_TEXTURES["Circle_Halo_1"])
        overlay.objectiveGlow:SetVertexColor(glowR or 1, glowG or 1, glowB or 1, 1)
        overlay.objectiveGlow:Show()
        ConfigurePulseAnimation(overlay.objectiveGlow, pulseEnabled, glowAlpha * 0.28, glowAlpha, ClampNumber(CFG.objectivesGlowSpeed, 0.15, 2.5, 0.9))
    else
        if overlay.objectiveGlow.pulseAnim then overlay.objectiveGlow.pulseAnim:Stop() end
        overlay.objectiveGlow:Hide()
        overlay.objectiveGlow:SetAlpha(0)
    end
end

local function UpdateAffiliation(overlay, unit, parent)
    local badge = overlay and overlay.affiliateFrame
    if not badge then return end

    if CFG.affiliateBadgeEnabled == false or not BattleMender.GetFriendlyAffiliation then
        badge:Hide()
        return
    end

    local inParty, inGuild, inFriends = BattleMender.GetFriendlyAffiliation(unit)
    inParty = CFG.affiliateParty ~= false and inParty
    inGuild = CFG.affiliateGuild ~= false and inGuild
    inFriends = CFG.affiliateFriend ~= false and inFriends
    if not inParty and not inGuild and not inFriends then
        badge:Hide()
        return
    end

    local iconSize = tonumber(CFG.iconSize) or 45
    local badgeSize = math.max(14, math.floor(iconSize * ClampNumber(CFG.affiliateBadgeScale, 0.30, 1.0, 0.56) + 0.5))
    local distance = iconSize * ClampNumber(CFG.affiliateBadgeDistanceScale, 0, 1.5, 0.64)
    local radians = math.rad((tonumber(CFG.affiliateBadgeAngle) or 42) % 360)
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", parent, "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
    badge:SetSize(badgeSize, badgeSize)

    overlay.affiliateStarOuter:SetSize(badgeSize, badgeSize)
    local texturePath = BattleMender.GetAffiliateBadgeTexture(CFG.affiliateBadgeTexture)
    if overlay.affiliateStarOuter.BMLastTexturePath ~= texturePath then
        overlay.affiliateStarOuter:SetTexture(texturePath)
        overlay.affiliateStarOuter:SetTexCoord(0, 1, 0, 1)
        overlay.affiliateStarOuter:SetVertexColor(1, 1, 1, 1)
        overlay.affiliateStarOuter.BMLastTexturePath = texturePath
    end
    overlay.affiliateStarInner:Hide()

    -- Presentation priority only: Party > Guild > Friends. Raw relationship
    -- flags remain independent for visibility exceptions and plate scaling.
    local glyph = inParty and "P" or (inGuild and "G" or "F")
    overlay.affiliateText:SetText(glyph)
    local fontSize = math.max(7, math.floor(badgeSize * 0.42 + 0.5))
    local font = select(1, overlay.affiliateText:GetFont())
    if font then overlay.affiliateText:SetFont(font, fontSize, "OUTLINE") end

    badge:Show()
end

-------------------------------------------------
-- Public update
-------------------------------------------------

function BattleMender.UpdateOverlay(frame, plate)
    if not frame then return end

    local state = BattleMender.GetState(frame)
    local unit = state.unit or BattleMender.ResolvePlateUnit(plate, frame)

    if not BattleMender.IsFriendlyPlayer(unit) then
        HideOverlayVisuals(BM_OVERLAYS[frame])
        return
    end

    local overlay = BattleMender.EnsureOverlay(frame)
    local parent = BattleMender.GetVisualFrame(plate) or frame
    local specID = state.specID

    if BattleMender.ApplyFriendlyVisualScale then
        BattleMender.ApplyFriendlyVisualScale(frame, overlay, plate, parent, unit)
    end

    PrepareOverlayHolders(overlay, parent)

    if BattleMender.BindFriendlyHitTest then
        BattleMender.BindFriendlyHitTest(frame, plate, overlay)
    end

    if CFG.debugClickbox or BattleMender.DebugClickboxVisible then
        overlay.debugBox:Show()
    else
        overlay.debugBox:Hide()
    end

    local isFaded = GetLOSState(frame, overlay, plate)

    overlay.healerActive = CFG.healerCrossEnabled == true and BattleMender.IsHealerUnit(unit, specID)
    if overlay.healerActive and CFG.specIconEnabled ~= false then
        local control = overlay.healerControl
        local host = overlay.healerControlHost
        if host then
            local iconSize = tonumber(CFG.iconSize) or 45
            local badgeSize = math.max(12, math.floor(iconSize * ClampNumber(CFG.healerControlBadgeScale, 0.35, 1.4, 0.64) + 0.5))
            local distance = iconSize * ClampNumber(CFG.healerControlDistanceScale, 0, 1.5, 0.58)
            local radians = math.rad((tonumber(CFG.healerControlAngle) or 138) % 360)
            host:ClearAllPoints()
            host:SetPoint("CENTER", parent, "CENTER", math.cos(radians) * distance, math.sin(radians) * distance)
            host:SetSize(badgeSize, badgeSize)
            -- These are addon-owned configuration values, never aura state.
            host:SetShown(CFG.healerControlEnabled == true and control ~= nil and control.unit == unit)
        end
    else
        if overlay.healerDamagedCross then overlay.healerDamagedCross:Hide() end
        if overlay.healerHealthyCross then overlay.healerHealthyCross:Hide() end
        overlay.healerControlHost:Hide()
    end

    UpdateAffiliation(overlay, unit, parent)
    UpdateSpecIcon(overlay, unit, specID, isFaded)
    UpdateRing(overlay, unit, parent, isFaded)
    UpdateObjectiveBadge(overlay, unit, parent)
    UpdateAccentOverlay(overlay, unit, isFaded)
    UpdateHealthVisuals(frame, isFaded)
    UpdateHoverVisuals(frame, overlay)
    ApplyNameplateFadeAlpha(plate, overlay)

    BattleMender.GetState(frame).modified = true
end

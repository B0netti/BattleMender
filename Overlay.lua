BattleMender = BattleMender or {}

local CFG = BattleMender.CFG
BattleMender._Overlays = BattleMender._Overlays or {}
local BM_OVERLAYS = BattleMender._Overlays

local HALO_TEXTURES = {
    ["Circle_Halo_1"] = "Interface\\AddOns\\BattleMender\\Textures\\Circle_Halo_2.tga",
}

local SPEC_PATH = "Interface\\AddOns\\BattleMender\\Textures\\Specs\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local ACCENT_OVERLAY_TEXTURES = {
    ["Metal_Ring"] = true,
    ["Glass_Ring"] = true,
}

local ACCENT_TEXTURE_PATH = "Interface\\AddOns\\BattleMender\\Textures\\"

local ACCENT_TEXCOORD_INSETS = {
    Metal_Ring = 0.005,
    Glass_Ring = 0.012,
}

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

local function ResolveFriendlyVisualScale(plate, parentFrame)
    if CFG.friendlyVisualScaleLock == false then
        return 1
    end

    local uiScale = GetFrameEffectiveScale(UIParent) or 1
    local parentScale = GetFrameEffectiveScale(parentFrame) or GetFrameEffectiveScale(plate)

    if not parentScale or parentScale <= 0 then
        return 1
    end

    -- Child visuals inherit the native nameplate scale. Invert that scale so
    -- BattleMender's configured Icon Size remains stable on screen. Clamp the
    -- compensation so broken/temporary scale reads cannot explode the overlay.
    return ClampNumber(uiScale / parentScale, 0.35, 3.0, 1)
end

function BattleMender.ApplyFriendlyVisualScale(frame, overlay, plate, parentFrame)
    if not overlay then return 1 end

    local scale = ResolveFriendlyVisualScale(plate, parentFrame or frame)

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
    setFrameScale(overlay.healthOverlay)
    setFrameScale(overlay.healthClipFrame)

    return scale
end

function BattleMender.GetFriendlyVisualScale(frame, plate)
    local parent = BattleMender.GetVisualFrame and BattleMender.GetVisualFrame(plate) or frame
    return ResolveFriendlyVisualScale(plate, parent)
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

    if overlay.specGlow and overlay.specGlow:IsShown() then
        local alpha = CFG.specGlowBrightness or 1
        overlay.specGlow:SetAlpha(alpha * fadeAlpha)
    end

    if overlay.ringGlow and overlay.ringGlow:IsShown() then
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

	local pulseOverlay = damagedFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	pulseOverlay:SetAllPoints()
	pulseOverlay:Hide()

	local mask1 = damagedFrame:CreateMaskTexture()
	mask1:SetTexture(
		"Interface\\CharacterFrame\\TempPortraitAlphaMask",
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
		ringFrame = ringFrame,
		accentFrame = accentFrame,

		haloGlow = haloGlow,
		damagedSpecIcon = damagedSpecIcon,
		pulseOverlay = pulseOverlay,
		specIcon = specIcon,
		specGlow = specGlow,
		classRing = classRing,
		ringGlow = ringGlow,
		accentOverlay = accentOverlay,
		accentGlow = accentGlow,
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

    hitTestFrame:Show()

    if type(plate.ClearAllHitTestPoints) ~= "function"
        or type(plate.SetAllHitTestPoints) ~= "function"
    then
        return false
    end

    if overlay.hitTestPlate ~= plate then
        local ok = pcall(function()
            plate:ClearAllHitTestPoints()
            plate:SetAllHitTestPoints(hitTestFrame)
        end)

        if not ok then
            return false
        end

        overlay.hitTestPlate = plate
    end

    BattleMender.FriendlyHitTestBindingApplied = true
    return true
end

function BattleMender.RestoreNativeHitTest(frame, overlay)
    overlay = overlay or (frame and BM_OVERLAYS[frame])
    if not overlay then return false end

    local plate = overlay.hitTestPlate
    overlay.hitTestPlate = nil

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

	overlay.healthOverlay = health
	overlay.healthOverlayTexture = tex
	overlay.healthClipFrame = healthClipFrame
	overlay.healthSpecFrame = healthSpecFrame
	overlay.healthSpecIcon = healthSpecIcon
	overlay.healthSpecMask = healthSpecMask

    return health, tex
end

local function HideOverlayVisuals(overlay)
    if not overlay then return end

    if overlay.haloFrame then overlay.haloFrame:Hide() end
    if overlay.damagedFrame then overlay.damagedFrame:Hide() end
    if overlay.specFrame then overlay.specFrame:Hide() end
    if overlay.ringFrame then overlay.ringFrame:Hide() end
    if overlay.accentFrame then overlay.accentFrame:Hide() end

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

    if BattleMender.ApplyFriendlyVisualScale then
        BattleMender.ApplyFriendlyVisualScale(frame, overlay, plate, parent)
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

    local tex, coords = BattleMender.GetOverlayTexture("SPEC", unit, specID)

    local alpha = faded
        and (CFG.losDamageIconAlpha or CFG.damageIconAlpha or 1)
        or  (CFG.damageIconAlpha or 1)

    local blend = faded
        and (CFG.losDamageIconBlendMode or CFG.damageIconBlendMode or "BLEND")
        or  (CFG.damageIconBlendMode or "BLEND")


    overlay.damagedFrame:Show()
    overlay.damagedSpecIcon:Show()

    if tex then
        overlay.damagedSpecIcon:SetTexture(tex)
        ApplyTexCoords(overlay.damagedSpecIcon, coords, true)
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

    return tex, coords
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

    local speed = faded and (CFG.losPulseSpeed or 0.8) or (CFG.pulseSpeed or 0.8)
    local intensity = faded and (CFG.losPulseIntensity or 0.3) or (CFG.pulseIntensity or 0.3)
    local doPulse = faded and (CFG.losPulseEnable == true) or (not faded and CFG.pulseEnable ~= false)

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

    local enabled = faded and (CFG.losPulseOverlayEnable == true) or (not faded and CFG.pulseOverlayEnable == true)
    if not enabled then
        overlay.pulseOverlay:Hide()
        return
    end

    local r, g, b = GetDamageColor()
    local file = CFG.pulseOverlayTexture or "Circle_AlphaGradient_In"
    local blend = faded and (CFG.losPulseOverlayBlend or "ADD") or (CFG.pulseOverlayBlend or "ADD")
    local alpha = faded and (CFG.losPulseOverlayAlpha or 0.5) or (CFG.pulseOverlayAlpha or 0.5)

    overlay.pulseOverlay:SetTexture("Interface\\AddOns\\BattleMender\\Textures\\" .. file .. ".tga")
    overlay.pulseOverlay:SetBlendMode(blend)
    overlay.pulseOverlay:SetVertexColor(r, g, b, alpha)
    --overlay.pulseOverlay:Show()
	overlay.pulseOverlay:Hide()
end

-------------------------------------------------
-- Health-clipped spec icon
-------------------------------------------------
local function UpdateHealthClippedSpecIcon(overlay, tex, coords)
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
	icon:SetTexture(tex)

	if coords then
		icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		icon:SetTexCoord(0.04, 0.96, 0.04, 0.96)
	end

	local faded = overlay.BMLastLOS == true
	local desaturate = faded and (CFG.losSpecIconDesaturate == true) or (CFG.specIconDesaturate == true)

	icon:SetDesaturated(desaturate)
	icon:SetVertexColor(1, 1, 1, 1)
	local blend = faded
		and (CFG.losSpecIconBlendMode or CFG.specIconBlendMode or "BLEND")
		or  (CFG.specIconBlendMode or "BLEND")

	local alpha = faded
		and (CFG.losSpecIconAlpha or CFG.specIconAlpha or 1)
		or  (CFG.specIconAlpha or 1)

	icon:SetBlendMode(blend)
	icon:SetAlpha(alpha)
	icon:Show()

	if overlay.healthSpecMask then
		overlay.healthSpecMask:ClearAllPoints()
		overlay.healthSpecMask:SetAllPoints(frame)
		overlay.healthSpecMask:Show()
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
end

local function UpdateSpecIcon(overlay, unit, specID, faded)
    -------------------------------------------------
    -- Always configure damaged/missing-health layer.
    -- This should NOT depend on specIconEnabled.
    -------------------------------------------------

    local tex, coords = ConfigureDamagedSpecIcon(overlay, unit, specID, faded)

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
        overlay.specIcon:SetTexture(tex)
        ApplyTexCoords(overlay.specIcon, coords, true)
        overlay.specIcon:SetAlpha(0)
        overlay.specIcon:Hide()
    end

    -------------------------------------------------
    -- Full-color spec icon clipped to current health.
    -- Do not call this when health overlay is disabled,
    -- because the health overlay frames may not exist.
    -------------------------------------------------

    if CFG.healthEnable ~= false then
        UpdateHealthClippedSpecIcon(overlay, tex, coords)
    else
        HideHealthOverlay(overlay)
    end

    -------------------------------------------------
    -- Hover glow texture.
    -------------------------------------------------

    if overlay.specGlow then
        overlay.specGlow:SetTexture(tex)
        ApplyTexCoords(overlay.specGlow, coords, true)
        overlay.specGlow:SetVertexColor(1, 1, 1, 1)
    end
end

-------------------------------------------------
-- Ring
-------------------------------------------------

local BORDER_TEXTURE_ALIASES = {
    sheild_tall = "shield_tall",
}

local BORDER_FIT_SCALES = {
    ["Ring_10px"] = 1.06,
    ["Ring_20px"] = 1.10,
    ["Ring_30px"] = 1.14,
    ["Ring_40px"] = 1.18,
    ["Metal_Ring"] = 1.10,
    ["plastic_ring"] = 1.10,
    ["defensive_cogwheel"] = 1.12,
    ["shield_easy"] = 1.16,
    ["shield_ring"] = 1.16,
    ["shield_tall"] = 1.18,
    ["sheild_tall"] = 1.18,
}

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
    local textureFile = BORDER_TEXTURE_ALIASES[file] or file
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
    local scale = CFG.ringScale or 1
    local fit = BORDER_FIT_SCALES[file] or 1.10
    local ringSize = math.floor((iconSize * fit * scale) + 0.5)

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

		local faded = overlay.BMLastLOS == true

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
			
            local accentGlowEnabled = faded
                and (CFG.losAccentOverlayGlowEnabled == true)
                or (CFG.accentOverlayGlowEnabled == true)

            local accentFadeIn = faded
                and (CFG.losAccentOverlayGlowFadeIn or CFG.accentOverlayGlowFadeIn or 0.05)
                or (CFG.accentOverlayGlowFadeIn or 0.05)

            if accentGlowEnabled and overlay.accentGlow then
                FadeInGlow(overlay.accentGlow, accentPeak, accentFadeIn)
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
        BattleMender.ApplyFriendlyVisualScale(frame, overlay, plate, parent)
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

    UpdateSpecIcon(overlay, unit, specID, isFaded)
    UpdateRing(overlay, unit, parent, isFaded)
    UpdateAccentOverlay(overlay, unit, isFaded)
    UpdateHealthVisuals(frame, isFaded)
    UpdateHoverVisuals(frame, overlay)
    ApplyNameplateFadeAlpha(plate, overlay)

    BattleMender.GetState(frame).modified = true
end

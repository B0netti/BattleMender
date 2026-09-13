BattleMender = BattleMender or {}

local BM = BattleMender
local EPI = BM.EnemyPlateInternal
local CFG = EPI.CFG
local NAMEPLATE_AGGRO_FLARE_ATLAS = EPI.NAMEPLATE_AGGRO_FLARE_ATLAS
local NAMEPLATE_AGGRO_MASK_ATLAS = EPI.NAMEPLATE_AGGRO_MASK_ATLAS
local AURA_FLARES = EPI.AURA_FLARES
local IsTestUnit = EPI.IsTestUnit
local UnitLooksLikePlayer = EPI.UnitLooksLikePlayer
local ConfigColor = EPI.ConfigColor
local UseStableHealthClip = EPI.UseStableHealthClip
local GetUnitColor = EPI.GetUnitColor
local GetNativeHealthStatusBarForPlate = EPI.GetNativeHealthStatusBarForPlate

local function ApplyRenderedHealthColor(region, plate, unit, alpha)
    if not region or not plate then return false end

    -- Prefer the color BattleMender is already rendering on this health bar.
    -- Keep any potentially restricted color components inside pcall and pass
    -- them directly to the texture without comparing them in Lua.
    local source
    local getter
    if UseStableHealthClip() and plate.healthFillTex and type(plate.healthFillTex.GetVertexColor) == "function" then
        source = plate.healthFillTex
        getter = "GetVertexColor"
    elseif plate.health and type(plate.health.GetStatusBarColor) == "function" then
        source = plate.health
        getter = "GetStatusBarColor"
    end

    if source and getter then
        local ok = pcall(function()
            local r, g, b = source[getter](source)
            region:SetVertexColor(r, g, b, alpha)
        end)
        if ok then return true end
    end

    local r, g, b = GetUnitColor(unit, true, plate.nativeFrame)
    region:SetVertexColor(r or 1, g or 1, b or 1, alpha)
    return true
end

local function ApplyThreatFlareCustomColor(region, alpha)
    local r, g, b = ConfigColor("enemyPlateAuraFlare", 1, 0.12, 0.04, 1)
    region:SetVertexColor(r, g, b, alpha)
end

local function ApplyNativeRenderedClassColor(region, plate, alpha)
    if not region or not plate or not GetNativeHealthStatusBarForPlate then
        return false
    end

    -- Blizzard can still render the correct enemy-player class color while the
    -- corresponding UnitClass identity data is restricted to addon Lua. Copy the
    -- already-rendered status-bar color straight into our texture without ever
    -- inspecting, comparing, converting, or caching the RGB components.
    local nativeHealth = GetNativeHealthStatusBarForPlate(plate)
    if not nativeHealth or type(nativeHealth.GetStatusBarColor) ~= "function" then
        return false
    end

    -- Do not trust a recycled native bar on the very first update for a new
    -- occupant. EnemyPlates.lua marks the current generation ready on the next
    -- frame, after Blizzard has had a chance to repaint its native health bar.
    if plate.nativeClassColorReadyGeneration ~= (plate.unitGeneration or 0) then
        return false
    end

    local ok = pcall(function()
        local r, g, b = nativeHealth:GetStatusBarColor()
        region:SetVertexColor(r, g, b, alpha)
    end)

    return ok == true
end

local function ApplyThreatFlareColor(region, plate, unit, alpha, forceCustom)
    if not region then return end

    local mode = CFG.enemyPlateAuraFlareColorMode or "CUSTOM"
    if mode == "CUSTOM" or forceCustom == true then
        ApplyThreatFlareCustomColor(region, alpha)
        return
    end

    -- Class mode resolves the current unit's class directly from Blizzard.
    -- Do this before consulting any rendered plate color: AuraContainer buttons
    -- are recycled between units, and their BattleMender-owned flare textures can
    -- otherwise retain the previous unit's class color.
    if IsTestUnit(unit) then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
        if c then
            region:SetVertexColor(c.r, c.g, c.b, alpha)
            return
        end
    elseif unit and UnitClass then
        local applied = false
        local ok = pcall(function()
            local _, classToken = UnitClass(unit)
            local color = C_ClassColor and C_ClassColor.GetClassColor
                and C_ClassColor.GetClassColor(classToken)
            if not color then return end
            local r, g, b = color:GetRGB()
            region:SetVertexColor(r, g, b, alpha)
            applied = true
        end)
        if ok and applied then return end
    end

    -- Solo Shuffle / arena can restrict the class identity path above even
    -- though Blizzard's own enemy nameplate has already been painted with the
    -- correct class color. This is the authoritative restricted-PvP fallback
    -- and is deliberately independent of BattleMender's visible health-bar
    -- color mode.
    if ApplyNativeRenderedClassColor(region, plate, alpha) then
        return
    end

    -- In restricted PvP UnitClass/C_ClassColor may be unavailable to addon Lua,
    -- while EnemyHealth has already copied Blizzard's current class color onto
    -- BattleMender's own health region. Reuse that rendered result only when it
    -- was resolved during the current plate generation; this prevents a recycled
    -- physical plate from donating the previous occupant's tint.
    if UnitLooksLikePlayer(unit, plate and plate.nativeFrame) then
        if plate
            and plate.healthClassColorResolved == true
            and plate.healthClassColorGeneration == (plate.unitGeneration or 0)
            and ApplyRenderedHealthColor(region, plate, unit, alpha)
        then
            return
        end

        ApplyThreatFlareCustomColor(region, alpha)
        return
    end

    ApplyRenderedHealthColor(region, plate, unit, alpha)
end

local function RefreshAuraFlareColorsForPlate(plate, unit)
    if not plate then return end

    local opacity = tonumber(CFG.enemyPlateAuraFlareOpacity) or 0.28
    if opacity < 0 then opacity = 0 end
    if opacity > 1 then opacity = 1 end

    -- Never inspect or alter Blizzard AuraButton visibility here. Only recolor
    -- BattleMender-owned texture regions. This allows recycled managed buttons
    -- to follow the current nameplate class without touching their secret state.
    for _, effect in pairs(AURA_FLARES) do
        if type(effect) == "table" and effect.plate == plate and effect.lockFlareColor ~= true then
            if effect.flareBase then
                pcall(ApplyThreatFlareColor, effect.flareBase, plate, unit, math.min(1, opacity * 1.15), effect.forceCustomColor)
            end
            if effect.flareAdditive then
                pcall(ApplyThreatFlareColor, effect.flareAdditive, plate, unit, math.min(1, opacity * 0.9), effect.forceCustomColor)
            end
        end
    end
end

local function SetHealthThreatFlare(plate, flareBase, flareAdditive, flareMask, unit, forceCustom)
    if not plate or not plate.health or not flareBase or not flareAdditive then return end

    local height = tonumber(CFG.enemyPlateAuraFlareHeight) or 32
    if height < 4 then height = 4 end
    if height > 100 then height = 100 end

    local density = tonumber(CFG.enemyPlateAuraFlareDensity) or 1
    if density < 0.5 then density = 0.5 end
    if density > 2.5 then density = 2.5 end

    local yOffset = tonumber(CFG.enemyPlateAuraFlareYOffset) or 4
    if yOffset < -20 then yOffset = -20 end
    if yOffset > 40 then yOffset = 40 end

    local opacity = tonumber(CFG.enemyPlateAuraFlareOpacity) or 0.28
    if opacity < 0 then opacity = 0 end
    if opacity > 1 then opacity = 1 end

    -- SetHorizTile maps source pixels to local UI units. Give the flare layers
    -- a density-scaled logical width; a constant horizontal Scale animation in
    -- the already-running Progressive animation group counter-scales that width
    -- back to the bar. This avoids post-init SetScale calls on 12.1 AuraButtons.
    local barWidth = plate.health:GetWidth()
    if not barWidth or barWidth <= 0 then
        barWidth = tonumber(CFG.enemyPlateWidth) or 120
    end

    local function AnchorFlareLayer(region)
        region:ClearAllPoints()
        region:SetSize(barWidth * density, height)
        region:SetPoint("BOTTOM", plate.health, "TOP", 0, yOffset)
    end

    local function AnchorMask(region)
        region:ClearAllPoints()
        region:SetSize(barWidth, height)
        region:SetPoint("BOTTOM", plate.health, "TOP", 0, yOffset)
    end

    -- Keep the health-bar coverage but make flare height/density independently
    -- configurable. REPEAT matches Blizzard's horizontal wrap behavior.
    if not flareBase._bmAggroFlareConfigured then
        flareBase:SetAtlas(NAMEPLATE_AGGRO_FLARE_ATLAS, false, nil, true, "REPEAT", "CLAMP")
        flareBase:SetHorizTile(true)
        flareBase:SetBlendMode("BLEND")
        flareBase._bmAggroFlareConfigured = true
    end
    if not flareAdditive._bmAggroFlareConfigured then
        flareAdditive:SetAtlas(NAMEPLATE_AGGRO_FLARE_ATLAS, false, nil, true, "REPEAT", "CLAMP")
        flareAdditive:SetHorizTile(true)
        flareAdditive:SetBlendMode("ADD")
        flareAdditive._bmAggroFlareConfigured = true
    end
    if flareMask and not flareMask._bmAggroMaskConfigured then
        flareMask:SetAtlas(NAMEPLATE_AGGRO_MASK_ATLAS, false)
        flareMask._bmAggroMaskConfigured = true
    end

    AnchorFlareLayer(flareBase)
    AnchorFlareLayer(flareAdditive)
    if flareMask then AnchorMask(flareMask) end

    ApplyThreatFlareColor(flareBase, plate, unit, math.min(1, opacity * 1.15), forceCustom)
    ApplyThreatFlareColor(flareAdditive, plate, unit, math.min(1, opacity * 0.9), forceCustom)

    flareBase:Show()
    flareAdditive:Show()
    if flareMask then flareMask:Show() end
end

local function EnsureThreatFlareScrollAnimation(owner, effect, density)
    if not owner or not effect or effect.scrollAnim then return end
    if not owner.CreateAnimationGroup or not effect.flareBase or not effect.flareAdditive then return end

    local okGroup, group = pcall(owner.CreateAnimationGroup, owner)
    if not okGroup or not group then return end
    group:SetLooping("REPEAT")

    local function AddScroll(target, offsetU)
        -- Lua uses the constructor name "TextureCoord" for the XML
        -- <TextureCoordTranslation> animation type used by Blizzard.
        local okAnim, anim = pcall(group.CreateAnimation, group, "TextureCoord")
        if not okAnim or not anim then return false end

        if not anim.SetTarget or not anim.SetOffset then return false end
        local okTarget, targeted = pcall(anim.SetTarget, anim, target)
        if not okTarget or targeted == false then return false end

        anim:SetDuration(40)
        anim:SetOrder(1)
        anim:SetOffset(offsetU, 0)
        return true
    end

    -- Match Blizzard's Progressive aggro treatment: the base and additive flare
    -- layers crawl in opposite horizontal directions over a 40-second loop.
    if not AddScroll(effect.flareBase, 1) or not AddScroll(effect.flareAdditive, -1) then
        pcall(group.Stop, group)
        return
    end

    density = tonumber(density) or 1
    if density < 0.5 then density = 0.5 end
    if density > 2.5 then density = 2.5 end
    local scaleX = 1 / density

    local function AddHorizontalScale(target)
        if math.abs(density - 1) < 0.001 then return true end
        local okAnim, anim = pcall(group.CreateAnimation, group, "Scale")
        if not okAnim or not anim then return false end
        if not anim.SetTarget or not anim.SetScaleFrom or not anim.SetScaleTo then return false end
        local okTarget, targeted = pcall(anim.SetTarget, anim, target)
        if not okTarget or targeted == false then return false end
        anim:SetDuration(40)
        anim:SetOrder(1)
        if anim.SetOrigin then anim:SetOrigin("CENTER", 0, 0) end
        anim:SetScaleFrom(scaleX, 1)
        anim:SetScaleTo(scaleX, 1)
        return true
    end

    -- Use the animation system rather than Region:SetScale: the flare lives on
    -- Blizzard's managed AuraButton and the 14.10-safe rule is to avoid later
    -- direct scale/state mutations on that restricted subtree.
    if not AddHorizontalScale(effect.flareBase) or not AddHorizontalScale(effect.flareAdditive) then
        pcall(group.Stop, group)
        return
    end

    effect.scrollAnim = group
    effect.flareDensity = density
end

-- Aura-category flare ownership in the 12.1 managed path.
--
-- CustomAuraButtonTemplate frames and their descendants carry secret aspects.
-- Do not attach scripts, create visibility proxies, poll visibility, or try to
-- re-layer descendant frames. The safe path is to create only texture regions on
-- the AuraButton during initializeFrame. Those regions inherit Blizzard's button
-- visibility automatically. Their geometry is anchored above BattleMender's
-- health bar; Vertical Offset is the supported way to move the flame base clear
-- of the bar without touching protected frame state after initialization.
local function ApplyAuraFlare(plate, category, button, forceCustomColor, lockFlareColor)
    if not plate or not button then return end

    local triggerCategory = CFG.enemyPlateAuraFlareTriggerCategory or "DANGER"
    if category ~= triggerCategory then return end

    local effect = AURA_FLARES[button]

    if CFG.enemyPlateAuraFlareEnabled == false then
        -- Manual/Test Mode buttons are addon-owned and reused, so clean an
        -- existing effect when the option is toggled off. Managed buttons are
        -- rebuilt/hidden by AuraContainer and do not require post-init access.
        if type(effect) == "table" then
            if effect.scrollAnim and effect.scrollAnim.Stop then
                pcall(effect.scrollAnim.Stop, effect.scrollAnim)
            end
            for _, region in ipairs({ effect.flareBase, effect.flareAdditive, effect.flareMask }) do
                if region and region.Hide then pcall(region.Hide, region) end
            end
        end
        return
    end

    if type(effect) ~= "table" then
        effect = {}

        -- Keep these as direct AuraButton regions. This is the same ownership
        -- model that rendered safely before the 14.8 root-layering experiment.
        local okBase, flareBase = pcall(button.CreateTexture, button, nil, "BACKGROUND", nil, -7)
        if okBase then effect.flareBase = flareBase end

        local okAdditive, flareAdditive = pcall(button.CreateTexture, button, nil, "BACKGROUND", nil, -6)
        if okAdditive then effect.flareAdditive = flareAdditive end

        if button.CreateMaskTexture then
            local okMask, flareMask = pcall(button.CreateMaskTexture, button, nil, "BACKGROUND", nil, -5)
            if okMask then effect.flareMask = flareMask end
        end

        if effect.flareMask then
            if effect.flareBase and effect.flareBase.AddMaskTexture then
                pcall(effect.flareBase.AddMaskTexture, effect.flareBase, effect.flareMask)
            end
            if effect.flareAdditive and effect.flareAdditive.AddMaskTexture then
                pcall(effect.flareAdditive.AddMaskTexture, effect.flareAdditive, effect.flareMask)
            end
        end

        AURA_FLARES[button] = effect
    end

    -- AuraButtons are recycled by Blizzard. Keep explicit ownership so the
    -- current nameplate refresh can recolor our texture regions for the new unit.
    effect.plate = plate
    effect.category = category
    effect.forceCustomColor = forceCustomColor == true
    effect.lockFlareColor = lockFlareColor == true

    local density = tonumber(CFG.enemyPlateAuraFlareDensity) or 1
    if density < 0.5 then density = 0.5 end
    if density > 2.5 then density = 2.5 end
    if effect.scrollAnim and effect.flareDensity ~= density then
        -- This path is only meaningful for reusable manual/Test Mode buttons;
        -- managed buttons are rebuilt whenever the flare signature changes.
        pcall(effect.scrollAnim.Stop, effect.scrollAnim)
        effect.scrollAnim = nil
    end
    EnsureThreatFlareScrollAnimation(button, effect, density)

    -- For managed buttons this runs only inside initializeFrame. Once Blizzard
    -- applies the secret-aspect restriction, the textures simply follow their
    -- owner's native show/hide state and the already-started animation loops.
    if effect.flareBase and effect.flareAdditive then
        pcall(SetHealthThreatFlare, plate, effect.flareBase, effect.flareAdditive, effect.flareMask, plate.unit, effect.forceCustomColor)
    end
    if effect.scrollAnim and effect.scrollAnim.Play and not effect.scrollAnim:IsPlaying() then
        pcall(effect.scrollAnim.Play, effect.scrollAnim)
    end
end



-- Export private helpers used by later enemy-nameplate modules.
EPI.ApplyRenderedHealthColor = ApplyRenderedHealthColor
EPI.ApplyThreatFlareCustomColor = ApplyThreatFlareCustomColor
EPI.ApplyThreatFlareColor = ApplyThreatFlareColor
EPI.RefreshAuraFlareColorsForPlate = RefreshAuraFlareColorsForPlate
EPI.SetHealthThreatFlare = SetHealthThreatFlare
EPI.EnsureThreatFlareScrollAnimation = EnsureThreatFlareScrollAnimation
EPI.ApplyAuraFlare = ApplyAuraFlare

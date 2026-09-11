BattleMender = BattleMender or {}

local BM = BattleMender
local EPI = BM.EnemyPlateInternal
local CFG = EPI.CFG
local OUTER_GLOW_TEXTURE = EPI.OUTER_GLOW_TEXTURE
local CLASS_ICON = EPI.CLASS_ICON
local IsTestUnit = EPI.IsTestUnit
local GetEnemyBorderStyle = EPI.GetEnemyBorderStyle
local SetBorderColor = EPI.SetBorderColor
local IsBattlegroundOrArena = EPI.IsBattlegroundOrArena
local UnitLooksLikePlayer = EPI.UnitLooksLikePlayer
local ConfigColor = EPI.ConfigColor
local GetSafeHealthRatio = EPI.GetSafeHealthRatio
local UnitIsCurrentTarget = EPI.UnitIsCurrentTarget
local UnitIsCurrentMouseover = EPI.UnitIsCurrentMouseover
local UseStableHealthClip = EPI.UseStableHealthClip
local GetNativeHealthRatio = EPI.GetNativeHealthRatio
local UpdateEnemyHealthFillClip = EPI.UpdateEnemyHealthFillClip
local ApplyEnemyHealthTexture = EPI.ApplyEnemyHealthTexture
local ApplyEnemyHealthBackground = EPI.ApplyEnemyHealthBackground
local UpdateEnemyAbsorb = EPI.UpdateEnemyAbsorb
local ApplyEnemyPlayerClassColor = EPI.ApplyEnemyPlayerClassColor
local ShouldUsePlayerHealthClassColor = EPI.ShouldUsePlayerHealthClassColor
local GetUnitColor = EPI.GetUnitColor
local GetUnitNameColor = EPI.GetUnitNameColor

local function UpdatePortrait(plate, unit)
    if IsTestUnit(unit) then
        if CFG.enemyPlatePortraitEnabled == false then
            plate.portrait:Hide()
            return
        end

        plate.portrait:Show()
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.PALADIN
        if coords then
            plate.portraitTex:SetTexture(CLASS_ICON)
            plate.portraitTex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            plate.portraitTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            plate.portraitTex:SetTexCoord(0, 1, 0, 1)
        end
        return
    end

    local inBG = IsBattlegroundOrArena()
    if CFG.enemyPlatePortraitEnabled == false or (CFG.enemyPlatePortraitHideInBG ~= false and inBG) then
        plate.portrait:Hide()
        return
    end

    plate.portrait:Show()
    plate.portraitTex:SetTexCoord(0, 1, 0, 1)
    if SetPortraitTexture then
        pcall(SetPortraitTexture, plate.portraitTex, unit)
    end
end

local function ApplyEnemyHealthColors(plate, unit, frame)
    local r, g, b, a = GetUnitColor(unit, true, frame)

    -- Record whether this update successfully resolved a real player class
    -- color. The aura flare can safely reuse that already-rendered result when
    -- UnitClass is temporarily unavailable on its own refresh.
    plate.healthClassColorResolved = false

    -- Target and low-health are highlighted on the background/glow layers.
    -- Do not replace the bar's actual unit/reaction/class color when targeting.
    if UseStableHealthClip() then
        pcall(plate.health.SetStatusBarColor, plate.health, 1, 1, 1, 0.001)
        if plate.healthFillTex then
            if ShouldUsePlayerHealthClassColor(unit, frame)
                and ApplyEnemyPlayerClassColor(plate.healthFillTex, "SetVertexColor", plate, unit)
            then
                plate.healthClassColorResolved = true
                return
            end
            pcall(plate.healthFillTex.SetVertexColor, plate.healthFillTex, r or 1, g or 1, b or 1, a or 1)
        end
    else
        if ShouldUsePlayerHealthClassColor(unit, frame)
            and ApplyEnemyPlayerClassColor(plate.health, "SetStatusBarColor", plate, unit)
        then
            plate.healthClassColorResolved = true
            return
        end
        pcall(plate.health.SetStatusBarColor, plate.health, r or 1, g or 1, b or 1, a or 1)
        if plate.healthFillTex then
            plate.healthFillTex:Hide()
        end
    end
end

local OUTER_GLOW_EXPANSION = 2.0 -- health-bar heights per side

local function HideHealthGlow(glow)
    if not glow then return end

    if glow.Hide then
        glow:Hide()
        return
    end

    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        local tex = glow[key]
        if tex and tex.Hide then
            tex:Hide()
        end
    end
end

local function ConfigureGlowPiece(tex, r, g, b, a)
    if not tex then return end
    tex:SetTexture(OUTER_GLOW_TEXTURE)
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(r or 1, g or 1, b or 1, a or 0.72)
end

local function SetHealthGlow(plate, glow, r, g, b, a, expansionScale)
    if not plate or not plate.health or not glow then return end

    local healthWidth = plate.health:GetWidth()
    local healthHeight = plate.health:GetHeight()
    if type(healthWidth) ~= "number" or healthWidth <= 0 then
        healthWidth = tonumber(CFG.enemyPlateWidth) or 130
    end
    if type(healthHeight) ~= "number" or healthHeight <= 0 then
        healthHeight = tonumber(CFG.enemyPlateHealthHeight) or 10
    end

    -- 2x the health-bar height on EACH side by default.
    local expansion = healthHeight * (tonumber(expansionScale) or OUTER_GLOW_EXPANSION)

    -- Backward-compatible fallback for any legacy single-texture glow object.
    if glow.ClearAllPoints then
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", plate.health, "TOPLEFT", -expansion, expansion)
        glow:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", expansion, -expansion)
        ConfigureGlowPiece(glow, r, g, b, a)
        glow:SetTexCoord(0, 1, 0, 1)
        glow:Show()
        return
    end

    local top = glow.top
    local bottom = glow.bottom
    local left = glow.left
    local right = glow.right
    if not (top and bottom and left and right) then return end

    local fullWidth = healthWidth + (expansion * 2)
    local fullHeight = healthHeight + (expansion * 2)
    if fullWidth <= 0 or fullHeight <= 0 or expansion <= 0 then
        HideHealthGlow(glow)
        return
    end

    -- These texture coordinates sample exactly the same stretched glow that the
    -- old single texture used, except the central health-bar rectangle is omitted.
    local uLeft = expansion / fullWidth
    local uRight = (expansion + healthWidth) / fullWidth
    local vTop = expansion / fullHeight
    local vBottom = (expansion + healthHeight) / fullHeight

    for _, tex in ipairs({ top, bottom, left, right }) do
        ConfigureGlowPiece(tex, r, g, b, a)
        tex:ClearAllPoints()
    end

    top:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", -expansion, 0)
    top:SetSize(fullWidth, expansion)
    top:SetTexCoord(0, 1, 0, vTop)

    bottom:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", -expansion, 0)
    bottom:SetSize(fullWidth, expansion)
    bottom:SetTexCoord(0, 1, vBottom, 1)

    left:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMLEFT", 0, 0)
    left:SetSize(expansion, healthHeight)
    left:SetTexCoord(0, uLeft, vTop, vBottom)

    right:SetPoint("BOTTOMLEFT", plate.health, "BOTTOMRIGHT", 0, 0)
    right:SetSize(expansion, healthHeight)
    right:SetTexCoord(uRight, 1, vTop, vBottom)

    top:Show()
    bottom:Show()
    left:Show()
    right:Show()
end

local function SetHealthBackgroundAlert(plate, r, g, b, a)
    if not plate or not plate.healthAlertBG then return end

    plate.healthAlertBG:SetColorTexture(r or 1, g or 1, b or 1, a or 0.27)
    plate.healthAlertBG:Show()
end

local function GetLowHealthGlowColor(unit, plate)
    local ratio = plate and plate.lastHealthRatio or nil
    if type(ratio) ~= "number" then
        ratio = GetNativeHealthRatio(plate)
    end
    if type(ratio) ~= "number" then
        ratio = GetSafeHealthRatio(unit)
    end
    if CFG.enemyPlateLowHealthEnabled == false or not ratio then
        return nil
    end

    local threshold = tonumber(CFG.enemyPlateLowHealthThreshold) or 0.15
    if threshold < 0.01 then threshold = 0.01 end
    if threshold > 1 then threshold = 1 end

    if ratio <= (threshold * 0.5) then
        return ConfigColor("enemyPlateLowHealthHalf", 0.57647058823529, 0.17254901960784, 0.17254901960784, 0.12549019607843)
    elseif ratio <= threshold then
        return ConfigColor("enemyPlateLowHealth", 0.71764705882353, 0.71764705882353, 0.2156862745098, 0.14117647058824)
    end

    return nil
end

local function UpdateEnemyHighlights(plate, unit)
    local targetHighlightEnabled = CFG.enemyPlateTargetHighlightEnabled ~= false
    local targetBackgroundTint = CFG.enemyPlateTargetBackgroundTint ~= false
    local targetGlowEnabled = CFG.enemyPlateTargetGlowEnabled ~= false
    local lowHealthBackgroundTint = CFG.enemyPlateLowHealthBackgroundTint ~= false
    local lowHealthGlowEnabled = CFG.enemyPlateLowHealthGlowEnabled ~= false
    local isTarget = IsTestUnit(unit) or UnitIsCurrentTarget(unit)
    local lowR, lowG, lowB, lowA = GetLowHealthGlowColor(unit, plate)

    -- Health-bar border is normally the shared enemy element border color.
    -- The current target may override only this border without recoloring cast,
    -- portrait, or aura borders.
    local _, borderR, borderG, borderB, borderA = GetEnemyBorderStyle()
    if targetHighlightEnabled and isTarget then
        borderR, borderG, borderB, borderA = ConfigColor("enemyPlateTargetBorder", 1, 1, 1, 1)
    end
    SetBorderColor(plate.health, borderR, borderG, borderB, borderA)

    if plate.healthAlertBG then
        plate.healthAlertBG:Hide()
    end
    if plate.targetGlow then
        HideHealthGlow(plate.targetGlow)
    end
    if plate.lowHealthGlow then
        HideHealthGlow(plate.lowHealthGlow)
    end

    if targetHighlightEnabled and isTarget then
        local r, g, b, a = ConfigColor("enemyPlateTargetColor", 1, 1, 1, 0.27058823529412)
        if targetGlowEnabled and plate.targetGlow then
            SetHealthGlow(plate, plate.targetGlow, r, g, b, 0.72)
        end
        if targetBackgroundTint then
            SetHealthBackgroundAlert(plate, r, g, b, a)
        end
    elseif lowR then
        if lowHealthGlowEnabled and plate.lowHealthGlow then
            SetHealthGlow(plate, plate.lowHealthGlow, lowR, lowG, lowB, 0.55)
        end
        if lowHealthBackgroundTint then
            SetHealthBackgroundAlert(plate, lowR, lowG, lowB, lowA)
        end
    end

    -- Hover remains an overlay on the bar itself; target and low-health use
    -- independently controlled background tint and/or outer glow layers.
    if plate.targetOverlay then
        plate.targetOverlay:Hide()
    end

    if plate.hoverOverlay then
        if CFG.enemyPlateHoverHighlightEnabled ~= false and UnitIsCurrentMouseover(unit) then
            local r, g, b, a = ConfigColor("enemyPlateHoverColor", 1, 1, 1, 0.18)
            plate.hoverOverlay:SetColorTexture(r, g, b, a)
            plate.hoverOverlay:Show()
        else
            plate.hoverOverlay:Hide()
        end
    end
end

local function UpdateHealth(plate, unit, frame)
    if IsTestUnit(unit) then
        ApplyEnemyHealthTexture(plate, unit)
        ApplyEnemyHealthBackground(plate)
        plate.health:SetMinMaxValues(0, 1)
        plate.health:SetValue(0.72)
        UpdateEnemyHealthFillClip(plate)
        UpdateEnemyAbsorb(plate, unit)
        ApplyEnemyHealthColors(plate, unit, frame)
        UpdateEnemyHighlights(plate, unit)
        plate.healthText:SetText("")
        plate.healthText:Hide()
        return
    end

    local maxHealth = UnitHealthMax(unit)
    local health = UnitHealth(unit)

    -- Modern nameplate health values can be "secret numbers" when accessed
    -- through an addon-tainted path. They may be passed into StatusBar APIs,
    -- but must not be compared, converted, divided, rounded, or formatted by
    -- addon code. Keep the bar fill and omit custom numeric health text.
    ApplyEnemyHealthTexture(plate, unit)
    ApplyEnemyHealthBackground(plate)
    pcall(plate.health.SetMinMaxValues, plate.health, 0, maxHealth)
    pcall(plate.health.SetValue, plate.health, health)
    UpdateEnemyHealthFillClip(plate)
    UpdateEnemyAbsorb(plate, unit)

    ApplyEnemyHealthColors(plate, unit, frame)
    UpdateEnemyHighlights(plate, unit)

    plate.healthText:SetText("")
    plate.healthText:Hide()
end

local function UpdateName(plate, unit, frame)
    if IsTestUnit(unit) then
        if CFG.enemyPlateShowName == false then
            if plate.nameFrame then plate.nameFrame:Hide() end
            plate.name:Hide()
            return
        end
        if plate.nameFrame then plate.nameFrame:Show() end
        plate.name:Show()
        pcall(plate.name.SetText, plate.name, "Enemy Test - Paladin")
        plate.name:SetTextColor(GetUnitNameColor(unit, frame))
        return
    end

    if CFG.enemyPlateShowName == false
        or (CFG.enemyPlateHidePlayerNamesInPvP ~= false and IsBattlegroundOrArena() and UnitLooksLikePlayer(unit, frame)) then
        if plate.nameFrame then plate.nameFrame:Hide() end
        plate.name:Hide()
        return
    end

    if plate.nameFrame then plate.nameFrame:Show() end
    plate.name:Show()
    pcall(plate.name.SetText, plate.name, UnitName(unit) or "")
    if UnitLooksLikePlayer(unit, frame)
        and CFG.enemyPlateClassColorNames ~= false
        and ApplyEnemyPlayerClassColor(plate.name, "SetTextColor", plate, unit)
    then
        return
    end
    plate.name:SetTextColor(1, 1, 1)
end



-- Export private helpers used by later enemy-nameplate modules.
EPI.UpdatePortrait = UpdatePortrait
EPI.ApplyEnemyHealthColors = ApplyEnemyHealthColors
EPI.OUTER_GLOW_EXPANSION = OUTER_GLOW_EXPANSION
EPI.HideHealthGlow = HideHealthGlow
EPI.ConfigureGlowPiece = ConfigureGlowPiece
EPI.SetHealthGlow = SetHealthGlow
EPI.SetHealthBackgroundAlert = SetHealthBackgroundAlert
EPI.GetLowHealthGlowColor = GetLowHealthGlowColor
EPI.UpdateEnemyHighlights = UpdateEnemyHighlights
EPI.UpdateHealth = UpdateHealth
EPI.UpdateName = UpdateName

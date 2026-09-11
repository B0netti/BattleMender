BattleMender = BattleMender or {}

local BM = BattleMender
local EPI = BM.EnemyPlateInternal
local CFG = EPI.CFG
local CAST_STATE = EPI.CAST_STATE
local IsTestUnit = EPI.IsTestUnit
local ReadUnitIsUnit = EPI.ReadUnitIsUnit
local SafeUnitIsUnit = EPI.SafeUnitIsUnit
local UpdateCastIconBorder = EPI.UpdateCastIconBorder
local ClampNumber = EPI.ClampNumber
local ApplyEnemyCastTexture = EPI.ApplyEnemyCastTexture
local UpdateEnemyCastSpark = EPI.UpdateEnemyCastSpark

local function ReadCastInfo(unit)
    if UnitCastingInfo then
        local name, text, texture, startTimeMS, endTimeMS, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
        if name then
            return name, texture, startTimeMS, endTimeMS, notInterruptible, false, spellID
        end
    end

    if UnitChannelInfo then
        local name, text, texture, startTimeMS, endTimeMS, _, notInterruptible, spellID = UnitChannelInfo(unit)
        if name then
            return name, texture, startTimeMS, endTimeMS, notInterruptible, true, spellID
        end
    end

    return nil
end

local function GetCastInfo(unit)
    if IsTestUnit(unit) then
        local now = (GetTime and GetTime() or 0) * 1000
        local cycle = 2400
        local startMS = now - (now % cycle)
        local endMS = startMS + cycle
        return "BattleMender Test Cast", "Interface\\Icons\\Spell_Fire_Fireball02", startMS, endMS, false, false, nil
    end

    -- The target token is a direct, reliable relationship to the visible
    -- nameplate. Prefer it when it identifies this plate, because Retail can
    -- expose fuller cast information through target than through nameplateN.
    if unit ~= "target" and UnitIsUnit then
        local ok, isTarget = pcall(function()
            return UnitIsUnit(unit, "target") and true or false
        end)
        if ok and isTarget == true then
            local name, texture, startTimeMS, endTimeMS, notInterruptible, isChannel, spellID = ReadCastInfo("target")
            if name then
                return name, texture, startTimeMS, endTimeMS, notInterruptible, isChannel, spellID
            end
        end
    end

    return ReadCastInfo(unit)
end

local function HideCustomCast(plate)
    plate.castActive = false
    plate.castElapsed = 0
    pcall(plate.cast.SetValue, plate.cast, 0)
    pcall(plate.castText.SetText, plate.castText, "")
    pcall(plate.castIcon.SetTexture, plate.castIcon, nil)

    plate.cast:Hide(); plate.castText:Hide(); plate.castIcon:Hide(); plate.castIconBG:Hide()

    UpdateEnemyCastSpark(plate)

    if BM.SuppressEnemyNativeCast and plate.nativeFrame then
        BM.SuppressEnemyNativeCast(plate.nativeFrame)
    end
end

-- Keep cast state in BattleMender-owned storage, keyed by the unit token used
-- for the visible plate. This follows the same supported path as established
-- nameplate providers: the API return initializes the state and the explicit
-- UNIT_SPELLCAST_* interruptibility event is authoritative for the cast.
local function GetCastState(unit, create)
    if not unit then return nil end

    local state = CAST_STATE[unit]
    if not state and create then
        state = {}
        CAST_STATE[unit] = state
    end

    return state
end

local function GetInterruptedCastHoldTime()
    return ClampNumber(CFG.enemyPlateCastInterruptedHoldTime, 0.75, 0.1, 3)
end

local function IsInterruptedCastHeld(state)
    return state
        and state.interruptedUntil
        and (GetTime and GetTime() or 0) < state.interruptedUntil
end

function BM.HandleEnemyCastEvent(event, unit)
    if not unit then return end

    local state = GetCastState(unit, true)
    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
    then
        state.notInterruptible = nil
        state.interruptedUntil = nil
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        state.notInterruptible = true
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        state.notInterruptible = false
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        state.notInterruptible = nil
        state.interruptedUntil = (GetTime and GetTime() or 0) + GetInterruptedCastHoldTime()
    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    then
        -- Retail can send a normal stop event immediately after INTERRUPTED.
        -- Preserve the explicit interruption result until its configured hold
        -- expires; new casts and plate cleanup still clear it immediately.
        if not IsInterruptedCastHeld(state) then
            CAST_STATE[unit] = nil
        end
    end

end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function ConfigureEnemyCastEvents(plate, unit)
    local root = plate and plate.root
    if not root then return end

    -- ApplyEnemyPlate also runs for health and aura refreshes. Avoid cycling a
    -- live event subscription when this plate is still showing the same unit.
    if plate.castEventUnit == unit then
        return
    end

    for _, event in ipairs(CAST_EVENTS) do
        root:UnregisterEvent(event)
    end

    plate.castEventUnit = nil

    if not unit or IsTestUnit(unit) then
        return
    end

    -- RegisterUnitEvent is Blizzard's own cast-bar subscription model. It
    -- delivers the explicit INTERRUPTIBLE / NOT_INTERRUPTIBLE state even when
    -- UnitCastingInfo's boolean return is restricted for a nameplate unit.
    for _, event in ipairs(CAST_EVENTS) do
        root:RegisterUnitEvent(event, unit)
    end
    plate.castEventUnit = unit
end

local function SafeUnitIsUnit(unitA, unitB)
    if not unitA or not unitB or not UnitIsUnit then
        return false
    end

    -- UnitIsUnit can return a secret boolean on nameplate-target paths. Keep
    -- the comparison inside pcall, but avoid allocating a closure per call.
    local ok, result = pcall(ReadUnitIsUnit, unitA, unitB)
    return ok and result == true
end

local function SafeUnitExists(unit)
    if not unit or not UnitExists then
        return false
    end

    -- UnitExists can also produce a protected/secret boolean for derived
    -- nameplate target tokens. Keep the boolean coercion inside pcall.
    local ok, result = pcall(function()
        return UnitExists(unit) and true or false
    end)

    return ok and result == true
end

local function CastTargetsPlayer(unit)
    if IsTestUnit(unit) then
        return false
    end
    local target = unit and (unit .. "target")
    return SafeUnitExists(target) and SafeUnitIsUnit(target, "player")
end

local function CastIsConfirmedNotInterruptible(plate, unit)
    if plate and plate.castNotInterruptible ~= nil then
        return plate.castNotInterruptible == true
    end

    local state = GetCastState(unit, false)
    if state and state.notInterruptible ~= nil then
        return state.notInterruptible == true
    end
    return false
end

local function GetEnemyCastBaseColor(unit)
    if CastTargetsPlayer(unit) then
        return
            tonumber(CFG.enemyPlateCastTargetPlayerR) or 1,
            tonumber(CFG.enemyPlateCastTargetPlayerG) or 0.12,
            tonumber(CFG.enemyPlateCastTargetPlayerB) or 0.08
    end

    return
        tonumber(CFG.enemyPlateCastInterruptibleR) or 1,
        tonumber(CFG.enemyPlateCastInterruptibleG) or 0.82,
        tonumber(CFG.enemyPlateCastInterruptibleB) or 0.05
end

local function GetEnemyCastColor(plate, unit, notInterruptible)
    local baseR, baseG, baseB = GetEnemyCastBaseColor(unit)
    local lockedR = tonumber(CFG.enemyPlateCastNotInterruptibleR) or 0.45
    local lockedG = tonumber(CFG.enemyPlateCastNotInterruptibleG) or 0.45
    local lockedB = tonumber(CFG.enemyPlateCastNotInterruptibleB) or 0.45

    -- Explicit UNIT_SPELLCAST_NOT_INTERRUPTIBLE remains authoritative when
    -- available. On 12.1, however, the cast-info flag is commonly a secret
    -- boolean. Preserve it as an opaque value and use Blizzard's approved
    -- boolean-to-color operation, which selects the configured color without
    -- exposing or comparing the protected state in Lua.
    if CastIsConfirmedNotInterruptible(plate, unit) then
        return lockedR, lockedG, lockedB
    end

    local isSecret = BM.IsSecretValue and BM.IsSecretValue(notInterruptible)
    local evaluate = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    if isSecret then
        if evaluate then
            local ok, r, g, b = pcall(function()
                return
                    evaluate(notInterruptible, lockedR, baseR),
                    evaluate(notInterruptible, lockedG, baseG),
                    evaluate(notInterruptible, lockedB, baseB)
            end)
            if ok then
                return r, g, b
            end
        end

        -- Never compare a secret boolean, including on clients where the
        -- approved curve evaluator is unexpectedly unavailable.
        return baseR, baseG, baseB
    elseif notInterruptible == true then
        return lockedR, lockedG, lockedB
    end

    return baseR, baseG, baseB
end

local function ApplyEnemyCastColor(plate, r, g, b)
    local texture = plate and plate.cast and plate.cast:GetStatusBarTexture()
    if texture and texture.SetVertexColor then
        local ok = pcall(texture.SetVertexColor, texture, r, g, b, 1)
        if ok then
            return true
        end
    end

    if plate and plate.cast then
        local ok = pcall(plate.cast.SetStatusBarColor, plate.cast, r, g, b, 1)
        return ok
    end

    return false
end

local function ShowInterruptedCast(plate)
    plate.castActive = true
    ApplyEnemyCastTexture(plate, false)
    plate.cast:Show()
    plate.castText:Show()
    plate.castIcon:Show()
    if plate.castSpark then plate.castSpark:Hide() end
    UpdateCastIconBorder(plate)

    pcall(plate.cast.SetMinMaxValues, plate.cast, 0, 1)
    if plate.cast.SetReverseFill then
        pcall(plate.cast.SetReverseFill, plate.cast, false)
    end
    pcall(plate.cast.SetValue, plate.cast, 1)
    plate.cast:SetStatusBarColor(
        tonumber(CFG.enemyPlateCastInterruptedR) or 0.9,
        tonumber(CFG.enemyPlateCastInterruptedG) or 0.2,
        tonumber(CFG.enemyPlateCastInterruptedB) or 0.2,
        1
    )
    pcall(plate.castText.SetText, plate.castText, INTERRUPTED or "Interrupted")
end

function BM.UpdateEnemyCastOnly(plate, unit)
    if not plate or not unit or CFG.enemyPlateShowCastbar == false then
        if plate then HideCustomCast(plate) end
        return
    end

    local now = GetTime() * 1000
    local state = GetCastState(unit, false)
    -- The cast API can retain the old cast for one frame after an interrupt.
    -- The explicit interruption event is authoritative during the configured
    -- hold window, so show its result before consulting that stale API state.
    if IsInterruptedCastHeld(state) then
        ShowInterruptedCast(plate)
        return
    end

    local name, texture, startMS, endMS, notInterruptible, isChannel = GetCastInfo(unit)
    if name == nil or startMS == nil or endMS == nil then
        if state and state.interruptedUntil then
            CAST_STATE[unit] = nil
        end
        HideCustomCast(plate)
        return
    end

    state = GetCastState(unit, true)
    state.interruptedUntil = nil

    plate.castActive = true
    -- Never compare the cast-info notInterruptible return here: in Retail 12.1
    -- it can be a secret boolean. Texture selection uses the explicit
    -- UNIT_SPELLCAST_INTERRUPTIBLE / NOT_INTERRUPTIBLE event state instead.
    local confirmedNotInterruptible = CastIsConfirmedNotInterruptible(plate, unit)
    ApplyEnemyCastTexture(plate, confirmedNotInterruptible)
    plate.cast:Show(); plate.castText:Show(); plate.castIcon:Show()
    UpdateCastIconBorder(plate)
    pcall(plate.cast.SetMinMaxValues, plate.cast, startMS, endMS)

    -- Normal casts fill from left to right. Channels use their remaining time,
    -- with the coloured segment also anchored on the left so it drains toward
    -- the left edge instead of appearing on the opposite side of the bar.
    local progressApplied
    if isChannel == true then
        progressApplied = pcall(function()
            if plate.cast.SetReverseFill then
                plate.cast:SetReverseFill(false)
            end
            plate.cast:SetValue(endMS - now + startMS)
        end)
    else
        progressApplied = pcall(function()
            if plate.cast.SetReverseFill then
                plate.cast:SetReverseFill(false)
            end
            plate.cast:SetValue(now)
        end)
    end

    -- Fallback for clients that protect cast-time arithmetic. This preserves a
    -- visible channel bar rather than failing the entire update.
    if not progressApplied then
        pcall(plate.cast.SetValue, plate.cast, now)
        if plate.cast.SetReverseFill then
            pcall(plate.cast.SetReverseFill, plate.cast, false)
        end
    end

    local cr, cg, cb = GetEnemyCastColor(plate, unit, notInterruptible)
    local colorApplied = ApplyEnemyCastColor(plate, cr, cg, cb)
    if not colorApplied then
        local baseR, baseG, baseB = GetEnemyCastBaseColor(unit)
        ApplyEnemyCastColor(plate, baseR, baseG, baseB)
    end

    pcall(plate.castText.SetText, plate.castText, name)
    if texture ~= nil then
        pcall(plate.castIcon.SetTexture, plate.castIcon, texture)
    else
        plate.castIcon:SetTexture(nil)
    end

    UpdateEnemyCastSpark(plate)

    if BM.SuppressEnemyNativeCast and plate.nativeFrame then
        BM.SuppressEnemyNativeCast(plate.nativeFrame)
    end
end

local function UpdateCast(plate, unit)
    BM.UpdateEnemyCastOnly(plate, unit)
end



-- Export private helpers used by later enemy-nameplate modules.
EPI.ReadCastInfo = ReadCastInfo
EPI.GetCastInfo = GetCastInfo
EPI.HideCustomCast = HideCustomCast
EPI.GetCastState = GetCastState
EPI.GetInterruptedCastHoldTime = GetInterruptedCastHoldTime
EPI.IsInterruptedCastHeld = IsInterruptedCastHeld
EPI.CAST_EVENTS = CAST_EVENTS
EPI.ConfigureEnemyCastEvents = ConfigureEnemyCastEvents
EPI.SafeUnitIsUnit = SafeUnitIsUnit
EPI.SafeUnitExists = SafeUnitExists
EPI.CastTargetsPlayer = CastTargetsPlayer
EPI.CastIsConfirmedNotInterruptible = CastIsConfirmedNotInterruptible
EPI.GetEnemyCastBaseColor = GetEnemyCastBaseColor
EPI.GetEnemyCastColor = GetEnemyCastColor
EPI.ApplyEnemyCastColor = ApplyEnemyCastColor
EPI.ShowInterruptedCast = ShowInterruptedCast
EPI.UpdateCast = UpdateCast

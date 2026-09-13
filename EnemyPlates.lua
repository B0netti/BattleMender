BattleMender = BattleMender or {}

local BM = BattleMender
local EPI = BM.EnemyPlateInternal
local CFG = EPI.CFG
local ENEMY = EPI.ENEMY
local CAST_STATE = EPI.CAST_STATE
local TEST_UNIT = EPI.TEST_UNIT
local TEST_ANCHOR_NAME = EPI.TEST_ANCHOR_NAME
local ResolveEnemyPlateParent = EPI.ResolveEnemyPlateParent
local IsTestUnit = EPI.IsTestUnit
local ConfigColor = EPI.ConfigColor
local ResolveNativeEnemyUnitFrame = EPI.ResolveNativeEnemyUnitFrame
local RestoreNativeEnemy = EPI.RestoreNativeEnemy
local HideNativeEnemy = EPI.HideNativeEnemy
local EnsureEnemyPlate = EPI.EnsureEnemyPlate
local HideEnemyPlateVisual = EPI.HideEnemyPlateVisual
local UpdateEnemyObjectiveFlash = EPI.UpdateEnemyObjectiveFlash
local SELECTABLE_AURA_SETTING_PREFIX = EPI.SELECTABLE_AURA_SETTING_PREFIX
local SetupEnemyLayout = EPI.SetupEnemyLayout
local UpdatePortrait = EPI.UpdatePortrait
local UpdateEnemyHighlights = EPI.UpdateEnemyHighlights
local UpdateHealth = EPI.UpdateHealth
local UpdateName = EPI.UpdateName
local RefreshAuraFlareColorsForPlate = EPI.RefreshAuraFlareColorsForPlate
local ConfigureEnemyCastEvents = EPI.ConfigureEnemyCastEvents
local SafeUnitExists = EPI.SafeUnitExists
local UpdateCast = EPI.UpdateCast
local UpdateAuraCategory = EPI.UpdateAuraCategory
local UpdateManagedAuraCategory = EPI.UpdateManagedAuraCategory
local HideManagedEnemyAuras = EPI.HideManagedEnemyAuras
local ShouldUseManagedEnemyAuras = EPI.ShouldUseManagedEnemyAuras
local ShouldShowAuraCategory = EPI.ShouldShowAuraCategory
local UpdateAuras = EPI.UpdateAuras

function BM._GetActiveEnemyPlateForUnit(unit)
    if not unit or IsTestUnit(unit) or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return nil, nil
    end

    if not BM.ShouldUseCustomEnemyPlates or not BM.ShouldUseCustomEnemyPlates() then
        return nil, nil
    end

    local ok, nativePlate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not nativePlate then
        return nil, nil
    end

    local plate = ENEMY[nativePlate]
    if not plate or plate.unit ~= unit or not plate.root or not plate.root:IsShown() then
        return nil, nil
    end

    return plate, nativePlate
end

-- Narrow event dispatcher for the custom enemy provider. This prevents health,
-- aura, threat and cast events from recursively doing layout/name/aura work that
-- is unrelated to the event that fired.
function BM.HandleEnemyVisualEvent(event, unit)
    local plate, nativePlate = BM._GetActiveEnemyPlateForUnit(unit)
    if not plate then return false end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(plate, unit, nativePlate)
        return true
    end

    if event == "UNIT_AURA" then
        -- Managed AuraContainers self-register UNIT_AURA and update their own
        -- secret aura state. Calling UpdateAllAuras again from BattleMender is
        -- redundant and was one of the main raid-event amplification paths.
        if not ShouldUseManagedEnemyAuras() then
            UpdateAuras(plate, unit)
        end
        return true
    end

    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_INTERRUPTIBLE"
        or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"
    then
        BM.UpdateEnemyCastOnly(plate, unit)
        return true
    end

    return false
end

function BM._ForEachVisibleEnemyPlate(callback)
    if type(callback) ~= "function" then return end

    for _, plate in pairs(ENEMY) do
        local unit = plate and plate.unit
        if unit and not IsTestUnit(unit) and plate.root and plate.root:IsShown() then
            callback(plate, unit)
        end
    end
end

function BM._UpdateTargetGatedAuraCategories(plate, unit)
    if CFG.enemyPlateShowAuras == false then return end

    local managed = ShouldUseManagedEnemyAuras()
    local update = managed and UpdateManagedAuraCategory or UpdateAuraCategory

    if CFG.enemyPlateBuffAurasTargetOnly == true then
        update(
            plate,
            unit,
            "BUFF",
            ShouldShowAuraCategory(unit, CFG.enemyPlateShowBuffs ~= false, true)
        )
    end

    if CFG.enemyPlateDebuffAurasTargetOnly == true then
        update(
            plate,
            unit,
            "DEBUFF",
            ShouldShowAuraCategory(unit, CFG.enemyPlateShowDebuffs ~= false, true)
        )
    end

    for _, category in ipairs({ "CUSTOM", "DANGER" }) do
        local prefix = SELECTABLE_AURA_SETTING_PREFIX[category]
        local root = "enemyPlate" .. prefix
        if CFG[root .. "AurasTargetOnly"] == true then
            update(
                plate,
                unit,
                category,
                ShouldShowAuraCategory(unit, CFG[root .. "AurasEnabled"] == true, true)
            )
        end
    end
end

function BM._SetEnemyHoverOverlay(plate, enabled)
    if not plate or not plate.hoverOverlay then return end

    if enabled and CFG.enemyPlateHoverHighlightEnabled ~= false then
        local r, g, b, a = ConfigColor("enemyPlateHoverColor", 1, 1, 1, 0.18)
        plate.hoverOverlay:SetColorTexture(r, g, b, a)
        plate.hoverOverlay:Show()
    else
        plate.hoverOverlay:Hide()
    end
end

function BM.RefreshEnemyHoverState()
    local previous = BM._EnemyHoveredPlate
    local current = nil

    if BM.ShouldUseCustomEnemyPlates and BM.ShouldUseCustomEnemyPlates()
        and C_NamePlate and C_NamePlate.GetNamePlateForUnit
    then
        local ok, nativePlate = pcall(C_NamePlate.GetNamePlateForUnit, "mouseover")
        if ok and nativePlate then
            local candidate = ENEMY[nativePlate]
            if candidate
                and candidate.unit
                and not IsTestUnit(candidate.unit)
                and candidate.root
                and candidate.root:IsShown()
            then
                current = candidate
            end
        end
    end

    if previous and previous ~= current then
        BM._SetEnemyHoverOverlay(previous, false)
    end

    if current then
        BM._SetEnemyHoverOverlay(current, true)
    end

    BM._EnemyHoveredPlate = current
end

function BM.RefreshEnemyTargetState()
    if not BM.ShouldUseCustomEnemyPlates or not BM.ShouldUseCustomEnemyPlates() then return end

    BM._ForEachVisibleEnemyPlate(function(plate, unit)
        UpdateEnemyHighlights(plate, unit)
        BM._UpdateTargetGatedAuraCategories(plate, unit)
    end)
end

function BM.RefreshEnemyCombatState()
    if not BM.ShouldUseCustomEnemyPlates or not BM.ShouldUseCustomEnemyPlates() then return end

    BM._ForEachVisibleEnemyPlate(function(plate, unit)
        UpdateAuras(plate, unit)
    end)
end

function BM._PersistEnemyTestPosition(frame)
    if not frame or not UIParent then return end

    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not frameX or not frameY or not parentX or not parentY then return end

    local x = math.floor((frameX - parentX) + 0.5)
    local y = math.floor((frameY - parentY) + 0.5)

    CFG.enemyPlateTestAnchorPoint = "CENTER"
    CFG.enemyPlateTestXOffset = x
    CFG.enemyPlateTestYOffset = y

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)

    -- Persist only the preview position. Test mode itself remains session-only
    -- and is still forced off when the options window closes, combat starts,
    -- the UI reloads, or the player logs out.
    local target = BM.DB and BM.DB.profile or _G.BattleMenderDB
    if type(target) == "table" then
        target.enemyPlateTestAnchorPoint = "CENTER"
        target.enemyPlateTestXOffset = x
        target.enemyPlateTestYOffset = y
        target.enemyPlateTestMode = false
    end
end

function BM._ConfigureEnemyTestDrag(frame, plate)
    if not frame or not plate or not plate.root then return end

    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local root = plate.root

    -- Do not rely on the visual root itself for dragging. StatusBar children can
    -- win mouse hit-testing even when they do not have useful mouse scripts,
    -- leaving the root's OnDragStart unreliable. A dedicated, transparent Button
    -- above every visual child provides one consistent drag surface.
    local handle = plate.testDragHandle
    if not handle then
        handle = CreateFrame("Button", nil, root)
        plate.testDragHandle = handle
        handle:SetAllPoints(root)
        handle:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
        handle:RegisterForDrag("LeftButton")

        handle:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then return end
            if InCombatLockdown and InCombatLockdown() then return end

            frame.BMEnemyTestDragging = true
            frame:StartMoving()
        end)

        local function FinishDrag()
            if not frame.BMEnemyTestDragging then return end
            frame.BMEnemyTestDragging = nil
            frame:StopMovingOrSizing()
            BM._PersistEnemyTestPosition(frame)
        end

        handle:SetScript("OnMouseUp", FinishDrag)
        handle:SetScript("OnDragStop", FinishDrag)
        handle:SetScript("OnHide", FinishDrag)
    end

    handle:ClearAllPoints()
    handle:SetAllPoints(root)
    handle:SetFrameLevel((root:GetFrameLevel() or 50) + 100)
    handle:EnableMouse(true)
    if handle.SetMouseClickEnabled then handle:SetMouseClickEnabled(true) end
    if handle.SetMouseMotionEnabled then handle:SetMouseMotionEnabled(true) end
    handle:Show()
end

function BM.RefreshEnemyPlateTestMode()
    local enabled = CFG.enemyPlateTestMode == true

    if enabled and InCombatLockdown and InCombatLockdown() then
        CFG.enemyPlateTestMode = false
        enabled = false
    end

    local frame = BM.EnemyPlateTestAnchor
    if not enabled then
        if frame then
            frame:StopMovingOrSizing()
            local plate = ENEMY[frame]
            if plate then
                if plate.testDragHandle then
                    plate.testDragHandle:EnableMouse(false)
                    if plate.testDragHandle.SetMouseClickEnabled then plate.testDragHandle:SetMouseClickEnabled(false) end
                    if plate.testDragHandle.SetMouseMotionEnabled then plate.testDragHandle:SetMouseMotionEnabled(false) end
                    plate.testDragHandle:Hide()
                end
                frame.BMEnemyTestDragging = nil
                HideEnemyPlateVisual(plate)
            end
            frame:Hide()
        end
        return
    end

    if not frame then
        frame = CreateFrame("Frame", TEST_ANCHOR_NAME, UIParent)
        frame:SetSize(1, 1)
        frame.unit = TEST_UNIT
        BM.EnemyPlateTestAnchor = frame
    end

    frame.unit = TEST_UNIT
    if not frame.BMEnemyTestDragging then
        frame:ClearAllPoints()
        frame:SetPoint(
            "CENTER",
            UIParent,
            "CENTER",
            tonumber(CFG.enemyPlateTestXOffset) or 0,
            tonumber(CFG.enemyPlateTestYOffset) or 120
        )
    end
    frame:Show()

    local plate = EnsureEnemyPlate(frame)
    plate.unit = TEST_UNIT
    plate.nativeFrame = nil
    ConfigureEnemyCastEvents(plate, nil)

    SetupEnemyLayout(plate, frame, TEST_UNIT)
    UpdateName(plate, TEST_UNIT, frame)
    UpdateHealth(plate, TEST_UNIT, frame)
    UpdateCast(plate, TEST_UNIT)
    UpdateAuras(plate, TEST_UNIT)
    RefreshAuraFlareColorsForPlate(plate, TEST_UNIT)
    UpdatePortrait(plate, TEST_UNIT)
    UpdateEnemyObjectiveFlash(plate, TEST_UNIT)
    BM._ConfigureEnemyTestDrag(frame, plate)
    plate.root:SetAlpha(1)
    plate.root:Show()
end

function BM._InvalidateEnemyPlateOccupant(plate)
    if not plate then return end

    if BM._EnemyHoveredPlate == plate then
        BM._EnemyHoveredPlate = nil
    end

    ConfigureEnemyCastEvents(plate, nil)
    if plate.unit then
        CAST_STATE[plate.unit] = nil
        plate.unitGeneration = (plate.unitGeneration or 0) + 1
    end

    plate.unit = nil
    plate.castNotInterruptible = nil
    plate.castActive = false
    plate.objectiveFlashKey = nil
    plate.healthClassColorResolved = false
    plate.healthClassColorGeneration = nil
    plate.nativeClassColorReadyGeneration = nil

    -- Stop managed containers following a unit token after its nameplate has
    -- been removed. The entries themselves are retained so class-matched flare
    -- containers can be reused later without recreating forbidden AuraButtons.
    HideManagedEnemyAuras(plate)
    HideEnemyPlateVisual(plate)
end

function BM.InvalidateEnemyUnit(unit)
    if not unit then return end

    -- NAME_PLATE_UNIT_REMOVED can arrive after Blizzard has already made
    -- C_NamePlate.GetNamePlateForUnit(unit) unavailable. Walk BattleMender's
    -- own weak plate table so the old occupant is still invalidated by token.
    for _, plate in pairs(ENEMY) do
        if plate and plate.unit == unit then
            BM._InvalidateEnemyPlateOccupant(plate)
        end
    end
end

function BM.ClearEnemyPlate(frame)
    local plate = frame and ENEMY[frame]
    if plate then
        BM._InvalidateEnemyPlateOccupant(plate)
    end
    RestoreNativeEnemy(frame)
end

function BM.ApplyEnemyPlate(frame, nativePlate)
    if not frame then return end

    -- A Blizzard UnitFrame can be recycled directly from a friendly carrier to
    -- an enemy plate. BattleMender's friendly objective badge intentionally
    -- ignores parent alpha, so hiding the native enemy UnitFrame is not enough:
    -- a stale carrier badge can otherwise reappear above the custom enemy bar.
    -- Only hide BattleMender-owned overlay frames here; do not mutate Blizzard
    -- child regions or protected nameplate geometry.
    local recycledUnitFrame = ResolveNativeEnemyUnitFrame(frame)
    if recycledUnitFrame and BM.HideOverlayVisuals then
        BM.HideOverlayVisuals(recycledUnitFrame)
    end

    local unit = BM.ResolvePlateUnit and BM.ResolvePlateUnit(nativePlate, frame)
    if not unit or not SafeUnitExists(unit) then
        BM.ClearEnemyPlate(frame)
        return
    end

    local isFriend = false
    if UnitIsFriend then
        local okFriend, friendResult = pcall(function()
            return UnitIsFriend("player", unit) and true or false
        end)
        isFriend = okFriend and friendResult == true
    end
    if isFriend then
        local isAttackable = BM.IsUnitAttackableByPlayer
            and BM.IsUnitAttackableByPlayer(unit)

        if not isAttackable then
            BM.ClearEnemyPlate(frame)
            return
        end
    end

    if not BM.ShouldUseCustomEnemyPlates or not BM.ShouldUseCustomEnemyPlates() then
        BM.ClearEnemyPlate(frame)
        if BM.ApplyEnemyVisualCompensation then
            BM.ApplyEnemyVisualCompensation(frame, nativePlate)
        end
        return
    end

    HideNativeEnemy(frame)

    local plate = EnsureEnemyPlate(frame, nativePlate)
    if plate.unit ~= unit then
        if plate.unit then
            CAST_STATE[plate.unit] = nil
            plate.unitGeneration = (plate.unitGeneration or 0) + 1
        end
        plate.castNotInterruptible = nil
        plate.objectiveFlashKey = nil
        plate.healthClassColorResolved = false
        plate.healthClassColorGeneration = nil
        plate.nativeClassColorReadyGeneration = nil
        if plate.objectiveFlashAnim then plate.objectiveFlashAnim:Stop() end
        if plate.objectiveFlash then
            plate.objectiveFlash:SetAlpha(0)
            plate.objectiveFlash:Hide()
        end
    end
    plate.unit = unit
    -- RegisterUnitEvent can synchronously deliver the current cast. Record the
    -- native outer frame first so all event-time state refers to this plate.
    plate.nativeFrame = frame
    plate.nativePlate = nativePlate
    plate.anchorFrame = ResolveEnemyPlateParent(frame, nativePlate)
    ConfigureEnemyCastEvents(plate, unit)
    SetupEnemyLayout(plate, frame, unit)
    UpdateName(plate, unit, frame)
    UpdateHealth(plate, unit, frame)
    UpdateCast(plate, unit)
    UpdateAuras(plate, unit)
    RefreshAuraFlareColorsForPlate(plate, unit)
    UpdatePortrait(plate, unit)
    UpdateEnemyObjectiveFlash(plate, unit)

    -- Blizzard may repaint a recycled native nameplate after our first callback.
    -- Defer permission to mirror its class color until the next frame, then
    -- recolor any active BattleMender flare for this exact plate generation.
    if plate.nativeClassColorReadyGeneration ~= (plate.unitGeneration or 0) then
        local colorGeneration = plate.unitGeneration or 0
        C_Timer.After(0, function()
            if plate
                and plate.unit == unit
                and (plate.unitGeneration or 0) == colorGeneration
            then
                plate.nativeClassColorReadyGeneration = colorGeneration
                RefreshAuraFlareColorsForPlate(plate, unit)
            end
        end)
    end

    -- Do not re-touch Blizzard native cast/status/aura widgets after update.
    -- The custom plate is drawn above the outer NamePlate frame instead.

    -- Do not read alpha from Blizzard nameplate frames here. Keep custom enemy
    -- plate opacity independent so this path stays off native frame internals.
    plate.root:SetAlpha(1)
end

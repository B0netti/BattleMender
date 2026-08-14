BattleMender = BattleMender or {}
local CFG = BattleMender.CFG
local BM_OVERLAYS = BattleMender._Overlays

function BattleMender.GetVisualFrame(plate)
    -- Native WoW path. Do not resolve ElvUI's ElvNP_* frame.
    return plate and (plate.UnitFrame or plate)
end

function BattleMender.ResolvePlateUnit(plate, frame)
    return (frame and frame.unit)
        or (plate and plate.UnitFrame and plate.UnitFrame.unit)
end

-------------------------------------------------
-- Clear friendly plate
-------------------------------------------------

local function ClearFriendlyPlate(frame)
    if not frame then return end

    -- AuraContainer displays are keyed to this recycled UnitFrame. Clear them
    -- before any native hit-test or overlay state is reused for another unit.
    if BattleMender.Defensives and BattleMender.Defensives.ClearFrame then
        BattleMender.Defensives.ClearFrame(frame)
    end

    -------------------------------------------------
    -- Clear BattleMender state
    -------------------------------------------------

    local state = BattleMender.GetState and BattleMender.GetState(frame)

    if state then
        state.active = nil
        state.modified = nil
        state.unit = nil
        state.specID = nil
    end

    -------------------------------------------------
    -- Hide and reset BattleMender-owned overlay
    -------------------------------------------------

    local overlay = BM_OVERLAYS and BM_OVERLAYS[frame]

    -- A friendly plate's outer Blizzard NamePlate is rebound to BattleMender's
    -- circular hit-test region while active. Restore its native UnitFrame target
    -- before the frame is recycled for an enemy, NPC, or no-unit plate.
    if BattleMender.RestoreNativeHitTest then
        BattleMender.RestoreNativeHitTest(frame, overlay)
    end

    if overlay then
        overlay.BMLastUnit = nil
        overlay.BMLastVisualScale = nil
        overlay.BMLastLOS = nil
        overlay.BMLOSChangeCount = nil
        overlay.BMIsHovering = nil

        -------------------------------------------------
        -- Frames
        -------------------------------------------------

        if overlay.haloFrame then
            overlay.haloFrame.BMLastParent = nil
            overlay.haloFrame.BMLastPoint = nil
            overlay.haloFrame.BMLastX = nil
            overlay.haloFrame.BMLastY = nil
            overlay.haloFrame:Hide()
        end

        if overlay.damagedFrame then
            overlay.damagedFrame.BMLastParent = nil
            overlay.damagedFrame.BMLastPoint = nil
            overlay.damagedFrame.BMLastX = nil
            overlay.damagedFrame.BMLastY = nil
            overlay.damagedFrame:Hide()
        end

        if overlay.specFrame then
            overlay.specFrame.BMLastParent = nil
            overlay.specFrame.BMLastPoint = nil
            overlay.specFrame.BMLastX = nil
            overlay.specFrame.BMLastY = nil
            overlay.specFrame:Hide()
        end

        if overlay.ringFrame then
            overlay.ringFrame.BMLastParent = nil
            overlay.ringFrame.BMLastSize = nil
            overlay.ringFrame:Hide()
        end

        -------------------------------------------------
        -- BattleMender-owned health overlay
        -------------------------------------------------

        if overlay.healthOverlay then
            overlay.healthOverlay.BMLastParent = nil
            overlay.healthOverlay.BMLastPoint = nil
            overlay.healthOverlay.BMLastX = nil
            overlay.healthOverlay.BMLastY = nil

            overlay.healthOverlay.BMLockedR = nil
            overlay.healthOverlay.BMLockedG = nil
            overlay.healthOverlay.BMLockedB = nil
            overlay.healthOverlay.BMLockedAlpha = nil

            overlay.healthOverlay:Hide()
        end

        if overlay.healthClipFrame then
            overlay.healthClipFrame.BMLastParent = nil
            overlay.healthClipFrame.BMLastPoint = nil
            overlay.healthClipFrame.BMLastX = nil
            overlay.healthClipFrame.BMLastY = nil
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

        -------------------------------------------------
        -- Textures / glows
        -------------------------------------------------

        if overlay.damagedSpecIcon then
            overlay.damagedSpecIcon:Hide()
        end

        if overlay.pulseOverlay then
            overlay.pulseOverlay:Hide()
        end

        if overlay.specIcon then
            overlay.specIcon:Hide()
        end

        if overlay.specGlow then
            overlay.specGlow:Hide()
        end

        if overlay.blackRing then
            overlay.blackRing:Hide()
        end

        if overlay.classRing then
            overlay.classRing:Hide()
        end

        if overlay.ringGlow then
            overlay.ringGlow:Hide()
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

        if overlay.haloGlow then
            overlay.haloGlow:Hide()
        end

        if overlay.hitTestFrame then
            overlay.hitTestFrame:Hide()
            overlay.hitTestFrame.BMLastSize = nil
        end

        if overlay.debugBox then
            overlay.debugBox:Hide()
        end
    end

    -------------------------------------------------
    -- Restore native / Blizzard / ElvUI highlight elements
    -------------------------------------------------

    if BattleMender.RestoreBaseHighlights then
        BattleMender.RestoreBaseHighlights(frame)
    elseif RestoreBaseHighlights then
        RestoreBaseHighlights(frame)
    end
	
	-- Do not re-resolve through BattleMender.GetOverlay here.
	-- Use the overlay already pulled from BM_OVERLAYS above, so recycled
	-- enemy plates cannot keep a stale accent texture alive.
	if BattleMender.HideAccentOverlay then
		BattleMender.HideAccentOverlay(overlay)
	elseif overlay then
		if overlay.accentFrame then
			overlay.accentFrame.BMLastParent = nil
			overlay.accentFrame.BMLastSize = nil
			overlay.accentFrame.BMLastFile = nil
			overlay.accentFrame:Hide()
		end

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
	end
end

BattleMender.ClearFriendlyPlate = ClearFriendlyPlate

-------------------------------------------------
-- Apply friendly plate
-------------------------------------------------

local function ApplyFriendlyPlate(frame, plate)
    if not frame or not plate then return end

    local CFG = BattleMender.CFG
    if not CFG then return end

    local unit = frame.unit or plate.unitToken
    if not unit then
        ClearFriendlyPlate(frame)
        return
    end

    -------------------------------------------------
    -- State
    -------------------------------------------------

    local state = BattleMender.GetState and BattleMender.GetState(frame)

    if state then
        state.active = true
        state.unit = unit
    end

    -------------------------------------------------
    -- Ensure overlay exists
    -------------------------------------------------

    local overlay = BattleMender.EnsureOverlay and BattleMender.EnsureOverlay(frame)
    if not overlay then return end

    -------------------------------------------------
    -- Recycled plate check
    -------------------------------------------------

    if overlay.BMLastUnit ~= unit then
        overlay.BMLastUnit = unit
        overlay.BMLastVisualScale = nil
        overlay.BMLastLOS = nil
        overlay.BMLOSChangeCount = nil
        overlay.BMIsHovering = nil

        -------------------------------------------------
        -- Reset holder frame position caches
        -------------------------------------------------

        if overlay.haloFrame then
            overlay.haloFrame.BMLastParent = nil
            overlay.haloFrame.BMLastPoint = nil
            overlay.haloFrame.BMLastX = nil
            overlay.haloFrame.BMLastY = nil
        end

        if overlay.damagedFrame then
            overlay.damagedFrame.BMLastParent = nil
            overlay.damagedFrame.BMLastPoint = nil
            overlay.damagedFrame.BMLastX = nil
            overlay.damagedFrame.BMLastY = nil
        end

        if overlay.specFrame then
            overlay.specFrame.BMLastParent = nil
            overlay.specFrame.BMLastPoint = nil
            overlay.specFrame.BMLastX = nil
            overlay.specFrame.BMLastY = nil
        end

        if overlay.ringFrame then
            overlay.ringFrame.BMLastParent = nil
            overlay.ringFrame.BMLastSize = nil
        end

        -------------------------------------------------
        -- Reset BattleMender-owned health overlay caches
        -------------------------------------------------

        if overlay.healthOverlay then
            overlay.healthOverlay.BMLastParent = nil
            overlay.healthOverlay.BMLastPoint = nil
            overlay.healthOverlay.BMLastX = nil
            overlay.healthOverlay.BMLastY = nil

            overlay.healthOverlay.BMLockedR = nil
            overlay.healthOverlay.BMLockedG = nil
            overlay.healthOverlay.BMLockedB = nil
            overlay.healthOverlay.BMLockedAlpha = nil
        end

        if overlay.healthClipFrame then
            overlay.healthClipFrame.BMLastParent = nil
            overlay.healthClipFrame.BMLastPoint = nil
            overlay.healthClipFrame.BMLastX = nil
            overlay.healthClipFrame.BMLastY = nil
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

        -------------------------------------------------
        -- Hide recycled textures that will be rebuilt
        -------------------------------------------------

        if overlay.damagedSpecIcon then
            overlay.damagedSpecIcon:Hide()
        end

        if overlay.pulseOverlay then
            overlay.pulseOverlay:Hide()
        end

        if overlay.specIcon then
            overlay.specIcon:Hide()
        end

        if overlay.specGlow then
            overlay.specGlow:Hide()
        end

        if overlay.blackRing then
            overlay.blackRing:Hide()
        end

        if overlay.classRing then
            overlay.classRing:Hide()
        end

        if overlay.ringGlow then
            overlay.ringGlow:Hide()
        end

        if overlay.haloGlow then
            overlay.haloGlow:Hide()
        end
    end

    -------------------------------------------------
    -- Spec state
    -------------------------------------------------

    if BattleMender.GetUnitSpecID then
        local specID = BattleMender.GetUnitSpecID(unit)

        if state then
            state.specID = specID
        end
    end

    -------------------------------------------------
    -- Health
    -------------------------------------------------

    if CFG.healthEnable ~= false then
        if BattleMender.ApplyVerticalBar then
            BattleMender.ApplyVerticalBar(frame, plate)
        end
    else
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

        if state then
            state.modified = nil
        end
    end

    -------------------------------------------------
    -- Overlay
    -------------------------------------------------

    if BattleMender.UpdateOverlay then
        BattleMender.UpdateOverlay(frame, plate)
    end

    if BattleMender.Defensives and BattleMender.Defensives.UpdatePlate then
        BattleMender.Defensives.UpdatePlate(plate)
    end
end

-------------------------------------------------
-- Apply to nameplate
-------------------------------------------------

function BattleMender.ApplyToPlate(plate)
    if not plate then return end

    local frame = plate.UnitFrame or plate
    if not frame then return end

    local unit = BattleMender.ResolvePlateUnit(plate, frame)

    if not unit or not UnitExists(unit) then
        ClearFriendlyPlate(frame)
        if BattleMender.ClearEnemyPlate then
            -- Enemy custom plates are keyed to the outer NamePlate frame in the
            -- taint-safe path. Do not use the inner CompactUnitFrame as the enemy
            -- key; touching that tree makes Blizzard health/cast/aura updates more
            -- likely to run while tainted by BattleMender.
            BattleMender.ClearEnemyPlate(plate)
        end
        return
    end

    local isFriendly =
        BattleMender.CFG.enabled
        and BattleMender.IsFriendlyPlayer(unit)
        and not BattleMender.IsSleeping

    if isFriendly then
        if BattleMender.ClearEnemyPlate then
            BattleMender.ClearEnemyPlate(plate)
        end

        local state = BattleMender.GetState(frame)

        state.unit = unit
        state.specID = BattleMender.GetUnitSpecID(unit)
        state.active = true

        ApplyFriendlyPlate(frame, plate)
        return
    end

    ClearFriendlyPlate(frame)

    if BattleMender.ApplyEnemyPlate then
        -- Pass the outer NamePlate as the primary frame. ApplyEnemyPlate can still
        -- resolve the unit through plate.UnitFrame.unit, but its custom visual tree
        -- no longer keys off or parents to Blizzard's inner CompactUnitFrame.
        BattleMender.ApplyEnemyPlate(plate, plate)
    elseif BattleMender.ApplyEnemyVisualCompensation then
        -- Disabled by default in current builds. Kept only as an old fallback.
        BattleMender.ApplyEnemyVisualCompensation(frame, plate)
    end
end

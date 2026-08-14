BattleMender = BattleMender or {}

local BM = BattleMender
local CFG = BM.CFG or {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local R21_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\r21"
local RIBBON_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\ribbon"
local CRIMP_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\crimp"
local OUTER_GLOW_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\outer_glow.tga"
local CLASS_ICON = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"


local function ResolveSharedMediaStatusbar(key)
    local text = type(key) == "string" and key or nil
    local name = text and string.match(text, "^LSM:(.+)$") or nil
    if not name or name == "" then
        return nil
    end

    local libStub = _G.LibStub
    if not libStub then
        return nil
    end

    local ok, media = pcall(libStub, "LibSharedMedia-3.0", true)
    if not ok or not media or not media.Fetch then
        return nil
    end

    if media.Register then
        pcall(media.Register, media, "statusbar", "BattleMender Flat", WHITE)
        pcall(media.Register, media, "statusbar", "BattleMender Ribbon", RIBBON_TEXTURE)
        pcall(media.Register, media, "statusbar", "BattleMender Crimp", CRIMP_TEXTURE)
    end

    local okFetch, path = pcall(media.Fetch, media, "statusbar", name)
    if okFetch and type(path) == "string" and path ~= "" then
        return path
    end

    return nil
end

BM._EnemyPlates = BM._EnemyPlates or setmetatable({}, { __mode = "k" })
BM._EnemyNativeState = BM._EnemyNativeState or setmetatable({}, { __mode = "k" })
BM._EnemyCastInterruptibility = BM._EnemyCastInterruptibility or {}

local ENEMY = BM._EnemyPlates
local NATIVE = BM._EnemyNativeState
local CAST_INTERRUPTIBILITY = BM._EnemyCastInterruptibility

local TEST_UNIT = "battlemender-test-enemy"
local TEST_ANCHOR_NAME = "BattleMenderEnemyPlateTestAnchor"

local function ResolveEnemyPlateParent(frame, nativePlate)
    -- The synthetic preview must remain parented to its movable anchor. The
    -- normal enemy-plate path deliberately climbs from Blizzard's inner
    -- UnitFrame to the outer NamePlate, but doing that for the preview parents
    -- its visuals directly to UIParent. StartMoving() would then move only the
    -- invisible anchor while the visible preview remained stationary.
    if frame and (frame.unit == TEST_UNIT or frame == BM.EnemyPlateTestAnchor) then
        return frame
    end

    -- Keep BattleMender-owned enemy frames off Blizzard's CompactUnitFrame.
    -- Parent to the outer NamePlate frame where possible; touching the inner
    -- UnitFrame/health/cast/aura tree can taint Blizzard's own update paths.
    if nativePlate then
        return nativePlate
    end

    if frame and frame.namePlateFrame then
        return frame.namePlateFrame
    end

    if frame and type(frame.GetParent) == "function" then
        local ok, parent = pcall(frame.GetParent, frame)
        if ok and parent then
            return parent
        end
    end

    return frame
end

local FALLBACK_AURA_ICONS = {
    BUFF = "Interface\\Icons\\Spell_Holy_PowerWordShield",
    DEBUFF = "Interface\\Icons\\Ability_CheapShot",
    CUSTOM = "Interface\\Icons\\Spell_Nature_InsectSwarm",
}

local TEST_AURA_DATA = {
    BUFF = {
        { name = "Big Defensive", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", applications = 1 },
        { name = "External", icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit", applications = 1 },
        { name = "Raid Buff", icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude", applications = 1 },
    },
    DEBUFF = {
        { name = "Crowd Control", icon = "Interface\\Icons\\Ability_CheapShot", applications = 1 },
        { name = "Personal DoT", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", applications = 2 },
        { name = "Raid Debuff", icon = "Interface\\Icons\\Ability_Rogue_KidneyShot", applications = 1 },
    },
    CUSTOM = {
        { name = "Personal Rot", icon = "Interface\\Icons\\Spell_Nature_InsectSwarm", applications = 1 },
        { name = "Personal Debuff", icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", applications = 3 },
        { name = "Tracked DoT", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", applications = 1 },
    },
}

local function IsTestUnit(unit)
    return unit == TEST_UNIT
end

local function GetFallbackAuraIcon(category, index)
    return FALLBACK_AURA_ICONS[category] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local CLASSIFICATION_COLORS = {
    worldboss = { 0.78, 0.65, 0.00 },
    elite = { 0.82, 0.25, 0.68 },
    rareelite = { 0.08, 0.76, 0.66 },
    rare = { 0.28, 0.78, 0.02 },
    minus = { 0.49, 0.25, 0.78 },
}

local REACTION_COLORS = {
    -- ElvUI-style selection colors. Normal/trivial NPCs use reaction color;
    -- only rare/elite/minus/worldboss use classification color.
    [1] = { 0.82, 0.26, 0.26 }, -- hostile
    [2] = { 0.82, 0.26, 0.26 },
    [3] = { 1.00, 0.50, 0.20 }, -- unfriendly
    [4] = { 0.85098039215686, 0.76078431372549, 0.36078431372549 }, -- neutral #d9c25c
    [5] = { 0.29, 0.69, 0.31 }, -- friendly
    [6] = { 0.29, 0.69, 0.31 },
    [7] = { 0.29, 0.69, 0.31 },
    [8] = { 0.29, 0.69, 0.31 },
}


local SafeText
local SafeBoolFromSecret

local function AuraIsPermanent(aura)
    local ok, permanent = pcall(function()
        return aura and (aura.duration == 0 or aura.expirationTime == 0)
    end)

    return ok and permanent == true
end

local function AuraHasNameplateSignal(aura)
    if not aura then return false end

    return SafeBoolFromSecret(aura.nameplateShowPersonal)
        or SafeBoolFromSecret(aura.nameplateShowAll)
        or SafeBoolFromSecret(aura.isBossAura)
end


local function SafeCall(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return false end
    return pcall(obj[method], obj, ...)
end

local function SafeHide(obj)
    if obj and type(obj.Hide) == "function" then
        pcall(obj.Hide, obj)
    end
end

local function SafeShow(obj)
    if obj and type(obj.Show) == "function" then
        pcall(obj.Show, obj)
    end
end

local function SafeSetText(region, text)
    if not region or type(region.SetText) ~= "function" then return end
    if text == nil then text = "" end
    pcall(region.SetText, region, text)
end

SafeText = function(value)
    -- Do not compare the result of tostring(value). On live nameplate aura
    -- paths, tostring(secret) can itself return a secret string, and comparing
    -- that value taint-errors. Return only plain strings when the call succeeds.
    local ok, text = pcall(function() return tostring(value) end)
    if ok and type(text) == "string" then
        return text
    end
    return nil
end

local function SafeNumber(value)
    local ok, numberValue = pcall(tonumber, value)
    if ok then
        return numberValue
    end
    return nil
end


local function SafeCount(value)
    local numberValue = SafeNumber(value)
    return numberValue or 0
end

SafeBoolFromSecret = function(value)
    -- Secret booleans cannot be tested from an addon-tainted path. Do the
    -- boolean coercion inside pcall; if Blizzard rejects it, treat as false.
    local ok, result = pcall(function()
        return value and true or false
    end)

    return ok and result == true
end

local function SafeUnitIsUnit(unitA, unitB)
    if not unitA or not unitB or type(UnitIsUnit) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return UnitIsUnit(unitA, unitB) and true or false
    end)

    return ok and result == true
end

local function GetEnemyBorderStyle()
    local thickness = tonumber(CFG.enemyPlateBorderWidth)
    if thickness == nil then thickness = 1 end
    if thickness < 0 then thickness = 0 end
    if thickness > 6 then thickness = 6 end

    return thickness,
        tonumber(CFG.enemyPlateBorderR) or 0,
        tonumber(CFG.enemyPlateBorderG) or 0,
        tonumber(CFG.enemyPlateBorderB) or 0,
        tonumber(CFG.enemyPlateBorderA) or 1
end

local function AddBorder(frame, thickness)
    if not frame then return end

    local sharedThickness, r, g, bColor, a = GetEnemyBorderStyle()
    thickness = tonumber(thickness) or sharedThickness
    if thickness < 0 then thickness = 0 end

    frame.BMBorder = frame.BMBorder or {}
    local b = frame.BMBorder

    if not b.top then
        b.top = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        b.bottom = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        b.left = frame:CreateTexture(nil, "OVERLAY", nil, 1)
        b.right = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    end

    if thickness <= 0 or a <= 0 then
        for _, tex in pairs(b) do tex:Hide() end
        return
    end

    for _, tex in pairs(b) do
        tex:SetColorTexture(r, g, bColor, a)
        tex:Show()
    end

    -- These are physical UI units, not a percentage of the element size. A
    -- 1px border therefore remains visually 1px on a 12px health bar and a
    -- 30px aura icon alike (before the plate's inherited/native scale).
    b.top:ClearAllPoints(); b.top:SetPoint("TOPLEFT", frame, "TOPLEFT", -thickness, thickness); b.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", thickness, thickness); b.top:SetHeight(thickness)
    b.bottom:ClearAllPoints(); b.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -thickness, -thickness); b.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", thickness, -thickness); b.bottom:SetHeight(thickness)
    b.left:ClearAllPoints(); b.left:SetPoint("TOPLEFT", frame, "TOPLEFT", -thickness, thickness); b.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -thickness, -thickness); b.left:SetWidth(thickness)
    b.right:ClearAllPoints(); b.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", thickness, thickness); b.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", thickness, -thickness); b.right:SetWidth(thickness)
end

local function SetBorderColor(frame, r, g, b, a)
    local border = frame and frame.BMBorder
    if not border then return end

    for _, tex in pairs(border) do
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
        end
    end
end

local function UpdateCastIconBorder(plate)
    if not plate or not plate.castIcon or not plate.castIconBG then return end

    local thickness, r, g, b, a = GetEnemyBorderStyle()
    plate.castIconBG:ClearAllPoints()

    if thickness <= 0 or a <= 0 then
        plate.castIconBG:Hide()
        return
    end

    plate.castIconBG:SetColorTexture(r, g, b, a)
    plate.castIconBG:SetPoint("TOPLEFT", plate.castIcon, "TOPLEFT", -thickness, thickness)
    plate.castIconBG:SetPoint("BOTTOMRIGHT", plate.castIcon, "BOTTOMRIGHT", thickness, -thickness)

    if plate.castIcon:IsShown() then
        plate.castIconBG:Show()
    end
end

local function IsAddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok then return loaded == true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok then return loaded == true end
    end
    return false
end

local function ElvUIUnitNameplateEnabled(np, key)
    local units = np and np.units
    local unit = units and units[key]

    if type(unit) ~= "table" then
        return false
    end

    -- ElvUI's unit sections have moved between builds/profiles. The visible
    -- checkbox normally writes unit.enable, but some profiles expose unit.enabled
    -- or leave one field stale. Treat the section as an active external enemy
    -- provider only when one of the known enable fields is explicitly true.
    -- This lets BattleMender draw enemy plates when ElvUI's global NamePlates
    -- module is enabled but ENEMY_PLAYER / ENEMY_NPC are individually disabled.
    if unit.enable == true or unit.enabled == true then
        return true
    end

    return false
end

local function IsElvUIEnemyNameplatesActive()
    if not _G.ElvUI then return false end

    local ok, E = pcall(function()
        return unpack(_G.ElvUI)
    end)

    if not ok or not E then return false end

    local privateEnabled = E.private and E.private.nameplates and E.private.nameplates.enable
    local dbNameplates = E.db and E.db.nameplates

    if privateEnabled == false then
        return false
    end

    local enemyPlayerEnabled = ElvUIUnitNameplateEnabled(dbNameplates, "ENEMY_PLAYER")
    local enemyNPCEnabled = ElvUIUnitNameplateEnabled(dbNameplates, "ENEMY_NPC")

    if not enemyPlayerEnabled and not enemyNPCEnabled then
        return false
    end

    if privateEnabled == true then
        return true
    end

    -- If the global private switch is unavailable, treat ElvUI as actively
    -- providing enemy plates only when its nameplate module has built plate data
    -- and at least one enemy unit section is enabled.
    local moduleOK, NP = pcall(function()
        return E.GetModule and E:GetModule("NamePlates", true)
    end)

    return moduleOK and NP and NP.Plates ~= nil
end

local function IsPlaterActive()
    return _G.Plater ~= nil or IsAddonLoaded("Plater") or IsAddonLoaded("Plater_Nameplates")
end

function BM.HasActiveExternalNameplateAddon()
    return IsPlaterActive() or IsElvUIEnemyNameplatesActive()
end

function BM.GetEnemyNameplateProviderStatus()
    local status = {
        plater = IsPlaterActive(),
        elvuiLoaded = _G.ElvUI ~= nil,
        elvuiEnemyActive = false,
        elvuiEnemyPlayer = false,
        elvuiEnemyNPC = false,
    }

    if _G.ElvUI then
        local ok, E = pcall(function() return unpack(_G.ElvUI) end)
        local np = ok and E and E.db and E.db.nameplates
        status.elvuiEnemyPlayer = ElvUIUnitNameplateEnabled(np, "ENEMY_PLAYER")
        status.elvuiEnemyNPC = ElvUIUnitNameplateEnabled(np, "ENEMY_NPC")
        status.elvuiEnemyActive = IsElvUIEnemyNameplatesActive()
    end

    return status
end

function BM.PrintEnemyNameplateProviderStatus()
    local status = BM.GetEnemyNameplateProviderStatus and BM.GetEnemyNameplateProviderStatus()
    if not status then return end

    print("|cff33ff99BattleMender Enemy Provider|r")
    print("BattleMender custom enemy enabled:", CFG.enemyPlatesEnabled == true)
    print("Auto-disable known mods:", CFG.enemyPlatesAutoDisableKnownMods ~= false)
    print("Should use custom enemy plates:", BM.ShouldUseCustomEnemyPlates and BM.ShouldUseCustomEnemyPlates() or false)
    print("CustomEnemyPlatesActive:", BM.CustomEnemyPlatesActive == true)
    print("Plater active:", status.plater == true)
    print("ElvUI loaded:", status.elvuiLoaded == true)
    print("ElvUI enemy provider active:", status.elvuiEnemyActive == true)
    print("ElvUI ENEMY_PLAYER enabled:", status.elvuiEnemyPlayer == true)
    print("ElvUI ENEMY_NPC enabled:", status.elvuiEnemyNPC == true)
end

function BM.ShouldUseCustomEnemyPlates()
    if CFG.enabled == false or CFG.enemyPlatesEnabled == false then
        return false
    end

    if CFG.enemyPlatesAutoDisableKnownMods ~= false and BM.HasActiveExternalNameplateAddon and BM.HasActiveExternalNameplateAddon() then
        return false
    end

    return true
end

local function IsBattlegroundOrArena()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "pvp" or instanceType == "arena")
end

local function UnitLooksLikePlayer(unit, frame)
    if frame and frame.isPlayer == true then return true end

    if UnitIsPlayer then
        local ok, isPlayer = pcall(function()
            return UnitIsPlayer(unit) and true or false
        end)
        if ok and isPlayer == true then return true end
    end

    return false
end

local function ConfigColor(prefix, fallbackR, fallbackG, fallbackB, fallbackA)
    return
        tonumber(CFG[prefix .. "R"]) or fallbackR or 1,
        tonumber(CFG[prefix .. "G"]) or fallbackG or 1,
        tonumber(CFG[prefix .. "B"]) or fallbackB or 1,
        tonumber(CFG[prefix .. "A"]) or fallbackA or 1
end

local function ResolveHealthTextureValue(value, fallback, customValue)
    local text = SafeText(value)
    if not text or text == "" or text == "SAME" then
        return fallback or WHITE
    end

    if text == "CUSTOM" then
        local custom = SafeText(customValue)
        if custom and custom ~= "" and custom ~= "CUSTOM" then
            return ResolveHealthTextureValue(custom, fallback)
        end
        return fallback or WHITE
    end

    local sharedMediaPath = ResolveSharedMediaStatusbar(text)
    if sharedMediaPath then
        return sharedMediaPath
    end

    if text == "FLAT" or text == "WHITE" or text == "DEFAULT" or text == WHITE then
        return WHITE
    elseif text == "R21" or text == "r21" or text == R21_TEXTURE then
        return RIBBON_TEXTURE
    elseif text == "RIBBON" or text == "ribbon" or text == RIBBON_TEXTURE then
        return RIBBON_TEXTURE
    elseif text == "CRIMP" or text == "crimp" or text == CRIMP_TEXTURE then
        return CRIMP_TEXTURE
    end

    return text
end

local function UnitIsTaggedNPC(unit)
    if not unit or UnitLooksLikePlayer(unit) then
        return false
    end

    if UnitIsTapDenied then
        local ok, tapped = pcall(UnitIsTapDenied, unit)
        if ok and tapped == true then
            return true
        end
    end

    if UnitIsTapped and UnitIsTappedByPlayer then
        local ok, tapped, byPlayer = pcall(function()
            return UnitIsTapped(unit), UnitIsTappedByPlayer(unit)
        end)
        if ok and tapped == true and byPlayer ~= true then
            return true
        end
    end

    return false
end

local function GetUnitReactionColor(unit)
    -- Blizzard's compact nameplate coloring treats a neutral NPC as hostile once
    -- the player is on that NPC's threat list. UnitReaction intentionally does
    -- not change just because a neutral mob has entered combat, and selection
    -- APIs can remain neutral for training dummies. Mirror the default behavior
    -- first, then fall back to selection/reaction state below.
    if UnitThreatSituation then
        local okThreat, onThreatList = pcall(function()
            return UnitThreatSituation("player", unit) ~= nil
        end)
        if okThreat and onThreatList then
            return ConfigColor("enemyPlateSelectionHostile", 0.82, 0.26, 0.26, 1)
        end
    end

    -- UnitSelectionType is the same hostility state Blizzard uses for the
    -- selection outline/circle. In particular it changes Neutral -> Hostile when
    -- a neutral NPC is engaged, which UnitReaction/UnitIsEnemy can lag or fail to
    -- expose on modern restricted nameplate tokens. Keep all comparisons inside
    -- pcall so a restricted result simply falls through to the older APIs.
    if UnitSelectionType then
        local okSelection, selectionKey = pcall(function()
            local selectionType = UnitSelectionType(unit, true)
            if selectionType == 0 then return "HOSTILE" end
            if selectionType == 1 then return "UNFRIENDLY" end
            if selectionType == 2 then return "NEUTRAL" end
            if selectionType == 3 or selectionType == 13 then return "FRIENDLY" end
            if selectionType == 9 then return "DEAD" end
            return nil
        end)

        if okSelection then
            if selectionKey == "HOSTILE" then
                return ConfigColor("enemyPlateSelectionHostile", 0.82, 0.26, 0.26, 1)
            elseif selectionKey == "UNFRIENDLY" then
                return ConfigColor("enemyPlateSelectionUnfriendly", 1, 0.50, 0.20, 1)
            elseif selectionKey == "NEUTRAL" then
                return ConfigColor("enemyPlateNeutral", 0.85098039215686, 0.76078431372549, 0.36078431372549, 1)
            elseif selectionKey == "FRIENDLY" then
                return ConfigColor("enemyPlateSelectionFriendly", 0.29, 0.69, 0.31, 1)
            elseif selectionKey == "DEAD" then
                return ConfigColor("enemyPlateSelectionDead", 1, 1, 1, 1)
            end
        end
    end

    -- Fallback for clients/contexts where UnitSelectionType is unavailable.
    if UnitIsEnemy then
        local okEnemy, enemyKey = pcall(function()
            local value = UnitIsEnemy(unit, "player")
            if value == true then return "HOSTILE" end
            value = UnitIsEnemy("player", unit)
            if value == true then return "HOSTILE" end
            return nil
        end)
        if okEnemy and enemyKey == "HOSTILE" then
            return ConfigColor("enemyPlateSelectionHostile", 0.82, 0.26, 0.26, 1)
        end
    end

    local ok, reactionKey = pcall(function()
        local reaction = UnitReaction(unit, "player")
        if not reaction then reaction = UnitReaction("player", unit) end
        if reaction == 4 then return "NEUTRAL", reaction end
        if reaction == 3 then return "UNFRIENDLY", reaction end
        if reaction and reaction <= 2 then return "HOSTILE", reaction end
        if reaction and reaction >= 5 then return "FRIENDLY", reaction end
        return nil, reaction
    end)

    if ok then
        if reactionKey == "NEUTRAL" then
            return ConfigColor("enemyPlateNeutral", 0.85098039215686, 0.76078431372549, 0.36078431372549, 1)
        elseif reactionKey == "UNFRIENDLY" then
            return ConfigColor("enemyPlateSelectionUnfriendly", 1, 0.50, 0.20, 1)
        elseif reactionKey == "HOSTILE" then
            return ConfigColor("enemyPlateSelectionHostile", 0.82, 0.26, 0.26, 1)
        elseif reactionKey == "FRIENDLY" then
            return ConfigColor("enemyPlateSelectionFriendly", 0.29, 0.69, 0.31, 1)
        end
    end

    return nil
end

local function GetUnitClassificationColor(unit)
    if CFG.enemyPlateClassificationColors == false then
        return nil
    end

    local ok, classification = pcall(UnitClassification, unit)
    if not ok or not classification then
        return nil
    end

    -- ElvUI-style behavior: ordinary neutral/normal NPCs should not become flat
    -- white from the classification table. Use classification colors only for
    -- meaningful classifications.
    if classification == "normal" or classification == "trivial" then
        return nil
    end

    if classification == "worldboss" then
        return ConfigColor("enemyPlateClassificationWorldboss", 0.78, 0.65, 0, 1)
    elseif classification == "elite" then
        return ConfigColor("enemyPlateClassificationEliteBoss", 0.82, 0.25, 0.68, 1)
    elseif classification == "rareelite" then
        return ConfigColor("enemyPlateClassificationRareElite", 0.08, 0.76, 0.66, 1)
    elseif classification == "rare" then
        return ConfigColor("enemyPlateClassificationRare", 0.28, 0.78, 0.02, 1)
    elseif classification == "minus" then
        return ConfigColor("enemyPlateClassificationEliteMini", 0.49, 0.25, 0.78, 1)
    end

    local c = CLASSIFICATION_COLORS[classification]
    if c then return c[1], c[2], c[3], c[4] or 1 end

    return nil
end

local function GetSafeHealthRatio(unit)
    if not unit or not UnitHealth or not UnitHealthMax then
        return nil
    end

    local ok, ratio = pcall(function()
        local maxHealth = UnitHealthMax(unit)
        local health = UnitHealth(unit)
        if maxHealth and maxHealth > 0 then
            return health / maxHealth
        end
        return nil
    end)

    if ok and type(ratio) == "number" then
        return ratio
    end

    return nil
end

local function UnitIsCurrentTarget(unit)
    return unit and SafeUnitIsUnit(unit, "target")
end

local function UnitIsCurrentMouseover(unit)
    return unit and SafeUnitIsUnit(unit, "mouseover")
end

local function UnitIsCurrentFocus(unit)
    return unit and SafeUnitIsUnit(unit, "focus")
end

local function ClampNumber(value, fallback, minValue, maxValue)
    local n = tonumber(value) or fallback
    if minValue and n < minValue then n = minValue end
    if maxValue and n > maxValue then n = maxValue end
    return n
end

local function ResolveEnemyPlateScale(unit)
    local base = ClampNumber(CFG.enemyPlateScale, 1, 0.5, 2)

    -- Focus wins over target, matching the texture priority path.
    if UnitIsCurrentFocus(unit) then
        return base * ClampNumber(CFG.enemyPlateFocusScale, 1.15, 0.5, 2)
    end

    if IsTestUnit(unit) or UnitIsCurrentTarget(unit) then
        return base * ClampNumber(CFG.enemyPlateTargetScale, 1, 0.5, 2)
    end

    return base * ClampNumber(CFG.enemyPlateNonTargetScale, 1, 0.5, 2)
end

local function ResolveEnemyHealthTexture(unit)
    local base = ResolveHealthTextureValue(CFG.enemyPlateHealthTexture, WHITE, CFG.enemyPlateHealthTextureCustom)

    -- Focus wins over target so focus-marked targets keep their distinctive bar
    -- texture even if they are also the current target.
    if UnitIsCurrentFocus(unit) then
        return ResolveHealthTextureValue(CFG.enemyPlateFocusHealthTexture, base, CFG.enemyPlateFocusHealthTextureCustom)
    end

    if IsTestUnit(unit) or UnitIsCurrentTarget(unit) then
        return ResolveHealthTextureValue(CFG.enemyPlateTargetHealthTexture, base, CFG.enemyPlateTargetHealthTextureCustom)
    end

    return base
end

local function UseStableHealthClip()
    return CFG.enemyPlateHealthFillMode == "CLIP"
end

local function ApplyEnemyHealthTextureTiling(plate)
    if not plate then return end

    -- Direct StatusBar mode is the reliable live-health path. The experimental
    -- clip renderer keeps the visible art full-width and uses the StatusBar only
    -- as a hidden solver, but some protected nameplate health paths report full
    -- geometry and cannot be trusted on all clients.
    if plate.health and plate.health.GetStatusBarTexture then
        local ok, tex = pcall(plate.health.GetStatusBarTexture, plate.health)
        if ok and tex then
            pcall(tex.SetHorizTile, tex, false)
            pcall(tex.SetVertTile, tex, false)
            pcall(tex.SetTexCoord, tex, 0, 1, 0, 1)
            if UseStableHealthClip() then
                pcall(tex.SetTexture, tex, WHITE)
                pcall(tex.SetVertexColor, tex, 1, 1, 1, 0.001)
                pcall(tex.SetAlpha, tex, 0.001)
            else
                pcall(tex.SetAlpha, tex, 1)
            end
        end
    end

    if plate.healthFillTex then
        pcall(plate.healthFillTex.SetHorizTile, plate.healthFillTex, false)
        pcall(plate.healthFillTex.SetVertTile, plate.healthFillTex, false)
        pcall(plate.healthFillTex.SetTexCoord, plate.healthFillTex, 0, 1, 0, 1)
    end
end

local function GetNativeHealthStatusBarForPlate(plate)
    if not plate then return nil end

    local frame = plate.nativeFrame or plate.nativePlate
    if not frame then return nil end

    -- Do not mutate the Blizzard health bar. This only reads ordinary rendered
    -- geometry from the native fill texture, which is safer than calculating
    -- with UnitHealth/UnitHealthMax secret numbers in addon-tainted execution.
    local unitFrame = frame.UnitFrame or frame.unitFrame
    if not unitFrame and (frame.healthBar or frame.HealthBarsContainer or frame.castBar) then
        unitFrame = frame
    end

    if not unitFrame then return nil end
    return unitFrame.healthBar or unitFrame.HealthBar or unitFrame.health or unitFrame.Health
end

local function GetNativeHealthRatio(plate)
    local ok, ratio = pcall(function()
        local nativeHealth = GetNativeHealthStatusBarForPlate(plate)
        if not nativeHealth or not nativeHealth.GetStatusBarTexture then return nil end

        local nativeFullWidth = nativeHealth:GetWidth()
        if type(nativeFullWidth) ~= "number" or nativeFullWidth <= 0 then return nil end

        local statusTex = nativeHealth:GetStatusBarTexture()
        if not statusTex then return nil end

        local nativeFillWidth
        local left, right = statusTex:GetLeft(), statusTex:GetRight()
        if left and right then
            nativeFillWidth = right - left
        end

        if type(nativeFillWidth) ~= "number" or nativeFillWidth < 0 then
            nativeFillWidth = statusTex:GetWidth()
        end

        if type(nativeFillWidth) ~= "number" then return nil end

        local nextRatio = nativeFillWidth / nativeFullWidth
        if nextRatio ~= nextRatio then return nil end
        if nextRatio < 0 then nextRatio = 0 end
        if nextRatio > 1 then nextRatio = 1 end
        return nextRatio
    end)

    if ok and type(ratio) == "number" then
        return ratio
    end

    return nil
end

local function UpdateEnemyHealthFillClip(plate)
    if not plate or not plate.health then return end

    if not UseStableHealthClip() then
        if plate.healthFillClip then plate.healthFillClip:Hide() end
        if plate.healthFillTex then plate.healthFillTex:Hide() end

        -- Keep a best-effort rendered ratio for low-health highlight logic.
        -- This reads only rendered StatusBar geometry; if the client reports
        -- full width, low-health highlight simply does not override the bar.
        local okRatio, ratio = pcall(function()
            if not plate.health.GetStatusBarTexture then return nil end
            local fullWidth = plate.health:GetWidth()
            if type(fullWidth) ~= "number" or fullWidth <= 0 then return nil end
            local tex = plate.health:GetStatusBarTexture()
            if not tex then return nil end
            local left, right = tex:GetLeft(), tex:GetRight()
            local w = nil
            if left and right then w = right - left end
            if type(w) ~= "number" or w < 0 then w = tex:GetWidth() end
            if type(w) ~= "number" then return nil end
            local nextRatio = w / fullWidth
            if nextRatio ~= nextRatio then return nil end
            if nextRatio < 0 then nextRatio = 0 end
            if nextRatio > 1 then nextRatio = 1 end
            return nextRatio
        end)
        if okRatio and type(ratio) == "number" then
            plate.lastHealthRatio = ratio
        end
        return
    end

    if not plate.healthFillClip or not plate.healthFillTex then return end

    -- The visible bar texture remains full-width and is revealed by a clipping
    -- frame. For live nameplates, avoid calculating with UnitHealth/Max secret
    -- numbers; mirror Blizzard's own rendered native health fill width instead.
    local ok = pcall(function()
        local fullWidth = plate.health:GetWidth() or 1
        local height = plate.health:GetHeight() or 1
        local fillWidth = nil

        local nativeRatio = GetNativeHealthRatio(plate)
        if type(nativeRatio) == "number" then
            fillWidth = fullWidth * nativeRatio
        else
            local ratioOk, ratioWidth = pcall(function()
                local value = plate.health:GetValue()
                local minValue, maxValue = plate.health:GetMinMaxValues()
                if type(value) ~= "number" or type(minValue) ~= "number" or type(maxValue) ~= "number" then
                    return nil
                end

                local denom = maxValue - minValue
                if denom <= 0 then return nil end

                local ratio = (value - minValue) / denom
                if ratio ~= ratio then return nil end
                if ratio < 0 then ratio = 0 end
                if ratio > 1 then ratio = 1 end

                return fullWidth * ratio
            end)

            if ratioOk and type(ratioWidth) == "number" then
                fillWidth = ratioWidth
            end
        end

        if type(fillWidth) ~= "number" then fillWidth = fullWidth end
        if fillWidth < 0 then fillWidth = 0 end
        if fillWidth > fullWidth then fillWidth = fullWidth end

        if fullWidth > 0 then
            plate.lastHealthRatio = fillWidth / fullWidth
        else
            plate.lastHealthRatio = nil
        end

        if plate.healthFillClip.SetClipsChildren then
            plate.healthFillClip:SetClipsChildren(true)
        end

        plate.healthFillClip:ClearAllPoints()
        plate.healthFillClip:SetPoint("LEFT", plate.health, "LEFT", 0, 0)
        plate.healthFillClip:SetSize(fillWidth > 0 and fillWidth or 0.001, height)

        plate.healthFillTex:ClearAllPoints()
        plate.healthFillTex:SetPoint("TOPLEFT", plate.healthFillClip, "TOPLEFT", 0, 0)
        plate.healthFillTex:SetSize(fullWidth, height)

        if fillWidth <= 0 then
            plate.healthFillTex:Hide()
        else
            plate.healthFillTex:Show()
        end
    end)

    if not ok then
        -- Fallback: show the normal StatusBar texture if clipping cannot be
        -- updated on a future client build. This is less visually stable, but
        -- avoids blank health bars.
        if plate.health and plate.health.GetStatusBarTexture then
            local texOk, tex = pcall(plate.health.GetStatusBarTexture, plate.health)
            if texOk and tex then
                pcall(tex.SetAlpha, tex, 1)
            end
        end
    end
end

local function ApplyEnemyHealthTexture(plate, unit)
    if not plate or not plate.health then return end

    local texture = ResolveEnemyHealthTexture(unit)

    if UseStableHealthClip() then
        -- Experimental anti-jiggle renderer: hidden StatusBar fill + clipped
        -- full-width art. Kept as an option, but not the default because some
        -- live nameplate health paths do not expose a usable fill width.
        pcall(plate.health.SetStatusBarTexture, plate.health, WHITE)
        if plate.healthTexturePath ~= texture then
            if plate.healthFillTex then
                local ok = pcall(plate.healthFillTex.SetTexture, plate.healthFillTex, texture)
                if not ok then
                    pcall(plate.healthFillTex.SetTexture, plate.healthFillTex, WHITE)
                    texture = WHITE
                end
            end
            plate.healthTexturePath = texture
        end
    else
        -- Reliable renderer: let StatusBar handle protected/secret health
        -- values internally so the visible fill always tracks damage/healing.
        if plate.healthTexturePath ~= texture or plate.healthFillMode ~= "STATUSBAR" then
            local ok = pcall(plate.health.SetStatusBarTexture, plate.health, texture)
            if not ok then
                pcall(plate.health.SetStatusBarTexture, plate.health, WHITE)
                texture = WHITE
            end
            plate.healthTexturePath = texture
        end
        if plate.healthFillClip then plate.healthFillClip:Hide() end
        if plate.healthFillTex then plate.healthFillTex:Hide() end
    end

    plate.healthFillMode = UseStableHealthClip() and "CLIP" or "STATUSBAR"
    ApplyEnemyHealthTextureTiling(plate)
    UpdateEnemyHealthFillClip(plate)
end

local function ApplyEnemyHealthBackground(plate)
    if not plate or not plate.health or not plate.health.bg then return end

    local r, g, b, a = ConfigColor("enemyPlateHealthBackground", 0, 0, 0, 0.85)
    plate.health.bg:SetColorTexture(r or 0, g or 0, b or 0, a or 0.85)
end

local function NativeEnemyClassColorsEnabled()
    if not GetCVarBool then return false end

    local ok, enabled = pcall(GetCVarBool, "nameplateShowClassColor")
    return ok and enabled == true
end

local function ApplyNativeEnemyClassColor(region, methodName, plate)
    if not region or not plate or not NativeEnemyClassColorsEnabled() then
        return false
    end

    local nativeHealth = GetNativeHealthStatusBarForPlate(plate)
    local method = region[methodName]
    if not nativeHealth or type(nativeHealth.GetStatusBarColor) ~= "function" or type(method) ~= "function" then
        return false
    end

    -- In 12.1, UnitClass can be secret for enemy nameplates. Blizzard has
    -- already resolved the enabled native class color for display, so pass that
    -- rendered color straight into our own region without inspecting it.
    local ok = pcall(function()
        local r, g, b, a = nativeHealth:GetStatusBarColor()
        method(region, r, g, b, a)
    end)

    return ok == true
end

local function ShouldUsePlayerHealthClassColor(unit, frame)
    return UnitLooksLikePlayer(unit, frame)
        and (CFG.enemyPlateClassColorHealth ~= false
            or (CFG.enemyPlateClassColorHealthInPvP ~= false and IsBattlegroundOrArena()))
end

local function GetUnitColor(unit, forHealth, frame)
    if IsTestUnit(unit) then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
        if c then return c.r, c.g, c.b, 1 end
        return 0.96, 0.55, 0.73, 1
    end

    if forHealth and UnitIsDeadOrGhost then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok and dead == true then
            return ConfigColor("enemyPlateSelectionDead", 1, 1, 1, 1)
        end
    end

    if UnitLooksLikePlayer(unit, frame) then
        if forHealth then
            return ConfigColor("enemyPlateSelectionPlayer", 0.34, 0.51, 0.96, 1)
        end
    end

    if forHealth and UnitIsTaggedNPC(unit) then
        return ConfigColor("enemyPlateTaggedNPC", 0.6, 0.6, 0.6, 1)
    end

    if forHealth then
        local r, g, b, a = GetUnitClassificationColor(unit)
        if r then return r, g, b, a end
    end

    local r, g, b, a = GetUnitReactionColor(unit)
    if r then return r, g, b, a end

    return 0.72, 0.12, 0.18, 1
end

local function GetUnitNameColor(unit, frame)
    if IsTestUnit(unit) then
        if CFG.enemyPlateClassColorNames == false then
            return 1, 1, 1
        end
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.PALADIN
        if c then return c.r, c.g, c.b end
        return 0.96, 0.55, 0.73
    end

    return 1, 1, 1
end

local function SetRegionAlpha(region, alpha)
    if region and region.SetAlpha then
        pcall(region.SetAlpha, region, alpha)
    end
end

local function SetTextureAlpha(tex, alpha)
    if tex and tex.SetAlpha then
        pcall(tex.SetAlpha, tex, alpha)
    end
end

local function SetFrameTreeAlpha(region, alpha, depth)
    -- Alpha-only native suppression. Do not Hide(), Show(), reparent, resize, or
    -- re-anchor Blizzard nameplate regions here. Blizzard may later run protected
    -- UpdateAnchors on the same castbar/healthbar and reject protected anchors if
    -- our addon has touched the internal frame tree too aggressively.
    if not region then return end
    depth = depth or 0
    if depth > 3 then return end

    SetRegionAlpha(region, alpha)

    if type(region.GetRegions) == "function" then
        local ok, regions = pcall(function() return { region:GetRegions() } end)
        if ok then
            for _, child in ipairs(regions) do
                SetTextureAlpha(child, alpha)
            end
        end
    end

    if type(region.GetChildren) == "function" then
        local ok, children = pcall(function() return { region:GetChildren() } end)
        if ok then
            for _, child in ipairs(children) do
                SetFrameTreeAlpha(child, alpha, depth + 1)
            end
        end
    end
end

local function HideFrameTree(region)
    SetFrameTreeAlpha(region, 0, 0)
end

local function ShowFrameTree(region)
    SetFrameTreeAlpha(region, 1, 0)
end


local function SetNativeFontStringsAlpha(region, alpha, depth)
    -- Some Blizzard-native name text is not exposed as frame.name/NameText,
    -- especially on NPC plates. Hide FontString regions inside known native
    -- nameplate containers without walking into BattleMender's custom frame.
    if not region then return end
    depth = depth or 0
    if depth > 4 then return end

    if type(region.GetRegions) == "function" then
        local ok, regions = pcall(function() return { region:GetRegions() } end)
        if ok then
            for _, child in ipairs(regions) do
                local objectType
                if child and type(child.GetObjectType) == "function" then
                    local okType, value = pcall(child.GetObjectType, child)
                    if okType then objectType = value end
                end

                if objectType == "FontString" then
                    SetTextureAlpha(child, alpha)
                end
            end
        end
    end

    if type(region.GetChildren) == "function" then
        local ok, children = pcall(function() return { region:GetChildren() } end)
        if ok then
            for _, child in ipairs(children) do
                SetNativeFontStringsAlpha(child, alpha, depth + 1)
            end
        end
    end
end

local function SetNativeNamesAlpha(frame, alpha)
    if not frame then return end

    -- Direct FontString regions on UnitFrame. Do not recurse from the root,
    -- because BattleMender's custom enemy plate is also parented to UnitFrame.
    if type(frame.GetRegions) == "function" then
        local ok, regions = pcall(function() return { frame:GetRegions() } end)
        if ok then
            for _, child in ipairs(regions) do
                local objectType
                if child and type(child.GetObjectType) == "function" then
                    local okType, value = pcall(child.GetObjectType, child)
                    if okType then objectType = value end
                end

                if objectType == "FontString" then
                    SetTextureAlpha(child, alpha)
                end
            end
        end
    end

    -- Known native containers/fields that can contain default name text.
    -- Do not recurse into HealthBarsContainer, WidgetContainer, or CastBar here.
    -- On current clients the Blizzard nameplate castbar owns protected stage
    -- tables; addon-side traversal/alpha changes can taint those tables and
    -- later break Blizzard_CastingBarFrame:StopFinishAnims().
    local containers = {
        frame.name,
        frame.Name,
        frame.nameText,
        frame.NameText,
        frame.unitName,
        frame.UnitName,
        frame.NameFrame,
        frame.nameFrame,
        frame.UnitNameFrame,
        frame.ClassificationFrame,
    }

    for _, region in ipairs(containers) do
        SetNativeFontStringsAlpha(region, alpha, 0)
        SetTextureAlpha(region, alpha)
    end
end

local function HideNativeNames(frame)
    SetNativeNamesAlpha(frame, 0)
end

local function ShowNativeNames(frame)
    SetNativeNamesAlpha(frame, 1)
end

local function HideNativeRegionList(frame, alpha)
    local hide = (alpha or 0) <= 0
    local regions = {
        frame.healthBar,
        frame.HealthBar,
        frame.Health,
        frame.health,
        -- Do not touch Blizzard native castbar frames. Their internal stage
        -- tables can become forbidden while execution is tainted by an addon,
        -- causing Blizzard's own CastingBarFrame:SetUnit path to error.
        frame.name,
        frame.Name,
        frame.nameText,
        frame.NameText,
        frame.unitName,
        frame.UnitName,
        frame.AurasFrame,
        frame.AuraFrame,
        frame.aurasFrame,
        frame.BuffFrame,
        frame.BuffsFrame,
        frame.DebuffFrame,
        frame.DebuffsFrame,
        -- HealthBarsContainer/WidgetContainer can contain or reach the native
        -- castbar. Do not recurse through them for enemy custom plates.
    }

    for _, region in ipairs(regions) do
        if hide then
            HideFrameTree(region)
        else
            ShowFrameTree(region)
        end
    end

    if hide then
        HideNativeNames(frame)
    end

    -- BattleMender draws classification through health color, so the native elite /
    -- rare classification badge should not leak over the custom plate. The BG /
    -- raid-target objective indicator remains independently controllable.
    if hide then
        HideFrameTree(frame.ClassificationFrame)
    else
        ShowFrameTree(frame.ClassificationFrame)
    end

    if CFG.enemyPlateObjectiveIndicator == false then
        if hide then
            HideFrameTree(frame.RaidTargetFrame)
        else
            ShowFrameTree(frame.RaidTargetFrame)
        end
    end
end

local function ResolveNativeEnemyUnitFrame(frame)
    if not frame then return nil end

    -- ApplyEnemyPlate now keys off the outer NamePlate# frame. Blizzard's visible
    -- enemy art is usually on outer.UnitFrame. Use that root frame only; do not
    -- inspect or mutate its health/cast/aura children.
    local unitFrame = frame.UnitFrame or frame.unitFrame
    if unitFrame then return unitFrame end

    -- Backward compatible fallback for older call paths that may still pass the
    -- inner CompactUnitFrame directly.
    if frame.healthBar or frame.castBar or frame.HealthBarsContainer then
        return frame
    end

    return nil
end

local function GetFrameEffectiveScale(frame)
    if not frame or type(frame.GetEffectiveScale) ~= "function" then
        return nil
    end

    local ok, value = pcall(frame.GetEffectiveScale, frame)
    value = ok and tonumber(value) or nil
    if value and value > 0 then
        return value
    end

    return nil
end

local function ResolveNativeEnemyVisualScale(plate, anchorFrame)
    if not plate or IsTestUnit(plate.unit) then
        return 1
    end

    -- Blizzard currently applies distance/selected scaling to the native
    -- UnitFrame more reliably than to the outer NamePlate root. BattleMender's
    -- custom root remains parented to the outer frame for taint safety, so mirror
    -- only the rendered effective-scale ratio instead of parenting to or resizing
    -- the Blizzard child.
    local nativeRoot = plate.nativeFrame or plate.nativePlate
    local nativeUnitFrame = ResolveNativeEnemyUnitFrame(nativeRoot)
    local nativeScale = GetFrameEffectiveScale(nativeUnitFrame)
    local anchorScale = GetFrameEffectiveScale(anchorFrame) or GetFrameEffectiveScale(UIParent) or 1

    if not nativeScale or not anchorScale or anchorScale <= 0 then
        return 1
    end

    return ClampNumber(nativeScale / anchorScale, 1, 0.25, 3)
end

local function RestoreNativeEnemy(frame)
    if not frame then return end

    if NATIVE[frame] then
        local unitFrame = ResolveNativeEnemyUnitFrame(frame)
        if unitFrame and type(unitFrame.SetAlpha) == "function" then
            pcall(unitFrame.SetAlpha, unitFrame, 1)
        end
    end

    NATIVE[frame] = nil
    -- Do not walk or restore Blizzard's native nameplate child tree here.
    -- Prior builds hid native health/cast/aura/classification regions directly,
    -- but that can taint Blizzard's internal CompactUnitFrame, aura, and castbar
    -- update paths on Retail. Restoring only the root alpha keeps this path narrow.
end

local function HideNativeEnemy(frame)
    if not frame then return end
    NATIVE[frame] = NATIVE[frame] or true

    if CFG.enemyPlateHideNativeBlizzard == false then
        RestoreNativeEnemy(frame)
        return
    end

    local unitFrame = ResolveNativeEnemyUnitFrame(frame)
    if unitFrame and type(unitFrame.SetAlpha) == "function" then
        -- Hide the native Blizzard enemy art without walking protected child
        -- tables. This removes the duplicate default plate while avoiding the
        -- earlier taint-prone health/cast/aura traversal.
        pcall(unitFrame.SetAlpha, unitFrame, 0)
    end
end

local function SuppressNativeCast(frame)
    -- Intentionally no-op.
    -- BattleMender draws its custom castbar above the Blizzard nameplate rather
    -- than mutating Blizzard's CastingBarFrame. Mutating or recursively walking
    -- frame.CastBar/StagePoints/StagePips while tainted can produce:
    -- "attempted to iterate a table that cannot be accessed while tainted" in
    -- Blizzard_UIPanels_Game/Mainline/CastingBarFrame.lua:StopFinishAnims().
    return
end

BM.SuppressEnemyNativeCast = SuppressNativeCast

local function CreateStatusBar(parent, layer)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetFrameLevel((parent:GetFrameLevel() or 1) + (layer or 1))

    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.85)
    bar.bg = bg

    AddBorder(bar)
    return bar
end

local function EnsureEnemyPlate(frame, nativePlate)
    local parent = ResolveEnemyPlateParent(frame, nativePlate)
    local existing = ENEMY[frame]
    if existing then
        existing.anchorFrame = parent or frame
        if existing.root and parent and existing.root.GetParent and existing.root:GetParent() ~= parent then
            if not InCombatLockdown or not InCombatLockdown() then
                pcall(existing.root.SetParent, existing.root, parent)
            end
        end
        return existing
    end

    local root = CreateFrame("Frame", nil, parent or frame)
    root:SetFrameStrata("HIGH")
    root:SetFrameLevel(50)
    root:EnableMouse(false)
    if root.SetMouseMotionEnabled then root:SetMouseMotionEnabled(false) end

    local portrait = CreateFrame("Frame", nil, root)
    portrait:EnableMouse(false)
    local portraitTex = portrait:CreateTexture(nil, "ARTWORK")
    portraitTex:SetAllPoints()
    local portraitBG = portrait:CreateTexture(nil, "BACKGROUND")
    portraitBG:SetAllPoints()
    portraitBG:SetColorTexture(0, 0, 0, 0.85)
    AddBorder(portrait)

    local health = CreateStatusBar(root, 2)

    local healthFillClip = CreateFrame("Frame", nil, health)
    healthFillClip:EnableMouse(false)
    if healthFillClip.SetMouseMotionEnabled then healthFillClip:SetMouseMotionEnabled(false) end
    if healthFillClip.SetClipsChildren then healthFillClip:SetClipsChildren(true) end
    healthFillClip:SetPoint("LEFT", health, "LEFT", 0, 0)
    healthFillClip:SetSize(1, 1)
    if healthFillClip.SetFrameLevel then
        healthFillClip:SetFrameLevel((health:GetFrameLevel() or 1) + 1)
    end

    local healthFillTex = healthFillClip:CreateTexture(nil, "ARTWORK", nil, 0)
    healthFillTex:SetTexture(WHITE)
    healthFillTex:SetTexCoord(0, 1, 0, 1)
    healthFillTex:SetVertexColor(1, 1, 1, 1)
    healthFillTex:SetPoint("TOPLEFT", healthFillClip, "TOPLEFT", 0, 0)

    local healthText = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    healthText:SetPoint("RIGHT", health, "RIGHT", -3, 0)
    healthText:SetJustifyH("RIGHT")
    healthText:SetTextColor(1, 1, 1, 1)
    -- Health percentage text is intentionally disabled for the custom enemy plate.
    healthText:SetText("")
    healthText:Hide()

    -- ElvUI-style target / low-health alert layer. This colors the nameplate
    -- background itself, while targetGlow / lowHealthGlow provide the soft
    -- outer background glow.
    local healthAlertBG = health:CreateTexture(nil, "BACKGROUND", nil, 0)
    healthAlertBG:SetAllPoints()
    healthAlertBG:SetBlendMode("ADD")
    healthAlertBG:Hide()

    local targetGlow = root:CreateTexture(nil, "BACKGROUND", nil, -1)
    targetGlow:SetBlendMode("ADD")
    targetGlow:Hide()

    local lowHealthGlow = root:CreateTexture(nil, "BACKGROUND", nil, -2)
    lowHealthGlow:SetBlendMode("ADD")
    lowHealthGlow:Hide()

    local targetOverlay = health:CreateTexture(nil, "OVERLAY", nil, 2)
    targetOverlay:SetAllPoints()
    targetOverlay:Hide()

    local hoverOverlay = health:CreateTexture(nil, "OVERLAY", nil, 3)
    hoverOverlay:SetAllPoints()
    hoverOverlay:Hide()

    -- Keep name text on a dedicated high frame. A FontString parented directly
    -- to the root can be drawn underneath child StatusBars, which makes the name
    -- disappear when it is positioned inside/near the health bar or when plates
    -- are tightly stacked.
    local nameFrame = CreateFrame("Frame", nil, root)
    nameFrame:SetFrameLevel(20)
    nameFrame:EnableMouse(false)
    if nameFrame.SetMouseMotionEnabled then nameFrame:SetMouseMotionEnabled(false) end

    local name = nameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetJustifyH("LEFT")
    name:SetShadowOffset(1, -1)
    -- Enemy names should remain a single line. With a bounded width and wrapping
    -- disabled, Blizzard truncates overflowing FontString text with an ellipsis.
    -- This is also secret-value safe: UnitName can be secret in combat, so we
    -- deliberately let the FontString renderer perform truncation instead of
    -- doing Lua string-length/substr operations on the unit name.
    if name.SetWordWrap then name:SetWordWrap(false) end
    if name.SetNonSpaceWrap then name:SetNonSpaceWrap(false) end
    if name.SetMaxLines then name:SetMaxLines(1) end

    local cast = CreateStatusBar(root, 3)
    if cast.bg then
        cast.bg:SetColorTexture(0, 0, 0, 0)
    end
    local castText = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castText:SetJustifyH("LEFT")
    castText:SetShadowOffset(1, -1)

    local castIcon = root:CreateTexture(nil, "ARTWORK")
    castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local castIconBG = root:CreateTexture(nil, "BACKGROUND")
    castIconBG:SetColorTexture(0, 0, 0, 1)

    local auraFrame = CreateFrame("Frame", nil, root)
    auraFrame:EnableMouse(false)
    if auraFrame.SetMouseMotionEnabled then auraFrame:SetMouseMotionEnabled(false) end

    local auraButtons = {}

    local plate = {
        root = root,
        anchorFrame = parent or frame,
        portrait = portrait,
        portraitTex = portraitTex,
        health = health,
        healthFillClip = healthFillClip,
        healthFillTex = healthFillTex,
        healthText = healthText,
        healthAlertBG = healthAlertBG,
        targetGlow = targetGlow,
        lowHealthGlow = lowHealthGlow,
        targetOverlay = targetOverlay,
        hoverOverlay = hoverOverlay,
        nameFrame = nameFrame,
        name = name,
        cast = cast,
        castText = castText,
        castIcon = castIcon,
        castIconBG = castIconBG,
        -- Legacy aura frame/table retained for older code paths and safe hide.
        auraFrame = auraFrame,
        auraButtons = auraButtons,
        auraFrames = {},
        auraButtonsByCategory = {},
    }

    root:SetScript("OnUpdate", function(_, elapsed)
        if not plate.castActive or not plate.unit then return end
        plate.castElapsed = (plate.castElapsed or 0) + (elapsed or 0)
        local updateRate = tonumber(CFG.enemyPlateCastUpdateRate) or 0.01
        if updateRate < 0 then updateRate = 0 end
        if plate.castElapsed < updateRate then return end
        plate.castElapsed = 0

        if BM.UpdateEnemyCastOnly then
            BM.UpdateEnemyCastOnly(plate, plate.unit)
        end
    end)

    if healthFillClip then
        healthFillClip._bmPlate = plate
        healthFillClip._bmElapsed = 0
        healthFillClip:SetScript("OnUpdate", function(self, elapsed)
            self._bmElapsed = (self._bmElapsed or 0) + (elapsed or 0)
            if self._bmElapsed < 0.03 then return end
            self._bmElapsed = 0
            if self._bmPlate and self._bmPlate.root and self._bmPlate.root:IsShown() then
                UpdateEnemyHealthFillClip(self._bmPlate)
            end
        end)
    end

    ENEMY[frame] = plate
    return plate
end

local function HideEnemyPlateVisual(plate)
    if not plate then return end
    plate.root:Hide()
end

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function SafePoint(value, fallback)
    value = tostring(value or fallback or "CENTER")
    if VALID_POINTS[value] then return value end
    return fallback or "CENTER"
end

local AURA_PREFIX = {
    BUFF = "enemyPlateBuffAura",
    DEBUFF = "enemyPlateDebuffAura",
    CUSTOM = "enemyPlateCustomAura",
}

local function AuraConfig(category, suffix, fallback)
    local prefix = AURA_PREFIX[category]
    local value = prefix and CFG[prefix .. suffix]

    if value == nil and category ~= "CUSTOM" then
        value = CFG["enemyPlateAura" .. suffix]
    end

    if value == nil then
        value = fallback
    end

    return value
end

-- Keep the manual and 12.1 managed aura paths on the same physical footprint.
-- The category frame is an anchor, not a full nameplate-sized canvas: making it
-- match the configured icon grid means its corners remain intuitive anchors.
local function GetAuraLayoutMetrics(category)
    local defaultSize = category == "CUSTOM" and 16 or 30
    local defaultPerRow = 5
    local size = tonumber(AuraConfig(category, "Size", defaultSize)) or defaultSize
    local perRow = tonumber(AuraConfig(category, "PerRow", defaultPerRow)) or defaultPerRow
    local rows = tonumber(AuraConfig(category, "Rows", 1)) or 1
    local spacing = tonumber(AuraConfig(category, "Spacing", 1)) or 1
    if size < 8 then size = 8 end
    if perRow < 1 then perRow = 1 end
    if rows < 1 then rows = 1 end
    if spacing < 0 then spacing = 0 end

    -- 3:4 Tall keeps Size as the height; Custom Flat keeps Size as the width
    -- and reduces its height to form a compact horizontal strip.
    local customFlat = category == "CUSTOM" and CFG.enemyPlateCustomAuraFlat ~= false
    local cropSides = (category == "BUFF" and CFG.enemyPlateBuffAuraCropSides == true)
        or (category == "DEBUFF" and CFG.enemyPlateDebuffAuraCropSides == true)
    local itemHeight = customFlat and math.max(8, math.floor((size * 0.67) + 0.5)) or size
    local itemWidth = cropSides and math.max(6, size * 0.75) or size
    local layoutWidth = (perRow * itemWidth) + ((perRow - 1) * spacing)
    local layoutHeight = (rows * itemHeight) + ((rows - 1) * spacing)

    return size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat, layoutWidth, layoutHeight
end

local function GetAuraAttachFrame(plate, category)
    local attach = AuraConfig(category, "AttachTo", "HEALTH")
    if attach == "CAST" then
        return plate.cast
    elseif attach == "NAME" then
        return plate.name
    elseif attach == "ROOT" then
        return plate.root
    end
    return plate.health
end

local function EnsureAuraCategoryFrame(plate, category)
    plate.auraFrames = plate.auraFrames or {}
    local frame = plate.auraFrames[category]
    if frame then return frame end

    frame = CreateFrame("Frame", nil, plate.root)
    frame:EnableMouse(false)
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(false) end
    plate.auraFrames[category] = frame
    return frame
end

local function SetupAuraCategoryFrame(plate, category)
    local auraFrame = EnsureAuraCategoryFrame(plate, category)
    local auraAnchor = SafePoint(AuraConfig(category, "AnchorPoint", "BOTTOMLEFT"), "BOTTOMLEFT")
    local auraAttach = SafePoint(AuraConfig(category, "AttachPoint", "TOPLEFT"), "TOPLEFT")
    local auraTarget = GetAuraAttachFrame(plate, category)
    auraFrame:ClearAllPoints()
    auraFrame:SetPoint(
        auraAnchor,
        auraTarget,
        auraAttach,
        tonumber(AuraConfig(category, "XOffset", -2)) or -2,
        tonumber(AuraConfig(category, "YOffset", 4)) or 4
    )
    local _, _, _, _, _, _, _, _, layoutWidth, layoutHeight = GetAuraLayoutMetrics(category)
    auraFrame:SetSize(math.max(1, layoutWidth), math.max(1, layoutHeight))
end

local function SetupEnemyLayout(plate, frame, unit)
    local width = ClampNumber(CFG.enemyPlateWidth, 154, 80, 260)
    local healthHeight = ClampNumber(CFG.enemyPlateHealthHeight, 12, 6, 28)
    local castHeight = ClampNumber(CFG.enemyPlateCastHeight, 10, 4, 24)
    local castWidth = CFG.enemyPlateCastMatchHealthWidth ~= false
        and width
        or ClampNumber(CFG.enemyPlateCastWidth, width, 40, 320)
    local castAnchorPoint = SafePoint(CFG.enemyPlateCastAnchorPoint, "TOPLEFT")
    local castAttachPoint = SafePoint(CFG.enemyPlateCastAttachPoint, "BOTTOMLEFT")
    local castX = tonumber(CFG.enemyPlateCastXOffset) or 0
    local castY = tonumber(CFG.enemyPlateCastYOffset) or -3

    local anchorFrame = plate.anchorFrame or ResolveEnemyPlateParent(frame, plate.nativePlate) or frame
    local configuredScale = ResolveEnemyPlateScale(unit)
    local nativeVisualScale = ResolveNativeEnemyVisualScale(plate, anchorFrame)
    local scale = configuredScale * nativeVisualScale

    plate.root:ClearAllPoints()
    plate.root:SetPoint("CENTER", anchorFrame, "CENTER", 0, 0)
    plate.root:SetSize(width, 96)
    plate.root:SetScale(scale)
    plate.root:Show()

    if IsTestUnit(unit) and frame and frame.SetSize then
        frame:SetSize(width * scale, 96 * scale)
    end

    plate.health:ClearAllPoints()
    plate.health:SetPoint("CENTER", plate.root, "CENTER", 0, 0)
    plate.health:SetSize(width, healthHeight)
    AddBorder(plate.health)
    if plate.healthFillClip then
        plate.healthFillClip:SetHeight(healthHeight)
    end
    if plate.healthFillTex then
        plate.healthFillTex:SetSize(width, healthHeight)
    end
    ApplyEnemyHealthTextureTiling(plate)
    UpdateEnemyHealthFillClip(plate)

    if CFG.enemyPlateShowName == false then
        if plate.nameFrame then plate.nameFrame:Hide() end
        plate.name:Hide()
    else
        if plate.nameFrame then
            plate.nameFrame:ClearAllPoints()
            plate.nameFrame:SetAllPoints(plate.root)
            plate.nameFrame:SetFrameLevel((plate.health.GetFrameLevel and plate.health:GetFrameLevel() or 2) + 20)
            plate.nameFrame:Show()
        end
        local namePosition = CFG.enemyPlateNamePosition or "ABOVE"
        local nameX = tonumber(CFG.enemyPlateNameXOffset) or 0
        local nameY = tonumber(CFG.enemyPlateNameYOffset) or 2

        plate.name:Show()
        plate.name:ClearAllPoints()

        if namePosition == "BELOW" then
            plate.name:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", nameX, nameY)
            plate.name:SetPoint("TOPRIGHT", plate.health, "BOTTOMRIGHT", nameX, nameY)
            plate.name:SetJustifyH("LEFT")
        elseif namePosition == "LEFT" then
            plate.name:SetPoint("RIGHT", plate.health, "LEFT", -4 + nameX, nameY)
            plate.name:SetWidth(width)
            plate.name:SetJustifyH("RIGHT")
        elseif namePosition == "RIGHT" then
            plate.name:SetPoint("LEFT", plate.health, "RIGHT", 4 + nameX, nameY)
            plate.name:SetWidth(width)
            plate.name:SetJustifyH("LEFT")
        elseif namePosition == "CENTER" then
            plate.name:SetPoint("CENTER", plate.health, "CENTER", nameX, nameY)
            plate.name:SetWidth(width)
            plate.name:SetJustifyH("CENTER")
        else
            plate.name:SetPoint("BOTTOMLEFT", plate.health, "TOPLEFT", nameX, nameY)
            plate.name:SetPoint("BOTTOMRIGHT", plate.health, "TOPRIGHT", nameX, nameY)
            plate.name:SetJustifyH("LEFT")
        end

        -- Keep the name constrained to one line for every anchor mode. The
        -- existing anchors/SetWidth calls bound it to the health-bar width.
        if plate.name.SetWordWrap then plate.name:SetWordWrap(false) end
        if plate.name.SetNonSpaceWrap then plate.name:SetNonSpaceWrap(false) end
        if plate.name.SetMaxLines then plate.name:SetMaxLines(1) end

        plate.name:SetFontObject("GameFontNormalSmall")
        if plate.name.SetFont then
            local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            plate.name:SetFont(font, tonumber(CFG.enemyPlateNameSize) or 12, "OUTLINE")
        end
    end

    local portraitSize = ClampNumber(CFG.enemyPlatePortraitSize, 36, 16, 72)
    local portraitPosition = CFG.enemyPlatePortraitPosition or "LEFT"
    local portraitX = tonumber(CFG.enemyPlatePortraitXOffset) or 0
    local portraitY = tonumber(CFG.enemyPlatePortraitYOffset) or 0

    plate.portrait:ClearAllPoints()
    if portraitPosition == "RIGHT" then
        plate.portrait:SetPoint("LEFT", plate.health, "RIGHT", 4 + portraitX, portraitY)
    elseif portraitPosition == "TOP" then
        plate.portrait:SetPoint("BOTTOM", plate.health, "TOP", portraitX, 4 + portraitY)
    elseif portraitPosition == "BOTTOM" then
        plate.portrait:SetPoint("TOP", plate.health, "BOTTOM", portraitX, -4 + portraitY)
    else
        plate.portrait:SetPoint("RIGHT", plate.health, "LEFT", -4 + portraitX, portraitY)
    end
    plate.portrait:SetSize(portraitSize, portraitSize)
    AddBorder(plate.portrait)

    local castIconSize = ClampNumber(CFG.enemyPlateCastIconSize, 20, 12, 40)
    local castIconPosition = CFG.enemyPlateCastIconPosition or "RIGHT"
    local castIconX = tonumber(CFG.enemyPlateCastIconXOffset) or 3
    local castIconY = tonumber(CFG.enemyPlateCastIconYOffset) or 0

    plate.cast:ClearAllPoints()
    plate.cast:SetPoint(castAnchorPoint, plate.health, castAttachPoint, castX, castY)
    plate.cast:SetSize(castWidth, castHeight)
    AddBorder(plate.cast)

    plate.castIcon:ClearAllPoints()
    if castIconPosition == "LEFT" then
        plate.castIcon:SetPoint("RIGHT", plate.cast, "LEFT", -castIconX, castIconY)
    elseif castIconPosition == "TOP" then
        plate.castIcon:SetPoint("BOTTOMRIGHT", plate.cast, "TOPRIGHT", castIconX, castIconY)
    elseif castIconPosition == "BOTTOM" then
        plate.castIcon:SetPoint("TOPRIGHT", plate.cast, "BOTTOMRIGHT", castIconX, castIconY)
    else
        plate.castIcon:SetPoint("TOPLEFT", plate.cast, "TOPRIGHT", castIconX, castIconY)
    end
    plate.castIcon:SetSize(castIconSize, castIconSize)
    UpdateCastIconBorder(plate)

    plate.castText:ClearAllPoints()
    plate.castText:SetPoint("TOPLEFT", plate.cast, "BOTTOMLEFT", 0, -1)
    plate.castText:SetPoint("TOPRIGHT", plate.cast, "BOTTOMRIGHT", 0, -1)
    if plate.castText.SetFont then
        local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        plate.castText:SetFont(font, tonumber(CFG.enemyPlateCastTextSize) or 10, "OUTLINE")
    end

    -- Legacy auraFrame is retained but no longer used for the split aura layout.
    plate.auraFrame:ClearAllPoints()
    plate.auraFrame:SetPoint("CENTER", plate.root, "CENTER", 0, 0)
    plate.auraFrame:SetSize(width, 120)
    plate.auraFrame:Hide()

    SetupAuraCategoryFrame(plate, "BUFF")
    SetupAuraCategoryFrame(plate, "DEBUFF")
    SetupAuraCategoryFrame(plate, "CUSTOM")
end

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

    -- Target and low-health are highlighted on the background/glow layers.
    -- Do not replace the bar's actual unit/reaction/class color when targeting.
    if UseStableHealthClip() then
        pcall(plate.health.SetStatusBarColor, plate.health, 1, 1, 1, 0.001)
        if plate.healthFillTex then
            if ShouldUsePlayerHealthClassColor(unit, frame)
                and ApplyNativeEnemyClassColor(plate.healthFillTex, "SetVertexColor", plate)
            then
                return
            end
            pcall(plate.healthFillTex.SetVertexColor, plate.healthFillTex, r or 1, g or 1, b or 1, a or 1)
        end
    else
        if ShouldUsePlayerHealthClassColor(unit, frame)
            and ApplyNativeEnemyClassColor(plate.health, "SetStatusBarColor", plate)
        then
            return
        end
        pcall(plate.health.SetStatusBarColor, plate.health, r or 1, g or 1, b or 1, a or 1)
        if plate.healthFillTex then
            plate.healthFillTex:Hide()
        end
    end
end

local OUTER_GLOW_EXPANSION = 2.0 -- health-bar heights per side

local function SetHealthGlow(plate, glow, r, g, b, a)
    if not plate or not plate.health or not glow then return end

    local healthHeight = plate.health:GetHeight()
    if type(healthHeight) ~= "number" or healthHeight <= 0 then
        healthHeight = tonumber(CFG.enemyPlateHealthHeight) or 10
    end

    -- 2x the health-bar height on EACH side.
    local expansion = healthHeight * OUTER_GLOW_EXPANSION

    glow:ClearAllPoints()
    glow:SetPoint(
        "TOPLEFT",
        plate.health,
        "TOPLEFT",
        -expansion,
        expansion
    )
    glow:SetPoint(
        "BOTTOMRIGHT",
        plate.health,
        "BOTTOMRIGHT",
        expansion,
        -expansion
    )

    glow:SetTexture(OUTER_GLOW_TEXTURE)
    glow:SetHorizTile(false)
    glow:SetVertTile(false)
    glow:SetTexCoord(0, 1, 0, 1)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(r or 1, g or 1, b or 1, a or 0.72)
    glow:Show()
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
        plate.targetGlow:Hide()
    end
    if plate.lowHealthGlow then
        plate.lowHealthGlow:Hide()
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
        and ApplyNativeEnemyClassColor(plate.name, "SetTextColor", plate)
    then
        return
    end
    plate.name:SetTextColor(1, 1, 1)
end

local function GetCastInfo(unit)
    if IsTestUnit(unit) then
        local now = (GetTime and GetTime() or 0) * 1000
        local cycle = 2400
        local startMS = now - (now % cycle)
        local endMS = startMS + cycle
        return "BattleMender Test Cast", "Interface\\Icons\\Spell_Fire_Fireball02", startMS, endMS, false, false, nil
    end

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

local function HideCustomCast(plate)
    plate.castActive = false
    plate.castElapsed = 0
    pcall(plate.cast.SetValue, plate.cast, 0)
    pcall(plate.castText.SetText, plate.castText, "")
    pcall(plate.castIcon.SetTexture, plate.castIcon, nil)

    plate.cast:Hide(); plate.castText:Hide(); plate.castIcon:Hide(); plate.castIconBG:Hide()

    if BM.SuppressEnemyNativeCast and plate.nativeFrame then
        BM.SuppressEnemyNativeCast(plate.nativeFrame)
    end
end

-- The UnitCastingInfo/UnitChannelInfo notInterruptible return can be protected
-- on modern nameplate paths. Spellcast interruptibility events are ordinary
-- event state, so cache them by unit token and let that state override every
-- other cast color (including Targeting You).
function BM.HandleEnemyCastEvent(event, unit)
    if not unit then return end

    if event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        CAST_INTERRUPTIBILITY[unit] = 1
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        CAST_INTERRUPTIBILITY[unit] = 0
    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
    then
        -- New cast/channel: discard state from the previous spell. The API value
        -- is used until an explicit interruptibility event arrives.
        CAST_INTERRUPTIBILITY[unit] = nil
    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    then
        CAST_INTERRUPTIBILITY[unit] = nil
    end
end

local function SafeBooleanTrue(value)
    local ok, result = pcall(function()
        return value == true
    end)
    return ok and result == true
end

local function SafeUnitIsUnit(unitA, unitB)
    if not unitA or not unitB or not UnitIsUnit then
        return false
    end

    -- UnitIsUnit can return a secret boolean on nameplate-target paths. Do not
    -- compare or branch on that result outside pcall; if Blizzard blocks the
    -- comparison, treat it as false rather than hard-erroring the renderer.
    local ok, result = pcall(function()
        return UnitIsUnit(unitA, unitB) and true or false
    end)

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

local function CastIsNotInterruptible(unit, apiValue)
    local cached = unit and CAST_INTERRUPTIBILITY[unit]
    if cached == 1 then
        return true
    elseif cached == 0 then
        return false
    end

    return SafeBooleanTrue(apiValue)
end

local function GetEnemyCastColor(unit, notInterruptible)
    -- Uninterruptible is the strongest cast state and must always retain its
    -- configured warning color, including when the cast is targeting the player.
    if CastIsNotInterruptible(unit, notInterruptible) then
        return
            tonumber(CFG.enemyPlateCastNotInterruptibleR) or 0.45,
            tonumber(CFG.enemyPlateCastNotInterruptibleG) or 0.45,
            tonumber(CFG.enemyPlateCastNotInterruptibleB) or 0.45
    end

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

function BM.UpdateEnemyCastOnly(plate, unit)
    if not plate or not unit or CFG.enemyPlateShowCastbar == false then
        if plate then HideCustomCast(plate) end
        return
    end

    local name, texture, startMS, endMS, notInterruptible, isChannel = GetCastInfo(unit)
    if name == nil or startMS == nil or endMS == nil then
        HideCustomCast(plate)
        return
    end

    local now = GetTime() * 1000
    plate.castActive = true
    plate.cast:Show(); plate.castText:Show(); plate.castIcon:Show()
    UpdateCastIconBorder(plate)
    pcall(plate.cast.SetMinMaxValues, plate.cast, startMS, endMS)

    -- Normal casts fill from left to right. Channels show remaining time, but
    -- keep the colored portion anchored to the right so the empty portion grows
    -- from left to right. This makes a channel visibly drain rather than look
    -- like an ordinary cast filling backwards.
    local progressApplied
    if isChannel == true then
        progressApplied = pcall(function()
            if plate.cast.SetReverseFill then
                plate.cast:SetReverseFill(true)
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
            pcall(plate.cast.SetReverseFill, plate.cast, isChannel == true)
        end
    end

    local cr, cg, cb = GetEnemyCastColor(unit, notInterruptible)
    plate.cast:SetStatusBarColor(cr, cg, cb, 1)

    pcall(plate.castText.SetText, plate.castText, name)
    if texture ~= nil then
        pcall(plate.castIcon.SetTexture, plate.castIcon, texture)
    else
        plate.castIcon:SetTexture(nil)
    end

    if BM.SuppressEnemyNativeCast and plate.nativeFrame then
        BM.SuppressEnemyNativeCast(plate.nativeFrame)
    end
end

local function UpdateCast(plate, unit)
    BM.UpdateEnemyCastOnly(plate, unit)
end

local function GetAuraByIndex(unit, index, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and aura then return aura end
        return nil
    end

    if UnitAura then
        local name, icon, count, dispelType, duration, expirationTime, sourceUnit, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll = UnitAura(unit, index, filter)
        if name then
            return {
                name = name,
                icon = icon,
                applications = count,
                duration = duration,
                expirationTime = expirationTime,
                sourceUnit = sourceUnit,
                spellId = spellId,
                isBossAura = isBossDebuff,
                nameplateShowAll = nameplateShowAll,
                castByPlayer = castByPlayer,
            }
        end
    end

    return nil
end

-- This is an out-of-combat compatibility enumerator. In 12.1, neither indexed
-- AuraData APIs nor the vector returned by GetUnitAuras may be iterated while
-- aura information is secret; the combat display uses AuraContainer below.
local function VisitAuras(unit, filter, visitor)
    if C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function" then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, filter, 40)
        if ok and auras then
            local iterated = pcall(function()
                for _, aura in ipairs(auras) do
                    visitor(aura)
                end
            end)
            if iterated then
                return true
            end
        end
    end

    -- Older clients retain the indexed fallback. It is deliberately not relied
    -- on by the current 12.1 display path.
    for index = 1, 40 do
        local aura = GetAuraByIndex(unit, index, filter)
        if not aura then break end
        visitor(aura)
    end
    return false
end

local function CFGToggle(key, defaultValue)
    local value = CFG[key]
    if value == nil then
        return defaultValue == true
    end
    return value == true
end

local function ModeIsPlayerScoped(mode)
    if mode == "PERSONAL" then
        return true
    end

    -- `!PLAYER` explicitly means an aura from someone else; do not let the
    -- substring itself select the Player permanent-aura option.
    return type(mode) == "string"
        and mode:find("!PLAYER", 1, true) == nil
        and mode:find("PLAYER", 1, true) ~= nil
end

local function ShouldBlockPermanentAura(aura, mode, baseFilter, useCustomFilters)
    if not AuraIsPermanent(aura) then
        return false
    end

    if baseFilter == "HELPFUL" then
        if ModeIsPlayerScoped(mode) then
            if useCustomFilters then
                return CFG.enemyPlateCustomBuffPlayerBlockPermanent == true
            end
            return CFG.enemyPlateBuffPlayerBlockPermanent == true
        end

        if useCustomFilters then
            return CFG.enemyPlateCustomBuffOthersBlockPermanent == true
        end
        return CFG.enemyPlateBuffOthersBlockPermanent == true
    end

    if ModeIsPlayerScoped(mode) then
        if useCustomFilters then
            return CFG.enemyPlateCustomDebuffPlayerBlockPermanent == true
        end
        return CFG.enemyPlateDebuffPlayerBlockPermanent == true
    end

    if useCustomFilters then
        return CFG.enemyPlateCustomDebuffOthersBlockPermanent == true
    end
    return CFG.enemyPlateDebuffOthersBlockPermanent == true
end

local function IsBlizzardAuraFilterMode(mode, baseFilter)
    if type(mode) ~= "string" or type(baseFilter) ~= "string" then
        return false
    end

    return mode == baseFilter or mode:find("^" .. baseFilter .. "|", 1, false) == 1
end

local function ResolveAuraMode(baseFilter)
    if baseFilter == "HARMFUL" then
        local mode = CFG.enemyPlateAuraDebuffFilter
        if mode == "HARMFUL|NOT_CANCELABLE" then
            mode = "HARMFUL|!CANCELABLE"
        end
        if not mode then
            mode = CFG.enemyPlatePersonalDebuffsOnly ~= false and "PERSONAL" or "ALL"
        end
        return mode
    end

    if baseFilter == "HELPFUL" then
        local mode = CFG.enemyPlateAuraBuffFilter
        if mode == "HELPFUL|NOT_CANCELABLE" then
            mode = "HELPFUL|!CANCELABLE"
        end
        if not mode then
            mode = CFG.enemyPlateSelfBuffsOnly ~= false and "SELF" or "ALL"
        end
        return mode
    end

    return "ALL"
end

local function AddAuraMode(out, mode)
    if not mode or mode == "" then
        return
    end

    -- Several visible category controls can resolve to the same native filter.
    -- Do not enumerate it twice: aura instance IDs may be restricted on live
    -- nameplates, where duplicate detection must deliberately fail open.
    for _, existingMode in ipairs(out) do
        if existingMode == mode then
            return
        end
    end

    out[#out + 1] = mode
end

local function ResolveAuraModes(baseFilter)
    local modes = {}

    if baseFilter == "HELPFUL" then
        -- Buffs mirror the ElvUI-style category layout, but only expose helpful
        -- aura categories. Defensive categories live here, not in Debuffs.
        if CFGToggle("enemyPlateBuffUsePlayer", CFG.enemyPlateSelfBuffsOnly ~= false) then
            AddAuraMode(modes, "HELPFUL|PLAYER")
        end

        if CFG.enemyPlateBuffUseRaidDispellable == true then
            AddAuraMode(modes, "HELPFUL|RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffUseDispellable == true then
            AddAuraMode(modes, "HELPFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffUseImportant == true then
            AddAuraMode(modes, "HELPFUL|IMPORTANT|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffUseRaidInCombat == true then
            AddAuraMode(modes, "HELPFUL|RAID_IN_COMBAT|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffPlayerRaid == true then
            AddAuraMode(modes, "HELPFUL|PLAYER|RAID")
        end

        if CFG.enemyPlateBuffPlayerCancelable == true then
            AddAuraMode(modes, "HELPFUL|PLAYER|CANCELABLE")
        end

        if CFG.enemyPlateBuffPlayerNotCancelable == true then
            AddAuraMode(modes, "HELPFUL|PLAYER|!CANCELABLE")
        end

        if CFG.enemyPlateBuffPlayerBigDefensive == true then
            -- WoW 12.x exposes defensive categories directly. Use Blizzard's
            -- native classification instead of reading aura spellId/name,
            -- which can be secret on live enemy nameplates.
            AddAuraMode(modes, "HELPFUL|PLAYER|BIG_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffPlayerExternalDefensive == true then
            AddAuraMode(modes, "HELPFUL|PLAYER|EXTERNAL_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffOthersRaid == true then
            AddAuraMode(modes, "HELPFUL|RAID")
        end

        if CFG.enemyPlateBuffOthersCancelable == true then
            AddAuraMode(modes, "HELPFUL|CANCELABLE")
        end

        if CFG.enemyPlateBuffOthersNotCancelable == true then
            AddAuraMode(modes, "HELPFUL|!CANCELABLE")
        end

        if CFG.enemyPlateBuffOthersBigDefensive == true then
            AddAuraMode(modes, "HELPFUL|!PLAYER|BIG_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY")
        end

        if CFG.enemyPlateBuffOthersExternalDefensive == true then
            AddAuraMode(modes, "HELPFUL|!PLAYER|EXTERNAL_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY")
        end

        -- The display switch is the master control. With no category selected,
        -- preserve the broad useful default and show helpful auras; checking a
        -- category turns the selection into the requested narrower union.
        if #modes == 0 then
            AddAuraMode(modes, "HELPFUL")
        end
        return modes
    end

    if baseFilter ~= "HARMFUL" then
        return { ResolveAuraMode(baseFilter) }
    end

    if CFGToggle("enemyPlateDebuffUsePlayer", CFG.enemyPlateDebuffUsePersonal ~= false) then
        AddAuraMode(modes, "HARMFUL|PLAYER")
    end

    if CFG.enemyPlateDebuffUseRaidDispellable == true then
        AddAuraMode(modes, "HARMFUL|RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY")
    end

    if CFG.enemyPlateDebuffUseDispellable == true then
        AddAuraMode(modes, "HARMFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY")
    end

    -- Debuffs only expose harmful categories. Big Defensive / External
    -- Defensive are intentionally not part of this UI path.
    if CFG.enemyPlateDebuffPlayerRaid == true then
        AddAuraMode(modes, "HARMFUL|PLAYER|RAID")
    end

    if CFG.enemyPlateDebuffPlayerCrowdControl == true then
        -- WoW 12.x native CC classification. PLAYER includes player, pet and
        -- vehicle auras; INCLUDE_NAME_PLATE_ONLY also includes CC Blizzard
        -- exposes specifically to nameplate consumers.
        AddAuraMode(modes, "HARMFUL|PLAYER|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY")
    end

    if CFG.enemyPlateDebuffOthersRaid == true then
        AddAuraMode(modes, "HARMFUL|RAID")
    end

    if CFG.enemyPlateDebuffOthersCrowdControl == true then
        -- Ask Blizzard for non-player CC directly instead of inspecting
        -- sourceUnit/spellId, both of which can be restricted on nameplates.
        AddAuraMode(modes, "HARMFUL|!PLAYER|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY")
    end

    -- See the helpful-aura branch above: no checked category means all harmful
    -- auras, while any checked category becomes the explicit filter union.
    if #modes == 0 then
        AddAuraMode(modes, "HARMFUL")
    end
    return modes
end

local function ResolveCustomAuraModes(baseFilter)
    local modes = {}

    if baseFilter == "HELPFUL" then
        if CFG.enemyPlateCustomBuffUsePlayer == true then AddAuraMode(modes, "HELPFUL|PLAYER") end
        if CFG.enemyPlateCustomBuffUseRaidDispellable == true then AddAuraMode(modes, "HELPFUL|RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffUseDispellable == true then AddAuraMode(modes, "HELPFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffUseImportant == true then AddAuraMode(modes, "HELPFUL|IMPORTANT|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffUseRaidInCombat == true then AddAuraMode(modes, "HELPFUL|RAID_IN_COMBAT|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffPlayerRaid == true then AddAuraMode(modes, "HELPFUL|PLAYER|RAID") end
        if CFG.enemyPlateCustomBuffPlayerCancelable == true then AddAuraMode(modes, "HELPFUL|PLAYER|CANCELABLE") end
        if CFG.enemyPlateCustomBuffPlayerNotCancelable == true then AddAuraMode(modes, "HELPFUL|PLAYER|!CANCELABLE") end
        if CFG.enemyPlateCustomBuffPlayerBigDefensive == true then AddAuraMode(modes, "HELPFUL|PLAYER|BIG_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffPlayerExternalDefensive == true then AddAuraMode(modes, "HELPFUL|PLAYER|EXTERNAL_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffOthersRaid == true then AddAuraMode(modes, "HELPFUL|RAID") end
        if CFG.enemyPlateCustomBuffOthersCancelable == true then AddAuraMode(modes, "HELPFUL|CANCELABLE") end
        if CFG.enemyPlateCustomBuffOthersNotCancelable == true then AddAuraMode(modes, "HELPFUL|!CANCELABLE") end
        if CFG.enemyPlateCustomBuffOthersBigDefensive == true then AddAuraMode(modes, "HELPFUL|!PLAYER|BIG_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomBuffOthersExternalDefensive == true then AddAuraMode(modes, "HELPFUL|!PLAYER|EXTERNAL_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY") end
    elseif baseFilter == "HARMFUL" then
        if CFG.enemyPlateCustomDebuffUsePlayer == true then AddAuraMode(modes, "HARMFUL|PLAYER") end
        if CFG.enemyPlateCustomDebuffUseRaidDispellable == true then AddAuraMode(modes, "HARMFUL|RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomDebuffUseDispellable == true then AddAuraMode(modes, "HARMFUL|DISPELLABLE|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomDebuffPlayerRaid == true then AddAuraMode(modes, "HARMFUL|PLAYER|RAID") end
        if CFG.enemyPlateCustomDebuffPlayerCrowdControl == true then AddAuraMode(modes, "HARMFUL|PLAYER|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY") end
        if CFG.enemyPlateCustomDebuffOthersRaid == true then AddAuraMode(modes, "HARMFUL|RAID") end
        if CFG.enemyPlateCustomDebuffOthersCrowdControl == true then AddAuraMode(modes, "HARMFUL|!PLAYER|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY") end
    end

    -- Custom's Buff/Debuff master switches use the same fallback as the
    -- dedicated groups: an enabled type with no narrow category selected is
    -- an all-helpful or all-harmful display.
    if #modes == 0 and (baseFilter == "HELPFUL" or baseFilter == "HARMFUL") then
        AddAuraMode(modes, baseFilter)
    end
    return modes
end

local function GetAuraCollectionFilter(baseFilter, mode)
    -- BattleMender's custom categories inspect the normal HELPFUL/HARMFUL list
    -- and then apply their selected native filter. Explicit Blizzard categories
    -- are passed directly to C_UnitAuras/UnitAura.
    if IsBlizzardAuraFilterMode(mode, baseFilter) then
        return mode
    end

    return baseFilter
end

local function AuraAllowed(aura, baseFilter, unit, mode, ignoreGroupEnabled, useCustomFilters)
    if not aura then return false end

    if ShouldBlockPermanentAura(aura, mode, baseFilter, useCustomFilters) then
        return false
    end

    -- If the user picked a built-in Blizzard filter category such as
    -- HELPFUL|RAID or HARMFUL|INCLUDE_NAME_PLATE_ONLY, trust Blizzard's own
    -- filter result and avoid extra BattleMender source/nameplate checks.
    if IsBlizzardAuraFilterMode(mode, baseFilter) then
        return true
    end

    local hasNameplateSignal = AuraHasNameplateSignal(aura)

    if baseFilter == "HARMFUL" then
        if not ignoreGroupEnabled and CFG.enemyPlateShowDebuffs == false then
            return false
        end

        if mode == "ALL" then
            return true
        elseif mode == "NAMEPLATE" then
            return hasNameplateSignal or SafeUnitIsUnit(aura.sourceUnit, "player")
        end

        return SafeUnitIsUnit(aura.sourceUnit, "player")
    end

    if baseFilter == "HELPFUL" then
        if not ignoreGroupEnabled and CFG.enemyPlateShowBuffs == false then
            return false
        end

        if mode == "ALL" then
            return true
        elseif mode == "NAMEPLATE" then
            return hasNameplateSignal
        end

        -- SELF means buffs cast by / owned by the unit whose nameplate this is.
        return SafeUnitIsUnit(aura.sourceUnit, unit or aura.sourceUnit)
    end

    return false
end

local function MarkAuraSeen(seen, aura)
    if not seen or not aura then
        return true
    end

    -- auraInstanceID is usually safe and is the best de-dupe key when the same
    -- aura is returned through multiple checked Blizzard filters. Keep the table
    -- indexing inside pcall so secret-key paths never hard-error.
    local ok, isNew = pcall(function()
        local key = aura.auraInstanceID
        if key == nil then
            return true
        end

        if seen[key] then
            return false
        end

        seen[key] = true
        return true
    end)

    if ok then
        return isNew ~= false
    end

    return true
end

local function CollectAuraCategory(unit, category)
    if IsTestUnit(unit) then
        return TEST_AURA_DATA[category] or {}
    end

    local auras = {}
    local seen = {}

    local function collect(baseFilter)
        local modes = ResolveAuraModes(baseFilter)

        for _, mode in ipairs(modes) do
            local filter = GetAuraCollectionFilter(baseFilter, mode)

            VisitAuras(unit, filter, function(aura)
                if AuraAllowed(aura, baseFilter, unit, mode) and MarkAuraSeen(seen, aura) then
                    -- AuraData belongs to Blizzard. In 12.1 it can contain
                    -- restricted values, so never attach addon bookkeeping to
                    -- that table; the renderer only needs the opaque value.
                    auras[#auras + 1] = aura
                end
            end)
        end
    end

    local function collectCustomModes(baseFilter)
        local modes = ResolveCustomAuraModes(baseFilter)
        for _, mode in ipairs(modes) do
            local filter = GetAuraCollectionFilter(baseFilter, mode)

            VisitAuras(unit, filter, function(aura)
                if AuraAllowed(aura, baseFilter, unit, mode, true, true) and MarkAuraSeen(seen, aura) then
                    auras[#auras + 1] = aura
                end
            end)
        end
    end

    if category == "BUFF" then
        collect("HELPFUL")
    elseif category == "DEBUFF" then
        collect("HARMFUL")
    elseif category == "CUSTOM" then
        -- Custom is a third independent aura container for selected native
        -- helpful and harmful categories.
        if CFG.enemyPlateCustomShowBuffs == true then
            collectCustomModes("HELPFUL")
        end
        if CFG.enemyPlateCustomShowDebuffs == true then
            collectCustomModes("HARMFUL")
        end
    end

    -- Do not sort by expiration time. expirationTime can be a secret number and
    -- comparing it from addon code can taint-error on live. Blizzard already
    -- returns a stable nameplate-relevant order.
    return auras
end

function BM.PrintNativeCrowdControlStatus()
    local unit
    if UnitExists and UnitExists("target") then
        unit = "target"
    elseif UnitExists and UnitExists("mouseover") then
        unit = "mouseover"
    end

    print("|cff33ff99BattleMender:|r native crowd-control status")
    print("  test unit:", tostring(unit or "none (target or mouse over a unit)"))
    print("  GetUnitAuras:", tostring(C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function"))
    if not unit then return end

    local filters = {
        "HARMFUL|PLAYER|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY",
        "HARMFUL|!PLAYER|CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY",
    }

    for _, filter in ipairs(filters) do
        local count = 0
        print("  filter:", filter)
        VisitAuras(unit, filter, function(aura)
            count = count + 1
            print("    ", tostring(count), SafeText(aura.name, "<restricted aura>"))
        end)
        if count == 0 then
            print("     (no matching auras)")
        end
    end
end

local function EnsureAuraButton(plate, category, index)
    plate.auraFrames = plate.auraFrames or {}
    plate.auraButtonsByCategory = plate.auraButtonsByCategory or {}

    local frame = EnsureAuraCategoryFrame(plate, category)
    local buttons = plate.auraButtonsByCategory[category]
    if not buttons then
        buttons = {}
        plate.auraButtonsByCategory[category] = buttons
    end

    local btn = buttons[index]
    if btn then return btn end

    btn = CreateFrame("Frame", nil, frame)
    btn:EnableMouse(false)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local count = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    count:SetShadowOffset(1, -1)
    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints()
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    if cd.SetUseAuraDisplayTime then cd:SetUseAuraDisplayTime(true) end
    AddBorder(btn)

    btn.icon = icon
    btn.count = count
    btn.cd = cd
    buttons[index] = btn
    return btn
end

local function HideAuraCategory(plate, category)
    if not plate then return end

    local frame = plate.auraFrames and plate.auraFrames[category]
    if frame then frame:Hide() end

    local buttons = plate.auraButtonsByCategory and plate.auraButtonsByCategory[category]
    if buttons then
        for _, btn in ipairs(buttons) do
            btn:Hide()
        end
    end
end

local function UpdateAuraCategory(plate, unit, category, enabled)
    if enabled == false then
        HideAuraCategory(plate, category)
        return
    end

    local auraFrame = EnsureAuraCategoryFrame(plate, category)
    auraFrame:Show()

    local size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat = GetAuraLayoutMetrics(category)
    local colStep = itemWidth + spacing
    local rowStep = itemHeight + spacing

    local maxAuras = perRow * rows
    local auras = CollectAuraCategory(unit, category)
    local growX = AuraConfig(category, "GrowthX", "RIGHT") == "LEFT" and -1 or 1
    local defaultGrowY = (category == "DEBUFF" or category == "CUSTOM") and "DOWN" or "UP"
    local growY = AuraConfig(category, "GrowthY", defaultGrowY) == "DOWN" and -1 or 1
    local point
    if growY == -1 then
        point = growX == -1 and "TOPRIGHT" or "TOPLEFT"
    else
        point = growX == -1 and "BOTTOMRIGHT" or "BOTTOMLEFT"
    end

    local align = AuraConfig(category, "Align", "LEFT") or "LEFT"
    local desaturate = AuraConfig(category, "Desaturate", false) == true
    local showCooldownSwipe = AuraConfig(category, "CooldownSwipe", true) ~= false

    for i = 1, maxAuras do
        local aura = auras[i]
        local btn = EnsureAuraButton(plate, category, i)
        AddBorder(btn)
        btn:ClearAllPoints()

        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local rowRemaining = maxAuras - (row * perRow)
        local rowItems = perRow
        if rowRemaining < rowItems then rowItems = rowRemaining end
        if #auras > 0 then
            local realRemaining = #auras - (row * perRow)
            if realRemaining > 0 and realRemaining < rowItems then rowItems = realRemaining end
        end

        local rowWidth = (rowItems * itemWidth) + ((rowItems - 1) * spacing)
        local offsetX = growX * col * colStep
        if align == "CENTER" then
            offsetX = offsetX - (growX * rowWidth * 0.5)
        elseif align == "RIGHT" then
            offsetX = offsetX - (growX * rowWidth)
        end

        btn:SetPoint(point, auraFrame, point, offsetX, growY * row * rowStep)
        btn:SetSize(itemWidth, itemHeight)

        if aura then
            -- AuraData icon fields may be restricted in 12.1. Pass the value
            -- straight to Blizzard's texture widget inside the protected call;
            -- do not evaluate it with Lua's `or` before that call.
            local iconOK, iconApplied = pcall(function()
                local texture = aura.icon
                if texture == nil then
                    return false
                end
                btn.icon:SetTexture(texture)
                return true
            end)
            if not (iconOK and iconApplied == true) then
                pcall(btn.icon.SetTexture, btn.icon, GetFallbackAuraIcon(category, i))
            end
            if customFlat then
                pcall(btn.icon.SetTexCoord, btn.icon, 0.08, 0.92, 0.18, 0.82)
            elseif cropSides then
                -- Base aura crop uses 0.08..0.92 vertically (0.84 texture span).
                -- A 3:4 portrait frame needs a horizontal texture span of
                -- 0.84 * 0.75 = 0.63, centered at 0.5 => 0.185..0.815.
                pcall(btn.icon.SetTexCoord, btn.icon, 0.185, 0.815, 0.08, 0.92)
            else
                pcall(btn.icon.SetTexCoord, btn.icon, 0.08, 0.92, 0.08, 0.92)
            end
            if btn.icon.SetDesaturated then
                pcall(btn.icon.SetDesaturated, btn.icon, desaturate)
            end

            local countText = ""
            local countOK, computedCount = pcall(function()
                local n = tonumber(aura.applications)
                if n and n > 1 then
                    return tostring(n)
                end
                return ""
            end)
            if countOK and type(computedCount) == "string" then
                countText = computedCount
            end
            btn.count:SetText(countText)

            if btn.cd then
                local swipeApplied = false

                -- Midnight's numeric aura duration/expiration fields may be secret
                -- in combat. The supported display path is to ask Blizzard for the
                -- aura's DurationObject using the NeverSecret auraInstanceID, then
                -- hand that object directly to the Cooldown widget. No timing
                -- arithmetic or secret numeric values pass through Lua.
                if showCooldownSwipe
                    and not IsTestUnit(unit)
                    and C_UnitAuras
                    and C_UnitAuras.GetAuraDuration
                    and btn.cd.SetCooldownFromDurationObject
                then
                    -- Keep the never-secret aura instance ID and the duration
                    -- object on Blizzard's supported widget path. In particular,
                    -- do not compare the ID with nil outside this guarded call.
                    local okDuration, applied = pcall(function()
                        local durationObject = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
                        if not durationObject then
                            return false
                        end
                        btn.cd:SetCooldownFromDurationObject(durationObject, true)
                        return true
                    end)
                    swipeApplied = okDuration and applied == true
                elseif showCooldownSwipe and IsTestUnit(unit) and btn.cd.SetCooldown then
                    -- Preview only: use public synthetic timing so Test Mode shows
                    -- what the swipe looks like without requiring a real aura.
                    local now = GetTime and GetTime() or 0
                    local okSwipe = pcall(btn.cd.SetCooldown, btn.cd, now - 2, 10, 1)
                    swipeApplied = okSwipe == true
                end

                if not swipeApplied then
                    btn.cd:Clear()
                end
            end
            btn:Show()
        else
            btn:Hide()
        end
    end

    local buttons = plate.auraButtonsByCategory and plate.auraButtonsByCategory[category]
    if buttons then
        for i = maxAuras + 1, #buttons do
            buttons[i]:Hide()
        end
    end
end

-- Aura data is secret during 12.1 combat. AuraContainer owns the selection,
-- timing, icon and visibility of these buttons without exposing that data to
-- addon Lua. Manual frames remain the non-secret, out-of-combat fallback.
local function EnemyAuraContainerAvailable()
    return AuraContainerSortMethod ~= nil
        and AuraContainerSortDirection ~= nil
        and CustomAuraContainerSlotDefaultOptions ~= nil
end

local function EnsureEnemyAuraContainerAPI()
    if EnemyAuraContainerAvailable() then
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        return false
    end

    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loader then
        pcall(loader, "Blizzard_AuraContainer")
    end
    return EnemyAuraContainerAvailable()
end

local function HideManualAuraButtons(plate, category)
    local buttons = plate.auraButtonsByCategory and plate.auraButtonsByCategory[category]
    if buttons then
        for _, button in ipairs(buttons) do
            button:Hide()
        end
    end
end

local function PositionManagedAuraContainer(plate, category, container)
    if not plate or not container then return end

    local auraFrame = EnsureAuraCategoryFrame(plate, category)
    local growX = AuraConfig(category, "GrowthX", "RIGHT") == "LEFT" and -1 or 1
    local defaultGrowY = (category == "DEBUFF" or category == "CUSTOM") and "DOWN" or "UP"
    local growY = AuraConfig(category, "GrowthY", defaultGrowY) == "DOWN" and -1 or 1
    local point

    if growY == -1 then
        point = growX == -1 and "TOPRIGHT" or "TOPLEFT"
    else
        point = growX == -1 and "BOTTOMRIGHT" or "BOTTOMLEFT"
    end

    container:ClearAllPoints()
    container:SetPoint(point, auraFrame, point)
end

local function ManagedAuraInitializer(category, itemWidth, itemHeight, cropSides, customFlat)
    return function(button)
        button:EnableMouse(false)
        button:SetSize(itemWidth, itemHeight)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(button)
        if customFlat then
            icon:SetTexCoord(0.08, 0.92, 0.18, 0.82)
        elseif cropSides then
            -- The visible source is 0.84 high.  A 3:4 frame needs 0.63 wide
            -- source, centered at 0.5, to preserve the spell-art aspect.
            icon:SetTexCoord(0.185, 0.815, 0.08, 0.92)
        else
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if button.SetIcon then
            button:SetIcon(icon)
        end

        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints(button)
        if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
        if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
        if cooldown.SetUseAuraDisplayTime then cooldown:SetUseAuraDisplayTime(true) end
        if button.SetDurationCooldown then
            button:SetDurationCooldown(cooldown)
        end

        AddBorder(button)
    end
end

local function ManagedAuraSignature(category, modes, size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat)
    return table.concat(modes, ";") .. ":" .. category .. ":" .. size .. ":" .. perRow .. ":" .. rows .. ":" .. spacing
        .. ":" .. itemWidth .. ":" .. itemHeight .. ":" .. tostring(cropSides) .. ":" .. tostring(customFlat)
end

local function DisableManagedAuraCategory(plate, category)
    local entry = plate.managedAuraContainers and plate.managedAuraContainers[category]
    if not entry then return end
    if entry.container then
        pcall(entry.container.SetEnabled, entry.container, false)
        pcall(entry.container.Hide, entry.container)
    end
end

local function BuildManagedAuraCategory(plate, unit, category, modes, signature)
    local auraFrame = EnsureAuraCategoryFrame(plate, category)
    local size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat, layoutWidth, layoutHeight = GetAuraLayoutMetrics(category)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, auraFrame, "CustomAuraContainerTemplate")
    if not ok or not container then
        return nil
    end

    container:SetIgnoreParentAlpha(true)
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel((auraFrame:GetFrameLevel() or 1) + 5)
    container:SetSize(layoutWidth, layoutHeight)
    PositionManagedAuraContainer(plate, category, container)

    local maxAuras = perRow * rows
    -- AuraContainer groups are independent. Divide the configured display
    -- budget across the checked categories so enabling several filters does not
    -- expand a five-icon row into five icons per category.
    local maxPerGroup = math.max(1, math.floor(maxAuras / math.max(1, #modes)))
    local initializer = ManagedAuraInitializer(category, itemWidth, itemHeight, cropSides, customFlat)
    for index, mode in ipairs(modes) do
        local added = pcall(container.AddAuraGroup, container, "BattleMender" .. category .. index, mode, {
            maxFrameCount = maxPerGroup,
            sortMethod = AuraContainerSortMethod.Default,
            sortDirection = AuraContainerSortDirection.Normal,
            initializeFrame = initializer,
        })
        if not added then
            pcall(container.SetEnabled, container, false)
            container:Hide()
            return nil
        end
    end

    if not pcall(container.SetUnit, container, unit) then
        pcall(container.SetEnabled, container, false)
        container:Hide()
        return nil
    end

    plate.managedAuraContainers = plate.managedAuraContainers or {}
    local entry = { container = container, unit = unit, signature = signature }
    plate.managedAuraContainers[category] = entry
    return entry
end

local function UpdateManagedAuraCategory(plate, unit, category, enabled)
    if enabled == false then
        DisableManagedAuraCategory(plate, category)
        HideManualAuraButtons(plate, category)
        return true
    end

    if not EnsureEnemyAuraContainerAPI() then
        return false
    end

    local modes = {}
    if category == "CUSTOM" then
        if CFG.enemyPlateCustomShowBuffs == true then
            for _, mode in ipairs(ResolveCustomAuraModes("HELPFUL")) do
                AddAuraMode(modes, mode)
            end
        end
        if CFG.enemyPlateCustomShowDebuffs == true then
            for _, mode in ipairs(ResolveCustomAuraModes("HARMFUL")) do
                AddAuraMode(modes, mode)
            end
        end
    else
        local baseFilter = category == "BUFF" and "HELPFUL" or "HARMFUL"
        modes = ResolveAuraModes(baseFilter)
    end
    if #modes == 0 then
        DisableManagedAuraCategory(plate, category)
        HideManualAuraButtons(plate, category)
        return true
    end

    local size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat = GetAuraLayoutMetrics(category)
    local signature = ManagedAuraSignature(category, modes, size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat)
    local entry = plate.managedAuraContainers and plate.managedAuraContainers[category]

    if entry and entry.signature ~= signature then
        DisableManagedAuraCategory(plate, category)
        entry = nil
    end

    if not entry then
        entry = BuildManagedAuraCategory(plate, unit, category, modes, signature)
    elseif entry.unit ~= unit then
        local set = pcall(entry.container.SetUnit, entry.container, unit)
        if set then entry.unit = unit end
        if not set then return false end
    end

    if not entry then
        return false
    end

    -- SetupAuraCategoryFrame moves the category frame for offset and attach
    -- changes. Reapply the internal origin as well, because AuraContainer does
    -- not know BattleMender's Up/Down and Left/Right growth settings.
    PositionManagedAuraContainer(plate, category, entry.container)

    local shown = pcall(function()
        entry.container:SetEnabled(true)
        entry.container:Show()
        entry.container:UpdateAllAuras()
    end)
    if not shown then
        return false
    end

    EnsureAuraCategoryFrame(plate, category):Show()
    HideManualAuraButtons(plate, category)
    return true
end

local function HideManagedEnemyAuras(plate)
    for _, category in ipairs({ "BUFF", "DEBUFF", "CUSTOM" }) do
        DisableManagedAuraCategory(plate, category)
    end
end

local function ShouldUseManagedEnemyAuras()
    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    -- Aura information can also be secret before combat begins in instanced
    -- PvP, M+, and encounters. Use the managed path throughout instances so a
    -- staging area cannot start on the unsafe manual renderer.
    if IsInInstance then
        local inInstance = IsInInstance()
        return inInstance == true
    end

    return false
end

local function PrepareManagedEnemyAuras(plate, unit)
    for _, category in ipairs({ "BUFF", "DEBUFF", "CUSTOM" }) do
        local entry = plate.managedAuraContainers and plate.managedAuraContainers[category]
        if entry and entry.unit ~= unit then
            if pcall(entry.container.SetUnit, entry.container, unit) then
                entry.unit = unit
            end
        end
    end
end

local function ShouldShowAuraCategory(unit, enabled, targetOnly)
    if enabled == false then
        return false
    end

    return targetOnly ~= true or UnitIsCurrentTarget(unit)
end

local function UpdateAuras(plate, unit)
    if CFG.enemyPlateShowAuras == false and not IsTestUnit(unit) then
        HideManagedEnemyAuras(plate)
        if plate.auraFrame then plate.auraFrame:Hide() end
        for _, btn in ipairs(plate.auraButtons or {}) do btn:Hide() end
        HideAuraCategory(plate, "BUFF")
        HideAuraCategory(plate, "DEBUFF")
        HideAuraCategory(plate, "CUSTOM")
        return
    end

    if IsTestUnit(unit) then
        HideManagedEnemyAuras(plate)
        -- Test mode should always show Buffs, Debuffs, and Custom so the
        -- three separate layout groups can be tuned without a hostile target.
        UpdateAuraCategory(plate, unit, "BUFF", true)
        UpdateAuraCategory(plate, unit, "DEBUFF", true)
        UpdateAuraCategory(plate, unit, "CUSTOM", true)
        return
    end

    if ShouldUseManagedEnemyAuras() then
        -- Secret aura data cannot be enumerated by addon Lua in 12.1. Let the
        -- managed containers keep Buffs, Debuffs, and Custom's selected native
        -- categories updated by Blizzard.
        local showBuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowBuffs ~= false, CFG.enemyPlateBuffAurasTargetOnly)
        local showDebuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowDebuffs ~= false, CFG.enemyPlateDebuffAurasTargetOnly)
        local showCustom = ShouldShowAuraCategory(unit, CFG.enemyPlateCustomAurasEnabled ~= false, CFG.enemyPlateCustomAurasTargetOnly ~= false)
        UpdateManagedAuraCategory(plate, unit, "BUFF", showBuff)
        UpdateManagedAuraCategory(plate, unit, "DEBUFF", showDebuff)
        UpdateManagedAuraCategory(plate, unit, "CUSTOM", showCustom)
        return
    end

    -- Load Blizzard_AuraContainer while configuration is still safe, so its
    -- managed combat display is ready before the player next enters combat.
    EnsureEnemyAuraContainerAPI()
    HideManagedEnemyAuras(plate)
    PrepareManagedEnemyAuras(plate, unit)

    local showBuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowBuffs ~= false, CFG.enemyPlateBuffAurasTargetOnly)
    local showDebuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowDebuffs ~= false, CFG.enemyPlateDebuffAurasTargetOnly)
    local showCustom = ShouldShowAuraCategory(unit, CFG.enemyPlateCustomAurasEnabled ~= false, CFG.enemyPlateCustomAurasTargetOnly ~= false)
    UpdateAuraCategory(plate, unit, "BUFF", showBuff)
    UpdateAuraCategory(plate, unit, "DEBUFF", showDebuff)
    UpdateAuraCategory(plate, unit, "CUSTOM", showCustom)
end

local function PersistEnemyTestPosition(frame)
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

local function ConfigureEnemyTestDrag(frame, plate)
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
            PersistEnemyTestPosition(frame)
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

    SetupEnemyLayout(plate, frame, TEST_UNIT)
    UpdateName(plate, TEST_UNIT, frame)
    UpdateHealth(plate, TEST_UNIT, frame)
    UpdateCast(plate, TEST_UNIT)
    UpdateAuras(plate, TEST_UNIT)
    UpdatePortrait(plate, TEST_UNIT)
    ConfigureEnemyTestDrag(frame, plate)
    plate.root:SetAlpha(1)
    plate.root:Show()
end

function BM.ClearEnemyPlate(frame)
    local plate = frame and ENEMY[frame]
    if plate then
        if plate.unit then
            CAST_INTERRUPTIBILITY[plate.unit] = nil
        end
        plate.unit = nil
        plate.castActive = false
        HideEnemyPlateVisual(plate)
    end
    RestoreNativeEnemy(frame)
end

function BM.ApplyEnemyPlate(frame, nativePlate)
    if not frame then return end

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
        BM.ClearEnemyPlate(frame)
        return
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
    plate.unit = unit
    plate.nativeFrame = frame
    plate.nativePlate = nativePlate
    plate.anchorFrame = ResolveEnemyPlateParent(frame, nativePlate)
    SetupEnemyLayout(plate, frame, unit)
    UpdateName(plate, unit, frame)
    UpdateHealth(plate, unit, frame)
    UpdateCast(plate, unit)
    UpdateAuras(plate, unit)
    UpdatePortrait(plate, unit)

    -- Do not re-touch Blizzard native cast/status/aura widgets after update.
    -- The custom plate is drawn above the outer NamePlate frame instead.

    -- Do not read alpha from Blizzard nameplate frames here. Keep custom enemy
    -- plate opacity independent so this path stays off native frame internals.
    plate.root:SetAlpha(1)
end

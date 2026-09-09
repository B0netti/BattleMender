BattleMender = BattleMender or {}

local BM = BattleMender
local CFG = BM.CFG or {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local R21_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\r21"
local RIBBON_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\ribbon"
local CRIMP_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\crimp"
local BLIZZARD_STATUSBAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local BLIZZARD_CASTBAR_SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local BLIZZARD_CASTBAR_SPARK_ATLAS = "ui-castingbar-pip"
local OUTER_GLOW_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\outer_glow.tga"
local NAMEPLATE_AGGRO_FLARE_ATLAS = "UI-HUD-Nameplates-Aggro-Flare"
local NAMEPLATE_AGGRO_MASK_ATLAS = "UI-HUD-Nameplates-Aggro-Mask"
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
BM._EnemyNativeUnitOwner = BM._EnemyNativeUnitOwner or setmetatable({}, { __mode = "k" })
BM._EnemyNativeAlphaHooked = BM._EnemyNativeAlphaHooked or setmetatable({}, { __mode = "k" })
BM._EnemyNativeAlphaGuard = BM._EnemyNativeAlphaGuard or setmetatable({}, { __mode = "k" })
BM._EnemyCastState = BM._EnemyCastState or {}
BM._EnemyAuraFlares = BM._EnemyAuraFlares or setmetatable({}, { __mode = "k" })

local ENEMY = BM._EnemyPlates
local NATIVE = BM._EnemyNativeState
local NATIVE_UNIT_OWNER = BM._EnemyNativeUnitOwner
local NATIVE_ALPHA_HOOKED = BM._EnemyNativeAlphaHooked
local NATIVE_ALPHA_GUARD = BM._EnemyNativeAlphaGuard
local CAST_STATE = BM._EnemyCastState
local AURA_FLARES = BM._EnemyAuraFlares

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
    DANGER = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
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
    DANGER = {
        { name = "Important Buff", icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit", applications = 1 },
        { name = "Important Control", icon = "Interface\\Icons\\Ability_Rogue_KidneyShot", applications = 1 },
        { name = "Important Debuff", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", applications = 2 },
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

local function CoerceBoolean(value)
    return value and true or false
end

local function ReadUnitIsUnit(unitA, unitB)
    return UnitIsUnit(unitA, unitB) and true or false
end

SafeBoolFromSecret = function(value)
    -- Keep the secret-value branch inside pcall, but reuse one helper function
    -- instead of allocating a fresh closure on every aura/nameplate update.
    local ok, result = pcall(CoerceBoolean, value)
    return ok and result == true
end

local function SafeUnitIsUnit(unitA, unitB)
    if not unitA or not unitB or type(UnitIsUnit) ~= "function" then
        return false
    end

    local ok, result = pcall(ReadUnitIsUnit, unitA, unitB)
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

    -- Retail 12.1 can make UnitIsPlayer(nameplateN) a secret boolean during
    -- restricted PvP. UnitTreatAsPlayerForDisplay is a better first predicate
    -- for display code and remains useful when the older identity predicate is
    -- unavailable to addon Lua. Keep every predicate comparison inside pcall so
    -- a secret result simply falls through instead of tainting the update.
    if UnitTreatAsPlayerForDisplay then
        local ok, isPlayer = pcall(function()
            local value = UnitTreatAsPlayerForDisplay(unit)
            return value == true
        end)
        if ok and isPlayer == true then return true end
    end

    if UnitIsPlayer then
        local ok, isPlayer = pcall(function()
            local value = UnitIsPlayer(unit)
            return value == true
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
    elseif text == "BLIZZARD" or text == "blizzard" or text == BLIZZARD_STATUSBAR_TEXTURE then
        -- Legacy 14.x selector. This generic file was not the modern native nameplate art.
        return fallback or WHITE
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
    -- PvE threat is intentionally NOT a BattleMender presentation state.
    -- Keep NPC colors tied to their underlying reaction/classification instead
    -- of changing neutral -> hostile when aggro, threat owner, or target changes.
    -- This also avoids doing appearance work on the high-frequency threat path.
    local ok, reactionKey = pcall(function()
        local reaction = UnitReaction(unit, "player")
        if not reaction then reaction = UnitReaction("player", unit) end
        if reaction == 4 then return "NEUTRAL" end
        if reaction == 3 then return "UNFRIENDLY" end
        if reaction and reaction <= 2 then return "HOSTILE" end
        if reaction and reaction >= 5 then return "FRIENDLY" end
        return nil
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

    -- Reaction can occasionally be unavailable on a restricted nameplate token.
    -- Use enemy-ness only as a static fallback; unlike UnitThreatSituation and
    -- UnitSelectionType this is not used as an explicit threat visualization.
    if UnitIsEnemy then
        local okEnemy, isEnemy = pcall(UnitIsEnemy, unit, "player")
        if okEnemy and isEnemy == true then
            return ConfigColor("enemyPlateSelectionHostile", 0.82, 0.26, 0.26, 1)
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

local function ReadSafeHealthRatio(unit)
    local maxHealth = UnitHealthMax(unit)
    local health = UnitHealth(unit)
    if maxHealth and maxHealth > 0 then
        return health / maxHealth
    end
    return nil
end

local function GetSafeHealthRatio(unit)
    if not unit or not UnitHealth or not UnitHealthMax then
        return nil
    end

    local ok, ratio = pcall(ReadSafeHealthRatio, unit)
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

local function ResolveEnemyAbsorbTexture(unit)
    local base = ResolveEnemyHealthTexture(unit)
    local value = tostring(CFG.enemyPlateAbsorbTexture or "SAME")
    if value == "" or value == "SAME" or value == "BLIZZARD" or value == "blizzard" or value == BLIZZARD_STATUSBAR_TEXTURE then
        return base
    end
    return ResolveHealthTextureValue(value, base, CFG.enemyPlateAbsorbTextureCustom)
end

local function ResolveEnemyCastTexture(notInterruptible)
    local base = ResolveHealthTextureValue(CFG.enemyPlateCastTexture, WHITE, CFG.enemyPlateCastTextureCustom)
    if notInterruptible == true then
        return ResolveHealthTextureValue(CFG.enemyPlateCastNotInterruptibleTexture, base, CFG.enemyPlateCastNotInterruptibleTextureCustom)
    end
    return base
end


local function UseStableHealthClip()
    -- Stable Clip was experimental and has been retired. Keep the helper so the
    -- established health rendering code remains structurally unchanged, but all
    -- profiles now use the reliable direct StatusBar path.
    return false
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

local function ReadNativeHealthRatio(plate)
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
end

local function GetNativeHealthRatio(plate)
    local ok, ratio = pcall(ReadNativeHealthRatio, plate)
    if ok and type(ratio) == "number" then
        return ratio
    end

    return nil
end

local function GetNativeAbsorbRegionForPlate(plate)
    if not plate then return nil end

    local nativeHealth = GetNativeHealthStatusBarForPlate(plate)
    if not nativeHealth then return nil end

    local candidates = {
        nativeHealth.totalAbsorb,
        nativeHealth.TotalAbsorb,
        nativeHealth.totalAbsorbBar,
        nativeHealth.TotalAbsorbBar,
        nativeHealth.totalAbsorbOverlay,
        nativeHealth.TotalAbsorbOverlay,
    }

    local nativeRoot = plate.nativeFrame or plate.nativePlate
    local unitFrame = nativeRoot and ResolveNativeEnemyUnitFrame(nativeRoot) or nil
    if unitFrame then
        candidates[#candidates + 1] = unitFrame.totalAbsorb
        candidates[#candidates + 1] = unitFrame.TotalAbsorb
        candidates[#candidates + 1] = unitFrame.totalAbsorbBar
        candidates[#candidates + 1] = unitFrame.TotalAbsorbBar
        candidates[#candidates + 1] = unitFrame.totalAbsorbOverlay
        candidates[#candidates + 1] = unitFrame.TotalAbsorbOverlay
    end

    for _, region in ipairs(candidates) do
        if region then
            return region
        end
    end

    return nil
end

local function GetRegionEffectiveWidth(region)
    if not region then return nil end

    local ok, width = pcall(function()
        local left = region.GetLeft and region:GetLeft() or nil
        local right = region.GetRight and region:GetRight() or nil
        local w = nil
        if left and right then w = right - left end
        if type(w) ~= "number" or w < 0 then
            w = region.GetWidth and region:GetWidth() or nil
        end
        if type(w) ~= "number" then return nil end
        return w
    end)

    if ok and type(width) == "number" and width >= 0 then
        return width
    end

    return nil
end

local function GetNativeAbsorbRatio(plate)
    local ok, ratio = pcall(function()
        local nativeHealth = GetNativeHealthStatusBarForPlate(plate)
        local absorbRegion = GetNativeAbsorbRegionForPlate(plate)
        if not nativeHealth or not absorbRegion then return nil end

        if absorbRegion.IsShown and not absorbRegion:IsShown() then
            return 0
        end

        local nativeFullWidth = nativeHealth:GetWidth()
        if type(nativeFullWidth) ~= "number" or nativeFullWidth <= 0 then return nil end

        local nativeAbsorbWidth = GetRegionEffectiveWidth(absorbRegion)
        if type(nativeAbsorbWidth) ~= "number" then return nil end

        local nextRatio = nativeAbsorbWidth / nativeFullWidth
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

local function UpdateEnemyAbsorb(plate, unit)
    if not plate or not plate.healthAbsorbClip or not plate.healthAbsorbTex then return end

    if CFG.enemyPlateShowAbsorbs == false then
        plate.healthAbsorbClip:Hide()
        plate.healthAbsorbTex:Hide()
        if plate.healthAbsorbEdge then plate.healthAbsorbEdge:Hide() end
        return
    end

    local fullWidth = plate.health.GetWidth and plate.health:GetWidth() or 0
    local height = plate.health.GetHeight and plate.health:GetHeight() or 0
    if type(fullWidth) ~= "number" or fullWidth <= 0 or type(height) ~= "number" or height <= 0 then
        plate.healthAbsorbClip:Hide()
        plate.healthAbsorbTex:Hide()
        if plate.healthAbsorbEdge then plate.healthAbsorbEdge:Hide() end
        return
    end

    local healthRatio, absorbRatio
    if IsTestUnit(unit) then
        healthRatio = 0.72
        absorbRatio = 0.18
    else
        healthRatio = plate.lastHealthRatio
        absorbRatio = GetNativeAbsorbRatio(plate)
    end

    if type(healthRatio) ~= "number" then healthRatio = 0 end
    if type(absorbRatio) ~= "number" then absorbRatio = 0 end
    if healthRatio < 0 then healthRatio = 0 end
    if healthRatio > 1 then healthRatio = 1 end
    if absorbRatio < 0 then absorbRatio = 0 end

    local remaining = 1 - healthRatio
    if remaining < 0 then remaining = 0 end
    if absorbRatio > remaining then absorbRatio = remaining end

    local fillStart = fullWidth * healthRatio
    local absorbWidth = fullWidth * absorbRatio

    if absorbWidth <= 0.5 then
        plate.healthAbsorbClip:Hide()
        plate.healthAbsorbTex:Hide()
        if plate.healthAbsorbEdge then plate.healthAbsorbEdge:Hide() end
        return
    end

    local texture = ResolveEnemyAbsorbTexture(unit)
    if plate.healthAbsorbTexturePath ~= texture then
        local ok = pcall(plate.healthAbsorbTex.SetTexture, plate.healthAbsorbTex, texture)
        if not ok then
            texture = ResolveEnemyHealthTexture(unit) or WHITE
            pcall(plate.healthAbsorbTex.SetTexture, plate.healthAbsorbTex, texture)
        end
        plate.healthAbsorbTexturePath = texture
    end

    local r, g, b, a = ConfigColor("enemyPlateAbsorbColor", 0.72, 0.92, 1, 0.85)
    pcall(plate.healthAbsorbTex.SetVertexColor, plate.healthAbsorbTex, r, g, b, a)
    pcall(plate.healthAbsorbTex.SetHorizTile, plate.healthAbsorbTex, false)
    pcall(plate.healthAbsorbTex.SetVertTile, plate.healthAbsorbTex, false)
    pcall(plate.healthAbsorbTex.SetTexCoord, plate.healthAbsorbTex, 0, 1, 0, 1)

    plate.healthAbsorbClip:ClearAllPoints()
    plate.healthAbsorbClip:SetPoint("LEFT", plate.health, "LEFT", fillStart, 0)
    plate.healthAbsorbClip:SetSize(absorbWidth, height)

    plate.healthAbsorbTex:ClearAllPoints()
    plate.healthAbsorbTex:SetPoint("TOPLEFT", plate.healthAbsorbClip, "TOPLEFT", 0, 0)
    plate.healthAbsorbTex:SetSize(fullWidth, height)

    plate.healthAbsorbClip:Show()
    plate.healthAbsorbTex:Show()

    if plate.healthAbsorbEdge then
        local edgeWidth = math.max(1, math.min(2, absorbWidth))
        local edgeR = math.min(1, (r or 1) + 0.15)
        local edgeG = math.min(1, (g or 1) + 0.15)
        local edgeB = math.min(1, (b or 1) + 0.15)
        plate.healthAbsorbEdge:ClearAllPoints()
        plate.healthAbsorbEdge:SetPoint("TOPLEFT", plate.healthAbsorbClip, "TOPLEFT", 0, 0)
        plate.healthAbsorbEdge:SetSize(edgeWidth, height)
        plate.healthAbsorbEdge:SetColorTexture(edgeR, edgeG, edgeB, math.min(1, (a or 0.85) + 0.1))
        plate.healthAbsorbEdge:Show()
    end
end

local function ApplyEnemyCastTexture(plate, notInterruptible)
    if not plate or not plate.cast then return end

    local texture = ResolveEnemyCastTexture(notInterruptible)
    if plate.castTexturePath == texture then return end

    local ok = pcall(plate.cast.SetStatusBarTexture, plate.cast, texture)
    if not ok then
        pcall(plate.cast.SetStatusBarTexture, plate.cast, WHITE)
        texture = WHITE
    end

    plate.castTexturePath = texture
end

local function UpdateEnemyCastSpark(plate)
    if not plate or not plate.castSpark then return end

    if CFG.enemyPlateCastSpark ~= true or plate.castActive ~= true then
        plate.castSpark:Hide()
        return
    end

    local statusTex = plate.cast.GetStatusBarTexture and plate.cast:GetStatusBarTexture() or nil
    if not statusTex then
        plate.castSpark:Hide()
        return
    end

    local barHeight = plate.cast.GetHeight and plate.cast:GetHeight() or 0
    if type(barHeight) ~= "number" or barHeight <= 0 then
        plate.castSpark:Hide()
        return
    end

    plate.castSpark:ClearAllPoints()
    plate.castSpark:SetPoint("CENTER", statusTex, "RIGHT", 0, 0)
    if plate.castSpark.SetAtlas then
        local ok = pcall(plate.castSpark.SetAtlas, plate.castSpark, BLIZZARD_CASTBAR_SPARK_ATLAS, false)
        if not ok then
            pcall(plate.castSpark.SetTexture, plate.castSpark, BLIZZARD_CASTBAR_SPARK_TEXTURE)
        end
    else
        pcall(plate.castSpark.SetTexture, plate.castSpark, BLIZZARD_CASTBAR_SPARK_TEXTURE)
    end
    -- Blizzard's modern NamePlateCastingBar uses a fixed 4x12 pip.
    -- Set the size after SetAtlas so atlas-native dimensions cannot override it.
    plate.castSpark:SetSize(4, 12)
    plate.castSpark:SetBlendMode("ADD")
    plate.castSpark:SetVertexColor(1, 1, 1, 0.95)
    if plate.castSpark.SetDrawLayer then
        pcall(plate.castSpark.SetDrawLayer, plate.castSpark, "OVERLAY", 7)
    end
    plate.castSpark:Show()
end

local function NativeEnemyClassColorsEnabled()
    if not GetCVarBool then return false end

    local ok, enabled = pcall(GetCVarBool, "nameplateShowClassColor")
    return ok and enabled == true
end

local function ApplyDirectEnemyClassColor(region, methodName, unit)
    if not region or not unit or not NativeEnemyClassColorsEnabled() then
        return false
    end

    local method = region[methodName]
    if type(method) ~= "function" or not UnitClass then
        return false
    end

    -- UnitClass can return a secret class token in 12.1 PvP. Do not index
    -- RAID_CLASS_COLORS with it. C_ClassColor is Blizzard's native secret-safe
    -- class-color accessor and can accept the token without Lua inspecting it.
    -- Keep GetRGB -> Set* in the same pcall so secret RGB components are passed
    -- directly to the widget rather than compared or calculated in Lua.
    local applied = false
    local ok = pcall(function()
        local _, classToken = UnitClass(unit)
        local color = C_ClassColor and C_ClassColor.GetClassColor
            and C_ClassColor.GetClassColor(classToken)
        if not color then return end

        method(region, color:GetRGB())
        applied = true
    end)

    return ok == true and applied == true
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

    -- Last-resort fallback only. The native health bar can briefly retain the
    -- previous occupant's color while a recycled nameplate is being updated.
    local ok = pcall(function()
        local r, g, b, a = nativeHealth:GetStatusBarColor()
        method(region, r, g, b, a)
    end)

    return ok == true
end

local function ApplyEnemyPlayerClassColor(region, methodName, plate, unit)
    if ApplyDirectEnemyClassColor(region, methodName, unit) then
        return true
    end

    return ApplyNativeEnemyClassColor(region, methodName, plate)
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

local function IsForbiddenFrame(frame)
    if not frame or type(frame.IsForbidden) ~= "function" then return false end
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    return ok and forbidden == true
end

local function EnsureNativeEnemyAlphaHook(frame, unitFrame)
    if not frame or not unitFrame or type(unitFrame.SetAlpha) ~= "function" then return end

    -- NamePlate UnitFrames are pooled. Refresh the weak owner mapping every time
    -- the frame is acquired, while installing at most one SetAlpha hook per
    -- Blizzard UnitFrame. Midnight's native renderer can legitimately reapply
    -- distance/classification alpha after our initial hide; the hook simply
    -- restores alpha 0 while BattleMender owns that outer plate.
    NATIVE_UNIT_OWNER[unitFrame] = frame
    if NATIVE_ALPHA_HOOKED[unitFrame] then return end

    local ok = pcall(hooksecurefunc, unitFrame, "SetAlpha", function(self)
        if NATIVE_ALPHA_GUARD[self] or IsForbiddenFrame(self) then return end

        local owner = NATIVE_UNIT_OWNER[self]
        if not owner or not NATIVE[owner] or CFG.enemyPlateHideNativeBlizzard == false then
            return
        end

        NATIVE_ALPHA_GUARD[self] = true
        pcall(self.SetAlpha, self, 0)
        NATIVE_ALPHA_GUARD[self] = nil
    end)

    if ok then
        NATIVE_ALPHA_HOOKED[unitFrame] = true
    end
end

local function RestoreNativeEnemy(frame)
    if not frame then return end

    local wasHidden = NATIVE[frame]
    -- Clear ownership before restoring alpha. Otherwise our SetAlpha hook would
    -- immediately force the native frame back to zero during provider changes.
    NATIVE[frame] = nil

    local unitFrame = ResolveNativeEnemyUnitFrame(frame)
    if unitFrame and NATIVE_UNIT_OWNER[unitFrame] == frame then
        NATIVE_UNIT_OWNER[unitFrame] = nil
    end

    if wasHidden and unitFrame and type(unitFrame.SetAlpha) == "function" then
        pcall(unitFrame.SetAlpha, unitFrame, 1)
    end

    -- Do not walk or restore Blizzard's native nameplate child tree here.
    -- Prior builds hid native health/cast/aura/classification regions directly,
    -- but that can taint Blizzard's internal CompactUnitFrame, aura, and castbar
    -- update paths on Retail. Restoring only the root alpha keeps this path narrow.
end

local function HideNativeEnemy(frame)
    if not frame then return end
    NATIVE[frame] = true

    if CFG.enemyPlateHideNativeBlizzard == false then
        RestoreNativeEnemy(frame)
        return
    end

    local unitFrame = ResolveNativeEnemyUnitFrame(frame)
    if unitFrame and type(unitFrame.SetAlpha) == "function" then
        EnsureNativeEnemyAlphaHook(frame, unitFrame)
        -- Hide the native Blizzard enemy art without walking protected child
        -- tables. The SetAlpha hook above keeps it hidden if Blizzard later
        -- reapplies alpha for distance, selection, or trivial/minus presentation.
        NATIVE_ALPHA_GUARD[unitFrame] = true
        pcall(unitFrame.SetAlpha, unitFrame, 0)
        NATIVE_ALPHA_GUARD[unitFrame] = nil
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

    local healthAbsorbClip = CreateFrame("Frame", nil, health)
    healthAbsorbClip:EnableMouse(false)
    if healthAbsorbClip.SetMouseMotionEnabled then healthAbsorbClip:SetMouseMotionEnabled(false) end
    if healthAbsorbClip.SetClipsChildren then healthAbsorbClip:SetClipsChildren(true) end
    healthAbsorbClip:SetPoint("LEFT", health, "LEFT", 0, 0)
    healthAbsorbClip:SetSize(1, 1)
    if healthAbsorbClip.SetFrameLevel then
        healthAbsorbClip:SetFrameLevel((health:GetFrameLevel() or 1) + 2)
    end

    local healthAbsorbTex = healthAbsorbClip:CreateTexture(nil, "OVERLAY", nil, 1)
    healthAbsorbTex:SetTexture(WHITE)
    healthAbsorbTex:SetTexCoord(0, 1, 0, 1)
    healthAbsorbTex:SetVertexColor(0.72, 0.92, 1, 0.85)
    healthAbsorbTex:SetPoint("TOPLEFT", healthAbsorbClip, "TOPLEFT", 0, 0)

    local healthAbsorbEdge = health:CreateTexture(nil, "OVERLAY", nil, 3)
    healthAbsorbEdge:Hide()

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

    -- The target / low-health halo is rendered as four cropped pieces of the
    -- same outer_glow texture. This leaves the health-bar rectangle itself fully
    -- cut out, so translucent health textures cannot reveal glow through the bar.
    -- Four pieces are preferable to an inverse mask here: the cutout geometry is
    -- exact for any configured bar width/height and needs no additional mask art.
    local function CreateExteriorGlowPieces(sublevel)
        local pieces = {}
        for _, key in ipairs({ "top", "bottom", "left", "right" }) do
            local tex = root:CreateTexture(nil, "BACKGROUND", nil, sublevel)
            tex:SetBlendMode("ADD")
            tex:Hide()
            pieces[key] = tex
        end
        return pieces
    end

    local targetGlow = CreateExteriorGlowPieces(-1)
    local lowHealthGlow = CreateExteriorGlowPieces(-2)

    local targetOverlay = health:CreateTexture(nil, "OVERLAY", nil, 2)
    targetOverlay:SetAllPoints()
    targetOverlay:Hide()

    local hoverOverlay = health:CreateTexture(nil, "OVERLAY", nil, 3)
    hoverOverlay:SetAllPoints()
    hoverOverlay:Hide()

    -- Blizzard's NamePlateThreatDisplay.Flash uses this same additive bar-fill
    -- texture with two 0.25-second alpha pulses. BattleMender repeats that short
    -- double flash (with a quiet gap) while an enemy PvP objective carrier is
    -- classified, tinting it to the flag/orb/cart/bounty color.
    local objectiveFlash = health:CreateTexture(nil, "OVERLAY", nil, 6)
    objectiveFlash:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    objectiveFlash:SetAllPoints()
    objectiveFlash:SetBlendMode("ADD")
    objectiveFlash:SetAlpha(0)
    objectiveFlash:Hide()

    local objectiveFlashAnim = objectiveFlash:CreateAnimationGroup()
    objectiveFlashAnim:SetLooping("REPEAT")

    local objectiveFlashOne = objectiveFlashAnim:CreateAnimation("Alpha")
    objectiveFlashOne:SetDuration(0.25)
    objectiveFlashOne:SetOrder(1)
    objectiveFlashOne:SetFromAlpha(1)
    objectiveFlashOne:SetToAlpha(0)

    local objectiveFlashTwo = objectiveFlashAnim:CreateAnimation("Alpha")
    objectiveFlashTwo:SetDuration(0.25)
    objectiveFlashTwo:SetOrder(2)
    objectiveFlashTwo:SetFromAlpha(1)
    objectiveFlashTwo:SetToAlpha(0)

    -- Blizzard's original threat flash is a one-shot double pulse. Objective
    -- carriers need persistent readability, so leave a short dark interval
    -- before repeating the same two-pulse cadence.
    local objectiveFlashGap = objectiveFlashAnim:CreateAnimation("Alpha")
    objectiveFlashGap:SetDuration(1.10)
    objectiveFlashGap:SetOrder(3)
    objectiveFlashGap:SetFromAlpha(0)
    objectiveFlashGap:SetToAlpha(0)

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

    local castSpark = cast:CreateTexture(nil, "OVERLAY", nil, 7)
    castSpark:SetTexture(BLIZZARD_CASTBAR_SPARK_TEXTURE)
    castSpark:SetBlendMode("ADD")
    castSpark:Hide()

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
        healthAbsorbClip = healthAbsorbClip,
        healthAbsorbTex = healthAbsorbTex,
        healthAbsorbEdge = healthAbsorbEdge,
        healthText = healthText,
        healthAlertBG = healthAlertBG,
        targetGlow = targetGlow,
        lowHealthGlow = lowHealthGlow,
        targetOverlay = targetOverlay,
        hoverOverlay = hoverOverlay,
        objectiveFlash = objectiveFlash,
        objectiveFlashAnim = objectiveFlashAnim,
        nameFrame = nameFrame,
        name = name,
        cast = cast,
        castText = castText,
        castIcon = castIcon,
        castIconBG = castIconBG,
        castSpark = castSpark,
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

    -- Register cast events directly on this BattleMender-owned frame once it
    -- has a live unit. Global UNIT_SPELLCAST events remain a useful fallback,
    -- but binding here matches Blizzard's casting-bar path and keeps the
    -- interruptibility event associated with this visible nameplate token.
    root:SetScript("OnEvent", function(_, event, unit, ...)
        if not plate.unit or not unit then return end

        -- Keep the explicit interruptibility state on this visible cast bar,
        -- matching provider cast-bar implementations. This avoids depending on
        -- the event token having the same string identity as the resolved
        -- nameplate token used by the renderer.
        if event == "UNIT_SPELLCAST_START"
            or event == "UNIT_SPELLCAST_CHANNEL_START"
        then
            plate.castNotInterruptible = nil
        elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            plate.castNotInterruptible = true
        elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
            plate.castNotInterruptible = false
        elseif event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        then
            plate.castNotInterruptible = nil
        end

        if BM.HandleEnemyCastEvent then
            BM.HandleEnemyCastEvent(event, unit, ...)
        end
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
    if plate.objectiveFlashAnim and plate.objectiveFlashAnim.Stop then
        plate.objectiveFlashAnim:Stop()
    end
    if plate.objectiveFlash then
        plate.objectiveFlash:SetAlpha(0)
        plate.objectiveFlash:Hide()
    end
    plate.objectiveFlashKey = nil
    plate.root:Hide()
end

local function UpdateEnemyObjectiveFlash(plate, unit)
    if not plate or not plate.objectiveFlash or not plate.objectiveFlashAnim then return end

    if CFG.enemyPlateObjectiveFlashEnabled == false or IsTestUnit(unit) then
        plate.objectiveFlashKey = nil
        plate.objectiveFlashAnim:Stop()
        plate.objectiveFlash:SetAlpha(0)
        plate.objectiveFlash:Hide()
        return
    end

    local atlas, r, g, b
    if BM.GetPvPObjectiveInfo then
        atlas, r, g, b = BM.GetPvPObjectiveInfo(unit)
    end

    if not atlas then
        plate.objectiveFlashKey = nil
        plate.objectiveFlashAnim:Stop()
        plate.objectiveFlash:SetAlpha(0)
        plate.objectiveFlash:Hide()
        return
    end

    plate.objectiveFlash:SetVertexColor(r or 1, g or 1, b or 0, 1)
    plate.objectiveFlash:Show()

    -- A recycled plate or a carrier changing objective type should restart the
    -- attention pulse immediately. Otherwise leave the repeating animation alone.
    if plate.objectiveFlashKey ~= atlas or not plate.objectiveFlashAnim:IsPlaying() then
        plate.objectiveFlashKey = atlas
        plate.objectiveFlashAnim:Stop()
        plate.objectiveFlash:SetAlpha(0)
        plate.objectiveFlashAnim:Play()
    end
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
    DANGER = "enemyPlateDangerAura",
}

local AURA_CATEGORIES = { "BUFF", "DEBUFF", "CUSTOM", "DANGER" }

local SELECTABLE_AURA_SETTING_PREFIX = {
    CUSTOM = "Custom",
    DANGER = "Danger",
}

local function AuraConfig(category, suffix, fallback)
    local prefix = AURA_PREFIX[category]
    local value = prefix and CFG[prefix .. suffix]

    if value == nil and not SELECTABLE_AURA_SETTING_PREFIX[category] then
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
    local selectablePrefix = SELECTABLE_AURA_SETTING_PREFIX[category]
    local defaultSize = selectablePrefix and 16 or 30
    local defaultPerRow = 5
    local size = tonumber(AuraConfig(category, "Size", defaultSize)) or defaultSize
    local perRow = tonumber(AuraConfig(category, "PerRow", defaultPerRow)) or defaultPerRow
    local rows = tonumber(AuraConfig(category, "Rows", 1)) or 1
    local spacing = tonumber(AuraConfig(category, "Spacing", 1)) or 1
    if size < 8 then size = 8 end
    if perRow < 1 then perRow = 1 end
    if rows < 1 then rows = 1 end
    if spacing < 0 then spacing = 0 end

    -- 3:4 Tall keeps Size as the height; selectable-container Flat keeps Size
    -- as the width and reduces its height to form a compact horizontal strip.
    local customFlat = selectablePrefix and AuraConfig(category, "Flat", true) ~= false
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
    if plate.healthAbsorbClip then
        plate.healthAbsorbClip:SetHeight(healthHeight)
    end
    if plate.healthAbsorbTex then
        plate.healthAbsorbTex:SetSize(width, healthHeight)
    end
    if plate.healthAbsorbEdge then
        plate.healthAbsorbEdge:SetHeight(healthHeight)
    end
    ApplyEnemyHealthTextureTiling(plate)
    UpdateEnemyHealthFillClip(plate)
    UpdateEnemyAbsorb(plate, unit)

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

    for _, category in ipairs(AURA_CATEGORIES) do
        SetupAuraCategoryFrame(plate, category)
    end
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

local function ApplyThreatFlareColor(region, plate, unit, alpha)
    if not region then return end

    local mode = CFG.enemyPlateAuraFlareColorMode or "CUSTOM"
    if mode == "CUSTOM" then
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

    -- Health rendering has an additional native class-color fallback. If that
    -- path successfully resolved this player's class earlier in the same plate
    -- update, reuse the already-rendered color instead of giving up here.
    if UnitLooksLikePlayer(unit, plate and plate.nativeFrame) then
        if plate and plate.healthClassColorResolved == true then
            if ApplyRenderedHealthColor(region, plate, unit, alpha) then
                return
            end
        end

        -- Never flash neutral white when the class is temporarily unavailable.
        -- The user's configured flare color is the stable final fallback.
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
        if type(effect) == "table" and effect.plate == plate then
            if effect.flareBase then
                pcall(ApplyThreatFlareColor, effect.flareBase, plate, unit, math.min(1, opacity * 1.15))
            end
            if effect.flareAdditive then
                pcall(ApplyThreatFlareColor, effect.flareAdditive, plate, unit, math.min(1, opacity * 0.9))
            end
        end
    end
end

local function SetHealthThreatFlare(plate, flareBase, flareAdditive, flareMask, unit)
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

    ApplyThreatFlareColor(flareBase, plate, unit, math.min(1, opacity * 1.15))
    ApplyThreatFlareColor(flareAdditive, plate, unit, math.min(1, opacity * 0.9))

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
local function ApplyAuraFlare(plate, category, button)
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
        pcall(SetHealthThreatFlare, plate, effect.flareBase, effect.flareAdditive, effect.flareMask, plate.unit)
    end
    if effect.scrollAnim and effect.scrollAnim.Play and not effect.scrollAnim:IsPlaying() then
        pcall(effect.scrollAnim.Play, effect.scrollAnim)
    end
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

local function ShouldBlockPermanentAura(aura, baseFilter, selectablePrefix)
    if not AuraIsPermanent(aura) then
        return false
    end

    if selectablePrefix then
        local auraType = baseFilter == "HELPFUL" and "Buff" or "Debuff"
        return CFG["enemyPlate" .. selectablePrefix .. auraType .. "BlockPermanent"] == true
    end

    if baseFilter == "HELPFUL" then
        return CFG.enemyPlateBuffOthersBlockPermanent == true
    end
    return CFG.enemyPlateDebuffBlockPermanent == true
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

local function AddAuraModeWithExclusions(out, mode, exclusions)
    for _, token in ipairs(exclusions or {}) do
        if not ("|" .. mode .. "|"):find("|" .. token .. "|", 1, true) then
            mode = mode .. "|" .. token
        end
    end
    AddAuraMode(out, mode)
end

local function AddConfiguredExclusion(exclusions, key, token)
    if CFG[key] ~= true then return end

    for _, existing in ipairs(exclusions) do
        if existing == token then return end
    end
    exclusions[#exclusions + 1] = token
end

local function AuraFilterMode(baseFilter, sourceToken, categoryTokens)
    local mode = baseFilter
    if sourceToken then
        mode = mode .. "|" .. sourceToken
    end
    if categoryTokens then
        mode = mode .. "|" .. categoryTokens
    end
    return mode
end

local function ResolveEnemyBuffExclusions()
    local exclusions = {}
    AddConfiguredExclusion(exclusions, "enemyPlateBuffExcludeRaidDispellable", "!RAID_PLAYER_DISPELLABLE")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffExcludeDispellable", "!DISPELLABLE")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffExcludeImportant", "!IMPORTANT")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffExcludeRaidInCombat", "!RAID_IN_COMBAT")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffOthersExcludeRaid", "!RAID")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffOthersExcludeCancelable", "!CANCELABLE")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffOthersExcludeBigDefensive", "!BIG_DEFENSIVE")
    AddConfiguredExclusion(exclusions, "enemyPlateBuffOthersExcludeExternalDefensive", "!EXTERNAL_DEFENSIVE")
    return exclusions
end

local function ResolveEnemyDebuffExclusions()
    local exclusions = {}
    AddConfiguredExclusion(exclusions, "enemyPlateDebuffExcludeRaidDispellable", "!RAID_PLAYER_DISPELLABLE")
    AddConfiguredExclusion(exclusions, "enemyPlateDebuffExcludeDispellable", "!DISPELLABLE")
    AddConfiguredExclusion(exclusions, "enemyPlateDebuffExcludeRaid", "!RAID")
    AddConfiguredExclusion(exclusions, "enemyPlateDebuffExcludeCrowdControl", "!CROWD_CONTROL")
    return exclusions
end

-- Blizzard can classify one helpful aura as both BIG_DEFENSIVE and
-- EXTERNAL_DEFENSIVE. AuraContainer renders each selected native filter as an
-- independent group, so partition the overlap in the filter string itself.
-- External owns the overlap; Big Defensive keeps non-external defensives.
local function AddDefensiveAuraModes(out, sourceToken, showBig, showExternal, exclusions)
    local prefix = AuraFilterMode("HELPFUL", sourceToken)
    if showBig == true then
        local mode = prefix .. "|BIG_DEFENSIVE"
        if showExternal == true then
            mode = mode .. "|!EXTERNAL_DEFENSIVE"
        end
        AddAuraModeWithExclusions(out, mode .. "|INCLUDE_NAME_PLATE_ONLY", exclusions)
    end

    if showExternal == true then
        AddAuraModeWithExclusions(out, prefix .. "|EXTERNAL_DEFENSIVE|INCLUDE_NAME_PLATE_ONLY", exclusions)
    end
end

local function ResolveAuraModes(baseFilter)
    local modes = {}

    if baseFilter == "HELPFUL" then
        local exclusions = ResolveEnemyBuffExclusions()
        local sourceToken = "!PLAYER"

        if CFG.enemyPlateBuffUseRaidDispellable == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
        if CFG.enemyPlateBuffUseDispellable == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
        if CFG.enemyPlateBuffUseImportant == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "IMPORTANT|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
        if CFG.enemyPlateBuffUseRaidInCombat == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID_IN_COMBAT|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
        if CFG.enemyPlateBuffOthersRaid == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID"), exclusions)
        end
        if CFG.enemyPlateBuffOthersCancelable == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "CANCELABLE"), exclusions)
        end
        AddDefensiveAuraModes(
            modes,
            sourceToken,
            CFG.enemyPlateBuffOthersBigDefensive,
            CFG.enemyPlateBuffOthersExternalDefensive,
            exclusions
        )

        if #modes == 0 then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken), exclusions)
        end
        return modes
    end

    if baseFilter ~= "HARMFUL" then
        return { ResolveAuraMode(baseFilter) }
    end

    local exclusions = ResolveEnemyDebuffExclusions()
    local sourceToken = CFG.enemyPlateDebuffOnlyCastByYou == true and "PLAYER" or nil

    if CFG.enemyPlateDebuffUseRaidDispellable == true then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"), exclusions)
    end
    if CFG.enemyPlateDebuffUseDispellable == true then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"), exclusions)
    end
    if CFG.enemyPlateDebuffRaid == true then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID"), exclusions)
    end
    if CFG.enemyPlateDebuffCrowdControl == true then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY"), exclusions)
    end

    if #modes == 0 then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken), exclusions)
    end
    return modes
end

local function ResolveSelectableAuraExclusions(prefix, baseFilter)
    local exclusions = {}
    local auraType = baseFilter == "HELPFUL" and "Buff" or "Debuff"
    local keyPrefix = "enemyPlate" .. prefix .. auraType

    AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeRaidDispellable", "!RAID_PLAYER_DISPELLABLE")
    AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeDispellable", "!DISPELLABLE")
    AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeRaid", "!RAID")

    if baseFilter == "HELPFUL" then
        AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeImportant", "!IMPORTANT")
        AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeRaidInCombat", "!RAID_IN_COMBAT")
        AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeCancelable", "!CANCELABLE")
        AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeBigDefensive", "!BIG_DEFENSIVE")
        AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeExternalDefensive", "!EXTERNAL_DEFENSIVE")
    else
        AddConfiguredExclusion(exclusions, keyPrefix .. "ExcludeCrowdControl", "!CROWD_CONTROL")
    end

    return exclusions
end

local function ResolveSelectableAuraModes(baseFilter, prefix)
    local modes = {}
    local auraType = baseFilter == "HELPFUL" and "Buff" or "Debuff"
    local keyPrefix = "enemyPlate" .. prefix .. auraType
    local exclusions = ResolveSelectableAuraExclusions(prefix, baseFilter)
    local sourceToken = baseFilter == "HARMFUL"
        and CFG[keyPrefix .. "OnlyCastByYou"] == true
        and "PLAYER"
        or nil

    if CFG[keyPrefix .. "UseRaidDispellable"] == true then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID_PLAYER_DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"), exclusions)
    end
    if CFG[keyPrefix .. "UseDispellable"] == true then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "DISPELLABLE|INCLUDE_NAME_PLATE_ONLY"), exclusions)
    end
    if baseFilter == "HELPFUL" then
        if CFG[keyPrefix .. "UseImportant"] == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, nil, "IMPORTANT|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
        if CFG[keyPrefix .. "UseRaidInCombat"] == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, nil, "RAID_IN_COMBAT|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
        if CFG[keyPrefix .. "Raid"] == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, nil, "RAID"), exclusions)
        end
        if CFG[keyPrefix .. "Cancelable"] == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, nil, "CANCELABLE"), exclusions)
        end
        AddDefensiveAuraModes(
            modes,
            nil,
            CFG[keyPrefix .. "BigDefensive"],
            CFG[keyPrefix .. "ExternalDefensive"],
            exclusions
        )
    else
        if CFG[keyPrefix .. "Raid"] == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "RAID"), exclusions)
        end
        if CFG[keyPrefix .. "CrowdControl"] == true then
            AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken, "CROWD_CONTROL|INCLUDE_NAME_PLATE_ONLY"), exclusions)
        end
    end

    if #modes == 0 then
        AddAuraModeWithExclusions(modes, AuraFilterMode(baseFilter, sourceToken), exclusions)
    end
    return modes
end

local function GetAuraCollectionFilter(baseFilter, mode)
    -- Selectable containers inspect the normal HELPFUL/HARMFUL list and apply
    -- their selected native filter. Explicit Blizzard categories are passed
    -- directly to C_UnitAuras/UnitAura.
    if IsBlizzardAuraFilterMode(mode, baseFilter) then
        return mode
    end

    return baseFilter
end

local function AuraAllowed(aura, baseFilter, unit, mode, ignoreGroupEnabled, selectablePrefix)
    if not aura then return false end

    if ShouldBlockPermanentAura(aura, baseFilter, selectablePrefix) then
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

    local function collectSelectableModes(baseFilter, prefix)
        local modes = ResolveSelectableAuraModes(baseFilter, prefix)
        for _, mode in ipairs(modes) do
            local filter = GetAuraCollectionFilter(baseFilter, mode)

            VisitAuras(unit, filter, function(aura)
                if AuraAllowed(aura, baseFilter, unit, mode, true, prefix) and MarkAuraSeen(seen, aura) then
                    auras[#auras + 1] = aura
                end
            end)
        end
    end

    if category == "BUFF" then
        collect("HELPFUL")
    elseif category == "DEBUFF" then
        collect("HARMFUL")
    else
        local prefix = SELECTABLE_AURA_SETTING_PREFIX[category]
        local root = prefix and ("enemyPlate" .. prefix)
        if root and CFG[root .. "ShowBuffs"] == true then
            collectSelectableModes("HELPFUL", prefix)
        end
        if root and CFG[root .. "ShowDebuffs"] == true then
            collectSelectableModes("HARMFUL", prefix)
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
    if btn then
        ApplyAuraFlare(plate, category, btn)
        return btn
    end

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
    ApplyAuraFlare(plate, category, btn)
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
    local growthX = AuraConfig(category, "GrowthX", "RIGHT") or "RIGHT"
    local growX = growthX == "LEFT" and -1 or 1
    local defaultGrowY = category == "DEBUFF" and "DOWN" or "UP"
    local growY = AuraConfig(category, "GrowthY", defaultGrowY) == "DOWN" and -1 or 1
    local point
    if growthX == "CENTER" then
        point = growY == -1 and "TOP" or "BOTTOM"
    elseif growY == -1 then
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
        local offsetX
        if growthX == "CENTER" then
            -- Center-growth uses the midpoint of the current row as its origin,
            -- so one icon sits on the anchor and longer rows expand evenly.
            offsetX = (col - ((rowItems - 1) * 0.5)) * colStep
        else
            offsetX = growX * col * colStep
            if align == "CENTER" then
                offsetX = offsetX - (growX * rowWidth * 0.5)
            elseif align == "RIGHT" then
                offsetX = offsetX - (growX * rowWidth)
            end
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
    local growthX = AuraConfig(category, "GrowthX", "RIGHT") or "RIGHT"
    local defaultGrowY = category == "DEBUFF" and "DOWN" or "UP"
    local growthY = AuraConfig(category, "GrowthY", defaultGrowY) or defaultGrowY
    local growX = growthX == "LEFT" and -1 or 1
    local growY = growthY == "DOWN" and -1 or 1
    local point

    if growthX == "CENTER" then
        point = growY == -1 and "TOP" or "BOTTOM"
    elseif growY == -1 then
        point = growX == -1 and "TOPRIGHT" or "TOPLEFT"
    else
        point = growX == -1 and "BOTTOMRIGHT" or "BOTTOMLEFT"
    end

    container:ClearAllPoints()
    container:SetPoint(point, auraFrame, point)

    -- AuraContainer owns live/secret aura geometry in 12.1. Configure its flow
    -- origin as well as the outer frame anchor so Center behaves consistently
    -- with the manual Test Mode renderer. Native flow cannot alternate around
    -- an origin, so Center uses a centered outer edge and fills to the right.
    local setAnchor = container.SetFlowLayoutAnchorPoint or container.SetAuraLayoutAnchorPoint
    local setGrowth = container.SetFlowLayoutGrowthDirection or container.SetAuraLayoutGrowthDirection
    local setLineSize = container.SetFlowLayoutMaximumLineSize or container.SetAuraLayoutRowWidth

    local flowPoint = point
    if growthX == "CENTER" then
        flowPoint = growY == -1 and "TOPLEFT" or "BOTTOMLEFT"
    end
    if setAnchor then
        pcall(setAnchor, container, flowPoint)
    end

    local flowDirection = AnchorUtil and AnchorUtil.FlowDirection
    if setGrowth and flowDirection then
        local horizontal = growthX == "LEFT" and flowDirection.Left or flowDirection.Right
        local vertical = growY == -1 and flowDirection.Down or flowDirection.Up
        if horizontal and vertical then
            pcall(setGrowth, container, horizontal, vertical)
        end
    end

    if setLineSize then
        local _, _, _, _, _, _, _, _, layoutWidth = GetAuraLayoutMetrics(category)
        pcall(setLineSize, container, layoutWidth)
    end
end

local function ManagedAuraInitializer(plate, category, itemWidth, itemHeight, cropSides, customFlat, desaturate)
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
        if icon.SetDesaturated then
            pcall(icon.SetDesaturated, icon, desaturate)
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
        ApplyAuraFlare(plate, category, button)
    end
end

local function AuraFlareSignature(category)
    local triggerCategory = CFG.enemyPlateAuraFlareTriggerCategory or "DANGER"
    if category ~= triggerCategory then return "" end

    local r, g, b = ConfigColor("enemyPlateAuraFlare", 1, 0.12, 0.04, 1)
    return table.concat({
        tostring(CFG.enemyPlateAuraFlareEnabled ~= false),
        tostring(triggerCategory),
        tostring(CFG.enemyPlateAuraFlareColorMode or "CUSTOM"),
        tostring(tonumber(CFG.enemyPlateAuraFlareHeight) or 32),
        tostring(tonumber(CFG.enemyPlateAuraFlareDensity) or 1),
        tostring(tonumber(CFG.enemyPlateAuraFlareYOffset) or 4),
        tostring(tonumber(CFG.enemyPlateAuraFlareOpacity) or 0.28),
        tostring(r), tostring(g), tostring(b),
    }, ",")
end

local function ManagedAuraSignature(category, modes, size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat, desaturate)
    return table.concat(modes, ";") .. ":" .. category .. ":" .. size .. ":" .. perRow .. ":" .. rows .. ":" .. spacing
        .. ":" .. itemWidth .. ":" .. itemHeight .. ":" .. tostring(cropSides) .. ":" .. tostring(customFlat)
        .. ":" .. tostring(desaturate) .. ":" .. AuraFlareSignature(category)
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
    local desaturate = AuraConfig(category, "Desaturate", false) == true
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
    local initializer = ManagedAuraInitializer(plate, category, itemWidth, itemHeight, cropSides, customFlat, desaturate)
    for index, mode in ipairs(modes) do
        local added = pcall(container.AddAuraGroup, container, "BattleMender" .. category .. index, mode, {
            maxFrameCount = maxPerGroup,
            sortMethod = AuraContainerSortMethod.Default,
            sortDirection = AuraContainerSortDirection.Normal,
            initializeFrame = initializer,
            -- AuraContainer owns button placement in the 12.1 managed path.
            -- Supplying the group layout is therefore required for the user's
            -- spacing slider to affect the actual icon gaps (including Important).
            layout = {
                elementWidth = itemWidth,
                elementHeight = itemHeight,
                elementSpacing = spacing,
                lineSpacing = spacing,
                groupSpacing = spacing,
                groupLineSpacing = spacing,
            },
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
    local selectablePrefix = SELECTABLE_AURA_SETTING_PREFIX[category]
    if selectablePrefix then
        local root = "enemyPlate" .. selectablePrefix
        if CFG[root .. "ShowBuffs"] == true then
            for _, mode in ipairs(ResolveSelectableAuraModes("HELPFUL", selectablePrefix)) do
                AddAuraMode(modes, mode)
            end
        end
        if CFG[root .. "ShowDebuffs"] == true then
            for _, mode in ipairs(ResolveSelectableAuraModes("HARMFUL", selectablePrefix)) do
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
    local desaturate = AuraConfig(category, "Desaturate", false) == true
    local signature = ManagedAuraSignature(category, modes, size, perRow, rows, spacing, itemWidth, itemHeight, cropSides, customFlat, desaturate)
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
    for _, category in ipairs(AURA_CATEGORIES) do
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
    for _, category in ipairs(AURA_CATEGORIES) do
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
    if CFG.enemyPlateShowAuras == false then
        HideManagedEnemyAuras(plate)
        if plate.auraFrame then plate.auraFrame:Hide() end
        for _, btn in ipairs(plate.auraButtons or {}) do btn:Hide() end
        for _, category in ipairs(AURA_CATEGORIES) do
            HideAuraCategory(plate, category)
        end
        return
    end

    if IsTestUnit(unit) then
        HideManagedEnemyAuras(plate)
        -- Preview synthetic auras without target-only gating, but respect the
        -- same master/container enable switches the live plate uses. This keeps
        -- Test Mode useful for layout work without showing disabled groups.
        local enabled = {
            BUFF = CFG.enemyPlateShowBuffs ~= false,
            DEBUFF = CFG.enemyPlateShowDebuffs ~= false,
            CUSTOM = CFG.enemyPlateCustomAurasEnabled == true,
            DANGER = CFG.enemyPlateDangerAurasEnabled == true,
        }
        for _, category in ipairs(AURA_CATEGORIES) do
            UpdateAuraCategory(plate, unit, category, enabled[category] == true)
        end
        return
    end

    local function UpdateSelectableContainers(update)
        for _, category in ipairs({ "CUSTOM", "DANGER" }) do
            local prefix = SELECTABLE_AURA_SETTING_PREFIX[category]
            local root = "enemyPlate" .. prefix
            local show = ShouldShowAuraCategory(
                unit,
                CFG[root .. "AurasEnabled"] == true,
                CFG[root .. "AurasTargetOnly"] == true
            )
            update(plate, unit, category, show)
        end
    end

    if ShouldUseManagedEnemyAuras() then
        -- Secret aura data cannot be enumerated by addon Lua in 12.1. Let the
        -- managed containers keep all four groups' selected native categories
        -- updated by Blizzard.
        local showBuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowBuffs ~= false, CFG.enemyPlateBuffAurasTargetOnly)
        local showDebuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowDebuffs ~= false, CFG.enemyPlateDebuffAurasTargetOnly)
        UpdateManagedAuraCategory(plate, unit, "BUFF", showBuff)
        UpdateManagedAuraCategory(plate, unit, "DEBUFF", showDebuff)
        UpdateSelectableContainers(UpdateManagedAuraCategory)
        return
    end

    -- Load Blizzard_AuraContainer while configuration is still safe, so its
    -- managed combat display is ready before the player next enters combat.
    EnsureEnemyAuraContainerAPI()
    HideManagedEnemyAuras(plate)
    PrepareManagedEnemyAuras(plate, unit)

    local showBuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowBuffs ~= false, CFG.enemyPlateBuffAurasTargetOnly)
    local showDebuff = ShouldShowAuraCategory(unit, CFG.enemyPlateShowDebuffs ~= false, CFG.enemyPlateDebuffAurasTargetOnly)
    UpdateAuraCategory(plate, unit, "BUFF", showBuff)
    UpdateAuraCategory(plate, unit, "DEBUFF", showDebuff)
    UpdateSelectableContainers(UpdateAuraCategory)
end

-- Resolve an already-created live custom enemy plate without rebuilding it.
-- High-frequency events should use this path rather than ApplyEnemyPlate.
local function GetActiveEnemyPlateForUnit(unit)
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
    local plate, nativePlate = GetActiveEnemyPlateForUnit(unit)
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

local function ForEachVisibleEnemyPlate(callback)
    if type(callback) ~= "function" then return end

    for _, plate in pairs(ENEMY) do
        local unit = plate and plate.unit
        if unit and not IsTestUnit(unit) and plate.root and plate.root:IsShown() then
            callback(plate, unit)
        end
    end
end

local function UpdateTargetGatedAuraCategories(plate, unit)
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

local function SetEnemyHoverOverlay(plate, enabled)
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
        SetEnemyHoverOverlay(previous, false)
    end

    if current then
        SetEnemyHoverOverlay(current, true)
    end

    BM._EnemyHoveredPlate = current
end

function BM.RefreshEnemyTargetState()
    if not BM.ShouldUseCustomEnemyPlates or not BM.ShouldUseCustomEnemyPlates() then return end

    ForEachVisibleEnemyPlate(function(plate, unit)
        UpdateEnemyHighlights(plate, unit)
        UpdateTargetGatedAuraCategories(plate, unit)
    end)
end

function BM.RefreshEnemyCombatState()
    if not BM.ShouldUseCustomEnemyPlates or not BM.ShouldUseCustomEnemyPlates() then return end

    ForEachVisibleEnemyPlate(function(plate, unit)
        UpdateAuras(plate, unit)
    end)
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
    ConfigureEnemyCastEvents(plate, nil)

    SetupEnemyLayout(plate, frame, TEST_UNIT)
    UpdateName(plate, TEST_UNIT, frame)
    UpdateHealth(plate, TEST_UNIT, frame)
    UpdateCast(plate, TEST_UNIT)
    UpdateAuras(plate, TEST_UNIT)
    RefreshAuraFlareColorsForPlate(plate, TEST_UNIT)
    UpdatePortrait(plate, TEST_UNIT)
    UpdateEnemyObjectiveFlash(plate, TEST_UNIT)
    ConfigureEnemyTestDrag(frame, plate)
    plate.root:SetAlpha(1)
    plate.root:Show()
end

function BM.ClearEnemyPlate(frame)
    local plate = frame and ENEMY[frame]
    if plate then
        if BM._EnemyHoveredPlate == plate then
            BM._EnemyHoveredPlate = nil
        end
        ConfigureEnemyCastEvents(plate, nil)
        if plate.unit then
            CAST_STATE[plate.unit] = nil
        end
        plate.unit = nil
        plate.castNotInterruptible = nil
        plate.castActive = false
        plate.objectiveFlashKey = nil
        HideEnemyPlateVisual(plate)
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
        end
        plate.castNotInterruptible = nil
        plate.objectiveFlashKey = nil
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

    -- Do not re-touch Blizzard native cast/status/aura widgets after update.
    -- The custom plate is drawn above the outer NamePlate frame instead.

    -- Do not read alpha from Blizzard nameplate frames here. Keep custom enemy
    -- plate opacity independent so this path stays off native frame internals.
    plate.root:SetAlpha(1)
end

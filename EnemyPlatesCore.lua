BattleMender = BattleMender or {}

local BM = BattleMender
BM.EnemyPlateInternal = BM.EnemyPlateInternal or {}
local EPI = BM.EnemyPlateInternal
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

    if BM.IsArenaInstance and BM.IsArenaInstance() then
        base = base * ClampNumber(CFG.arenaEnemyPlateScale, 1, 1, 2)
    end

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

local function GetSafeEnemyClassPoolKey(unit)
    if not unit or not UnitClass then return nil end

    local ok, classToken, classID = pcall(function()
        local _, token, id = UnitClass(unit)
        return token, id
    end)
    if not ok then return nil end

    -- 12.1 can restrict individual UnitClass return values. Only use values as
    -- Lua table keys after explicitly proving they are not secret. This key is
    -- used to keep a small per-class pool of managed aura containers so a
    -- recycled AuraButton never has to be recolored after it becomes forbidden.
    if _G.issecretvalue then
        if not _G.issecretvalue(classID) and type(classID) == "number" then
            return "ID:" .. tostring(classID)
        end
        if not _G.issecretvalue(classToken) and type(classToken) == "string" then
            return "CLASS:" .. classToken
        end
        return nil
    end

    if type(classID) == "number" then
        return "ID:" .. tostring(classID)
    end
    if type(classToken) == "string" and classToken ~= "" then
        return "CLASS:" .. classToken
    end

    return nil
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
        unitGeneration = 0,
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



-- Private cross-module API. These are implementation details, not public addon APIs.
EPI.CFG = CFG
EPI.WHITE = WHITE
EPI.R21_TEXTURE = R21_TEXTURE
EPI.RIBBON_TEXTURE = RIBBON_TEXTURE
EPI.CRIMP_TEXTURE = CRIMP_TEXTURE
EPI.BLIZZARD_STATUSBAR_TEXTURE = BLIZZARD_STATUSBAR_TEXTURE
EPI.BLIZZARD_CASTBAR_SPARK_TEXTURE = BLIZZARD_CASTBAR_SPARK_TEXTURE
EPI.BLIZZARD_CASTBAR_SPARK_ATLAS = BLIZZARD_CASTBAR_SPARK_ATLAS
EPI.OUTER_GLOW_TEXTURE = OUTER_GLOW_TEXTURE
EPI.NAMEPLATE_AGGRO_FLARE_ATLAS = NAMEPLATE_AGGRO_FLARE_ATLAS
EPI.NAMEPLATE_AGGRO_MASK_ATLAS = NAMEPLATE_AGGRO_MASK_ATLAS
EPI.CLASS_ICON = CLASS_ICON
EPI.ResolveSharedMediaStatusbar = ResolveSharedMediaStatusbar
EPI.ENEMY = ENEMY
EPI.NATIVE = NATIVE
EPI.NATIVE_UNIT_OWNER = NATIVE_UNIT_OWNER
EPI.NATIVE_ALPHA_HOOKED = NATIVE_ALPHA_HOOKED
EPI.NATIVE_ALPHA_GUARD = NATIVE_ALPHA_GUARD
EPI.CAST_STATE = CAST_STATE
EPI.AURA_FLARES = AURA_FLARES
EPI.TEST_UNIT = TEST_UNIT
EPI.TEST_ANCHOR_NAME = TEST_ANCHOR_NAME
EPI.ResolveEnemyPlateParent = ResolveEnemyPlateParent
EPI.FALLBACK_AURA_ICONS = FALLBACK_AURA_ICONS
EPI.TEST_AURA_DATA = TEST_AURA_DATA
EPI.IsTestUnit = IsTestUnit
EPI.GetFallbackAuraIcon = GetFallbackAuraIcon
EPI.CLASSIFICATION_COLORS = CLASSIFICATION_COLORS
EPI.REACTION_COLORS = REACTION_COLORS
EPI.SafeText = SafeText
EPI.SafeBoolFromSecret = SafeBoolFromSecret
EPI.AuraIsPermanent = AuraIsPermanent
EPI.AuraHasNameplateSignal = AuraHasNameplateSignal
EPI.SafeCall = SafeCall
EPI.SafeHide = SafeHide
EPI.SafeShow = SafeShow
EPI.SafeSetText = SafeSetText
EPI.SafeNumber = SafeNumber
EPI.SafeCount = SafeCount
EPI.CoerceBoolean = CoerceBoolean
EPI.ReadUnitIsUnit = ReadUnitIsUnit
EPI.SafeUnitIsUnit = SafeUnitIsUnit
EPI.GetEnemyBorderStyle = GetEnemyBorderStyle
EPI.AddBorder = AddBorder
EPI.SetBorderColor = SetBorderColor
EPI.UpdateCastIconBorder = UpdateCastIconBorder
EPI.IsAddonLoaded = IsAddonLoaded
EPI.ElvUIUnitNameplateEnabled = ElvUIUnitNameplateEnabled
EPI.IsElvUIEnemyNameplatesActive = IsElvUIEnemyNameplatesActive
EPI.IsPlaterActive = IsPlaterActive
EPI.IsBattlegroundOrArena = IsBattlegroundOrArena
EPI.UnitLooksLikePlayer = UnitLooksLikePlayer
EPI.ConfigColor = ConfigColor
EPI.ResolveHealthTextureValue = ResolveHealthTextureValue
EPI.UnitIsTaggedNPC = UnitIsTaggedNPC
EPI.GetUnitReactionColor = GetUnitReactionColor
EPI.GetUnitClassificationColor = GetUnitClassificationColor
EPI.ReadSafeHealthRatio = ReadSafeHealthRatio
EPI.GetSafeHealthRatio = GetSafeHealthRatio
EPI.UnitIsCurrentTarget = UnitIsCurrentTarget
EPI.UnitIsCurrentMouseover = UnitIsCurrentMouseover
EPI.UnitIsCurrentFocus = UnitIsCurrentFocus
EPI.ClampNumber = ClampNumber
EPI.ResolveEnemyPlateScale = ResolveEnemyPlateScale
EPI.ResolveEnemyHealthTexture = ResolveEnemyHealthTexture
EPI.ResolveEnemyAbsorbTexture = ResolveEnemyAbsorbTexture
EPI.ResolveEnemyCastTexture = ResolveEnemyCastTexture
EPI.UseStableHealthClip = UseStableHealthClip
EPI.ApplyEnemyHealthTextureTiling = ApplyEnemyHealthTextureTiling
EPI.GetNativeHealthStatusBarForPlate = GetNativeHealthStatusBarForPlate
EPI.ReadNativeHealthRatio = ReadNativeHealthRatio
EPI.GetNativeHealthRatio = GetNativeHealthRatio
EPI.GetNativeAbsorbRegionForPlate = GetNativeAbsorbRegionForPlate
EPI.GetRegionEffectiveWidth = GetRegionEffectiveWidth
EPI.GetNativeAbsorbRatio = GetNativeAbsorbRatio
EPI.UpdateEnemyHealthFillClip = UpdateEnemyHealthFillClip
EPI.ApplyEnemyHealthTexture = ApplyEnemyHealthTexture
EPI.ApplyEnemyHealthBackground = ApplyEnemyHealthBackground
EPI.UpdateEnemyAbsorb = UpdateEnemyAbsorb
EPI.ApplyEnemyCastTexture = ApplyEnemyCastTexture
EPI.UpdateEnemyCastSpark = UpdateEnemyCastSpark
EPI.NativeEnemyClassColorsEnabled = NativeEnemyClassColorsEnabled
EPI.ApplyDirectEnemyClassColor = ApplyDirectEnemyClassColor
EPI.GetSafeEnemyClassPoolKey = GetSafeEnemyClassPoolKey
EPI.ApplyNativeEnemyClassColor = ApplyNativeEnemyClassColor
EPI.ApplyEnemyPlayerClassColor = ApplyEnemyPlayerClassColor
EPI.ShouldUsePlayerHealthClassColor = ShouldUsePlayerHealthClassColor
EPI.GetUnitColor = GetUnitColor
EPI.GetUnitNameColor = GetUnitNameColor
EPI.SetRegionAlpha = SetRegionAlpha
EPI.SetTextureAlpha = SetTextureAlpha
EPI.SetFrameTreeAlpha = SetFrameTreeAlpha
EPI.HideFrameTree = HideFrameTree
EPI.ShowFrameTree = ShowFrameTree
EPI.SetNativeFontStringsAlpha = SetNativeFontStringsAlpha
EPI.SetNativeNamesAlpha = SetNativeNamesAlpha
EPI.HideNativeNames = HideNativeNames
EPI.ShowNativeNames = ShowNativeNames
EPI.HideNativeRegionList = HideNativeRegionList
EPI.ResolveNativeEnemyUnitFrame = ResolveNativeEnemyUnitFrame
EPI.GetFrameEffectiveScale = GetFrameEffectiveScale
EPI.ResolveNativeEnemyVisualScale = ResolveNativeEnemyVisualScale
EPI.IsForbiddenFrame = IsForbiddenFrame
EPI.EnsureNativeEnemyAlphaHook = EnsureNativeEnemyAlphaHook
EPI.RestoreNativeEnemy = RestoreNativeEnemy
EPI.HideNativeEnemy = HideNativeEnemy
EPI.SuppressNativeCast = SuppressNativeCast
EPI.CreateStatusBar = CreateStatusBar
EPI.EnsureEnemyPlate = EnsureEnemyPlate
EPI.HideEnemyPlateVisual = HideEnemyPlateVisual
EPI.UpdateEnemyObjectiveFlash = UpdateEnemyObjectiveFlash
EPI.VALID_POINTS = VALID_POINTS
EPI.SafePoint = SafePoint
EPI.AURA_PREFIX = AURA_PREFIX
EPI.AURA_CATEGORIES = AURA_CATEGORIES
EPI.SELECTABLE_AURA_SETTING_PREFIX = SELECTABLE_AURA_SETTING_PREFIX
EPI.AuraConfig = AuraConfig
EPI.GetAuraLayoutMetrics = GetAuraLayoutMetrics
EPI.GetAuraAttachFrame = GetAuraAttachFrame
EPI.EnsureAuraCategoryFrame = EnsureAuraCategoryFrame
EPI.SetupAuraCategoryFrame = SetupAuraCategoryFrame
EPI.SetupEnemyLayout = SetupEnemyLayout

-- BattleMender.lua
-- Stable baseline build
-- Native nameplate build - ElvUI independent
-- Wow 12.x
BattleMender = BattleMender or {}

local ADDON = CreateFrame("Frame", "BattleMenderFrame")
BattleMender.Frame = ADDON

local INIT_DONE = false

-- Read the packaged TOC version so login text and the options footer always
-- stay synchronized with the release archive.
function BattleMender.GetVersion()
    local getter = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if getter then
        local ok, version = pcall(getter, "BattleMender", "Version")
        if ok and type(version) == "string" and version ~= "" then
            return version
        end
    end

    return "unknown"
end

-- Never store BattleMender state directly on Blizzard nameplate frames.
-- Writing addon fields onto Blizzard-owned frames/regions can taint later secure
-- aura/cast/health update paths.
BattleMender._State = BattleMender._State or setmetatable({}, { __mode = "k" })
BattleMender._Overlays = BattleMender._Overlays or setmetatable({}, { __mode = "k" })
local BM_STATE = BattleMender._State
local BM_OVERLAYS = BattleMender._Overlays

function BattleMender.GetState(frame)
    local state = BM_STATE[frame]
    if not state then
        state = {}
        BM_STATE[frame] = state
    end
    return state
end

-------------------------------------------------
-- Plate Cleaner Pipeline
-------------------------------------------------
function BattleMender.CleanPlate(frame)
    if not frame then return end

    local overlay = BattleMender._Overlays and BattleMender._Overlays[frame]
    if not overlay then return end

    if BattleMender.HideHealerVisuals then BattleMender.HideHealerVisuals(overlay) end

    if overlay.haloFrame then overlay.haloFrame:Hide() end
    if overlay.damagedFrame then overlay.damagedFrame:Hide() end
    if overlay.specFrame then overlay.specFrame:Hide() end
    if overlay.ringFrame then overlay.ringFrame:Hide() end
	if overlay.accentFrame then overlay.accentFrame:Hide() end
    if BattleMender.HideObjectiveBadge then
        BattleMender.HideObjectiveBadge(overlay)
    elseif overlay.objectiveFrame then
        overlay.objectiveFrame:Hide()
    end

    if overlay.healthOverlay then overlay.healthOverlay:Hide() end
    if overlay.healthClipFrame then overlay.healthClipFrame:Hide() end
    if overlay.healthSpecFrame then overlay.healthSpecFrame:Hide() end
    if overlay.healthSpecIcon then overlay.healthSpecIcon:Hide() end
    if overlay.healthSpecMask then overlay.healthSpecMask:Hide() end

    if overlay.damagedSpecIcon then overlay.damagedSpecIcon:Hide() end
    if overlay.pulseOverlay then overlay.pulseOverlay:Hide() end
    if overlay.specIcon then overlay.specIcon:Hide() end
    if overlay.specGlow then overlay.specGlow:Hide() end
    if overlay.classRing then overlay.classRing:Hide() end
    if overlay.ringGlow then overlay.ringGlow:Hide() end
    if overlay.accentOverlay then overlay.accentOverlay:Hide() end
    if overlay.accentGlow then overlay.accentGlow:Hide() end
    if overlay.haloGlow then overlay.haloGlow:Hide() end
    if overlay.hitTestFrame then overlay.hitTestFrame:Hide() end
    if overlay.debugBox then overlay.debugBox:Hide() end
end

-------------------------------------------------
-- Saved Variables
-------------------------------------------------

BattleMenderDB = BattleMenderDB or {}

-- Friendly border definitions live in one place so the renderer, preview and
-- options menu all agree on the same texture names and automatic fit. The fit
-- values are calibrated to keep the central circular opening approximately the
-- same size when swapping between normal ring/cogwheel textures. Shield-shaped
-- assets are retained with their legacy fit for now; they need art-specific
-- treatment rather than circular-opening normalization.
BattleMender.FriendlyBorderDefinitions = {
    -- fit: geometric normalization based on the transparent circular opening.
    -- visualBias: small art-specific correction chosen by eye after live testing.
    -- Final size = iconSize * fit * visualBias * userFineTune.
    Ring_10px = { label = "Circle - Thin", fit = 1.01, visualBias = 1.05, texture = "Ring_10px", shape = "CIRCLE", calibrated = true },
    Ring_20px = { label = "Circle - Standard", fit = 1.10, visualBias = 1.05, texture = "Ring_20px", shape = "CIRCLE", calibrated = true },
    Ring_30px = { label = "Circle - Heavy", fit = 1.21, visualBias = 1.05, texture = "Ring_30px", shape = "CIRCLE", calibrated = true },
    Ring_40px = { label = "Circle - Extra Heavy", fit = 1.35, visualBias = 1.00, texture = "Ring_40px", shape = "CIRCLE", calibrated = true },
    Metal_Ring = { label = "Metal Ring", fit = 1.17, visualBias = 1.00, texture = "Metal_Ring", shape = "CIRCLE", calibrated = true },
    plastic_ring = { label = "Plastic Ring", fit = 1.31, visualBias = 1.05, texture = "plastic_ring", shape = "CIRCLE", calibrated = true },
    defensive_cogwheel = { label = "Defensive Cogwheel", fit = 1.49, visualBias = 1.00, texture = "defensive_cogwheel", shape = "COGWHEEL", calibrated = true },

    -- Shield variants deliberately retain legacy sizing. Their non-circular
    -- silhouettes need art-specific calibration rather than hole normalization.
    shield_easy = { label = "Shield - Compact", fit = 1.16, visualBias = 1.00, texture = "shield_easy", shape = "SHIELD", calibrated = false },
    shield_ring = { label = "Shield - Ring", fit = 1.16, visualBias = 1.00, texture = "shield_ring", shape = "SHIELD", calibrated = false },
    shield_tall = { label = "Shield - Tall", fit = 1.18, visualBias = 1.00, texture = "shield_tall", shape = "SHIELD", calibrated = false },
}

BattleMender.FriendlyBorderOrder = {
    "Ring_10px",
    "Ring_20px",
    "Ring_30px",
    "Ring_40px",
    "Metal_Ring",
    "plastic_ring",
    "defensive_cogwheel",
    "shield_easy",
    "shield_ring",
    "shield_tall",
}

BattleMender.FriendlyBorderAliases = {
    sheild_tall = "shield_tall",
}

function BattleMender.NormalizeFriendlyBorderKey(key)
    if type(key) ~= "string" then return key end
    return BattleMender.FriendlyBorderAliases[key] or key
end

function BattleMender.GetFriendlyBorderDefinition(key)
    key = BattleMender.NormalizeFriendlyBorderKey(key)
    return key and BattleMender.FriendlyBorderDefinitions[key], key
end

function BattleMender.GetFriendlyBorderFit(key)
    local definition = BattleMender.GetFriendlyBorderDefinition(key)
    return definition and definition.fit or 1.10
end

function BattleMender.GetFriendlyBorderVisualBias(key)
    local definition = BattleMender.GetFriendlyBorderDefinition(key)
    return definition and definition.visualBias or 1
end

function BattleMender.GetFriendlyBorderEffectiveFit(key)
    return BattleMender.GetFriendlyBorderFit(key) * BattleMender.GetFriendlyBorderVisualBias(key)
end

function BattleMender.GetFriendlyBorderTextureName(key)
    local definition, normalized = BattleMender.GetFriendlyBorderDefinition(key)
    return definition and definition.texture or normalized or "Ring_20px"
end

-- Affiliate badge art is centralized so live plates, the options menu and the
-- BattleMender-owned preview always expose the same supported texture set.
BattleMender.AffiliateBadgeDefinitions = {
    GOLD = { label = "Gold Star", texture = "Interface\\AddOns\\BattleMender\\Media\\gold_star.tga" },
    SILVER = { label = "Silver Star", texture = "Interface\\AddOns\\BattleMender\\Media\\silver_star.tga" },
    BRONZE = { label = "Bronze Star", texture = "Interface\\AddOns\\BattleMender\\Media\\bronze_star.tga" },
    DECO = { label = "Deco Star", texture = "Interface\\AddOns\\BattleMender\\Media\\deco_star.tga" },
}

BattleMender.AffiliateBadgeOrder = { "GOLD", "SILVER", "BRONZE", "DECO" }

function BattleMender.NormalizeAffiliateBadgeTextureKey(key)
    key = type(key) == "string" and key:upper() or "GOLD"
    return BattleMender.AffiliateBadgeDefinitions[key] and key or "GOLD"
end

function BattleMender.GetAffiliateBadgeDefinition(key)
    key = BattleMender.NormalizeAffiliateBadgeTextureKey(key)
    return BattleMender.AffiliateBadgeDefinitions[key], key
end

function BattleMender.GetAffiliateBadgeTexture(key)
    local definition = BattleMender.GetAffiliateBadgeDefinition(key)
    return definition.texture
end

local defaults = {
    profileSchemaVersion = 32,
    -- General
    enabled = true,
    debug = false,
    updateRate = 0.05,
    losUpdateRate = 0.15,
    clickSize = 66,
    -- Keep BattleMender friendly spec plates visually stable when Blizzard
    -- scales the native nameplate frame by distance/target state/overlap rules.
    -- The secure clickbox still follows Blizzard's native plate; this only
    -- counter-scales BattleMender-owned visual overlay frames.
    friendlyVisualScaleLock = false,
    debugClickbox = false,
    showLoginMessage = true,
    -- BattleMender-owned interaction controls. These operate on Blizzard's
    -- nameplate hit-test geometry rather than writing to another addon's DB.
    friendlyClickthrough = false,
    enemyPlateClickthrough = false,
    developerMode = false,

    -- Options UI state

    -- Friendly spec plate preview/test mode. This is BattleMender-owned UI, not
    -- a secure nameplate. It exists only to preview visual layering such as
    -- missing-health fill, damaged spec icon, border, and glass panel settings.
    friendlyTestMode = false,
    friendlyTestHealthPercent = 62,
    friendlyTestSpecID = 1467,
    friendlyTestClass = "DEATHKNIGHT",
    friendlyTestLOS = false,
    friendlyTestAffiliate = false,
    friendlyPreviewObjective = "NONE",
    friendlyPreviewAura = "NONE",
    friendlyTestAnchorPoint = "CENTER",
    friendlyTestXOffset = 303,
    friendlyTestYOffset = 97,

    -- Blizzard friendly-player presentation while BattleMender is loaded.
    -- These are independent so users can keep Blizzard's player name while
    -- suppressing the redundant native health bar/art behind BattleMender.
    hideBlizzardFriendlyHealthArt = true,
    hideBlizzardFriendlyPlayerName = false,

    -- Environment-specific presentation. Arena multipliers scale only
    -- BattleMender-owned visuals; the friendly click target follows the same
    -- multiplier when the protected size API can be updated out of combat.
    arenaFriendlyPlateScale = 1,
    arenaEnemyPlateScale = 1,
    -- Friendly visibility is environment-specific. Arena is intentionally
    -- excluded from these three-way switches and keeps the normal PvP view.
    friendlyGroupOnlyWorld = false,
    friendlyGroupOnlyRest = false,
    friendlyGroupOnlyBG = false,
    friendlyHideWorld = false,
    friendlyHideRest = false,
    friendlyHideBG = false,

    -- Instanced PvE behavior
    disableInDungeons = true,
    disableInRaids = true,
    disableInScenarios = false,
    restoreDefaultClickboxInPvE = true,
    instanceClickboxWidth = 110,
    instanceClickboxHeight = 45,

    -- Nameplate compatibility
    -- Hidden automatic fallback support for clients where Blizzard no longer
    -- exposes C_NamePlate.SetNamePlateFriendlySize. Global sizing keeps the
    -- friendly spec icon square-clickable; enemyVisualCompensation keeps enemy
    -- Blizzard plates visually usable when that global path is required.
    enemyVisualCompensation = true,
    enemyVisualWidth = 154,
    enemyVisualHeight = 45,

    -- Basic custom enemy plates for users without an active nameplate addon.
    -- This becomes especially important when the global square clickbox fallback
    -- is required, because Blizzard-native enemy plate art can otherwise inherit
    -- BattleMender's compact friendly clickbox size.
    enemyPlatesEnabled = true,
    enemyPlatesAutoDisableKnownMods = true,
    enemyPlateHideNativeBlizzard = true,
    enemyPlateWidth = 120,
    enemyPlateHealthHeight = 9,
    enemyPlateCastHeight = 8,
    enemyPlateNameSize = 8,
    enemyPlateScale = 1,
    enemyPlateNonTargetScale = 1,
    enemyPlateTargetScale = 1,
    enemyPlateFocusScale = 1.15,
    enemyPlateShowName = false,
    enemyPlateHidePlayerNamesInPvP = true,
    enemyPlateClassColorNames = true,
    enemyPlateClassColorHealth = true,
    enemyPlateClassColorHealthInPvP = true,
    enemyPlateClassificationColors = true,
    enemyPlateHealthTexture = "FLAT",
    enemyPlateHealthTextureCustom = "",
    enemyPlateTargetHealthTexture = "FLAT",
    enemyPlateTargetHealthTextureCustom = "",
    enemyPlateFocusHealthTexture = "RIBBON",
    enemyPlateFocusHealthTextureCustom = "",
    enemyPlateShowAbsorbs = true,
    enemyPlateAbsorbTexture = "SAME",
    enemyPlateAbsorbTextureCustom = "",
    enemyPlateAbsorbColorR = 0.72,
    enemyPlateAbsorbColorG = 0.92,
    enemyPlateAbsorbColorB = 1,
    enemyPlateAbsorbColorA = 0.85,
    enemyPlateHealthTextureTile = true,
    enemyPlateHealthTextureTileWidth = 64,
    enemyPlateHealthBackgroundR = 0.06666667014360428,
    enemyPlateHealthBackgroundG = 0.06666667014360428,
    enemyPlateHealthBackgroundB = 0.06666667014360428,
    enemyPlateHealthBackgroundA = 0.5951970219612122,

    -- Shared border for BattleMender-owned enemy elements. These settings were
    -- added before the release-prep branch but were accidentally omitted from
    -- Core defaults, so they could not survive a profile reload.
    enemyPlateBorderWidth = 1,
    enemyPlateBorderR = 0,
    enemyPlateBorderG = 0,
    enemyPlateBorderB = 0,
    enemyPlateBorderA = 1,

    -- ElvUI-style enemy plate colors / highlights.
    -- Tagged NPC matches ElvUI's default #999999. Neutral uses ElvUI's selection
    -- neutral #d9c25c instead of falling through to the flat NPC normal color.
    enemyPlateTaggedNPCR = 0.6,
    enemyPlateTaggedNPCG = 0.6,
    enemyPlateTaggedNPCB = 0.6,
    enemyPlateTaggedNPCA = 1,
    enemyPlateNeutralR = 0.8666667342185974,
    enemyPlateNeutralG = 0.7568628191947937,
    enemyPlateNeutralB = 0.3372549116611481,
    enemyPlateNeutralA = 1,
    enemyPlateSelectionHostileR = 0.82,
    enemyPlateSelectionHostileG = 0.26,
    enemyPlateSelectionHostileB = 0.26,
    enemyPlateSelectionHostileA = 1,
    enemyPlateSelectionUnfriendlyR = 1,
    enemyPlateSelectionUnfriendlyG = 0.5,
    enemyPlateSelectionUnfriendlyB = 0.2,
    enemyPlateSelectionUnfriendlyA = 1,
    enemyPlateSelectionFriendlyR = 0.29,
    enemyPlateSelectionFriendlyG = 0.69,
    enemyPlateSelectionFriendlyB = 0.31,
    enemyPlateSelectionFriendlyA = 1,
    enemyPlateSelectionPlayerR = 0.34,
    enemyPlateSelectionPlayerG = 0.51,
    enemyPlateSelectionPlayerB = 0.96,
    enemyPlateSelectionPlayerA = 1,
    enemyPlateSelectionPartyR = 0.42,
    enemyPlateSelectionPartyG = 0.23,
    enemyPlateSelectionPartyB = 1,
    enemyPlateSelectionPartyA = 1,
    enemyPlateSelectionPartyPVPR = 0.74,
    enemyPlateSelectionPartyPVPG = 0.2,
    enemyPlateSelectionPartyPVPB = 0.95,
    enemyPlateSelectionPartyPVPA = 1,
    enemyPlateSelectionFriendR = 0.2,
    enemyPlateSelectionFriendG = 1,
    enemyPlateSelectionFriendB = 0.43,
    enemyPlateSelectionFriendA = 1,
    enemyPlateSelectionDeadR = 1,
    enemyPlateSelectionDeadG = 1,
    enemyPlateSelectionDeadB = 1,
    enemyPlateSelectionDeadA = 1,
    enemyPlateSelectionBGFriendlyR = 0.08,
    enemyPlateSelectionBGFriendlyG = 0.61,
    enemyPlateSelectionBGFriendlyB = 0.32,
    enemyPlateSelectionBGFriendlyA = 1,
    enemyPlateClassificationWorldbossR = 0.78,
    enemyPlateClassificationWorldbossG = 0.65,
    enemyPlateClassificationWorldbossB = 0,
    enemyPlateClassificationWorldbossA = 1,
    enemyPlateClassificationEliteBossR = 0.7647059559822083,
    enemyPlateClassificationEliteBossG = 0.2352941334247589,
    enemyPlateClassificationEliteBossB = 0.6352941393852234,
    enemyPlateClassificationEliteBossA = 1,
    enemyPlateClassificationEliteMiniR = 0.49,
    enemyPlateClassificationEliteMiniG = 0.25,
    enemyPlateClassificationEliteMiniB = 0.78,
    enemyPlateClassificationEliteMiniA = 1,
    enemyPlateClassificationRareEliteR = 0.08,
    enemyPlateClassificationRareEliteG = 0.76,
    enemyPlateClassificationRareEliteB = 0.66,
    enemyPlateClassificationRareEliteA = 1,
    enemyPlateClassificationRareR = 0.28,
    enemyPlateClassificationRareG = 0.78,
    enemyPlateClassificationRareB = 0.02,
    enemyPlateClassificationRareA = 1,
    enemyPlateClassificationCasterR = 0.05,
    enemyPlateClassificationCasterG = 0.56,
    enemyPlateClassificationCasterB = 0.78,
    enemyPlateClassificationCasterA = 1,
    enemyPlatePreferTargetColor = false,
    enemyPlateTargetHighlightEnabled = true,
    enemyPlateTargetColorR = 0.729411780834198,
    enemyPlateTargetColorG = 0.7882353663444519,
    enemyPlateTargetColorB = 0.7921569347381592,
    enemyPlateTargetColorA = 0.1177661269903183,
    enemyPlateTargetBorderR = 0,
    enemyPlateTargetBorderG = 0,
    enemyPlateTargetBorderB = 0,
    enemyPlateTargetBorderA = 1,
    enemyPlateHoverHighlightEnabled = true,
    enemyPlateHoverColorR = 1,
    enemyPlateHoverColorG = 1,
    enemyPlateHoverColorB = 1,
    enemyPlateHoverColorA = 0.3538769781589508,
    enemyPlateLowHealthEnabled = true,
    enemyPlateLowHealthThreshold = 0.26,
    enemyPlateLowHealthR = 1,
    enemyPlateLowHealthG = 0.09803922474384308,
    enemyPlateLowHealthB = 0,
    enemyPlateLowHealthA = 1,
    enemyPlateTargetBackgroundTint = true,
    enemyPlateTargetGlowEnabled = true,
    enemyPlateLowHealthBackgroundTint = true,
    enemyPlateLowHealthGlowEnabled = false,
    enemyPlateLowHealthHalfR = 0.7215686440467834,
    enemyPlateLowHealthHalfG = 0.01568627543747425,
    enemyPlateLowHealthHalfB = 0,
    enemyPlateLowHealthHalfA = 0.7016785740852356,
    enemyPlateShowCastbar = true,

    -- Independent cast-bar geometry. These must live in defaults because the
    -- profile save path intentionally persists only known default keys.
    enemyPlateCastMatchHealthWidth = false,
    enemyPlateCastWidth = 104,
    enemyPlateCastAnchorPoint = "TOPLEFT",
    enemyPlateCastAttachPoint = "BOTTOMLEFT",
    enemyPlateCastXOffset = 0,
    enemyPlateCastYOffset = -1,

    enemyPlateCastIconSize = 15,
    enemyPlateCastIconPosition = "RIGHT",
    enemyPlateCastIconXOffset = 1,
    enemyPlateCastIconYOffset = 0,
    enemyPlateCastTextSize = 8,
    enemyPlateCastTexture = "FLAT",
    enemyPlateCastTextureCustom = "",
    enemyPlateCastNotInterruptibleTexture = "SAME",
    enemyPlateCastNotInterruptibleTextureCustom = "",
    enemyPlateCastSpark = true,
    enemyPlateCastInterruptibleR = 0.8666667342185974,
    enemyPlateCastInterruptibleG = 0.686274528503418,
    enemyPlateCastInterruptibleB = 0.2627451121807098,
    enemyPlateCastNotInterruptibleR = 0.6509804129600525,
    enemyPlateCastNotInterruptibleG = 0.6509804129600525,
    enemyPlateCastNotInterruptibleB = 0.6509804129600525,
    enemyPlateCastTargetPlayerR = 0.7882353663444519,
    enemyPlateCastTargetPlayerG = 0.4078431725502014,
    enemyPlateCastTargetPlayerB = 0.2431372702121735,
    enemyPlateCastInterruptedR = 0.9,
    enemyPlateCastInterruptedG = 0.2,
    enemyPlateCastInterruptedB = 0.2,
    enemyPlateCastInterruptedHoldTime = 0.75,
    enemyPlateNamePosition = "ABOVE",
    enemyPlateNameXOffset = 0,
    enemyPlateNameYOffset = 0,
    enemyPlateShowAuras = true,
    enemyPlateTestMode = false,
    enemyPlateTestAnchorPoint = "CENTER",
    enemyPlateTestXOffset = 383,
    enemyPlateTestYOffset = 120,
    -- The dedicated enemy Buff display excludes auras cast by the local player.
    enemyPlateBuffUsePlayerDispellable = false,
    enemyPlateBuffExcludePlayerDispellable = false,
    enemyPlateBuffUseRaidDispellable = false,
    enemyPlateBuffExcludeRaidDispellable = false,
    enemyPlateBuffUseDispellable = false,
    enemyPlateBuffExcludeDispellable = false,
    enemyPlateBuffUseImportant = false,
    enemyPlateBuffExcludeImportant = false,
    enemyPlateBuffUseRaidInCombat = false,
    enemyPlateBuffExcludeRaidInCombat = false,
    enemyPlateBuffOthersRaid = false,
    enemyPlateBuffOthersExcludeRaid = false,
    enemyPlateBuffOthersCancelable = false,
    enemyPlateBuffOthersExcludeCancelable = false,
    enemyPlateBuffOthersBigDefensive = true,
    enemyPlateBuffOthersExcludeBigDefensive = false,
    enemyPlateBuffOthersExternalDefensive = true,
    enemyPlateBuffOthersExcludeExternalDefensive = false,
    enemyPlateBuffOthersBlockPermanent = false,

    -- Debuff categories use the same include/exclude pairs as Buff categories.
    -- The legacy single value is retained only as an import fallback; active
    -- filtering reads the current enemyPlateDebuff* booleans below.
    enemyPlateAuraDebuffFilter = "PERSONAL",
    enemyPlateDebuffUsePersonal = false,
    -- These are the visible controls in Enemy Plates > Auras > Debuff Filters.
    enemyPlateAuraStackAuras = true,
    enemyPlateAuraDesaturate = false,
    enemyPlateAuraKeepSizeRatio = true,
    enemyPlateDebuffOnlyCastByYou = false,
    enemyPlateDebuffUseRaidDispellable = false,
    enemyPlateDebuffExcludeRaidDispellable = false,
    enemyPlateDebuffUseDispellable = false,
    enemyPlateDebuffExcludeDispellable = false,
    enemyPlateDebuffRaid = false,
    enemyPlateDebuffExcludeRaid = false,
    enemyPlateDebuffCrowdControl = true,
    enemyPlateDebuffExcludeCrowdControl = false,
    enemyPlateDebuffBlockPermanent = false,

    enemyPlateAuraAlign = "LEFT",
    enemyPlateAuraSize = 30,
    enemyPlateAuraPerRow = 5,
    enemyPlateAuraRows = 1,
    enemyPlateAuraSpacing = 1,
    enemyPlateAuraXOffset = -2,
    enemyPlateAuraYOffset = 4,
    enemyPlateAuraAttachTo = "HEALTH",
    enemyPlateAuraAnchorPoint = "BOTTOMLEFT",
    enemyPlateAuraAttachPoint = "TOPLEFT",
    enemyPlateAuraGrowthX = "RIGHT",
    enemyPlateAuraGrowthY = "UP",
    enemyPlateShowBuffs = true,
    enemyPlateBuffAurasTargetOnly = false,
    enemyPlateShowDebuffs = true,
    enemyPlateDebuffAurasTargetOnly = false,
    enemyPlatePersonalDebuffsOnly = false,

    -- Split aura layout. Buffs, Debuffs, Custom, and Danger render as separate
    -- groups with independent size, growth, anchoring, and filtering. The
    -- legacy enemyPlateAura* keys above remain as fallback values for profiles
    -- from earlier BattleMender builds.
    enemyPlateBuffAuraSize = 30,
    enemyPlateBuffAuraPerRow = 2,
    enemyPlateBuffAuraRows = 1,
    enemyPlateBuffAuraSpacing = 3,
    enemyPlateBuffAuraXOffset = -3,
    enemyPlateBuffAuraYOffset = 14,
    enemyPlateBuffAuraAttachTo = "HEALTH",
    enemyPlateBuffAuraAnchorPoint = "TOPRIGHT",
    enemyPlateBuffAuraAttachPoint = "TOPLEFT",
    enemyPlateBuffAuraGrowthX = "LEFT",
    enemyPlateBuffAuraGrowthY = "DOWN",
    enemyPlateBuffAuraAlign = "LEFT",
    enemyPlateBuffAuraDesaturate = false,
    enemyPlateBuffAuraKeepSizeRatio = true,
    enemyPlateBuffAuraCropSides = true,
    enemyPlateBuffAuraCooldownSwipe = true,

    enemyPlateDebuffAuraSize = 30,
    enemyPlateDebuffAuraPerRow = 2,
    enemyPlateDebuffAuraRows = 1,
    enemyPlateDebuffAuraSpacing = 3,
    enemyPlateDebuffAuraXOffset = 3,
    enemyPlateDebuffAuraYOffset = 12,
    enemyPlateDebuffAuraAttachTo = "HEALTH",
    enemyPlateDebuffAuraAnchorPoint = "TOPLEFT",
    enemyPlateDebuffAuraAttachPoint = "TOPRIGHT",
    enemyPlateDebuffAuraGrowthX = "RIGHT",
    enemyPlateDebuffAuraGrowthY = "DOWN",
    enemyPlateDebuffAuraAlign = "LEFT",
    enemyPlateDebuffAuraDesaturate = false,
    enemyPlateDebuffAuraKeepSizeRatio = false,
    enemyPlateDebuffAuraCropSides = true,
    enemyPlateDebuffAuraCooldownSwipe = true,

    enemyPlateCustomAurasEnabled = false,
    enemyPlateCustomAurasTargetOnly = true,
    -- Custom is a true third aura container: it can independently select
    -- native helpful and harmful categories. Buff filters are source-neutral;
    -- Debuffs can optionally limit every selected category to PLAYER sources.
    enemyPlateCustomShowBuffs = false,
    enemyPlateCustomShowDebuffs = true,
    enemyPlateCustomBuffUsePlayerDispellable = false,
    enemyPlateCustomBuffExcludePlayerDispellable = false,
    enemyPlateCustomBuffUseRaidDispellable = false,
    enemyPlateCustomBuffExcludeRaidDispellable = false,
    enemyPlateCustomBuffUseDispellable = false,
    enemyPlateCustomBuffExcludeDispellable = false,
    enemyPlateCustomBuffUseImportant = false,
    enemyPlateCustomBuffExcludeImportant = false,
    enemyPlateCustomBuffUseRaidInCombat = false,
    enemyPlateCustomBuffExcludeRaidInCombat = false,
    enemyPlateCustomBuffRaid = false,
    enemyPlateCustomBuffExcludeRaid = false,
    enemyPlateCustomBuffCancelable = false,
    enemyPlateCustomBuffExcludeCancelable = false,
    enemyPlateCustomBuffBigDefensive = false,
    enemyPlateCustomBuffExcludeBigDefensive = false,
    enemyPlateCustomBuffExternalDefensive = false,
    enemyPlateCustomBuffExcludeExternalDefensive = false,
    enemyPlateCustomBuffBlockPermanent = false,
    enemyPlateCustomDebuffOnlyCastByYou = true,
    enemyPlateCustomDebuffUseRaidDispellable = false,
    enemyPlateCustomDebuffExcludeRaidDispellable = false,
    enemyPlateCustomDebuffUseDispellable = false,
    enemyPlateCustomDebuffExcludeDispellable = false,
    enemyPlateCustomDebuffRaid = false,
    enemyPlateCustomDebuffExcludeRaid = false,
    enemyPlateCustomDebuffCrowdControl = false,
    enemyPlateCustomDebuffExcludeCrowdControl = true,
    enemyPlateCustomDebuffBlockPermanent = false,
    enemyPlateCustomAuraSize = 16,
    enemyPlateCustomAuraPerRow = 4,
    enemyPlateCustomAuraRows = 1,
    enemyPlateCustomAuraSpacing = 4,
    enemyPlateCustomAuraXOffset = -1,
    enemyPlateCustomAuraYOffset = 15,
    enemyPlateCustomAuraAttachTo = "HEALTH",
    enemyPlateCustomAuraAnchorPoint = "BOTTOMRIGHT",
    enemyPlateCustomAuraAttachPoint = "BOTTOMRIGHT",
    enemyPlateCustomAuraGrowthX = "LEFT",
    enemyPlateCustomAuraGrowthY = "UP",
    enemyPlateCustomAuraAlign = "LEFT",
    enemyPlateCustomAuraDesaturate = true,
    enemyPlateCustomAuraKeepSizeRatio = true,
    enemyPlateCustomAuraCooldownSwipe = false,
    enemyPlateCustomAuraFlat = true,

    -- Important is a fourth independent aura container. The internal Danger
    -- prefix is retained for saved-profile compatibility. It reuses Custom's
    -- native-category model but has separate filters, visibility, and layout.
    -- The release baseline enables Important with the maintainer-tested filters
    -- and layout below; existing profiles retain their own enabled state.
    enemyPlateDangerAurasEnabled = true,
    enemyPlateDangerAurasTargetOnly = true,
    enemyPlateDangerShowBuffs = false,
    enemyPlateDangerShowDebuffs = true,
    -- Aura-driven Progressive flare. This is intentionally independent of the
    -- Important container so any visible aura category can drive the effect.
    enemyPlateAuraFlareEnabled = true,
    enemyPlateAuraFlareTriggerCategory = "DANGER", -- BUFF / DEBUFF / CUSTOM / DANGER (Important)
    enemyPlateAuraFlareColorMode = "CUSTOM",
    enemyPlateAuraFlareHeight = 31,
    enemyPlateAuraFlareDensity = 1,
    enemyPlateAuraFlareYOffset = -2,
    enemyPlateAuraFlareOpacity = 0.88,
    enemyPlateAuraFlareR = 0.9960784912109375,
    enemyPlateAuraFlareG = 0.07058823853731155,
    enemyPlateAuraFlareB = 0,

    -- Legacy 14.7-14.11 Important-flare keys. Kept in defaults only so schema
    -- migration can distinguish old untouched values from custom values. Runtime
    -- rendering no longer reads these keys.
    enemyPlateDangerHealthGlowEnabled = true,
    enemyPlateDangerHealthGlowColorMode = "CUSTOM",
    enemyPlateDangerHealthGlowHeight = 31,
    enemyPlateDangerHealthGlowYOffset = -2,
    enemyPlateDangerHealthGlowOpacity = 0.88,
    enemyPlateDangerHealthGlowR = 0.9960784912109375,
    enemyPlateDangerHealthGlowG = 0.07058823853731155,
    enemyPlateDangerHealthGlowB = 0,
    enemyPlateDangerHealthGlowA = 0.88, -- legacy alpha fallback for older profiles
    enemyPlateDangerBuffUsePlayerDispellable = false,
    enemyPlateDangerBuffExcludePlayerDispellable = false,
    enemyPlateDangerBuffUseRaidDispellable = false,
    enemyPlateDangerBuffExcludeRaidDispellable = false,
    enemyPlateDangerBuffUseDispellable = false,
    enemyPlateDangerBuffExcludeDispellable = false,
    enemyPlateDangerBuffUseImportant = true,
    enemyPlateDangerBuffExcludeImportant = false,
    enemyPlateDangerBuffUseRaidInCombat = false,
    enemyPlateDangerBuffExcludeRaidInCombat = false,
    enemyPlateDangerBuffRaid = false,
    enemyPlateDangerBuffExcludeRaid = false,
    enemyPlateDangerBuffCancelable = false,
    enemyPlateDangerBuffExcludeCancelable = false,
    enemyPlateDangerBuffBigDefensive = false,
    enemyPlateDangerBuffExcludeBigDefensive = true,
    enemyPlateDangerBuffExternalDefensive = false,
    enemyPlateDangerBuffExcludeExternalDefensive = true,
    enemyPlateDangerBuffBlockPermanent = false,
    enemyPlateDangerDebuffOnlyCastByYou = false,
    enemyPlateDangerDebuffUseRaidDispellable = false,
    enemyPlateDangerDebuffExcludeRaidDispellable = false,
    enemyPlateDangerDebuffUseDispellable = false,
    enemyPlateDangerDebuffExcludeDispellable = false,
    enemyPlateDangerDebuffRaid = false,
    enemyPlateDangerDebuffExcludeRaid = false,
    enemyPlateDangerDebuffCrowdControl = false,
    enemyPlateDangerDebuffExcludeCrowdControl = false,
    enemyPlateDangerDebuffBlockPermanent = false,
    enemyPlateDangerAuraSize = 28,
    enemyPlateDangerAuraPerRow = 2,
    enemyPlateDangerAuraRows = 1,
    enemyPlateDangerAuraSpacing = 6,
    enemyPlateDangerAuraXOffset = 0,
    enemyPlateDangerAuraYOffset = 19,
    enemyPlateDangerAuraAttachTo = "HEALTH",
    enemyPlateDangerAuraAnchorPoint = "CENTER",
    enemyPlateDangerAuraAttachPoint = "CENTER",
    enemyPlateDangerAuraGrowthX = "CENTER",
    enemyPlateDangerAuraGrowthY = "DOWN",
    enemyPlateDangerAuraAlign = "CENTER",
    enemyPlateDangerAuraDesaturate = false,
    enemyPlateDangerAuraKeepSizeRatio = true,
    enemyPlateDangerAuraCooldownSwipe = true,
    enemyPlateDangerAuraFlat = true,

    -- Experimental class-based enemy PvP voice alerts. Disabled by default for
    -- existing/release profiles until the class/phrase mapping is validated in
    -- live battlegrounds. Runtime uses Blizzard's native 12.1 aura-sound API.
    enemyClassAudioEnabled = false,
    enemyClassAudioWorldTestEnabled = true,
    enemyClassAudioImportantEnabled = true,
    enemyClassAudioDefensiveEnabled = true,
    enemyClassAudioChannel = "Master",

    enemyPlateCastUpdateRate = 0.01,
    enemyPlatePortraitEnabled = false,
    enemyPlatePortraitHideInBG = true,
    enemyPlatePortraitSize = 24,
    enemyPlatePortraitMode = "CLASS",
    enemyPlatePortraitPosition = "LEFT",
    enemyPlatePortraitXOffset = 28,
    enemyPlatePortraitYOffset = 19,
    enemyPlateObjectiveIndicator = true,
    enemyPlateObjectiveFlashEnabled = true,

    -- Positioning
    iconSize = 50,
    anchorMode = "TOP",
    anchorPoint = "TOP",
    anchorX = 0,
    anchorY = 0,

    -- Legacy damage color fallback.
    -- Kept temporarily for DB migration only; active drawing uses damageIcon*.
    iconTextureMode = "SOLID",
    iconAlpha = 1,
    iconUseClassColor = false,
    iconColorR = 1,
    iconColorG = 0.2039215862751,
    iconColorB = 0,

    -- Spec icon. Texture mode is intentionally fixed to spec icon.
    specIconEnabled = true,
    specIconAlpha = 1,
    specIconDesaturate = false,
    specIconUseClassColor = false,
    specIconColorR = 1,
    specIconColorG = 1,
    specIconColorB = 1,
    specIconBlendMode = "MOD",

    -- Optional healer role art; existing profiles retain their spec icons.
    healerCrossEnabled = false,
    -- Healthy healer background defaults to the friendly healer/plate
    -- occupant's class color. Missing health continues to use the normal
    -- damaged presentation. CUSTOM retains a manual RGB fallback.
    -- Healer color modes use the healer/plate occupant (target) class.
    -- CUSTOM retains the manual RGB fallback below.
    healerBackgroundColorMode = "CLASS",
    healerBackgroundUseClassColor = true, -- legacy compatibility key
    healerBackgroundBrightness = 1,
    healerBackgroundR = 0.035,
    healerBackgroundG = 0.035,
    healerBackgroundB = 0.045,
    healerCrossScale = 0.9,
    healerCrossR = 0.22,
    healerCrossG = 1,
    healerCrossB = 0.12,
    healerDamageCrossR = 1,
    healerDamageCrossG = 0.82,
    healerDamageCrossB = 0.16,
    healerControlEnabled = true,
    -- CC badge accent. CLASS always means the healer/plate occupant's class.
    -- The badge uses the actual hard-CC/silence aura icon.
    healerControlColorMode = "CLASS",
    healerControlR = 1,
    healerControlG = 0.65,
    healerControlB = 0.06,
    healerControlBadgeScale = 0.64,
    healerControlAngle = 138,
    healerControlDistanceScale = 0.58,
    friendlyTestHealerControl = false,

    -- Friendly affiliation system. HOME is the manually formed party/raid; in
    -- battlegrounds it remains distinct from Blizzard's temporary INSTANCE raid.
    affiliateParty = true,
    affiliateGuild = true,
    affiliateFriend = true,
    affiliateBadgeEnabled = true,
    affiliateBadgeTexture = "GOLD",
    affiliateBadgeScale = 0.56,
    affiliateBadgeAngle = 42,
    affiliateBadgeDistanceScale = 0.64,
    -- Per-unit BattleMender visual emphasis only. Blizzard exposes friendly
    -- clickbox sizing globally, so this intentionally does not resize clickboxes.
    affiliatePlateScale = 1.15,

    -- Hide Friendly Plates can retain selected social relationships.
    friendlyHideKeepParty = true,
    friendlyHideKeepGuild = true,
    friendlyHideKeepFriends = true,

    -- Arena-only friendly CC voice alerts. Fancy voice is reserved for the
    -- healer; Deep voice is used for other friendly arena players.
    arenaCCVoiceEnabled = true,
    arenaCCVoiceHealerEnabled = true,
    arenaCCVoiceHealerPack = "FANCY",
    arenaCCVoiceNonHealerEnabled = true,
    arenaCCVoiceMinDuration = 1.0,
    arenaCCVoiceRotateAlternates = true,
    arenaCCVoiceChannel = "Master",

    -- Damaged / missing-health visual
    damageIconAlpha = 1,
    damageIconR = 0.7960785031318665,
    damageIconG = 0.09803922474384308,
    damageIconB = 0,
    damageIconBlendMode = "BLEND",

    -- Fallback when spec is unknown
    damageIconFallbackR = 1,
    damageIconFallbackG = 0.02,
    damageIconFallbackB = 0.02,
    damageIconFallbackBlendMode = "BLEND",

    -- Class ring
    ringEnabled = true,
    ringTexture = "plastic_ring",
    -- Automatic per-texture fit handles normal size differences. This value is
    -- only a small user adjustment around that calibrated fit.
    ringFineTune = 1.00,
    ringAlpha = 1,

    -- Accent Overlay
    accentOverlayEnabled = true,
    accentOverlayTexture = "Glass_Ring",
    accentOverlayScale = 0.95,
    accentOverlayAlpha = 1,
    accentOverlayBlendMode = "ADD",
    accentOverlayUseClassColor = false,
    accentOverlayColorR = 1,
    accentOverlayColorG = 1,
    accentOverlayColorB = 1,

    -- Accent Overlay hover
    accentOverlayGlowEnabled = false,
    accentOverlayGlowBrightness = 0.15,
    accentOverlayGlowFadeIn = 0.15,
    accentOverlayGlowFadeOut = 0.15,

    -- Health overlay
    healthEnable = true,
    healthOverlayAlpha = 1,
    healthOverlayBlendMode = "BLEND",
    healthOverlayUseClassColor = false,
    healthOverlayColorR = 0.8392157554626465,
    healthOverlayColorG = 0.8156863451004028,
    healthOverlayColorB = 0.8196079134941101,
    healthOverlayReverseFill = true,

    -- Hover / pulse effects
    specGlowEnabled = true,
    specGlowBrightness = 0.2,
    specGlowFadeIn = 0.15,
    specGlowFadeOut = 0.2,

    ringGlowEnabled = true,
    ringGlowBrightness = 0.4,
    ringGlowFadeIn = 0.07,
    ringGlowFadeOut = 0.1,

    pulseEnable = true,
    pulseSpeed = 0.15,
    pulseIntensity = 0.6,
    pulseOverlayEnable = false,
    pulseOverlayTexture = "Circle_Smooth2",
    pulseOverlayBlend = "ADD",
    pulseOverlayAlpha = 1,

    haloEnabled = false,
    haloGlowTexture = "Circle_Halo_1",
    haloGlowSizeScale = 2,
    haloGlowAlpha = 0.5,

    -- Line of sight state
    losIconAlpha = 0.8,

    losSpecIconDesaturate = false,
    losSpecIconAlpha = 0.5,
    losSpecIconBlendMode = "BLEND",

    losHealthOverlayAlpha = 0.4,
    losHealthOverlayBlendMode = "BLEND",
    losHealthOverlayUseClassColor = false,
    losHealthOverlayColorR = 0.94901967048645,
    losHealthOverlayColorG = 1,
    losHealthOverlayColorB = 1,
    losHealthOverlayAutoCompensate = false,
    losHealthOverlayCompensationStrength = 0,

    -- Damaged / missing-health visual while out of line of sight
    losDamageIconAlpha = 0.4,
    losDamageIconBlendMode = "BLEND",

    -- Class ring while out of line of sight. Keep LoS intentionally simple:
    -- standard ring, reduced opacity, and no accent overlay by default.
    losRingTexture = "Ring_20px",
    losRingAlpha = 0.7,

    -- LoS Accent Overlay
    losAccentOverlayTexture = "NONE",
    losAccentOverlayScale = 0.8500000000000001,
    losAccentOverlayAlpha = 1,
    losAccentOverlayBlendMode = "BLEND",
    losAccentOverlayUseClassColor = true,
    losAccentOverlayColorR = 1,
    losAccentOverlayColorG = 1,
    losAccentOverlayColorB = 1,

    -- LoS Accent Overlay hover
    losAccentOverlayGlowEnabled = false,
    losAccentOverlayGlowBrightness = 0.1,
    losAccentOverlayGlowFadeIn = 0.6000000000000001,
    losAccentOverlayGlowFadeOut = 0.7000000000000001,


    -- Friendly defensive and immunity displays. The renderer uses Blizzard's
    -- 12.1 AuraContainer to select, show, and time the configured helpful
    -- auras; these keys control only BattleMender-owned presentation.
    -- Keep this opt-in until AuraContainer's inactive-button lifecycle is
    -- confirmed on live. The PTR renderer can otherwise paint blank immunity
    -- rings over ordinary friendly spec icons.
    defensiveDisplayEnabled = false,
    defensiveVisualRevision = 5,
    majorDefensiveEnabled = false,
    majorDefensiveBadgeScale = 0.72,
    majorDefensiveLayer = "BEHIND",
    majorDefensiveDistanceScale = 0.53,
    majorDefensiveAngle = 42,
    majorDefensiveBorderTexture = "NORMAL",
    majorDefensiveBorderScale = 1.18,
    majorDefensiveBorderAlpha = 1,
    majorDefensiveBorderColorMode = "AUTO",
    majorDefensiveCustomR = 0.3,
    majorDefensiveCustomG = 0.72,
    majorDefensiveCustomB = 1,
    objectivesEnabled = true,
    objectivesBadgeScale = 0.72,
    objectivesLayer = "BEHIND",
    objectivesDistanceScale = 0.53,
    objectivesAngle = 42,
    objectivesBorderTexture = "COGWHEEL",
    objectivesBorderScale = 1.18,
    objectivesBorderAlpha = 1,
    objectivesBorderColorMode = "AUTO",
    objectivesCustomR = 0.3,
    objectivesCustomG = 0.72,
    objectivesCustomB = 1,
    objectivesGlowEnabled = true,
    objectivesGlowAlpha = 0.46,
    objectivesGlowSpeed = 0.9,
    objectivesGlowScale = 2.25,
    objectivesPulse = true,
    objectivesPulseSpeed = 0.9,
    immunityDisplayEnabled = false,
    immunityReplaceSpecIcon = true,
    immunityIconScale = 1,
    immunityRingScale = 1.18,
    immunityRingAlpha = 0.92,
    immunityGlowEnabled = true,
    immunityGlowAlpha = 0.42,
    immunityGlowSpeed = 0.9,
    immunityCooldownSwipe = true,
    immunityCooldownRingAlpha = 0.92,
}

BattleMender.Defaults = defaults

local CFG = {}
BattleMender.CFG = CFG 

local ENEMY_AURA_FILTER_STATE_KEYS = {
    { "enemyPlateBuffUsePlayerDispellable", "enemyPlateBuffExcludePlayerDispellable" },
    { "enemyPlateBuffUseRaidDispellable", "enemyPlateBuffExcludeRaidDispellable" },
    { "enemyPlateBuffUseDispellable", "enemyPlateBuffExcludeDispellable" },
    { "enemyPlateBuffUseImportant", "enemyPlateBuffExcludeImportant" },
    { "enemyPlateBuffUseRaidInCombat", "enemyPlateBuffExcludeRaidInCombat" },
    { "enemyPlateBuffOthersRaid", "enemyPlateBuffOthersExcludeRaid" },
    { "enemyPlateBuffOthersCancelable", "enemyPlateBuffOthersExcludeCancelable" },
    { "enemyPlateBuffOthersBigDefensive", "enemyPlateBuffOthersExcludeBigDefensive" },
    { "enemyPlateBuffOthersExternalDefensive", "enemyPlateBuffOthersExcludeExternalDefensive" },
    { "enemyPlateDebuffUseRaidDispellable", "enemyPlateDebuffExcludeRaidDispellable" },
    { "enemyPlateDebuffUseDispellable", "enemyPlateDebuffExcludeDispellable" },
    { "enemyPlateDebuffRaid", "enemyPlateDebuffExcludeRaid" },
    { "enemyPlateDebuffCrowdControl", "enemyPlateDebuffExcludeCrowdControl" },
    { "enemyPlateCustomBuffUsePlayerDispellable", "enemyPlateCustomBuffExcludePlayerDispellable" },
    { "enemyPlateCustomBuffUseRaidDispellable", "enemyPlateCustomBuffExcludeRaidDispellable" },
    { "enemyPlateCustomBuffUseDispellable", "enemyPlateCustomBuffExcludeDispellable" },
    { "enemyPlateCustomBuffUseImportant", "enemyPlateCustomBuffExcludeImportant" },
    { "enemyPlateCustomBuffUseRaidInCombat", "enemyPlateCustomBuffExcludeRaidInCombat" },
    { "enemyPlateCustomBuffRaid", "enemyPlateCustomBuffExcludeRaid" },
    { "enemyPlateCustomBuffCancelable", "enemyPlateCustomBuffExcludeCancelable" },
    { "enemyPlateCustomBuffBigDefensive", "enemyPlateCustomBuffExcludeBigDefensive" },
    { "enemyPlateCustomBuffExternalDefensive", "enemyPlateCustomBuffExcludeExternalDefensive" },
    { "enemyPlateCustomDebuffUseRaidDispellable", "enemyPlateCustomDebuffExcludeRaidDispellable" },
    { "enemyPlateCustomDebuffUseDispellable", "enemyPlateCustomDebuffExcludeDispellable" },
    { "enemyPlateCustomDebuffRaid", "enemyPlateCustomDebuffExcludeRaid" },
    { "enemyPlateCustomDebuffCrowdControl", "enemyPlateCustomDebuffExcludeCrowdControl" },
    { "enemyPlateDangerBuffUsePlayerDispellable", "enemyPlateDangerBuffExcludePlayerDispellable" },
    { "enemyPlateDangerBuffUseRaidDispellable", "enemyPlateDangerBuffExcludeRaidDispellable" },
    { "enemyPlateDangerBuffUseDispellable", "enemyPlateDangerBuffExcludeDispellable" },
    { "enemyPlateDangerBuffUseImportant", "enemyPlateDangerBuffExcludeImportant" },
    { "enemyPlateDangerBuffUseRaidInCombat", "enemyPlateDangerBuffExcludeRaidInCombat" },
    { "enemyPlateDangerBuffRaid", "enemyPlateDangerBuffExcludeRaid" },
    { "enemyPlateDangerBuffCancelable", "enemyPlateDangerBuffExcludeCancelable" },
    { "enemyPlateDangerBuffBigDefensive", "enemyPlateDangerBuffExcludeBigDefensive" },
    { "enemyPlateDangerBuffExternalDefensive", "enemyPlateDangerBuffExcludeExternalDefensive" },
    { "enemyPlateDangerDebuffUseRaidDispellable", "enemyPlateDangerDebuffExcludeRaidDispellable" },
    { "enemyPlateDangerDebuffUseDispellable", "enemyPlateDangerDebuffExcludeDispellable" },
    { "enemyPlateDangerDebuffRaid", "enemyPlateDangerDebuffExcludeRaid" },
    { "enemyPlateDangerDebuffCrowdControl", "enemyPlateDangerDebuffExcludeCrowdControl" },
}

local function NormalizeEnemyAuraFilterStates(target)
    if type(target) ~= "table" then return end

    -- Imported or manually edited profiles can set both booleans. Inclusion
    -- wins so each category always resolves to exactly one visible state.
    for _, keys in ipairs(ENEMY_AURA_FILTER_STATE_KEYS) do
        if target[keys[1]] == true then
            target[keys[2]] = false
        end
    end
end

-------------------------------------------------
-- Transient / session-only options
-------------------------------------------------
local TRANSIENT_TEST_MODE_KEYS = {
    friendlyTestMode = true,
    enemyPlateTestMode = true,
    friendlyTestHealerControl = true,
    friendlyTestAffiliate = true,
}

local function ClearTransientTestModesFromTable(tbl)
    if type(tbl) ~= "table" then return end

    for key in pairs(TRANSIENT_TEST_MODE_KEYS) do
        if tbl[key] ~= nil then
            tbl[key] = false
        end
    end
end

local function DisableRuntimeTestModeVisuals()
    if BattleMender.HideFriendlyTestMode then
        BattleMender.HideFriendlyTestMode()
    end

    if BattleMender.RefreshEnemyPlateTestMode then
        BattleMender.RefreshEnemyPlateTestMode()
    end

    if BattleMender.Defensives and BattleMender.Defensives.HidePreview then
        BattleMender.Defensives.HidePreview()
    end
end

-- Prototype-era option tables were removed after the native settings UI became
-- explicit and user-facing. Keep settings definitions in defaults + Options.lua.

-- Debug print  /run BattleMender.CFG.debug=true
local function Debug(...)
    if not CFG.debug then
        return
    end
    
    print("|cff33ff99BattleMender:|r", ...)
end

BattleMender.Debug = Debug

-------------------------------------------------
-- Config load/save
-------------------------------------------------

local function CopyDefaultValue(v)
    if type(v) ~= "table" then
        return v
    end

    local out = {}
    for k, child in pairs(v) do
        out[k] = CopyDefaultValue(child)
    end
    return out
end

local DB_MIGRATIONS = {
    showClickbox = "debugClickbox",

    topIconEnable = "specIconEnabled",
    topIconAlpha = "specIconAlpha",
    topIconUseClassColor = "specIconUseClassColor",
    topIconColorR = "specIconColorR",
    topIconColorG = "specIconColorG",
    topIconColorB = "specIconColorB",
    topIconBlendMode = "specIconBlendMode",

    borderEnable = "ringEnabled",
    borderTexture = "ringTexture",
    borderScale = "ringScale",
    borderAlpha = "ringAlpha",

    healthAlpha = "healthOverlayAlpha",
    healthBlendMode = "healthOverlayBlendMode",
    healthUseClassColor = "healthOverlayUseClassColor",
    healthColorR = "healthOverlayColorR",
    healthColorG = "healthOverlayColorG",
    healthColorB = "healthOverlayColorB",
    healthReverseFill = "healthOverlayReverseFill",

    hoverTopEnable = "specGlowEnabled",
    hoverTopBrightness = "specGlowBrightness",
    hoverTopFadeIn = "specGlowFadeIn",
    hoverTopFadeOut = "specGlowFadeOut",
    hoverRingEnable = "ringGlowEnabled",
    hoverRingBrightness = "ringGlowBrightness",
    hoverRingFadeIn = "ringGlowFadeIn",
    hoverRingFadeOut = "ringGlowFadeOut",

    haloEnable = "haloEnabled",

    losTopIconAlpha = "losSpecIconAlpha",
    losTopIconBlendMode = "losSpecIconBlendMode",
    losHealthAlpha = "losHealthOverlayAlpha",
    losHealthBlendMode = "losHealthOverlayBlendMode",
    losHealthUseClassColor = "losHealthOverlayUseClassColor",
    losHealthColorR = "losHealthOverlayColorR",
    losHealthColorG = "losHealthOverlayColorG",
    losHealthColorB = "losHealthOverlayColorB",
    losBorderAlpha = "losRingAlpha",
}

local BORDER_TEXTURE_VALUE_MIGRATIONS = {
    sheild_tall = "shield_tall",
}

local function MigrateBorderTextureValue(db, key)
    local value = db[key]
    if type(value) == "string" then
        db[key] = BORDER_TEXTURE_VALUE_MIGRATIONS[value] or value
    end
end

local function MigrateDBKeys(db)
    if type(db) ~= "table" then return end

    for oldKey, newKey in pairs(DB_MIGRATIONS) do
        if db[newKey] == nil and db[oldKey] ~= nil then
            db[newKey] = CopyDefaultValue(db[oldKey])
        end
    end

    MigrateBorderTextureValue(db, "ringTexture")
    MigrateBorderTextureValue(db, "losRingTexture")
end

local CURRENT_PROFILE_SCHEMA = 32

local RELEASE_OBSOLETE_PROFILE_KEYS = {
    showClickbox = true,
    disableBGPortrait = true,
    disableElvUIWarning = true,
    autoContextDefaults = true,
    optionsFriendlyVisualsOpen = true,
    optionsFriendlyAdvancedOpen = true,
    optionsEffectsAdvancedOpen = true,
    friendlySecureClickProxy = true,
    enemyPlateBackgroundAlertEnabled = true,
    enemyPlateHealthGlowEnabled = true,
    enemyPlateHealthGlowTexture = true,
    enemyPlateHealthGlowTextureCustom = true,
    enemyPlateHealthGlowPadding = true,
    enemyPlateAuraCrowdControlIDs = true,
    enemyPlateAuraBigDefensiveIDs = true,
    enemyPlateAuraExternalDefensiveIDs = true,
    enemyPlateImportantAuraIDs = true,
    enemyPlateAuraBlocklistIDs = true,
    enemyPlateBuffUseBlocklist = true,
    enemyPlateDebuffUseBlocklist = true,
    enemyPlateCustomAuraIDs = true,
    enemyPlateCustomUseSpellIDs = true,
    enemyPlateCustomBuffUseBlocklist = true,
    enemyPlateCustomDebuffUseBlocklist = true,
    enemyPlateShowPermanentAuras = true,
    repairElvUIDisabledNameplates = true,
}

local function MigrateReleaseProfile(db)
    if type(db) ~= "table" then return end

    local schema = tonumber(rawget(db, "profileSchemaVersion")) or 0
    if schema >= CURRENT_PROFILE_SCHEMA then return end

    if schema < 1 then
        -- Old builds shipped Developer Mode enabled while the options were still
        -- under active development. Start existing users in the public-facing UI;
        -- they can explicitly re-enable Developer Mode if they need it.
        db.developerMode = false
        db.debug = false
        db.debugClickbox = false
        db.friendlyTestMode = false
        db.enemyPlateTestMode = false

        -- The R21 texture is not part of the distributable package. Preserve a
        -- working presentation for older profiles by moving that legacy selection
        -- to the bundled Ribbon texture.
        for _, key in ipairs({ "enemyPlateHealthTexture", "enemyPlateTargetHealthTexture", "enemyPlateFocusHealthTexture" }) do
            local value = rawget(db, key)
            if value == "R21" or value == "r21" or value == "LSM:BattleMender R21" then
                db[key] = "RIBBON"
            end
        end

        for key in pairs(RELEASE_OBSOLETE_PROFILE_KEYS) do
            db[key] = nil
        end
    end

    if schema < 2 then
        -- PTR v0.3 positioned the major-defensive badge with absolute offsets.
        -- Convert only profiles that actually contain that old data; new live
        -- profiles should receive the defaults above unchanged.
        local oldX = tonumber(rawget(db, "majorDefensiveOffsetX"))
        local oldY = tonumber(rawget(db, "majorDefensiveOffsetY"))
        local oldDistance = tonumber(rawget(db, "majorDefensiveDistance"))

        if oldX or oldY then
            oldX = oldX or 18
            oldY = oldY or 16
            oldDistance = math.sqrt((oldX * oldX) + (oldY * oldY))
            local angle
            if math.atan2 then
                angle = math.atan2(oldY, oldX)
            elseif oldX > 0 then
                angle = math.atan(oldY / oldX)
            elseif oldX < 0 and oldY >= 0 then
                angle = math.atan(oldY / oldX) + math.pi
            elseif oldX < 0 then
                angle = math.atan(oldY / oldX) - math.pi
            elseif oldY > 0 then
                angle = math.pi * 0.5
            else
                angle = -math.pi * 0.5
            end
            db.majorDefensiveAngle = math.deg(angle) % 360
        end

        if oldDistance and rawget(db, "majorDefensiveDistanceScale") == nil then
            local iconSize = math.max(1, tonumber(rawget(db, "iconSize")) or defaults.iconSize)
            db.majorDefensiveDistanceScale = oldDistance / iconSize
        end

        if tonumber(rawget(db, "immunityRingScale")) == 1.20 then
            db.immunityRingScale = 1.18
        end
        if tonumber(rawget(db, "immunityRingAlpha")) == 1.00 then
            db.immunityRingAlpha = 0.92
        end

        db.majorDefensiveOffsetX = nil
        db.majorDefensiveOffsetY = nil
        db.majorDefensiveDistance = nil
        db.defensiveVisualRevision = 5
    end

    if schema < 3 then
        -- v14.1.0 created AuraContainer buttons for inactive slots on the live
        -- client, covering normal spec icons with blank immunity rings. Disable
        -- the unvalidated display for every existing profile; the user can
        -- explicitly re-enable it once the native button lifecycle is fixed.
        db.defensiveDisplayEnabled = false
    end

    if schema < 4 then
        -- NOT_CANCELABLE was removed as an aura-filter token in 12.1. Preserve
        -- profiles that selected it by converting to the supported negation.
        if rawget(db, "enemyPlateAuraDebuffFilter") == "HARMFUL|NOT_CANCELABLE" then
            db.enemyPlateAuraDebuffFilter = "HARMFUL|!CANCELABLE"
        end
    end

    if schema < 6 then
        -- The broad nameplate-only controls duplicated the top-level Enable
        -- Buffs/Debuffs switches rather than refining them. Remove them and
        -- migrate the old, unsupported "Player Dispellable" choice to the
        -- supported RAID_PLAYER_DISPELLABLE category.
        db.enemyPlateBuffUseBlizzardNameplateOnly = nil
        db.enemyPlateDebuffUseBlizzardNameplateOnly = nil
        db.enemyPlateBuffUseAll = nil
        db.enemyPlateBuffUseNameplate = nil
        db.enemyPlateDebuffUseNameplate = nil
        db.enemyPlateDebuffUseAll = nil
        db.enemyPlateDebuffUseBlizzardHarmful = nil
        db.enemyPlateDebuffUseBlizzardPlayer = nil
        db.enemyPlateDebuffUseBlizzardRaid = nil
        db.enemyPlateDebuffUseBlizzardCancelable = nil
        db.enemyPlateDebuffUseBlizzardNotCancelable = nil

        if db.enemyPlateBuffUsePlayerDispellable == true then
            db.enemyPlateBuffUseRaidDispellable = true
        end
        if db.enemyPlateDebuffUsePlayerDispellable == true then
            db.enemyPlateDebuffUseRaidDispellable = true
        end
        if db.enemyPlateCustomBuffUsePlayerDispellable == true then
            db.enemyPlateCustomBuffUseRaidDispellable = true
        end
        if db.enemyPlateCustomDebuffUsePlayerDispellable == true then
            db.enemyPlateCustomDebuffUseRaidDispellable = true
        end

        db.enemyPlateBuffUsePlayerDispellable = nil
        db.enemyPlateDebuffUsePlayerDispellable = nil
        db.enemyPlateCustomBuffUsePlayerDispellable = nil
        db.enemyPlateCustomDebuffUsePlayerDispellable = nil
    end

    if schema < 7 then
        -- "ElvUI Raid Frames" was neither a Blizzard aura category nor a
        -- meaningful nameplate filter. Remove its UI and all inactive profile
        -- state. Custom now exposes the same native Buff/Debuff filters as the
        -- dedicated groups, with explicit master switches for each type.
        local function AnyEnabled(keys)
            for _, key in ipairs(keys) do
                if db[key] == true then
                    return true
                end
            end
            return false
        end

        local customBuffKeys = {
            "enemyPlateCustomBuffUsePlayer",
            "enemyPlateCustomBuffUseRaidDispellable",
            "enemyPlateCustomBuffPlayerRaid",
            "enemyPlateCustomBuffPlayerRaidFrames",
            "enemyPlateCustomBuffPlayerCancelable",
            "enemyPlateCustomBuffPlayerNotCancelable",
            "enemyPlateCustomBuffPlayerBigDefensive",
            "enemyPlateCustomBuffPlayerExternalDefensive",
            "enemyPlateCustomBuffOthersRaid",
            "enemyPlateCustomBuffOthersRaidFrames",
            "enemyPlateCustomBuffOthersCancelable",
            "enemyPlateCustomBuffOthersNotCancelable",
            "enemyPlateCustomBuffOthersBigDefensive",
            "enemyPlateCustomBuffOthersExternalDefensive",
        }
        local customDebuffKeys = {
            "enemyPlateCustomDebuffUsePlayer",
            "enemyPlateCustomDebuffUseRaidDispellable",
            "enemyPlateCustomDebuffPlayerRaid",
            "enemyPlateCustomDebuffPlayerRaidFrames",
            "enemyPlateCustomDebuffPlayerCrowdControl",
            "enemyPlateCustomDebuffOthersRaid",
            "enemyPlateCustomDebuffOthersRaidFrames",
            "enemyPlateCustomDebuffOthersCrowdControl",
        }

        if db.enemyPlateCustomShowBuffs == nil and AnyEnabled(customBuffKeys) then
            db.enemyPlateCustomShowBuffs = true
        end
        if db.enemyPlateCustomShowDebuffs == nil and AnyEnabled(customDebuffKeys) then
            db.enemyPlateCustomShowDebuffs = true
        end

        for _, key in ipairs({
            "enemyPlateBuffPlayerRaidFrames",
            "enemyPlateBuffOthersRaidFrames",
            "enemyPlateDebuffPlayerRaidFrames",
            "enemyPlateDebuffOthersRaidFrames",
            "enemyPlateCustomBuffPlayerRaidFrames",
            "enemyPlateCustomBuffOthersRaidFrames",
            "enemyPlateCustomDebuffPlayerRaidFrames",
            "enemyPlateCustomDebuffOthersRaidFrames",
        }) do
            db[key] = nil
        end
    end

    if schema < 8 then
        -- Explicit spell-ID filtering uses the legacy manual aura path, which
        -- cannot read secret combat aura data in 12.1. Retire its settings so
        -- all displays use Blizzard's native category filters consistently.
        for _, key in ipairs({
            "enemyPlateAuraBlocklistIDs",
            "enemyPlateBuffUseBlocklist",
            "enemyPlateDebuffUseBlocklist",
            "enemyPlateCustomAuraIDs",
            "enemyPlateCustomUseSpellIDs",
            "enemyPlateCustomBuffUseBlocklist",
            "enemyPlateCustomDebuffUseBlocklist",
            "enemyPlateShowPermanentAuras",
        }) do
            db[key] = nil
        end
    end

    if schema < 9 then
        -- These are new display-scope switches. Missing values retain the
        -- established behaviour of showing Buffs and Debuffs on all plates.
        db.enemyPlateBuffAurasTargetOnly = db.enemyPlateBuffAurasTargetOnly == true
        db.enemyPlateDebuffAurasTargetOnly = db.enemyPlateDebuffAurasTargetOnly == true
    end

    if schema < 10 then
        -- Preserve a visible but brief interrupted-cast result for profiles
        -- created before the cast-bar interrupted-state presentation existed.
        for _, key in ipairs({
            "enemyPlateCastInterruptedR",
            "enemyPlateCastInterruptedG",
            "enemyPlateCastInterruptedB",
            "enemyPlateCastInterruptedHoldTime",
        }) do
            if rawget(db, key) == nil then
                db[key] = CopyDefaultValue(defaults[key])
            end
        end
    end

    if schema < 11 then
        -- A PLAYER aura filter means an aura cast by the local player, not an
        -- aura owned by the enemy player on the nameplate. Remove those
        -- misleading dedicated-Buff settings; Custom Auras keeps its explicit
        -- source controls for users who need that rare behaviour.
        for _, key in ipairs({
            "enemyPlateAuraBuffFilter",
            "enemyPlateSelfBuffsOnly",
            "enemyPlateBuffUsePlayer",
            "enemyPlateBuffPlayerRaid",
            "enemyPlateBuffPlayerCancelable",
            "enemyPlateBuffPlayerNotCancelable",
            "enemyPlateBuffPlayerBigDefensive",
            "enemyPlateBuffPlayerExternalDefensive",
            "enemyPlateBuffPlayerBlockPermanent",
        }) do
            db[key] = nil
        end
    end

    if schema < 12 then
        -- Enemy Buff categories now support an explicit excluded state. Keep
        -- every existing checked category included and initialize all new
        -- negative states to off.
        for _, key in ipairs({
            "enemyPlateBuffExcludeRaidDispellable",
            "enemyPlateBuffExcludeDispellable",
            "enemyPlateBuffExcludeImportant",
            "enemyPlateBuffExcludeRaidInCombat",
            "enemyPlateBuffOthersExcludeRaid",
            "enemyPlateBuffOthersExcludeCancelable",
            "enemyPlateBuffOthersExcludeNotCancelable",
            "enemyPlateBuffOthersExcludeBigDefensive",
            "enemyPlateBuffOthersExcludeExternalDefensive",
        }) do
            db[key] = false
        end
    end

    if schema < 13 then
        -- Retail now exposes friendly names-only and class-color choices in the
        -- Blizzard Nameplate settings. Retire BattleMender's duplicate profile
        -- controls so instance transitions cannot override those user choices.
        db.instanceFriendlyNamesOnly = nil
        db.instanceClassColorNames = nil
    end

    if schema < 14 then
        -- All visible aura categories now use one include/exclude state pair.
        -- Fold the former Cancelable + Not Cancelable controls into a single
        -- Cancelable state: include means cancelable, exclude means not
        -- cancelable. If both halves were selected, neither filter is needed.
        local function ConsolidateCancelable(includeKey, excludeKey, notIncludeKey, notExcludeKey)
            local wantsCancelable = rawget(db, includeKey) == true
                or (notExcludeKey and rawget(db, notExcludeKey) == true)
            local wantsNotCancelable = rawget(db, excludeKey) == true
                or rawget(db, notIncludeKey) == true

            if wantsCancelable ~= wantsNotCancelable then
                db[includeKey] = wantsCancelable
                db[excludeKey] = wantsNotCancelable
            else
                db[includeKey] = false
                db[excludeKey] = false
            end

            db[notIncludeKey] = nil
            if notExcludeKey then
                db[notExcludeKey] = nil
            end
        end

        ConsolidateCancelable(
            "enemyPlateBuffOthersCancelable",
            "enemyPlateBuffOthersExcludeCancelable",
            "enemyPlateBuffOthersNotCancelable",
            "enemyPlateBuffOthersExcludeNotCancelable"
        )
        ConsolidateCancelable(
            "enemyPlateCustomBuffPlayerCancelable",
            "enemyPlateCustomBuffPlayerExcludeCancelable",
            "enemyPlateCustomBuffPlayerNotCancelable"
        )
        ConsolidateCancelable(
            "enemyPlateCustomBuffOthersCancelable",
            "enemyPlateCustomBuffOthersExcludeCancelable",
            "enemyPlateCustomBuffOthersNotCancelable"
        )

        -- Preserve every existing checked category as included and initialize
        -- the newly added negative state to off.
        for _, key in ipairs({
            "enemyPlateDebuffExcludePlayer",
            "enemyPlateDebuffExcludeRaidDispellable",
            "enemyPlateDebuffExcludeDispellable",
            "enemyPlateDebuffPlayerExcludeRaid",
            "enemyPlateDebuffPlayerExcludeCrowdControl",
            "enemyPlateDebuffOthersExcludeRaid",
            "enemyPlateDebuffOthersExcludeCrowdControl",
            "enemyPlateCustomBuffExcludePlayer",
            "enemyPlateCustomBuffExcludeRaidDispellable",
            "enemyPlateCustomBuffExcludeDispellable",
            "enemyPlateCustomBuffExcludeImportant",
            "enemyPlateCustomBuffExcludeRaidInCombat",
            "enemyPlateCustomBuffPlayerExcludeRaid",
            "enemyPlateCustomBuffPlayerExcludeCancelable",
            "enemyPlateCustomBuffPlayerExcludeBigDefensive",
            "enemyPlateCustomBuffPlayerExcludeExternalDefensive",
            "enemyPlateCustomBuffOthersExcludeRaid",
            "enemyPlateCustomBuffOthersExcludeCancelable",
            "enemyPlateCustomBuffOthersExcludeBigDefensive",
            "enemyPlateCustomBuffOthersExcludeExternalDefensive",
            "enemyPlateCustomDebuffExcludePlayer",
            "enemyPlateCustomDebuffExcludeRaidDispellable",
            "enemyPlateCustomDebuffExcludeDispellable",
            "enemyPlateCustomDebuffPlayerExcludeRaid",
            "enemyPlateCustomDebuffPlayerExcludeCrowdControl",
            "enemyPlateCustomDebuffOthersExcludeRaid",
            "enemyPlateCustomDebuffOthersExcludeCrowdControl",
        }) do
            if rawget(db, key) == nil then
                db[key] = false
            end
        end

        -- These Debuff fields were never exposed by the current UI or read by
        -- the runtime filter resolver.
        for _, key in ipairs({
            "enemyPlateDebuffPlayerCancelable",
            "enemyPlateDebuffPlayerNotCancelable",
            "enemyPlateDebuffPlayerBigDefensive",
            "enemyPlateDebuffPlayerExternalDefensive",
            "enemyPlateDebuffOthersCancelable",
            "enemyPlateDebuffOthersNotCancelable",
            "enemyPlateDebuffOthersBigDefensive",
            "enemyPlateDebuffOthersExternalDefensive",
        }) do
            db[key] = nil
        end
    end

    if schema < 16 then
        -- Source-specific category copies made the Buff and Debuff filters
        -- unnecessarily repetitive. Buff categories are now source-neutral;
        -- Debuffs have one optional PLAYER-source modifier applied to the
        -- complete filter. Inclusion wins when old source groups disagree.
        local function ConsolidateSourceCategory(includeKey, excludeKey, oldPairs)
            local include = rawget(db, includeKey) == true
            local exclude = rawget(db, excludeKey) == true

            for _, pair in ipairs(oldPairs) do
                include = include or rawget(db, pair[1]) == true
                exclude = exclude or rawget(db, pair[2]) == true
            end

            db[includeKey] = include
            db[excludeKey] = not include and exclude or false
        end

        ConsolidateSourceCategory("enemyPlateDebuffRaid", "enemyPlateDebuffExcludeRaid", {
            { "enemyPlateDebuffPlayerRaid", "enemyPlateDebuffPlayerExcludeRaid" },
            { "enemyPlateDebuffOthersRaid", "enemyPlateDebuffOthersExcludeRaid" },
        })
        ConsolidateSourceCategory("enemyPlateDebuffCrowdControl", "enemyPlateDebuffExcludeCrowdControl", {
            { "enemyPlateDebuffPlayerCrowdControl", "enemyPlateDebuffPlayerExcludeCrowdControl" },
            { "enemyPlateDebuffOthersCrowdControl", "enemyPlateDebuffOthersExcludeCrowdControl" },
        })
        db.enemyPlateDebuffOnlyCastByYou = rawget(db, "enemyPlateDebuffUsePlayer") == true
        db.enemyPlateDebuffBlockPermanent = rawget(db, "enemyPlateDebuffPlayerBlockPermanent") == true
            or rawget(db, "enemyPlateDebuffOthersBlockPermanent") == true

        local function ConsolidateSelectableContainer(prefix)
            local buff = "enemyPlate" .. prefix .. "Buff"
            local debuff = "enemyPlate" .. prefix .. "Debuff"

            for _, category in ipairs({ "Raid", "Cancelable", "BigDefensive", "ExternalDefensive" }) do
                ConsolidateSourceCategory(buff .. category, buff .. "Exclude" .. category, {
                    { buff .. "Player" .. category, buff .. "PlayerExclude" .. category },
                    { buff .. "Others" .. category, buff .. "OthersExclude" .. category },
                })
            end
            db[buff .. "BlockPermanent"] = rawget(db, buff .. "PlayerBlockPermanent") == true
                or rawget(db, buff .. "OthersBlockPermanent") == true

            for _, category in ipairs({ "Raid", "CrowdControl" }) do
                ConsolidateSourceCategory(debuff .. category, debuff .. "Exclude" .. category, {
                    { debuff .. "Player" .. category, debuff .. "PlayerExclude" .. category },
                    { debuff .. "Others" .. category, debuff .. "OthersExclude" .. category },
                })
            end
            db[debuff .. "OnlyCastByYou"] = rawget(db, debuff .. "UsePlayer") == true
            db[debuff .. "BlockPermanent"] = rawget(db, debuff .. "PlayerBlockPermanent") == true
                or rawget(db, debuff .. "OthersBlockPermanent") == true
        end

        ConsolidateSelectableContainer("Custom")
        ConsolidateSelectableContainer("Danger")

        for _, key in ipairs({
            "enemyPlateDebuffUsePlayer", "enemyPlateDebuffExcludePlayer",
            "enemyPlateDebuffPlayerRaid", "enemyPlateDebuffPlayerExcludeRaid",
            "enemyPlateDebuffPlayerCrowdControl", "enemyPlateDebuffPlayerExcludeCrowdControl",
            "enemyPlateDebuffPlayerBlockPermanent",
            "enemyPlateDebuffOthersRaid", "enemyPlateDebuffOthersExcludeRaid",
            "enemyPlateDebuffOthersCrowdControl", "enemyPlateDebuffOthersExcludeCrowdControl",
            "enemyPlateDebuffOthersBlockPermanent",
        }) do
            db[key] = nil
        end

        for _, prefix in ipairs({ "enemyPlateCustom", "enemyPlateDanger" }) do
            for _, suffix in ipairs({
                "BuffUsePlayer", "BuffExcludePlayer",
                "BuffPlayerRaid", "BuffPlayerExcludeRaid",
                "BuffPlayerCancelable", "BuffPlayerExcludeCancelable",
                "BuffPlayerBigDefensive", "BuffPlayerExcludeBigDefensive",
                "BuffPlayerExternalDefensive", "BuffPlayerExcludeExternalDefensive",
                "BuffPlayerBlockPermanent",
                "BuffOthersRaid", "BuffOthersExcludeRaid",
                "BuffOthersCancelable", "BuffOthersExcludeCancelable",
                "BuffOthersBigDefensive", "BuffOthersExcludeBigDefensive",
                "BuffOthersExternalDefensive", "BuffOthersExcludeExternalDefensive",
                "BuffOthersBlockPermanent",
                "DebuffUsePlayer", "DebuffExcludePlayer",
                "DebuffPlayerRaid", "DebuffPlayerExcludeRaid",
                "DebuffPlayerCrowdControl", "DebuffPlayerExcludeCrowdControl",
                "DebuffPlayerBlockPermanent",
                "DebuffOthersRaid", "DebuffOthersExcludeRaid",
                "DebuffOthersCrowdControl", "DebuffOthersExcludeCrowdControl",
                "DebuffOthersBlockPermanent",
            }) do
                db[prefix .. suffix] = nil
            end
        end

        -- Danger is new and intentionally opt-in. Materialize its complete
        -- default state so older profiles reset, export, and import it exactly
        -- like the established Custom container.
        for key, defaultValue in pairs(defaults) do
            if type(key) == "string"
                and key:find("^enemyPlateDanger")
                and rawget(db, key) == nil
            then
                db[key] = CopyDefaultValue(defaultValue)
            end
        end
    end

    if schema < 17 then
        -- 14.7 separates the Important Progressive flare from the target/low-health
        -- outer-glow system and gives the flare independent geometry/color controls.
        -- New controls use the current official defaults. Preserve genuinely
        -- customized legacy glow color/alpha from schema 16 profiles, but migrate
        -- the old untouched legacy defaults to the current release defaults.
        if rawget(db, "enemyPlateDangerHealthGlowColorMode") == nil then
            db.enemyPlateDangerHealthGlowColorMode = defaults.enemyPlateDangerHealthGlowColorMode
        end
        if rawget(db, "enemyPlateDangerHealthGlowHeight") == nil then
            db.enemyPlateDangerHealthGlowHeight = defaults.enemyPlateDangerHealthGlowHeight
        end

        local legacyR = tonumber(rawget(db, "enemyPlateDangerHealthGlowR"))
        local legacyG = tonumber(rawget(db, "enemyPlateDangerHealthGlowG"))
        local legacyB = tonumber(rawget(db, "enemyPlateDangerHealthGlowB"))
        local legacyA = tonumber(rawget(db, "enemyPlateDangerHealthGlowA"))
        local epsilon = 0.0001

        if legacyR ~= nil and math.abs(legacyR - 1) <= epsilon then
            db.enemyPlateDangerHealthGlowR = defaults.enemyPlateDangerHealthGlowR
        end
        if legacyG ~= nil and math.abs(legacyG - 0.12) <= epsilon then
            db.enemyPlateDangerHealthGlowG = defaults.enemyPlateDangerHealthGlowG
        end
        if legacyB ~= nil and math.abs(legacyB - 0.04) <= epsilon then
            db.enemyPlateDangerHealthGlowB = defaults.enemyPlateDangerHealthGlowB
        end

        if rawget(db, "enemyPlateDangerHealthGlowOpacity") == nil then
            if legacyA ~= nil and math.abs(legacyA - 0.28) > epsilon then
                db.enemyPlateDangerHealthGlowOpacity = legacyA
            else
                db.enemyPlateDangerHealthGlowOpacity = defaults.enemyPlateDangerHealthGlowOpacity
            end
        end
    end

    if schema < 18 then
        -- 14.8 introduced an independent vertical offset for the Important
        -- Progressive flare. Profiles that have never seen the control inherit
        -- the current official release default.
        if rawget(db, "enemyPlateDangerHealthGlowYOffset") == nil then
            db.enemyPlateDangerHealthGlowYOffset = defaults.enemyPlateDangerHealthGlowYOffset
        end
    end

    if schema < 19 then
        -- 14.12 makes the Progressive flare independent of the Important aura
        -- container. Preserve the user's existing Important-flare appearance and
        -- behavior, and use Important as the initial trigger category.
        local function MigrateFlareValue(newKey, oldKey)
            if rawget(db, newKey) == nil then
                local value = rawget(db, oldKey)
                if value == nil then value = defaults[newKey] end
                db[newKey] = CopyDefaultValue(value)
            end
        end

        MigrateFlareValue("enemyPlateAuraFlareEnabled", "enemyPlateDangerHealthGlowEnabled")
        MigrateFlareValue("enemyPlateAuraFlareColorMode", "enemyPlateDangerHealthGlowColorMode")
        MigrateFlareValue("enemyPlateAuraFlareHeight", "enemyPlateDangerHealthGlowHeight")
        MigrateFlareValue("enemyPlateAuraFlareYOffset", "enemyPlateDangerHealthGlowYOffset")
        MigrateFlareValue("enemyPlateAuraFlareOpacity", "enemyPlateDangerHealthGlowOpacity")
        MigrateFlareValue("enemyPlateAuraFlareR", "enemyPlateDangerHealthGlowR")
        MigrateFlareValue("enemyPlateAuraFlareG", "enemyPlateDangerHealthGlowG")
        MigrateFlareValue("enemyPlateAuraFlareB", "enemyPlateDangerHealthGlowB")

        if rawget(db, "enemyPlateAuraFlareTriggerCategory") == nil then
            db.enemyPlateAuraFlareTriggerCategory = defaults.enemyPlateAuraFlareTriggerCategory
        end

        -- These keys are no longer runtime settings. Removing explicit saved
        -- copies keeps profile exports focused on the new independent flare.
        db.enemyPlateDangerHealthGlowEnabled = nil
        db.enemyPlateDangerHealthGlowColorMode = nil
        db.enemyPlateDangerHealthGlowHeight = nil
        db.enemyPlateDangerHealthGlowYOffset = nil
        db.enemyPlateDangerHealthGlowOpacity = nil
        db.enemyPlateDangerHealthGlowR = nil
        db.enemyPlateDangerHealthGlowG = nil
        db.enemyPlateDangerHealthGlowB = nil
        db.enemyPlateDangerHealthGlowA = nil
    end

    if schema < 20 then
        -- 14.13 removes the experimental Stable Clip health renderer and adds
        -- independent horizontal density for the aura-driven Progressive flare.
        -- Existing profiles are moved to the reliable direct StatusBar path.
        db.enemyPlateHealthFillMode = nil
        if rawget(db, "enemyPlateAuraFlareDensity") == nil then
            db.enemyPlateAuraFlareDensity = defaults.enemyPlateAuraFlareDensity
        end
    end

    if schema < 21 then
        -- 15.0 retires BattleMender's old ElvUI DB-repair path. Interaction is
        -- now owned entirely by BattleMender and the unified Friendly Preview
        -- stores its feature selections in the profile.
        db.repairElvUIDisabledNameplates = nil
        if rawget(db, "friendlyClickthrough") == nil then db.friendlyClickthrough = false end
        if rawget(db, "enemyPlateClickthrough") == nil then db.enemyPlateClickthrough = false end
        if rawget(db, "friendlyPreviewObjective") == nil then db.friendlyPreviewObjective = "NONE" end
        if rawget(db, "friendlyPreviewAura") == nil then db.friendlyPreviewAura = "NONE" end
    end

    if schema < 22 then
        -- 15.3 normalizes friendly border fitting per texture. Preserve the
        -- apparent size of the currently selected border by converting the old
        -- shared Border Size multiplier into the new Fine Tune multiplier.
        local legacyFits = {
            Ring_10px = 1.06,
            Ring_20px = 1.10,
            Ring_30px = 1.14,
            Ring_40px = 1.18,
            Metal_Ring = 1.10,
            plastic_ring = 1.10,
            defensive_cogwheel = 1.12,
            shield_easy = 1.16,
            shield_ring = 1.16,
            shield_tall = 1.18,
            sheild_tall = 1.18,
        }

        if rawget(db, "ringFineTune") == nil then
            local selected = BattleMender.NormalizeFriendlyBorderKey(rawget(db, "ringTexture") or defaults.ringTexture)
            local oldScale = tonumber(rawget(db, "ringScale")) or 1.21
            local oldFit = legacyFits[selected] or 1.10
            local newFit = BattleMender.GetFriendlyBorderFit(selected)
            local fineTune = oldScale * oldFit / math.max(0.001, newFit)
            db.ringFineTune = math.max(0.65, math.min(1.50, fineTune))
        end

        db.ringScale = nil
    end

    if schema < 23 then
        -- 15.4 separates geometric normalization from a small per-texture
        -- visual bias. Preserve the currently selected border's apparent size
        -- by absorbing that new bias into the existing user fine-tune value.
        local selected = BattleMender.NormalizeFriendlyBorderKey(rawget(db, "ringTexture") or defaults.ringTexture)
        local bias = BattleMender.GetFriendlyBorderVisualBias(selected)
        local oldFineTune = tonumber(rawget(db, "ringFineTune")) or 1
        db.ringFineTune = math.max(0.85, math.min(1.15, oldFineTune / math.max(0.001, bias)))
    end

    if schema < 24 then
        -- 15.6 simplifies the LoS presentation and removes two dead/unstable
        -- controls. Only migrate profiles still carrying the previous defaults;
        -- deliberate custom LoS border/overlay selections remain untouched.
        if rawget(db, "losRingTexture") == nil or rawget(db, "losRingTexture") == "SAME" then
            db.losRingTexture = "Ring_20px"
        end
        if rawget(db, "losRingAlpha") == nil or tonumber(rawget(db, "losRingAlpha")) == 1 then
            db.losRingAlpha = 0.7
        end
        if rawget(db, "losAccentOverlayTexture") == nil or rawget(db, "losAccentOverlayTexture") == "SAME" then
            db.losAccentOverlayTexture = "NONE"
        end

        -- This multiplier was exposed in Settings but never read by the renderer.
        db.losRingAlphaMultiplier = nil

        -- LoS pulse caused the entire damaged/spec holder to flicker and is no
        -- longer part of the LoS visual state. Old profile keys are retired.
        db.losPulseEnable = nil
        db.losPulseSpeed = nil
        db.losPulseIntensity = nil
        db.losPulseOverlayEnable = nil
        db.losPulseOverlayTexture = nil
        db.losPulseOverlayBlend = nil
        db.losPulseOverlayAlpha = nil
    end

    if schema < 25 then
        -- 15.9 gives BattleMender explicit, independent ownership of the two
        -- native friendly-player elements that can otherwise sit behind the
        -- circular friendly plate. Keep the player name visible by default.
        if rawget(db, "hideBlizzardFriendlyHealthArt") == nil then
            db.hideBlizzardFriendlyHealthArt = true
        end
        if rawget(db, "hideBlizzardFriendlyPlayerName") == nil then
            db.hideBlizzardFriendlyPlayerName = false
        end
    end

    if schema < 26 then
        for key, value in pairs(defaults) do
            if key:match("^healer") and rawget(db, key) == nil then
                db[key] = CopyDefaultValue(value)
            end
        end
    end

    if schema < 27 then
        -- 15.20 adds environment-specific visibility/scaling plus a revived
        -- player-specific offensive-dispel aura filter. Schema < 6 retired an
        -- older unsupported setting with the same name, so initialize these as
        -- genuinely new controls rather than resurrecting the old value.
        for _, key in ipairs({
            "arenaFriendlyPlateScale",
            "arenaEnemyPlateScale",
            "friendlyOnlyGroupMembers",
            "friendlyHideInRestAreas",
            "enemyPlateBuffUsePlayerDispellable",
            "enemyPlateBuffExcludePlayerDispellable",
            "enemyPlateCustomBuffUsePlayerDispellable",
            "enemyPlateCustomBuffExcludePlayerDispellable",
            "enemyPlateDangerBuffUsePlayerDispellable",
            "enemyPlateDangerBuffExcludePlayerDispellable",
        }) do
            if rawget(db, key) == nil then
                db[key] = CopyDefaultValue(defaults[key])
            end
        end
    end

    if schema < 28 then
        -- 15.22 splits friendly visibility by environment. Preserve the old
        -- broad group-only behavior across the three new contexts and map the
        -- former city/rest toggle specifically to the Rest context. Arena is
        -- intentionally unaffected.
        local oldGroupOnly = rawget(db, "friendlyOnlyGroupMembers") == true
        local oldHideRest = rawget(db, "friendlyHideInRestAreas") == true
        for _, key in ipairs({
            "friendlyGroupOnlyWorld", "friendlyGroupOnlyRest", "friendlyGroupOnlyBG",
            "friendlyHideWorld", "friendlyHideRest", "friendlyHideBG",
            "healerDamageCrossR", "healerDamageCrossG", "healerDamageCrossB",
            "healerControlBadgeScale", "healerControlAngle", "healerControlDistanceScale",
        }) do
            if rawget(db, key) == nil then
                db[key] = CopyDefaultValue(defaults[key])
            end
        end
        if oldGroupOnly then
            db.friendlyGroupOnlyWorld = true
            db.friendlyGroupOnlyRest = true
            db.friendlyGroupOnlyBG = true
        end
        if oldHideRest then
            db.friendlyHideRest = true
        end
        db.friendlyOnlyGroupMembers = nil
        db.friendlyHideInRestAreas = nil

        -- The first healer-cross build used class-color backing. The new
        -- health language intentionally makes the healthy center neutral/dark
        -- so the green cross has consistent contrast across every healer class.
        -- Preserve an explicitly custom background, but migrate class-color mode
        -- itself to the new neutral treatment.
        if rawget(db, "healerBackgroundUseClassColor") == true then
            db.healerBackgroundUseClassColor = false
            if (tonumber(rawget(db, "healerBackgroundR")) or 1) == 1
                and (tonumber(rawget(db, "healerBackgroundG")) or 1) == 1
                and (tonumber(rawget(db, "healerBackgroundB")) or 1) == 1
            then
                db.healerBackgroundR = defaults.healerBackgroundR
                db.healerBackgroundG = defaults.healerBackgroundG
                db.healerBackgroundB = defaults.healerBackgroundB
            end
        end
    end

    if schema < 29 then
        -- 16.3 adds opt-in class-based enemy aura voice cues. Keep the new
        -- experimental system disabled for established profiles while seeding
        -- the per-category toggles/channel so enabling it is deterministic.
        for _, key in ipairs({
            "enemyClassAudioEnabled",
            "enemyClassAudioWorldTestEnabled",
            "enemyClassAudioImportantEnabled",
            "enemyClassAudioDefensiveEnabled",
            "enemyClassAudioChannel",
        }) do
            if rawget(db, key) == nil then
                db[key] = CopyDefaultValue(defaults[key])
            end
        end
    end

    if schema < 30 then
        -- 16.4 makes healer color semantics explicit: CLASS always resolves
        -- from the friendly healer/plate occupant, never the player or aura caster.
        db.healerBackgroundColorMode = "CLASS"
        db.healerBackgroundUseClassColor = true -- legacy mirror
        db.healerControlColorMode = "CLASS"
    end

    if schema < 31 then
        -- 16.5 promotes affiliation from a healer/BG-only experiment into a
        -- general friendly-player relationship system. Preserve any 16.4
        -- marker choices, then retire the healer-specific keys.
        if rawget(db, "affiliateParty") == nil then
            local old = rawget(db, "healerAffiliationHomeGroup")
            db.affiliateParty = old == nil and defaults.affiliateParty or old ~= false
        end
        if rawget(db, "affiliateGuild") == nil then
            local old = rawget(db, "healerAffiliationGuild")
            db.affiliateGuild = old == nil and defaults.affiliateGuild or old ~= false
        end
        if rawget(db, "affiliateFriend") == nil then db.affiliateFriend = defaults.affiliateFriend end
        if rawget(db, "affiliateBadgeEnabled") == nil then
            local old = rawget(db, "healerAffiliationEnabled")
            db.affiliateBadgeEnabled = old == nil and defaults.affiliateBadgeEnabled or old ~= false
        end
        if rawget(db, "affiliateBadgeScale") == nil then
            db.affiliateBadgeScale = tonumber(rawget(db, "healerAffiliationBadgeScale")) or defaults.affiliateBadgeScale
        end
        if rawget(db, "affiliateBadgeAngle") == nil then
            db.affiliateBadgeAngle = tonumber(rawget(db, "healerAffiliationAngle")) or defaults.affiliateBadgeAngle
        end
        if rawget(db, "affiliateBadgeDistanceScale") == nil then
            db.affiliateBadgeDistanceScale = tonumber(rawget(db, "healerAffiliationDistanceScale")) or defaults.affiliateBadgeDistanceScale
        end
        for _, key in ipairs({
            "affiliatePlateScale", "friendlyHideKeepParty",
            "friendlyHideKeepGuild", "friendlyHideKeepFriends",
        }) do
            if rawget(db, key) == nil then db[key] = CopyDefaultValue(defaults[key]) end
        end

        db.healerAffiliationEnabled = nil
        db.healerAffiliationGuild = nil
        db.healerAffiliationHomeGroup = nil
        db.healerAffiliationBadgeScale = nil
        db.healerAffiliationAngle = nil
        db.healerAffiliationDistanceScale = nil
    end

    if schema < 32 then
        -- 16.6 replaces the hard-coded Blizzard raid-marker art with bundled,
        -- selectable affiliate star textures. Existing profiles retain the
        -- familiar gold presentation.
        if rawget(db, "affiliateBadgeTexture") == nil then
            db.affiliateBadgeTexture = defaults.affiliateBadgeTexture
        end
    end

    db.profileSchemaVersion = CURRENT_PROFILE_SCHEMA
end

local function ResolveAceDB()
    local libStub = _G.LibStub

    if not libStub then
        local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if loader then
            pcall(loader, "Ace3")
            libStub = _G.LibStub
        end
    end

    return libStub and libStub("AceDB-3.0", true) or nil
end

local function IsLegacyFlatDB(db)
    return type(db) == "table"
        and db.profiles == nil
        and db.profileKeys == nil
end

local function NormalizeHealerSettings(target)
    for key, defaultValue in pairs(defaults) do
        if key:match("^healer") then
            local value = target[key]
            if type(value) ~= type(defaultValue) then
                value = defaultValue
            elseif type(value) == "number" then
                if value ~= value or value == math.huge or value == -math.huge then
                    value = defaultValue
                else
                    local minimum, maximum = 0, 1
                    if key == "healerCrossScale" then
                        minimum, maximum = 0.4, 1.3
                    elseif key == "healerControlBadgeScale" then
                        minimum, maximum = 0.35, 1.4
                    elseif key == "healerControlDistanceScale" then
                        minimum, maximum = 0, 1.5
                    elseif key == "healerControlAngle" then
                        minimum, maximum = 0, 360
                    elseif key == "healerAffiliationBadgeScale" then
                        minimum, maximum = 0.30, 1.0
                    elseif key == "healerAffiliationDistanceScale" then
                        minimum, maximum = 0, 1.5
                    elseif key == "healerAffiliationAngle" then
                        minimum, maximum = 0, 360
                    end
                    value = math.max(minimum, math.min(maximum, value))
                end
            end
            target[key] = value
        end
    end
    target.friendlyTestHealerControl = target.friendlyTestHealerControl == true
end

local function NormalizeAffiliateSettings(target)
    if type(target) ~= "table" then return end
    target.affiliateBadgeTexture = BattleMender.NormalizeAffiliateBadgeTextureKey(target.affiliateBadgeTexture)
    target.friendlyTestAffiliate = target.friendlyTestAffiliate == true
end

local function CopyKnownSettings(source, target)
    for key, defaultValue in pairs(defaults) do
        local value = source and source[key]
        if value == nil then
            value = defaultValue
        end

        if TRANSIENT_TEST_MODE_KEYS[key] then
            value = false
        end

        target[key] = CopyDefaultValue(value)
    end
    NormalizeHealerSettings(target)
    NormalizeAffiliateSettings(target)
end

local function NormalizeEnemyPlateColorDefaults(target)
    -- Early v33-v35 builds stored alpha values as 0.69 / 0.36 / 0.32 even
    -- though the ElvUI color picker values were 69 / 36 / 32 out of 255.
    -- Convert only those exact development defaults; preserve user-edited values.
    if not target then return end

    if target.enemyPlateTargetColorA == 0.69 then
        target.enemyPlateTargetColorA = 69 / 255
    end

    if target.enemyPlateLowHealthA == 0.36 then
        target.enemyPlateLowHealthA = 36 / 255
    end

    if target.enemyPlateLowHealthHalfA == 0.32 then
        target.enemyPlateLowHealthHalfA = 32 / 255
    end

    if target.enemyPlateTargetBackgroundTint == nil then
        target.enemyPlateTargetBackgroundTint = target.enemyPlateBackgroundAlertEnabled ~= false
    end

    if target.enemyPlateTargetGlowEnabled == nil then
        target.enemyPlateTargetGlowEnabled = target.enemyPlateHealthGlowEnabled ~= false
    end

    if target.enemyPlateLowHealthBackgroundTint == nil then
        target.enemyPlateLowHealthBackgroundTint = target.enemyPlateBackgroundAlertEnabled ~= false
    end

    if target.enemyPlateLowHealthGlowEnabled == nil then
        target.enemyPlateLowHealthGlowEnabled = target.enemyPlateHealthGlowEnabled ~= false
    end
end

function BattleMender.SyncCFGFromProfile()
    local source = BattleMender.DB and BattleMender.DB.profile or BattleMenderDB
    MigrateDBKeys(source)
    MigrateReleaseProfile(source)

    wipe(CFG)
    CopyKnownSettings(source, CFG)
    NormalizeEnemyAuraFilterStates(CFG)
    NormalizeEnemyPlateColorDefaults(CFG)
    ClearTransientTestModesFromTable(CFG)
end

local function NotifyOptionsChanged()
    local libStub = _G.LibStub
    local registry = libStub and libStub("AceConfigRegistry-3.0", true)
    if registry then
        registry:NotifyChange("BattleMender")
    end
end

function BattleMender.RefreshAfterProfileChange()
    BattleMender.SyncCFGFromProfile()

    -- A profile operation must apply the same runtime-facing settings as a
    -- normal SaveRefresh.  Previously the AceDB profile callbacks refreshed
    -- visible plates, but skipped several subsystems whose configuration is
    -- cached outside CFG.  That made copied/switched profiles look partially
    -- applied, most noticeably for managed defensive/immunity aura styling.
    if BattleMender.UpdateInstanceStatus then
        -- Also reapplies friendly Blizzard visibility and the friendly clickbox.
        BattleMender.UpdateInstanceStatus()
    else
        if BattleMender.ApplyFriendlyBlizzardVisibility then
            BattleMender.ApplyFriendlyBlizzardVisibility()
        end
        if BattleMender.SetFriendlyClickbox then
            BattleMender.SetFriendlyClickbox()
        end
    end

    -- Enemy-provider enable/visibility CVars are profile-owned settings too.
    -- Apply them before rebuilding the currently visible plates.
    if BattleMender.ApplyCustomEnemyPlateCVars then
        BattleMender.ApplyCustomEnemyPlateCVars()
    end

    if BattleMender.RefreshAll then
        BattleMender.RefreshAll()
    end

    -- AuraContainer buttons retain presentation state after creation.  A normal
    -- settings edit calls ApplySettings(), so profile copy/switch/reset must do
    -- the same or aura scale/ring/swipe/position values can remain from the
    -- previous profile until the plate is rebuilt.  ApplySettings safely queues
    -- itself when combat lockdown prevents immediate changes.
    if BattleMender.Defensives and BattleMender.Defensives.ApplySettings then
        BattleMender.Defensives.ApplySettings()
    end
    if BattleMender.EnemyAudio and BattleMender.EnemyAudio.ApplySettings then
        BattleMender.EnemyAudio.ApplySettings()
    end

    NotifyOptionsChanged()
end

function BattleMender.OnProfileChanged()
    BattleMender.RefreshAfterProfileChange()
end

function BattleMender.LoadDB()
    if BattleMender.DB then
        BattleMender.SyncCFGFromProfile()
        return
    end

    local AceDB = ResolveAceDB()
    if AceDB then
        local legacy

        -- Older BattleMender builds stored settings directly in BattleMenderDB.
        -- Preserve that table, let AceDB create its profile structure, then copy
        -- the known settings into the initial profile.
        if IsLegacyFlatDB(BattleMenderDB) then
            legacy = CopyDefaultValue(BattleMenderDB)
            BattleMenderDB = {}
        end

        local db = AceDB:New("BattleMenderDB", { profile = defaults }, true)
        BattleMender.DB = db

        if legacy and next(legacy) then
            MigrateDBKeys(legacy)
            MigrateReleaseProfile(legacy)
            for key in pairs(defaults) do
                if legacy[key] ~= nil then
                    db.profile[key] = CopyDefaultValue(legacy[key])
                end
            end
        end

        MigrateDBKeys(db.profile)
        MigrateReleaseProfile(db.profile)

        if not BattleMender.ProfileCallbacksRegistered then
            -- CallbackHandler mixins use dot syntax here. With colon syntax,
            -- the AceDB object is passed as the callback target and
            -- BattleMender is incorrectly treated as the event name.
            db.RegisterCallback(BattleMender, "OnProfileChanged", "OnProfileChanged")
            db.RegisterCallback(BattleMender, "OnProfileCopied", "OnProfileChanged")
            db.RegisterCallback(BattleMender, "OnProfileReset", "OnProfileChanged")
            BattleMender.ProfileCallbacksRegistered = true
        end

        BattleMender.SyncCFGFromProfile()
        return
    end

    -- Graceful fallback for installations that only include AceConfig.
    MigrateDBKeys(BattleMenderDB)
    MigrateReleaseProfile(BattleMenderDB)
    wipe(CFG)
    CopyKnownSettings(BattleMenderDB, CFG)
    NormalizeEnemyAuraFilterStates(CFG)
end

function BattleMender.SaveDB()
    local target = BattleMender.DB and BattleMender.DB.profile or BattleMenderDB

    NormalizeEnemyAuraFilterStates(CFG)
    NormalizeHealerSettings(CFG)
    NormalizeAffiliateSettings(CFG)

    for key, defaultValue in pairs(defaults) do
        local value = CFG[key]
        if value == nil then
            value = defaultValue
        end
        if key == "friendlyTestHealerControl" then value = false end
        target[key] = CopyDefaultValue(value)
    end
end

function BattleMender.SaveRefresh()
    BattleMender.SaveDB()
    if BattleMender.ApplyFriendlyBlizzardVisibility then
        BattleMender.ApplyFriendlyBlizzardVisibility()
    end
    if BattleMender.ApplyCustomEnemyPlateCVars then
        BattleMender.ApplyCustomEnemyPlateCVars()
    end
    BattleMender.RefreshAll()
    if BattleMender.Defensives and BattleMender.Defensives.ApplySettings then
        BattleMender.Defensives.ApplySettings(true)
    end
    if BattleMender.EnemyAudio and BattleMender.EnemyAudio.ApplySettings then
        BattleMender.EnemyAudio.ApplySettings()
    end
end

function BattleMender.DisableTestModes(save, refresh)
    ClearTransientTestModesFromTable(CFG)

    local target = BattleMender.DB and BattleMender.DB.profile or BattleMenderDB
    ClearTransientTestModesFromTable(target)

    DisableRuntimeTestModeVisuals()

    if save ~= false and BattleMender.SaveDB then
        BattleMender.SaveDB()
    end

    if refresh == true and BattleMender.RefreshAll then
        BattleMender.RefreshAll()
    end

    NotifyOptionsChanged()
end


-------------------------------------------------
-- Profile import / export
-------------------------------------------------
local PROFILE_EXPORT_PREFIX = "BattleMenderProfile"
local PROFILE_EXPORT_VERSION = 1

local function EncodeProfileString(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%25")
    value = value:gsub("\r", "%%0D")
    value = value:gsub("\n", "%%0A")
    return value
end

local function DecodeProfileString(value)
    value = tostring(value or "")
    value = value:gsub("%%0D", "\r")
    value = value:gsub("%%0A", "\n")
    value = value:gsub("%%25", "%%")
    return value
end

local function EncodeProfileValue(value)
    local valueType = type(value)

    if valueType == "boolean" then
        return value and "b:1" or "b:0"
    elseif valueType == "number" then
        return "n:" .. tostring(value)
    elseif valueType == "string" then
        return "s:" .. EncodeProfileString(value)
    end

    return nil
end

local function DecodeProfileValue(valueType, encoded)
    if valueType == "b" then
        if encoded == "1" or encoded == "true" then
            return true
        elseif encoded == "0" or encoded == "false" then
            return false
        end
    elseif valueType == "n" then
        return tonumber(encoded)
    elseif valueType == "s" then
        return DecodeProfileString(encoded)
    end

    return nil
end

-- Old exported profiles can still contain the source-specific aura settings
-- removed by schema 16. Admit only these known boolean keys, then let the same
-- saved-profile migration consolidate them into the current filter model.
local LEGACY_AURA_SOURCE_IMPORT_KEYS = {}

for _, key in ipairs({
    "enemyPlateDebuffUsePlayer", "enemyPlateDebuffExcludePlayer",
    "enemyPlateDebuffPlayerRaid", "enemyPlateDebuffPlayerExcludeRaid",
    "enemyPlateDebuffPlayerCrowdControl", "enemyPlateDebuffPlayerExcludeCrowdControl",
    "enemyPlateDebuffPlayerBlockPermanent",
    "enemyPlateDebuffOthersRaid", "enemyPlateDebuffOthersExcludeRaid",
    "enemyPlateDebuffOthersCrowdControl", "enemyPlateDebuffOthersExcludeCrowdControl",
    "enemyPlateDebuffOthersBlockPermanent",
}) do
    LEGACY_AURA_SOURCE_IMPORT_KEYS[key] = true
end

for _, prefix in ipairs({ "enemyPlateCustom", "enemyPlateDanger" }) do
    for _, suffix in ipairs({
        "BuffUsePlayer", "BuffExcludePlayer",
        "BuffPlayerRaid", "BuffPlayerExcludeRaid",
        "BuffPlayerCancelable", "BuffPlayerExcludeCancelable",
        "BuffPlayerBigDefensive", "BuffPlayerExcludeBigDefensive",
        "BuffPlayerExternalDefensive", "BuffPlayerExcludeExternalDefensive",
        "BuffPlayerBlockPermanent",
        "BuffOthersRaid", "BuffOthersExcludeRaid",
        "BuffOthersCancelable", "BuffOthersExcludeCancelable",
        "BuffOthersBigDefensive", "BuffOthersExcludeBigDefensive",
        "BuffOthersExternalDefensive", "BuffOthersExcludeExternalDefensive",
        "BuffOthersBlockPermanent",
        "DebuffUsePlayer", "DebuffExcludePlayer",
        "DebuffPlayerRaid", "DebuffPlayerExcludeRaid",
        "DebuffPlayerCrowdControl", "DebuffPlayerExcludeCrowdControl",
        "DebuffPlayerBlockPermanent",
        "DebuffOthersRaid", "DebuffOthersExcludeRaid",
        "DebuffOthersCrowdControl", "DebuffOthersExcludeCrowdControl",
        "DebuffOthersBlockPermanent",
    }) do
        LEGACY_AURA_SOURCE_IMPORT_KEYS[prefix .. suffix] = true
    end
end

function BattleMender.ExportProfile()
    if BattleMender.SaveDB then
        BattleMender.SaveDB()
    end

    local source = BattleMender.DB and BattleMender.DB.profile or BattleMenderDB or CFG
    local keys = {}

    for key in pairs(defaults) do
        keys[#keys + 1] = key
    end

    table.sort(keys)

    local out = {
        PROFILE_EXPORT_PREFIX .. ":" .. PROFILE_EXPORT_VERSION,
    }

    for _, key in ipairs(keys) do
        local defaultValue = defaults[key]
        local value = source and source[key]

        if value == nil then
            value = CFG[key]
        end

        if value == nil then
            value = defaultValue
        end

        local encoded = EncodeProfileValue(value)
        if encoded then
            out[#out + 1] = key .. "=" .. encoded
        end
    end

    return table.concat(out, "\n")
end

function BattleMender.ImportProfile(text)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot import a profile while in combat."
    end

    if type(text) ~= "string" or text == "" then
        return false, "No profile text was provided."
    end

    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    local header = text:match("^([^\n\r]+)")
    if header ~= (PROFILE_EXPORT_PREFIX .. ":" .. PROFILE_EXPORT_VERSION) then
        return false, "Invalid BattleMender profile text."
    end

    local imported = {}
    local count = 0

    for line in text:gmatch("[^\r\n]+") do
        if line ~= header then
            local key, valueType, encoded = line:match("^([%w_]+)=([bns]):(.*)$")

            if key and (defaults[key] ~= nil or LEGACY_AURA_SOURCE_IMPORT_KEYS[key]) then
                local decoded = DecodeProfileValue(valueType, encoded)
                local defaultType = defaults[key] ~= nil and type(defaults[key]) or "boolean"

                if decoded ~= nil and type(decoded) == defaultType then
                    imported[key] = CopyDefaultValue(decoded)
                    count = count + 1
                end
            end
        end
    end

    if count == 0 then
        return false, "No valid BattleMender settings were found."
    end

    local target = BattleMender.DB and BattleMender.DB.profile or BattleMenderDB

    for key in pairs(LEGACY_AURA_SOURCE_IMPORT_KEYS) do
        target[key] = nil
    end

    for key in pairs(defaults) do
        if imported[key] ~= nil then
            target[key] = CopyDefaultValue(imported[key])
        else
            target[key] = CopyDefaultValue(defaults[key])
        end
    end

    for key in pairs(LEGACY_AURA_SOURCE_IMPORT_KEYS) do
        if imported[key] ~= nil then
            target[key] = imported[key]
        end
    end

    ClearTransientTestModesFromTable(target)

    BattleMender.SyncCFGFromProfile()
    BattleMender.SaveDB()

    if BattleMender.RefreshAfterProfileChange then
        BattleMender.RefreshAfterProfileChange()
    else
        if BattleMender.RefreshAll then
            BattleMender.RefreshAll()
        end
    end

    return true, "Imported " .. tostring(count) .. " BattleMender profile settings."
end

function BattleMender.ResetToDefaults()
    if InCombatLockdown and InCombatLockdown() then
        print("|cff33ff99BattleMender:|r Cannot reset defaults while in combat.")
        return
    end

    if BattleMender.DB then
        BattleMender.DB:ResetProfile()
        -- AceDB fires OnProfileReset synchronously. This fallback keeps the
        -- reset reliable if another AceDB build omits that callback.
        BattleMender.RefreshAfterProfileChange()
    else
        wipe(BattleMenderDB)
        wipe(CFG)
        CopyKnownSettings(defaults, CFG)
        BattleMender.SaveDB()

        if BattleMender.UpdateInstanceStatus then
            BattleMender.UpdateInstanceStatus()
        elseif BattleMender.SetFriendlyClickbox then
            BattleMender.SetFriendlyClickbox()
        end

        if BattleMender.RefreshAll then
            BattleMender.RefreshAll()
        end
    end

    print("|cff33ff99BattleMender:|r current profile reset to defaults.")
end

-------------------------------------------------
-- Runtime state
-------------------------------------------------
-- Global sleep flag
BattleMender.IsSleeping = false

-------------------------------------------------
-- Nameplate CVars
--
-- This helper supports explicit Blizzard CVar controls and the custom enemy
-- provider's visibility requirements. BattleMender also owns the two explicit
-- friendly native-element visibility toggles exposed on Friendly Plates > General.
-------------------------------------------------
local GetElvUINameplateTables
local BM_CVAR_CACHE = BM_CVAR_CACHE or {}
BattleMender.PendingNameplateCVars = BattleMender.PendingNameplateCVars or {}

function BattleMender.SetNameplateCVar(name, value)
    if not name or not SetCVar then return false end

    if BM_CVAR_CACHE[name] == nil and GetCVar then
        BM_CVAR_CACHE[name] = GetCVar(name)
    end

    local valueText = tostring(value)

    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingNameplateCVars[name] = valueText
        return false
    end

    local ok = pcall(SetCVar, name, valueText)
    if ok then
        BattleMender.PendingNameplateCVars[name] = nil
        if type(name) == "string" and name:match("^nameplate") and BattleMender.ScheduleNameplateLayoutUpdate then
            BattleMender.ScheduleNameplateLayoutUpdate()
        end
    end

    return ok
end

function BattleMender.ApplyPendingNameplateCVars()
    if InCombatLockdown and InCombatLockdown() then return end

    local appliedNameplateLayoutCVar = false
    for name, value in pairs(BattleMender.PendingNameplateCVars) do
        if pcall(SetCVar, name, value) then
            BattleMender.PendingNameplateCVars[name] = nil
            if type(name) == "string" and name:match("^nameplate") then
                appliedNameplateLayoutCVar = true
            end
        end
    end

    if appliedNameplateLayoutCVar and BattleMender.ScheduleNameplateLayoutUpdate then
        BattleMender.ScheduleNameplateLayoutUpdate()
    end
end

-- Keep Blizzard's native friendly presentation independently controllable.
-- names-only removes Blizzard's health bar/art while retaining its player name;
-- UnitNameFriendlyPlayerName can then hide that remaining name separately.
function BattleMender.ApplyFriendlyBlizzardVisibility()
    if not BattleMender.SetNameplateCVar then return end

    BattleMender.SetNameplateCVar(
        "nameplateShowOnlyNameForFriendlyPlayerUnits",
        CFG.hideBlizzardFriendlyHealthArt ~= false and 1 or 0
    )
    BattleMender.SetNameplateCVar(
        "UnitNameFriendlyPlayerName",
        CFG.hideBlizzardFriendlyPlayerName == true and 0 or 1
    )
end

local function GetElvUINameplateModule()
    local E = select(1, GetElvUINameplateTables())
    if not E or type(E.GetModule) ~= "function" then
        return nil
    end

    local ok, module = pcall(E.GetModule, E, "NamePlates", true)
    if ok then
        return module
    end

    return nil
end

local function CallNameplateMethod(target, method, ...)
    if target and type(target[method]) == "function" then
        pcall(target[method], target, ...)
    end
end

function BattleMender.ApplyNameplateLayoutUpdate()
    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingNameplateLayoutUpdate = true
        return false
    end

    BattleMender.PendingNameplateLayoutUpdate = nil
    BattleMender.NameplateLayoutUpdateScheduled = nil

    -- Native driver safe mode:
    -- Do not call NamePlateDriverFrame:UpdateNamePlateOptions* from BattleMender.
    -- Calling those Blizzard methods from addon-tainted execution can taint the
    -- native CompactUnitFrame option table. On 12.x clients Blizzard then reaches
    -- secret health values in CompactUnitFrame_UpdateHealPrediction and throws:
    -- "attempt to compare local 'maxHealth' (a secret number value...)".
    --
    -- We still write CVars out of combat, but let Blizzard apply them naturally as
    -- plates are recreated. BattleMender only refreshes its own custom overlays.
    if BattleMender.RefreshActivePlates then
        BattleMender.RefreshActivePlates()
    end

    return true
end

function BattleMender.ScheduleNameplateLayoutUpdate()
    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingNameplateLayoutUpdate = true
        return false
    end

    if BattleMender.NameplateLayoutUpdateScheduled then
        return true
    end

    BattleMender.NameplateLayoutUpdateScheduled = true

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if BattleMender.ApplyNameplateLayoutUpdate then
                BattleMender.ApplyNameplateLayoutUpdate()
            end
        end)
    else
        BattleMender.ApplyNameplateLayoutUpdate()
    end

    return true
end

function BattleMender.SetNameplateStacking(value)
    value = value and true or false

    local E, db = GetElvUINameplateTables()
    if E and db then
        -- Keep ElvUI's DB aligned with the CVar. Otherwise ElvUI can re-apply
        -- its previous motionType on the next environment/nameplate refresh,
        -- making the BattleMender toggle appear to do nothing.
        db.motionType = value and "STACKED" or "OVERLAP"

        local env = db.enviromentConditions or db.environmentConditions
        if type(env) == "table" then
            env.stackingEnabled = true
            env.enable = true
            env.stackingNameplates = env.stackingNameplates or {}
            local inInstance, instanceType = IsInInstance()
            local key = "world"
            if inInstance and instanceType then
                key = instanceType
            elseif IsResting and IsResting() then
                key = "resting"
            end
            env.stackingNameplates[key] = value
            -- Keep common ElvUI environment keys aligned so changing zones does
            -- not immediately restore the old stacking state.
            env.stackingNameplates.world = value
            env.stackingNameplates.party = value
            env.stackingNameplates.raid = value
            env.stackingNameplates.arena = value
            env.stackingNameplates.pvp = value
            env.stackingNameplates.resting = value
        end
    end

    if BattleMender.SetNameplateCVar then
        BattleMender.SetNameplateCVar("nameplateMotion", value and 1 or 0)
    elseif SetCVar then
        pcall(SetCVar, "nameplateMotion", value and "1" or "0")
    end

    if BattleMender.ScheduleNameplateLayoutUpdate then
        BattleMender.ScheduleNameplateLayoutUpdate()
    end
end

function BattleMender.PrintNameplateStackingStatus()
    local _, db = GetElvUINameplateTables()
    local env = db and (db.enviromentConditions or db.environmentConditions)
    local inInstance, instanceType = IsInInstance()
    local key = "world"
    if inInstance and instanceType then
        key = instanceType
    elseif IsResting and IsResting() then
        key = "resting"
    end

    local function val(v)
        if v == nil then return "nil" end
        return tostring(v)
    end

    print("|cff33ff99BattleMender:|r nameplate stacking status")
    print("  CVar nameplateMotion:", val(GetCVar and GetCVar("nameplateMotion")))
    print("  CVar overlap H/V:", val(GetCVar and GetCVar("nameplateOverlapH")), val(GetCVar and GetCVar("nameplateOverlapV")))
    print("  pending motion:", val(BattleMender.PendingNameplateCVars and BattleMender.PendingNameplateCVars.nameplateMotion))
    if db then
        print("  ElvUI motionType:", val(db.motionType))
    end
    if env then
        print("  ElvUI stackingEnabled:", val(env.stackingEnabled), "environment:", key, "value:", val(env.stackingNameplates and env.stackingNameplates[key]))
    end
    print("  pending layout refresh:", val(BattleMender.PendingNameplateLayoutUpdate), "scheduled:", val(BattleMender.NameplateLayoutUpdateScheduled))
end

-------------------------------------------------
-- ElvUI disabled-nameplate repair
-------------------------------------------------
local ELVUI_NAMEPLATE_UNIT_KEYS = {
    "FRIENDLY_PLAYER",
    "FRIENDLY_NPC",
    "ENEMY_PLAYER",
    "ENEMY_NPC",
}

GetElvUINameplateTables = function()
    if not _G.ElvUI then
        return nil
    end

    local ok, E = pcall(function()
        return unpack(_G.ElvUI)
    end)

    if not ok or not E then
        return nil
    end

    local db = E.db and E.db.nameplates
    local private = E.private and E.private.nameplates

    return E, db, private
end

function BattleMender.IsElvUIFriendlyNameplatesEnabled()
    local _, db, private = GetElvUINameplateTables()

    -- Do not warn when ElvUI's NamePlates module itself is disabled.
    if private and private.enable == false then
        return false
    end
    if db and db.enable == false then
        return false
    end

    local friendly = db
        and db.units
        and db.units.FRIENDLY_PLAYER

    return friendly and friendly.enable ~= false or false
end

function BattleMender.WarnElvUIFriendlyNameplates()
    if BattleMender._ElvUIFriendlyLoginWarningShown then
        return false
    end

    if not BattleMender.IsElvUIFriendlyNameplatesEnabled() then
        return false
    end

    BattleMender._ElvUIFriendlyLoginWarningShown = true
    print("|cff33ff99BattleMender:|r |cffffcc00ElvUI Friendly Player nameplates are enabled. Disable to avoid conflicting presentation.|r")
    return true
end

function BattleMender.IsElvUILoadedWithNameplatesDisabled()
    local _, db, private = GetElvUINameplateTables()

    if not db and not private then
        return false
    end

    if private and private.enable == false then
        return true
    end

    if db and db.enable == false then
        return true
    end

    return false
end

function BattleMender.HasElvUIOrphanNameplateUnitToggles()
    local _, db = GetElvUINameplateTables()
    local units = db and db.units

    if not units then
        return false
    end

    for _, key in ipairs(ELVUI_NAMEPLATE_UNIT_KEYS) do
        local unitDB = units[key]
        if unitDB and unitDB.enable ~= false then
            return true
        end
    end

    return false
end

function BattleMender.PrintFriendlyMouseStatus()
    local E, db, private = GetElvUINameplateTables()
    local driver = _G.NamePlateDriverFrame
    local manager = _G.C_NamePlateManager
    local namePlateType = _G.Enum and _G.Enum.NamePlateType

    local function val(v)
        if v == nil then return "nil" end
        return tostring(v)
    end

    print("|cff33ff99BattleMender:|r friendly mouse status")
    print("  enabled:", val(CFG.enabled), "sleeping:", val(BattleMender.IsSleeping))
    print("  clickbox:", val(BattleMender.ClickboxResizeMode), "available:", val(BattleMender.ClickboxResizeAvailable))
    print("  BattleMender clickthrough friendly/enemy:", val(CFG.friendlyClickthrough), val(CFG.enemyPlateClickthrough))
    print("  ElvUI:", E and "loaded" or "not loaded")
    if db or private then
        print("  ElvUI nameplates db/private:", val(db and db.enable), val(private and private.enable))
    end
    print("  Native hit-test manager:", manager and "available" or "missing",
        "friendly type:", val(namePlateType and namePlateType.Friendly),
        "API:", val(manager and type(manager.SetNamePlateHitTestInsets) == "function"))
    print("  Legacy native driver:", driver and "available" or "missing",
        "friendly API:", val(driver and type(driver.SetFriendlyInteractible) == "function"))
    print("  Native interactibility applied:", val(BattleMender.NativeNameplateInteractibilityApplied),
        "mode:", val(BattleMender.NameplateHitTestMode),
        "pending:", val(BattleMender.PendingNameplateInteractibility))
    print("  Per-plate hit-test binding:", val(BattleMender.FriendlyHitTestBindingApplied))
    print("  CVar friendly names-only:", val(GetCVar and GetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits")))
    print("  CVar class-colored friendly names:", val(GetCVar and GetCVar("nameplateUseClassColorForFriendlyPlayerUnitNames")))
end

function BattleMender.ApplyNameplateInteractibility()
    -- WoW 12.x exposes per-nameplate-type hit-test insets. BattleMender uses
    -- those public controls for its own clickthrough settings; it no longer
    -- writes ElvUI nameplate interaction settings.
    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingNameplateInteractibility = true
        return false
    end

    BattleMender.PendingNameplateInteractibility = nil
    BattleMender.NativeNameplateInteractibilityApplied = false
    BattleMender.EnemyNameplateInteractibilityApplied = false
    BattleMender.NameplateHitTestMode = "none"

    local manager = _G.C_NamePlateManager
    local namePlateType = _G.Enum and _G.Enum.NamePlateType
    local setInsets = manager and manager.SetNamePlateHitTestInsets
    local friendlyType = namePlateType and namePlateType.Friendly
    local enemyType = namePlateType and namePlateType.Enemy

    local managerApplied = false
    if type(setInsets) == "function" then
        if friendlyType ~= nil then
            -- Negative expands the usable hit target; a very large positive
            -- inset collapses it for BattleMender's Clickthrough mode.
            local inset = CFG.friendlyClickthrough == true and 10000 or -10000
            if pcall(setInsets, friendlyType, inset, inset, inset, inset) then
                BattleMender.NativeNameplateInteractibilityApplied = true
                managerApplied = true
            end
        end

        if enemyType ~= nil then
            local customEnemy = BattleMender.ShouldUseCustomEnemyPlates
                and BattleMender.ShouldUseCustomEnemyPlates()
            if customEnemy then
                local inset = CFG.enemyPlateClickthrough == true and 10000 or -10000
                if pcall(setInsets, enemyType, inset, inset, inset, inset) then
                    BattleMender.EnemyNameplateInteractibilityApplied = true
                    BattleMender.EnemyNameplateHitTestWasManaged = true
                    managerApplied = true
                end
            elseif BattleMender.EnemyNameplateHitTestWasManaged then
                -- Restore Blizzard's neutral/default hit-test inset when
                -- BattleMender stops being the enemy-nameplate provider.
                pcall(setInsets, enemyType, 0, 0, 0, 0)
                BattleMender.EnemyNameplateHitTestWasManaged = nil
            end
        end
    end

    if managerApplied then
        BattleMender.NameplateHitTestMode = CFG.friendlyClickthrough == true
            and "manager-clickthrough" or "manager"
        return true
    end

    -- Older-client fallback for friendly plates. Enemy clickthrough requires the
    -- current C_NamePlateManager API and therefore remains unchanged if absent.
    local driver = _G.NamePlateDriverFrame
    if driver and type(driver.SetFriendlyInteractible) == "function" then
        local interactible = CFG.friendlyClickthrough ~= true
        local ok = pcall(driver.SetFriendlyInteractible, driver, interactible)
        if ok then
            BattleMender.NativeNameplateInteractibilityApplied = true
            BattleMender.NameplateHitTestMode = interactible and "driver" or "driver-clickthrough"
            return true
        end
    end

    return false
end


-- Detect restricted instances (Dungeons, Raids, and Scenarios)
function BattleMender.UpdateInstanceStatus()
    local inInstance, instanceType = IsInInstance()
    local shouldSleep = false

    if inInstance then
        if instanceType == "party" then
            shouldSleep = CFG.disableInDungeons ~= false
        elseif instanceType == "raid" then
            shouldSleep = CFG.disableInRaids ~= false
        elseif instanceType == "scenario" then
            shouldSleep = CFG.disableInScenarios == true
        end
    end

    BattleMender.IsSleeping = shouldSleep

    if shouldSleep then
        BattleMender.Debug("sleeping in", instanceType or "instance")
    end

    if BattleMender.ApplyFriendlyBlizzardVisibility then
        BattleMender.ApplyFriendlyBlizzardVisibility()
    end

    if BattleMender.SetFriendlyClickbox then
        BattleMender.SetFriendlyClickbox()
    end
end

-------------------------------------------------
-- Helpers
-------------------------------------------------
function BattleMender.IsFriendlyPlayer(unit)
    return unit
        and UnitExists(unit)
        and UnitIsPlayer(unit)
        and UnitIsFriend("player", unit)
        and not BattleMender.IsUnitAttackableByPlayer(unit)
end

-- 12.1 can return secret identity values for a friendly nameplate token. Do
-- not ask UnitClass/GetInspectSpecialization to interpret nameplateN directly;
-- resolve the same player through a stable player/party/raid token first.
local FRIENDLY_TOKEN_BY_NAMEPLATE = {}

function BattleMender.GetFriendlyUnitToken(unit)
    if not unit or not UnitExists(unit) then return nil end

    if UnitIsUnit(unit, "player") then
        return "player"
    end

    local cached = FRIENDLY_TOKEN_BY_NAMEPLATE[unit]
    if cached and UnitExists(cached) and UnitIsUnit(unit, cached) then
        return cached
    end

    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, count do
            local candidate = "raid" .. index
            if UnitExists(candidate) and UnitIsUnit(unit, candidate) then
                FRIENDLY_TOKEN_BY_NAMEPLATE[unit] = candidate
                return candidate
            end
        end
    else
        for index = 1, 4 do
            local candidate = "party" .. index
            if UnitExists(candidate) and UnitIsUnit(unit, candidate) then
                FRIENDLY_TOKEN_BY_NAMEPLATE[unit] = candidate
                return candidate
            end
        end
    end

    FRIENDLY_TOKEN_BY_NAMEPLATE[unit] = nil
    return nil
end

local function IsTrainingGroundsArenaInstance()
    if not (C_PvP and type(C_PvP.IsTrainingGroundsArena) == "function") then
        return false
    end
    if type(GetInstanceInfo) ~= "function" then
        return false
    end

    -- Training Grounds: Arena is a 12.1 PvP training queue and can be exposed
    -- through the battleground-style instance path rather than instanceType
    -- "arena". Blizzard added a dedicated classifier for this case; feed it
    -- the active instance's LFG dungeon ID (10th GetInstanceInfo return).
    local okInfo, lfgDungeonID = pcall(function()
        return select(10, GetInstanceInfo())
    end)
    if not okInfo or not lfgDungeonID then
        return false
    end

    local okArena, isTrainingArena = pcall(C_PvP.IsTrainingGroundsArena, lfgDungeonID)
    return okArena and isTrainingArena == true
end

function BattleMender.IsArenaInstance()
    if type(IsInInstance) ~= "function" then return false end

    local ok, inInstance, instanceType = pcall(IsInInstance)
    if not ok or inInstance ~= true then return false end
    if instanceType == "arena" then return true end

    -- 12.1 Training Grounds arenas do not consistently report the legacy
    -- arena instance type, so include Blizzard's explicit training classifier.
    if IsTrainingGroundsArenaInstance() then return true end

    -- Fallback for future arena-like PvP modes. Keep this behind the confirmed
    -- in-instance check so world PvP cannot accidentally receive arena scaling.
    if C_PvP and type(C_PvP.IsMatchConsideredArena) == "function" then
        local okArena, consideredArena = pcall(C_PvP.IsMatchConsideredArena)
        if okArena and consideredArena == true then return true end
    end

    return false
end

-- Environment visibility only governs BattleMender's custom friendly
-- presentation. Blizzard's optional friendly name remains controlled by the
-- normal native-name settings. Arena is intentionally excluded from these
-- World / Rest / BG switches so arena visibility cannot be hidden accidentally.
local function GetFriendlyVisibilityEnvironment()
    if BattleMender.IsArenaInstance and BattleMender.IsArenaInstance() then
        return "ARENA"
    end
    if type(IsInInstance) == "function" then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "pvp" then return "BG" end
    end
    if type(IsResting) == "function" and IsResting() then return "REST" end
    return "WORLD"
end

local function IsReadableValue(value)
    if value == nil then return true end
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end

-- UnitIsUnit(nameplateN, partyN/raidN) is intentionally restricted on modern
-- clients, so GetFriendlyUnitToken cannot be the only group-membership test.
-- In active PvP, UnitName remains readable specifically so addons can present
-- player identity without reconstructing secret unit comparisons. Use that as
-- a safe roster fallback after the stable-token path.
local function GetReadableUnitName(unit)
    if not unit or type(UnitName) ~= "function" then return nil end

    local ok, name, realm = pcall(UnitName, unit)
    if not ok or not name then return nil end
    if not IsReadableValue(name) or not IsReadableValue(realm) then return nil end

    if realm == "" then realm = nil end
    return name, realm
end

local function PublicUnitNamesMatch(unitA, unitB)
    local nameA, realmA = GetReadableUnitName(unitA)
    local nameB, realmB = GetReadableUnitName(unitB)
    if not nameA or not nameB or nameA ~= nameB then return false end

    -- Blizzard commonly omits the realm for same-realm units. If both sides
    -- provide a realm, require it to match; otherwise the public character name
    -- is the best identity signal available to addons in the restricted context.
    if realmA and realmB then
        return realmA == realmB
    end

    return true
end

-- Resolve a friendly visible unit to the stable player/party/raid token that
-- should be used by systems which must bind to a public unit token (for example
-- Blizzard's managed AuraContainer). UnitIsUnit(nameplateN, partyN/raidN) is
-- restricted in active PvP, so fall back to the same public-name roster match
-- used by friendly group visibility. This returns only an existing group token;
-- it never stores or compares restricted GUIDs.
function BattleMender.ResolveFriendlyGroupToken(unit)
    if not unit or not UnitExists(unit) then return nil end

    local direct = BattleMender.GetFriendlyUnitToken and BattleMender.GetFriendlyUnitToken(unit)
    if direct then return direct end

    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, count do
            local candidate = "raid" .. index
            if UnitExists(candidate) and PublicUnitNamesMatch(unit, candidate) then
                return candidate
            end
        end
    elseif IsInGroup and IsInGroup() then
        for index = 1, 4 do
            local candidate = "party" .. index
            if UnitExists(candidate) and PublicUnitNamesMatch(unit, candidate) then
                return candidate
            end
        end
    end

    return nil
end

-- Affiliate relationship helpers ---------------------------------------------
-- HOME means the normal manually formed group in the world and the pre-BG
-- group inside a battleground, rather than Blizzard's temporary INSTANCE raid.
local AFFILIATE_FRIEND_NAMES = {}
local AFFILIATE_FRIEND_GUIDS = {}
local AFFILIATE_FRIEND_CACHE_AT = 0
local AFFILIATE_STATUS_CACHE = {}

local function NormalizeAffiliateText(value)
    if not value or not IsReadableValue(value) then return nil end
    value = tostring(value)
    if value == "" then return nil end
    return string.lower((value:gsub("%s+", "")))
end

local function AddAffiliateFriendName(name, realm)
    if not name or not IsReadableValue(name) then return end
    local rawName = tostring(name)
    local embeddedName, embeddedRealm = rawName:match("^([^%-]+)%-(.+)$")
    if embeddedName then
        rawName = embeddedName
        if not realm or realm == "" then realm = embeddedRealm end
    end

    local nameKey = NormalizeAffiliateText(rawName)
    if not nameKey then return end
    AFFILIATE_FRIEND_NAMES[nameKey] = true

    local realmKey = NormalizeAffiliateText(realm)
    if realmKey then
        AFFILIATE_FRIEND_NAMES[nameKey .. "-" .. realmKey] = true
    end
end

local function RefreshAffiliateFriendCache(force)
    local now = GetTime and GetTime() or 0
    if not force and now > 0 and (now - AFFILIATE_FRIEND_CACHE_AT) < 5 then return end

    AFFILIATE_FRIEND_CACHE_AT = now
    wipe(AFFILIATE_FRIEND_NAMES)
    wipe(AFFILIATE_FRIEND_GUIDS)
    wipe(AFFILIATE_STATUS_CACHE)

    if C_FriendList and type(C_FriendList.GetNumFriends) == "function"
        and type(C_FriendList.GetFriendInfoByIndex) == "function"
    then
        local okCount, count = pcall(C_FriendList.GetNumFriends)
        count = okCount and tonumber(count) or 0
        for index = 1, count do
            local okInfo, info = pcall(C_FriendList.GetFriendInfoByIndex, index)
            if okInfo and type(info) == "table" then
                AddAffiliateFriendName(info.name)
                if info.guid and IsReadableValue(info.guid) then
                    AFFILIATE_FRIEND_GUIDS[info.guid] = true
                end
            end
        end
    end

    if type(BNGetNumFriends) == "function" and C_BattleNet
        and type(C_BattleNet.GetFriendNumGameAccounts) == "function"
        and type(C_BattleNet.GetFriendGameAccountInfo) == "function"
    then
        local okCount, count = pcall(BNGetNumFriends)
        count = okCount and tonumber(count) or 0
        for friendIndex = 1, count do
            local okGames, gameCount = pcall(C_BattleNet.GetFriendNumGameAccounts, friendIndex)
            gameCount = okGames and tonumber(gameCount) or 0
            for accountIndex = 1, gameCount do
                local okGame, game = pcall(C_BattleNet.GetFriendGameAccountInfo, friendIndex, accountIndex)
                if okGame and type(game) == "table"
                    and game.isOnline == true
                    and (not BNET_CLIENT_WOW or game.clientProgram == BNET_CLIENT_WOW)
                then
                    AddAffiliateFriendName(game.characterName, game.realmName)
                    if game.playerGuid and IsReadableValue(game.playerGuid) then
                        AFFILIATE_FRIEND_GUIDS[game.playerGuid] = true
                    end
                end
            end
        end
    end
end

function BattleMender.RefreshAffiliateFriendCache(force)
    RefreshAffiliateFriendCache(force == true)
end

local function IsUnitInHomeGroup(candidate)
    if not candidate then return false end
    local homeCategory = LE_PARTY_CATEGORY_HOME or 1

    -- UnitInParty does not treat battleground raid members as party members, so
    -- its normal one-argument form is already the HOME-party signal we want.
    if type(UnitInParty) == "function" then
        local ok, result = pcall(UnitInParty, candidate)
        if ok and IsReadableValue(result) and result == true then return true end
    end

    -- HOME can also be a manually formed raid. These APIs accept the explicit
    -- party category, keeping it separate from the temporary INSTANCE raid.
    if type(UnitInRaid) == "function" then
        local ok, result = pcall(UnitInRaid, candidate, homeCategory)
        if ok and IsReadableValue(result) and result ~= nil and result ~= false then return true end
    end
    if type(UnitInSubgroup) == "function" then
        local ok, result = pcall(UnitInSubgroup, candidate, homeCategory)
        if ok and IsReadableValue(result) and result == true then return true end
    end

    return false
end

local function IsUnitGuildAffiliate(candidate, fallbackUnit)
    if type(UnitIsInMyGuild) ~= "function" then return false end
    for _, token in ipairs({ candidate, fallbackUnit }) do
        if token then
            local ok, result = pcall(UnitIsInMyGuild, token)
            if ok and IsReadableValue(result) and result == true then return true end
        end
    end
    return false
end

local function IsUnitFriendAffiliate(candidate, fallbackUnit)
    local guid
    for _, token in ipairs({ candidate, fallbackUnit }) do
        if token and type(UnitGUID) == "function" then
            local ok, value = pcall(UnitGUID, token)
            if ok and value and IsReadableValue(value) then
                guid = value
                break
            end
        end
    end

    if guid then
        if C_FriendList and type(C_FriendList.IsFriend) == "function" then
            local ok, result = pcall(C_FriendList.IsFriend, guid)
            if ok and IsReadableValue(result) and result == true then return true end
        end
        if C_BattleNet and type(C_BattleNet.GetAccountInfoByGUID) == "function" then
            local ok, account = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
            if ok and type(account) == "table" and account.isFriend == true then return true end
        end
    end

    RefreshAffiliateFriendCache(false)
    if guid and AFFILIATE_FRIEND_GUIDS[guid] then return true end

    local name, realm = GetReadableUnitName(fallbackUnit or candidate)
    local nameKey = NormalizeAffiliateText(name)
    if not nameKey then return false end
    local realmKey = NormalizeAffiliateText(realm)
    if realmKey then
        return AFFILIATE_FRIEND_NAMES[nameKey .. "-" .. realmKey] == true
    end
    return AFFILIATE_FRIEND_NAMES[nameKey] == true
end

local function GetAffiliateStatusCacheKey(unit)
    local name, realm = GetReadableUnitName(unit)
    local nameKey = NormalizeAffiliateText(name)
    if not nameKey then return nil end
    local realmKey = NormalizeAffiliateText(realm)
    return realmKey and (nameKey .. "-" .. realmKey) or nameKey
end

-- Raw relationship booleans. Settings decide independently whether a relation
-- drives the star/scale and whether it exempts a player from Environment hiding.
-- Results are cached briefly because the active friendly renderer revisits plates
-- for LoS/hover drift and should not query guild/friend APIs every 0.15 seconds.
function BattleMender.GetFriendlyAffiliation(unit)
    if not unit or not UnitExists(unit) then return false, false, false end

    local now = GetTime and GetTime() or 0
    local cacheKey = GetAffiliateStatusCacheKey(unit)
    local cached = cacheKey and AFFILIATE_STATUS_CACHE[cacheKey]
    if cached and now > 0 and (now - cached.at) < 2 then
        return cached.party, cached.guild, cached.friend
    end

    local rosterUnit = BattleMender.ResolveFriendlyGroupToken
        and BattleMender.ResolveFriendlyGroupToken(unit)
    local candidate = rosterUnit or unit

    local inParty = IsUnitInHomeGroup(candidate)
    local inGuild = IsUnitGuildAffiliate(candidate, unit)
    local inFriends = IsUnitFriendAffiliate(candidate, unit)

    if cacheKey then
        AFFILIATE_STATUS_CACHE[cacheKey] = {
            at = now, party = inParty, guild = inGuild, friend = inFriends,
        }
    end

    return inParty, inGuild, inFriends
end

function BattleMender.IsFriendlyAffiliate(unit)
    local inParty, inGuild, inFriends = BattleMender.GetFriendlyAffiliation(unit)
    return (CFG.affiliateParty ~= false and inParty)
        or (CFG.affiliateGuild ~= false and inGuild)
        or (CFG.affiliateFriend ~= false and inFriends)
end

function BattleMender.IsFriendlyGroupMember(unit)
    if not unit or not UnitExists(unit) then return false end

    -- These comparisons are explicitly permitted and cover the local player.
    local okPlayer, isPlayer = pcall(UnitIsUnit, unit, "player")
    if okPlayer and IsReadableValue(isPlayer) and isPlayer == true then
        return true
    end

    -- Outside restricted nameplate contexts the existing stable-token resolver
    -- is still the strongest result and is also used by spec detection.
    if BattleMender.GetFriendlyUnitToken(unit) ~= nil then
        return true
    end

    -- Nameplate-vs-party/raid UnitIsUnit comparisons are unavailable in
    -- restricted PvP. Compare the public UnitName result against the roster
    -- instead. This is only a visibility decision; no secret value is retained.
    if IsInRaid and IsInRaid() then
        local count = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, count do
            local candidate = "raid" .. index
            if UnitExists(candidate) and PublicUnitNamesMatch(unit, candidate) then
                return true
            end
        end
    elseif IsInGroup and IsInGroup() then
        for index = 1, 4 do
            local candidate = "party" .. index
            if UnitExists(candidate) and PublicUnitNamesMatch(unit, candidate) then
                return true
            end
        end
    end

    return false
end

function BattleMender.ShouldShowFriendlyPlate(unit)
    local env = GetFriendlyVisibilityEnvironment()
    if env == "ARENA" then return true end

    local hide = (env == "BG" and CFG.friendlyHideBG == true)
        or (env == "REST" and CFG.friendlyHideRest == true)
        or (env == "WORLD" and CFG.friendlyHideWorld == true)
    if hide then
        local inParty, inGuild, inFriends = BattleMender.GetFriendlyAffiliation(unit)
        if CFG.friendlyHideKeepParty ~= false and inParty then return true end
        if CFG.friendlyHideKeepGuild ~= false and inGuild then return true end
        if CFG.friendlyHideKeepFriends ~= false and inFriends then return true end
        return false
    end

    local groupOnly = (env == "BG" and CFG.friendlyGroupOnlyBG == true)
        or (env == "REST" and CFG.friendlyGroupOnlyRest == true)
        or (env == "WORLD" and CFG.friendlyGroupOnlyWorld == true)
    if groupOnly then
        return BattleMender.IsFriendlyGroupMember(unit)
    end

    return true
end

-- Same-faction and group members can remain socially friendly while they are
-- hostile for an active duel. Use the visible token first; only resolve an
-- equivalent stable group token if the client restricts that result. Keep the
-- boolean coercion inside pcall so a restricted result cannot escape into Lua.
function BattleMender.IsUnitAttackableByPlayer(unit)
    if not unit or type(UnitCanAttack) ~= "function" then
        return false
    end

    local function CanAttack(candidate)
        if not candidate then return false, false end

        local ok, result = pcall(function()
            return UnitCanAttack("player", candidate) and true or false
        end)

        return ok and result == true, ok
    end

    local attackable, readable = CanAttack(unit)
    if readable then
        return attackable
    end

    local stableUnit = BattleMender.GetFriendlyUnitToken
        and BattleMender.GetFriendlyUnitToken(unit)
    if stableUnit and stableUnit ~= unit then
        local stableAttackable = CanAttack(stableUnit)
        return stableAttackable
    end

    return false
end

function BattleMender.ClearFriendlyUnitTokenCache()
    wipe(FRIENDLY_TOKEN_BY_NAMEPLATE)
end

function BattleMender.IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

function BattleMender.GetFriendlyClassFile(unit)
    -- Prefer the stable roster token. In restricted PvP, direct
    -- nameplate-vs-raid UnitIsUnit comparisons can fail, so use the same
    -- public-name resolver that backs the healer CC badge. This guarantees
    -- healer CLASS colors describe the target healer, not the local player.
    local token = BattleMender.GetFriendlyUnitToken(unit)
    if not token and BattleMender.ResolveFriendlyGroupToken then
        token = BattleMender.ResolveFriendlyGroupToken(unit)
    end
    -- In open world cities the direct nameplate result can still be public.
    -- Test it with issecretvalue before doing any Lua table access; in PvP it
    -- will be discarded and the group-token path above remains authoritative.
    token = token or unit

    local ok, _, classFile = pcall(UnitClass, token)
    if ok and classFile and not BattleMender.IsSecretValue(classFile) then
        return classFile
    end

    return nil
end

function BattleMender.ClassColor(unit)
    local classFile = BattleMender.GetFriendlyClassFile(unit)
    local c = classFile and RAID_CLASS_COLORS[classFile]
    return c or NORMAL_FONT_COLOR
end

function BattleMender.ClassIcon(unit)
    local classFile = BattleMender.GetFriendlyClassFile(unit)
    if not classFile then return nil end

    return
        "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",
        CLASS_ICON_TCOORDS[classFile]
end

-------------------------------------------------
-- Refresh
-------------------------------------------------

function BattleMender.RefreshPlate(plate)
    if plate and BattleMender.ApplyToPlate then
        BattleMender.ApplyToPlate(plate)
    end
end

function BattleMender.RefreshUnit(unit)
    if not unit or not BattleMender.ApplyToPlate then return end

    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then
        BattleMender.ApplyToPlate(plate)
    end
end

function BattleMender.RefreshAll()
    local plates = C_NamePlate.GetNamePlates()
    if plates then
        for _, plate in ipairs(plates) do
            BattleMender.RefreshPlate(plate)
        end
    end

    if BattleMender.RefreshEnemyPlateTestMode then
        BattleMender.RefreshEnemyPlateTestMode()
    end

    if BattleMender.UpdateFriendlyTestMode then
        BattleMender.UpdateFriendlyTestMode()
    end
end

-- Lightweight fallback used only for effects whose inputs are not reliably evented
-- by Blizzard nameplates, especially line-of-sight alpha and hover drift.
function BattleMender.RefreshActivePlates()
    if not BattleMender.ApplyToPlate then return end

    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end

    for _, plate in ipairs(plates) do
        local frame = BattleMender.GetVisualFrame and BattleMender.GetVisualFrame(plate)
        local state = frame and BM_STATE[frame]
        local unit = frame and BattleMender.ResolvePlateUnit and BattleMender.ResolvePlateUnit(plate, frame)

        if state and state.active and BattleMender.IsFriendlyPlayer(unit) then
            -- Active friendly plates only need visual refreshes here. Avoid the
            -- full ApplyToPlate path on every LoS tick, because it can collide
            -- with Blizzard's nameplate rebuilds and make the spec icon
            -- blink while the mouse is stationary.
            if BattleMender.UpdateOverlay then
                BattleMender.UpdateOverlay(frame, plate)
            else
                BattleMender.ApplyToPlate(plate)
            end
        elseif (state and state.active)
            or BattleMender.EnemyVisualCompensationActive == true
        then
            -- The 0.15s fallback poll exists for friendly LoS/hover drift.
            -- Custom enemy plates are event-driven and maintain their own cast
            -- and rendered-health polling. Re-running the full enemy update here
            -- caused every visible enemy to rebuild layout, health, cast, aura
            -- containers, flare colors, and portrait several times per second.
            BattleMender.ApplyToPlate(plate)
        end
    end
end

-------------------------------------------------
-- Temporary clickbox preview
-------------------------------------------------
function BattleMender.ShowTemporaryClickboxPreview(duration)
    BattleMender.DebugClickboxVisible = true

    if BattleMender.RefreshActivePlates then
        BattleMender.RefreshActivePlates()
    elseif BattleMender.RefreshAll then
        BattleMender.RefreshAll()
    end

    if BattleMender.ClickboxPreviewTimer then
        BattleMender.ClickboxPreviewTimer:Cancel()
    end

    BattleMender.ClickboxPreviewTimer = C_Timer.NewTimer(duration or 1.75, function()
        BattleMender.DebugClickboxVisible = false
        if BattleMender.RefreshActivePlates then
            BattleMender.RefreshActivePlates()
        elseif BattleMender.RefreshAll then
            BattleMender.RefreshAll()
        end
    end)
end

-------------------------------------------------
-- Clickbox
-------------------------------------------------
local function GetElvUINameplateClickSize(kind, fallbackWidth, fallbackHeight)
    if not _G.ElvUI then
        return fallbackWidth, fallbackHeight
    end

    local ok, E = pcall(function()
        return unpack(_G.ElvUI)
    end)

    if not ok or not E or not E.db or not E.db.nameplates then
        return fallbackWidth, fallbackHeight
    end

    local click = E.db.nameplates.clickSize
    if not click then
        return fallbackWidth, fallbackHeight
    end

    local widthKey = kind .. "Width"
    local heightKey = kind .. "Height"

    return tonumber(click[widthKey]) or fallbackWidth,
        tonumber(click[heightKey]) or fallbackHeight
end

local function RestoreNonFriendlyNameplateSizesAfterGlobalFallback()
    if not C_NamePlate then return end

    -- The global fallback is intentionally allowed because on some clients it is
    -- the only available API that makes the friendly BattleMender icon use a
    -- real square click target. Where Blizzard still exposes enemy/self-specific
    -- sizing APIs, restore those after the global call so enemy visuals are not
    -- compressed into the BattleMender square.
    local enemyWidth, enemyHeight = GetElvUINameplateClickSize("enemy", 110, 45)
    local personalWidth, personalHeight = GetElvUINameplateClickSize("personal", enemyWidth, enemyHeight)

    if type(C_NamePlate.SetNamePlateEnemySize) == "function" then
        pcall(C_NamePlate.SetNamePlateEnemySize, enemyWidth, enemyHeight)
    end

    if type(C_NamePlate.SetNamePlateSelfSize) == "function" then
        pcall(C_NamePlate.SetNamePlateSelfSize, personalWidth, personalHeight)
    end
end

function BattleMender.ApplyCustomEnemyPlateCVars()
    -- ElvUI can leave Blizzard enemy nameplate CVars disabled when its global
    -- NamePlates module is enabled but ENEMY_PLAYER / ENEMY_NPC are turned off.
    -- BattleMender still needs Blizzard to create the underlying NamePlate#
    -- frames so the custom enemy visual layer has something to attach to.
    if not BattleMender.ShouldUseCustomEnemyPlates
        or not BattleMender.ShouldUseCustomEnemyPlates()
    then
        return
    end

    if BattleMender.SetNameplateCVar then
        BattleMender.SetNameplateCVar("nameplateShowEnemies", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyPlayers", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyNPCs", 1)

        -- 12.1 marks enemy UnitClass results secret. The custom renderer
        -- mirrors Blizzard's already-rendered class color instead, which
        -- requires the native enemy class-color source to be enabled.
        if CFG.enemyPlateClassColorNames ~= false
            or CFG.enemyPlateClassColorHealth ~= false
            or CFG.enemyPlateClassColorHealthInPvP ~= false
            or CFG.enemyPlateAuraFlareColorMode == "CLASS"
        then
            BattleMender.SetNameplateCVar("nameplateShowClassColor", 1)
        end

        -- These are harmless on clients where the CVars do not exist, because
        -- SetNameplateCVar already wraps SetCVar and queues safely in combat.
        -- Explicitly include Blizzard's weaker/minus classification. Some packs
        -- use these plates heavily and BattleMender still needs the underlying
        -- NamePlate# object even though its native artwork is suppressed.
        BattleMender.SetNameplateCVar("nameplateShowEnemyMinus", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyMinions", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyPets", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyGuardians", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyTotems", 1)
    end
end

function BattleMender.SetFriendlyClickbox()
    if BattleMender.ApplyCustomEnemyPlateCVars then
        BattleMender.ApplyCustomEnemyPlateCVars()
    end

    local width = CFG.clickSize or 60
    local height = width

    if BattleMender.IsSleeping and CFG.restoreDefaultClickboxInPvE ~= false then
        width = CFG.instanceClickboxWidth or 110
        height = CFG.instanceClickboxHeight or 45
    elseif BattleMender.IsArenaInstance and BattleMender.IsArenaInstance() then
        local arenaScale = tonumber(CFG.arenaFriendlyPlateScale) or 1
        if arenaScale < 1 then arenaScale = 1 end
        if arenaScale > 2 then arenaScale = 2 end
        width = width * arenaScale
        height = height * arenaScale
    end

    local previousClickboxResizeAvailable = BattleMender.ClickboxResizeAvailable
    local previousClickboxResizeMode = BattleMender.ClickboxResizeMode
    local previousCustomEnemyPlatesActive = BattleMender.CustomEnemyPlatesActive

    BattleMender.ClickboxResizeAvailable = false
    BattleMender.ClickboxResizeMode = "none"
    BattleMender.EnemyVisualCompensationActive = false
    BattleMender.CustomEnemyPlatesActive = false

    if not C_NamePlate then
        if BattleMender.ApplyNameplateInteractibility then
            BattleMender.ApplyNameplateInteractibility()
        end
        return false
    end

    -- Nameplate size APIs are protected on current clients. pcall() does not
    -- prevent ADDON_ACTION_BLOCKED reports if this path runs during combat, so
    -- defer all secure clickbox resizing until PLAYER_REGEN_ENABLED.
    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingFriendlyClickboxResize = true
        BattleMender.ClickboxResizeAvailable = previousClickboxResizeAvailable or false
        BattleMender.ClickboxResizeMode = previousClickboxResizeMode or "pending"
        BattleMender.CustomEnemyPlatesActive = BattleMender.ShouldUseCustomEnemyPlates
            and BattleMender.ShouldUseCustomEnemyPlates()
            and previousCustomEnemyPlatesActive
            or false
        return false
    end

    BattleMender.PendingFriendlyClickboxResize = nil

    if type(C_NamePlate.SetNamePlateFriendlySize) == "function" then
        if pcall(C_NamePlate.SetNamePlateFriendlySize, width, height) then
            BattleMender.ClickboxResizeAvailable = true
            BattleMender.ClickboxResizeMode = "friendly"
            BattleMender.CustomEnemyPlatesActive = BattleMender.ShouldUseCustomEnemyPlates
                and BattleMender.ShouldUseCustomEnemyPlates()
                or false
            if BattleMender.ApplyNameplateInteractibility then
                BattleMender.ApplyNameplateInteractibility()
            end
            return true
        end
        return false
    end

    -- Fallback: some 12.x clients no longer expose SetNamePlateFriendlySize.
    -- Use the global square size so friendly BattleMender plates keep a real
    -- Blizzard click target. Enemy visuals are handled by BattleMender's custom
    -- enemy plate layer for users without ElvUI/Plater nameplates.
    if type(C_NamePlate.SetNamePlateSize) == "function" then
        if pcall(C_NamePlate.SetNamePlateSize, width, height) then
            BattleMender.ClickboxResizeAvailable = true
            BattleMender.ClickboxResizeMode = "global"

            BattleMender.CustomEnemyPlatesActive = BattleMender.ShouldUseCustomEnemyPlates
                and BattleMender.ShouldUseCustomEnemyPlates()
                and width == height
                or false

            -- Keep the older geometry-compensation path disabled when the new
            -- custom enemy plate layer is active. It remains available as a
            -- fallback for test builds, but is no longer the default strategy.
            BattleMender.EnemyVisualCompensationActive = false

            if BattleMender.CustomEnemyPlatesActive ~= true then
                RestoreNonFriendlyNameplateSizesAfterGlobalFallback()
            end
            if BattleMender.ApplyNameplateInteractibility then
                BattleMender.ApplyNameplateInteractibility()
            end
            return true
        end
    end

    if BattleMender.ApplyNameplateInteractibility then
        BattleMender.ApplyNameplateInteractibility()
    end
    return false
end

-------------------------------------------------
-- OnUpdate
-------------------------------------------------
local losElapsed = 0

function BattleMender.OnUpdate(_, dt)
    -- Phase 6: no full-nameplate polling here. Only active BattleMender
    -- plates are revisited for LoS alpha / hover visual drift.
    if not BattleMender.RefreshActivePlates then return end

    losElapsed = losElapsed + dt

    if losElapsed >= (CFG.losUpdateRate or 0.15) then
        losElapsed = 0
        BattleMender.RefreshActivePlates()
    end
end


-------------------------------------------------
-- Compatibility Checks
-------------------------------------------------

-- Robust Auto-Off for Clickbox
local function ForceDisableDebug()
    if CFG and CFG.debugClickbox then
        CFG.debugClickbox = false
    end

    BattleMender.DebugClickboxVisible = false

    if BattleMender.ClickboxPreviewTimer then
        BattleMender.ClickboxPreviewTimer:Cancel()
        BattleMender.ClickboxPreviewTimer = nil
    end

    BattleMender.Debug("Hiding Debug Visuals.")

    if BattleMender.RefreshAll then
        BattleMender.RefreshAll()
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------
function BattleMender.OnEvent(self, event, unit, ...)
    if event == "PLAYER_LOGOUT" then
        if BattleMender.DisableTestModes then
            BattleMender.DisableTestModes(true, false)
        else
            ClearTransientTestModesFromTable(CFG)
            BattleMender.SaveDB()
        end
        return
    end

    if event == "INSPECT_READY" then
        if BattleMender.OnInspectReady then
            BattleMender.OnInspectReady(unit)
        end
        return
    end

    -- Login / reload boot path.
    if event == "PLAYER_ENTERING_WORLD" then
        if not INIT_DONE then
            BattleMender.LoadDB()
            if BattleMender.DisableTestModes then
                BattleMender.DisableTestModes(true, false)
            end
            INIT_DONE = true

            if self.InitSettingsPanel then
                self:InitSettingsPanel()
            end

            if BattleMender.InitializeMinimapButton then
                BattleMender.InitializeMinimapButton()
            end

            if CFG.showLoginMessage ~= false then
                local version = BattleMender.GetVersion and BattleMender.GetVersion() or "unknown"
                print("|cff87DE00BattleMender:|r loaded (" .. version .. ").")
            end

			if CFG.showLoginMessage ~= false and BattleMender.WarnElvUIFriendlyNameplates then
				BattleMender.WarnElvUIFriendlyNameplates()
			end
            
        end

        if BattleMender.Defensives and BattleMender.Defensives.Initialize then
            BattleMender.Defensives.Initialize()
        end
        BattleMender.SetFriendlyClickbox()
        BattleMender.UpdateInstanceStatus()
        if BattleMender.RefreshAffiliateFriendCache then
            BattleMender.RefreshAffiliateFriendCache(true)
        end
        if BattleMender.ArenaAudio and BattleMender.ArenaAudio.OnWorldChanged then
            BattleMender.ArenaAudio.OnWorldChanged()
        end
        BattleMender.RefreshAll()
        if BattleMender.Defensives and BattleMender.Defensives.ApplySettings then
            BattleMender.Defensives.ApplySettings(true)
        end
        return
    end

    -- Nameplate lifecycle: targeted, not global.
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- A physical nameplate/unit token may be recycled for a new enemy.
        -- Invalidate any stale BattleMender enemy occupant before resolving the
        -- fresh plate, even if the prior REMOVED event could not resolve it.
        if BattleMender.InvalidateEnemyUnit then
            BattleMender.InvalidateEnemyUnit(unit)
        end

        -- Blizzard can make the removed plate unavailable before
        -- NAME_PLATE_UNIT_REMOVED reaches us. Reset the recycled UnitFrame here
        -- as well, before applying its new unit, so an old hit-test cache cannot
        -- suppress the fresh square hover/click region on this plate.
        if BattleMender.ForgetUnitSpec then
            BattleMender.ForgetUnitSpec(unit)
        end
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate and BattleMender.GetVisualFrame and BattleMender.ClearFriendlyPlate then
            local frame = BattleMender.GetVisualFrame(plate)
            if frame then
                BattleMender.ClearFriendlyPlate(frame)
            end
        end
        BattleMender.RefreshUnit(unit)
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        -- Always invalidate BattleMender's own enemy state first. Blizzard may
        -- already have detached the outer nameplate, but our weak table still
        -- knows which custom plate owned this unit token.
        if BattleMender.InvalidateEnemyUnit then
            BattleMender.InvalidateEnemyUnit(unit)
        end

        -- The plate may already be unavailable by this event. If it is still
        -- accessible, clean it; otherwise the weak state/overlay table will age out.
        if BattleMender.ForgetUnitSpec then
            BattleMender.ForgetUnitSpec(unit)
        end
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate and BattleMender.GetVisualFrame then
            local frame = BattleMender.GetVisualFrame(plate)
            if frame then
                if BattleMender.ClearFriendlyPlate then
                    BattleMender.ClearFriendlyPlate(frame)
                end
                if BattleMender.ClearEnemyVisualCompensation then
                    BattleMender.ClearEnemyVisualCompensation(frame)
                end
            end
        end
        return
    end

    -- Zone changes invalidate all stable group-token mappings and spec data.
    if event == "ZONE_CHANGED_NEW_AREA" then
        if BattleMender.ClearSpecCache then
            BattleMender.ClearSpecCache()
        end
        BattleMender.UpdateInstanceStatus()
        if BattleMender.ArenaAudio and BattleMender.ArenaAudio.OnWorldChanged then
            BattleMender.ArenaAudio.OnWorldChanged()
        end
        BattleMender.RefreshAll()
        -- A settings edit made inside an active PvP map may have deferred
        -- AuraContainer geometry. Leaving the restricted map is the next safe
        -- opportunity to apply it.
        if BattleMender.Defensives and BattleMender.Defensives.ApplySettings then
            BattleMender.Defensives.ApplySettings(true)
        end
        return
    end

    -- This event fires for the player and for party/raid members. Invalidate
    -- only the changed token, then let Spec.lua obtain a fresh INSPECT_READY
    -- result instead of immediately recaching Blizzard's previous spec.
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if BattleMender.ForgetUnitSpec and unit then
            BattleMender.ForgetUnitSpec(unit)
        elseif BattleMender.ClearSpecCache then
            BattleMender.ClearSpecCache()
        end
        if BattleMender.ArenaAudio and BattleMender.ArenaAudio.OnSpecChanged then
            BattleMender.ArenaAudio.OnSpecChanged()
        end
        BattleMender.RefreshAll()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if BattleMender.ClearSpecCache then
            BattleMender.ClearSpecCache()
        end
        if BattleMender.RefreshAffiliateFriendCache then
            BattleMender.RefreshAffiliateFriendCache(true)
        end
        if BattleMender.ArenaAudio and BattleMender.ArenaAudio.OnRosterChanged then
            BattleMender.ArenaAudio.OnRosterChanged()
        end
        BattleMender.RefreshAll()
        return
    end

    if event == "PLAYER_UPDATE_RESTING" then
        if INIT_DONE then
            BattleMender.RefreshAll()
        end
        return
    end

    if event == "SPELLS_CHANGED" then
        -- "Dispellable by Me" derives restricted-context candidate filters
        -- from the active player/pet spellbook. Rebuild visible aura containers
        -- when talents, overrides, or pet abilities change.
        if INIT_DONE then
            BattleMender.RefreshAll()
        end
        return
    end

    -- A same-faction or grouped duel opponent may keep UnitIsFriend=true while
    -- UnitCanAttack changes. Reclassify every visible plate at both boundaries
    -- so it swaps to the enemy style for the duel and back afterward.
    if event == "DUEL_INBOUNDS" or event == "DUEL_FINISHED" then
        BattleMender.RefreshAll()
        return
    end

    -- Unit-targeted visual updates. Keep the custom enemy provider on narrow
    -- component updates for high-frequency events. A full ApplyEnemyPlate here
    -- would also redo layout, portrait, cast and all AuraContainers for every
    -- health/aura event. PvE threat events are intentionally not presentation
    -- events for BattleMender and are not registered.
    if event == "UNIT_HEALTH"
        or event == "UNIT_MAXHEALTH"
        or event == "UNIT_AURA"
    then
        if event == "UNIT_AURA" and BattleMender.ArenaAudio and BattleMender.ArenaAudio.OnUnitAura then
            BattleMender.ArenaAudio.OnUnitAura(unit)
        end

        if BattleMender.HandleEnemyVisualEvent
            and BattleMender.HandleEnemyVisualEvent(event, unit)
        then
            return
        end

        BattleMender.RefreshUnit(unit)
        return
    end

    -- Flags/faction changes are comparatively rare and can affect several
    -- presentation decisions, so retain the complete targeted refresh.
    if event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
        BattleMender.RefreshUnit(unit)
        return
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
        if BattleMender.HandleEnemyCastEvent then
            BattleMender.HandleEnemyCastEvent(event, unit, ...)
        end

        if BattleMender.HandleEnemyVisualEvent
            and BattleMender.HandleEnemyVisualEvent(event, unit)
        then
            return
        end

        BattleMender.RefreshUnit(unit)
        return
    end

    -- Mouseover and target changes can affect hover/ring state on more than one plate.
    if event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_DISABLED" and BattleMender.DisableTestModes then
            -- Preview frames must never remain active in combat. This also
            -- prevents a draggable test plate from intercepting clicks after
            -- the options window is no longer the player's focus.
            BattleMender.DisableTestModes(true, false)
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if BattleMender.ApplyPendingNameplateCVars then
                BattleMender.ApplyPendingNameplateCVars()
            end
            if BattleMender.PendingNameplateLayoutUpdate and BattleMender.ApplyNameplateLayoutUpdate then
                BattleMender.ApplyNameplateLayoutUpdate()
            end
            if BattleMender.PendingNameplateInteractibility and BattleMender.ApplyNameplateInteractibility then
                BattleMender.ApplyNameplateInteractibility()
            end
            if BattleMender.SetFriendlyClickbox then
                BattleMender.SetFriendlyClickbox()
            end
            if BattleMender.Defensives and BattleMender.Defensives.OnCombatEnded then
                BattleMender.Defensives.OnCombatEnded()
            end
            if BattleMender.ArenaAudio and BattleMender.ArenaAudio.OnCombatEnded then
                BattleMender.ArenaAudio.OnCombatEnded()
            end
            if BattleMender.ResumePublicSpecResolution then
                -- City inspect requests deliberately do nothing during combat.
                -- Resume any visible public plates now that inspecting is safe.
                BattleMender.ResumePublicSpecResolution(false)
            end
            if BattleMender.ClearPublicCityCombatSpecs then
                BattleMender.ClearPublicCityCombatSpecs()
            end
        end

        -- Mouseover changes are extremely frequent when the cursor moves across
        -- a raid pack. Do not sweep every visible friendly + enemy nameplate.
        -- Update only the previous/current hovered plate on each provider.
        if event == "UPDATE_MOUSEOVER_UNIT" then
            if BattleMender.RefreshFriendlyHoverState then
                BattleMender.RefreshFriendlyHoverState()
            end
            if BattleMender.RefreshEnemyHoverState then
                BattleMender.RefreshEnemyHoverState()
            end
            return
        end

        BattleMender.RefreshActivePlates()

        if event == "PLAYER_TARGET_CHANGED" then
            if BattleMender.RefreshEnemyTargetState then
                BattleMender.RefreshEnemyTargetState()
            end
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            -- Outside instances the enemy aura renderer can switch between the
            -- manual and managed 12.1 paths at combat boundaries. This is rare
            -- enough to refresh the aura component for visible enemy plates.
            if BattleMender.RefreshEnemyCombatState then
                BattleMender.RefreshEnemyCombatState()
            end
        end
        return
    end
end

-- Event registration is performed in Bootstrap.lua after all modules are loaded.
-- ADDON:RegisterEvent("PLAYER_ENTERING_WORLD")
-- ADDON:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- ADDON:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
-- ADDON:RegisterEvent("GROUP_ROSTER_UPDATE")
-- ADDON:RegisterEvent("DUEL_INBOUNDS")
-- ADDON:RegisterEvent("DUEL_FINISHED")
-- ADDON:RegisterEvent("PLAYER_TARGET_CHANGED")
-- ADDON:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
-- ADDON:RegisterEvent("PLAYER_REGEN_DISABLED") -- Start of combat
-- ADDON:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- ADDON:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- ADDON:RegisterEvent("PLAYER_REGEN_ENABLED")

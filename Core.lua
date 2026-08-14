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

    if overlay.haloFrame then overlay.haloFrame:Hide() end
    if overlay.damagedFrame then overlay.damagedFrame:Hide() end
    if overlay.specFrame then overlay.specFrame:Hide() end
    if overlay.ringFrame then overlay.ringFrame:Hide() end
	if overlay.accentFrame then overlay.accentFrame:Hide() end

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

local defaults = {
    profileSchemaVersion = 9,
    -- General
    enabled = true,
    debug = false,
    updateRate = 0.05,
    losUpdateRate = 0.15,
    clickSize = 60,
    -- Keep BattleMender friendly spec plates visually stable when Blizzard
    -- scales the native nameplate frame by distance/target state/overlap rules.
    -- The secure clickbox still follows Blizzard's native plate; this only
    -- counter-scales BattleMender-owned visual overlay frames.
    friendlyVisualScaleLock = false,
    debugClickbox = false,
    showLoginMessage = true,
    -- ElvUI can leave unit-specific nameplate settings active after its global
    -- nameplate module is disabled. That orphaned state can shrink/misplace
    -- Blizzard friendly mouse regions while BattleMender is using native plates.
    repairElvUIDisabledNameplates = true,
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
    friendlyTestAnchorPoint = "CENTER",
    friendlyTestXOffset = 303,
    friendlyTestYOffset = 97,

    -- Instanced PvE behavior
    disableInDungeons = true,
    disableInRaids = true,
    disableInScenarios = false,
    instanceFriendlyNamesOnly = true,
    instanceClassColorNames = true,
    -- BattleMender keeps Blizzard friendly plates in names-only mode while
    -- active, then maps the native plate's hit-test region to its circular
    -- BattleMender clickbox. No addon-owned secure proxy button is created.
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
    enemyPlateCastHeight = 6,
    enemyPlateNameSize = 8,
    enemyPlateScale = 1.3,
    enemyPlateNonTargetScale = 1,
    enemyPlateTargetScale = 1,
    enemyPlateFocusScale = 1.15,
    enemyPlateShowName = true,
    enemyPlateHidePlayerNamesInPvP = true,
    enemyPlateClassColorNames = true,
    enemyPlateClassColorHealth = true,
    enemyPlateClassColorHealthInPvP = true,
    enemyPlateClassificationColors = true,
    enemyPlateHealthTexture = "CRIMP",
    enemyPlateHealthFillMode = "STATUSBAR",
    enemyPlateHealthTextureCustom = "",
    enemyPlateTargetHealthTexture = "FLAT",
    enemyPlateTargetHealthTextureCustom = "",
    enemyPlateFocusHealthTexture = "RIBBON",
    enemyPlateFocusHealthTextureCustom = "",
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
    enemyPlateNeutralR = 1,
    enemyPlateNeutralG = 0.8705883026123047,
    enemyPlateNeutralB = 0.388235330581665,
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
    enemyPlateClassificationEliteBossR = 0.82,
    enemyPlateClassificationEliteBossG = 0.25,
    enemyPlateClassificationEliteBossB = 0.68,
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
    enemyPlateCastInterruptibleR = 0.8666667342185974,
    enemyPlateCastInterruptibleG = 0.686274528503418,
    enemyPlateCastInterruptibleB = 0.2627451121807098,
    enemyPlateCastNotInterruptibleR = 0.45,
    enemyPlateCastNotInterruptibleG = 0.45,
    enemyPlateCastNotInterruptibleB = 0.45,
    enemyPlateCastTargetPlayerR = 0.6392157077789307,
    enemyPlateCastTargetPlayerG = 0.1882353127002716,
    enemyPlateCastTargetPlayerB = 0.7882353663444519,
    enemyPlateNamePosition = "ABOVE",
    enemyPlateNameXOffset = 0,
    enemyPlateNameYOffset = 0,
    enemyPlateShowAuras = true,
    enemyPlateTestMode = false,
    enemyPlateTestAnchorPoint = "CENTER",
    enemyPlateTestXOffset = 383,
    enemyPlateTestYOffset = 120,
    -- Buff filters mirror the ElvUI-style category UI used by debuffs, but only
    -- expose categories that make sense for helpful auras. Keep the legacy
    -- single value for migration/import compatibility.
    enemyPlateAuraBuffFilter = "HELPFUL|PLAYER",
    enemyPlateBuffUsePlayer = false,
    enemyPlateBuffUseRaidDispellable = false,
    enemyPlateBuffUseDispellable = false,
    enemyPlateBuffUseImportant = false,
    enemyPlateBuffUseRaidInCombat = false,
    enemyPlateBuffPlayerRaid = false,
    enemyPlateBuffPlayerCancelable = false,
    enemyPlateBuffPlayerNotCancelable = false,
    enemyPlateBuffPlayerBigDefensive = true,
    enemyPlateBuffPlayerExternalDefensive = true,
    enemyPlateBuffPlayerBlockPermanent = false,
    enemyPlateBuffOthersRaid = false,
    enemyPlateBuffOthersCancelable = false,
    enemyPlateBuffOthersNotCancelable = false,
    enemyPlateBuffOthersBigDefensive = true,
    enemyPlateBuffOthersExternalDefensive = true,
    enemyPlateBuffOthersBlockPermanent = false,

    -- Debuff filters are multi-select checkboxes. The legacy single value is
    -- retained only as an import fallback; active filtering reads the current
    -- enemyPlateDebuffUse* booleans below.
    enemyPlateAuraDebuffFilter = "PERSONAL",
    enemyPlateDebuffUsePersonal = false,
    -- These are the visible controls in Enemy Plates > Auras > Debuff Filters.
    enemyPlateAuraStackAuras = true,
    enemyPlateAuraDesaturate = false,
    enemyPlateAuraKeepSizeRatio = true,
    enemyPlateDebuffUsePlayer = false,
    enemyPlateDebuffUseRaidDispellable = false,
    enemyPlateDebuffUseDispellable = false,
    enemyPlateDebuffPlayerRaid = false,
    enemyPlateDebuffPlayerCancelable = false,
    enemyPlateDebuffPlayerNotCancelable = false,
    enemyPlateDebuffPlayerCrowdControl = true,
    enemyPlateDebuffPlayerBigDefensive = false,
    enemyPlateDebuffPlayerExternalDefensive = false,
    enemyPlateDebuffPlayerBlockPermanent = true,
    enemyPlateDebuffOthersRaid = false,
    enemyPlateDebuffOthersCancelable = false,
    enemyPlateDebuffOthersNotCancelable = false,
    enemyPlateDebuffOthersCrowdControl = true,
    enemyPlateDebuffOthersBigDefensive = false,
    enemyPlateDebuffOthersExternalDefensive = false,
    enemyPlateDebuffOthersBlockPermanent = true,

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
    enemyPlateSelfBuffsOnly = false,
    enemyPlateShowDebuffs = true,
    enemyPlateDebuffAurasTargetOnly = false,
    enemyPlatePersonalDebuffsOnly = false,

    -- Split aura category layout. Buffs, debuffs, and custom auras are rendered
    -- as separate groups so each can have independent size, growth, anchoring,
    -- and filtering. The legacy enemyPlateAura* keys above remain as fallback
    -- values for profiles from earlier BattleMender builds.
    enemyPlateBuffAuraSize = 30,
    enemyPlateBuffAuraPerRow = 2,
    enemyPlateBuffAuraRows = 1,
    enemyPlateBuffAuraSpacing = 3,
    enemyPlateBuffAuraXOffset = -3,
    enemyPlateBuffAuraYOffset = 12,
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

    enemyPlateCustomAurasEnabled = true,
    enemyPlateCustomAurasTargetOnly = true,
    -- Custom is a true third aura container: it can independently select
    -- native helpful and harmful categories.
    enemyPlateCustomShowBuffs = false,
    enemyPlateCustomShowDebuffs = false,
    enemyPlateCustomBuffUsePlayer = false,
    enemyPlateCustomBuffUseRaidDispellable = false,
    enemyPlateCustomBuffUseDispellable = false,
    enemyPlateCustomBuffUseImportant = false,
    enemyPlateCustomBuffUseRaidInCombat = false,
    enemyPlateCustomBuffPlayerRaid = false,
    enemyPlateCustomBuffPlayerCancelable = false,
    enemyPlateCustomBuffPlayerNotCancelable = false,
    enemyPlateCustomBuffPlayerBigDefensive = false,
    enemyPlateCustomBuffPlayerExternalDefensive = false,
    enemyPlateCustomBuffPlayerBlockPermanent = false,
    enemyPlateCustomBuffOthersRaid = false,
    enemyPlateCustomBuffOthersCancelable = false,
    enemyPlateCustomBuffOthersNotCancelable = false,
    enemyPlateCustomBuffOthersBigDefensive = false,
    enemyPlateCustomBuffOthersExternalDefensive = false,
    enemyPlateCustomBuffOthersBlockPermanent = false,
    enemyPlateCustomDebuffUsePlayer = false,
    enemyPlateCustomDebuffUseRaidDispellable = false,
    enemyPlateCustomDebuffUseDispellable = false,
    enemyPlateCustomDebuffPlayerRaid = false,
    enemyPlateCustomDebuffPlayerCrowdControl = false,
    enemyPlateCustomDebuffPlayerBlockPermanent = false,
    enemyPlateCustomDebuffOthersRaid = false,
    enemyPlateCustomDebuffOthersCrowdControl = false,
    enemyPlateCustomDebuffOthersBlockPermanent = false,
    enemyPlateCustomAuraSize = 16,
    enemyPlateCustomAuraPerRow = 5,
    enemyPlateCustomAuraRows = 1,
    enemyPlateCustomAuraSpacing = 2,
    enemyPlateCustomAuraXOffset = 0,
    enemyPlateCustomAuraYOffset = 2,
    enemyPlateCustomAuraAttachTo = "HEALTH",
    enemyPlateCustomAuraAnchorPoint = "BOTTOMLEFT",
    enemyPlateCustomAuraAttachPoint = "TOPLEFT",
    enemyPlateCustomAuraGrowthX = "RIGHT",
    enemyPlateCustomAuraGrowthY = "UP",
    enemyPlateCustomAuraAlign = "LEFT",
    enemyPlateCustomAuraDesaturate = true,
    enemyPlateCustomAuraKeepSizeRatio = true,
    enemyPlateCustomAuraCooldownSwipe = false,
    enemyPlateCustomAuraFlat = true,
    enemyPlateCastUpdateRate = 0.01,
    enemyPlatePortraitEnabled = false,
    enemyPlatePortraitHideInBG = true,
    enemyPlatePortraitSize = 24,
    enemyPlatePortraitMode = "CLASS",
    enemyPlatePortraitPosition = "LEFT",
    enemyPlatePortraitXOffset = 28,
    enemyPlatePortraitYOffset = 19,
    enemyPlateObjectiveIndicator = false,

    -- Positioning
    iconSize = 45,
    anchorMode = "TOP",
    anchorPoint = "TOP",
    anchorX = 0,
    anchorY = -9,

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

    -- Damaged / missing-health visual
    damageIconAlpha = 1,
    damageIconR = 1,
    damageIconG = 0.125490203499794,
    damageIconB = 0,
    damageIconBlendMode = "BLEND",

    -- Fallback when spec is unknown
    damageIconFallbackR = 1,
    damageIconFallbackG = 0.02,
    damageIconFallbackB = 0.02,
    damageIconFallbackBlendMode = "BLEND",

    -- Class ring
    ringEnabled = true,
    ringTexture = "Metal_Ring",
    ringScale = 1.13,
    ringAlpha = 1,

    -- Accent Overlay
    accentOverlayEnabled = true,
    accentOverlayTexture = "Glass_Ring",
    accentOverlayScale = 1,
    accentOverlayAlpha = 1,
    accentOverlayBlendMode = "BLEND",
    accentOverlayUseClassColor = false,
    accentOverlayColorR = 1,
    accentOverlayColorG = 1,
    accentOverlayColorB = 1,

    -- Accent Overlay hover
    accentOverlayGlowEnabled = false,
    accentOverlayGlowBrightness = 0.2,
    accentOverlayGlowFadeIn = 0.15,
    accentOverlayGlowFadeOut = 0.15,

    -- Health overlay
    healthEnable = true,
    healthOverlayAlpha = 1,
    healthOverlayBlendMode = "BLEND",
    healthOverlayUseClassColor = false,
    healthOverlayColorR = 1,
    healthOverlayColorG = 0.9725490808486938,
    healthOverlayColorB = 0.9803922176361084,
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

    pulseEnable = false,
    pulseSpeed = 0.4,
    pulseIntensity = 0.2,
    pulseOverlayEnable = false,
    pulseOverlayTexture = "Circle_AlphaGradient_Out",
    pulseOverlayBlend = "BLEND",
    pulseOverlayAlpha = 0.3,

    haloEnabled = false,
    haloGlowTexture = "Circle_Halo_1",
    haloGlowSizeScale = 2,
    haloGlowAlpha = 0.5,

    -- Line of sight state
    losIconAlpha = 0.8,

    losSpecIconDesaturate = false,
    losSpecIconAlpha = 0.40000000596046,
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

    -- Class ring while out of line of sight
    losRingTexture = "SAME",
    losRingAlpha = 0.94999998807907,
    losRingAlphaMultiplier = 1,

    -- LoS Accent Overlay
    losAccentOverlayTexture = "Glass_Ring",
    losAccentOverlayScale = 0.95,
    losAccentOverlayAlpha = 0.4,
    losAccentOverlayBlendMode = "ADD",
    losAccentOverlayUseClassColor = false,
    losAccentOverlayColorR = 1,
    losAccentOverlayColorG = 1,
    losAccentOverlayColorB = 1,

    -- LoS Accent Overlay hover
    losAccentOverlayGlowEnabled = true,
    losAccentOverlayGlowBrightness = 0.1,
    losAccentOverlayGlowFadeIn = 0.1,
    losAccentOverlayGlowFadeOut = 0.15,

    losPulseEnable = false,
    losPulseSpeed = 0.1,
    losPulseIntensity = 0.85,
    losPulseOverlayEnable = false,
    losPulseOverlayTexture = "Circle_Smooth2",
    losPulseOverlayBlend = "ADD",
    losPulseOverlayAlpha = 1,

    -- Friendly defensive and immunity displays. The renderer uses Blizzard's
    -- 12.1 AuraContainer to select, show, and time the configured helpful
    -- auras; these keys control only BattleMender-owned presentation.
    -- Keep this opt-in until AuraContainer's inactive-button lifecycle is
    -- confirmed on live. The PTR renderer can otherwise paint blank immunity
    -- rings over ordinary friendly spec icons.
    defensiveDisplayEnabled = false,
    defensiveVisualRevision = 5,
    majorDefensiveEnabled = true,
    majorDefensiveBadgeScale = 0.72,
    majorDefensiveLayer = "BEHIND",
    majorDefensiveDistanceScale = 0.53,
    majorDefensiveAngle = 42,
    majorDefensiveBorderTexture = "NORMAL",
    majorDefensiveBorderScale = 1.18,
    majorDefensiveBorderAlpha = 1,
    majorDefensiveBorderColorMode = "AUTO",
    majorDefensiveCustomR = 0.30,
    majorDefensiveCustomG = 0.72,
    majorDefensiveCustomB = 1,
    immunityDisplayEnabled = true,
    immunityReplaceSpecIcon = true,
    immunityIconScale = 1,
    immunityRingScale = 1.18,
    immunityRingAlpha = 0.92,
    immunityGlowEnabled = true,
    immunityGlowAlpha = 0.42,
    immunityGlowSpeed = 0.90,
    immunityCooldownSwipe = true,
    immunityCooldownRingAlpha = 0.92,
}

BattleMender.Defaults = defaults

local CFG = {}
BattleMender.CFG = CFG 

-------------------------------------------------
-- Transient / session-only options
-------------------------------------------------
local TRANSIENT_TEST_MODE_KEYS = {
    friendlyTestMode = true,
    enemyPlateTestMode = true,
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

local CURRENT_PROFILE_SCHEMA = 9

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
        if rawget(db, "enemyPlateAuraBuffFilter") == "HELPFUL|NOT_CANCELABLE" then
            db.enemyPlateAuraBuffFilter = "HELPFUL|!CANCELABLE"
        end
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

    if BattleMender.UpdateInstanceStatus then
        BattleMender.UpdateInstanceStatus()
    elseif BattleMender.SetFriendlyClickbox then
        BattleMender.SetFriendlyClickbox()
    end

    if BattleMender.RefreshAll then
        BattleMender.RefreshAll()
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
end

function BattleMender.SaveDB()
    local target = BattleMender.DB and BattleMender.DB.profile or BattleMenderDB

    for key, defaultValue in pairs(defaults) do
        local value = CFG[key]
        if value == nil then
            value = defaultValue
        end
        target[key] = CopyDefaultValue(value)
    end
end

function BattleMender.SaveRefresh()
    BattleMender.SaveDB()
    if BattleMender.ApplyCustomEnemyPlateCVars then
        BattleMender.ApplyCustomEnemyPlateCVars()
    end
    BattleMender.RefreshAll()
    if BattleMender.Defensives and BattleMender.Defensives.ApplySettings then
        BattleMender.Defensives.ApplySettings(true)
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

            if key and defaults[key] ~= nil then
                local decoded = DecodeProfileValue(valueType, encoded)
                local defaultType = type(defaults[key])

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

    for key in pairs(defaults) do
        if imported[key] ~= nil then
            target[key] = CopyDefaultValue(imported[key])
        else
            target[key] = CopyDefaultValue(defaults[key])
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
-- Native friendly nameplate CVars
--
-- Do not hide Blizzard health bars by mutating frame.healthBar.
-- That taints Blizzard's nameplate aura/cast/health prediction paths.
-- Use the supported friendly-name-only CVar instead, and keep BattleMender's
-- custom overlay drawn on top of the remaining native nameplate frame.
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

function BattleMender.RepairElvUIDisabledNameplateState()
    if CFG.repairElvUIDisabledNameplates == false then
        return false
    end

    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingElvUINameplateRepair = true
        return false
    end

    local E, db = GetElvUINameplateTables()
    if not E or not db then
        return false
    end

    if not BattleMender.IsElvUILoadedWithNameplatesDisabled() then
        return false
    end

    local changed = false

    if type(db.clickThrough) == "table" then
        if db.clickThrough.friendly ~= false then
            db.clickThrough.friendly = false
            changed = true
        end

        if db.clickThrough.enemy ~= false then
            db.clickThrough.enemy = false
            changed = true
        end
    end

    if type(db.units) == "table" then
        for _, key in ipairs(ELVUI_NAMEPLATE_UNIT_KEYS) do
            local unitDB = db.units[key]
            if type(unitDB) == "table" and unitDB.enable ~= false then
                unitDB.enable = false
                changed = true
            end
        end
    end

    if changed then
        BattleMender.ElvUINameplateStateRepaired = true
        BattleMender.Debug("repaired ElvUI disabled-nameplate unit toggles")
    end

    -- Do not call ElvUI's SetNamePlateClickThrough or ConfigureAll here. In the
    -- exact broken state, ElvUI's nameplate driver can be nil, and calling into
    -- it caused PlateDriver errors. The corrected DB state is enough after
    -- reload/reconfigure, and BattleMender reapplies Blizzard sizing below.
    return changed
end


function BattleMender.PrintFriendlyMouseStatus()
    local E, db, private = GetElvUINameplateTables()
    local units = db and db.units
    local fp = units and units.FRIENDLY_PLAYER
    local click = db and db.clickThrough
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
    print("  ElvUI:", E and "loaded" or "not loaded")
    if db or private then
        print("  ElvUI nameplates db/private:", val(db and db.enable), val(private and private.enable))
        print("  ElvUI clickThrough.friendly:", val(click and click.friendly))
        print("  ElvUI FRIENDLY_PLAYER.enable:", val(fp and fp.enable), "clickThrough:", val(fp and fp.clickThrough or (fp and fp.clickthrough)))
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

function BattleMender.ScheduleElvUIDisabledNameplateRepair()
    local function ReapplyNativeClickboxState()
        local repaired = false
        if CFG.repairElvUIDisabledNameplates ~= false then
            repaired = BattleMender.RepairElvUIDisabledNameplateState() == true
        end

        local resized = false
        if BattleMender.SetFriendlyClickbox then
            resized = BattleMender.SetFriendlyClickbox() == true
        elseif BattleMender.ApplyNameplateInteractibility then
            resized = BattleMender.ApplyNameplateInteractibility() == true
        end

        if (repaired or resized) and BattleMender.RefreshAll then
            BattleMender.RefreshAll()
        end
    end

    -- Blizzard and UI replacements can reapply their nameplate state during the
    -- login sequence. Reassert the native hit-test state and secure size
    -- immediately and again after the frame tree has settled.
    ReapplyNativeClickboxState()

    if C_Timer and C_Timer.After then
        C_Timer.After(0, ReapplyNativeClickboxState)
        C_Timer.After(1, ReapplyNativeClickboxState)
    end
end

function BattleMender.ApplyNameplateInteractibility()
    -- WoW 12.x controls nameplate mouse interaction through per-type hit-test
    -- insets. A large negative inset marks the friendly plate type as
    -- interactible; the exact clickable geometry is then supplied per plate by
    -- SetAllHitTestPoints in Overlay.lua.
    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingNameplateInteractibility = true
        return false
    end

    BattleMender.PendingNameplateInteractibility = nil
    BattleMender.NativeNameplateInteractibilityApplied = false
    BattleMender.NameplateHitTestMode = "none"

    local manager = _G.C_NamePlateManager
    local namePlateType = _G.Enum and _G.Enum.NamePlateType
    local setInsets = manager and manager.SetNamePlateHitTestInsets
    local friendlyType = namePlateType and namePlateType.Friendly

    if type(setInsets) == "function" and friendlyType ~= nil then
        local inset = -10000
        local ok = pcall(setInsets, friendlyType, inset, inset, inset, inset)
        if ok then
            BattleMender.NativeNameplateInteractibilityApplied = true
            BattleMender.NameplateHitTestMode = "manager"
            return true
        end
    end

    -- Older-client fallback. This path is intentionally secondary because the
    -- current retail API is C_NamePlateManager.SetNamePlateHitTestInsets.
    local driver = _G.NamePlateDriverFrame
    if driver and type(driver.SetFriendlyInteractible) == "function" then
        local ok = pcall(driver.SetFriendlyInteractible, driver, true)
        if ok then
            BattleMender.NativeNameplateInteractibilityApplied = true
            BattleMender.NameplateHitTestMode = "driver"
            return true
        end
    end

    return false
end

function BattleMender.ApplyFriendlyNameOnlyCVar()
    if InCombatLockdown and InCombatLockdown() then
        BattleMender.PendingFriendlyNameOnlyCVar = true
        return false
    end

    BattleMender.PendingFriendlyNameOnlyCVar = nil

    local namesOnly = 1
    local classColorNames = 1

    if BattleMender.IsSleeping then
        namesOnly = CFG.instanceFriendlyNamesOnly ~= false and 1 or 0
        classColorNames = CFG.instanceClassColorNames ~= false and 1 or 0
    end

    local namesApplied = BattleMender.SetNameplateCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", namesOnly)
    local colorsApplied = BattleMender.SetNameplateCVar("nameplateUseClassColorForFriendlyPlayerUnitNames", classColorNames)
    return namesApplied or colorsApplied
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

    BattleMender.ApplyFriendlyNameOnlyCVar()

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

function BattleMender.ClearFriendlyUnitTokenCache()
    wipe(FRIENDLY_TOKEN_BY_NAMEPLATE)
end

function BattleMender.IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

function BattleMender.GetFriendlyClassFile(unit)
    local token = BattleMender.GetFriendlyUnitToken(unit)
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
            -- with Blizzard's name-only plate rebuilds and make the spec icon
            -- blink while the mouse is stationary.
            if BattleMender.UpdateOverlay then
                BattleMender.UpdateOverlay(frame, plate)
            else
                BattleMender.ApplyToPlate(plate)
            end
        elseif (state and state.active)
            or BattleMender.EnemyVisualCompensationActive == true
            or BattleMender.CustomEnemyPlatesActive == true
        then
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
        then
            BattleMender.SetNameplateCVar("nameplateShowClassColor", 1)
        end

        -- These are harmless on clients where the CVars do not exist, because
        -- SetNameplateCVar already wraps SetCVar and queues safely in combat.
        BattleMender.SetNameplateCVar("nameplateShowEnemyMinions", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyPets", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyGuardians", 1)
        BattleMender.SetNameplateCVar("nameplateShowEnemyTotems", 1)
    end
end

function BattleMender.SetFriendlyClickbox()
    if BattleMender.RepairElvUIDisabledNameplateState then
        BattleMender.RepairElvUIDisabledNameplateState()
    end

    if BattleMender.ApplyFriendlyNameOnlyCVar then
        BattleMender.ApplyFriendlyNameOnlyCVar()
    end

    if BattleMender.ApplyCustomEnemyPlateCVars then
        BattleMender.ApplyCustomEnemyPlateCVars()
    end

    local width = CFG.clickSize or 60
    local height = width

    if BattleMender.IsSleeping and CFG.restoreDefaultClickboxInPvE ~= false then
        width = CFG.instanceClickboxWidth or 110
        height = CFG.instanceClickboxHeight or 45
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
            BattleMender.OnInspectReady()
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

        if BattleMender.ScheduleElvUIDisabledNameplateRepair then
            BattleMender.ScheduleElvUIDisabledNameplateRepair()
        end
        if BattleMender.Defensives and BattleMender.Defensives.Initialize then
            BattleMender.Defensives.Initialize()
        end
        BattleMender.SetFriendlyClickbox()
        BattleMender.UpdateInstanceStatus()
        BattleMender.RefreshAll()
        if BattleMender.Defensives and BattleMender.Defensives.ApplySettings then
            BattleMender.Defensives.ApplySettings(true)
        end
        return
    end

    -- Nameplate lifecycle: targeted, not global.
    if event == "NAME_PLATE_UNIT_ADDED" then
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

    -- Context changes can affect every visible plate.
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if BattleMender.ClearSpecCache then
            BattleMender.ClearSpecCache()
        end
        BattleMender.UpdateInstanceStatus()
        BattleMender.RefreshAll()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if BattleMender.ClearSpecCache then
            BattleMender.ClearSpecCache()
        end
        BattleMender.RefreshAll()
        return
    end

    -- Unit-targeted visual updates.
    if event == "UNIT_HEALTH"
        or event == "UNIT_MAXHEALTH"
        or event == "UNIT_FLAGS"
        or event == "UNIT_FACTION"
        or event == "UNIT_AURA"
        or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_THREAT_SITUATION_UPDATE"
    then
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
            BattleMender.HandleEnemyCastEvent(event, unit)
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
            if BattleMender.PendingFriendlyNameOnlyCVar then
                BattleMender.ApplyFriendlyNameOnlyCVar()
            end
            if BattleMender.PendingElvUINameplateRepair and BattleMender.RepairElvUIDisabledNameplateState then
                BattleMender.PendingElvUINameplateRepair = nil
                BattleMender.RepairElvUIDisabledNameplateState()
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
            if BattleMender.ResumePublicSpecResolution then
                -- City inspect requests deliberately do nothing during combat.
                -- Resume any visible public plates now that inspecting is safe.
                BattleMender.ResumePublicSpecResolution(false)
            end
            if BattleMender.ClearPublicCityCombatSpecs then
                BattleMender.ClearPublicCityCombatSpecs()
            end
        end

        BattleMender.RefreshActivePlates()
        return
    end
end

-- Event registration is performed in Bootstrap.lua after all modules are loaded.
-- ADDON:RegisterEvent("PLAYER_ENTERING_WORLD")
-- ADDON:RegisterEvent("NAME_PLATE_UNIT_ADDED")
-- ADDON:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
-- ADDON:RegisterEvent("GROUP_ROSTER_UPDATE")
-- ADDON:RegisterEvent("PLAYER_TARGET_CHANGED")
-- ADDON:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
-- ADDON:RegisterEvent("PLAYER_REGEN_DISABLED") -- Start of combat
-- ADDON:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- ADDON:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- ADDON:RegisterEvent("PLAYER_REGEN_ENABLED")

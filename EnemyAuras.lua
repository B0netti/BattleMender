BattleMender = BattleMender or {}

local BM = BattleMender
local EPI = BM.EnemyPlateInternal
local CFG = EPI.CFG
local TEST_AURA_DATA = EPI.TEST_AURA_DATA
local IsTestUnit = EPI.IsTestUnit
local GetFallbackAuraIcon = EPI.GetFallbackAuraIcon
local SafeText = EPI.SafeText
local AuraIsPermanent = EPI.AuraIsPermanent
local AuraHasNameplateSignal = EPI.AuraHasNameplateSignal
local SafeUnitIsUnit = EPI.SafeUnitIsUnit
local AddBorder = EPI.AddBorder
local UnitLooksLikePlayer = EPI.UnitLooksLikePlayer
local ConfigColor = EPI.ConfigColor
local UnitIsCurrentTarget = EPI.UnitIsCurrentTarget
local GetSafeEnemyClassPoolKey = EPI.GetSafeEnemyClassPoolKey
local AURA_CATEGORIES = EPI.AURA_CATEGORIES
local SELECTABLE_AURA_SETTING_PREFIX = EPI.SELECTABLE_AURA_SETTING_PREFIX
local AuraConfig = EPI.AuraConfig
local GetAuraLayoutMetrics = EPI.GetAuraLayoutMetrics
local EnsureAuraCategoryFrame = EPI.EnsureAuraCategoryFrame
local SetupAuraCategoryFrame = EPI.SetupAuraCategoryFrame
local ApplyAuraFlare = EPI.ApplyAuraFlare

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
                dispelName = dispelType,
                isStealable = isStealable,
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

-- "Dispellable by Me" cannot use RAID_PLAYER_DISPELLABLE because that
-- category deliberately includes purge/steal capability from other group
-- members. In unrestricted contexts AuraData.canActivePlayerDispel is exact.
-- In 12.1 restricted aura contexts, the managed AuraContainer cannot expose
-- that field to addon Lua, so derive the player's offensive dispel capability
-- from the current spellbook and let Blizzard filter by dispel type.
local PLAYER_DISPEL_INCLUDE_PREFIX = "BM_PLAYER_DISPELLABLE_INCLUDE::"
local PLAYER_DISPEL_EXCLUDE_PREFIX = "BM_PLAYER_DISPELLABLE_EXCLUDE::"

local PLAYER_OFFENSIVE_DISPELS = {
    -- Magic purge / remove
    [370] = { magicPurge = true },       -- Purge
    [378773] = { magicPurge = true },    -- Greater Purge
    [528] = { magicPurge = true },       -- Dispel Magic
    [278326] = { magicPurge = true },    -- Consume Magic
    [1276610] = { magicPurge = true },   -- Warlock Devour Magic (12.1 talent/override)

    -- Magic steal: unlike a purge, only stealable Magic buffs qualify.
    [30449] = { magicSteal = true },     -- Spellsteal

    -- Magic + Enrage
    [19801] = { magicPurge = true, enrage = true },
    [455641] = { magicPurge = true, enrage = true }, -- current override

    -- Enrage-only removals
    [2908] = { enrage = true },          -- Soothe
    [5938] = { enrage = true },          -- Shiv
}

local PET_OFFENSIVE_DISPELS = {
    [19505] = { magicPurge = true },     -- Felhunter: Devour Magic
}

local function SpellKnownInBank(spellID, bank)
    if not C_SpellBook then return false end

    local fn = C_SpellBook.IsSpellKnownOrInSpellBook
        or C_SpellBook.IsSpellKnown
        or C_SpellBook.IsSpellInSpellBook
    if type(fn) ~= "function" then return false end

    local ok, known = pcall(fn, spellID, bank, true)
    return ok and known == true
end

local function GetPlayerOffensiveDispelProfile()
    local profile = {
        magicPurge = false,
        magicSteal = false,
        enrage = false,
    }

    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1

    local function applyKnown(map, bank)
        for spellID, capability in pairs(map) do
            if SpellKnownInBank(spellID, bank) then
                if capability.magicPurge then profile.magicPurge = true end
                if capability.magicSteal then profile.magicSteal = true end
                if capability.enrage then profile.enrage = true end
            end
        end
    end

    applyKnown(PLAYER_OFFENSIVE_DISPELS, playerBank)
    applyKnown(PET_OFFENSIVE_DISPELS, petBank)
    return profile
end

local function PlayerOffensiveDispelSignature()
    local p = GetPlayerOffensiveDispelProfile()
    return (p.magicPurge and "P" or "-")
        .. (p.magicSteal and "S" or "-")
        .. (p.enrage and "E" or "-")
end

local function EncodePlayerDispellableMode(mode, exclude)
    return (exclude and PLAYER_DISPEL_EXCLUDE_PREFIX or PLAYER_DISPEL_INCLUDE_PREFIX) .. mode
end

local function DecodePlayerDispellableMode(mode)
    if type(mode) ~= "string" then return mode, nil end
    if mode:sub(1, #PLAYER_DISPEL_INCLUDE_PREFIX) == PLAYER_DISPEL_INCLUDE_PREFIX then
        return mode:sub(#PLAYER_DISPEL_INCLUDE_PREFIX + 1), "INCLUDE"
    end
    if mode:sub(1, #PLAYER_DISPEL_EXCLUDE_PREFIX) == PLAYER_DISPEL_EXCLUDE_PREFIX then
        return mode:sub(#PLAYER_DISPEL_EXCLUDE_PREFIX + 1), "EXCLUDE"
    end
    return mode, nil
end

local function AuraCanActivePlayerDispel(aura)
    if not aura then return false end

    local ok, value, hasValue = pcall(function()
        local v = aura.canActivePlayerDispel
        if issecretvalue and issecretvalue(v) then
            return false, false
        end
        if v == nil then
            return false, false
        end
        return v == true, true
    end)
    if ok and hasValue then
        return value == true
    end

    -- Legacy/out-of-combat fallback for clients that do not populate
    -- canActivePlayerDispel on AuraData. Keep all comparisons inside pcall so
    -- an unexpectedly restricted dispel field never escapes into addon Lua.
    local readable, canDispel = pcall(function()
        local dispelName = aura.dispelName
        local stealableValue = aura.isStealable
        if issecretvalue and (issecretvalue(dispelName) or issecretvalue(stealableValue)) then
            return false
        end

        local profile = GetPlayerOffensiveDispelProfile()
        if dispelName == "Magic" then
            return profile.magicPurge or (profile.magicSteal and stealableValue == true)
        end
        if dispelName == "Enrage" then
            return profile.enrage
        end
        return false
    end)
    return readable and canDispel == true
end

-- One encoded mode can expand to more than one AuraGroup. This is required for
-- Spellsteal exclusions: NOT (Magic AND stealable) is represented as non-Magic
-- plus Magic/non-stealable groups without reading restricted AuraData.
local function ExpandManagedPlayerDispelMode(encodedMode)
    local mode, disposition = DecodePlayerDispellableMode(encodedMode)
    if not disposition then
        return { { filter = mode, candidateFilters = {} } }
    end

    local profile = GetPlayerOffensiveDispelProfile()
    local groups = {}
    local hasMagic = profile.magicPurge or profile.magicSteal
    local hasAny = hasMagic or profile.enrage
    if not hasAny then
        if disposition == "EXCLUDE" then
            return { { filter = mode, candidateFilters = {} } }
        end
        return groups
    end

    if disposition == "INCLUDE" then
        local includeTypes = {}
        if profile.magicPurge then includeTypes.Magic = true end
        if profile.enrage then includeTypes.Enrage = true end

        if next(includeTypes) then
            groups[#groups + 1] = {
                filter = mode,
                candidateFilters = { includeDispelTypes = includeTypes },
            }
        end

        if profile.magicSteal and not profile.magicPurge then
            groups[#groups + 1] = {
                filter = mode,
                candidateFilters = {
                    includeDispelTypes = { Magic = true },
                    isStealable = true,
                },
            }
        end
        return groups
    end

    local excludeTypes = {}
    if profile.magicPurge then excludeTypes.Magic = true end
    if profile.enrage then excludeTypes.Enrage = true end

    if profile.magicSteal and not profile.magicPurge then
        -- Keep all non-Magic (and, if relevant, non-Enrage) auras.
        local firstExclude = { Magic = true }
        if profile.enrage then firstExclude.Enrage = true end
        groups[#groups + 1] = {
            filter = mode,
            candidateFilters = { excludeDispelTypes = firstExclude },
        }
        -- Also keep Magic buffs that the mage cannot actually steal.
        groups[#groups + 1] = {
            filter = mode,
            candidateFilters = {
                includeDispelTypes = { Magic = true },
                isStealable = false,
            },
        }
        return groups
    end

    groups[#groups + 1] = {
        filter = mode,
        candidateFilters = next(excludeTypes) and { excludeDispelTypes = excludeTypes } or {},
    }
    return groups
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

        if CFG.enemyPlateBuffUsePlayerDispellable == true then
            local mode = AuraFilterMode(baseFilter, sourceToken, "DISPELLABLE|INCLUDE_NAME_PLATE_ONLY")
            for _, token in ipairs(exclusions) do
                if not ("|" .. mode .. "|"):find("|" .. token .. "|", 1, true) then
                    mode = mode .. "|" .. token
                end
            end
            AddAuraMode(modes, EncodePlayerDispellableMode(mode, false))
        end

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

        if CFG.enemyPlateBuffExcludePlayerDispellable == true then
            for index, mode in ipairs(modes) do
                modes[index] = EncodePlayerDispellableMode(mode, true)
            end
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

    if baseFilter == "HELPFUL" and CFG[keyPrefix .. "UsePlayerDispellable"] == true then
        local mode = AuraFilterMode(baseFilter, sourceToken, "DISPELLABLE|INCLUDE_NAME_PLATE_ONLY")
        for _, token in ipairs(exclusions) do
            if not ("|" .. mode .. "|"):find("|" .. token .. "|", 1, true) then
                mode = mode .. "|" .. token
            end
        end
        AddAuraMode(modes, EncodePlayerDispellableMode(mode, false))
    end
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

    if baseFilter == "HELPFUL" and CFG[keyPrefix .. "ExcludePlayerDispellable"] == true then
        for index, mode in ipairs(modes) do
            modes[index] = EncodePlayerDispellableMode(mode, true)
        end
    end
    return modes
end

local function GetAuraCollectionFilter(baseFilter, mode)
    mode = DecodePlayerDispellableMode(mode)
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

    local decodedMode, playerDispelDisposition = DecodePlayerDispellableMode(mode)
    mode = decodedMode
    if playerDispelDisposition then
        local canDispel = AuraCanActivePlayerDispel(aura)
        if playerDispelDisposition == "INCLUDE" and not canDispel then return false end
        if playerDispelDisposition == "EXCLUDE" and canDispel then return false end
    end

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

local function ManagedAuraInitializer(plate, category, itemWidth, itemHeight, cropSides, customFlat, desaturate, forceFlareCustom, lockFlareColor)
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
        ApplyAuraFlare(plate, category, button, forceFlareCustom, lockFlareColor)
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
        .. ":PD=" .. PlayerOffensiveDispelSignature()
end

local function DisableManagedAuraCategory(plate, category)
    local entry = plate.managedAuraContainers and plate.managedAuraContainers[category]
    if not entry then return end
    if entry.container then
        pcall(entry.container.SetEnabled, entry.container, false)
        pcall(entry.container.Hide, entry.container)
    end
end

local function BuildManagedAuraCategory(plate, unit, category, modes, signature, forceFlareCustom, lockFlareColor)
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

    local managedGroups = {}
    for _, mode in ipairs(modes) do
        for _, group in ipairs(ExpandManagedPlayerDispelMode(mode)) do
            managedGroups[#managedGroups + 1] = group
        end
    end
    if #managedGroups == 0 then
        -- The player currently has no matching offensive dispel capability.
        -- Keep a valid empty managed container rather than falling back to the
        -- unsafe manual renderer while aura data is restricted.
        if not pcall(container.SetUnit, container, unit) then
            pcall(container.SetEnabled, container, false)
            container:Hide()
            return nil
        end
        plate.managedAuraContainers = plate.managedAuraContainers or {}
        local entry = {
            container = container,
            unit = unit,
            signature = signature,
            unitGeneration = plate.unitGeneration,
            empty = true,
        }
        plate.managedAuraContainers[category] = entry
        return entry
    end

    local maxAuras = perRow * rows
    -- AuraContainer groups are independent. Divide the configured display
    -- budget across the effective checked categories so enabling several filters
    -- does not expand a five-icon row into five icons per category.
    local maxPerGroup = math.max(1, math.floor(maxAuras / math.max(1, #managedGroups)))
    local initializer = ManagedAuraInitializer(plate, category, itemWidth, itemHeight, cropSides, customFlat, desaturate, forceFlareCustom, lockFlareColor)
    for index, group in ipairs(managedGroups) do
        local added = pcall(container.AddAuraGroup, container, "BattleMender" .. category .. index, group.filter, {
            maxFrameCount = maxPerGroup,
            candidateFilters = group.candidateFilters or {},
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

                -- Each checked native aura category is a separate Blizzard
                -- AuraGroup internally, but Buffs/Debuffs are one visual list
                -- to the user. Do not add another gap or force a wrap at the
                -- boundary between categories (for example Big Defensive ->
                -- External Defensive, or two selected Debuff categories).
                groupSpacing = 0,
                groupLineSpacing = 0,
                forceNewLine = false,
                layoutIndex = index,
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
    local entry = {
        container = container,
        unit = unit,
        signature = signature,
        unitGeneration = plate.unitGeneration,
    }
    plate.managedAuraContainers[category] = entry
    return entry
end

local function GetManagedFlarePoolKey(plate, unit, category)
    local triggerCategory = CFG.enemyPlateAuraFlareTriggerCategory or "DANGER"
    if CFG.enemyPlateAuraFlareEnabled == false
        or (CFG.enemyPlateAuraFlareColorMode or "CUSTOM") ~= "CLASS"
        or category ~= triggerCategory
    then
        return nil, false
    end

    -- Player class colors are creation-time state for managed AuraButtons. Once
    -- the button enters the forbidden aura partition we cannot reliably repaint
    -- its child textures. Reuse a container only for the same safely-resolved
    -- class; otherwise select/build a different class-specific container.
    if UnitLooksLikePlayer(unit, plate and plate.nativeFrame) then
        local classKey = GetSafeEnemyClassPoolKey(unit)
        if classKey then
            return classKey, false
        end

        -- If Blizzard withholds the class key, use one stable custom-colored
        -- fallback container rather than risk showing the previous enemy class.
        return "CLASS:FALLBACK", true
    end

    -- NPCs have no class color. Keep one stable custom fallback in CLASS mode.
    return "NONPLAYER:FALLBACK", true
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
    local flarePoolKey, forceFlareCustom = GetManagedFlarePoolKey(plate, unit, category)

    plate.managedAuraContainers = plate.managedAuraContainers or {}
    plate.managedAuraContainerPools = plate.managedAuraContainerPools or {}

    local entry = plate.managedAuraContainers[category]

    if entry and (entry.signature ~= signature
        or (flarePoolKey and entry.flarePoolKey ~= flarePoolKey))
    then
        DisableManagedAuraCategory(plate, category)
        entry = nil
        plate.managedAuraContainers[category] = nil
    end

    -- Class-colored flare containers are pooled by class for this physical
    -- nameplate. AuraButtons can then be reused only for another unit of the
    -- same class, avoiding both stale colors and an unbounded rebuild-per-swap
    -- pattern when Blizzard recycles nameplate frames.
    if not entry and flarePoolKey then
        local pool = plate.managedAuraContainerPools[category]
        if not pool then
            pool = {}
            plate.managedAuraContainerPools[category] = pool
        end

        local pooled = pool[flarePoolKey]
        if pooled and pooled.signature == signature then
            entry = pooled
            plate.managedAuraContainers[category] = entry
        end
    end

    if not entry then
        local okBuild, built = pcall(
            BuildManagedAuraCategory,
            plate, unit, category, modes, signature,
            forceFlareCustom, flarePoolKey ~= nil
        )

        if okBuild then
            entry = built
        end

        if entry and flarePoolKey then
            entry.flarePoolKey = flarePoolKey
            local pool = plate.managedAuraContainerPools[category]
            pool[flarePoolKey] = entry
        end
    end

    if not entry then
        return false
    end

    -- Unit tokens themselves are recycled (for example nameplate3 can refer to
    -- a different enemy later). The lifecycle serial forces SetUnit/refresh even
    -- when the token string is unchanged. For a pooled class entry this is safe:
    -- the fixed flare tint already matches the new occupant's class.
    if entry.unit ~= unit or entry.unitGeneration ~= plate.unitGeneration then
        local set = pcall(entry.container.SetUnit, entry.container, unit)
        if set then
            entry.unit = unit
            entry.unitGeneration = plate.unitGeneration
        end
        if not set then return false end
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


-- Export private helpers used by later enemy-nameplate modules.
EPI.GetAuraByIndex = GetAuraByIndex
EPI.VisitAuras = VisitAuras
EPI.ShouldBlockPermanentAura = ShouldBlockPermanentAura
EPI.IsBlizzardAuraFilterMode = IsBlizzardAuraFilterMode
EPI.ResolveAuraMode = ResolveAuraMode
EPI.AddAuraMode = AddAuraMode
EPI.AddAuraModeWithExclusions = AddAuraModeWithExclusions
EPI.AddConfiguredExclusion = AddConfiguredExclusion
EPI.AuraFilterMode = AuraFilterMode
EPI.ResolveEnemyBuffExclusions = ResolveEnemyBuffExclusions
EPI.ResolveEnemyDebuffExclusions = ResolveEnemyDebuffExclusions
EPI.AddDefensiveAuraModes = AddDefensiveAuraModes
EPI.ResolveAuraModes = ResolveAuraModes
EPI.ResolveSelectableAuraExclusions = ResolveSelectableAuraExclusions
EPI.ResolveSelectableAuraModes = ResolveSelectableAuraModes
EPI.GetAuraCollectionFilter = GetAuraCollectionFilter
EPI.AuraAllowed = AuraAllowed
EPI.MarkAuraSeen = MarkAuraSeen
EPI.CollectAuraCategory = CollectAuraCategory
EPI.EnsureAuraButton = EnsureAuraButton
EPI.HideAuraCategory = HideAuraCategory
EPI.UpdateAuraCategory = UpdateAuraCategory
EPI.EnemyAuraContainerAvailable = EnemyAuraContainerAvailable
EPI.EnsureEnemyAuraContainerAPI = EnsureEnemyAuraContainerAPI
EPI.HideManualAuraButtons = HideManualAuraButtons
EPI.PositionManagedAuraContainer = PositionManagedAuraContainer
EPI.ManagedAuraInitializer = ManagedAuraInitializer
EPI.AuraFlareSignature = AuraFlareSignature
EPI.ManagedAuraSignature = ManagedAuraSignature
EPI.DisableManagedAuraCategory = DisableManagedAuraCategory
EPI.BuildManagedAuraCategory = BuildManagedAuraCategory
EPI.GetManagedFlarePoolKey = GetManagedFlarePoolKey
EPI.UpdateManagedAuraCategory = UpdateManagedAuraCategory
EPI.HideManagedEnemyAuras = HideManagedEnemyAuras
EPI.ShouldUseManagedEnemyAuras = ShouldUseManagedEnemyAuras
EPI.PrepareManagedEnemyAuras = PrepareManagedEnemyAuras
EPI.ShouldShowAuraCategory = ShouldShowAuraCategory
EPI.UpdateAuras = UpdateAuras

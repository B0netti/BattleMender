BattleMender = BattleMender or {}

-------------------------------------------------
-- Native Spec Engine
-------------------------------------------------

BattleMender.SpecCache = BattleMender.SpecCache or {}
local ClassSpecDict = {}
local CachePublicCityCombatSpec

-------------------------------------------------
-- Spec debug throttle
-------------------------------------------------

BattleMender.SpecDebug = BattleMender.SpecDebug or false
BattleMender.SpecDebugLast = BattleMender.SpecDebugLast or {}

local function SpecDebug(key, ...)
    if not BattleMender.SpecDebug then return end

    local now = GetTime()
    local last = BattleMender.SpecDebugLast[key] or 0

    if now - last < 10 then
        return
    end

    BattleMender.SpecDebugLast[key] = now
    print("|cff33ff99BattleMender Spec:|r", ...)
end

-------------------------------------------------
-- Safe helpers
-------------------------------------------------

local function BuildSpecDictionary()
    wipe(ClassSpecDict)

    for classID = 1, 13 do
        local _, classFile = GetClassInfo(classID)
        if classFile then
            local specs = {}
            ClassSpecDict[classFile] = specs

            for index = 1, 4 do
                local specID, name = GetSpecializationInfoForClassID(classID, index)
                if specID and name then
                    local lowerName = string.lower(name)
                    specs[lowerName] = specID
                end
            end
        end
    end
end

local SCAN_TOOLTIP = CreateFrame("GameTooltip", "BattleMenderScanTooltip", nil, "GameTooltipTemplate")
if SCAN_TOOLTIP and SCAN_TOOLTIP.SetAlpha then
    SCAN_TOOLTIP:SetAlpha(0)
end

local function IsUsablePublicSpecID(specID)
    if specID == nil then return false end
    if BattleMender.IsSecretValue and BattleMender.IsSecretValue(specID) then
        return false
    end

    -- GetInspectSpecialization returns 0 when no inspect result is available.
    -- Zero is truthy in Lua, so it must be rejected explicitly before it can
    -- produce an invalid "specs/0.tga" texture path.
    local ok, usable = pcall(function()
        return type(specID) == "number" and specID > 0
    end)
    return ok and usable == true
end

local function SafeCacheGet(unitToken)
    if not unitToken then return nil end

    local ok, value = pcall(function()
        return BattleMender.SpecCache[unitToken]
    end)

    if ok then
        return value
    end

    return nil
end

local function SafeCacheSet(unitToken, specID)
    if not unitToken or not IsUsablePublicSpecID(specID) then return end

    pcall(function()
        BattleMender.SpecCache[unitToken] = specID
    end)

    if CachePublicCityCombatSpec then
        CachePublicCityCombatSpec(unitToken, specID)
    end
end

local function SafeInspectSpec(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local ok, specID = pcall(GetInspectSpecialization, unit)

    if ok and IsUsablePublicSpecID(specID) then
        return specID
    end

    return nil
end

local function GetGroupInspectUnit(unit)
    return BattleMender.GetFriendlyUnitToken
        and BattleMender.GetFriendlyUnitToken(unit)
end

local function MatchTooltipSpecText(text, classSpecs)
    if not text or not classSpecs then return nil end
    if BattleMender.IsSecretValue and BattleMender.IsSecretValue(text) then
        return nil
    end

    local ok, specID = pcall(function()
        local lowerText = string.lower(text)
        for specName, id in pairs(classSpecs) do
            if string.find(lowerText, specName, 1, true) then
                return id
            end
        end
    end)
    return ok and specID or nil
end

local function SafeTooltipSpec(unit)
    if InCombatLockdown and InCombatLockdown() then return nil end
    if not SCAN_TOOLTIP or not BattleMender.GetFriendlyClassFile then return nil end

    local classFile = BattleMender.GetFriendlyClassFile(unit)
    local classSpecs = classFile and ClassSpecDict[classFile]
    if not classSpecs then return nil end

    -- The data API produces the full unit tooltip synchronously. In a public
    -- city this can include a specialization before inspect data is available;
    -- in a restricted context every read remains inside pcall and is rejected.
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, specID = pcall(function()
            local data = C_TooltipInfo.GetUnit(unit)
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(data)
            end

            for _, line in ipairs(data and data.lines or {}) do
                if TooltipUtil and TooltipUtil.SurfaceArgs then
                    TooltipUtil.SurfaceArgs(line)
                end

                local spec = MatchTooltipSpecText(line.leftText, classSpecs)
                    or MatchTooltipSpecText(line.rightText, classSpecs)
                if spec then
                    return spec
                end
            end
        end)
        if ok and specID then
            return specID
        end
    end

    SCAN_TOOLTIP:SetOwner(UIParent, "ANCHOR_NONE")
    SCAN_TOOLTIP:ClearLines()

    local assigned = pcall(SCAN_TOOLTIP.SetUnit, SCAN_TOOLTIP, unit)
    if not assigned then return nil end
    SCAN_TOOLTIP:Show()

    for index = 1, SCAN_TOOLTIP:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local line = _G["BattleMenderScanTooltipText" .. side .. index]
            local ok, text = line and pcall(line.GetText, line)
            local specID = ok and MatchTooltipSpecText(text, classSpecs)
            if specID then
                SCAN_TOOLTIP:Hide()
                return specID
            end
        end
    end

    SCAN_TOOLTIP:Hide()
    return nil
end

-- A public city plate can be recycled while the player is in combat. At that
-- point 12.1 can withhold both tooltip and inspect data, even for a player we
-- resolved moments earlier. Keep a combat-only cache keyed by a public full
-- name so the same player retains their known spec without carrying an old
-- nameplate token's icon to another player.
local COMBAT_CITY_SPEC_CACHE = {}

local function GetPublicCityIdentity(unit)
    if not unit or not UnitFullName then return nil end

    local ok, name, realm = pcall(UnitFullName, unit)
    if not ok
        or (BattleMender.IsSecretValue and BattleMender.IsSecretValue(name))
        or (BattleMender.IsSecretValue and BattleMender.IsSecretValue(realm))
    then
        return nil
    end

    if name == nil then return nil end

    local checked, valid = pcall(function()
        return type(name) == "string" and (realm == nil or type(realm) == "string")
    end)
    if not checked or not valid then return nil end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

CachePublicCityCombatSpec = function(unit, specID)
    if not IsUsablePublicSpecID(specID) or GetGroupInspectUnit(unit) then return end

    local identity = GetPublicCityIdentity(unit)
    if identity then
        COMBAT_CITY_SPEC_CACHE[identity] = specID
    end
end

local function GetPublicCityCombatSpec(unit)
    if not (InCombatLockdown and InCombatLockdown()) or GetGroupInspectUnit(unit) then
        return nil
    end

    local identity = GetPublicCityIdentity(unit)
    if not identity then return nil end

    local specID = COMBAT_CITY_SPEC_CACHE[identity]
    return IsUsablePublicSpecID(specID) and specID or nil
end

function BattleMender.ClearPublicCityCombatSpecs()
    wipe(COMBAT_CITY_SPEC_CACHE)
end

-- Public city nameplates do not have a group token, and
-- GetInspectSpecialization returns 0 until an inspect request completes. Keep
-- one deliberately slow request in flight so BattleMender never spams the
-- inspect service or touches the restricted PvP path.
local INSPECT_QUEUE = {}
local INSPECT_QUEUED_GENERATION = {}
local INSPECT_UNIT_GENERATION = {}
local INSPECT_FAILURE_COUNT = {}
local FAST_PROBE_GENERATION = {}
local ACTIVE_INSPECT
local LAST_INSPECT_REQUEST_TIME = 0
local INSPECT_REQUEST_INTERVAL = 1.5
local INSPECT_RESPONSE_TIMEOUT = 3
local INSPECT_RETRY_DELAY = 3
local INSPECT_COOLDOWN_RETRY_DELAY = 15
local INSPECT_MAX_RETRIES = 3
local ScheduleNextInspect
local QueuePublicInspect
local RetryPublicInspect

local function QueueFastPublicSpecProbe(unit)
    if not unit or not C_Timer or not C_Timer.After then return end

    local generation = INSPECT_UNIT_GENERATION[unit] or 0
    if FAST_PROBE_GENERATION[unit] == generation then return end
    FAST_PROBE_GENERATION[unit] = generation

    local delays = { 0, 0.05, 0.15, 0.35 }
    local attempt = 0
    local function probe()
        attempt = attempt + 1
        if FAST_PROBE_GENERATION[unit] ~= generation
            or INSPECT_UNIT_GENERATION[unit] ~= generation
            or not UnitExists(unit)
        then
            return
        end

        -- This is a local read only. It does not send another inspect request;
        -- it simply catches public data Blizzard may populate a frame after the
        -- nameplate was acquired.
        local specID = SafeInspectSpec(unit)
        if specID then
            FAST_PROBE_GENERATION[unit] = nil
            INSPECT_QUEUED_GENERATION[unit] = nil
            INSPECT_FAILURE_COUNT[unit] = nil
            SafeCacheSet(unit, specID)
            if BattleMender.RefreshUnit then
                BattleMender.RefreshUnit(unit)
            end
            return
        end

        local nextDelay = delays[attempt + 1]
        if nextDelay then
            C_Timer.After(nextDelay, probe)
        else
            FAST_PROBE_GENERATION[unit] = nil
        end
    end

    probe()
end

local function ScheduleInspectAfter(delay)
    if delay <= 0 then
        ScheduleNextInspect()
    else
        C_Timer.After(delay, ScheduleNextInspect)
    end
end

ScheduleNextInspect = function()
    if ACTIVE_INSPECT or #INSPECT_QUEUE == 0 then return end

    while #INSPECT_QUEUE > 0 do
        local request = table.remove(INSPECT_QUEUE, 1)
        if INSPECT_QUEUED_GENERATION[request.unit] == request.generation then
            INSPECT_QUEUED_GENERATION[request.unit] = nil

            if INSPECT_UNIT_GENERATION[request.unit] == request.generation
                and UnitExists(request.unit)
            then
                ACTIVE_INSPECT = request
                LAST_INSPECT_REQUEST_TIME = GetTime()
                local ok = pcall(NotifyInspect, request.unit)
                if not ok then
                    ACTIVE_INSPECT = nil
                    RetryPublicInspect(request)
                    ScheduleInspectAfter(INSPECT_REQUEST_INTERVAL)
                    return
                else
                    -- INSPECT_READY is authoritative. This timer only releases
                    -- a failed or throttled request so later plates can try.
                    C_Timer.After(INSPECT_RESPONSE_TIMEOUT, function()
                        if ACTIVE_INSPECT == request then
                            ACTIVE_INSPECT = nil
                            if ClearInspectPlayer then pcall(ClearInspectPlayer) end
                            RetryPublicInspect(request)
                            ScheduleNextInspect()
                        end
                    end)
                    return
                end
            end
        end
    end
end

QueuePublicInspect = function(unit)
    if not unit or not NotifyInspect or not C_Timer or not C_Timer.After then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not UnitExists(unit) or GetGroupInspectUnit(unit) then return end

    local generation = INSPECT_UNIT_GENERATION[unit] or 0
    if ACTIVE_INSPECT
        and ACTIVE_INSPECT.unit == unit
        and ACTIVE_INSPECT.generation == generation
    then
        return
    end
    if INSPECT_QUEUED_GENERATION[unit] == generation then return end

    INSPECT_QUEUED_GENERATION[unit] = generation
    INSPECT_QUEUE[#INSPECT_QUEUE + 1] = { unit = unit, generation = generation }
    QueueFastPublicSpecProbe(unit)
    ScheduleNextInspect()
end

RetryPublicInspect = function(request)
    if not request
        or INSPECT_UNIT_GENERATION[request.unit] ~= request.generation
        or not UnitExists(request.unit)
    then
        return
    end

    local failures = (INSPECT_FAILURE_COUNT[request.unit] or 0) + 1
    INSPECT_FAILURE_COUNT[request.unit] = failures

    -- The first few retries handle ordinary inspect latency.  A city client can
    -- also reject or delay inspect data for considerably longer (for example,
    -- while the player has only just appeared).  Do not leave that visible
    -- plate on the class fallback forever once the quick budget is spent; keep
    -- retrying at a deliberately slow rate until the plate is recycled.
    local delay = failures <= INSPECT_MAX_RETRIES
        and INSPECT_RETRY_DELAY
        or INSPECT_COOLDOWN_RETRY_DELAY

    C_Timer.After(delay, function()
        if INSPECT_UNIT_GENERATION[request.unit] == request.generation
            and not (InCombatLockdown and InCombatLockdown())
        then
            QueuePublicInspect(request.unit)
        end
    end)
end

function BattleMender.OnInspectReady()
    local request = ACTIVE_INSPECT
    if not request then return end
    ACTIVE_INSPECT = nil

    if INSPECT_UNIT_GENERATION[request.unit] == request.generation
        and UnitExists(request.unit)
    then
        local specID = SafeInspectSpec(request.unit)
        if specID then
            FAST_PROBE_GENERATION[request.unit] = nil
            INSPECT_FAILURE_COUNT[request.unit] = nil
            SafeCacheSet(request.unit, specID)
            if BattleMender.RefreshUnit then
                BattleMender.RefreshUnit(request.unit)
            end
        else
            RetryPublicInspect(request)
        end
    end

    if ClearInspectPlayer then pcall(ClearInspectPlayer) end

    -- Throttle from the start of the previous request, not from when its
    -- response arrived. Fast city responses therefore advance the queue much
    -- sooner while the request rate remains conservative.
    local elapsed = math.max(0, GetTime() - LAST_INSPECT_REQUEST_TIME)
    ScheduleInspectAfter(math.max(0, INSPECT_REQUEST_INTERVAL - elapsed))
end

function BattleMender.ForgetUnitSpec(unit)
    if not unit then return end

    INSPECT_UNIT_GENERATION[unit] = (INSPECT_UNIT_GENERATION[unit] or 0) + 1
    INSPECT_QUEUED_GENERATION[unit] = nil
    INSPECT_FAILURE_COUNT[unit] = nil
    FAST_PROBE_GENERATION[unit] = nil
    pcall(function()
        BattleMender.SpecCache[unit] = nil
    end)
end

function BattleMender.ClearSpecCache()
    wipe(BattleMender.SpecCache)
    wipe(COMBAT_CITY_SPEC_CACHE)
    wipe(INSPECT_QUEUE)
    wipe(INSPECT_QUEUED_GENERATION)
    wipe(INSPECT_UNIT_GENERATION)
    wipe(INSPECT_FAILURE_COUNT)
    wipe(FAST_PROBE_GENERATION)
    ACTIVE_INSPECT = nil
    if BattleMender.ClearFriendlyUnitTokenCache then
        BattleMender.ClearFriendlyUnitTokenCache()
    end
end

-- Re-enter city spec resolution for the currently visible plates.  This is
-- intentionally limited to non-group friendly players: group and PvP units
-- use their canonical party/raid token path and must never be inspected here.
-- `restartExhausted` is used after Friendly Plates is enabled again, so a
-- plate that previously reached its slow-retry phase gets a fresh quick try.
function BattleMender.ResumePublicSpecResolution(restartExhausted)
    if InCombatLockdown and InCombatLockdown() then return end
    if not BattleMender.CFG or BattleMender.CFG.enabled == false then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end

    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end

    for _, plate in ipairs(plates) do
        local frame = BattleMender.GetVisualFrame and BattleMender.GetVisualFrame(plate)
        local unit = frame and BattleMender.ResolvePlateUnit
            and BattleMender.ResolvePlateUnit(plate, frame)

        if unit
            and UnitExists(unit)
            and BattleMender.IsFriendlyPlayer(unit)
            and not GetGroupInspectUnit(unit)
            and not SafeCacheGet(unit)
        then
            if restartExhausted then
                INSPECT_FAILURE_COUNT[unit] = nil
            end

            -- Use the normal entry point so an immediately available direct
            -- or tooltip specialization is shown without waiting for inspect.
            local specID = BattleMender.GetUnitSpecID(unit)
            if specID and BattleMender.RefreshUnit then
                BattleMender.RefreshUnit(unit)
            end
        end
    end

    ScheduleNextInspect()
end

-------------------------------------------------
-- Public API
-------------------------------------------------

function BattleMender.GetUnitSpecID(unit)
    if not unit or not UnitExists(unit) then
        SpecDebug("no-unit", "No unit or unit does not exist.")
        return nil
    end

    -- 12.1 may mark values returned through nameplateN as secret. Prefer a
    -- canonical player/party/raid unit; only use the direct nameplate result
    -- when SafeInspectSpec has confirmed that it is public.
    local inspectUnit = GetGroupInspectUnit(unit)
    if not inspectUnit then
        local cached = SafeCacheGet(unit)
        if cached then
            return cached
        end

        -- Preserve a known city specialization over a combat-time plate
        -- recycle. The cache is keyed by a guarded public player identity, not
        -- by nameplateN, so an unrelated player cannot inherit the old icon.
        local combatSpecID = GetPublicCityCombatSpec(unit)
        if combatSpecID then
            SafeCacheSet(unit, combatSpecID)
            return combatSpecID
        end

        -- Open-world nameplates need an asynchronous inspect request before
        -- GetInspectSpecialization can return their public spec ID.
        local publicSpecID = SafeInspectSpec(unit)
        if publicSpecID then
            SafeCacheSet(unit, publicSpecID)
            return publicSpecID
        end

        local tooltipSpecID = SafeTooltipSpec(unit)
        if tooltipSpecID then
            SafeCacheSet(unit, tooltipSpecID)
            return tooltipSpecID
        end

        QueuePublicInspect(unit)
        return nil
    end

    local cached = SafeCacheGet(inspectUnit)
    if cached then
        SpecDebug("cache-" .. tostring(unit), "Cache hit:", unit)
        return cached
    end

    if inspectUnit == "player" then
        local currentSpec = GetSpecialization()
        if currentSpec then
            local id = GetSpecializationInfo(currentSpec)
            if IsUsablePublicSpecID(id) then
                SafeCacheSet(inspectUnit, id)
                return id
            end
        end
        return nil
    end

    local specID = SafeInspectSpec(inspectUnit)
    if specID then
        SafeCacheSet(inspectUnit, specID)
        return specID
    end

    SpecDebug("inspect-none-" .. tostring(inspectUnit), "No inspect spec for:", inspectUnit)
    return nil
end

BuildSpecDictionary()

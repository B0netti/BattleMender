BattleMender = BattleMender or {}
local BM = BattleMender
local CFG = BM.CFG or {}

-------------------------------------------------
-- Settings launcher only
--
-- The full BattleMender configuration now lives in the standalone Ace3 window
-- created by Settings.lua. The native Options > AddOns page remains only as a
-- lightweight entry point.
-------------------------------------------------

local function SaveAndRefresh()
    if BM.SaveRefresh then BM.SaveRefresh() end
    if BM.SetFriendlyClickbox then BM.SetFriendlyClickbox() end
end

function BM.OpenOptions(section)
    if BM.OpenStandaloneOptions then
        BM.OpenStandaloneOptions(section)
        return
    end

    print("|cff33ff99BattleMender:|r Ace3 options are not available. Make sure AceConfig-3.0, AceConfigDialog-3.0, and AceGUI-3.0 are loaded.")
end

-------------------------------------------------
-- AddOn Compartment + minimap launcher (LibDBIcon)
-------------------------------------------------
local MINIMAP_BUTTON_NAME = "BattleMender"
local MINIMAP_BUTTON_ICON = "Interface\\AddOns\\BattleMender\\Media\\Icon.tga"
local MINIMAP_BUTTON_DEFAULT_POS = 270

local function OpenPlateSection(button)
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end

    if button == "RightButton" then
        BM.OpenOptions("enemyPlates")
    else
        -- The Friendly Plates top-level AceConfig key is "normal".
        BM.OpenOptions("normal")
    end
end

local function AddLauncherTooltipLines(tooltip)
    if not tooltip then return end

    tooltip:AddLine("BattleMender", 0.53, 0.87, 0.00)
    tooltip:AddLine("Left-click: Friendly Plates", 1, 1, 1)
    tooltip:AddLine("Right-click: Enemy Plates", 1, 1, 1)
    tooltip:AddLine("Drag: Move minimap button", 0.72, 0.72, 0.72)
end

local function ResolveCompartmentButton(first, second)
    if second == "LeftButton" or second == "RightButton" then
        return second
    end
    if first == "LeftButton" or first == "RightButton" then
        return first
    end
    return "LeftButton"
end

function BattleMender_OnAddonCompartmentClick(addonName, buttonName)
    OpenPlateSection(ResolveCompartmentButton(addonName, buttonName))
end

function BattleMender_OnAddonCompartmentEnter(addonName, menuButtonFrame)
    local owner = menuButtonFrame
    if not owner or type(owner.GetObjectType) ~= "function" then
        owner = _G.AddonCompartmentFrame or UIParent
    end

    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    AddLauncherTooltipLines(GameTooltip)
    GameTooltip:Show()
end

function BattleMender_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

local function GetMinimapLibraries()
    local libStub = _G.LibStub
    if not libStub then return nil, nil end

    local LDB = libStub("LibDataBroker-1.1", true)
    local DBIcon = libStub("LibDBIcon-1.0", true)
    return LDB, DBIcon
end

function BM.GetMinimapButtonDB()
    BattleMenderDB = type(BattleMenderDB) == "table" and BattleMenderDB or {}

    local db = BattleMenderDB.minimap
    if type(db) ~= "table" then
        local profile = BM.DB and BM.DB.profile
        local legacyDB = BattleMenderDB.minimapButton
        if type(legacyDB) ~= "table" and profile then
            legacyDB = profile.minimapButton or profile.minimap
        end

        local oldShow = profile and profile.showMinimapButton
        local oldPos = profile and profile.minimapButtonAngle

        if oldShow == nil then oldShow = BattleMenderDB.showMinimapButton end
        if oldPos == nil then oldPos = BattleMenderDB.minimapButtonAngle end

        db = {
            hide = type(legacyDB) == "table" and legacyDB.hide == true or oldShow == false,
            minimapPos = type(legacyDB) == "table" and tonumber(legacyDB.minimapPos)
                or tonumber(oldPos)
                or MINIMAP_BUTTON_DEFAULT_POS,
        }
        BattleMenderDB.minimap = db
    end

    if db.hide == nil then db.hide = false end
    if tonumber(db.minimapPos) == nil then
        db.minimapPos = MINIMAP_BUTTON_DEFAULT_POS
    end

    -- Remove the temporary keys used by the overwritten custom launcher build.
    BattleMenderDB.showMinimapButton = nil
    BattleMenderDB.minimapButtonAngle = nil
    BattleMenderDB.minimapButton = nil
    local profile = BM.DB and BM.DB.profile
    if profile then
        profile.showMinimapButton = nil
        profile.minimapButtonAngle = nil
        profile.minimapButton = nil
        profile.minimap = nil
    end

    return db
end

function BM.InitializeMinimapButton()
    local LDB, DBIcon = GetMinimapLibraries()
    local db = BM.GetMinimapButtonDB()
    if not LDB or not DBIcon or not db then
        return false
    end

    local launcher = LDB:GetDataObjectByName(MINIMAP_BUTTON_NAME)
    if not launcher then
        launcher = LDB:NewDataObject(MINIMAP_BUTTON_NAME, {
            type = "launcher",
            text = "BattleMender",
            label = "BattleMender",
            icon = MINIMAP_BUTTON_ICON,
            OnClick = function(_, button)
                OpenPlateSection(button)
            end,
            OnTooltipShow = function(tooltip)
                AddLauncherTooltipLines(tooltip)
            end,
        })
    end

    if not launcher then
        return false
    end

    if DBIcon.IsRegistered and DBIcon:IsRegistered(MINIMAP_BUTTON_NAME) then
        if DBIcon.Refresh then
            DBIcon:Refresh(MINIMAP_BUTTON_NAME, db)
        end
    else
        local ok = pcall(DBIcon.Register, DBIcon, MINIMAP_BUTTON_NAME, launcher, db)
        if not ok then
            return false
        end
    end

    if db.hide then
        DBIcon:Hide(MINIMAP_BUTTON_NAME)
    else
        DBIcon:Show(MINIMAP_BUTTON_NAME)
    end

    BM.MinimapButtonInitialized = true
    return true
end

function BM.IsMinimapButtonShown()
    local db = BM.GetMinimapButtonDB()
    return db and db.hide ~= true
end

function BM.SetMinimapButtonShown(show)
    local db = BM.GetMinimapButtonDB()
    if not db then return end

    db.hide = not show

    local _, DBIcon = GetMinimapLibraries()
    if not BM.MinimapButtonInitialized then
        BM.InitializeMinimapButton()
    elseif DBIcon then
        if show then
            DBIcon:Show(MINIMAP_BUTTON_NAME)
        else
            DBIcon:Hide(MINIMAP_BUTTON_NAME)
        end
    end
end

function BM.ResetMinimapButtonPosition()
    local db = BM.GetMinimapButtonDB()
    if not db then return end

    db.minimapPos = MINIMAP_BUTTON_DEFAULT_POS
    local _, DBIcon = GetMinimapLibraries()
    if not BM.MinimapButtonInitialized then
        BM.InitializeMinimapButton()
    elseif DBIcon and DBIcon.Refresh then
        DBIcon:Refresh(MINIMAP_BUTTON_NAME, db)
    end
end

local function BuildLauncherPanel()
    local panel = CreateFrame("Frame", "BattleMenderSettingsLauncherPanel")
    panel.name = "BattleMender"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BattleMender")

    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    text:SetWidth(500)
    text:SetJustifyH("LEFT")
    text:SetText("BattleMender uses a standalone floating options window. Use the button below or type /bm.")

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    button:SetSize(220, 26)
    button:SetText("Open BattleMender Options")
    button:SetScript("OnClick", function()
        BM.OpenOptions()
    end)

    return panel
end

local function OpenNativeLauncherPanel()
    if Settings and Settings.OpenToCategory and BM.SettingsCategory then
        Settings.OpenToCategory(BM.SettingsCategory.ID or BM.SettingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and BM.SettingsPanel then
        InterfaceOptionsFrame_OpenToCategory(BM.SettingsPanel)
        InterfaceOptionsFrame_OpenToCategory(BM.SettingsPanel)
    else
        BM.OpenOptions()
    end
end

function BM.InitSettingsPanel()
    if BM.SettingsPanel then return end

    local panel = BuildLauncherPanel()
    BM.SettingsPanel = panel

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "BattleMender")
        Settings.RegisterAddOnCategory(category)
        BM.SettingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    SLASH_BATTLEMENDER1 = "/bm"
    SLASH_BATTLEMENDER2 = "/battlemender"
    SlashCmdList.BATTLEMENDER = function(msg)
        msg = string.lower(msg or "")

        if msg == "debug" then
            CFG.debug = not CFG.debug
            if BM.SaveDB then BM.SaveDB() end
            print("|cff33ff99BattleMender:|r debug", CFG.debug and "on" or "off")
            return
        elseif msg == "refresh" then
            SaveAndRefresh()
            print("|cff33ff99BattleMender:|r refreshed")
            return
        elseif msg == "options" or msg == "config" or msg == "" then
            BM.OpenOptions()
            return
        elseif msg == "blizzard" or msg == "native" then
            OpenNativeLauncherPanel()
            return
        elseif msg == "enemystatus" or msg == "enemydebug" then
            if BM.PrintEnemyNameplateProviderStatus then
                BM.PrintEnemyNameplateProviderStatus()
            else
                print("|cff33ff99BattleMender:|r enemy provider status is not available.")
            end
            return
        elseif msg == "stackingstatus" then
            if BM.PrintNameplateStackingStatus then
                BM.PrintNameplateStackingStatus()
            end
            return
        elseif msg == "stackingrepair" then
            if BM.RepairElvUIStackingOverride then
                BM.RepairElvUIStackingOverride()
            end
            return
        elseif msg == "teststatus" then
            if BM.PrintFriendlyTestModeStatus then
                BM.PrintFriendlyTestModeStatus()
            end
            return
        elseif msg == "ccstatus" then
            if BM.PrintNativeCrowdControlStatus then
                BM.PrintNativeCrowdControlStatus()
            else
                print("|cff33ff99BattleMender:|r native crowd-control diagnostics are not available.")
            end
            return
        elseif msg == "elvtargettextures" then
            if BM.PrintElvUITargetTextures then
                BM.PrintElvUITargetTextures()
            end
            return
        elseif msg == "mousestatus" then
            if BM.PrintFriendlyMouseStatus then
                BM.PrintFriendlyMouseStatus()
            end
            return
        elseif msg == "mousefix" then
            local resized = BM.SetFriendlyClickbox and BM.SetFriendlyClickbox()
            local interactive = BM.ApplyNameplateInteractibility and BM.ApplyNameplateInteractibility(true)
            if BM.RefreshAll then BM.RefreshAll() end
            print("|cff33ff99BattleMender:|r friendly mouse repair", (resized or interactive) and "applied." or "did not find a usable live API.")
            if BM.PrintFriendlyMouseStatus then BM.PrintFriendlyMouseStatus() end
            return
        elseif msg == "layoutrefresh" then
            if BM.ApplyNameplateLayoutUpdate then
                BM.ApplyNameplateLayoutUpdate()
                print("|cff33ff99BattleMender:|r nameplate layout refreshed.")
            end
            return
        end

        BM.OpenOptions()
    end
end

if BM.Frame then
    BM.Frame.InitSettingsPanel = BM.InitSettingsPanel
end

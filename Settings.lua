-- Settings.lua
-- Standalone Ace3 options for BattleMender.

BattleMender = BattleMender or {}
local BM = BattleMender
local CFG = BM.CFG or {}

local LibStub = _G.LibStub
local AceConfig
local AceConfigDialog
local AceGUI
local AceDBOptions

local function TryLoadAddon(name)
    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loader then
        pcall(loader, name)
    end
end

local function ResolveAce3()
    -- Do not cache a failed lookup forever. Some setups load Ace3 after this file.
    if not LibStub then
        TryLoadAddon("Ace3")
        LibStub = _G.LibStub
    end

    if not LibStub then
        return nil, nil, nil
    end

    AceConfig = AceConfig or LibStub("AceConfig-3.0", true)
    AceConfigDialog = AceConfigDialog or LibStub("AceConfigDialog-3.0", true)
    AceGUI = AceGUI or LibStub("AceGUI-3.0", true)
    AceDBOptions = AceDBOptions or LibStub("AceDBOptions-3.0", true)

    return AceConfig, AceConfigDialog, AceGUI, AceDBOptions
end

local APP_NAME = "BattleMender"
local OptionsRegistered = false
local OptionsFrame

-- Wide enough for the complete top-level tab hierarchy to remain on one row.
local OPTIONS_DEFAULT_WIDTH = 900
local OPTIONS_DEFAULT_HEIGHT = 620
local OPTIONS_MIN_WIDTH = 760
local OPTIONS_MIN_HEIGHT = 420
local OPTIONS_DEFAULT_PADDING = 0.06 -- 6% from top/left; always below 10%.

local ESCAPE_FRAME_NAME = "BattleMenderOptionsWindow"
local EscapeFrameRegistered = false

local BRAND_GREEN_HEX = "9cff00"
local BRAND_SILVER_HEX = "c4c9cc"
local BRAND_MUTED_HEX = "7e858a"

local function BrandSection(text)
    return "|cff" .. BRAND_GREEN_HEX .. text .. "|r"
end

local function BrandLabel(text)
    return "|cff" .. BRAND_SILVER_HEX .. text .. "|r"
end

local BLEND_MODES = {
    BLEND = "Normal",
    ADD = "Additive",
    MOD = "Multiply",
    DISABLE = "Raw",
}

local RING_TEXTURES = {
    Ring_10px = "Circle - Thin",
    Ring_20px = "Circle - Standard",
    Ring_30px = "Circle - Heavy",
    Ring_40px = "Circle - Extra Heavy",
    Metal_Ring = "Metal Ring",
    plastic_ring = "Plastic Ring",
    defensive_cogwheel = "Defensive Cogwheel",
    shield_easy = "Shield - Compact",
    shield_ring = "Shield - Ring",
    shield_tall = "Shield - Tall",
}

local LOS_RING_TEXTURES = {
    SAME = "Same as Normal",
    Ring_10px = "Circle - Thin",
    Ring_20px = "Circle - Standard",
    Ring_30px = "Circle - Heavy",
    Ring_40px = "Circle - Extra Heavy",
    Metal_Ring = "Metal Ring",
    plastic_ring = "Plastic Ring",
    defensive_cogwheel = "Defensive Cogwheel",
    shield_easy = "Shield - Compact",
    shield_ring = "Shield - Ring",
    shield_tall = "Shield - Tall",
}

local RING_TEXTURE_ORDER = {
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

local LOS_RING_TEXTURE_ORDER = {
    "SAME",
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

local ACCENT_OVERLAY_TEXTURES = {
    ["Metal_Ring"] = "Metal Ring",
    ["Glass_Ring"] = "Glass Ring",
}

local LOS_ACCENT_OVERLAY_TEXTURES = {
    ["SAME"] = "Same as Normal",
    ["Metal_Ring"] = "Metal Ring",
    ["Glass_Ring"] = "Glass Ring",
}

local PULSE_TEXTURES = {
    Circle_AlphaGradient_In = "Gradient In",
    Circle_AlphaGradient_Out = "Gradient Out",
    Circle_Smooth2 = "Smooth 2",
}

local DEFAULT_STATUSBAR_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local R21_STATUSBAR_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\r21"
local RIBBON_STATUSBAR_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\ribbon"
local CRIMP_STATUSBAR_TEXTURE = "Interface\\AddOns\\BattleMender\\Media\\Bars\\crimp"
local LSM_FLAT_NAME = "BattleMender Flat"
local LSM_R21_NAME = "BattleMender R21"
local LSM_RIBBON_NAME = "BattleMender Ribbon"
local LSM_CRIMP_NAME = "BattleMender Crimp"


local function GetSharedMedia()
    if not LibStub then
        LibStub = _G.LibStub
    end

    if not LibStub then
        return nil
    end

    local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok then
        return lib
    end

    return nil
end

local function RegisterBattleMenderStatusbars()
    local media = GetSharedMedia()
    if media and media.Register then
        pcall(media.Register, media, "statusbar", LSM_FLAT_NAME, DEFAULT_STATUSBAR_TEXTURE)
        pcall(media.Register, media, "statusbar", LSM_RIBBON_NAME, RIBBON_STATUSBAR_TEXTURE)
        pcall(media.Register, media, "statusbar", LSM_CRIMP_NAME, CRIMP_STATUSBAR_TEXTURE)
    end
    return media
end

local function BuildStatusbarTextureValues(allowSame)
    local values = {}

    if allowSame then
        values.SAME = "Same as Enemy"
    end

    values.FLAT = "Flat / White"
    values.CUSTOM = "Custom Path"

    local media = RegisterBattleMenderStatusbars()
    if media and media.HashTable then
        local ok, statusbars = pcall(media.HashTable, media, "statusbar")
        if ok and type(statusbars) == "table" then
            local names = {}
            for name in pairs(statusbars) do
                if type(name) == "string" and name ~= "" then
                    names[#names + 1] = name
                end
            end
            table.sort(names)
            for _, name in ipairs(names) do
                values["LSM:" .. name] = "Media: " .. name
            end
        end
    end

    return values
end

local function BuildLSMStatusbarValues(allowSame)
    local values = {}

    if allowSame then
        values.SAME = "Same as Enemy"
    end

    RegisterBattleMenderStatusbars()

    -- This is the table used by the common AceGUI/LibSharedMedia statusbar
    -- widget. Its values are texture paths, which lets the dropdown render the
    -- same preview strips users are used to in ElvUI/Details/etc.
    local lists = _G.AceGUIWidgetLSMlists
    if lists and type(lists.statusbar) == "table" then
        for name, texture in pairs(lists.statusbar) do
            if type(name) == "string" and name ~= "" then
                values[name] = texture or name
            end
        end
    else
        values[LSM_FLAT_NAME] = LSM_FLAT_NAME
        values[LSM_RIBBON_NAME] = LSM_RIBBON_NAME
        values[LSM_CRIMP_NAME] = LSM_CRIMP_NAME

        local media = GetSharedMedia()
        if media and media.HashTable then
            local ok, statusbars = pcall(media.HashTable, media, "statusbar")
            if ok and type(statusbars) == "table" then
                for name, texture in pairs(statusbars) do
                    if type(name) == "string" and name ~= "" then
                        values[name] = name
                    end
                end
            end
        end
    end

    if lists and type(lists.statusbar) == "table" then
        values[LSM_FLAT_NAME] = values[LSM_FLAT_NAME] or DEFAULT_STATUSBAR_TEXTURE
        values[LSM_RIBBON_NAME] = values[LSM_RIBBON_NAME] or RIBBON_STATUSBAR_TEXTURE
        values[LSM_CRIMP_NAME] = values[LSM_CRIMP_NAME] or CRIMP_STATUSBAR_TEXTURE
    else
        values[LSM_FLAT_NAME] = values[LSM_FLAT_NAME] or LSM_FLAT_NAME
        values[LSM_RIBBON_NAME] = values[LSM_RIBBON_NAME] or LSM_RIBBON_NAME
        values[LSM_CRIMP_NAME] = values[LSM_CRIMP_NAME] or LSM_CRIMP_NAME
    end

    return values
end

local ANCHOR_POINTS = {
    TOP = "Top",
    CENTER = "Center",
    BOTTOM = "Bottom",
}

local FRIENDLY_TEST_CLASSES = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    DEATHKNIGHT = "Death Knight",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    MONK = "Monk",
    DRUID = "Druid",
    DEMONHUNTER = "Demon Hunter",
    EVOKER = "Evoker",
}

local ENEMY_AURA_ATTACH_TO = {
    HEALTH = "Health",
    CAST = "Cast Bar",
    NAME = "Name",
    ROOT = "Plate Center",
}

local ENEMY_AURA_POINTS = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local ENEMY_GROWTH_X = {
    RIGHT = "Right",
    LEFT = "Left",
}

local ENEMY_GROWTH_Y = {
    UP = "Up",
    DOWN = "Down",
}

local ENEMY_AURA_ALIGN = {
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
}

local ENEMY_PORTRAIT_POSITIONS = {
    LEFT = "Left",
    RIGHT = "Right",
    TOP = "Top",
    BOTTOM = "Bottom",
}

local ENEMY_CAST_ICON_POSITIONS = {
    RIGHT = "Right",
    LEFT = "Left",
    TOP = "Top",
    BOTTOM = "Bottom",
}

local ENEMY_NAME_POSITIONS = {
    ABOVE = "Above Health",
    BELOW = "Below Health",
    LEFT = "Left of Health",
    RIGHT = "Right of Health",
    CENTER = "Inside Health",
}

local function SaveRefresh()
    if BM.SaveRefresh then BM.SaveRefresh() end
end

local function RefreshAuraFilterVisibility()
    if not LibStub then return end

    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry and registry.NotifyChange then
        pcall(registry.NotifyChange, registry, APP_NAME)
    end
end

local function EnemyColorOption(order, name, prefix, fallbackR, fallbackG, fallbackB, fallbackA, desc)
    return {
        order = order,
        type = "color",
        name = name,
        desc = desc,
        hasAlpha = true,
        get = function()
            return
                CFG[prefix .. "R"] or fallbackR or 1,
                CFG[prefix .. "G"] or fallbackG or 1,
                CFG[prefix .. "B"] or fallbackB or 1,
                CFG[prefix .. "A"] or fallbackA or 1
        end,
        set = function(_, r, g, b, a)
            CFG[prefix .. "R"] = r
            CFG[prefix .. "G"] = g
            CFG[prefix .. "B"] = b
            CFG[prefix .. "A"] = a
            SaveRefresh()
        end,
    }
end

local function EnemyTextureInput(order, name, key, fallback, desc)
    return {
        order = order,
        type = "input",
        width = "full",
        name = name,
        desc = desc,
        get = function()
            return CFG[key] or fallback or ""
        end,
        set = function(_, v)
            CFG[key] = tostring(v or "")
            SaveRefresh()
        end,
    }
end

local function TextureSelectionFromValue(value, allowSame)
    local v = tostring(value or "")
    if v == "" or v == "SAME" then
        return allowSame and "SAME" or "FLAT"
    end
    if v == "FLAT" or v == "WHITE" or v == "DEFAULT" or v == DEFAULT_STATUSBAR_TEXTURE then
        return "FLAT"
    end
    if v == "R21" or v == "r21" or v == R21_STATUSBAR_TEXTURE then
        return "R21"
    end
    if v == "CUSTOM" then
        return "CUSTOM"
    end
    if string.match(v, "^LSM:") then
        return v
    end
    return "CUSTOM"
end

local function StatusbarSelectionFromValue(value, allowSame)
    local v = tostring(value or "")
    if v == "" or v == "SAME" then
        return allowSame and "SAME" or LSM_FLAT_NAME
    end
    if v == "FLAT" or v == "WHITE" or v == "DEFAULT" or v == DEFAULT_STATUSBAR_TEXTURE then
        return LSM_FLAT_NAME
    end
    if v == "R21" or v == "r21" or v == R21_STATUSBAR_TEXTURE then
        return LSM_R21_NAME
    end
    if v == "RIBBON" or v == "ribbon" or v == RIBBON_STATUSBAR_TEXTURE then
        return LSM_RIBBON_NAME
    end
    if v == "CRIMP" or v == "crimp" or v == CRIMP_STATUSBAR_TEXTURE then
        return LSM_CRIMP_NAME
    end

    local name = string.match(v, "^LSM:(.+)$")
    if name and name ~= "" then
        return name
    end

    -- Raw custom paths cannot be previewed inside the LSM dropdown. Keep the
    -- selector stable instead of returning a value AceConfig cannot display.
    return LSM_FLAT_NAME
end

local function EnemyStatusbarSelect(order, name, key, allowSame, desc, disabled, fallbackKey)
    return {
        order = order,
        type = "select",
        dialogControl = "LSM30_Statusbar",
        name = name,
        desc = desc,
        values = function()
            return BuildLSMStatusbarValues(allowSame)
        end,
        disabled = disabled,
        get = function()
            local value = CFG[key]
            if fallbackKey and (value == nil or value == "" or value == "SAME") then
                value = CFG[fallbackKey]
            end
            return StatusbarSelectionFromValue(value, allowSame)
        end,
        set = function(_, v)
            if v == "SAME" and allowSame then
                CFG[key] = "SAME"
            elseif v == LSM_FLAT_NAME then
                CFG[key] = "FLAT"
            elseif v == LSM_R21_NAME then
                CFG[key] = "R21"
            elseif v == LSM_RIBBON_NAME then
                CFG[key] = "RIBBON"
            elseif v == LSM_CRIMP_NAME then
                CFG[key] = "CRIMP"
            elseif type(v) == "string" and v ~= "" then
                CFG[key] = "LSM:" .. v
            end
            SaveRefresh()
        end,
    }
end

local function EnemyTextureSelect(order, name, key, customKey, allowSame, desc)
    return {
        order = order,
        type = "select",
        name = name,
        desc = desc,
        values = function()
            return BuildStatusbarTextureValues(allowSame)
        end,
        get = function()
            return TextureSelectionFromValue(CFG[key], allowSame)
        end,
        set = function(_, v)
            if v == "SAME" and allowSame then
                CFG[key] = "SAME"
            elseif v == "FLAT" then
                CFG[key] = "FLAT"
            elseif v == "R21" then
                CFG[key] = "R21"
            elseif v == "CUSTOM" then
                CFG[key] = "CUSTOM"
                CFG[customKey] = CFG[customKey] or ""
            elseif type(v) == "string" and string.match(v, "^LSM:") then
                CFG[key] = v
            end
            SaveRefresh()
        end,
    }
end

local function EnemyTextureCustomInput(order, name, key, customKey, allowSame, desc)
    return {
        order = order,
        type = "input",
        width = "full",
        name = name,
        desc = desc,
        disabled = function()
            return TextureSelectionFromValue(CFG[key], allowSame) ~= "CUSTOM"
        end,
        get = function()
            return CFG[customKey] or ""
        end,
        set = function(_, v)
            CFG[key] = "CUSTOM"
            CFG[customKey] = tostring(v or "")
            SaveRefresh()
        end,
    }
end

local function EnemyAuraToggle(order, key, name, defaultValue, desc)
    return {
        order = order,
        type = "toggle",
        name = name,
        desc = desc,
        width = "normal",
        get = function()
            local value = CFG[key]
            if value == nil then
                return defaultValue == true
            end
            return value == true
        end,
        set = function(_, v)
            CFG[key] = v and true or false
            SaveRefresh()
        end,
    }
end

local function EnemyAuraCategoryToggle(order, prefix, suffix, name, defaultValue, desc)
    return EnemyAuraToggle(order, prefix .. suffix, name, defaultValue, desc)
end

local function EnemyAuraRange(order, prefix, suffix, name, min, max, step, fallback, desc)
    return {
        order = order,
        type = "range",
        name = name,
        desc = desc,
        min = min,
        max = max,
        step = step,
        get = function()
            local value = CFG[prefix .. suffix]
            if value == nil then
                value = fallback
            end
            return value
        end,
        set = function(_, v)
            CFG[prefix .. suffix] = v
            SaveRefresh()
        end,
    }
end

local function EnemyAuraSelect(order, prefix, suffix, name, values, fallback, desc)
    return {
        order = order,
        type = "select",
        name = name,
        desc = desc,
        values = values,
        get = function()
            return CFG[prefix .. suffix] or fallback
        end,
        set = function(_, v)
            CFG[prefix .. suffix] = v
            SaveRefresh()
        end,
    }
end

local function EnemyAuraLayoutArgs(prefix, defaults)
    defaults = defaults or {}
    return {
        style = {
            order = 10,
            type = "group",
            name = "Style",
            guiInline = true,
            args = {
                desaturate = EnemyAuraCategoryToggle(1, prefix, "Desaturate", "Desaturate Icon", defaults.desaturate == true),
                keepRatio = EnemyAuraCategoryToggle(2, prefix, "KeepSizeRatio", "Keep Size Ratio", defaults.keepRatio ~= false),
                cooldownSwipe = EnemyAuraCategoryToggle(3, prefix, "CooldownSwipe", "Cooldown Swipe", defaults.cooldownSwipe ~= false, "Show Blizzard's radial aura-duration swipe over these icons. Works with square and cropped 3:4 icons."),
                cropSides = (prefix == "enemyPlateBuffAura" or prefix == "enemyPlateDebuffAura") and EnemyAuraCategoryToggle(
                    4,
                    prefix,
                    "CropSides",
                    "Crop Sides (3:4 Tall)",
                    defaults.cropSides == true,
                    "Keep the configured aura Size as the height, use 75% of that size for the width, and center-crop the spell texture instead of squashing it."
                ) or nil,
            },
        },
        layout = {
            order = 20,
            type = "group",
            name = "Layout",
            guiInline = true,
            args = {
                size = EnemyAuraRange(1, prefix, "Size", "Size", 8, 60, 1, defaults.size or 30, "The base icon size. Custom Flat keeps this as the icon width and uses a shorter height."),
                perRow = EnemyAuraRange(2, prefix, "PerRow", "Per Row", 1, 12, 1, defaults.perRow or 5, "Maximum icons before the next row begins. This also sets the width of the aura anchor."),
                rows = EnemyAuraRange(3, prefix, "Rows", "Rows", 1, 4, 1, defaults.rows or 1, "Maximum number of rows. This sets the height of the aura anchor."),
                spacing = EnemyAuraRange(4, prefix, "Spacing", "Spacing", 0, 12, 1, defaults.spacing or 1, "Empty space between neighboring icons."),
                align = EnemyAuraSelect(5, prefix, "Align", "Alignment", ENEMY_AURA_ALIGN, defaults.align or "LEFT", "Places a shorter manual row at the left, centre, or right of its configured aura area."),
                x = EnemyAuraRange(6, prefix, "XOffset", "X Offset", -100, 100, 1, defaults.x or -2, "Fine horizontal adjustment after the two anchor points are connected. Positive moves right."),
                y = EnemyAuraRange(7, prefix, "YOffset", "Y Offset", -100, 100, 1, defaults.y or 4, "Fine vertical adjustment after the two anchor points are connected. Positive moves up."),
                attachTo = EnemyAuraSelect(8, prefix, "AttachTo", "Attach To", ENEMY_AURA_ATTACH_TO, defaults.attachTo or "HEALTH", "The nameplate element to attach to. Health is the usual choice for an aura row above the health bar."),
                anchorPoint = EnemyAuraSelect(9, prefix, "AnchorPoint", "Anchor Point", ENEMY_AURA_POINTS, defaults.anchorPoint or "BOTTOMLEFT", "The corner or edge of the aura area that will be connected to Attach Point."),
                attachPoint = EnemyAuraSelect(10, prefix, "AttachPoint", "Attach Point", ENEMY_AURA_POINTS, defaults.attachPoint or "TOPLEFT", "The corner or edge on Attach To that receives the aura area's Anchor Point. For a row above Health, use Top Left or Top Right."),
                growX = EnemyAuraSelect(11, prefix, "GrowthX", "Growth X", ENEMY_GROWTH_X, defaults.growX or "RIGHT", "Manual rows extend in this direction. In combat it selects which horizontal side of the configured aura area anchors the managed row."),
                growY = EnemyAuraSelect(12, prefix, "GrowthY", "Growth Y", ENEMY_GROWTH_Y, defaults.growY or "UP", "Manual rows extend in this direction. In combat it selects whether the managed row anchors at the top or bottom of the configured aura area."),
                reset = {
                    order = 20,
                    type = "execute",
                    name = "Restore This Layout",
                    desc = "Restores this aura group's built-in size, grid, anchor, growth, and offset settings without changing its filters or style.",
                    func = function()
                        CFG[prefix .. "Size"] = defaults.size or 30
                        CFG[prefix .. "PerRow"] = defaults.perRow or 5
                        CFG[prefix .. "Rows"] = defaults.rows or 1
                        CFG[prefix .. "Spacing"] = defaults.spacing or 1
                        CFG[prefix .. "Align"] = defaults.align or "LEFT"
                        CFG[prefix .. "XOffset"] = defaults.x or -2
                        CFG[prefix .. "YOffset"] = defaults.y or 4
                        CFG[prefix .. "AttachTo"] = defaults.attachTo or "HEALTH"
                        CFG[prefix .. "AnchorPoint"] = defaults.anchorPoint or "BOTTOMLEFT"
                        CFG[prefix .. "AttachPoint"] = defaults.attachPoint or "TOPLEFT"
                        CFG[prefix .. "GrowthX"] = defaults.growX or "RIGHT"
                        CFG[prefix .. "GrowthY"] = defaults.growY or "UP"
                        SaveRefresh()
                    end,
                },
            },
        },
    }
end

local function SaveRefreshClickbox()
    if BM.SetFriendlyClickbox then BM.SetFriendlyClickbox() end
    SaveRefresh()
    if BM.ShowTemporaryClickboxPreview then BM.ShowTemporaryClickboxPreview(1.75) end
end

local function GetCVarText(name, fallback)
    local pending = BM.PendingNameplateCVars and BM.PendingNameplateCVars[name]
    if pending ~= nil then
        return tostring(pending)
    end

    local value = GetCVar and GetCVar(name)
    if value == nil then
        return fallback
    end
    return value
end

local function GetCVarNumber(name, fallback)
    local value = tonumber(GetCVarText(name))
    return value or fallback
end

local function SetCVarValue(name, value)
    if BM.SetNameplateCVar then
        BM.SetNameplateCVar(name, value)
    elseif SetCVar then
        pcall(SetCVar, name, tostring(value))
    end
end

local function SetNameplateLayoutCVar(name, value)
    SetCVarValue(name, value)
    if BM.ScheduleNameplateLayoutUpdate then
        BM.ScheduleNameplateLayoutUpdate()
    end
end

local function SaveRefreshInstanceBehavior()
    if BM.UpdateInstanceStatus then BM.UpdateInstanceStatus() end
    SaveRefresh()
end

local function GetBattleMenderPlateStatusLines()
    local addonEnabled = CFG.enabled ~= false
    local friendlyText
    local enemyText

    if not addonEnabled then
        friendlyText = "|cff7e858aDisabled|r"
        enemyText = "|cff7e858aDisabled|r"
    else
        if BM.IsSleeping then
            friendlyText = "|cffffcc00Enabled (currently suspended by instance settings)|r"
        else
            friendlyText = "|cff33ff99Enabled|r"
        end

        if CFG.enemyPlatesEnabled == false then
            enemyText = "|cff7e858aDisabled|r"
        else
            local active = BM.ShouldUseCustomEnemyPlates and BM.ShouldUseCustomEnemyPlates()
            if active == false then
                enemyText = "|cffffcc00Enabled (currently yielding to another nameplate addon)|r"
            else
                enemyText = "|cff33ff99Enabled|r"
            end
        end
    end

    return {
        "|cff9cff00BattleMender plates|r",
        "Friendly Plates: " .. friendlyText,
        "Enemy Plates: " .. enemyText,
    }
end

local function GetElvUIStatusText()
    local lines = GetBattleMenderPlateStatusLines()
    lines[#lines + 1] = ""

    if not _G.ElvUI then
        lines[#lines + 1] = "|cffaaaaaaElvUI: not detected|r"
        lines[#lines + 1] = "|cff33ff99Compatible: BattleMender is using Blizzard's native nameplate driver, restoring mouse interaction, and applying its own clickbox size.|r"
        return table.concat(lines, "\n")
    end

    local ok, E = pcall(function()
        return unpack(_G.ElvUI)
    end)

    if not ok or not E then
        lines[#lines + 1] = "|cffffcc00ElvUI: detected, but its nameplate settings could not be inspected.|r"
        return table.concat(lines, "\n")
    end

    local np = E.db and E.db.nameplates
    local private = E.private and E.private.nameplates
    if not np then
        lines[#lines + 1] = "|cffffcc00ElvUI: detected|r"
        lines[#lines + 1] = "NamePlates settings are not currently available."
        return table.concat(lines, "\n")
    end

    local moduleEnabled = true
    if private and private.enable ~= nil then
        moduleEnabled = private.enable ~= false
    elseif np.enable ~= nil then
        moduleEnabled = np.enable ~= false
    end

    local function UnitStatus(unitKey)
        local unitDB = np.units and np.units[unitKey]
        if not unitDB then
            return "|cff7e858aUnknown|r", false
        end

        local enabled = unitDB.enable ~= false
        if enabled and unitDB.nameOnly == true then
            return "|cffffcc00Enabled (name only)|r", true
        end
        if enabled then
            return "|cff33ff99Enabled|r", true
        end
        return "|cff7e858aDisabled|r", false
    end

    lines[#lines + 1] = "|cff33ff99ElvUI detected|r"

    if not moduleEnabled then
        lines[#lines + 1] = "ElvUI NamePlates module: |cff7e858aDisabled|r"
        lines[#lines + 1] = "|cff33ff99Compatible: BattleMender is using Blizzard's native nameplate driver, restoring mouse interaction, and applying its own clickbox size.|r"

        local orphaned = BM.HasElvUIOrphanNameplateUnitToggles and BM.HasElvUIOrphanNameplateUnitToggles()
        if orphaned then
            if CFG.repairElvUIDisabledNameplates ~= false then
                lines[#lines + 1] = "Stored ElvUI unit and click-through state will be cleared automatically."
            else
                lines[#lines + 1] = "Stored ElvUI unit-nameplate state is still present. Enable the repair below or run it once to clear that stale state."
            end
        end

        return table.concat(lines, "\n")
    end

    local friendlyText, friendlyEnabled = UnitStatus("FRIENDLY_PLAYER")
    local enemyPlayerText, enemyPlayerEnabled = UnitStatus("ENEMY_PLAYER")
    local enemyNPCText, enemyNPCEnabled = UnitStatus("ENEMY_NPC")

    lines[#lines + 1] = "ElvUI NamePlates module: |cff33ff99Enabled|r"
    lines[#lines + 1] = "ElvUI Friendly Players: " .. friendlyText
    lines[#lines + 1] = "ElvUI Enemy Players: " .. enemyPlayerText
    lines[#lines + 1] = "ElvUI Enemy NPCs: " .. enemyNPCText

    if friendlyEnabled then
        lines[#lines + 1] = "|cffffcc00Disable ElvUI Friendly Player plates when using BattleMender friendly plates.|r"
    end

    if enemyPlayerEnabled or enemyNPCEnabled then
        lines[#lines + 1] = "|cffffcc00Disable the corresponding ElvUI enemy categories to use BattleMender enemy plates.|r"
    end

    if not friendlyEnabled and not enemyPlayerEnabled and not enemyNPCEnabled then
        lines[#lines + 1] = "|cff33ff99Compatible configuration active: ElvUI remains enabled while BattleMender owns the disabled unit categories.|r"
    elseif not friendlyEnabled then
        lines[#lines + 1] = "Friendly-player configuration is compatible with BattleMender."
    end

    return table.concat(lines, "\n")
end

local function ElvUINameplates()
    if not _G.ElvUI then return nil end

    local ok, E = pcall(function()
        return unpack(_G.ElvUI)
    end)

    if not ok or not E or not E.db or not E.db.nameplates then
        return nil
    end

    local moduleOK, NP = pcall(function()
        return E.GetModule and E:GetModule("NamePlates", true)
    end)

    if not moduleOK then
        NP = nil
    end

    return E, E.db.nameplates, NP
end

local function GetElvUIClickthrough(kind)
    local _, np = ElvUINameplates()
    return np and np.clickThrough and np.clickThrough[kind] == true
end

local function SetElvUIClickthrough(kind, value)
    local _, np = ElvUINameplates()
    if not np then return end

    np.clickThrough = np.clickThrough or {}
    np.clickThrough[kind] = value and true or false

    -- Do not call ElvUI NamePlates:ConfigureAll or SetNamePlateClickThrough from
    -- BattleMender options. Those paths can enter Blizzard native nameplate update
    -- code while execution is addon-tainted. The DB value is still saved; ElvUI or
    -- a reload can apply it later.
end


local function GetElvUIEnvironmentKey()
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        return instanceType
    end
    if IsResting and IsResting() then
        return "resting"
    end
    return "world"
end

local function GetNameplateStacking()
    local pending = BM.PendingNameplateCVars and BM.PendingNameplateCVars.nameplateMotion
    if pending ~= nil then
        return tonumber(pending) == 1
    end

    local _, np = ElvUINameplates()
    if np then
        local env = np.enviromentConditions
        local values = env and env.stackingNameplates
        local environmentValue = values and values[GetElvUIEnvironmentKey()]

        if env and env.stackingEnabled and environmentValue ~= nil then
            return environmentValue == true
        end

        if np.motionType ~= nil then
            return np.motionType == "STACKED"
        end
    end

    return tostring(GetCVarText("nameplateMotion", "0")) == "1"
end

local function ElvUINameplatesActive()
    local E, np = ElvUINameplates()
    if not E or not np then
        return false, nil
    end

    local private = E.private and E.private.nameplates
    if private and private.enable == false then
        return false, np
    end
    if np.enable == false then
        return false, np
    end

    return true, np
end

local function GetNameplateOverlap(axis)
    local active, np = ElvUINameplatesActive()
    local dbKey = axis == "H" and "overlapH" or "overlapV"
    local cvar = axis == "H" and "nameplateOverlapH" or "nameplateOverlapV"

    if active and np then
        local value = tonumber(np[dbKey])
        if value ~= nil then
            return value
        end
    end

    return GetCVarNumber(cvar, 1)
end

local function SetNameplateOverlap(axis, value)
    local active, np = ElvUINameplatesActive()
    local dbKey = axis == "H" and "overlapH" or "overlapV"
    local cvar = axis == "H" and "nameplateOverlapH" or "nameplateOverlapV"

    -- When ElvUI NamePlates is active it owns these CVars and can reapply its
    -- DB values at any time. A user changing the BattleMender slider is an
    -- explicit request, so mirror the value into ElvUI's DB without calling
    -- ElvUI's ConfigureAll/SetCVars paths (those can enter taint-prone native
    -- nameplate updates).
    if active and np then
        np[dbKey] = value
    end

    SetCVarValue(cvar, value)
    if BM.ScheduleNameplateLayoutUpdate then
        BM.ScheduleNameplateLayoutUpdate()
    end
end

local function SetNameplateStacking(value)
    value = value and true or false

    if BM.SetNameplateStacking then
        BM.SetNameplateStacking(value)
        return
    end

    local _, np, NP = ElvUINameplates()
    if np then
        -- ElvUI reapplies nameplateMotion from its own DB. Update both the
        -- normal setting and the active environment override so the checkbox
        -- cannot be immediately undone by ElvUI.
        np.motionType = value and "STACKED" or "OVERLAP"

        local env = np.enviromentConditions or np.environmentConditions
        if env then
            env.stackingEnabled = true
            env.enable = true
            env.stackingNameplates = env.stackingNameplates or {}
            env.stackingNameplates[GetElvUIEnvironmentKey()] = value
            env.stackingNameplates.world = value
            env.stackingNameplates.party = value
            env.stackingNameplates.raid = value
            env.stackingNameplates.arena = value
            env.stackingNameplates.pvp = value
            env.stackingNameplates.resting = value
        end

        if NP and NP.EnviromentConditionals then
            pcall(NP.EnviromentConditionals, NP)
        elseif NP and NP.SetCVars then
            pcall(NP.SetCVars, NP)
        end
    end

    -- Apply last so BattleMender remains authoritative for the current state.
    SetCVarValue("nameplateMotion", value and 1 or 0)

    if BM.ScheduleNameplateLayoutUpdate then
        BM.ScheduleNameplateLayoutUpdate()
    end
end

local function DisabledUnlessDeveloper()
    return CFG.developerMode ~= true
end

local function MakeOptions()
    local options = {
        type = "group",
        name = "BattleMender",
        childGroups = "tab",
        args = {
            general = {
                order = 1,
                type = "group",
                name = "General",
                args = {
                    branding = {
                        order = 0,
                        type = "description",
                        name = "|cffc4c9ccBATTLE|r|cff9cff00MENDER|r  |cff7e858aSPEC PLATES|r",
                        fontSize = "large",
                    },
                    status = {
                        order = 1,
                        type = "description",
                        name = GetElvUIStatusText,
                        fontSize = "medium",
                    },
                    enabled = {
                        order = 10,
                        type = "toggle",
                        name = "Enable BattleMender",
                        get = function() return CFG.enabled end,
                        set = function(_, v)
                            local wasEnabled = CFG.enabled ~= false
                            CFG.enabled = v and true or false
                            SaveRefresh()

                            -- RefreshAll restores the visible friendly
                            -- plates.  Resume their city-only spec work after
                            -- that pass so disabled plates cannot remain on a
                            -- stale inspect retry state when re-enabled.
                            if CFG.enabled and not wasEnabled
                                and BM.ResumePublicSpecResolution
                            then
                                BM.ResumePublicSpecResolution(true)
                            end
                        end,
                    },
                    developerMode = {
                        order = 11,
                        type = "toggle",
                        name = "Developer Mode",
                        desc = "Unlocks the Normal, LoS, and Effects advanced tabs.",
                        get = function() return CFG.developerMode == true end,
                        set = function(_, v) CFG.developerMode = v and true or false; SaveRefresh() end,
                    },
                    layoutGroup = {
                        order = 20,
                        type = "group",
                        name = BrandSection("Sizing & Positioning"),
                        guiInline = true,
                        args = {
                            iconSize = { order = 1, type = "range", name = "Icon Size", min = 20, max = 100, step = 1, get = function() return CFG.iconSize or 45 end, set = function(_, v) CFG.iconSize = v; SaveRefreshClickbox() end },
                            clickSize = { order = 2, type = "range", name = "Clickbox Size", min = 30, max = 150, step = 1, get = function() return CFG.clickSize or 55 end, set = function(_, v) CFG.clickSize = v; SaveRefreshClickbox() end },
                            friendlyVisualScaleLock = {
                                order = 3,
                                type = "toggle",
                                name = "Lock Visual Scale",
                                desc = "Keeps BattleMender friendly spec plate visuals at the configured Icon Size even when Blizzard scales native nameplates by distance, target state, or stacking layout. This does not resize the secure clickbox.",
                                get = function() return CFG.friendlyVisualScaleLock ~= false end,
                                set = function(_, v) CFG.friendlyVisualScaleLock = v and true or false; SaveRefresh() end,
                            },
                            anchorPoint = { order = 4, type = "select", name = "Anchor Point", values = ANCHOR_POINTS, get = function() return CFG.anchorPoint or "CENTER" end, set = function(_, v) CFG.anchorPoint = v; SaveRefresh() end },
                            anchorX = { order = 5, type = "range", name = "X Offset", min = -100, max = 100, step = 1, get = function() return CFG.anchorX or 0 end, set = function(_, v) CFG.anchorX = v; SaveRefresh() end },
                            anchorY = { order = 6, type = "range", name = "Y Offset", min = -100, max = 100, step = 1, get = function() return CFG.anchorY or 0 end, set = function(_, v) CFG.anchorY = v; SaveRefresh() end },
                        },
                    },
                    blizzardCVars = {
                        order = 30,
                        type = "group",
                        name = BrandSection("Blizzard CVars"),
                        guiInline = true,
                        args = {
                            stacking = {
                                order = 10,
                                type = "group",
                                name = BrandLabel("Nameplate Stacking"),
                                guiInline = true,
                                args = {
                                    nameplateMotion = { order = 1, type = "toggle", name = "Stack Nameplates", desc = "Switches Blizzard nameplates between stacking and overlapping. When ElvUI environment-specific stacking is enabled, this updates the current environment as well.", get = GetNameplateStacking, set = function(_, v) SetNameplateStacking(v) end },
                                    nameplateOverlapV = { order = 2, type = "range", name = "Vertical Overlap", desc = "Controls stacked-nameplate vertical spacing. When ElvUI NamePlates is active, BattleMender also updates ElvUI's overlap setting so ElvUI does not immediately restore its previous value.", min = 0.1, max = 1.5, step = 0.05, get = function() return GetNameplateOverlap("V") end, set = function(_, v) SetNameplateOverlap("V", v) end },
                                    nameplateOverlapH = { order = 3, type = "range", name = "Horizontal Overlap", desc = "Controls stacked-nameplate horizontal spacing. When ElvUI NamePlates is active, BattleMender also updates ElvUI's overlap setting so ElvUI does not immediately restore its previous value.", min = 0.1, max = 1.5, step = 0.05, get = function() return GetNameplateOverlap("H") end, set = function(_, v) SetNameplateOverlap("H", v) end },
                                    elvUIOverlapNote = { order = 4, type = "description", width = "full", name = function() local active = ElvUINameplatesActive(); return active and "|cffc4c9ccElvUI NamePlates is active: overlap sliders are mirrored to ElvUI so both addons use the same spacing values.|r" or "" end },
                                },
                            },
                            scaling = {
                                order = 20,
                                type = "group",
                                name = BrandLabel("Scaling"),
                                guiInline = true,
                                args = {
                                    nameplateMinScale = { order = 1, type = "range", name = "Min Scale", min = 0.1, max = 2, step = 0.05, get = function() return GetCVarNumber("nameplateMinScale", 1) end, set = function(_, v) SetNameplateLayoutCVar("nameplateMinScale", v) end },
                                    nameplateMaxScale = { order = 2, type = "range", name = "Max Scale", min = 0.1, max = 2, step = 0.05, get = function() return GetCVarNumber("nameplateMaxScale", 1) end, set = function(_, v) SetNameplateLayoutCVar("nameplateMaxScale", v) end },
                                    nameplateSelectedScale = { order = 3, type = "range", name = "Selected Scale", min = 0.1, max = 2, step = 0.05, get = function() return GetCVarNumber("nameplateSelectedScale", 1) end, set = function(_, v) SetNameplateLayoutCVar("nameplateSelectedScale", v) end },
                                },
                            },
                            alpha = {
                                order = 30,
                                type = "group",
                                name = BrandLabel("Alpha"),
                                guiInline = true,
                                args = {
                                    nameplateMinAlpha = { order = 1, type = "range", name = "Min Alpha", min = 0, max = 1, step = 0.05, get = function() return GetCVarNumber("nameplateMinAlpha", 1) end, set = function(_, v) SetCVarValue("nameplateMinAlpha", v) end },
                                    nameplateMaxAlpha = { order = 2, type = "range", name = "Max Alpha", min = 0, max = 1, step = 0.05, get = function() return GetCVarNumber("nameplateMaxAlpha", 1) end, set = function(_, v) SetCVarValue("nameplateMaxAlpha", v) end },
                                    nameplateSelectedAlpha = { order = 3, type = "range", name = "Selected Alpha", min = 0, max = 1, step = 0.05, get = function() return GetCVarNumber("nameplateSelectedAlpha", 1) end, set = function(_, v) SetCVarValue("nameplateSelectedAlpha", v) end },
                                },
                            },
                            clickthrough = {
                                order = 40,
                                type = "group",
                                name = BrandLabel("Clickthrough (ElvUI)"),
                                guiInline = true,
                                args = {
                                    info = { order = 1, type = "description", width = "full", name = "Clickthrough is not a Blizzard CVar. These controls update ElvUI's nameplate driver when ElvUI is loaded." },
                                    clickThroughFriendly = { order = 2, type = "toggle", name = "Friendly Clickthrough", get = function() return GetElvUIClickthrough("friendly") end, set = function(_, v) SetElvUIClickthrough("friendly", v) end, hidden = function() return not _G.ElvUI end },
                                    clickThroughEnemy = { order = 3, type = "toggle", name = "Enemy Clickthrough", get = function() return GetElvUIClickthrough("enemy") end, set = function(_, v) SetElvUIClickthrough("enemy", v) end, hidden = function() return not _G.ElvUI end },
                                },
                            },
                        },
                    },
                    quickEffects = {
                        order = 40,
                        type = "group",
                        name = BrandSection("Quick Effects"),
                        guiInline = true,
                        args = {
                            specGlowEnabled = { order = 1, type = "toggle", name = "Spec Icon Glow", get = function() return CFG.specGlowEnabled == true end, set = function(_, v) CFG.specGlowEnabled = v; SaveRefresh() end },
                            ringGlowEnabled = { order = 2, type = "toggle", name = "Border Glow", get = function() return CFG.ringGlowEnabled == true end, set = function(_, v) CFG.ringGlowEnabled = v; SaveRefresh() end },
                            haloEnabled = { order = 3, type = "toggle", name = "Hover Halo", get = function() return CFG.haloEnabled == true end, set = function(_, v) CFG.haloEnabled = v; SaveRefresh() end },
                            pulseEnable = { order = 4, type = "toggle", name = "Enable Pulse", get = function() return CFG.pulseEnable == true end, set = function(_, v) CFG.pulseEnable = v; SaveRefresh() end },
                        },
                    },
                    instanceBehavior = {
                        order = 50,
                        type = "group",
                        name = BrandSection("Instanced PvE Behavior"),
                        guiInline = true,
                        args = {
                            disableInDungeons = { order = 1, type = "toggle", name = "Disable in Dungeons", desc = "Put BattleMender to sleep in 5-player party instances.", get = function() return CFG.disableInDungeons ~= false end, set = function(_, v) CFG.disableInDungeons = v; SaveRefreshInstanceBehavior() end },
                            disableInRaids = { order = 2, type = "toggle", name = "Disable in Raids", desc = "Put BattleMender to sleep in raid instances.", get = function() return CFG.disableInRaids ~= false end, set = function(_, v) CFG.disableInRaids = v; SaveRefreshInstanceBehavior() end },
                            disableInScenarios = { order = 3, type = "toggle", name = "Disable in Scenarios", desc = "Put BattleMender to sleep in scenario instances.", get = function() return CFG.disableInScenarios == true end, set = function(_, v) CFG.disableInScenarios = v; SaveRefreshInstanceBehavior() end },
                            instanceFriendlyNamesOnly = { order = 4, type = "toggle", name = "Names Only While Disabled", desc = "Use Blizzard's friendly-player name-only mode while BattleMender is sleeping.", get = function() return CFG.instanceFriendlyNamesOnly ~= false end, set = function(_, v) CFG.instanceFriendlyNamesOnly = v; SaveRefreshInstanceBehavior() end },
                            instanceClassColorNames = { order = 5, type = "toggle", name = "Class-Colored Friendly Names", desc = "Use class colors for friendly player names while BattleMender is sleeping.", get = function() return CFG.instanceClassColorNames ~= false end, set = function(_, v) CFG.instanceClassColorNames = v; SaveRefreshInstanceBehavior() end },
                            restoreDefaultClickboxInPvE = { order = 6, type = "toggle", name = "Restore Default Clickbox While Disabled", desc = "Use a 110 x 45 friendly nameplate clickbox while BattleMender is sleeping instead of the circular BattleMender clickbox.", get = function() return CFG.restoreDefaultClickboxInPvE ~= false end, set = function(_, v) CFG.restoreDefaultClickboxInPvE = v; SaveRefreshInstanceBehavior() end },
                        },
                    },
                    generalGroup = {
                        order = 60,
                        type = "group",
                        name = BrandSection("General Settings"),
                        guiInline = true,
                        args = {
                            showLoginMessage = { order = 1, type = "toggle", name = "Show Login Message", get = function() return CFG.showLoginMessage ~= false end, set = function(_, v) CFG.showLoginMessage = v; SaveRefresh() end },
                            showMinimapButton = {
                                order = 2,
                                type = "toggle",
                                name = "Show Minimap Button",
                                desc = "Show BattleMender's standard LibDBIcon minimap launcher. Left-click opens Friendly Plates; right-click opens Enemy Plates.",
                                get = function()
                                    return BM.IsMinimapButtonShown and BM.IsMinimapButtonShown() or false
                                end,
                                set = function(_, v)
                                    if BM.SetMinimapButtonShown then
                                        BM.SetMinimapButtonShown(v == true)
                                    end
                                end,
                            },
                            resetMinimapButton = {
                                order = 2.1,
                                type = "execute",
                                name = "Reset Minimap Position",
                                desc = "Return the BattleMender minimap button to its default position.",
                                func = function()
                                    if BM.ResetMinimapButtonPosition then
                                        BM.ResetMinimapButtonPosition()
                                    end
                                end,
                            },
                            repairElvUIDisabledNameplates = {
                                order = 3,
                                type = "toggle",
                                name = "Repair Disabled ElvUI Nameplates",
                                desc = "When ElvUI is loaded but its NamePlates module is disabled, clear ElvUI's unit-specific nameplate toggles and clickthrough flags so Blizzard friendly plate mouse regions remain usable.",
                                get = function() return CFG.repairElvUIDisabledNameplates ~= false end,
                                set = function(_, v)
                                    CFG.repairElvUIDisabledNameplates = v and true or false
                                    if v and BM.ScheduleElvUIDisabledNameplateRepair then
                                        BM.ScheduleElvUIDisabledNameplateRepair()
                                    end
                                    SaveRefreshClickbox()
                                end,
                                hidden = function() return not _G.ElvUI end,
                            },
                            runElvUIRepair = {
                                order = 4,
                                type = "execute",
                                name = "Run ElvUI Repair Now",
                                desc = "Immediately repairs the disabled-ElvUI-nameplate state. Use this after changing ElvUI nameplate settings, out of combat.",
                                func = function()
                                    if BM.RepairElvUIDisabledNameplateState then
                                        local changed = BM.RepairElvUIDisabledNameplateState()
                                        if BM.SetFriendlyClickbox then BM.SetFriendlyClickbox() end
                                        if BM.RefreshAll then BM.RefreshAll() end
                                        print("|cff33ff99BattleMender:|r ElvUI disabled-nameplate repair " .. (changed and "applied." or "not needed."))
                                    end
                                end,
                                hidden = function() return not _G.ElvUI end,
                            },
                            debug = { order = 5, type = "toggle", name = "Debug Mode", get = function() return CFG.debug == true end, set = function(_, v) CFG.debug = v; SaveRefresh() end },
                            debugClickbox = { order = 6, type = "toggle", name = "Show Clickbox Debug", get = function() return CFG.debugClickbox == true end, set = function(_, v) CFG.debugClickbox = v; SaveRefresh() end },
                        },
                    },
                    resetGroup = {
                        order = 90,
                        type = "group",
                        name = "Reset",
                        guiInline = true,
                        args = {
                            resetToDefaults = {
                                order = 1,
                                type = "execute",
                                name = "Reset to Defaults",
                                desc = "Reset all BattleMender settings to the addon defaults.",
                                confirm = true,
                                confirmText = "Reset BattleMender settings to defaults?",
                                func = function()
                                    if BM.ResetToDefaults then
                                        BM.ResetToDefaults()
                                    else
                                        print("|cff33ff99BattleMender:|r ResetToDefaults function is missing.")
                                    end
                                end,
                            },
                        },
                    },
                },
            },
            effects = {
                order = 2,
                type = "group",
                name = "Effects",
                disabled = DisabledUnlessDeveloper,
                args = {
                    locked = { order = 1, type = "description", name = function() return CFG.developerMode and "" or "Enable Developer Mode on the General tab to edit these settings." end },
                    hoverGroup = {
                        order = 50,
                        type = "group",
                        name = "Hover Effects",
                        guiInline = true,
                        args = {
                            specGlowEnabled = { order = 1, type = "toggle", name = "Spec Icon Glow", get = function() return CFG.specGlowEnabled == true end, set = function(_, v) CFG.specGlowEnabled = v; SaveRefresh() end },
                            specGlowBrightness = { order = 2, type = "range", name = "Spec Glow Brightness", min = 0, max = 1, step = 0.05, get = function() return CFG.specGlowBrightness or 0.4 end, set = function(_, v) CFG.specGlowBrightness = v; SaveRefresh() end },
                            specGlowFadeIn = { order = 3, type = "range", name = "Spec Glow Fade In", min = 0, max = 1, step = 0.01, get = function() return CFG.specGlowFadeIn or 0 end, set = function(_, v) CFG.specGlowFadeIn = v; SaveRefresh() end },
                            specGlowFadeOut = { order = 4, type = "range", name = "Spec Glow Fade Out", min = 0, max = 1, step = 0.01, get = function() return CFG.specGlowFadeOut or 0.2 end, set = function(_, v) CFG.specGlowFadeOut = v; SaveRefresh() end },
                            ringGlowEnabled = { order = 5, type = "toggle", name = "Border Glow", get = function() return CFG.ringGlowEnabled == true end, set = function(_, v) CFG.ringGlowEnabled = v; SaveRefresh() end },
                            ringGlowBrightness = { order = 6, type = "range", name = "Border Glow Brightness", min = 0, max = 1, step = 0.05, get = function() return CFG.ringGlowBrightness or 0.4 end, set = function(_, v) CFG.ringGlowBrightness = v; SaveRefresh() end },
                            ringGlowFadeIn = { order = 7, type = "range", name = "Border Glow Fade In", min = 0, max = 1, step = 0.01, get = function() return CFG.ringGlowFadeIn or 0.05 end, set = function(_, v) CFG.ringGlowFadeIn = v; SaveRefresh() end },
                            ringGlowFadeOut = { order = 8, type = "range", name = "Border Glow Fade Out", min = 0, max = 1, step = 0.01, get = function() return CFG.ringGlowFadeOut or 0.1 end, set = function(_, v) CFG.ringGlowFadeOut = v; SaveRefresh() end },
                            haloEnabled = { order = 9, type = "toggle", name = "Hover Halo", get = function() return CFG.haloEnabled == true end, set = function(_, v) CFG.haloEnabled = v; SaveRefresh() end },
                            haloGlowSizeScale = { order = 10, type = "range", name = "Halo Size", min = 0.5, max = 4, step = 0.05, get = function() return CFG.haloGlowSizeScale or 1.5 end, set = function(_, v) CFG.haloGlowSizeScale = v; SaveRefresh() end },
                            haloGlowAlpha = { order = 11, type = "range", name = "Halo Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.haloGlowAlpha or 0.5 end, set = function(_, v) CFG.haloGlowAlpha = v; SaveRefresh() end },
                            pulseEnable = { order = 12, type = "toggle", name = "Enable Pulse", get = function() return CFG.pulseEnable == true end, set = function(_, v) CFG.pulseEnable = v; SaveRefresh() end },
                        },
                    },

                },
            },
            normal = {
                order = 3,
                type = "group",
                name = "Normal",
                disabled = DisabledUnlessDeveloper,
                args = {
                    locked = { order = 1, type = "description", name = function() return CFG.developerMode and "" or "Enable Developer Mode on the General tab to edit these settings." end },
                    spec = {
                        order = 10, type = "group", name = "Spec Icon", guiInline = true,
                        args = {
                            specIconEnabled = { order = 1, type = "toggle", name = "Enable Spec Icon", get = function() return CFG.specIconEnabled ~= false end, set = function(_, v) CFG.specIconEnabled = v; SaveRefresh() end },
                            specIconAlpha = { order = 2, type = "range", name = "Spec Icon Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.specIconAlpha or 1 end, set = function(_, v) CFG.specIconAlpha = v; SaveRefresh() end },
                            specIconBlendMode = { order = 3, type = "select", name = "Spec Icon Blend", values = BLEND_MODES, get = function() return CFG.specIconBlendMode or "MOD" end, set = function(_, v) CFG.specIconBlendMode = v; SaveRefresh() end },
                        },
                    },
                    damaged = {
                        order = 20, type = "group", name = "Damaged Spec Icon", guiInline = true,
                        args = {
                            damageIconAlpha = { order = 1, type = "range", name = "Damaged Spec Icon Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.damageIconAlpha or 1 end, set = function(_, v) CFG.damageIconAlpha = v; SaveRefresh() end },
                            damageIconBlendMode = { order = 2, type = "select", name = "Damaged Spec Icon Blend", values = BLEND_MODES, get = function() return CFG.damageIconBlendMode or "BLEND" end, set = function(_, v) CFG.damageIconBlendMode = v; SaveRefresh() end },
                            damageIconColor = { order = 3, type = "color", name = "Fallback Color", get = function() return CFG.damageIconR or 1, CFG.damageIconG or 0.02, CFG.damageIconB or 0.02 end, set = function(_, r, g, b) CFG.damageIconR = r; CFG.damageIconG = g; CFG.damageIconB = b; SaveRefresh() end },
                        },
                    },
                    health = {
                        order = 30, type = "group", name = "Health Overlay", guiInline = true,
                        args = {
                            healthEnable = { order = 1, type = "toggle", name = "Enable Health Overlay", get = function() return CFG.healthEnable ~= false end, set = function(_, v) CFG.healthEnable = v; SaveRefresh() end },
                            healthOverlayAlpha = { order = 2, type = "range", name = "Health Overlay Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.healthOverlayAlpha or 1 end, set = function(_, v) CFG.healthOverlayAlpha = v; SaveRefresh() end },
                            healthOverlayBlendMode = { order = 3, type = "select", name = "Health Overlay Blend", values = BLEND_MODES, get = function() return CFG.healthOverlayBlendMode or "BLEND" end, set = function(_, v) CFG.healthOverlayBlendMode = v; SaveRefresh() end },
                            healthOverlayUseClassColor = { order = 4, type = "toggle", name = "Use Class Color", get = function() return CFG.healthOverlayUseClassColor == true end, set = function(_, v) CFG.healthOverlayUseClassColor = v; SaveRefresh() end },
                            healthOverlayColor = { order = 5, type = "color", name = "Health Overlay Color", get = function() return CFG.healthOverlayColorR or 1, CFG.healthOverlayColorG or 1, CFG.healthOverlayColorB or 1 end, set = function(_, r, g, b) CFG.healthOverlayColorR = r; CFG.healthOverlayColorG = g; CFG.healthOverlayColorB = b; SaveRefresh() end },
                            healthOverlayReverseFill = { order = 6, type = "toggle", name = "Reverse Fill", get = function() return CFG.healthOverlayReverseFill == true end, set = function(_, v) CFG.healthOverlayReverseFill = v; SaveRefresh() end },
                        },
                    },
                    ring = {
                        order = 40, type = "group", name = "Border", guiInline = true,
                        args = {
                            ringEnabled = { order = 1, type = "toggle", name = "Enable Border", get = function() return CFG.ringEnabled ~= false end, set = function(_, v) CFG.ringEnabled = v; SaveRefresh() end },
                            ringTexture = { order = 2, type = "select", name = "Border Style", values = RING_TEXTURES, sorting = RING_TEXTURE_ORDER, get = function() return CFG.ringTexture or "Ring_20px" end, set = function(_, v) CFG.ringTexture = v; SaveRefresh() end },
                            ringScale = { order = 3, type = "range", name = "Border Size", min = 0.8, max = 1.4, step = 0.01, get = function() return CFG.ringScale or 1 end, set = function(_, v) CFG.ringScale = v; SaveRefresh() end },
                            ringAlpha = { order = 4, type = "range", name = "Border Opacity", min = 0, max = 1, step = 0.05, get = function() return CFG.ringAlpha or 1 end, set = function(_, v) CFG.ringAlpha = v; SaveRefresh() end },
                        },
                    },
					
                    accentOverlay = {
                        order = 45,
                        type = "group",
                        name = "Accent Overlay",
                        guiInline = true,
                        args = {
                            accentOverlayEnabled = {
                                order = 1,
                                type = "toggle",
                                name = "Enable Accent Overlay",
                                get = function() return CFG.accentOverlayEnabled == true end,
                                set = function(_, v) CFG.accentOverlayEnabled = v; SaveRefresh() end,
                            },
                            accentOverlayTexture = {
                                order = 2,
                                type = "select",
                                name = "Texture",
                                values = ACCENT_OVERLAY_TEXTURES,
                                get = function() return CFG.accentOverlayTexture or "Metal_Ring" end,
                                set = function(_, v) CFG.accentOverlayTexture = v; SaveRefresh() end,
                            },
                            accentOverlayScale = {
                                order = 3,
                                type = "range",
                                name = "Scale",
                                min = 0.5,
                                max = 2.5,
                                step = 0.05,
                                get = function() return CFG.accentOverlayScale or 1 end,
                                set = function(_, v) CFG.accentOverlayScale = v; SaveRefresh() end,
                            },
                            accentOverlayAlpha = {
                                order = 4,
                                type = "range",
                                name = BrandLabel("Alpha"),
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.accentOverlayAlpha or 1 end,
                                set = function(_, v) CFG.accentOverlayAlpha = v; SaveRefresh() end,
                            },
                            accentOverlayBlendMode = {
                                order = 5,
                                type = "select",
                                name = "Blend Mode",
                                values = BLEND_MODES,
                                get = function() return CFG.accentOverlayBlendMode or "BLEND" end,
                                set = function(_, v) CFG.accentOverlayBlendMode = v; SaveRefresh() end,
                            },
                            accentOverlayUseClassColor = {
                                order = 6,
                                type = "toggle",
                                name = "Use Class Color",
                                get = function() return CFG.accentOverlayUseClassColor == true end,
                                set = function(_, v) CFG.accentOverlayUseClassColor = v; SaveRefresh() end,
                            },
                            accentOverlayColor = {
                                order = 7,
                                type = "color",
                                name = "Color",
                                disabled = function() return CFG.accentOverlayUseClassColor == true end,
                                get = function()
                                    return CFG.accentOverlayColorR or 1,
                                           CFG.accentOverlayColorG or 1,
                                           CFG.accentOverlayColorB or 1
                                end,
                                set = function(_, r, g, b)
                                    CFG.accentOverlayColorR = r
                                    CFG.accentOverlayColorG = g
                                    CFG.accentOverlayColorB = b
                                    SaveRefresh()
                                end,
                            },
                            accentOverlayGlowEnabled = {
                                order = 8,
                                type = "toggle",
                                name = "Enable Hover Glow",
                                get = function() return CFG.accentOverlayGlowEnabled == true end,
                                set = function(_, v) CFG.accentOverlayGlowEnabled = v; SaveRefresh() end,
                            },
                            accentOverlayGlowBrightness = {
                                order = 9,
                                type = "range",
                                name = "Hover Glow Brightness",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.accentOverlayGlowBrightness or 0.45 end,
                                set = function(_, v) CFG.accentOverlayGlowBrightness = v; SaveRefresh() end,
                            },
                            accentOverlayGlowFadeIn = {
                                order = 10,
                                type = "range",
                                name = "Hover Fade In",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.accentOverlayGlowFadeIn or 0.05 end,
                                set = function(_, v) CFG.accentOverlayGlowFadeIn = v; SaveRefresh() end,
                            },
                            accentOverlayGlowFadeOut = {
                                order = 11,
                                type = "range",
                                name = "Hover Fade Out",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.accentOverlayGlowFadeOut or 0.15 end,
                                set = function(_, v) CFG.accentOverlayGlowFadeOut = v; SaveRefresh() end,
                            },
                        },
                    },
					
                    pulse = {
                        order = 50, type = "group", name = "Pulse", guiInline = true,
                        args = {
                            pulseEnable = { order = 1, type = "toggle", name = "Enable Pulse", get = function() return CFG.pulseEnable == true end, set = function(_, v) CFG.pulseEnable = v; SaveRefresh() end },
                            pulseSpeed = { order = 2, type = "range", name = "Pulse Speed", min = 0.1, max = 2, step = 0.05, get = function() return CFG.pulseSpeed or 0.2 end, set = function(_, v) CFG.pulseSpeed = v; SaveRefresh() end },
                            pulseIntensity = { order = 3, type = "range", name = "Pulse Intensity", min = 0.1, max = 1, step = 0.05, get = function() return CFG.pulseIntensity or 0.45 end, set = function(_, v) CFG.pulseIntensity = v; SaveRefresh() end },
                            pulseOverlayEnable = { order = 4, type = "toggle", name = "Enable Pulse Overlay", get = function() return CFG.pulseOverlayEnable == true end, set = function(_, v) CFG.pulseOverlayEnable = v; SaveRefresh() end },
                            pulseOverlayTexture = { order = 5, type = "select", name = "Pulse Overlay Texture", values = PULSE_TEXTURES, get = function() return CFG.pulseOverlayTexture or "Circle_Smooth2" end, set = function(_, v) CFG.pulseOverlayTexture = v; SaveRefresh() end },
                            pulseOverlayAlpha = { order = 6, type = "range", name = "Pulse Overlay Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.pulseOverlayAlpha or 1 end, set = function(_, v) CFG.pulseOverlayAlpha = v; SaveRefresh() end },
                            pulseOverlayBlend = { order = 7, type = "select", name = "Pulse Overlay Blend", values = BLEND_MODES, get = function() return CFG.pulseOverlayBlend or "ADD" end, set = function(_, v) CFG.pulseOverlayBlend = v; SaveRefresh() end },
                        },
                    },
                },
            },
            los = {
                order = 4,
                type = "group",
                name = "LoS",
                disabled = DisabledUnlessDeveloper,
                args = {
                    locked = { order = 1, type = "description", name = function() return CFG.developerMode and "" or "Enable Developer Mode on the General tab to edit these settings." end },
                    losEngine = {
                        order = 5,
                        type = "group",
                        name = "LoS Engine",
                        guiInline = true,
                        args = {
                            losUpdateRate = { order = 1, type = "range", name = "LoS Update Rate", min = 0.03, max = 0.50, step = 0.01, get = function() return CFG.losUpdateRate or 0.15 end, set = function(_, v) CFG.losUpdateRate = v; SaveRefresh() end },
                        },
                    },
                    losSpec = {
                        order = 10, type = "group", name = "LoS Spec Icon", guiInline = true,
                        args = {
                            losSpecIconAlpha = { order = 1, type = "range", name = "LoS Spec Icon Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losSpecIconAlpha or 0.45 end, set = function(_, v) CFG.losSpecIconAlpha = v; SaveRefresh() end },
                            losSpecIconBlendMode = { order = 2, type = "select", name = "LoS Spec Icon Blend", values = BLEND_MODES, get = function() return CFG.losSpecIconBlendMode or "BLEND" end, set = function(_, v) CFG.losSpecIconBlendMode = v; SaveRefresh() end },
                        },
                    },
                    losDamaged = {
                        order = 20, type = "group", name = "LoS Damaged Spec Icon", guiInline = true,
                        args = {
                            losDamageIconAlpha = { order = 1, type = "range", name = "LoS Damaged Spec Icon Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losDamageIconAlpha or 0.55 end, set = function(_, v) CFG.losDamageIconAlpha = v; SaveRefresh() end },
                            losDamageIconBlendMode = { order = 2, type = "select", name = "LoS Damaged Spec Icon Blend", values = BLEND_MODES, get = function() return CFG.losDamageIconBlendMode or "BLEND" end, set = function(_, v) CFG.losDamageIconBlendMode = v; SaveRefresh() end },
                        },
                    },
                    losHealth = {
                        order = 30, type = "group", name = "LoS Health Overlay", guiInline = true,
                        args = {
                            losHealthOverlayAlpha = { order = 1, type = "range", name = "LoS Health Overlay Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losHealthOverlayAlpha or 0.35 end, set = function(_, v) CFG.losHealthOverlayAlpha = v; SaveRefresh() end },
                            losHealthOverlayBlendMode = { order = 2, type = "select", name = "LoS Health Overlay Blend", values = BLEND_MODES, get = function() return CFG.losHealthOverlayBlendMode or "BLEND" end, set = function(_, v) CFG.losHealthOverlayBlendMode = v; SaveRefresh() end },
                            losHealthOverlayColor = { order = 4, type = "color", name = "LoS Health Overlay Color", get = function() return CFG.losHealthOverlayColorR or 0.3, CFG.losHealthOverlayColorG or 0.7, CFG.losHealthOverlayColorB or 0.7 end, set = function(_, r, g, b) CFG.losHealthOverlayColorR = r; CFG.losHealthOverlayColorG = g; CFG.losHealthOverlayColorB = b; SaveRefresh() end },
                            losHealthOverlayCompensationNote = {
								order = 5,
								type = "description",
								width = "full",
								fontSize = "medium",
								name = "The LoS Health Overlay color is automatically adjusted to compensate for the Damaged Spec Icon underneath. This helps preserve the selected overlay color when the damaged icon would otherwise bleed through during LoS fading.",
							},
						},
                    },
                    losRing = {
                        order = 40, type = "group", name = "LoS Border", guiInline = true,
                        args = {
                            losRingTexture = { order = 1, type = "select", name = "LoS Border Style", values = LOS_RING_TEXTURES, sorting = LOS_RING_TEXTURE_ORDER, get = function() return CFG.losRingTexture or "SAME" end, set = function(_, v) CFG.losRingTexture = v; SaveRefresh() end },
                            losRingAlpha = { order = 2, type = "range", name = "LoS Border Opacity", min = 0, max = 1, step = 0.05, get = function() return CFG.losRingAlpha or 0.75 end, set = function(_, v) CFG.losRingAlpha = v; SaveRefresh() end },
                            losRingAlphaMultiplier = { order = 3, type = "range", name = "LoS Border Opacity Multiplier", min = 0, max = 4, step = 0.05, get = function() return CFG.losRingAlphaMultiplier or 1 end, set = function(_, v) CFG.losRingAlphaMultiplier = v; SaveRefresh() end },
                        },
                    },
					
                    losAccentOverlay = {
                        order = 45,
                        type = "group",
                        name = "LoS Accent Overlay",
                        guiInline = true,
                        args = {
                            losAccentOverlayTexture = {
                                order = 1,
                                type = "select",
                                name = "Texture",
                                values = LOS_ACCENT_OVERLAY_TEXTURES,
                                get = function() return CFG.losAccentOverlayTexture or "SAME" end,
                                set = function(_, v) CFG.losAccentOverlayTexture = v; SaveRefresh() end,
                            },
                            losAccentOverlayScale = {
                                order = 2,
                                type = "range",
                                name = "Scale",
                                min = 0.5,
                                max = 2.5,
                                step = 0.05,
                                get = function() return CFG.losAccentOverlayScale or 1 end,
                                set = function(_, v) CFG.losAccentOverlayScale = v; SaveRefresh() end,
                            },
                            losAccentOverlayAlpha = {
                                order = 3,
                                type = "range",
                                name = BrandLabel("Alpha"),
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.losAccentOverlayAlpha or 0.75 end,
                                set = function(_, v) CFG.losAccentOverlayAlpha = v; SaveRefresh() end,
                            },
                            losAccentOverlayBlendMode = {
                                order = 4,
                                type = "select",
                                name = "Blend Mode",
                                values = BLEND_MODES,
                                get = function() return CFG.losAccentOverlayBlendMode or "BLEND" end,
                                set = function(_, v) CFG.losAccentOverlayBlendMode = v; SaveRefresh() end,
                            },
                            losAccentOverlayUseClassColor = {
                                order = 5,
                                type = "toggle",
                                name = "Use Class Color",
                                get = function() return CFG.losAccentOverlayUseClassColor == true end,
                                set = function(_, v) CFG.losAccentOverlayUseClassColor = v; SaveRefresh() end,
                            },
                            losAccentOverlayColor = {
                                order = 6,
                                type = "color",
                                name = "Color",
                                disabled = function() return CFG.losAccentOverlayUseClassColor == true end,
                                get = function()
                                    return CFG.losAccentOverlayColorR or 1,
                                           CFG.losAccentOverlayColorG or 1,
                                           CFG.losAccentOverlayColorB or 1
                                end,
                                set = function(_, r, g, b)
                                    CFG.losAccentOverlayColorR = r
                                    CFG.losAccentOverlayColorG = g
                                    CFG.losAccentOverlayColorB = b
                                    SaveRefresh()
                                end,
                            },
                            losAccentOverlayGlowEnabled = {
                                order = 7,
                                type = "toggle",
                                name = "Enable Hover Glow",
                                get = function() return CFG.losAccentOverlayGlowEnabled == true end,
                                set = function(_, v) CFG.losAccentOverlayGlowEnabled = v; SaveRefresh() end,
                            },
                            losAccentOverlayGlowBrightness = {
                                order = 8,
                                type = "range",
                                name = "Hover Glow Brightness",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.losAccentOverlayGlowBrightness or 0.35 end,
                                set = function(_, v) CFG.losAccentOverlayGlowBrightness = v; SaveRefresh() end,
                            },
                            losAccentOverlayGlowFadeIn = {
                                order = 9,
                                type = "range",
                                name = "Hover Fade In",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.losAccentOverlayGlowFadeIn or 0.05 end,
                                set = function(_, v) CFG.losAccentOverlayGlowFadeIn = v; SaveRefresh() end,
                            },
                            losAccentOverlayGlowFadeOut = {
                                order = 10,
                                type = "range",
                                name = "Hover Fade Out",
                                min = 0,
                                max = 1,
                                step = 0.05,
                                get = function() return CFG.losAccentOverlayGlowFadeOut or 0.15 end,
                                set = function(_, v) CFG.losAccentOverlayGlowFadeOut = v; SaveRefresh() end,
                            },
                        },
                    },
					
					
                    losPulse = {
                        order = 50, type = "group", name = "LoS Pulse", guiInline = true,
                        args = {
                            losPulseEnable = { order = 1, type = "toggle", name = "Enable LoS Pulse", get = function() return CFG.losPulseEnable == true end, set = function(_, v) CFG.losPulseEnable = v; SaveRefresh() end },
                            losPulseSpeed = { order = 2, type = "range", name = "LoS Pulse Speed", min = 0.1, max = 2, step = 0.05, get = function() return CFG.losPulseSpeed or 0.3 end, set = function(_, v) CFG.losPulseSpeed = v; SaveRefresh() end },
                            losPulseIntensity = { order = 3, type = "range", name = "LoS Pulse Intensity", min = 0.1, max = 1, step = 0.05, get = function() return CFG.losPulseIntensity or 0.8 end, set = function(_, v) CFG.losPulseIntensity = v; SaveRefresh() end },
                            losPulseOverlayEnable = { order = 4, type = "toggle", name = "Enable LoS Pulse Overlay", get = function() return CFG.losPulseOverlayEnable == true end, set = function(_, v) CFG.losPulseOverlayEnable = v; SaveRefresh() end },
                            losPulseOverlayTexture = { order = 5, type = "select", name = "LoS Pulse Overlay Texture", values = PULSE_TEXTURES, get = function() return CFG.losPulseOverlayTexture or "Circle_AlphaGradient_In" end, set = function(_, v) CFG.losPulseOverlayTexture = v; SaveRefresh() end },
                            losPulseOverlayAlpha = { order = 6, type = "range", name = "LoS Pulse Overlay Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losPulseOverlayAlpha or 1 end, set = function(_, v) CFG.losPulseOverlayAlpha = v; SaveRefresh() end },
                            losPulseOverlayBlend = { order = 7, type = "select", name = "LoS Pulse Overlay Blend", values = BLEND_MODES, get = function() return CFG.losPulseOverlayBlend or "ADD" end, set = function(_, v) CFG.losPulseOverlayBlend = v; SaveRefresh() end },
                        },
                    },
                },
            },
        },
    }



    options.args.enemyPlates = {
        order = 5,
        type = "group",
        name = "Enemy Plates",
        childGroups = "tab",
        args = {
            enabled = {
                order = 10,
                type = "toggle",
                name = "Enable Custom Enemy Plates",
                get = function() return CFG.enemyPlatesEnabled ~= false end,
                set = function(_, v) CFG.enemyPlatesEnabled = v and true or false; SaveRefreshClickbox() end,
            },
            autoDisable = {
                order = 11,
                type = "toggle",
                name = "Auto-disable with ElvUI / Plater",
                get = function() return CFG.enemyPlatesAutoDisableKnownMods ~= false end,
                set = function(_, v) CFG.enemyPlatesAutoDisableKnownMods = v and true or false; SaveRefreshClickbox() end,
            },
            hideNative = {
                order = 12,
                type = "toggle",
                name = "Hide Blizzard Enemy Plate Art",
                desc = "Hides Blizzard's native enemy UnitFrame by setting only the root native frame alpha to zero. This avoids walking Blizzard's protected health/cast/aura child tree while preventing the default plate from showing behind BattleMender's custom enemy plate.",
                get = function() return CFG.enemyPlateHideNativeBlizzard ~= false end,
                set = function(_, v) CFG.enemyPlateHideNativeBlizzard = v and true or false; SaveRefresh() end,
            },
            status = {
                order = 13,
                type = "description",
                width = "full",
                name = function()
                    local provider = "Blizzard"
                    local color = "|cffaaaaaa"

                    if BM.ShouldUseCustomEnemyPlates and BM.ShouldUseCustomEnemyPlates() then
                        provider = "BattleMender"
                        color = "|cff33ff99"
                    else
                        local providerStatus = BM.GetEnemyNameplateProviderStatus and BM.GetEnemyNameplateProviderStatus()
                        if providerStatus and providerStatus.plater then
                            provider = "Plater"
                            color = "|cff66ccff"
                        elseif providerStatus and providerStatus.elvuiEnemyActive then
                            provider = "ElvUI"
                            color = "|cff33ff99"
                        end
                    end

                    return "|cffc4c9ccEnemy Plates provider:|r " .. color .. provider .. "|r"
                end,
            },
            testButton = {
                order = 12.5,
                type = "execute",
                width = "normal",
                name = function()
                    return CFG.enemyPlateTestMode == true and "Stop Test" or "Test"
                end,
                desc = "Show the enemy plate preview. Drag the preview itself to move it. It closes automatically with the options window or when combat starts.",
                disabled = function()
                    return InCombatLockdown and InCombatLockdown()
                end,
                func = function()
                    if InCombatLockdown and InCombatLockdown() then return end

                    CFG.enemyPlateTestMode = CFG.enemyPlateTestMode ~= true
                    if BM.RefreshEnemyPlateTestMode then
                        BM.RefreshEnemyPlateTestMode()
                    end

                    if LibStub then
                        local registry = LibStub("AceConfigRegistry-3.0", true)
                        if registry and registry.NotifyChange then
                            pcall(registry.NotifyChange, registry, APP_NAME)
                        end
                    end
                end,
            },
            layout = {
                order = 20,
                type = "group",
                name = BrandSection("Health / Layout"),
                args = {
                    width = { order = 1, type = "range", name = "Width", min = 80, max = 260, step = 1, get = function() return CFG.enemyPlateWidth or 154 end, set = function(_, v) CFG.enemyPlateWidth = v; SaveRefresh() end },
                    healthHeight = { order = 2, type = "range", name = "Health Height", min = 6, max = 28, step = 1, get = function() return CFG.enemyPlateHealthHeight or 12 end, set = function(_, v) CFG.enemyPlateHealthHeight = v; SaveRefresh() end },
                    scale = { order = 3, type = "range", name = "Base Scale", min = 0.5, max = 2, step = 0.05, get = function() return CFG.enemyPlateScale or 1 end, set = function(_, v) CFG.enemyPlateScale = v; SaveRefresh() end },
                    nonTargetScale = { order = 4, type = "range", name = "Non-target Scale", min = 0.5, max = 2, step = 0.05, get = function() return CFG.enemyPlateNonTargetScale or 1 end, set = function(_, v) CFG.enemyPlateNonTargetScale = v; SaveRefresh() end },
                    targetScale = { order = 5, type = "range", name = "Current Target Scale", min = 0.5, max = 2, step = 0.05, get = function() return CFG.enemyPlateTargetScale or 1 end, set = function(_, v) CFG.enemyPlateTargetScale = v; SaveRefresh() end },
                    focusScale = { order = 6, type = "range", name = "Focus Target Scale", min = 0.5, max = 2, step = 0.05, get = function() return CFG.enemyPlateFocusScale or 1.15 end, set = function(_, v) CFG.enemyPlateFocusScale = v; SaveRefresh() end },
                    showName = { order = 7, type = "toggle", name = "Show Name", get = function() return CFG.enemyPlateShowName ~= false end, set = function(_, v) CFG.enemyPlateShowName = v and true or false; SaveRefresh() end },
                    hidePlayerNamesInPvP = {
                        order = 8,
                        type = "toggle",
                        name = "Hide Player Names in PvP",
                        desc = "Hides enemy player name text in battlegrounds and arenas while keeping enemy NPC names visible. Useful for reducing player-name clutter without losing NPC identification.",
                        disabled = function() return CFG.enemyPlateShowName == false end,
                        get = function() return CFG.enemyPlateHidePlayerNamesInPvP ~= false end,
                        set = function(_, v) CFG.enemyPlateHidePlayerNamesInPvP = v and true or false; SaveRefresh() end,
                    },
                    nameSize = { order = 9, type = "range", name = "Name Size", min = 8, max = 24, step = 1, get = function() return CFG.enemyPlateNameSize or 12 end, set = function(_, v) CFG.enemyPlateNameSize = v; SaveRefresh() end },
                    namePosition = { order = 10, type = "select", name = "Name Position", values = ENEMY_NAME_POSITIONS, get = function() return CFG.enemyPlateNamePosition or "ABOVE" end, set = function(_, v) CFG.enemyPlateNamePosition = v; SaveRefresh() end },
                    nameX = { order = 11, type = "range", name = "Name X Offset", min = -100, max = 100, step = 1, get = function() return CFG.enemyPlateNameXOffset or 0 end, set = function(_, v) CFG.enemyPlateNameXOffset = v; SaveRefresh() end },
                    nameY = { order = 12, type = "range", name = "Name Y Offset", min = -100, max = 100, step = 1, get = function() return CFG.enemyPlateNameYOffset or 2 end, set = function(_, v) CFG.enemyPlateNameYOffset = v; SaveRefresh() end },
                    classColorNames = { order = 13, type = "toggle", name = "Class-colored Names", desc = "Uses Blizzard's native enemy class-color source so player names remain compatible with 12.1 secret values.", get = function() return CFG.enemyPlateClassColorNames ~= false end, set = function(_, v) CFG.enemyPlateClassColorNames = v and true or false; SaveRefresh() end },
                    classColorHealth = { order = 13, type = "toggle", name = "Class-colored Player Health", desc = "Uses Blizzard's native enemy class-color source so player health bars remain compatible with 12.1 secret values.", get = function() return CFG.enemyPlateClassColorHealth ~= false end, set = function(_, v) CFG.enemyPlateClassColorHealth = v and true or false; SaveRefresh() end },
                    classificationColors = { order = 14, type = "toggle", name = "NPC Classification Colors", get = function() return CFG.enemyPlateClassificationColors ~= false end, set = function(_, v) CFG.enemyPlateClassificationColors = v and true or false; SaveRefresh() end },
                },
            },
            textures = {
                order = 23,
                type = "group",
                name = BrandSection("Bar Textures"),
                args = {
                    info = {
                        order = 0,
                        type = "description",
                        width = "full",
                        name = "Statusbar textures are pulled from LibSharedMedia, using the same preview dropdown style as ElvUI. BattleMender also registers Media\\Bars\\ribbon.tga and Media\\Bars\\crimp.tga as built-in statusbar options.",
                    },
                    enemyTexture = EnemyStatusbarSelect(1, "Nameplates StatusBar Texture", "enemyPlateHealthTexture", false, "Default enemy health bar texture."),
                    targetTexture = EnemyStatusbarSelect(2, "Current Target StatusBar Texture", "enemyPlateTargetHealthTexture", false, "Texture used when the unit is your current target. Focus still wins over target.", nil, "enemyPlateHealthTexture"),
                    focusTexture = EnemyStatusbarSelect(3, "Focus Target StatusBar Texture", "enemyPlateFocusHealthTexture", false, "Texture used when the unit is your focus target. Focus wins over target."),
                    fillMode = {
                        order = 4,
                        type = "select",
                        name = "Health Fill Rendering",
                        desc = "Direct StatusBar reliably follows live health. Stable Clip keeps detailed textures fixed in place, but is experimental because live nameplate health can be protected by the client.",
                        values = {
                            STATUSBAR = "Direct StatusBar - reliable fill",
                            CLIP = "Stable Clip - experimental",
                        },
                        get = function() return CFG.enemyPlateHealthFillMode or "STATUSBAR" end,
                        set = function(_, v) CFG.enemyPlateHealthFillMode = v or "STATUSBAR"; SaveRefresh() end,
                    },
                    backgroundColor = EnemyColorOption(5, "Health Background Color", "enemyPlateHealthBackground", 0, 0, 0, 0.85, "Base health-bar background. The alpha here controls the normal health background opacity."),
                    note = {
                        order = 6,
                        type = "description",
                        width = "full",
                        name = "Horizontal tiling has been removed. For repeated patterns, edit the texture itself so the bar can stretch normally.",
                    },
                },
            },

            colors = {
                order = 25,
                type = "group",
                name = BrandSection("Colors / Highlights"),
                args = {
                    info = { order = 1, type = "description", width = "full", name = "ElvUI-style enemy plate colors. Normal NPCs use reaction colors; rare/elite/minus/worldboss still use classification colors when enabled." },
                    selection = {
                        order = 10,
                        type = "group",
                        name = BrandLabel("Selection"),
                        guiInline = true,
                        args = {
                            hostile = EnemyColorOption(1, "Hostile", "enemyPlateSelectionHostile", 0.82, 0.26, 0.26, 1),
                            unfriendly = EnemyColorOption(2, "Unfriendly", "enemyPlateSelectionUnfriendly", 1, 0.50, 0.20, 1),
                            neutral = EnemyColorOption(3, "Neutral", "enemyPlateNeutral", 0.85098039215686, 0.76078431372549, 0.36078431372549, 1, "Used for neutral NPCs. ElvUI default: #d9c25c."),
                            friendly = EnemyColorOption(4, "Friendly", "enemyPlateSelectionFriendly", 0.29, 0.69, 0.31, 1),
                            player = EnemyColorOption(5, "Player", "enemyPlateSelectionPlayer", 0.34, 0.51, 0.96, 1, "Used for enemy players only when class-colored health is disabled."),
                            party = EnemyColorOption(6, "Party", "enemyPlateSelectionParty", 0.42, 0.23, 1, 1),
                            partyPVP = EnemyColorOption(7, "Party PVP", "enemyPlateSelectionPartyPVP", 0.74, 0.20, 0.95, 1),
                            friend = EnemyColorOption(8, "Friend", "enemyPlateSelectionFriend", 0.20, 1, 0.43, 1),
                            dead = EnemyColorOption(9, "Dead", "enemyPlateSelectionDead", 1, 1, 1, 1),
                            bgFriendly = EnemyColorOption(10, "Battleground Friendly", "enemyPlateSelectionBGFriendly", 0.08, 0.61, 0.32, 1),
                            tagged = EnemyColorOption(11, "Tagged NPC", "enemyPlateTaggedNPC", 0.6, 0.6, 0.6, 1, "Used for tap-denied or tagged NPCs. ElvUI default: #999999."),
                        },
                    },
                    classification = {
                        order = 15,
                        type = "group",
                        name = BrandLabel("Classification Colors"),
                        guiInline = true,
                        args = {
                            enabled = { order = 0, type = "toggle", name = "Use Classification Colors", get = function() return CFG.enemyPlateClassificationColors ~= false end, set = function(_, v) CFG.enemyPlateClassificationColors = v and true or false; SaveRefresh() end },
                            worldboss = EnemyColorOption(1, "Worldboss", "enemyPlateClassificationWorldboss", 0.78, 0.65, 0, 1),
                            eliteBoss = EnemyColorOption(2, "Elite Boss", "enemyPlateClassificationEliteBoss", 0.82, 0.25, 0.68, 1),
                            eliteMini = EnemyColorOption(3, "Elite Mini", "enemyPlateClassificationEliteMini", 0.49, 0.25, 0.78, 1),
                            rareElite = EnemyColorOption(4, "Rare Elite", "enemyPlateClassificationRareElite", 0.08, 0.76, 0.66, 1),
                            rare = EnemyColorOption(5, "Rare", "enemyPlateClassificationRare", 0.28, 0.78, 0.02, 1),
                            caster = EnemyColorOption(6, "Caster", "enemyPlateClassificationCaster", 0.05, 0.56, 0.78, 1, "Exposed for parity with ElvUI's color section. BattleMender does not currently infer caster-class NPCs from Blizzard classification."),
                        },
                    },
                    target = {
                        order = 20,
                        type = "group",
                        name = BrandLabel("Target"),
                        guiInline = true,
                        args = {
                            targetHighlight = { order = 1, type = "toggle", name = "Highlight Current Target", desc = "Master toggle for the current-target visual state. This no longer changes the real health-bar color.", get = function() return CFG.enemyPlateTargetHighlightEnabled ~= false end, set = function(_, v) CFG.enemyPlateTargetHighlightEnabled = v and true or false; SaveRefresh() end },
                            targetColor = EnemyColorOption(2, "Target Highlight Color", "enemyPlateTargetColor", 1, 1, 1, 0.27058823529412, "ElvUI target indicator alpha 69/255."),
                            targetBackground = { order = 3, type = "toggle", name = "Tint Health Background", desc = "Applies the target color to the normal health-bar background layer.", get = function() return CFG.enemyPlateTargetBackgroundTint ~= false end, set = function(_, v) CFG.enemyPlateTargetBackgroundTint = v and true or false; SaveRefresh() end },
                            targetGlow = { order = 4, type = "toggle", name = "Outer Background Glow", desc = "Shows the built-in stretched radial glow texture behind the health bar.", get = function() return CFG.enemyPlateTargetGlowEnabled ~= false end, set = function(_, v) CFG.enemyPlateTargetGlowEnabled = v and true or false; SaveRefresh() end },
                        },
                    },
                    hover = {
                        order = 25,
                        type = "group",
                        name = BrandLabel("Hover"),
                        guiInline = true,
                        args = {
                            hoverHighlight = { order = 1, type = "toggle", name = "Hover Highlight", desc = "Shows a simple overlay on the health bar while mousing over the unit.", get = function() return CFG.enemyPlateHoverHighlightEnabled ~= false end, set = function(_, v) CFG.enemyPlateHoverHighlightEnabled = v and true or false; SaveRefresh() end },
                            hoverColor = EnemyColorOption(2, "Hover Highlight Color", "enemyPlateHoverColor", 1, 1, 1, 0.18),
                        },
                    },
                    lowHealth = {
                        order = 30,
                        type = "group",
                        name = BrandLabel("Low Health"),
                        guiInline = true,
                        args = {
                            enabled = { order = 1, type = "toggle", name = "Use Low Health State", get = function() return CFG.enemyPlateLowHealthEnabled ~= false end, set = function(_, v) CFG.enemyPlateLowHealthEnabled = v and true or false; SaveRefresh() end },
                            threshold = { order = 2, type = "range", name = "Low Health Threshold", min = 0.01, max = 0.95, step = 0.01, isPercent = true, get = function() return CFG.enemyPlateLowHealthThreshold or 0.15 end, set = function(_, v) CFG.enemyPlateLowHealthThreshold = v; SaveRefresh() end },
                            low = EnemyColorOption(3, "Low Health Color", "enemyPlateLowHealth", 0.71764705882353, 0.71764705882353, 0.2156862745098, 0.14117647058824, "ElvUI low-health alpha 36/255."),
                            half = EnemyColorOption(4, "Low Health Half Color", "enemyPlateLowHealthHalf", 0.57647058823529, 0.17254901960784, 0.17254901960784, 0.12549019607843, "ElvUI low-health-half alpha 32/255."),
                            lowBackground = { order = 5, type = "toggle", name = "Tint Health Background", desc = "Applies the low-health color to the normal health-bar background layer.", get = function() return CFG.enemyPlateLowHealthBackgroundTint ~= false end, set = function(_, v) CFG.enemyPlateLowHealthBackgroundTint = v and true or false; SaveRefresh() end },
                            lowGlow = { order = 6, type = "toggle", name = "Outer Background Glow", desc = "Adds a separate padded texture behind the health bar at low health.", get = function() return CFG.enemyPlateLowHealthGlowEnabled ~= false end, set = function(_, v) CFG.enemyPlateLowHealthGlowEnabled = v and true or false; SaveRefresh() end },
                        },
                    },
                },
            },

            cast = {
                order = 30,
                type = "group",
                name = BrandSection("Cast Bar"),
                args = {
                    show = { order = 1, type = "toggle", name = "Show Cast Bar", get = function() return CFG.enemyPlateShowCastbar ~= false end, set = function(_, v) CFG.enemyPlateShowCastbar = v and true or false; SaveRefresh() end },
                    matchHealthWidth = {
                        order = 2,
                        type = "toggle",
                        name = "Match Health Width",
                        desc = "Use the enemy health-bar width for the cast bar. Disable this to set an independent cast-bar width.",
                        get = function() return CFG.enemyPlateCastMatchHealthWidth ~= false end,
                        set = function(_, v) CFG.enemyPlateCastMatchHealthWidth = v and true or false; SaveRefresh() end,
                    },
                    width = {
                        order = 3,
                        type = "range",
                        name = "Width",
                        desc = "Independent cast-bar width. This is available when Match Health Width is disabled.",
                        min = 40,
                        max = 320,
                        step = 1,
                        disabled = function() return CFG.enemyPlateCastMatchHealthWidth ~= false end,
                        get = function() return CFG.enemyPlateCastWidth or CFG.enemyPlateWidth or 154 end,
                        set = function(_, v) CFG.enemyPlateCastWidth = v; SaveRefresh() end,
                    },
                    height = { order = 4, type = "range", name = "Height", min = 4, max = 24, step = 1, get = function() return CFG.enemyPlateCastHeight or 10 end, set = function(_, v) CFG.enemyPlateCastHeight = v; SaveRefresh() end },
                    textSize = { order = 5, type = "range", name = "Text Size", min = 6, max = 24, step = 1, get = function() return CFG.enemyPlateCastTextSize or 10 end, set = function(_, v) CFG.enemyPlateCastTextSize = v; SaveRefresh() end },
                    icon = { order = 6, type = "range", name = "Spell Icon Size", min = 12, max = 40, step = 1, get = function() return CFG.enemyPlateCastIconSize or 20 end, set = function(_, v) CFG.enemyPlateCastIconSize = v; SaveRefresh() end },
                    iconPosition = { order = 7, type = "select", name = "Spell Icon Position", values = ENEMY_CAST_ICON_POSITIONS, get = function() return CFG.enemyPlateCastIconPosition or "RIGHT" end, set = function(_, v) CFG.enemyPlateCastIconPosition = v; SaveRefresh() end },
                    iconX = { order = 8, type = "range", name = "Spell Icon X Offset", min = -80, max = 80, step = 1, get = function() return CFG.enemyPlateCastIconXOffset or 3 end, set = function(_, v) CFG.enemyPlateCastIconXOffset = v; SaveRefresh() end },
                    iconY = { order = 9, type = "range", name = "Spell Icon Y Offset", min = -80, max = 80, step = 1, get = function() return CFG.enemyPlateCastIconYOffset or 0 end, set = function(_, v) CFG.enemyPlateCastIconYOffset = v; SaveRefresh() end },
                    updateRate = { order = 10, type = "range", name = "Smooth Update Rate", min = 0, max = 0.05, step = 0.005, get = function() return CFG.enemyPlateCastUpdateRate or 0.01 end, set = function(_, v) CFG.enemyPlateCastUpdateRate = v; SaveRefresh() end },
                    interruptibleColor = { order = 20, type = "color", name = "Interruptible Color", get = function() return CFG.enemyPlateCastInterruptibleR or 1, CFG.enemyPlateCastInterruptibleG or 0.82, CFG.enemyPlateCastInterruptibleB or 0.05 end, set = function(_, r, g, b) CFG.enemyPlateCastInterruptibleR = r; CFG.enemyPlateCastInterruptibleG = g; CFG.enemyPlateCastInterruptibleB = b; SaveRefresh() end },
                    notInterruptibleColor = { order = 21, type = "color", name = "Uninterruptible Color", get = function() return CFG.enemyPlateCastNotInterruptibleR or 0.45, CFG.enemyPlateCastNotInterruptibleG or 0.45, CFG.enemyPlateCastNotInterruptibleB or 0.45 end, set = function(_, r, g, b) CFG.enemyPlateCastNotInterruptibleR = r; CFG.enemyPlateCastNotInterruptibleG = g; CFG.enemyPlateCastNotInterruptibleB = b; SaveRefresh() end },
                    targetPlayerColor = { order = 22, type = "color", name = "Targeting You Color", get = function() return CFG.enemyPlateCastTargetPlayerR or 1, CFG.enemyPlateCastTargetPlayerG or 0.12, CFG.enemyPlateCastTargetPlayerB or 0.08 end, set = function(_, r, g, b) CFG.enemyPlateCastTargetPlayerR = r; CFG.enemyPlateCastTargetPlayerG = g; CFG.enemyPlateCastTargetPlayerB = b; SaveRefresh() end },
                },
            },
            auras = {
                order = 40,
                type = "group",
                name = BrandSection("Auras"),
                childGroups = "tab",
                args = {
                    show = { order = 1, type = "toggle", name = "Show Auras", desc = "Shows the separate Buff, Debuff, and Custom aura displays. Each group has its own layout and Blizzard aura categories.", get = function() return CFG.enemyPlateShowAuras ~= false end, set = function(_, v) CFG.enemyPlateShowAuras = v and true or false; SaveRefresh() end },
                    buffs = {
                        order = 10,
                        type = "group",
                        name = "Buffs",
                        childGroups = "tree",
                        args = (function()
                            local args = EnemyAuraLayoutArgs("enemyPlateBuffAura", { size = 30, perRow = 5, rows = 1, spacing = 1, x = -2, y = 4, attachTo = "HEALTH", anchorPoint = "BOTTOMLEFT", attachPoint = "TOPLEFT", growX = "RIGHT", growY = "UP", align = "LEFT" })
                            args.enable = { order = 0, type = "toggle", name = "Enable Buffs", desc = "Shows helpful auras. With no category selected, BattleMender uses the broad helpful-aura category; selected categories combine to narrow the display. Major and External Defensive are helpful-aura categories.", width = "half", get = function() return CFG.enemyPlateShowBuffs ~= false end, set = function(_, v) CFG.enemyPlateShowBuffs = v and true or false; SaveRefresh() end }
                            args.targetOnly = { order = 0.5, type = "toggle", name = "Current Target Only", desc = "Show the Buff display group only on your current target.", width = "half", get = function() return CFG.enemyPlateBuffAurasTargetOnly == true end, set = function(_, v) CFG.enemyPlateBuffAurasTargetOnly = v and true or false; SaveRefresh() end }
                            args.filters = {
                                order = 1,
                                type = "group",
                                name = "Filters",
                                guiInline = true,
                                args = {
                                    general = {
                                        order = 10,
                                        type = "group",
                                        name = "General",
                                        guiInline = true,
                                        width = "half",
                                        args = {
                                            player = EnemyAuraToggle(1, "enemyPlateBuffUsePlayer", "Player", true, "Show buffs cast by the player, pet, or vehicle."),
                                            raidDispellable = EnemyAuraToggle(2, "enemyPlateBuffUseRaidDispellable", "Raid Dispellable", false, "Show buffs a member of your raid can dispel, purge, or steal."),
                                            dispellable = EnemyAuraToggle(3, "enemyPlateBuffUseDispellable", "Any Dispellable", false, "Show buffs with any dispel type, regardless of your raid's capabilities."),
                                            important = EnemyAuraToggle(4, "enemyPlateBuffUseImportant", "Important", false, "Show Blizzard's IMPORTANT helpful-aura category."),
                                            raidInCombat = EnemyAuraToggle(5, "enemyPlateBuffUseRaidInCombat", "Raid In Combat", false, "Show helpful auras Blizzard flags for raid frames while in combat."),
                                        },
                                    },
                                    player = {
                                        order = 20,
                                        type = "group",
                                        name = "Player",
                                        guiInline = true,
                                        width = "half",
                                        args = {
                                            raid = EnemyAuraToggle(1, "enemyPlateBuffPlayerRaid", "Raid", false),
                                            cancelable = EnemyAuraToggle(2, "enemyPlateBuffPlayerCancelable", "Is Cancelable", false),
                                            notCancelable = EnemyAuraToggle(3, "enemyPlateBuffPlayerNotCancelable", "Not Cancelable", false),
                                            bigDef = EnemyAuraToggle(4, "enemyPlateBuffPlayerBigDefensive", "Big Defensive", false),
                                            extDef = EnemyAuraToggle(5, "enemyPlateBuffPlayerExternalDefensive", "External Defensive", false),
                                            blockPerm = EnemyAuraToggle(6, "enemyPlateBuffPlayerBlockPermanent", "Block Permanent", false),
                                        },
                                    },
                                    others = {
                                        order = 30,
                                        type = "group",
                                        name = "Others",
                                        guiInline = true,
                                        width = "half",
                                        args = {
                                            raid = EnemyAuraToggle(1, "enemyPlateBuffOthersRaid", "Raid", false),
                                            cancelable = EnemyAuraToggle(2, "enemyPlateBuffOthersCancelable", "Is Cancelable", false),
                                            notCancelable = EnemyAuraToggle(3, "enemyPlateBuffOthersNotCancelable", "Not Cancelable", false),
                                            bigDef = EnemyAuraToggle(4, "enemyPlateBuffOthersBigDefensive", "Big Defensive", false),
                                            extDef = EnemyAuraToggle(5, "enemyPlateBuffOthersExternalDefensive", "External Defensive", false),
                                            blockPerm = EnemyAuraToggle(6, "enemyPlateBuffOthersBlockPermanent", "Block Permanent", false),
                                        },
                                    },
                                },
                            }
                            return args
                        end)(),
                    },
                    debuffs = {
                        order = 20,
                        type = "group",
                        name = "Debuffs",
                        childGroups = "tree",
                        args = (function()
                            local args = EnemyAuraLayoutArgs("enemyPlateDebuffAura", { size = 30, perRow = 5, rows = 1, spacing = 1, x = -2, y = -16, attachTo = "CAST", anchorPoint = "TOPLEFT", attachPoint = "BOTTOMLEFT", growX = "RIGHT", growY = "DOWN", align = "LEFT" })
                            args.enable = { order = 0, type = "toggle", name = "Enable Debuffs", desc = "Shows harmful auras. With no category selected, BattleMender uses the broad harmful-aura category; selected categories combine to narrow the display. Defensive categories are under Buffs.", width = "half", get = function() return CFG.enemyPlateShowDebuffs ~= false end, set = function(_, v) CFG.enemyPlateShowDebuffs = v and true or false; SaveRefresh() end }
                            args.targetOnly = { order = 0.5, type = "toggle", name = "Current Target Only", desc = "Show the Debuff display group only on your current target.", width = "half", get = function() return CFG.enemyPlateDebuffAurasTargetOnly == true end, set = function(_, v) CFG.enemyPlateDebuffAurasTargetOnly = v and true or false; SaveRefresh() end }
                            args.filters = {
                                order = 1,
                                type = "group",
                                name = "Filters",
                                guiInline = true,
                                args = {
                                    general = {
                                        order = 10,
                                        type = "group",
                                        name = "General",
                                        guiInline = true,
                                        width = "half",
                                        args = {
                                            player = EnemyAuraToggle(1, "enemyPlateDebuffUsePlayer", "Player", true, "Show debuffs cast by the player, pet, or vehicle."),
                                            raidDispellable = EnemyAuraToggle(2, "enemyPlateDebuffUseRaidDispellable", "Raid Dispellable", false, "Show debuffs a member of your raid can dispel."),
                                            dispellable = EnemyAuraToggle(3, "enemyPlateDebuffUseDispellable", "Any Dispellable", false, "Show debuffs with any dispel type, regardless of your raid's capabilities."),
                                        },
                                    },
                                    player = {
                                        order = 20,
                                        type = "group",
                                        name = "Player",
                                        guiInline = true,
                                        width = "half",
                                        args = {
                                            raid = EnemyAuraToggle(1, "enemyPlateDebuffPlayerRaid", "Raid", false),
                                            cc = EnemyAuraToggle(2, "enemyPlateDebuffPlayerCrowdControl", "Crowd Control", false),
                                            blockPerm = EnemyAuraToggle(3, "enemyPlateDebuffPlayerBlockPermanent", "Block Permanent", false),
                                        },
                                    },
                                    others = {
                                        order = 30,
                                        type = "group",
                                        name = "Others",
                                        guiInline = true,
                                        width = "half",
                                        args = {
                                            raid = EnemyAuraToggle(1, "enemyPlateDebuffOthersRaid", "Raid", false),
                                            cc = EnemyAuraToggle(2, "enemyPlateDebuffOthersCrowdControl", "Crowd Control", false),
                                            blockPerm = EnemyAuraToggle(3, "enemyPlateDebuffOthersBlockPermanent", "Block Permanent", false),
                                        },
                                    },
                                },
                            }
                            return args
                        end)(),
                    },
                    custom = {
                        order = 30,
                        type = "group",
                        name = "Custom",
                        args = (function()
                            local args = EnemyAuraLayoutArgs("enemyPlateCustomAura", { size = 16, perRow = 5, rows = 1, spacing = 2, x = 0, y = 2, attachTo = "HEALTH", anchorPoint = "BOTTOMLEFT", attachPoint = "TOPLEFT", growX = "RIGHT", growY = "UP", align = "LEFT" })
                            args.enable = { order = 0, type = "toggle", name = "Enable Custom Auras", desc = "Enables an independent aura display for selected enemy Buff and Debuff categories.", width = "quarter", get = function() return CFG.enemyPlateCustomAurasEnabled ~= false end, set = function(_, v) CFG.enemyPlateCustomAurasEnabled = v and true or false; SaveRefresh() end }
                            args.targetOnly = { order = 0.5, type = "toggle", name = "Current Target Only", desc = "Show the Custom aura display group only on your current target. Buff and Debuff groups are unaffected.", width = "quarter", get = function() return CFG.enemyPlateCustomAurasTargetOnly ~= false end, set = function(_, v) CFG.enemyPlateCustomAurasTargetOnly = v and true or false; SaveRefresh() end }
                            args.displayBuffs = {
                                order = 0.6,
                                type = "toggle",
                                name = "Display Enemy Buffs",
                                desc = "Shows helpful enemy auras in Custom. With no Buff category selected, BattleMender uses the broad helpful-aura category; selected categories narrow the display.",
                                width = "quarter",
                                get = function() return CFG.enemyPlateCustomShowBuffs == true end,
                                set = function(_, v)
                                    CFG.enemyPlateCustomShowBuffs = v and true or false
                                    SaveRefresh()
                                    RefreshAuraFilterVisibility()
                                end,
                            }
                            args.displayDebuffs = {
                                order = 0.7,
                                type = "toggle",
                                name = "Display Enemy Debuffs",
                                desc = "Shows harmful enemy auras in Custom. With no Debuff category selected, BattleMender uses the broad harmful-aura category; selected categories narrow the display.",
                                width = "quarter",
                                get = function() return CFG.enemyPlateCustomShowDebuffs == true end,
                                set = function(_, v)
                                    CFG.enemyPlateCustomShowDebuffs = v and true or false
                                    SaveRefresh()
                                    RefreshAuraFilterVisibility()
                                end,
                            }
                            local customFilterArgs = {
                                    buffs = {
                                        order = 1,
                                        type = "group",
                                        name = "Buffs",
                                        guiInline = true,
                                        width = "full",
                                        hidden = function() return CFG.enemyPlateCustomShowBuffs ~= true end,
                                        args = {
                                            general = {
                                                order = 1,
                                                type = "group",
                                                name = "General",
                                                guiInline = true,
                                                width = "full",
                                                args = {
                                                    player = EnemyAuraToggle(1, "enemyPlateCustomBuffUsePlayer", "Player", false),
                                                    raidDispellable = EnemyAuraToggle(2, "enemyPlateCustomBuffUseRaidDispellable", "Raid Dispellable", false),
                                                    dispellable = EnemyAuraToggle(3, "enemyPlateCustomBuffUseDispellable", "Any Dispellable", false),
                                                    important = EnemyAuraToggle(4, "enemyPlateCustomBuffUseImportant", "Important", false),
                                                    raidInCombat = EnemyAuraToggle(5, "enemyPlateCustomBuffUseRaidInCombat", "Raid In Combat", false),
                                                },
                                            },
                                            player = {
                                                order = 2,
                                                type = "group",
                                                name = "Player",
                                                guiInline = true,
                                                width = "full",
                                                args = {
                                                    raid = EnemyAuraToggle(1, "enemyPlateCustomBuffPlayerRaid", "Raid", false),
                                                    cancelable = EnemyAuraToggle(2, "enemyPlateCustomBuffPlayerCancelable", "Is Cancelable", false),
                                                    notCancelable = EnemyAuraToggle(3, "enemyPlateCustomBuffPlayerNotCancelable", "Not Cancelable", false),
                                                    bigDef = EnemyAuraToggle(4, "enemyPlateCustomBuffPlayerBigDefensive", "Big Defensive", false),
                                                    extDef = EnemyAuraToggle(5, "enemyPlateCustomBuffPlayerExternalDefensive", "External Defensive", false),
                                                    blockPerm = EnemyAuraToggle(6, "enemyPlateCustomBuffPlayerBlockPermanent", "Block Permanent", false),
                                                },
                                            },
                                            others = {
                                                order = 3,
                                                type = "group",
                                                name = "Others",
                                                guiInline = true,
                                                width = "full",
                                                args = {
                                                    raid = EnemyAuraToggle(1, "enemyPlateCustomBuffOthersRaid", "Raid", false),
                                                    cancelable = EnemyAuraToggle(2, "enemyPlateCustomBuffOthersCancelable", "Is Cancelable", false),
                                                    notCancelable = EnemyAuraToggle(3, "enemyPlateCustomBuffOthersNotCancelable", "Not Cancelable", false),
                                                    bigDef = EnemyAuraToggle(4, "enemyPlateCustomBuffOthersBigDefensive", "Big Defensive", false),
                                                    extDef = EnemyAuraToggle(5, "enemyPlateCustomBuffOthersExternalDefensive", "External Defensive", false),
                                                    blockPerm = EnemyAuraToggle(6, "enemyPlateCustomBuffOthersBlockPermanent", "Block Permanent", false),
                                                },
                                            },
                                        },
                                    },
                                    debuffs = {
                                        order = 2,
                                        type = "group",
                                        name = "Debuffs",
                                        guiInline = true,
                                        width = "full",
                                        hidden = function() return CFG.enemyPlateCustomShowDebuffs ~= true end,
                                        args = {
                                            general = {
                                                order = 1,
                                                type = "group",
                                                name = "General",
                                                guiInline = true,
                                                width = "full",
                                                args = {
                                                    player = EnemyAuraToggle(1, "enemyPlateCustomDebuffUsePlayer", "Player", false),
                                                    raidDispellable = EnemyAuraToggle(2, "enemyPlateCustomDebuffUseRaidDispellable", "Raid Dispellable", false),
                                                    dispellable = EnemyAuraToggle(3, "enemyPlateCustomDebuffUseDispellable", "Any Dispellable", false),
                                                },
                                            },
                                            player = {
                                                order = 2,
                                                type = "group",
                                                name = "Player",
                                                guiInline = true,
                                                width = "full",
                                                args = {
                                                    raid = EnemyAuraToggle(1, "enemyPlateCustomDebuffPlayerRaid", "Raid", false),
                                                    cc = EnemyAuraToggle(2, "enemyPlateCustomDebuffPlayerCrowdControl", "Crowd Control", false),
                                                    blockPerm = EnemyAuraToggle(3, "enemyPlateCustomDebuffPlayerBlockPermanent", "Block Permanent", false),
                                                },
                                            },
                                            others = {
                                                order = 3,
                                                type = "group",
                                                name = "Others",
                                                guiInline = true,
                                                width = "full",
                                                args = {
                                                    raid = EnemyAuraToggle(1, "enemyPlateCustomDebuffOthersRaid", "Raid", false),
                                                    cc = EnemyAuraToggle(2, "enemyPlateCustomDebuffOthersCrowdControl", "Crowd Control", false),
                                                    blockPerm = EnemyAuraToggle(3, "enemyPlateCustomDebuffOthersBlockPermanent", "Block Permanent", false),
                                                },
                                            },
                                        },
                                    },
                            }
                            -- The two display types have one concise top-row
                            -- switch each; their native category filters stay
                            -- grouped under their respective type below.
                            for key, option in pairs(customFilterArgs) do
                                args[key] = option
                            end
                            return args
                        end)(),
                    },
                },
            },
            portrait = {
                order = 45,
                type = "group",
                name = BrandSection("Portrait / PvP"),
                args = {
                    show = { order = 1, type = "toggle", name = "Show Portrait", get = function() return CFG.enemyPlatePortraitEnabled ~= false end, set = function(_, v) CFG.enemyPlatePortraitEnabled = v and true or false; SaveRefresh() end },
                    hideBG = { order = 2, type = "toggle", name = "Hide Portrait in Battlegrounds", get = function() return CFG.enemyPlatePortraitHideInBG ~= false end, set = function(_, v) CFG.enemyPlatePortraitHideInBG = v and true or false; SaveRefresh() end },
                    size = { order = 3, type = "range", name = "Portrait Size", min = 16, max = 72, step = 1, get = function() return CFG.enemyPlatePortraitSize or 36 end, set = function(_, v) CFG.enemyPlatePortraitSize = v; SaveRefresh() end },
                    position = { order = 4, type = "select", name = "Position", values = ENEMY_PORTRAIT_POSITIONS, get = function() return CFG.enemyPlatePortraitPosition or "LEFT" end, set = function(_, v) CFG.enemyPlatePortraitPosition = v; SaveRefresh() end },
                    x = { order = 5, type = "range", name = "X Offset", min = -100, max = 100, step = 1, get = function() return CFG.enemyPlatePortraitXOffset or 0 end, set = function(_, v) CFG.enemyPlatePortraitXOffset = v; SaveRefresh() end },
                    y = { order = 6, type = "range", name = "Y Offset", min = -100, max = 100, step = 1, get = function() return CFG.enemyPlatePortraitYOffset or 0 end, set = function(_, v) CFG.enemyPlatePortraitYOffset = v; SaveRefresh() end },
                    objective = { order = 7, type = "toggle", name = "Keep BG Objective Indicator", get = function() return CFG.enemyPlateObjectiveIndicator ~= false end, set = function(_, v) CFG.enemyPlateObjectiveIndicator = v and true or false; SaveRefresh() end },
                },
            },
        },
    }

    options.args.profileTransfer = {
        order = 89,
        type = "group",
        name = "Import / Export",
        args = {
            info = {
                order = 1,
                type = "description",
                width = "full",
                name = "Export copies the current profile settings into text. Import replaces the current profile with pasted BattleMender profile text. Import is blocked in combat.",
            },
            exportBox = {
                order = 10,
                type = "input",
                name = "Export Current Profile",
                desc = "Copy this text and send it to another BattleMender user.",
                width = "full",
                multiline = 14,
                get = function()
                    return BM.ExportProfile and BM.ExportProfile() or "Profile export is not available."
                end,
                set = function() end,
            },
            importBox = {
                order = 20,
                type = "input",
                name = "Import Profile Text",
                desc = "Paste exported BattleMender profile text here, then press Import Profile below.",
                width = "full",
                multiline = 14,
                get = function()
                    return BM.ProfileImportText or ""
                end,
                set = function(_, value)
                    BM.ProfileImportText = value or ""
                end,
            },
            importProfile = {
                order = 30,
                type = "execute",
                name = "Import Profile",
                desc = "Replace the current profile with the pasted settings.",
                confirm = true,
                confirmText = "Replace your current BattleMender profile with the pasted settings?",
                func = function()
                    if not BM.ImportProfile then
                        print("|cff33ff99BattleMender:|r profile import is not available.")
                        return
                    end

                    local ok, message = BM.ImportProfile(BM.ProfileImportText or "")
                    if ok then
                        BM.ProfileImportText = ""
                        print("|cff33ff99BattleMender:|r " .. (message or "profile imported."))
                    else
                        print("|cff33ff99BattleMender:|r |cffff5555Import failed:|r " .. (message or "unknown error."))
                    end
                end,
            },
        },
    }

    if BM.DB and AceDBOptions then
        local profiles = AceDBOptions:GetOptionsTable(BM.DB)
        profiles.order = 90
        profiles.name = "Profiles"
        options.args.profiles = profiles
    else
        options.args.profiles = {
            order = 90,
            type = "group",
            name = "Profiles",
            args = {
                unavailable = {
                    order = 1,
                    type = "description",
                    name = "Profile support requires AceDB-3.0 and AceDBOptions-3.0 from the full Ace3 package.",
                },
            },
        }
    end



    -------------------------------------------------
    -- v24 menu organization pass
    -------------------------------------------------
    do
        local general = options.args.general
        local normal = options.args.normal
        local effects = options.args.effects
        local enemy = options.args.enemyPlates

        -------------------------------------------------
        -- Friendly visual page: accessible without Developer Mode
        -------------------------------------------------
        if normal then
            normal.order = 2
            normal.name = "Friendly Plates"
            normal.disabled = nil
            normal.childGroups = "tree"
            if normal.args then
                normal.args.locked = nil

                if normal.args.spec then
                    normal.args.spec.order = 10
                    normal.args.spec.name = BrandSection("Spec Icon")
                    normal.args.spec.guiInline = true
                end

                if normal.args.ring then
                    normal.args.ring.order = 20
                    normal.args.ring.name = BrandSection("Border")
                    normal.args.ring.guiInline = true
                    if normal.args.ring.args then
                        if normal.args.ring.args.ringEnabled then normal.args.ring.args.ringEnabled.name = "Enable Border" end
                        if normal.args.ring.args.ringTexture then normal.args.ring.args.ringTexture.name = "Border Style" end
                        if normal.args.ring.args.ringScale then normal.args.ring.args.ringScale.name = "Border Size" end
                        if normal.args.ring.args.ringAlpha then normal.args.ring.args.ringAlpha.name = "Border Opacity" end
                    end
                end

                if normal.args.accentOverlay then
                    normal.args.accentOverlay.order = 30
                    normal.args.accentOverlay.name = BrandSection("Glass Panel")
                    normal.args.accentOverlay.guiInline = true
                    if normal.args.accentOverlay.args then
                        if normal.args.accentOverlay.args.accentOverlayEnabled then normal.args.accentOverlay.args.accentOverlayEnabled.name = "Enable Glass Panel" end
                        if normal.args.accentOverlay.args.accentOverlayTexture then normal.args.accentOverlay.args.accentOverlayTexture.name = "Panel Texture" end
                        if normal.args.accentOverlay.args.accentOverlayScale then normal.args.accentOverlay.args.accentOverlayScale.name = "Panel Scale" end
                        if normal.args.accentOverlay.args.accentOverlayAlpha then normal.args.accentOverlay.args.accentOverlayAlpha.name = BrandLabel("Panel Alpha") end
                        if normal.args.accentOverlay.args.accentOverlayBlendMode then normal.args.accentOverlay.args.accentOverlayBlendMode.name = "Panel Blend" end
                    end
                end

                if normal.args.damaged then normal.args.damaged.order = 40 end
                if normal.args.health then normal.args.health.order = 50 end
            end
        end

        -------------------------------------------------
        -- Effects page: accessible and separated vertically via tree sections
        -------------------------------------------------
        if effects then
            effects.order = 3
            effects.disabled = nil
            effects.childGroups = "tree"
            effects.args = effects.args or {}
            effects.args.locked = nil

            if effects.args.hoverGroup then
                effects.args.hoverGroup.order = 10
                effects.args.hoverGroup.name = BrandSection("Spec / Border Hover")
                effects.args.hoverGroup.guiInline = true
                effects.args.hoverGroup.width = "full"
                if effects.args.hoverGroup.args then
                    if effects.args.hoverGroup.args.ringGlowEnabled then effects.args.hoverGroup.args.ringGlowEnabled.name = "Border Glow" end
                    if effects.args.hoverGroup.args.ringGlowBrightness then effects.args.hoverGroup.args.ringGlowBrightness.name = "Border Glow Brightness" end
                    if effects.args.hoverGroup.args.ringGlowFadeIn then effects.args.hoverGroup.args.ringGlowFadeIn.name = "Border Glow Fade In" end
                    if effects.args.hoverGroup.args.ringGlowFadeOut then effects.args.hoverGroup.args.ringGlowFadeOut.name = "Border Glow Fade Out" end
                    effects.args.hoverGroup.args.pulseEnable = nil
                end
            end

            if normal and normal.args then
                local pulse = normal.args.pulse
                if pulse then
                    normal.args.pulse = nil
                    pulse.order = 20
                    pulse.name = BrandSection("Pulse")
                    pulse.guiInline = true
                    pulse.width = "full"
                    effects.args.pulse = pulse
                end

                local glass = normal.args.accentOverlay
                local glassArgs = glass and glass.args
                if glassArgs then
                    local hover = {
                        order = 30,
                        type = "group",
                        name = BrandSection("Glass Panel Hover"),
                        guiInline = true,
                        width = "full",
                        args = {},
                    }

                    local function move(key, order, name)
                        local item = glassArgs[key]
                        if item then
                            glassArgs[key] = nil
                            item.order = order
                            if name then item.name = name end
                            hover.args[key] = item
                        end
                    end

                    move("accentOverlayGlowEnabled", 1, "Enable Glass Hover Glow")
                    move("accentOverlayGlowBrightness", 2, "Glass Hover Brightness")
                    move("accentOverlayGlowFadeIn", 3, "Glass Hover Fade In")
                    move("accentOverlayGlowFadeOut", 4, "Glass Hover Fade Out")

                    effects.args.glassPanelHover = hover
                end
            end
        end

        -------------------------------------------------
        -- Blizzard CVars get their own top-level page
        -------------------------------------------------
        local blizzard = general and general.args and general.args.blizzardCVars
        local clickthrough
        if blizzard then
            general.args.blizzardCVars = nil
            blizzard.order = 6
            blizzard.name = "Blizzard CVars"
            blizzard.guiInline = nil
            blizzard.childGroups = "tree"
            if blizzard.args then
                clickthrough = blizzard.args.clickthrough
                blizzard.args.clickthrough = nil
            end
            options.args.blizzardCVars = blizzard
        end

        -------------------------------------------------
        -- Compatibility page for ElvUI / other addon interaction
        -------------------------------------------------
        local generalGroup = general and general.args and general.args.generalGroup
        local repairToggle = generalGroup and generalGroup.args and generalGroup.args.repairElvUIDisabledNameplates
        local repairNow = generalGroup and generalGroup.args and generalGroup.args.runElvUIRepair
        local disableWarning = generalGroup and generalGroup.args and generalGroup.args.disableElvUIWarning
        local enemyAutoDisable = enemy and enemy.args and enemy.args.autoDisable

        if general and general.args then
            general.args.status = nil
            general.args.quickEffects = nil
        end

        if generalGroup and generalGroup.args then
            generalGroup.args.repairElvUIDisabledNameplates = nil
            generalGroup.args.runElvUIRepair = nil
            generalGroup.args.disableElvUIWarning = nil
        end

        if enemy and enemy.args then
            enemy.args.autoDisable = nil
        end

        if repairToggle then repairToggle.order = 10; repairToggle.hidden = nil end
        if repairNow then repairNow.order = 20; repairNow.hidden = nil end
        if disableWarning then disableWarning.order = 30; disableWarning.hidden = nil end
        if clickthrough then clickthrough.order = 30; clickthrough.name = BrandSection("ElvUI Clickthrough"); clickthrough.guiInline = true end
        if enemyAutoDisable then enemyAutoDisable.order = 40; enemyAutoDisable.name = "Auto-disable Enemy Plates with ElvUI / Plater" end

        options.args.compatibility = {
            order = 7,
            type = "group",
            name = "Compatibility",
            childGroups = "tree",
            args = {
                status = {
                    order = 1,
                    type = "description",
                    width = "full",
                    fontSize = "medium",
                    name = GetElvUIStatusText,
                },
                elvui = {
                    order = 10,
                    type = "group",
                    name = BrandSection("ElvUI"),
                    guiInline = true,
                    args = {
                        repair = repairToggle,
                        run = repairNow,
                        warning = disableWarning,
                    },
                },
                nameplateAddons = {
                    order = 20,
                    type = "group",
                    name = BrandSection("Nameplate Addons"),
                    guiInline = true,
                    args = {
                        autoDisable = enemyAutoDisable,
                    },
                },
                clickthrough = clickthrough,
            },
        }

        -------------------------------------------------
        -- Enemy plates are experimental: opt-in in defaults, still visible in UI
        -------------------------------------------------
        if enemy then
            enemy.order = 5
            if enemy.args and enemy.args.enabled then
                enemy.args.enabled.name = "Enable Custom Enemy Plates"
                enemy.args.enabled.desc = "Uses BattleMender custom enemy nameplates when no active ElvUI or Plater enemy nameplate provider is detected."
            end
        end

        -------------------------------------------------
        -- General page is now only core behavior/sizing/reset.
        -------------------------------------------------
        if general then
            general.order = 1
            general.name = "General"
        end
    end



    -------------------------------------------------
    -- v26 options polish / safer public defaults
    -------------------------------------------------
    do
        local normal = options.args.normal
        local effects = options.args.effects
        local enemy = options.args.enemyPlates

        -------------------------------------------------
        -- Friendly Plates: keep core controls public, grey advanced internals
        -- unless Developer Mode is enabled.
        -------------------------------------------------
        if normal and normal.args then
            if normal.args.spec and normal.args.spec.args then
                if normal.args.spec.args.specIconAlpha then
                    normal.args.spec.args.specIconAlpha.disabled = DisabledUnlessDeveloper
                    normal.args.spec.args.specIconAlpha.desc = "Advanced visual tuning. Enable Developer Mode on the General page to edit."
                end
                if normal.args.spec.args.specIconBlendMode then
                    normal.args.spec.args.specIconBlendMode.disabled = DisabledUnlessDeveloper
                    normal.args.spec.args.specIconBlendMode.desc = "Advanced visual tuning. Enable Developer Mode on the General page to edit."
                end
            end

            if normal.args.damaged then
                normal.args.damaged.disabled = DisabledUnlessDeveloper
                normal.args.damaged.desc = "Advanced missing-health/spec layering controls. Enable Developer Mode on the General page to edit."
            end

            if normal.args.health then
                normal.args.health.disabled = DisabledUnlessDeveloper
                normal.args.health.desc = "Advanced health-overlay controls. Enable Developer Mode on the General page to edit."
            end
        end

        -------------------------------------------------
        -- Effects: split the wide inline blocks into readable vertical rows.
        -------------------------------------------------
        if effects and effects.args and effects.args.hoverGroup and effects.args.hoverGroup.args then
            local hover = effects.args.hoverGroup
            local old = hover.args

            local function take(key)
                local item = old[key]
                old[key] = nil
                return item
            end

            local function group(order, name, args)
                return {
                    order = order,
                    type = "group",
                    name = BrandSection(name),
                    guiInline = true,
                    args = args,
                }
            end

            local specArgs = {}
            local borderArgs = {}
            local haloArgs = {}

            specArgs.specGlowEnabled = take("specGlowEnabled")
            specArgs.specGlowBrightness = take("specGlowBrightness")
            specArgs.specGlowFadeIn = take("specGlowFadeIn")
            specArgs.specGlowFadeOut = take("specGlowFadeOut")

            borderArgs.ringGlowEnabled = take("ringGlowEnabled")
            borderArgs.ringGlowBrightness = take("ringGlowBrightness")
            borderArgs.ringGlowFadeIn = take("ringGlowFadeIn")
            borderArgs.ringGlowFadeOut = take("ringGlowFadeOut")

            haloArgs.haloEnabled = take("haloEnabled")
            haloArgs.haloGlowSizeScale = take("haloGlowSizeScale")
            haloArgs.haloGlowAlpha = take("haloGlowAlpha")

            if specArgs.specGlowEnabled then specArgs.specGlowEnabled.order = 1; specArgs.specGlowEnabled.width = "full" end
            if specArgs.specGlowBrightness then specArgs.specGlowBrightness.order = 2 end
            if specArgs.specGlowFadeIn then specArgs.specGlowFadeIn.order = 3 end
            if specArgs.specGlowFadeOut then specArgs.specGlowFadeOut.order = 4 end

            if borderArgs.ringGlowEnabled then borderArgs.ringGlowEnabled.order = 1; borderArgs.ringGlowEnabled.width = "full" end
            if borderArgs.ringGlowBrightness then borderArgs.ringGlowBrightness.order = 2 end
            if borderArgs.ringGlowFadeIn then borderArgs.ringGlowFadeIn.order = 3 end
            if borderArgs.ringGlowFadeOut then borderArgs.ringGlowFadeOut.order = 4 end

            if haloArgs.haloEnabled then haloArgs.haloEnabled.order = 1; haloArgs.haloEnabled.width = "full" end
            if haloArgs.haloGlowSizeScale then haloArgs.haloGlowSizeScale.order = 2 end
            if haloArgs.haloGlowAlpha then haloArgs.haloGlowAlpha.order = 3 end

            hover.guiInline = nil
            hover.childGroups = "tree"
            hover.args = {
                specIconGlow = group(10, "Spec Icon Glow", specArgs),
                borderGlow = group(20, "Border Glow", borderArgs),
                hoverHalo = group(30, "Hover Halo", haloArgs),
            }
        end

        if effects and effects.args and effects.args.pulse and effects.args.pulse.args then
            local pulse = effects.args.pulse
            local old = pulse.args

            local function take(key)
                local item = old[key]
                old[key] = nil
                return item
            end

            local coreArgs = {}
            local overlayArgs = {}

            coreArgs.pulseEnable = take("pulseEnable")
            coreArgs.pulseSpeed = take("pulseSpeed")
            coreArgs.pulseIntensity = take("pulseIntensity")

            overlayArgs.pulseOverlayEnable = take("pulseOverlayEnable")
            overlayArgs.pulseOverlayTexture = take("pulseOverlayTexture")
            overlayArgs.pulseOverlayAlpha = take("pulseOverlayAlpha")
            overlayArgs.pulseOverlayBlend = take("pulseOverlayBlend")

            if coreArgs.pulseEnable then coreArgs.pulseEnable.order = 1; coreArgs.pulseEnable.width = "full" end
            if coreArgs.pulseSpeed then coreArgs.pulseSpeed.order = 2 end
            if coreArgs.pulseIntensity then coreArgs.pulseIntensity.order = 3 end

            if overlayArgs.pulseOverlayEnable then overlayArgs.pulseOverlayEnable.order = 1; overlayArgs.pulseOverlayEnable.width = "full" end
            if overlayArgs.pulseOverlayTexture then overlayArgs.pulseOverlayTexture.order = 2 end
            if overlayArgs.pulseOverlayAlpha then overlayArgs.pulseOverlayAlpha.order = 3 end
            if overlayArgs.pulseOverlayBlend then overlayArgs.pulseOverlayBlend.order = 4 end

            pulse.guiInline = nil
            pulse.childGroups = "tree"
            pulse.args = {
                pulseCore = {
                    order = 10,
                    type = "group",
                    name = BrandSection("Pulse"),
                    guiInline = true,
                    args = coreArgs,
                },
                pulseOverlay = {
                    order = 20,
                    type = "group",
                    name = BrandSection("Pulse Overlay"),
                    guiInline = true,
                    args = overlayArgs,
                },
            }
        end

        -------------------------------------------------
        -- Enemy Health / Layout: move name settings to their own row/group.
        -------------------------------------------------
        if enemy and enemy.args and enemy.args.layout and enemy.args.layout.args then
            local layout = enemy.args.layout
            local old = layout.args

            local function take(key)
                local item = old[key]
                old[key] = nil
                return item
            end

            local healthArgs = {
                width = take("width"),
                healthHeight = take("healthHeight"),
                scale = take("scale"),
                classColorHealth = take("classColorHealth"),
                classificationColors = take("classificationColors"),
            }

            local nameArgs = {
                showName = take("showName"),
                hidePlayerNamesInPvP = take("hidePlayerNamesInPvP"),
                nameSize = take("nameSize"),
                namePosition = take("namePosition"),
                nameX = take("nameX"),
                nameY = take("nameY"),
                classColorNames = take("classColorNames"),
            }

            if healthArgs.width then healthArgs.width.order = 1 end
            if healthArgs.healthHeight then healthArgs.healthHeight.order = 2 end
            if healthArgs.scale then healthArgs.scale.order = 3 end
            if healthArgs.classColorHealth then healthArgs.classColorHealth.order = 10; healthArgs.classColorHealth.width = "full" end
            if healthArgs.classificationColors then healthArgs.classificationColors.order = 11; healthArgs.classificationColors.width = "full" end

            if nameArgs.showName then nameArgs.showName.order = 1; nameArgs.showName.width = "full" end
            if nameArgs.hidePlayerNamesInPvP then nameArgs.hidePlayerNamesInPvP.order = 2; nameArgs.hidePlayerNamesInPvP.width = "full" end
            if nameArgs.nameSize then nameArgs.nameSize.order = 3 end
            if nameArgs.namePosition then nameArgs.namePosition.order = 4 end
            if nameArgs.nameX then nameArgs.nameX.order = 5 end
            if nameArgs.nameY then nameArgs.nameY.order = 6 end
            if nameArgs.classColorNames then nameArgs.classColorNames.order = 10; nameArgs.classColorNames.width = "full" end

            layout.guiInline = nil
            layout.childGroups = "tree"
            layout.args = {
                healthShape = {
                    order = 10,
                    type = "group",
                    name = BrandSection("Health Bar"),
                    guiInline = true,
                    args = healthArgs,
                },
                nameText = {
                    order = 20,
                    type = "group",
                    name = BrandSection("Name Text"),
                    guiInline = true,
                    args = nameArgs,
                },
            }
        end

        -------------------------------------------------
        -- Friendly Plates test mode: BattleMender-owned preview for health/missing-health layering.
        -------------------------------------------------
        if normal and normal.args then
            normal.args.testMode = {
                order = 5,
                type = "group",
                name = BrandSection("Test Mode"),
                guiInline = true,
                args = {
                    info = {
                        order = 1,
                        type = "description",
                        width = "full",
                        name = "Creates a non-secure BattleMender preview plate so you can tune missing-health fill, damaged spec icon, border, and glass panel visuals without needing another player nearby.",
                    },
                    friendlyTestMode = {
                        order = 10,
                        type = "toggle",
                        name = "Enable Friendly Plate Test Mode",
                        width = "full",
                        get = function() return CFG.friendlyTestMode == true end,
                        set = function(_, v) CFG.friendlyTestMode = v and true or false; SaveRefresh() end,
                    },
                    friendlyTestHealthPercent = {
                        order = 20,
                        type = "range",
                        name = "Health %",
                        min = 0, max = 100, step = 1,
                        get = function() return CFG.friendlyTestHealthPercent or 55 end,
                        set = function(_, v) CFG.friendlyTestHealthPercent = v; SaveRefresh() end,
                    },
                    friendlyTestLOS = {
                        order = 25,
                        type = "toggle",
                        name = "Preview LoS/Faded State",
                        get = function() return CFG.friendlyTestLOS == true end,
                        set = function(_, v) CFG.friendlyTestLOS = v and true or false; SaveRefresh() end,
                    },
                    friendlyTestSpecID = {
                        order = 30,
                        type = "input",
                        name = "Spec Texture ID",
                        desc = "Uses Textures\\Specs\\<id>.tga. Default 1467 is Devastation Evoker.",
                        get = function() return tostring(CFG.friendlyTestSpecID or 1467) end,
                        set = function(_, v) CFG.friendlyTestSpecID = tonumber(v) or 1467; SaveRefresh() end,
                    },
                    friendlyTestClass = {
                        order = 35,
                        type = "select",
                        name = "Preview Class Color",
                        values = FRIENDLY_TEST_CLASSES,
                        get = function() return CFG.friendlyTestClass or "EVOKER" end,
                        set = function(_, v) CFG.friendlyTestClass = v or "EVOKER"; SaveRefresh() end,
                    },
                    position = {
                        order = 40,
                        type = "group",
                        name = BrandLabel("Preview Position"),
                        guiInline = true,
                        args = {
                            friendlyTestAnchorPoint = {
                                order = 1, type = "select", name = "Anchor", values = ANCHOR_POINTS,
                                get = function() return CFG.friendlyTestAnchorPoint or "CENTER" end,
                                set = function(_, v) CFG.friendlyTestAnchorPoint = v; SaveRefresh() end,
                            },
                            friendlyTestXOffset = {
                                order = 2, type = "range", name = "X Offset", min = -600, max = 600, step = 1,
                                get = function() return CFG.friendlyTestXOffset or 0 end,
                                set = function(_, v) CFG.friendlyTestXOffset = v; SaveRefresh() end,
                            },
                            friendlyTestYOffset = {
                                order = 3, type = "range", name = "Y Offset", min = -400, max = 400, step = 1,
                                get = function() return CFG.friendlyTestYOffset or 120 end,
                                set = function(_, v) CFG.friendlyTestYOffset = v; SaveRefresh() end,
                            },
                        },
                    },
                },
            }
        end

        -------------------------------------------------
        -- Enemy plates now default enabled; auto-disable keeps them out of the
        -- way when an active enemy nameplate provider is present.
        -------------------------------------------------
        if enemy and enemy.args and enemy.args.enabled then
            enemy.args.enabled.desc = "Default-on fallback for users without active ElvUI or Plater enemy nameplates. Auto-disable keeps BattleMender out of the way when those providers are active."
        end
    end



    -------------------------------------------------
    -- v28 effects navigation / custom aura presentation polish
    -------------------------------------------------
    do
        local effects = options.args.effects
        local enemy = options.args.enemyPlates

        if effects and effects.args then
            effects.childGroups = "tab"

            local hover = effects.args.hoverGroup
            if hover then
                hover.name = "Hover"
                hover.guiInline = nil
                hover.childGroups = "tab"
                hover.order = 10
                hover.args = hover.args or {}

                local glass = effects.args.glassPanelHover
                if glass then
                    effects.args.glassPanelHover = nil
                    glass.order = 30
                    glass.name = BrandSection("Glass Panel Hover")
                    glass.guiInline = true
                    hover.args.glassPanelHover = glass
                end

                if hover.args.specIconGlow then
                    hover.args.specIconGlow.order = 10
                    hover.args.specIconGlow.name = BrandSection("Icon Hover")
                end
                if hover.args.borderGlow then
                    hover.args.borderGlow.order = 20
                    hover.args.borderGlow.name = BrandSection("Border Hover")
                end
                if hover.args.glassPanelHover then
                    hover.args.glassPanelHover.order = 30
                    hover.args.glassPanelHover.name = BrandSection("Glass Panel Hover")
                end
                if hover.args.hoverHalo then
                    hover.args.hoverHalo.order = 40
                    hover.args.hoverHalo.name = BrandSection("Hover Halo")
                end
            end

            if effects.args.pulse then
                effects.args.pulse.order = 20
                effects.args.pulse.name = "Pulse"
                effects.args.pulse.guiInline = nil
                effects.args.pulse.childGroups = "tab"
            end
        end

        if enemy and enemy.args and enemy.args.auras and enemy.args.auras.args then
            local custom = enemy.args.auras.args.custom
            local customArgs = custom and custom.args
            if customArgs and customArgs.style and customArgs.style.args then
                customArgs.style.args.flatCustom = {
                    order = 3,
                    type = "toggle",
                    name = "Flat 2/3-height Icons",
                    desc = "Draw Custom auras as wide, shallow icons cropped from the middle of the source icon. Useful for compact personal rotation debuffs.",
                    width = "full",
                    get = function() return CFG.enemyPlateCustomAuraFlat ~= false end,
                    set = function(_, v) CFG.enemyPlateCustomAuraFlat = v and true or false; SaveRefresh() end,
                }
            end
        end
    end



    -------------------------------------------------
    -- v82 live-release menu source cleanup
    -------------------------------------------------
    do
        local general = options.args.general
        local normal = options.args.normal
        local effects = options.args.effects
        local los = options.args.los
        local enemy = options.args.enemyPlates

        local function NotifyOptionsChanged()
            if not LibStub then return end
            local registry = LibStub("AceConfigRegistry-3.0", true)
            if registry and registry.NotifyChange then
                pcall(registry.NotifyChange, registry, APP_NAME)
            end
        end

        -------------------------------------------------
        -- General: keep only release-facing controls.
        -------------------------------------------------
        local friendlySizing
        if general and general.args then
            friendlySizing = general.args.layoutGroup
            general.args.layoutGroup = nil
            general.args.contextScaling = nil

            local generalSettings = general.args.generalGroup and general.args.generalGroup.args
            if generalSettings then
                generalSettings.debug = nil
                generalSettings.debugClickbox = nil
            end

            if general.args.developerMode then
                general.args.developerMode.desc = "Unlocks advanced Friendly Health and Test Mode controls."
                general.args.developerMode.set = function(_, v)
                    CFG.developerMode = v and true or false
                    SaveRefresh()
                    NotifyOptionsChanged()
                end
            end
        end

        -------------------------------------------------
        -- Lock Visual Scale belongs with Blizzard scaling, not friendly sizing.
        -------------------------------------------------
        local blizzard = options.args.blizzardCVars
        local scalingArgs = blizzard and blizzard.args and blizzard.args.scaling and blizzard.args.scaling.args
        local sizingArgs = friendlySizing and friendlySizing.args
        if scalingArgs and sizingArgs and sizingArgs.friendlyVisualScaleLock then
            local option = sizingArgs.friendlyVisualScaleLock
            sizingArgs.friendlyVisualScaleLock = nil
            option.order = 4
            option.width = "full"
            option.desc = "Keeps BattleMender friendly spec visuals at the configured Icon Size instead of following Blizzard Min/Max/Selected Scale. The native clickbox is unchanged."
            scalingArgs.friendlyVisualScaleLock = option
        end

        -------------------------------------------------
        -- Friendly Plates: horizontal release-facing navigation.
        -------------------------------------------------
        if normal and normal.args then
            local old = normal.args
            local appearanceArgs = {}
            local healthArgs = {}

            if friendlySizing then
                friendlySizing.order = 5
                friendlySizing.name = BrandSection("Sizing & Positioning")
                friendlySizing.guiInline = true
                appearanceArgs.sizing = friendlySizing
            end

            for _, key in ipairs({ "spec", "ring", "accentOverlay" }) do
                if old[key] then
                    appearanceArgs[key] = old[key]
                    old[key] = nil
                end
            end

            for _, key in ipairs({ "damaged", "health" }) do
                if old[key] then
                    local item = old[key]
                    old[key] = nil
                    -- The whole Health tab is developer-only, so do not stack
                    -- separate disabled functions on its child groups.
                    item.disabled = nil
                    healthArgs[key] = item
                end
            end

            local testMode = old.testMode
            old.testMode = nil
            old.locked = nil

            -- Preserve any future friendly appearance groups not explicitly
            -- named above rather than dropping them during the restructure.
            for key, item in pairs(old) do
                appearanceArgs[key] = item
            end

            options.args.effects = nil
            options.args.los = nil

            normal.order = 2
            normal.name = "Friendly Plates"
            normal.disabled = nil
            normal.childGroups = "tab"
            normal.args = {
                appearance = {
                    order = 10,
                    type = "group",
                    name = "Appearance",
                    childGroups = "tree",
                    args = appearanceArgs,
                },
                health = {
                    order = 20,
                    type = "group",
                    name = "Health",
                    desc = "Advanced missing-health texture, blend, and layer controls. Enable Developer Mode on the General tab to edit.",
                    disabled = DisabledUnlessDeveloper,
                    childGroups = "tree",
                    args = healthArgs,
                },
            }

            if effects then
                effects.order = 30
                effects.name = "Effects"
                effects.disabled = nil
                effects.args = effects.args or {}
                effects.args.locked = nil
                normal.args.effects = effects
            end

            if los then
                los.order = 40
                los.name = "Line of Sight"
                normal.args.los = los
            end

            -- A dedicated defensives page may be supplied by another current
            -- BattleMender source file. Fold it in when it is already part of
            -- the generated options table.
            local defensiveKey
            for _, key in ipairs({ "defensives", "friendlyDefensives", "defensive" }) do
                if options.args[key] then
                    defensiveKey = key
                    break
                end
            end
            if defensiveKey then
                local defensives = options.args[defensiveKey]
                options.args[defensiveKey] = nil
                defensives.order = 50
                defensives.name = "Defensives"
                normal.args.defensives = defensives
            end

            if testMode then
                testMode.order = 90
                testMode.name = "Test Mode"
                testMode.guiInline = nil
                testMode.hidden = nil
                testMode.disabled = DisabledUnlessDeveloper
                testMode.desc = "Developer preview controls. Enable Developer Mode on the General tab to edit."
                normal.args.testMode = testMode
            end
        end

    end



    -------------------------------------------------
    -- v87 target presentation / release-default preparation
    -------------------------------------------------
    do
        local enemy = options.args.enemyPlates
        local enemyArgs = enemy and enemy.args

        if enemyArgs then
            local colors = enemyArgs.colors
            local textures = enemyArgs.textures

            -------------------------------------------------
            -- Dedicated Target tab. Target-specific presentation no longer
            -- lives inside the generic Colors / Highlights page.
            -------------------------------------------------
            local targetHighlight = colors and colors.args and colors.args.target
            if colors and colors.args then
                colors.args.target = nil
                -- The outer glow art is now a built-in BattleMender asset.
                -- Remove the old custom path / padding controls.
                colors.args.glow = nil
                if colors.args.info then
                    colors.args.info.name = "Enemy reaction, classification, hover, and low-health colors. Current-target presentation has its own Target tab."
                end
                local lowHealth = colors.args.lowHealth and colors.args.lowHealth.args
                if lowHealth and lowHealth.lowGlow then
                    lowHealth.lowGlow.desc = "Uses BattleMender's built-in outer glow texture behind the health bar at low health."
                end
            end

            local targetTexture = textures and textures.args and textures.args.targetTexture
            if textures and textures.args then
                textures.args.targetTexture = nil
            end

            if targetHighlight then
                targetHighlight.order = 20
                targetHighlight.name = BrandSection("Highlight")
                targetHighlight.guiInline = true
                targetHighlight.args = targetHighlight.args or {}

                if targetHighlight.args.targetGlow then
                    targetHighlight.args.targetGlow.desc = "Uses BattleMender's built-in Media\\Bars\\outer_glow.tga texture behind the current target health bar."
                end

                local borderColor = EnemyColorOption(
                    5,
                    "Target Border Color",
                    "enemyPlateTargetBorder",
                    1, 1, 1, 1,
                    "Overrides the health-bar border color for the current target only. Other enemy element borders keep the shared border color."
                )
                borderColor.disabled = function() return CFG.enemyPlateTargetHighlightEnabled == false end
                targetHighlight.args.targetBorderColor = borderColor
            end

            local targetGeneralArgs = {
                targetScale = {
                    order = 1,
                    type = "range",
                    name = "Current Target Scale",
                    min = 0.5,
                    max = 2,
                    step = 0.05,
                    get = function() return CFG.enemyPlateTargetScale or 1 end,
                    set = function(_, v) CFG.enemyPlateTargetScale = v; SaveRefresh() end,
                },
            }

            if targetTexture then
                targetTexture.order = 2
                targetGeneralArgs.targetTexture = targetTexture
            end

            enemyArgs.target = {
                order = 24,
                type = "group",
                name = BrandSection("Target"),
                childGroups = "tree",
                args = {
                    info = {
                        order = 1,
                        type = "description",
                        width = "full",
                        name = "Current-target presentation. The outer glow texture is built in at Media\\Bars\\outer_glow.tga.",
                    },
                    general = {
                        order = 10,
                        type = "group",
                        name = BrandSection("Target Appearance"),
                        guiInline = true,
                        args = targetGeneralArgs,
                    },
                    highlight = targetHighlight,
                },
            }

        end
    end

    -- Defensives is loaded after this file so its controls are assembled here
    -- without creating a second options-registration path. The release menu
    -- restructuring above has already produced the Friendly Plates tab.
    local function SaveDefensiveSettings()
        SaveRefresh()
    end

    local defensiveOptions = {
        order = 50,
        type = "group",
        name = "Defensives",
        childGroups = "tree",
        args = {
            status = {
                order = 1, type = "description", width = "full",
                name = function()
                    local module = BM.Defensives
                    if module and module.IsAuraAPIAvailable and module.IsAuraAPIAvailable() then
                        return "|cff33ff99WoW 12.1 AuraContainer ready.|r Blizzard selects and times the auras; BattleMender controls their presentation."
                    end
                    return "|cffffcc00AuraContainer is unavailable.|r Defensive displays need the WoW 12.1 Blizzard_AuraContainer module."
                end,
            },
            general = {
                order = 10, type = "group", name = BrandSection("General"), guiInline = true,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable Defensive Displays", width = "full", get = function() return CFG.defensiveDisplayEnabled ~= false end, set = function(_, v) CFG.defensiveDisplayEnabled = v and true or false; SaveDefensiveSettings() end },
                    major = { order = 2, type = "toggle", name = "Show Major Defensives", get = function() return CFG.majorDefensiveEnabled ~= false end, set = function(_, v) CFG.majorDefensiveEnabled = v and true or false; SaveDefensiveSettings() end },
                    immunity = { order = 3, type = "toggle", name = "Show Immunities", get = function() return CFG.immunityDisplayEnabled ~= false end, set = function(_, v) CFG.immunityDisplayEnabled = v and true or false; SaveDefensiveSettings() end },
                },
            },
            major = {
                order = 20, type = "group", name = BrandSection("Major Defensive Badge"), guiInline = true,
                args = {
                    info = { order = 0, type = "description", width = "full", name = "Shows a configured defensive aura as a radial badge around the friendly specialization icon. It never changes the native square clickbox." },
                    scale = { order = 1, type = "range", name = "Badge Size", min = .35, max = 1.4, step = .01, get = function() return CFG.majorDefensiveBadgeScale or .72 end, set = function(_, v) CFG.majorDefensiveBadgeScale = v; SaveDefensiveSettings() end },
                    layer = { order = 2, type = "select", name = "Layer", values = { BEHIND = "Behind Plate", FRONT = "In Front of Plate" }, get = function() return CFG.majorDefensiveLayer or "BEHIND" end, set = function(_, v) CFG.majorDefensiveLayer = v; SaveDefensiveSettings() end },
                    distance = { order = 3, type = "range", name = "Radial Distance", desc = "Distance as a proportion of Icon Size, so the badge stays aligned when the plate is resized.", min = 0, max = 1.5, step = .01, get = function() return CFG.majorDefensiveDistanceScale or .53 end, set = function(_, v) CFG.majorDefensiveDistanceScale = v; SaveDefensiveSettings() end },
                    angle = { order = 4, type = "range", name = "Angle", desc = "0 degrees is right and 90 degrees is up.", min = 0, max = 360, step = 1, get = function() return CFG.majorDefensiveAngle or 42 end, set = function(_, v) CFG.majorDefensiveAngle = v; SaveDefensiveSettings() end },
                    border = { order = 10, type = "select", name = "Border Texture", values = { NONE = "None", THIN = "Circle - Thin", NORMAL = "Circle - Standard", METAL = "Circle - Heavy", COGWHEEL = "Defensive Cogwheel" }, get = function() return CFG.majorDefensiveBorderTexture or "NORMAL" end, set = function(_, v) CFG.majorDefensiveBorderTexture = v; SaveDefensiveSettings() end },
                    borderScale = { order = 11, type = "range", name = "Border Size", min = .9, max = 1.8, step = .01, get = function() return CFG.majorDefensiveBorderScale or 1.18 end, set = function(_, v) CFG.majorDefensiveBorderScale = v; SaveDefensiveSettings() end, disabled = function() return CFG.majorDefensiveBorderTexture == "NONE" end },
                    borderAlpha = { order = 12, type = "range", name = "Border Opacity", min = 0, max = 1, step = .01, get = function() return CFG.majorDefensiveBorderAlpha or 1 end, set = function(_, v) CFG.majorDefensiveBorderAlpha = v; SaveDefensiveSettings() end, disabled = function() return CFG.majorDefensiveBorderTexture == "NONE" end },
                    colorMode = { order = 13, type = "select", name = "Border Color", desc = "Auto uses the friendly player class for personal defensives and the known ability class for externals; it does not read aura source data.", values = { AUTO = "Auto", WHITE = "White", CUSTOM = "Custom" }, get = function() return CFG.majorDefensiveBorderColorMode or "AUTO" end, set = function(_, v) CFG.majorDefensiveBorderColorMode = v; SaveDefensiveSettings() end, disabled = function() return CFG.majorDefensiveBorderTexture == "NONE" end },
                    customColor = { order = 14, type = "color", name = "Custom Border Color", hasAlpha = false, get = function() return CFG.majorDefensiveCustomR or .3, CFG.majorDefensiveCustomG or .72, CFG.majorDefensiveCustomB or 1 end, set = function(_, r, g, b) CFG.majorDefensiveCustomR = r; CFG.majorDefensiveCustomG = g; CFG.majorDefensiveCustomB = b; SaveDefensiveSettings() end, disabled = function() return CFG.majorDefensiveBorderTexture == "NONE" or CFG.majorDefensiveBorderColorMode ~= "CUSTOM" end },
                },
            },
            immunity = {
                order = 30, type = "group", name = BrandSection("Immunity Overlay"), guiInline = true,
                args = {
                    info = { order = 0, type = "description", width = "full", name = "Shows an immunity aura over the specialization icon with an engine-driven duration ring." },
                    replace = { order = 1, type = "toggle", name = "Show Immunity Icon", get = function() return CFG.immunityReplaceSpecIcon ~= false end, set = function(_, v) CFG.immunityReplaceSpecIcon = v and true or false; SaveDefensiveSettings() end },
                    iconScale = { order = 2, type = "range", name = "Icon Size", min = .7, max = 1.4, step = .01, get = function() return CFG.immunityIconScale or 1 end, set = function(_, v) CFG.immunityIconScale = v; SaveDefensiveSettings() end },
                    ringScale = { order = 3, type = "range", name = "Ring Scale", min = 1, max = 1.6, step = .01, get = function() return CFG.immunityRingScale or 1.18 end, set = function(_, v) CFG.immunityRingScale = v; SaveDefensiveSettings() end },
                    ringAlpha = { order = 4, type = "range", name = "Base Ring Opacity", min = 0, max = 1, step = .01, get = function() return CFG.immunityRingAlpha or .92 end, set = function(_, v) CFG.immunityRingAlpha = v; SaveDefensiveSettings() end },
                    cooldown = { order = 5, type = "toggle", name = "Ring Cooldown", desc = "Applies the duration sweep to the ring instead of darkening the immunity icon.", get = function() return CFG.immunityCooldownSwipe ~= false end, set = function(_, v) CFG.immunityCooldownSwipe = v and true or false; SaveDefensiveSettings() end },
                    cooldownAlpha = { order = 6, type = "range", name = "Cooldown Ring Opacity", min = 0, max = 1, step = .01, get = function() return CFG.immunityCooldownRingAlpha or .92 end, set = function(_, v) CFG.immunityCooldownRingAlpha = v; SaveDefensiveSettings() end, disabled = function() return CFG.immunityCooldownSwipe == false end },
                    glow = { order = 7, type = "toggle", name = "Pulse Glow", get = function() return CFG.immunityGlowEnabled ~= false end, set = function(_, v) CFG.immunityGlowEnabled = v and true or false; SaveDefensiveSettings() end },
                    glowAlpha = { order = 8, type = "range", name = "Glow Opacity", min = 0, max = 1, step = .01, get = function() return CFG.immunityGlowAlpha or .42 end, set = function(_, v) CFG.immunityGlowAlpha = v; SaveDefensiveSettings() end, disabled = function() return CFG.immunityGlowEnabled == false end },
                    glowSpeed = { order = 9, type = "range", name = "Glow Speed", desc = "Seconds for each half of the glow pulse.", min = .15, max = 2.5, step = .05, get = function() return CFG.immunityGlowSpeed or .9 end, set = function(_, v) CFG.immunityGlowSpeed = v; SaveDefensiveSettings() end, disabled = function() return CFG.immunityGlowEnabled == false end },
                },
            },
            preview = {
                order = 40, type = "group", name = BrandSection("Preview"), guiInline = true,
                args = {
                    info = { order = 0, type = "description", width = "full", name = "The preview is BattleMender-owned and closes with the options window or when combat begins." },
                    major = { order = 1, type = "execute", name = "Preview Major", func = function() if BM.Defensives then BM.Defensives.ShowPreview("MAJOR") end end },
                    immunity = { order = 2, type = "execute", name = "Preview Immunity", func = function() if BM.Defensives then BM.Defensives.ShowPreview("IMMUNITY") end end },
                    both = { order = 3, type = "execute", name = "Preview Both", func = function() if BM.Defensives then BM.Defensives.ShowPreview("BOTH") end end },
                    hide = { order = 4, type = "execute", name = "Hide Preview", func = function() if BM.Defensives then BM.Defensives.HidePreview() end end },
                },
            },
        },
    }

    local friendly = options.args.normal
    if friendly and friendly.args then
        friendly.args.defensives = defensiveOptions
    else
        options.args.defensives = defensiveOptions
    end

    return options
end

function BM.RegisterAceOptions()
    if OptionsRegistered then return true end

    local AC, ACD = ResolveAce3()
    if not (AC and ACD) then return false end

    AC:RegisterOptionsTable(APP_NAME, MakeOptions)
    OptionsRegistered = true
    return true
end

local function RegisterEscapeClose(frame)
    if not frame then return end

    _G[ESCAPE_FRAME_NAME] = frame

    if not EscapeFrameRegistered and UISpecialFrames then
        table.insert(UISpecialFrames, ESCAPE_FRAME_NAME)
        EscapeFrameRegistered = true
    end
end

local function ApplyWindowBranding(widget)
    if not widget or not widget.frame then return end

    local frame = widget.frame
    RegisterEscapeClose(frame)

    widget:SetTitle("|cffc4c9ccBATTLE|r|cff9cff00MENDER|r  |cffc4c9ccSPEC PLATES|r")
    local version = BM.GetVersion and BM.GetVersion() or "unknown"
    widget:SetStatusText("|cff7e858aVersion|r |cffc4c9cc" .. version .. "|r")

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.018, 0.021, 0.023, 0.98)
        frame:SetBackdropBorderColor(0.68, 0.71, 0.73, 1)
    end

    if widget.titlebg then
        if widget.titlebg.SetColorTexture then
            widget.titlebg:SetColorTexture(0.035, 0.040, 0.043, 1)
        elseif widget.titlebg.SetVertexColor then
            widget.titlebg:SetVertexColor(0.12, 0.13, 0.14, 1)
        end
    end

    if widget.statusbg then
        if widget.statusbg.SetColorTexture then
            widget.statusbg:SetColorTexture(0.025, 0.028, 0.030, 1)
        elseif widget.statusbg.SetVertexColor then
            widget.statusbg:SetVertexColor(0.10, 0.11, 0.12, 1)
        end
    end

    if widget.title and widget.title.SetTextColor then
        widget.title:SetTextColor(0.86, 0.88, 0.89, 1)
    end

    if widget.status and widget.status.SetTextColor then
        widget.status:SetTextColor(0.58, 0.62, 0.64, 1)
    end

    if not frame.BattleMenderBrandAccent then
        local accent = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        accent:SetColorTexture(0.55, 1.0, 0.0, 0.95)
        accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -28)
        accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -28)
        accent:SetHeight(2)
        frame.BattleMenderBrandAccent = accent

        local inner = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        inner:SetColorTexture(0.006, 0.008, 0.009, 0.82)
        inner:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -31)
        inner:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -9, 22)
        frame.BattleMenderBrandInner = inner
    end
end

local OPTION_SECTION_ALIASES = {
    friendly = "normal",
    friendlyPlates = "normal",
    enemy = "enemyPlates",
    general = "general",
}

local function NormalizeOptionSection(section)
    if type(section) ~= "string" or section == "" then
        return nil
    end

    return OPTION_SECTION_ALIASES[section] or section
end

local function ApplyDefaultOptionsPosition(frame)
    if not frame or frame.BMDefaultPositionApplied then return end

    local parent = UIParent
    local parentWidth = parent and parent.GetWidth and parent:GetWidth() or 0
    local parentHeight = parent and parent.GetHeight and parent:GetHeight() or 0
    local leftPadding = parentWidth * OPTIONS_DEFAULT_PADDING
    local topPadding = parentHeight * OPTIONS_DEFAULT_PADDING

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", leftPadding, -topPadding)
    frame.BMDefaultPositionApplied = true
end

function BM.OpenStandaloneOptions(section)
    local AC, ACD, AG = ResolveAce3()

    if not (AC and ACD) then
        print("|cff33ff99BattleMender:|r Ace3 options are not available. Missing AceConfig-3.0 or AceConfigDialog-3.0. Check that Ace3 is enabled and loaded before BattleMender.")
        return
    end

    BM.RegisterAceOptions()
    section = NormalizeOptionSection(section)

    if AG then
        if not OptionsFrame then
            OptionsFrame = AG:Create("Frame")
            OptionsFrame:SetLayout("Fill")
            OptionsFrame:SetWidth(OPTIONS_DEFAULT_WIDTH)
            OptionsFrame:SetHeight(OPTIONS_DEFAULT_HEIGHT)

            if OptionsFrame.frame then
                if OptionsFrame.frame.SetResizeBounds then
                    OptionsFrame.frame:SetResizeBounds(OPTIONS_MIN_WIDTH, OPTIONS_MIN_HEIGHT)
                elseif OptionsFrame.frame.SetMinResize then
                    OptionsFrame.frame:SetMinResize(OPTIONS_MIN_WIDTH, OPTIONS_MIN_HEIGHT)
                end
                OptionsFrame.frame:SetResizable(true)
                OptionsFrame.frame:SetClampedToScreen(true)
                OptionsFrame.frame:SetFrameStrata("DIALOG")
                OptionsFrame.frame.BMDefaultPositionPending = true
            end

            -- Keep this one branded frame for BattleMender instead of returning
            -- it to AceGUI's global widget pool.
            OptionsFrame:SetCallback("OnClose", function(widget)
                if BM.DisableTestModes then
                    BM.DisableTestModes(true, false)
                else
                    if CFG then
                        CFG.friendlyTestMode = false
                        CFG.enemyPlateTestMode = false
                    end
                    if BM.SaveDB then BM.SaveDB() end
                end

                if BM.Defensives and BM.Defensives.HidePreview then
                    BM.Defensives.HidePreview()
                end

                if widget and widget.frame then
                    widget.frame:Hide()
                end
            end)

            -- Safety net for any path that hides the standalone options frame
            -- without firing AceGUI's OnClose callback (for example another UI
            -- panel replacing it). Preview frames must never outlive the menu.
            if OptionsFrame.frame and not OptionsFrame.frame.BMTestModeAutoHideHooked then
                OptionsFrame.frame.BMTestModeAutoHideHooked = true
                OptionsFrame.frame:HookScript("OnHide", function()
                    if CFG and (CFG.friendlyTestMode == true or CFG.enemyPlateTestMode == true) then
                        if BM.DisableTestModes then
                            BM.DisableTestModes(true, false)
                        end
                    end
                    if BM.Defensives and BM.Defensives.HidePreview then
                        BM.Defensives.HidePreview()
                    end
                end)
            end
        end

        ApplyWindowBranding(OptionsFrame)
        OptionsFrame.frame:SetFrameStrata("DIALOG")

        -- Select the requested page in AceConfig's saved tree state, then open
        -- the application root. Passing the section as Open()'s base path hides
        -- the parent navigation hierarchy, which made the minimap launcher look
        -- like a separate one-page options window.
        -- Clear any base path left on the reusable AceGUI container by an
        -- older build, then select the page while opening the full root tree.
        if OptionsFrame.SetUserData then
            OptionsFrame:SetUserData("basepath", nil)
        end
        if section and ACD.SelectGroup then
            ACD:SelectGroup(APP_NAME, section)
        end
        ACD:Open(APP_NAME, OptionsFrame)

        if OptionsFrame.frame and OptionsFrame.frame.BMDefaultPositionPending then
            OptionsFrame.frame.BMDefaultPositionPending = nil
            ApplyDefaultOptionsPosition(OptionsFrame.frame)
        end

        -- AceConfig creates its child widgets during Open; reassert the outer
        -- theme on the following frame in case the dialog adjusted its layers.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if OptionsFrame and OptionsFrame.frame and OptionsFrame.frame:IsShown() then
                    ApplyWindowBranding(OptionsFrame)
                end
            end)
        end
    else
        ACD:SetDefaultSize(APP_NAME, OPTIONS_DEFAULT_WIDTH, OPTIONS_DEFAULT_HEIGHT)
        if section and ACD.SelectGroup then
            ACD:SelectGroup(APP_NAME, section)
        end
        ACD:Open(APP_NAME)
    end
end

function BM.OpenOptionsSection(section)
    BM.OpenStandaloneOptions(section)
end

function BM.CloseStandaloneOptions()
    if BM.DisableTestModes then
        BM.DisableTestModes(true, false)
    end
    if BM.Defensives and BM.Defensives.HidePreview then
        BM.Defensives.HidePreview()
    end

    if AceGUI and AceGUI.ClearFocus then
        AceGUI:ClearFocus()
    end

    if OptionsFrame and OptionsFrame.frame then
        OptionsFrame.frame:Hide()
    elseif AceConfigDialog then
        AceConfigDialog:Close(APP_NAME)
    end
end

BM.RegisterAceOptions()

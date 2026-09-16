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

local AURA_FILTER_CHECKBOX = "BattleMenderAuraFilterCheckBox"

local function RegisterAuraFilterCheckBox(aceGUI)
    if not aceGUI then return end

    aceGUI:RegisterWidgetType(AURA_FILTER_CHECKBOX, function()
        -- Reuse AceGUI's maintained CheckBox implementation and add only the
        -- state colors needed by BattleMender's include/exclude filters.
        local widget = aceGUI:Create("CheckBox")
        local baseSetValue = widget.SetValue
        local baseSetDisabled = widget.SetDisabled

        widget.type = AURA_FILTER_CHECKBOX

        local function ApplyStateColor(self)
            local check = self.check
            if not check then return end

            local function SetCheckDesaturated(desaturated)
                if check.SetDesaturated then
                    check:SetDesaturated(desaturated)
                end
            end

            if self.disabled then
                SetCheckDesaturated(true)
                check:SetVertexColor(0.5, 0.5, 0.5)
            elseif self.checked == true then
                SetCheckDesaturated(false)
                check:SetVertexColor(1, 0.82, 0.05)
            elseif self.checked == nil then
                SetCheckDesaturated(false)
                check:SetVertexColor(1, 0.12, 0.08)
            else
                SetCheckDesaturated(false)
                check:SetVertexColor(1, 1, 1)
            end
        end

        widget.SetValue = function(self, value)
            baseSetValue(self, value)
            ApplyStateColor(self)
        end

        widget.SetDisabled = function(self, disabled)
            baseSetDisabled(self, disabled)
            ApplyStateColor(self)
        end

        return widget
    end, 1)
end

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

local RING_TEXTURES = {}
local RING_TEXTURE_ORDER = {}
for _, key in ipairs(BM.FriendlyBorderOrder or {}) do
    local definition = BM.FriendlyBorderDefinitions and BM.FriendlyBorderDefinitions[key]
    if definition then
        RING_TEXTURES[key] = definition.label or key
        RING_TEXTURE_ORDER[#RING_TEXTURE_ORDER + 1] = key
    end
end

local LOS_RING_TEXTURES = { SAME = "Same as Normal" }
local LOS_RING_TEXTURE_ORDER = { "SAME" }
for _, key in ipairs(RING_TEXTURE_ORDER) do
    LOS_RING_TEXTURES[key] = RING_TEXTURES[key]
    LOS_RING_TEXTURE_ORDER[#LOS_RING_TEXTURE_ORDER + 1] = key
end

local ACCENT_OVERLAY_TEXTURES = {
    ["Metal_Ring"] = "Metal Ring",
    ["Glass_Ring"] = "Glass Ring",
}

local LOS_ACCENT_OVERLAY_TEXTURES = {
    ["NONE"] = "Disabled",
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

local function BuildLSMStatusbarValues(allowSame, sameLabel)
    local values = {}

    if allowSame then
        values.SAME = sameLabel or "Same as Enemy"
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

local FRIENDLY_PREVIEW_OBJECTIVES = {
    NONE = "None",
    FLAG_HORDE = "Horde Flag",
    FLAG_ALLIANCE = "Alliance Flag",
    FLAG_NEUTRAL = "Neutral Flag",
    ORB_BLUE = "Blue Orb",
    ORB_GREEN = "Green Orb",
    ORB_ORANGE = "Orange Orb",
    ORB_PURPLE = "Purple Orb",
    CART_HORDE = "Horde Cart",
    CART_ALLIANCE = "Alliance Cart",
    BOUNTY_HORDE = "Horde Bounty",
    BOUNTY_ALLIANCE = "Alliance Bounty",
}

local FRIENDLY_PREVIEW_AURAS = {
    NONE = "None",
    MAJOR = "Major Defensive",
    IMMUNITY = "Immunity",
    BOTH = "Major + Immunity",
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
    CENTER = "Center",
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
    if v == "BLIZZARD" or v == "blizzard" or v == "Interface\\TargetingFrame\\UI-StatusBar" then
        return "BLIZZARD"
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
    if v == "BLIZZARD" or v == "blizzard" or v == "Interface\\TargetingFrame\\UI-StatusBar" then
        return allowSame and "SAME" or LSM_FLAT_NAME
    end

    local name = string.match(v, "^LSM:(.+)$")
    if name and name ~= "" then
        return name
    end

    -- Raw custom paths cannot be previewed inside the LSM dropdown. Keep the
    -- selector stable instead of returning a value AceConfig cannot display.
    return LSM_FLAT_NAME
end

local function EnemyStatusbarSelect(order, name, key, allowSame, desc, disabled, fallbackKey, sameLabel)
    return {
        order = order,
        type = "select",
        dialogControl = "LSM30_Statusbar",
        name = name,
        desc = desc,
        values = function()
            return BuildLSMStatusbarValues(allowSame, sameLabel)
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
            elseif v == "BLIZZARD" then
                CFG[key] = "BLIZZARD"
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

local function EnemyAuraFilterToggle(order, includeKey, excludeKey, name, defaultValue, desc)
    return {
        order = order,
        type = "toggle",
        tristate = true,
        dialogControl = AURA_FILTER_CHECKBOX,
        name = name,
        desc = (desc and (desc .. "\n\n") or "")
            .. "|cffffd10aYellow|r adds matching auras. |cffff3028Red|r removes matching auras. Empty ignores this category.",
        width = 1.25,
        get = function()
            if CFG[includeKey] == true then
                return true
            elseif CFG[excludeKey] == true then
                return nil
            elseif CFG[includeKey] == nil and CFG[excludeKey] == nil and defaultValue == true then
                return true
            end
            return false
        end,
        set = function(_, value)
            CFG[includeKey] = value == true
            CFG[excludeKey] = value == nil
            SaveRefresh()
        end,
    }
end

local function EnemyAuraFilterInstructions(order)
    return {
        order = order,
        type = "description",
        name = "Each category has three states: |cffffd10aYellow|r adds matching auras, |cffff3028Red|r removes matching auras, and empty ignores the category.",
        width = "full",
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
    local sizeDescription = defaults.allowFlat
        and "The base icon width. Flat 2/3-height Icons uses a shorter height."
        or "The base icon size."
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
                flat = defaults.allowFlat and EnemyAuraCategoryToggle(
                    4,
                    prefix,
                    "Flat",
                    "Flat 2/3-height Icons",
                    defaults.flat ~= false,
                    "Draw these auras as wide, shallow icons cropped from the middle of the source icon."
                ) or nil,
            },
        },
        layout = {
            order = 20,
            type = "group",
            name = "Layout",
            guiInline = true,
            args = {
                size = EnemyAuraRange(1, prefix, "Size", "Size", 8, 60, 1, defaults.size or 30, sizeDescription),
                perRow = EnemyAuraRange(2, prefix, "PerRow", "Per Row", 1, 12, 1, defaults.perRow or 5, "Maximum icons before the next row begins. This also sets the width of the aura anchor."),
                rows = EnemyAuraRange(3, prefix, "Rows", "Rows", 1, 4, 1, defaults.rows or 1, "Maximum number of rows. This sets the height of the aura anchor."),
                spacing = EnemyAuraRange(4, prefix, "Spacing", "Spacing", 0, 12, 1, defaults.spacing or 1, "Empty space between neighboring icons."),
                align = EnemyAuraSelect(5, prefix, "Align", "Alignment", ENEMY_AURA_ALIGN, defaults.align or "LEFT", "Places a shorter manual row at the left, centre, or right of its configured aura area."),
                x = EnemyAuraRange(6, prefix, "XOffset", "X Offset", -100, 100, 1, defaults.x or -2, "Fine horizontal adjustment after the two anchor points are connected. Positive moves right."),
                y = EnemyAuraRange(7, prefix, "YOffset", "Y Offset", -100, 100, 1, defaults.y or 4, "Fine vertical adjustment after the two anchor points are connected. Positive moves up."),
                attachTo = EnemyAuraSelect(8, prefix, "AttachTo", "Attach To", ENEMY_AURA_ATTACH_TO, defaults.attachTo or "HEALTH", "The nameplate element to attach to. Health is the usual choice for an aura row above the health bar."),
                anchorPoint = EnemyAuraSelect(9, prefix, "AnchorPoint", "Anchor Point", ENEMY_AURA_POINTS, defaults.anchorPoint or "BOTTOMLEFT", "The corner or edge of the aura area that will be connected to Attach Point."),
                attachPoint = EnemyAuraSelect(10, prefix, "AttachPoint", "Attach Point", ENEMY_AURA_POINTS, defaults.attachPoint or "TOPLEFT", "The corner or edge on Attach To that receives the aura area's Anchor Point. For a row above Health, use Top Left or Top Right."),
                growX = EnemyAuraSelect(11, prefix, "GrowthX", "Growth X", ENEMY_GROWTH_X, defaults.growX or "RIGHT", "Manual rows can grow left, right, or stay centered on the aura anchor. The managed combat layout uses the matching horizontal origin."),
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

local function BuildSelectableAuraContainerArgs(label, keyPrefix, defaults)
    defaults = defaults or {}
    local root = "enemyPlate" .. keyPrefix
    local buff = root .. "Buff"
    local debuff = root .. "Debuff"
    local args = EnemyAuraLayoutArgs(root .. "Aura", defaults)


    local function GetToggle(suffix, fallback)
        local value = CFG[root .. suffix]
        if value == nil then
            return fallback == true
        end
        return value == true
    end

    local function ShowWith(option, suffix, fallback)
        option.hidden = function() return not GetToggle(suffix, fallback) end
        return option
    end

    args.enable = {
        order = 0,
        type = "toggle",
        name = "Enable " .. label .. " Auras",
        desc = "Enables the independent " .. label .. " aura container with its own filters and layout.",
        width = "normal",
        get = function() return GetToggle("AurasEnabled", defaults.enabled) end,
        set = function(_, v) CFG[root .. "AurasEnabled"] = v and true or false; SaveRefresh() end,
    }
    args.targetOnly = {
        order = 0.5,
        type = "toggle",
        name = "Only on Current Target",
        desc = "Shows the " .. label .. " aura container only on your current target. Other aura containers are unaffected.",
        width = "normal",
        get = function() return GetToggle("AurasTargetOnly", defaults.targetOnly) end,
        set = function(_, v) CFG[root .. "AurasTargetOnly"] = v and true or false; SaveRefresh() end,
    }
    args.displayBuffs = {
        order = 0.6,
        type = "toggle",
        name = "Display Enemy Buffs",
        desc = "Adds helpful auras to " .. label .. ". With no yellow Buff filter, it starts from all buffs and applies any red exclusions.",
        width = "normal",
        get = function() return GetToggle("ShowBuffs", defaults.showBuffs) end,
        set = function(_, v)
            CFG[root .. "ShowBuffs"] = v and true or false
            SaveRefresh()
            RefreshAuraFilterVisibility()
        end,
    }
    args.displayDebuffs = {
        order = 0.7,
        type = "toggle",
        name = "Display Enemy Debuffs",
        desc = "Adds harmful auras to " .. label .. ". With no yellow Debuff filter, it starts from all debuffs and applies any red exclusions.",
        width = "normal",
        get = function() return GetToggle("ShowDebuffs", defaults.showDebuffs) end,
        set = function(_, v)
            CFG[root .. "ShowDebuffs"] = v and true or false
            SaveRefresh()
            RefreshAuraFilterVisibility()
        end,
    }

    args.filters = {
        order = 1,
        type = "group",
        name = "Filters",
        guiInline = true,
        width = "full",
        hidden = function()
            return not GetToggle("ShowBuffs", defaults.showBuffs)
                and not GetToggle("ShowDebuffs", defaults.showDebuffs)
        end,
        args = {
            instructions = EnemyAuraFilterInstructions(0),
            buffHeading = ShowWith({
                order = 1,
                type = "description",
                name = "|cffffd100Buff filters|r",
                fontSize = "medium",
                width = "full",
            }, "ShowBuffs", defaults.showBuffs),
            buffPlayerDispellable = ShowWith(EnemyAuraFilterToggle(2, buff .. "UsePlayerDispellable", buff .. "ExcludePlayerDispellable", "Dispellable by Me", false, "Enemy buffs your current character can actively purge, steal, or remove as an Enrage. The result follows your current spellbook/talents."), "ShowBuffs", defaults.showBuffs),
            buffRaidDispellable = ShowWith(EnemyAuraFilterToggle(3, buff .. "UseRaidDispellable", buff .. "ExcludeRaidDispellable", "Dispellable by Your Group", false, "Buffs Blizzard marks as removable by someone in your group."), "ShowBuffs", defaults.showBuffs),
            buffDispellable = ShowWith(EnemyAuraFilterToggle(4, buff .. "UseDispellable", buff .. "ExcludeDispellable", "Any Dispel Type", false, "Buffs with a dispel type, even when your current group cannot remove them."), "ShowBuffs", defaults.showBuffs),
            buffImportant = ShowWith(EnemyAuraFilterToggle(5, buff .. "UseImportant", buff .. "ExcludeImportant", "Important", false, "Buffs in Blizzard's Important helpful-aura category."), "ShowBuffs", defaults.showBuffs),
            buffRaidInCombat = ShowWith(EnemyAuraFilterToggle(6, buff .. "UseRaidInCombat", buff .. "ExcludeRaidInCombat", "Raid Frame (In Combat)", false, "Buffs Blizzard marks for raid-frame display during combat."), "ShowBuffs", defaults.showBuffs),
            buffRaid = ShowWith(EnemyAuraFilterToggle(7, buff .. "Raid", buff .. "ExcludeRaid", "Raid Frame", false, "Buffs Blizzard places in its Raid helpful-aura category."), "ShowBuffs", defaults.showBuffs),
            buffCancelable = ShowWith(EnemyAuraFilterToggle(8, buff .. "Cancelable", buff .. "ExcludeCancelable", "Cancelable", false, "Buffs the owner can cancel. A red state removes them, leaving non-cancelable matches."), "ShowBuffs", defaults.showBuffs),
            buffBigDefensive = ShowWith(EnemyAuraFilterToggle(9, buff .. "BigDefensive", buff .. "ExcludeBigDefensive", "Big Defensive", false, "Buffs in Blizzard's Big Defensive category."), "ShowBuffs", defaults.showBuffs),
            buffExternalDefensive = ShowWith(EnemyAuraFilterToggle(10, buff .. "ExternalDefensive", buff .. "ExcludeExternalDefensive", "External Defensive", false, "Buffs in Blizzard's External Defensive category."), "ShowBuffs", defaults.showBuffs),
            buffBlockPermanent = ShowWith(EnemyAuraToggle(11, buff .. "BlockPermanent", "Hide Permanent Auras", false, "Hides buffs with no duration when their aura data is readable. This is a normal two-state display modifier."), "ShowBuffs", defaults.showBuffs),
            debuffHeading = ShowWith({
                order = 20,
                type = "description",
                name = "|cffffd100Debuff filters|r",
                fontSize = "medium",
                width = "full",
            }, "ShowDebuffs", defaults.showDebuffs),
            debuffOnlyCastByYou = ShowWith(EnemyAuraToggle(21, debuff .. "OnlyCastByYou", "Only Cast by You", false, "Limits every selected Debuff filter—and the broad fallback when none is selected—to debuffs cast by you, your pet, or your vehicle."), "ShowDebuffs", defaults.showDebuffs),
            debuffRaidDispellable = ShowWith(EnemyAuraFilterToggle(22, debuff .. "UseRaidDispellable", debuff .. "ExcludeRaidDispellable", "Dispellable by Your Group", false, "Debuffs Blizzard marks as removable by someone in your group."), "ShowDebuffs", defaults.showDebuffs),
            debuffDispellable = ShowWith(EnemyAuraFilterToggle(23, debuff .. "UseDispellable", debuff .. "ExcludeDispellable", "Any Dispel Type", false, "Debuffs with a dispel type, even when your current group cannot remove them."), "ShowDebuffs", defaults.showDebuffs),
            debuffRaid = ShowWith(EnemyAuraFilterToggle(24, debuff .. "Raid", debuff .. "ExcludeRaid", "Raid Frame", false, "Debuffs Blizzard places in its Raid harmful-aura category."), "ShowDebuffs", defaults.showDebuffs),
            debuffCrowdControl = ShowWith(EnemyAuraFilterToggle(25, debuff .. "CrowdControl", debuff .. "ExcludeCrowdControl", "Crowd Control", false, "Debuffs Blizzard classifies as crowd control."), "ShowDebuffs", defaults.showDebuffs),
            debuffBlockPermanent = ShowWith(EnemyAuraToggle(26, debuff .. "BlockPermanent", "Hide Permanent Auras", false, "Hides debuffs with no duration when their aura data is readable. This is a normal two-state display modifier."), "ShowDebuffs", defaults.showDebuffs),
        },
    }

    return args
end
local function SaveRefreshClickbox()
    if BM.SetFriendlyClickbox then BM.SetFriendlyClickbox() end
    SaveRefresh()
    if BM.ShowTemporaryClickboxPreview then BM.ShowTemporaryClickboxPreview(1.75) end
end

local function SaveRefreshInteraction()
    if BM.SetFriendlyClickbox then
        BM.SetFriendlyClickbox()
    elseif BM.ApplyNameplateInteractibility then
        BM.ApplyNameplateInteractibility()
    end
    SaveRefresh()
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
        lines[#lines + 1] = "|cff33ff99Compatible: BattleMender is using Blizzard's native nameplate driver for its own plates.|r"
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
        childGroups = "tree",
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
                            friendlyNameInfo = { order = 4, type = "description", name = "Friendly names and class colors while BattleMender is disabled are controlled by Blizzard's Nameplate settings.", width = "full" },
                            restoreDefaultClickboxInPvE = { order = 5, type = "toggle", name = "Restore Default Clickbox While Disabled", desc = "Use a 110 x 45 friendly nameplate clickbox while BattleMender is sleeping instead of the circular BattleMender clickbox.", get = function() return CFG.restoreDefaultClickboxInPvE ~= false end, set = function(_, v) CFG.restoreDefaultClickboxInPvE = v; SaveRefreshInstanceBehavior() end },
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
                    locked = { order = 1, type = "description", name = function() return CFG.developerMode and "" or "Enable Developer Mode under Friendly Plates to edit these settings." end },
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
                    locked = { order = 1, type = "description", name = function() return CFG.developerMode and "" or "Enable Developer Mode under Friendly Plates to edit these settings." end },
                    spec = {
                        order = 10, type = "group", name = "Spec Icon", guiInline = true,
                        args = {
                            specIconEnabled = { order = 1, type = "toggle", name = "Enable Spec Icon", get = function() return CFG.specIconEnabled ~= false end, set = function(_, v) CFG.specIconEnabled = v; SaveRefresh() end },
                            specIconAlpha = { order = 2, type = "range", name = "Spec Icon Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.specIconAlpha or 1 end, set = function(_, v) CFG.specIconAlpha = v; SaveRefresh() end },
                            specIconBlendMode = { order = 3, type = "select", name = "Spec Icon Blend", values = BLEND_MODES, get = function() return CFG.specIconBlendMode or "MOD" end, set = function(_, v) CFG.specIconBlendMode = v; SaveRefresh() end },
                            specIconDesaturate = { order = 4, type = "toggle", name = "Desaturate Spec Icon", get = function() return CFG.specIconDesaturate == true end, set = function(_, v) CFG.specIconDesaturate = v and true or false; SaveRefresh() end },
                            specIconUseClassColor = { order = 5, type = "toggle", name = "Class Color Spec Icon", desc = "Tint the specialization artwork with the friendly player's class color.", get = function() return CFG.specIconUseClassColor == true end, set = function(_, v) CFG.specIconUseClassColor = v and true or false; SaveRefresh() end },
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
                            ringFineTune = { order = 3, type = "range", name = "Border Fine Tune", desc = "Circular borders are automatically normalized and visually calibrated per texture. Leave this at 1.00 for the intended fit, or make a small personal adjustment. Shield variants retain their legacy sizing for now.", min = 0.85, max = 1.15, step = 0.01, get = function() return CFG.ringFineTune or 1 end, set = function(_, v) CFG.ringFineTune = v; SaveRefresh() end },
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
                    locked = { order = 1, type = "description", name = function() return CFG.developerMode and "" or "Enable Developer Mode under Friendly Plates to edit these settings." end },
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
                            losSpecIconDesaturate = { order = 3, type = "toggle", name = "Desaturate in LoS State", get = function() return CFG.losSpecIconDesaturate == true end, set = function(_, v) CFG.losSpecIconDesaturate = v and true or false; SaveRefresh() end },
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
                            losRingTexture = { order = 1, type = "select", name = "LoS Border Style", values = LOS_RING_TEXTURES, sorting = LOS_RING_TEXTURE_ORDER, get = function() return CFG.losRingTexture or "Ring_20px" end, set = function(_, v) CFG.losRingTexture = v; SaveRefresh() end },
                            losRingAlpha = { order = 2, type = "range", name = "LoS Border Opacity", min = 0, max = 1, step = 0.05, get = function() return CFG.losRingAlpha or 0.7 end, set = function(_, v) CFG.losRingAlpha = v; SaveRefresh() end },
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
                                get = function() return CFG.losAccentOverlayTexture or "NONE" end,
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
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
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
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
                            },
                            losAccentOverlayBlendMode = {
                                order = 4,
                                type = "select",
                                name = "Blend Mode",
                                values = BLEND_MODES,
                                get = function() return CFG.losAccentOverlayBlendMode or "BLEND" end,
                                set = function(_, v) CFG.losAccentOverlayBlendMode = v; SaveRefresh() end,
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
                            },
                            losAccentOverlayUseClassColor = {
                                order = 5,
                                type = "toggle",
                                name = "Use Class Color",
                                get = function() return CFG.losAccentOverlayUseClassColor == true end,
                                set = function(_, v) CFG.losAccentOverlayUseClassColor = v; SaveRefresh() end,
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
                            },
                            losAccentOverlayColor = {
                                order = 6,
                                type = "color",
                                name = "Color",
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" or CFG.losAccentOverlayUseClassColor == true end,
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
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
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
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
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
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
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
                                disabled = function() return CFG.losAccentOverlayTexture == "NONE" end,
                            },
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
        childGroups = "tree",
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
                    absorbShow = { order = 4, type = "toggle", name = "Show Absorb Shields", desc = "Mirrors Blizzard absorb shields on top of the custom enemy health bar when the native nameplate exposes absorb geometry.", get = function() return CFG.enemyPlateShowAbsorbs ~= false end, set = function(_, v) CFG.enemyPlateShowAbsorbs = v and true or false; SaveRefresh() end },
                    absorbTexture = EnemyStatusbarSelect(5, "Absorb Shield Texture", "enemyPlateAbsorbTexture", true, "Texture used for the absorb segment that extends past the current health fill. Same as Health follows the current normal/target/focus health texture.", nil, "enemyPlateHealthTexture", "Same as Health"),
                    absorbColor = EnemyColorOption(6, "Absorb Shield Color", "enemyPlateAbsorbColor", 0.72, 0.92, 1, 0.85, "Tint and opacity for the absorb shield segment on the health bar."),
                    backgroundColor = EnemyColorOption(7, "Health Background Color", "enemyPlateHealthBackground", 0, 0, 0, 0.85, "Base health-bar background. The alpha here controls the normal health background opacity."),
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
                            targetGlow = { order = 4, type = "toggle", name = "Outer Background Glow", desc = "Shows the built-in outer glow only around the exterior of the health bar.", get = function() return CFG.enemyPlateTargetGlowEnabled ~= false end, set = function(_, v) CFG.enemyPlateTargetGlowEnabled = v and true or false; SaveRefresh() end },
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
                            lowGlow = { order = 6, type = "toggle", name = "Outer Background Glow", desc = "Adds the same exterior-only outer glow around the health bar at low health.", get = function() return CFG.enemyPlateLowHealthGlowEnabled ~= false end, set = function(_, v) CFG.enemyPlateLowHealthGlowEnabled = v and true or false; SaveRefresh() end },
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
                    interruptedHold = { order = 11, type = "range", name = "Interrupted Display Time", desc = "How long an interrupted enemy cast remains visible in its interrupted color.", min = 0.1, max = 3, step = 0.05, get = function() return CFG.enemyPlateCastInterruptedHoldTime or 0.75 end, set = function(_, v) CFG.enemyPlateCastInterruptedHoldTime = v; SaveRefresh() end },
                    castTexture = EnemyStatusbarSelect(12, "Interruptible Cast Texture", "enemyPlateCastTexture", false, "Texture for normal interruptible casts."),
                    castLockedTexture = EnemyStatusbarSelect(13, "Uninterruptible Cast Texture", "enemyPlateCastNotInterruptibleTexture", true, "Texture for confirmed uninterruptible casts. Use Same as Enemy to reuse the interruptible cast texture.", nil, "enemyPlateCastTexture"),
                    castSpark = { order = 14, type = "toggle", name = "Show Blizzard Spark", desc = "Displays Blizzard's moving cast spark at the leading edge of the fill.", get = function() return CFG.enemyPlateCastSpark == true end, set = function(_, v) CFG.enemyPlateCastSpark = v and true or false; SaveRefresh() end },
                    interruptibleColor = { order = 20, type = "color", name = "Interruptible Color", get = function() return CFG.enemyPlateCastInterruptibleR or 1, CFG.enemyPlateCastInterruptibleG or 0.82, CFG.enemyPlateCastInterruptibleB or 0.05 end, set = function(_, r, g, b) CFG.enemyPlateCastInterruptibleR = r; CFG.enemyPlateCastInterruptibleG = g; CFG.enemyPlateCastInterruptibleB = b; SaveRefresh() end },
                    notInterruptibleColor = { order = 21, type = "color", name = "Uninterruptible Color", get = function() return CFG.enemyPlateCastNotInterruptibleR or 0.45, CFG.enemyPlateCastNotInterruptibleG or 0.45, CFG.enemyPlateCastNotInterruptibleB or 0.45 end, set = function(_, r, g, b) CFG.enemyPlateCastNotInterruptibleR = r; CFG.enemyPlateCastNotInterruptibleG = g; CFG.enemyPlateCastNotInterruptibleB = b; SaveRefresh() end },
                    targetPlayerColor = { order = 22, type = "color", name = "Targeting You Color", get = function() return CFG.enemyPlateCastTargetPlayerR or 1, CFG.enemyPlateCastTargetPlayerG or 0.12, CFG.enemyPlateCastTargetPlayerB or 0.08 end, set = function(_, r, g, b) CFG.enemyPlateCastTargetPlayerR = r; CFG.enemyPlateCastTargetPlayerG = g; CFG.enemyPlateCastTargetPlayerB = b; SaveRefresh() end },
                    interruptedColor = { order = 23, type = "color", name = "Interrupted Color", get = function() return CFG.enemyPlateCastInterruptedR or 0.9, CFG.enemyPlateCastInterruptedG or 0.2, CFG.enemyPlateCastInterruptedB or 0.2 end, set = function(_, r, g, b) CFG.enemyPlateCastInterruptedR = r; CFG.enemyPlateCastInterruptedG = g; CFG.enemyPlateCastInterruptedB = b; SaveRefresh() end },
                },
            },
            auras = {
                order = 40,
                type = "group",
                name = BrandSection("Auras"),
                childGroups = "tree",
                args = {
                    show = { order = 1, type = "toggle", name = "Show Auras", desc = "Shows the separate Buff, Debuff, Custom, and Important aura displays. Each group has its own layout and Blizzard aura filters.", get = function() return CFG.enemyPlateShowAuras ~= false end, set = function(_, v) CFG.enemyPlateShowAuras = v and true or false; SaveRefresh() end },
                    buffs = {
                        order = 10,
                        type = "group",
                        name = "Buffs",
                        childGroups = "tree",
                        args = (function()
                            local args = EnemyAuraLayoutArgs("enemyPlateBuffAura", { size = 30, perRow = 5, rows = 1, spacing = 1, x = -2, y = 4, attachTo = "HEALTH", anchorPoint = "BOTTOMLEFT", attachPoint = "TOPLEFT", growX = "RIGHT", growY = "UP", align = "LEFT" })
                            args.enable = { order = 0, type = "toggle", name = "Enable Buffs", desc = "Shows helpful enemy auras not cast by you. With no yellow category, the display starts from all matching buffs and applies any red exclusions.", width = "normal", get = function() return CFG.enemyPlateShowBuffs ~= false end, set = function(_, v) CFG.enemyPlateShowBuffs = v and true or false; SaveRefresh() end }
                            args.targetOnly = { order = 0.5, type = "toggle", name = "Only on Current Target", desc = "Shows this Buff group only on your current target.", width = "normal", get = function() return CFG.enemyPlateBuffAurasTargetOnly == true end, set = function(_, v) CFG.enemyPlateBuffAurasTargetOnly = v and true or false; SaveRefresh() end }
                            args.filters = {
                                order = 1,
                                type = "group",
                                name = "Filters",
                                guiInline = true,
                                args = {
                                    instructions = EnemyAuraFilterInstructions(1),
                                    playerDispellable = EnemyAuraFilterToggle(2, "enemyPlateBuffUsePlayerDispellable", "enemyPlateBuffExcludePlayerDispellable", "Dispellable by Me", false, "Enemy buffs your current character can actively purge, steal, or remove as an Enrage. The result follows your current spellbook/talents."),
                                    raidDispellable = EnemyAuraFilterToggle(3, "enemyPlateBuffUseRaidDispellable", "enemyPlateBuffExcludeRaidDispellable", "Dispellable by Your Group", false, "Buffs Blizzard marks as removable by someone in your group."),
                                    dispellable = EnemyAuraFilterToggle(4, "enemyPlateBuffUseDispellable", "enemyPlateBuffExcludeDispellable", "Any Dispel Type", false, "Buffs with a dispel type, even when your current group cannot remove them."),
                                    important = EnemyAuraFilterToggle(5, "enemyPlateBuffUseImportant", "enemyPlateBuffExcludeImportant", "Important", false, "Buffs in Blizzard's Important helpful-aura category."),
                                    raidInCombat = EnemyAuraFilterToggle(6, "enemyPlateBuffUseRaidInCombat", "enemyPlateBuffExcludeRaidInCombat", "Raid Frame (In Combat)", false, "Buffs Blizzard marks for raid-frame display during combat."),
                                    raid = EnemyAuraFilterToggle(7, "enemyPlateBuffOthersRaid", "enemyPlateBuffOthersExcludeRaid", "Raid Frame", false, "Buffs in Blizzard's Raid helpful-aura category."),
                                    cancelable = EnemyAuraFilterToggle(8, "enemyPlateBuffOthersCancelable", "enemyPlateBuffOthersExcludeCancelable", "Cancelable", false, "Buffs the owner can cancel. A red state removes them, leaving non-cancelable matches."),
                                    bigDef = EnemyAuraFilterToggle(9, "enemyPlateBuffOthersBigDefensive", "enemyPlateBuffOthersExcludeBigDefensive", "Big Defensive", true, "Buffs in Blizzard's Big Defensive category."),
                                    extDef = EnemyAuraFilterToggle(10, "enemyPlateBuffOthersExternalDefensive", "enemyPlateBuffOthersExcludeExternalDefensive", "External Defensive", true, "Buffs in Blizzard's External Defensive category, usually applied by another unit."),
                                    blockPerm = EnemyAuraToggle(11, "enemyPlateBuffOthersBlockPermanent", "Hide Permanent Auras", false, "Hides buffs with no duration when their aura data is readable. This is a normal two-state display modifier."),
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
                            args.enable = { order = 0, type = "toggle", name = "Enable Debuffs", desc = "Shows harmful enemy auras. With no yellow category, the display starts from all debuffs and applies any red exclusions.", width = "normal", get = function() return CFG.enemyPlateShowDebuffs ~= false end, set = function(_, v) CFG.enemyPlateShowDebuffs = v and true or false; SaveRefresh() end }
                            args.targetOnly = { order = 0.5, type = "toggle", name = "Only on Current Target", desc = "Shows this Debuff group only on your current target.", width = "normal", get = function() return CFG.enemyPlateDebuffAurasTargetOnly == true end, set = function(_, v) CFG.enemyPlateDebuffAurasTargetOnly = v and true or false; SaveRefresh() end }
                            args.filters = {
                                order = 1,
                                type = "group",
                                name = "Filters",
                                guiInline = true,
                                args = {
                                    instructions = EnemyAuraFilterInstructions(1),
                                    onlyCastByYou = EnemyAuraToggle(2, "enemyPlateDebuffOnlyCastByYou", "Only Cast by You", false, "Limits every selected Debuff filter—and the broad fallback when none is selected—to debuffs cast by you, your pet, or your vehicle."),
                                    raidDispellable = EnemyAuraFilterToggle(3, "enemyPlateDebuffUseRaidDispellable", "enemyPlateDebuffExcludeRaidDispellable", "Dispellable by Your Group", false, "Debuffs Blizzard marks as removable by someone in your group."),
                                    dispellable = EnemyAuraFilterToggle(4, "enemyPlateDebuffUseDispellable", "enemyPlateDebuffExcludeDispellable", "Any Dispel Type", false, "Debuffs with a dispel type, even when your current group cannot remove them."),
                                    raid = EnemyAuraFilterToggle(5, "enemyPlateDebuffRaid", "enemyPlateDebuffExcludeRaid", "Raid Frame", false, "Debuffs Blizzard places in its Raid harmful-aura category."),
                                    cc = EnemyAuraFilterToggle(6, "enemyPlateDebuffCrowdControl", "enemyPlateDebuffExcludeCrowdControl", "Crowd Control", true, "Debuffs Blizzard classifies as crowd control."),
                                    blockPerm = EnemyAuraToggle(7, "enemyPlateDebuffBlockPermanent", "Hide Permanent Auras", true, "Hides debuffs with no duration when their aura data is readable. This is a normal two-state display modifier."),
                                },
                            }
                            return args
                        end)(),
                    },
                    custom = {
                        order = 30,
                        type = "group",
                        name = "Custom",
                        args = BuildSelectableAuraContainerArgs("Custom", "Custom", {
                            enabled = true,
                            targetOnly = true,
                            showBuffs = false,
                            showDebuffs = false,
                            size = 16,
                            perRow = 5,
                            rows = 1,
                            spacing = 2,
                            x = 0,
                            y = 2,
                            attachTo = "HEALTH",
                            anchorPoint = "BOTTOMLEFT",
                            attachPoint = "TOPLEFT",
                            growX = "RIGHT",
                            growY = "UP",
                            align = "LEFT",
                            desaturate = true,
                            keepRatio = true,
                            cooldownSwipe = false,
                            allowFlat = true,
                            flat = true,
                        }),
                    },
                    danger = {
                        order = 40,
                        type = "group",
                        name = "Important",
                        -- Keep the internal Danger prefix for backward-compatible
                        -- profiles; only the user-facing category name changes.
                        args = BuildSelectableAuraContainerArgs("Important", "Danger", {
                            enabled = false,
                            targetOnly = true,
                            showBuffs = false,
                            showDebuffs = false,
                            size = 16,
                            perRow = 5,
                            rows = 1,
                            spacing = 2,
                            x = 0,
                            y = 18,
                            attachTo = "HEALTH",
                            anchorPoint = "BOTTOMLEFT",
                            attachPoint = "TOPLEFT",
                            growX = "RIGHT",
                            growY = "UP",
                            align = "LEFT",
                            desaturate = false,
                            keepRatio = true,
                            cooldownSwipe = true,
                            allowFlat = true,
                            flat = true,
                        }),
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
                    objectiveFlash = { order = 8, type = "toggle", name = "Flash Objective Carriers", desc = "Repeats Blizzard's short double-flash treatment across the BattleMender health bar while an enemy flag, orb, cart, or bounty carrier is detected.", get = function() return CFG.enemyPlateObjectiveFlashEnabled ~= false end, set = function(_, v) CFG.enemyPlateObjectiveFlashEnabled = v and true or false; SaveRefresh() end },
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
                        if normal.args.ring.args.ringFineTune then normal.args.ring.args.ringFineTune.name = "Border Fine Tune" end
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
        -- Legacy construction step; 15.0 folds this back into General below.
        -------------------------------------------------
        local blizzard = general and general.args and general.args.blizzardCVars
        if blizzard then
            general.args.blizzardCVars = nil
            blizzard.order = 6
            blizzard.name = "Blizzard CVars"
            blizzard.guiInline = nil
            blizzard.childGroups = "tree"
            options.args.blizzardCVars = blizzard
        end

        -------------------------------------------------
        -- Compatibility page for provider detection / handoff.
        -------------------------------------------------
        local generalGroup = general and general.args and general.args.generalGroup
        local disableWarning = generalGroup and generalGroup.args and generalGroup.args.disableElvUIWarning
        local enemyAutoDisable = enemy and enemy.args and enemy.args.autoDisable

        if general and general.args then
            general.args.status = nil
            general.args.quickEffects = nil
        end

        if generalGroup and generalGroup.args then
            generalGroup.args.disableElvUIWarning = nil
        end

        if enemy and enemy.args then
            enemy.args.autoDisable = nil
        end

        if disableWarning then disableWarning.order = 30; disableWarning.hidden = nil end
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
                nameplateAddons = {
                    order = 20,
                    type = "group",
                    name = BrandSection("Nameplate Addons"),
                    guiInline = true,
                    args = {
                        autoDisable = enemyAutoDisable,
                        warning = disableWarning,
                    },
                },
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
            effects.childGroups = "tree"

            local hover = effects.args.hoverGroup
            if hover then
                hover.name = "Hover"
                hover.guiInline = nil
                hover.childGroups = "tree"
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
                effects.args.pulse.childGroups = "tree"
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
            normal.childGroups = "tree"
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
                defensives.name = "Auras"
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



    -------------------------------------------------
    -- v88 enemy navigation / independent aura flare
    -------------------------------------------------
    do
        local enemy = options.args.enemyPlates
        local enemyArgs = enemy and enemy.args

        if enemyArgs then
            local oldLayout = enemyArgs.layout
            local textures = enemyArgs.textures
            local colors = enemyArgs.colors
            local cast = enemyArgs.cast
            local auras = enemyArgs.auras
            local portrait = enemyArgs.portrait
            local target = enemyArgs.target

            -------------------------------------------------
            -- Health Bar: sizing, texture/fill, normal colors, and health states.
            -------------------------------------------------
            local healthShape = oldLayout and oldLayout.args and oldLayout.args.healthShape
            local nameText = oldLayout and oldLayout.args and oldLayout.args.nameText
            local healthArgs = healthShape and healthShape.args or {}

            local classColorHealth = healthArgs.classColorHealth
            healthArgs.classColorHealth = nil
            -- Duplicate of the Classification Colors toggle below.
            healthArgs.classificationColors = nil

            healthArgs.nonTargetScale = {
                order = 4,
                type = "range",
                name = "Non-target Scale",
                min = 0.5, max = 2, step = 0.05,
                get = function() return CFG.enemyPlateNonTargetScale or 1 end,
                set = function(_, v) CFG.enemyPlateNonTargetScale = v; SaveRefresh() end,
            }

            if healthShape then
                healthShape.order = 10
                healthShape.name = BrandSection("Size & Scaling")
                healthShape.guiInline = true
            end

            local focusTexture
            local textureArgs = textures and textures.args or {}
            if textureArgs.focusTexture then
                focusTexture = textureArgs.focusTexture
                textureArgs.focusTexture = nil
            end
            if textureArgs.info then
                textureArgs.info.name = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:16:16:0:0|t Target and Focus textures are configured separately."
            end
            -- Stable Clip was experimental and has been retired. Keep the direct
            -- StatusBar renderer as the single health-fill implementation.
            textureArgs.fillMode = nil
            textureArgs.note = nil
            if textureArgs.enemyTexture then
                textureArgs.enemyTexture.name = "StatusBar Texture"
            end
            if textures then
                textures.order = 20
                textures.name = BrandSection("Texture & Fill")
                textures.guiInline = true
            end

            local colorArgs = colors and colors.args or {}
            local hover = colorArgs.hover
            local lowHealth = colorArgs.lowHealth
            colorArgs.hover = nil
            colorArgs.lowHealth = nil
            colorArgs.info = nil

            if classColorHealth then
                classColorHealth.order = 1
                classColorHealth.width = "full"
                colorArgs.classColorHealth = classColorHealth
            end

            local normalColors = {
                order = 30,
                type = "group",
                name = BrandSection("Unit Colors"),
                guiInline = true,
                args = colorArgs,
            }

            local stateArgs = {}
            if hover then
                hover.order = 10
                hover.name = BrandLabel("Hover")
                stateArgs.hover = hover
            end
            if lowHealth then
                lowHealth.order = 20
                lowHealth.name = BrandLabel("Low Health")
                stateArgs.lowHealth = lowHealth
            end
            local healthStates = {
                order = 40,
                type = "group",
                name = BrandSection("Health States"),
                guiInline = true,
                args = stateArgs,
            }

            enemyArgs.healthBar = {
                order = 20,
                type = "group",
                name = "Health Bar",
                childGroups = "tree",
                args = {
                    sizing = healthShape,
                    texture = textures,
                    colors = normalColors,
                    states = healthStates,
                },
            }

            -------------------------------------------------
            -- Target / Focus: keep exceptional unit presentation together.
            -------------------------------------------------
            local targetGeneral = target and target.args and target.args.general
            local targetHighlight = target and target.args and target.args.highlight
            if targetGeneral then
                targetGeneral.order = 10
                targetGeneral.name = BrandSection("Target")
                targetGeneral.guiInline = true
                local args = targetGeneral.args or {}
                if args.targetScale then
                    args.targetScale.name = "Scale"
                end
                if args.targetTexture then
                    args.targetTexture.name = "StatusBar Texture"
                    args.targetTexture.desc = "Texture used for the target. Focus overrides it."
                end
            end
            if targetHighlight then
                targetHighlight.order = 20
                targetHighlight.name = BrandSection("Highlight")
                targetHighlight.guiInline = true
                local args = targetHighlight.args or {}
                if args.targetHighlight then
                    args.targetHighlight.name = "Enable Highlight"
                    args.targetHighlight.desc = "Enable target tint and glow effects without changing the health fill color."
                end
                if args.targetColor then
                    args.targetColor.name = "Color"
                    args.targetColor.desc = "Highlight tint."
                end
                if args.targetBorderColor then
                    args.targetBorderColor.name = "Border Color"
                    args.targetBorderColor.desc = "Border color while highlighted."
                end
                if args.targetGlow then
                    args.targetGlow.desc = "Shows the built-in outer glow around the exterior of the health bar."
                end
            end

            local focusArgs = {
                focusScale = {
                    order = 1,
                    type = "range",
                    name = "Scale",
                    min = 0.5, max = 2, step = 0.05,
                    get = function() return CFG.enemyPlateFocusScale or 1.15 end,
                    set = function(_, v) CFG.enemyPlateFocusScale = v; SaveRefresh() end,
                },
            }
            if focusTexture then
                focusTexture.order = 2
                focusTexture.name = "StatusBar Texture"
                focusTexture.desc = "Texture used for focus. Focus overrides target."
                focusArgs.focusTexture = focusTexture
            end

            enemyArgs.targetFocus = {
                order = 30,
                type = "group",
                name = "Target / Focus",
                childGroups = "tree",
                args = {
                    targetAppearance = targetGeneral,
                    targetHighlight = targetHighlight,
                    focusAppearance = {
                        order = 30,
                        type = "group",
                        name = BrandSection("Focus"),
                        guiInline = true,
                        args = focusArgs,
                    },
                },
            }

            -------------------------------------------------
            -- Cast Bar: split geometry/behavior from state colors.
            -------------------------------------------------
            if cast and cast.args then
                local old = cast.args
                local castLayoutArgs = {}
                local castColorArgs = {}
                local colorKeys = {
                    interruptibleColor = true,
                    notInterruptibleColor = true,
                    targetPlayerColor = true,
                    interruptedColor = true,
                }

                for key, item in pairs(old) do
                    if colorKeys[key] then
                        castColorArgs[key] = item
                    else
                        castLayoutArgs[key] = item
                    end
                end

                if castColorArgs.interruptibleColor then castColorArgs.interruptibleColor.order = 1 end
                if castColorArgs.notInterruptibleColor then castColorArgs.notInterruptibleColor.order = 2 end
                if castColorArgs.targetPlayerColor then castColorArgs.targetPlayerColor.order = 3 end
                if castColorArgs.interruptedColor then castColorArgs.interruptedColor.order = 4 end

                cast.order = 40
                cast.name = "Cast Bar"
                cast.childGroups = "tree"
                cast.args = {
                    layout = {
                        order = 10,
                        type = "group",
                        name = BrandSection("Layout & Behavior"),
                        guiInline = true,
                        args = castLayoutArgs,
                    },
                    colors = {
                        order = 20,
                        type = "group",
                        name = BrandSection("Cast Colors"),
                        guiInline = true,
                        args = castColorArgs,
                    },
                }
            end

            -------------------------------------------------
            -- Auras: Buff/Debuff/Custom/Important remain aura containers; the
            -- Progressive flare is now an independent aura-driven effect.
            -------------------------------------------------
            if auras and auras.args then
                auras.order = 50
                auras.name = "Auras"
                auras.childGroups = "tree"

                auras.args.flare = {
                    order = 50,
                    type = "group",
                    name = "Flare",
                    args = {
                        enabled = {
                            order = 10,
                            type = "toggle",
                            name = "Enable Aura Flare",
                            desc = "Use Blizzard's animated Progressive flare.",
                            width = "full",
                            get = function() return CFG.enemyPlateAuraFlareEnabled ~= false end,
                            set = function(_, v) CFG.enemyPlateAuraFlareEnabled = v and true or false; SaveRefresh() end,
                        },
                        trigger = {
                            order = 20,
                            type = "select",
                            name = "Trigger Aura Category",
                            values = {
                                BUFF = "Buffs",
                                DEBUFF = "Debuffs",
                                CUSTOM = "Custom",
                                DANGER = "Important",
                            },
                            get = function() return CFG.enemyPlateAuraFlareTriggerCategory or "DANGER" end,
                            set = function(_, v) CFG.enemyPlateAuraFlareTriggerCategory = v or "DANGER"; SaveRefresh() end,
                            disabled = function() return CFG.enemyPlateAuraFlareEnabled == false end,
                        },
                        colorMode = {
                            order = 30,
                            type = "select",
                            name = "Flare Color",
                            desc = "Class uses the target player's class color when Blizzard exposes it safely. If the class is temporarily unavailable, BattleMender first reuses a class color already resolved by the health bar, then falls back to the Custom Flare Color below. NPCs continue to use their rendered health/reaction color.",
                            values = {
                                CLASS = "Class",
                                CUSTOM = "Custom",
                            },
                            get = function() return CFG.enemyPlateAuraFlareColorMode or "CUSTOM" end,
                            set = function(_, v) CFG.enemyPlateAuraFlareColorMode = v; SaveRefresh() end,
                            disabled = function() return CFG.enemyPlateAuraFlareEnabled == false end,
                        },
                        customColor = {
                            order = 31,
                            type = "color",
                            name = "Custom Flare Color",
                            desc = "Used directly in Custom mode and as the fallback when Class mode cannot safely resolve a player class color.",
                            hasAlpha = false,
                            get = function()
                                return CFG.enemyPlateAuraFlareR or 1, CFG.enemyPlateAuraFlareG or 0.12, CFG.enemyPlateAuraFlareB or 0.04
                            end,
                            set = function(_, r, g, b)
                                CFG.enemyPlateAuraFlareR = r
                                CFG.enemyPlateAuraFlareG = g
                                CFG.enemyPlateAuraFlareB = b
                                SaveRefresh()
                            end,
                            disabled = function()
                                return CFG.enemyPlateAuraFlareEnabled == false
                            end,
                        },
                        opacity = {
                            order = 40,
                            type = "range",
                            name = "Opacity",
                            min = 0, max = 1, step = 0.01, isPercent = true,
                            get = function() return CFG.enemyPlateAuraFlareOpacity or 0.88 end,
                            set = function(_, v) CFG.enemyPlateAuraFlareOpacity = v; SaveRefresh() end,
                            disabled = function() return CFG.enemyPlateAuraFlareEnabled == false end,
                        },
                        height = {
                            order = 50,
                            type = "range",
                            name = "Height",
                            min = 4, max = 100, step = 1,
                            get = function() return CFG.enemyPlateAuraFlareHeight or 31 end,
                            set = function(_, v) CFG.enemyPlateAuraFlareHeight = v; SaveRefresh() end,
                            disabled = function() return CFG.enemyPlateAuraFlareEnabled == false end,
                        },
                        density = {
                            order = 55,
                            type = "range",
                            name = "Horizontal Density",
                            desc = "Higher values pack the flame texture more tightly across the bar; lower values stretch it out.",
                            min = 0.5, max = 2.5, step = 0.05, isPercent = true,
                            get = function() return CFG.enemyPlateAuraFlareDensity or 1 end,
                            set = function(_, v) CFG.enemyPlateAuraFlareDensity = v; SaveRefresh() end,
                            disabled = function() return CFG.enemyPlateAuraFlareEnabled == false end,
                        },
                        yOffset = {
                            order = 60,
                            type = "range",
                            name = "Vertical Offset",
                            desc = "Positive values move the flames upward relative to the top of the health bar.",
                            min = -20, max = 40, step = 1,
                            get = function() return CFG.enemyPlateAuraFlareYOffset or -2 end,
                            set = function(_, v) CFG.enemyPlateAuraFlareYOffset = v; SaveRefresh() end,
                            disabled = function() return CFG.enemyPlateAuraFlareEnabled == false end,
                        },
                    },
                }
            end

            -------------------------------------------------
            -------------------------------------------------
            -- Text / Indicators: move non-bar identity/pvp elements together.
            -------------------------------------------------
            local portraitArgs = portrait and portrait.args or {}
            local objective = portraitArgs.objective
            portraitArgs.objective = nil

            if nameText then
                nameText.order = 10
                nameText.name = BrandSection("Name Text")
                nameText.guiInline = true
            end

            local portraitGroup = {
                order = 20,
                type = "group",
                name = BrandSection("Portrait"),
                guiInline = true,
                args = portraitArgs,
            }

            local pvpArgs = {}
            if objective then
                objective.order = 1
                pvpArgs.objective = objective
            end

            enemyArgs.indicators = {
                order = 60,
                type = "group",
                name = "Text / Indicators",
                childGroups = "tree",
                args = {
                    nameText = nameText,
                    portrait = portraitGroup,
                    pvp = {
                        order = 30,
                        type = "group",
                        name = BrandSection("PvP Indicators"),
                        guiInline = true,
                        args = pvpArgs,
                    },
                },
            }

            -- Remove the superseded top-level sections after their controls have
            -- been moved into the consolidated release-facing tabs above.
            enemyArgs.layout = nil
            enemyArgs.textures = nil
            enemyArgs.colors = nil
            enemyArgs.target = nil
            enemyArgs.portrait = nil
        end
    end

    -- Auras/defensive display controls are assembled here
    -- without creating a second options-registration path. The release menu
    -- restructuring above has already produced the Friendly Plates tab.
    local function SaveDefensiveSettings()
        SaveRefresh()
    end

    local defensiveOptions = {
        order = 50,
        type = "group",
        name = "Auras",
        childGroups = "tree",
        args = {
            status = {
                order = 1, type = "description", width = "full",
                name = function()
                    local module = BM.Defensives
                    if module and module.IsAuraAPIAvailable and module.IsAuraAPIAvailable() then
                        return "|cff33ff99WoW 12.1 AuraContainer ready.|r Blizzard selects and times the auras; BattleMender controls their presentation."
                    end
                    return "|cffffcc00AuraContainer is unavailable.|r Aura displays need the WoW 12.1 Blizzard_AuraContainer module."
                end,
            },
            general = {
                order = 15, type = "group", name = BrandSection("General"), guiInline = true,
                args = {
                    enabled = { order = 1, type = "toggle", name = "Enable Aura Displays", width = "full", get = function() return CFG.defensiveDisplayEnabled ~= false end, set = function(_, v) CFG.defensiveDisplayEnabled = v and true or false; SaveDefensiveSettings() end },
                    major = { order = 2, type = "toggle", name = "Show Major Defensives", get = function() return CFG.majorDefensiveEnabled ~= false end, set = function(_, v) CFG.majorDefensiveEnabled = v and true or false; SaveDefensiveSettings() end },
                    immunity = { order = 3, type = "toggle", name = "Show Immunities", get = function() return CFG.immunityDisplayEnabled ~= false end, set = function(_, v) CFG.immunityDisplayEnabled = v and true or false; SaveDefensiveSettings() end },
                    objectives = { order = 4, type = "toggle", name = "Show Objectives", get = function() return CFG.objectivesEnabled ~= false end, set = function(_, v) CFG.objectivesEnabled = v and true or false; SaveDefensiveSettings() end },
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
            objectives = {
                order = 10, type = "group", name = BrandSection("Objectives"), guiInline = true,
                args = {
                    info = { order = 0, type = "description", width = "full", name = "Shows battleground objectives like flags, orbs, carts, and bounties as a separate radial badge, while preserving the centre spec icon and health display." },
                    enabled = { order = 1, type = "toggle", name = "Enable", get = function() return CFG.objectivesEnabled ~= false end, set = function(_, v) CFG.objectivesEnabled = v and true or false; SaveDefensiveSettings() end },
                    test = { order = 1.5, type = "execute", name = "Test Objectives", desc = "Shows a BattleMender-owned objective carrier preview using the current Objectives settings. The preview closes in combat.", func = function() if BM.Defensives then BM.Defensives.ShowPreview("OBJECTIVE") end end },
                    scale = { order = 2, type = "range", name = "Badge Size", min = .35, max = 1.6, step = .01, get = function() return CFG.objectivesBadgeScale or .72 end, set = function(_, v) CFG.objectivesBadgeScale = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    layer = { order = 3, type = "select", name = "Layer", values = { BEHIND = "Behind Plate", FRONT = "In Front of Plate" }, get = function() return CFG.objectivesLayer or "BEHIND" end, set = function(_, v) CFG.objectivesLayer = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    distance = { order = 4, type = "range", name = "Radial Distance", desc = "Distance as a proportion of Icon Size, so the badge stays aligned when the plate is resized.", min = 0, max = 1.5, step = .01, get = function() return CFG.objectivesDistanceScale or .53 end, set = function(_, v) CFG.objectivesDistanceScale = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    angle = { order = 5, type = "range", name = "Angle", desc = "0 degrees is right and 90 degrees is up.", min = 0, max = 360, step = 1, get = function() return CFG.objectivesAngle or 42 end, set = function(_, v) CFG.objectivesAngle = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    border = { order = 10, type = "select", name = "Border Texture", values = { NONE = "None", THIN = "Circle - Thin", NORMAL = "Circle - Standard", METAL = "Circle - Heavy", COGWHEEL = "Defensive Cogwheel" }, get = function() return CFG.objectivesBorderTexture or "COGWHEEL" end, set = function(_, v) CFG.objectivesBorderTexture = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    borderScale = { order = 11, type = "range", name = "Border Size", min = .9, max = 1.8, step = .01, get = function() return CFG.objectivesBorderScale or 1.18 end, set = function(_, v) CFG.objectivesBorderScale = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesBorderTexture == "NONE" end },
                    borderAlpha = { order = 12, type = "range", name = "Border Opacity", min = 0, max = 1, step = .01, get = function() return CFG.objectivesBorderAlpha or 1 end, set = function(_, v) CFG.objectivesBorderAlpha = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesBorderTexture == "NONE" end },
                    colorMode = { order = 13, type = "select", name = "Border Color", desc = "Auto uses the friendly player's class color so the objective badge still identifies class while the centre spec icon remains unchanged.", values = { AUTO = "Auto", WHITE = "White", CUSTOM = "Custom" }, get = function() return CFG.objectivesBorderColorMode or "AUTO" end, set = function(_, v) CFG.objectivesBorderColorMode = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesBorderTexture == "NONE" end },
                    customColor = { order = 14, type = "color", name = "Custom Border Color", hasAlpha = false, get = function() return CFG.objectivesCustomR or .3, CFG.objectivesCustomG or .72, CFG.objectivesCustomB or 1 end, set = function(_, r, g, b) CFG.objectivesCustomR = r; CFG.objectivesCustomG = g; CFG.objectivesCustomB = b; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesBorderTexture == "NONE" or CFG.objectivesBorderColorMode ~= "CUSTOM" end },
                    glow = { order = 20, type = "toggle", name = "Badge Glow", get = function() return CFG.objectivesGlowEnabled ~= false end, set = function(_, v) CFG.objectivesGlowEnabled = v and true or false; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    glowAlpha = { order = 21, type = "range", name = "Glow Opacity", min = 0, max = 1, step = .01, get = function() return CFG.objectivesGlowAlpha or .46 end, set = function(_, v) CFG.objectivesGlowAlpha = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesGlowEnabled == false end },
                    glowScale = { order = 22, type = "range", name = "Glow Size", min = 1, max = 3, step = .01, get = function() return CFG.objectivesGlowScale or 2.25 end, set = function(_, v) CFG.objectivesGlowScale = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesGlowEnabled == false end },
                    glowSpeed = { order = 23, type = "range", name = "Glow Speed", desc = "Seconds for each half of the badge glow pulse.", min = .15, max = 2.5, step = .05, get = function() return CFG.objectivesGlowSpeed or .9 end, set = function(_, v) CFG.objectivesGlowSpeed = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesGlowEnabled == false end },
                    pulse = { order = 24, type = "toggle", name = "Pulse Icon", get = function() return CFG.objectivesPulse ~= false end, set = function(_, v) CFG.objectivesPulse = v and true or false; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false end },
                    pulseSpeed = { order = 25, type = "range", name = "Pulse Speed", desc = "Seconds for each half of the objective icon pulse.", min = .15, max = 2.5, step = .05, get = function() return CFG.objectivesPulseSpeed or .9 end, set = function(_, v) CFG.objectivesPulseSpeed = v; SaveDefensiveSettings() end, disabled = function() return CFG.objectivesEnabled == false or CFG.objectivesPulse == false end },
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
                order = 40, type = "group", name = BrandSection("Aura Preview"), guiInline = true,
                args = {
                    info = { order = 0, type = "description", width = "full", name = "The preview is BattleMender-owned and closes with the options window or when combat begins." },
                    objective = { order = 1, type = "execute", name = "Preview Objectives", func = function() if BM.Defensives then BM.Defensives.ShowPreview("OBJECTIVE") end end },
                    major = { order = 2, type = "execute", name = "Preview Major", func = function() if BM.Defensives then BM.Defensives.ShowPreview("MAJOR") end end },
                    immunity = { order = 3, type = "execute", name = "Preview Immunity", func = function() if BM.Defensives then BM.Defensives.ShowPreview("IMMUNITY") end end },
                    both = { order = 4, type = "execute", name = "Preview Auras", func = function() if BM.Defensives then BM.Defensives.ShowPreview("BOTH") end end },
                    hide = { order = 5, type = "execute", name = "Hide Preview", func = function() if BM.Defensives then BM.Defensives.HidePreview() end end },
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

    -------------------------------------------------
    -- 15.0 navigation cleanup
    -- One vertical navigation model, BattleMender-owned interaction controls,
    -- and one shared Friendly Preview harness for health / LoS / objective / aura tests.
    -------------------------------------------------
    do
        options.childGroups = "tree"

        local general = options.args.general
        local friendlyPlates = options.args.normal
        local enemyPlates = options.args.enemyPlates
        local compatibility = options.args.compatibility

        local function NotifyOptionsChanged()
            if not LibStub then return end
            local registry = LibStub("AceConfigRegistry-3.0", true)
            if registry and registry.NotifyChange then
                pcall(registry.NotifyChange, registry, APP_NAME)
            end
        end

        local function ShowFriendlyPreview(kind)
            if InCombatLockdown and InCombatLockdown() then return end
            if BM.Defensives and BM.Defensives.ShowPreview then
                BM.Defensives.ShowPreview(kind or "CURRENT")
                NotifyOptionsChanged()
            end
        end

        -------------------------------------------------
        -- Quick setup presets. These intentionally touch only a small, visible
        -- set of settings so users can choose a style/playstyle and still fine
        -- tune everything normally afterwards.
        -------------------------------------------------
        local VISUAL_PRESETS = {
            BATTLEMENDER = {
                ringEnabled = true,
                ringTexture = "plastic_ring",
                ringFineTune = 1.00,
                ringAlpha = 1,
                accentOverlayEnabled = true,
                accentOverlayTexture = "Glass_Ring",
                accentOverlayScale = 0.95,
                accentOverlayAlpha = 1,
                accentOverlayBlendMode = "ADD",
                specGlowEnabled = true,
                ringGlowEnabled = true,
                pulseEnable = true,
                haloEnabled = false,
            },
            SIMPLE = {
                ringEnabled = true,
                ringTexture = "Ring_20px",
                ringFineTune = 1.00,
                ringAlpha = 1,
                accentOverlayEnabled = false,
                specGlowEnabled = false,
                ringGlowEnabled = false,
                pulseEnable = false,
                haloEnabled = false,
            },
            BOLD = {
                ringEnabled = true,
                ringTexture = "Ring_30px",
                ringFineTune = 1.00,
                ringAlpha = 1,
                accentOverlayEnabled = true,
                accentOverlayTexture = "Glass_Ring",
                accentOverlayScale = 0.95,
                accentOverlayAlpha = 1,
                accentOverlayBlendMode = "ADD",
                specGlowEnabled = true,
                ringGlowEnabled = true,
                pulseEnable = true,
                haloEnabled = true,
                haloGlowSizeScale = 2,
                haloGlowAlpha = 0.5,
            },
        }

        local function MatchesPreset(preset)
            if not preset then return false end
            for key, value in pairs(preset) do
                if CFG[key] ~= value then return false end
            end
            return true
        end

        local function GetCurrentVisualPreset()
            if MatchesPreset(VISUAL_PRESETS.BATTLEMENDER) then return "BattleMender" end
            if MatchesPreset(VISUAL_PRESETS.SIMPLE) then return "Simple" end
            if MatchesPreset(VISUAL_PRESETS.BOLD) then return "Bold" end
            return "Custom"
        end

        local function ApplyVisualPreset(key)
            local preset = VISUAL_PRESETS[key]
            if not preset then return end
            for setting, value in pairs(preset) do
                CFG[setting] = value
            end
            -- Keep LoS as a stable, restrained third-party-independent state:
            -- standard class border, reduced opacity, and no accent overlay.
            CFG.losRingTexture = "Ring_20px"
            CFG.losRingAlpha = 0.7
            CFG.losAccentOverlayTexture = "NONE"
            SaveRefresh()
            NotifyOptionsChanged()
        end

        local function ApplyQuickInteraction()
            if BM.SetFriendlyClickbox then
                BM.SetFriendlyClickbox()
            elseif BM.ApplyNameplateInteractibility then
                BM.ApplyNameplateInteractibility()
            end
            SaveRefresh()
            NotifyOptionsChanged()
        end

        local function ApplyFriendlyInteractionPreset(kind)
            if kind == "HEALING" then
                CFG.friendlyClickthrough = false
                CFG.clickSize = 72
            elseif kind == "INFO" then
                CFG.friendlyClickthrough = true
                CFG.clickSize = 50
            else
                return
            end
            ApplyQuickInteraction()
        end

        local function ApplyEnemyInteractionPreset(kind)
            if kind == "CLICKABLE" then
                CFG.enemyPlateClickthrough = false
            elseif kind == "TAB" then
                CFG.enemyPlateClickthrough = true
            else
                return
            end
            ApplyQuickInteraction()
        end

        local function ApplyPlaystylePreset(kind)
            if kind == "HEALER" then
                CFG.friendlyClickthrough = false
                CFG.enemyPlateClickthrough = true
                CFG.clickSize = 72
            elseif kind == "DPS" then
                CFG.friendlyClickthrough = true
                CFG.enemyPlateClickthrough = false
                CFG.clickSize = 50
            else
                return
            end

            -- Blizzard exposes stacking as one global nameplate motion mode, not
            -- independent friendly/enemy stacking. Both recommended playstyles
            -- use stacking; the user-facing toggle immediately below can change it.
            SetNameplateStacking(true)
            ApplyQuickInteraction()
        end

        local function GetCurrentPlaystylePreset()
            local stacked = GetNameplateStacking()
            if stacked and CFG.friendlyClickthrough ~= true and CFG.enemyPlateClickthrough == true and (tonumber(CFG.clickSize) or 0) == 72 then
                return "Healer / Hybrid"
            end
            if stacked and CFG.friendlyClickthrough == true and CFG.enemyPlateClickthrough ~= true and (tonumber(CFG.clickSize) or 0) == 50 then
                return "DPS / Information"
            end
            return "Custom"
        end

        -------------------------------------------------
        -- General: global behavior + Blizzard nameplate CVars.
        -------------------------------------------------
        local blizzard = options.args.blizzardCVars
        options.args.blizzardCVars = nil

        if general and general.args then
            general.order = 10
            general.name = "General"
            general.args.status = nil

            -- Developer Mode is a Friendly Plates concern, not global behavior.
            local developerMode = general.args.developerMode
            general.args.developerMode = nil

            general.args.quickSetup = {
                order = 5,
                type = "group",
                name = BrandSection("Quick Setup"),
                guiInline = true,
                args = {
                    appearanceHeading = {
                        order = 1, type = "description", width = "full",
                        name = "|cffffd100Appearance|r  |cff9fa4a8Choose a starting look. Detailed Friendly Plate settings remain available afterwards.|r",
                    },
                    appearanceStatus = {
                        order = 2, type = "description", width = "full",
                        name = function() return "Current: |cff9cff00" .. GetCurrentVisualPreset() .. "|r" end,
                    },
                    appearanceBattleMender = {
                        order = 3, type = "execute", name = "BattleMender", width = 0.95,
                        desc = "Plastic Ring + Glass panel with BattleMender's balanced hover and pulse effects.",
                        func = function() ApplyVisualPreset("BATTLEMENDER") end,
                    },
                    appearanceSimple = {
                        order = 4, type = "execute", name = "Simple", width = 0.95,
                        desc = "Standard class border with no glass panel, pulse, halo, or hover glows.",
                        func = function() ApplyVisualPreset("SIMPLE") end,
                    },
                    appearanceBold = {
                        order = 5, type = "execute", name = "Bold", width = 0.95,
                        desc = "Heavy class border + Glass panel with stronger visual emphasis and halo.",
                        func = function() ApplyVisualPreset("BOLD") end,
                    },

                    playstyleHeading = {
                        order = 10, type = "description", width = "full",
                        name = "\n|cffffd100Playstyle|r  |cff9fa4a8One-click interaction setup. These are recommendations, not role restrictions.|r",
                    },
                    playstyleStatus = {
                        order = 11, type = "description", width = "full",
                        name = function() return "Current: |cff9cff00" .. GetCurrentPlaystylePreset() .. "|r" end,
                    },
                    playstyleHealer = {
                        order = 12, type = "execute", name = "Healer / Hybrid", width = 1.35,
                        desc = "Large clickable friendly targets for mouseover/click healing; enemy plates click through for tab targeting; stacking enabled.",
                        func = function() ApplyPlaystylePreset("HEALER") end,
                    },
                    playstyleDPS = {
                        order = 13, type = "execute", name = "DPS / Information", width = 1.35,
                        desc = "Friendly plates are information-only and click through; enemy plates remain clickable; stacking enabled.",
                        func = function() ApplyPlaystylePreset("DPS") end,
                    },

                    interactionHeading = {
                        order = 20, type = "description", width = "full",
                        name = "\n|cffffd100Interaction Fine Tune|r",
                    },
                    friendlyInteractionLabel = {
                        order = 21, type = "description", width = "full",
                        name = function()
                            local mode = CFG.friendlyClickthrough == true and "Information Only" or "Mouseover / Healing"
                            return "Friendly: |cffc4c9cc" .. mode .. "|r   Clickbox: |cffc4c9cc" .. tostring(math.floor((tonumber(CFG.clickSize) or 0) + 0.5)) .. "|r"
                        end,
                    },
                    friendlyHealing = {
                        order = 22, type = "execute", name = "Mouseover / Healing", width = 1.35,
                        desc = "Friendly clickthrough Off; friendly clickbox 72px. Visible Icon Size is not changed.",
                        func = function() ApplyFriendlyInteractionPreset("HEALING") end,
                    },
                    friendlyInfo = {
                        order = 23, type = "execute", name = "Information Only", width = 1.35,
                        desc = "Friendly clickthrough On; friendly clickbox reduced to 50px. Visible Icon Size is not changed.",
                        func = function() ApplyFriendlyInteractionPreset("INFO") end,
                    },
                    enemyInteractionLabel = {
                        order = 24, type = "description", width = "full",
                        name = function()
                            return "Enemy: |cffc4c9cc" .. (CFG.enemyPlateClickthrough == true and "Tab Target / Clickthrough" or "Clickable") .. "|r"
                        end,
                    },
                    enemyClickable = {
                        order = 25, type = "execute", name = "Clickable", width = 1.35,
                        desc = "Enemy plates accept mouse interaction.",
                        func = function() ApplyEnemyInteractionPreset("CLICKABLE") end,
                    },
                    enemyTab = {
                        order = 26, type = "execute", name = "Tab Target / Clickthrough", width = 1.35,
                        desc = "BattleMender enemy plates ignore mouse interaction; target enemies with keyboard/tab targeting.",
                        func = function() ApplyEnemyInteractionPreset("TAB") end,
                    },
                    stacking = {
                        order = 30, type = "toggle", name = "Stack Nameplates", width = "normal",
                        desc = "Blizzard exposes one nameplate stacking mode, so this applies to friendly and enemy plates together.",
                        get = GetNameplateStacking,
                        set = function(_, v) SetNameplateStacking(v); NotifyOptionsChanged() end,
                    },
                    stackingNote = {
                        order = 31, type = "description", width = "double",
                        name = "|cff7e858aFriendly and enemy stacking cannot be configured independently with Blizzard's current nameplate motion control.|r",
                    },
                },
            }

            if blizzard then
                blizzard.order = 70
                blizzard.name = BrandSection("Blizzard Nameplates")
                blizzard.guiInline = true
                blizzard.childGroups = nil
                blizzard.args = blizzard.args or {}
                blizzard.args.clickthrough = nil
                for _, key in ipairs({ "stacking", "scaling", "alpha" }) do
                    local group = blizzard.args[key]
                    if group then
                        group.guiInline = true
                        group.childGroups = nil
                    end
                end
                if blizzard.args.stacking and blizzard.args.stacking.args then
                    blizzard.args.stacking.name = BrandLabel("Stacking Spacing")
                    blizzard.args.stacking.args.nameplateMotion = nil
                end
                general.args.blizzardNameplates = blizzard
            end

            local generalSettings = general.args.generalGroup and general.args.generalGroup.args
            if generalSettings then
                generalSettings.repairElvUIDisabledNameplates = nil
                generalSettings.runElvUIRepair = nil
            end

            -------------------------------------------------
            -- Environment: context-specific visibility and sizing. Keep these
            -- rules out of Friendly/Enemy appearance pages so users can reason
            -- about where a plate changes separately from how it looks.
            -------------------------------------------------
            local instanceBehavior = general.args.instanceBehavior
            general.args.instanceBehavior = nil
            if instanceBehavior then
                instanceBehavior.order = 30
                instanceBehavior.name = "Instanced PvE"
                instanceBehavior.guiInline = nil
            end

            options.args.environment = {
                order = 15,
                type = "group",
                name = "Environment",
                childGroups = "tree",
                args = {
                    arena = {
                        order = 10,
                        type = "group",
                        name = "Arena",
                        args = {
                            info = {
                                order = 1, type = "description", width = "full",
                                name = "Arena multipliers apply in normal arenas and Training Grounds: Arena. They multiply your normal BattleMender sizes rather than replacing them.",
                            },
                            friendlyScale = {
                                order = 2, type = "range", name = "Friendly Plate Scale",
                                desc = "Scales BattleMender's friendly visuals in arenas. The friendly clickbox uses the same multiplier when Blizzard's protected size API can be updated safely; combat changes are deferred until combat ends.",
                                min = 1, max = 2, step = 0.05, isPercent = true,
                                get = function() return CFG.arenaFriendlyPlateScale or 1 end,
                                set = function(_, v) CFG.arenaFriendlyPlateScale = v; SaveRefreshClickbox() end,
                            },
                            enemyScale = {
                                order = 3, type = "range", name = "Enemy Plate Scale",
                                desc = "Scales BattleMender-owned enemy plate visuals in arenas. This stacks with the normal Enemy Plates > Health Bar scale and target/focus multipliers.",
                                min = 1, max = 2, step = 0.05, isPercent = true,
                                get = function() return CFG.arenaEnemyPlateScale or 1 end,
                                set = function(_, v) CFG.arenaEnemyPlateScale = v; SaveRefresh() end,
                            },
                        },
                    },
                    friendlyVisibility = {
                        order = 20,
                        type = "group",
                        name = "Friendly Visibility",
                        args = {
                            groupOnly = {
                                order = 10, type = "group", name = BrandSection("Show Group Members Only"), guiInline = true,
                                args = {
                                    world = { order = 1, type = "toggle", name = "World", get = function() return CFG.friendlyGroupOnlyWorld == true end, set = function(_, v) CFG.friendlyGroupOnlyWorld = v and true or false; SaveRefresh() end },
                                    rest = { order = 2, type = "toggle", name = "City / Rest Area", get = function() return CFG.friendlyGroupOnlyRest == true end, set = function(_, v) CFG.friendlyGroupOnlyRest = v and true or false; SaveRefresh() end },
                                    bg = { order = 3, type = "toggle", name = "Battleground", get = function() return CFG.friendlyGroupOnlyBG == true end, set = function(_, v) CFG.friendlyGroupOnlyBG = v and true or false; SaveRefresh() end },
                                },
                            },
                            hide = {
                                order = 20, type = "group", name = BrandSection("Hide Friendly Plates"), guiInline = true,
                                args = {
                                    world = { order = 1, type = "toggle", name = "World", get = function() return CFG.friendlyHideWorld == true end, set = function(_, v) CFG.friendlyHideWorld = v and true or false; SaveRefresh() end },
                                    rest = { order = 2, type = "toggle", name = "City / Rest Area", get = function() return CFG.friendlyHideRest == true end, set = function(_, v) CFG.friendlyHideRest = v and true or false; SaveRefresh() end },
                                    bg = { order = 3, type = "toggle", name = "Battleground", get = function() return CFG.friendlyHideBG == true end, set = function(_, v) CFG.friendlyHideBG = v and true or false; SaveRefresh() end },
                                },
                            },
                            exceptions = {
                                order = 25, type = "group", name = BrandSection("Keep Visible When Hidden"), guiInline = true,
                                args = {
                                    party = { order = 1, type = "toggle", name = "Party / Pre-BG Group", desc = "Uses the HOME group, so battleground members who queued with you remain visible without treating the whole BG raid as your party.", get = function() return CFG.friendlyHideKeepParty ~= false end, set = function(_, v) CFG.friendlyHideKeepParty = v and true or false; SaveRefresh() end },
                                    guild = { order = 2, type = "toggle", name = "Guild", get = function() return CFG.friendlyHideKeepGuild ~= false end, set = function(_, v) CFG.friendlyHideKeepGuild = v and true or false; SaveRefresh() end },
                                    friends = { order = 3, type = "toggle", name = "Friends List", get = function() return CFG.friendlyHideKeepFriends ~= false end, set = function(_, v) CFG.friendlyHideKeepFriends = v and true or false; if BM.RefreshAffiliateFriendCache then BM.RefreshAffiliateFriendCache(true) end; SaveRefresh() end },
                                },
                            },
                            note = {
                                order = 30, type = "description", width = "full",
                                name = "|cff7e858aWhen Hide Friendly Plates is enabled, selected Party/Guild/Friends exceptions remain visible. Show Group Members Only still applies when Hide is off. Arena is intentionally unaffected. Blizzard's optional friendly-player name remains independent.|r",
                            },
                        },
                    },
                    pve = instanceBehavior,
                },
            }

            -------------------------------------------------
            -- Friendly Plates branch.
            -------------------------------------------------
            if friendlyPlates and friendlyPlates.args then
                friendlyPlates.order = 20
                friendlyPlates.name = "Friendly Plates"
                friendlyPlates.childGroups = "tree"
                friendlyPlates.disabled = nil

                local function HealerColor(order, name, prefix, disabled)
                    return {
                        order=order, type="color", name=name, hasAlpha=false, disabled=disabled,
                        get=function() return CFG[prefix .. "R"], CFG[prefix .. "G"], CFG[prefix .. "B"] end,
                        set=function(_, r, g, b)
                            CFG[prefix .. "R"], CFG[prefix .. "G"], CFG[prefix .. "B"] = r, g, b
                            SaveRefresh()
                        end,
                    }
                end
                local function HealerDisabled() return CFG.healerCrossEnabled ~= true end

                friendlyPlates.args.affiliates = {
                    order=24, type="group", name="Affiliates",
                    args={
                        relationships={
                            order=10, type="group", name=BrandSection("Relationships"), guiInline=true,
                            args={
                                info={order=1, type="description", width="full", name="Affiliates apply to all friendly players, not only healers. Party uses WoW's HOME group: your normal group in the world and your pre-BG group inside battlegrounds."},
                                party={order=2, type="toggle", name="Party / Pre-BG Group", get=function() return CFG.affiliateParty ~= false end, set=function(_, v) CFG.affiliateParty=v and true or false; SaveRefresh() end},
                                guild={order=3, type="toggle", name="Guild", get=function() return CFG.affiliateGuild ~= false end, set=function(_, v) CFG.affiliateGuild=v and true or false; SaveRefresh() end},
                                friend={order=4, type="toggle", name="Friends List", desc="Includes character friends and Battle.net friends when WoW exposes the friend's current WoW character/GUID.", get=function() return CFG.affiliateFriend ~= false end, set=function(_, v) CFG.affiliateFriend=v and true or false; if BM.RefreshAffiliateFriendCache then BM.RefreshAffiliateFriendCache(true) end; SaveRefresh() end},
                            },
                        },
                        emphasis={
                            order=20, type="group", name=BrandSection("Plate Emphasis"), guiInline=true,
                            args={
                                scale={order=1, type="range", name="Affiliate Plate Scale", desc="Visually enlarges BattleMender's plate for affiliates. This is per-player visual scaling only; the Blizzard friendly clickbox remains global and is not enlarged.", min=1, max=1.5, step=.01, isPercent=true, get=function() return CFG.affiliatePlateScale or 1.15 end, set=function(_, v) CFG.affiliatePlateScale=v; SaveRefresh() end},
                            },
                        },
                        badge={
                            order=30, type="group", name=BrandSection("Star Badge"), guiInline=true,
                            args={
                                enabled={order=1, type="toggle", name="Show Star Badge", width="full", get=function() return CFG.affiliateBadgeEnabled ~= false end, set=function(_, v) CFG.affiliateBadgeEnabled=v and true or false; SaveRefresh() end},
                                texture={
                                    order=2, type="select", name="Star Texture",
                                    values={ GOLD="Gold Star", SILVER="Silver Star", BRONZE="Bronze Star", DECO="Deco Star" },
                                    sorting={ "GOLD", "SILVER", "BRONZE", "DECO" },
                                    get=function() return BM.NormalizeAffiliateBadgeTextureKey(CFG.affiliateBadgeTexture) end,
                                    set=function(_, v) CFG.affiliateBadgeTexture=BM.NormalizeAffiliateBadgeTextureKey(v); SaveRefresh() end,
                                    disabled=function() return CFG.affiliateBadgeEnabled == false end,
                                },
                                preview={order=3, type="execute", name="Preview Affiliate Badge", func=function() ShowFriendlyPreview("AFFILIATE") end, disabled=function() return CFG.affiliateBadgeEnabled == false or (InCombatLockdown and InCombatLockdown()) end},
                                size={order=4, type="range", name="Badge Size", min=.30, max=1.0, step=.01, isPercent=true, get=function() return CFG.affiliateBadgeScale or .56 end, set=function(_, v) CFG.affiliateBadgeScale=v; SaveRefresh() end, disabled=function() return CFG.affiliateBadgeEnabled == false end},
                                distance={order=5, type="range", name="Distance", min=0, max=1.5, step=.01, isPercent=true, get=function() return CFG.affiliateBadgeDistanceScale or .64 end, set=function(_, v) CFG.affiliateBadgeDistanceScale=v; SaveRefresh() end, disabled=function() return CFG.affiliateBadgeEnabled == false end},
                                angle={order=6, type="range", name="Angle", min=0, max=360, step=1, get=function() return CFG.affiliateBadgeAngle or 42 end, set=function(_, v) CFG.affiliateBadgeAngle=v; SaveRefresh() end, disabled=function() return CFG.affiliateBadgeEnabled == false end},
                                note={order=7, type="description", width="full", name="The center glyph shows the highest-priority relationship: P (Party) > G (Guild) > F (Friend)."},
                            },
                        },
                    },
                }

                friendlyPlates.args.healers = {
                    order=25, type="group", name="Healer Appearance",
                    args={
                        enabled={
                            order=1, type="toggle", name="Enable Healer Cross", width="full",
                            desc="Replaces healer spec artwork with a health-aware role presentation: healthy regions use the healer background + green cross, while missing-health regions use the normal damaged color + a separate damaged cross color. Keeps the class ring.",
                            get=function() return CFG.healerCrossEnabled == true end,
                            set=function(_, v) CFG.healerCrossEnabled = v; SaveRefresh() end,
                        },
                        preview={
                            order=2, type="execute", name="Test Healer",
                            disabled=function() return HealerDisabled() or (InCombatLockdown and InCombatLockdown()) end,
                            func=function() ShowFriendlyPreview("HEALER") end,
                        },
                        background={
                            order=10, type="group", name=BrandSection("Healthy Background"), guiInline=true, disabled=HealerDisabled,
                            args={
                                colorMode={
                                    order=1, type="select", name="Color",
                                    desc="Class uses the friendly healer's (target) class color. Custom uses the RGB color below.",
                                    values={ CLASS="Class (Target)", CUSTOM="Custom" },
                                    get=function() return CFG.healerBackgroundColorMode or "CLASS" end,
                                    set=function(_, v)
                                        CFG.healerBackgroundColorMode = v
                                        CFG.healerBackgroundUseClassColor = (v == "CLASS") -- legacy mirror
                                        SaveRefresh()
                                    end,
                                },
                                color=HealerColor(2, "Custom Background Color", "healerBackground", function() return HealerDisabled() or (CFG.healerBackgroundColorMode or "CLASS") ~= "CUSTOM" end),
                                brightness={
                                    order=3, type="range", name="Background Brightness", min=0, max=1, step=0.01, isPercent=true,
                                    get=function() return CFG.healerBackgroundBrightness end,
                                    set=function(_, v) CFG.healerBackgroundBrightness = v; SaveRefresh() end,
                                },
                                note={order=4, type="description", width="full", name="Class (Target) is the default healthy background. Missing health still uses the normal Friendly Health damaged color, with the separate damaged-cross color above it."},
                            },
                        },
                        cross={
                            order=20, type="group", name=BrandSection("Health Cross"), guiInline=true, disabled=HealerDisabled,
                            args={
                                normal=HealerColor(1, "Healthy Cross Color", "healerCross", HealerDisabled),
                                damaged=HealerColor(2, "Damaged Cross Color", "healerDamageCross", HealerDisabled),
                                size={
                                    order=3, type="range", name="Cross Size", min=0.4, max=1.3, step=0.01, isPercent=true,
                                    desc="Scales both cross layers independently of the circular background and class ring.",
                                    get=function() return CFG.healerCrossScale end,
                                    set=function(_, v) CFG.healerCrossScale = v; SaveRefresh() end,
                                },
                                note={order=4, type="description", name="The health boundary clips both the background and the cross. The healthy region uses Healthy Background + Healthy Cross; the missing-health region uses Damage Color + Damaged Cross.", width="full"},
                            },
                        },
                        control={
                            order=30, type="group", name=BrandSection("CC / Silence Badge"), guiInline=true, disabled=HealerDisabled,
                            args={
                                enabled={
                                    order=1, type="toggle", name="Show CC / Silence Badge", width="full",
                                    desc="Shows a separate badge with the actual aura icon for hard loss-of-control effects (stuns, incapacitations and disorients) or silence. Roots, slows, knockbacks and interrupt school lockouts are ignored. If Blizzard cannot safely apply the spell allow-list, the warning is suppressed instead of risking a false positive.",
                                    get=function() return CFG.healerControlEnabled == true end,
                                    set=function(_, v) CFG.healerControlEnabled = v; SaveRefresh() end,
                                },
                                colorMode={
                                    order=2, type="select", name="Accent Color",
                                    desc="Class uses the friendly healer's (target) class color. It never uses your class or the CC caster's class.",
                                    values={ CLASS="Class (Target)", CUSTOM="Custom" },
                                    get=function() return CFG.healerControlColorMode or "CLASS" end,
                                    set=function(_, v) CFG.healerControlColorMode=v; SaveRefresh() end,
                                    disabled=function() return HealerDisabled() or not CFG.healerControlEnabled end,
                                },
                                accent=HealerColor(3, "Custom Accent Color", "healerControl", function() return HealerDisabled() or not CFG.healerControlEnabled or (CFG.healerControlColorMode or "CLASS") ~= "CUSTOM" end),
                                size={
                                    order=4, type="range", name="Badge Size", min=.35, max=1.4, step=.01, isPercent=true,
                                    get=function() return CFG.healerControlBadgeScale or .64 end,
                                    set=function(_, v) CFG.healerControlBadgeScale=v; SaveRefresh() end,
                                    disabled=function() return HealerDisabled() or not CFG.healerControlEnabled end,
                                },
                                distance={
                                    order=5, type="range", name="Distance", min=0, max=1.5, step=.01, isPercent=true,
                                    get=function() return CFG.healerControlDistanceScale or .58 end,
                                    set=function(_, v) CFG.healerControlDistanceScale=v; SaveRefresh() end,
                                    disabled=function() return HealerDisabled() or not CFG.healerControlEnabled end,
                                },
                                angle={
                                    order=6, type="range", name="Angle", min=0, max=360, step=1,
                                    get=function() return CFG.healerControlAngle or 138 end,
                                    set=function(_, v) CFG.healerControlAngle=v; SaveRefresh() end,
                                    disabled=function() return HealerDisabled() or not CFG.healerControlEnabled end,
                                },
                                note={order=7, type="description", width="full", name="Class (Target) is the default accent. The former center-cross CC recolor remains represented by the same saved custom accent color, but live CC is now separated into this badge so healer health remains readable."},
                            },
                        },
                    },
                }

                developerMode = developerMode or {
                    type = "toggle",
                    name = "Developer Mode",
                    get = function() return CFG.developerMode == true end,
                    set = function(_, v) CFG.developerMode = v and true or false; SaveRefresh(); NotifyOptionsChanged() end,
                }
                developerMode.order = 10
                developerMode.name = "Developer Mode"
                developerMode.desc = "Unlocks advanced Friendly Health and visual tuning controls. Preview remains available without Developer Mode."
                developerMode.width = "full"
                developerMode.disabled = nil

                friendlyPlates.args.general = {
                    order = 5,
                    type = "group",
                    name = "General",
                    args = {
                        developerMode = developerMode,
                        blizzardFriendlyElements = {
                            order = 15,
                            type = "group",
                            name = BrandSection("Blizzard Friendly Plate"),
                            guiInline = true,
                            args = {
                                hideHealthArt = {
                                    order = 1,
                                    type = "toggle",
                                    name = "Hide Blizzard Health Bar / Art",
                                    desc = "Uses Blizzard's friendly names-only presentation so the native horizontal health bar and plate art do not appear behind BattleMender. The Blizzard player name can remain visible independently.",
                                    get = function() return CFG.hideBlizzardFriendlyHealthArt ~= false end,
                                    set = function(_, v) CFG.hideBlizzardFriendlyHealthArt = v and true or false; SaveRefresh() end,
                                },
                                hidePlayerName = {
                                    order = 2,
                                    type = "toggle",
                                    name = "Hide Blizzard Player Name",
                                    desc = "Hides Blizzard's friendly-player name text independently of the native health bar/art setting.",
                                    get = function() return CFG.hideBlizzardFriendlyPlayerName == true end,
                                    set = function(_, v) CFG.hideBlizzardFriendlyPlayerName = v and true or false; SaveRefresh() end,
                                },
                            },
                        },
                        interaction = {
                            order = 20,
                            type = "group",
                            name = BrandSection("Interaction"),
                            guiInline = true,
                            args = {
                                clickthrough = {
                                    order = 1,
                                    type = "toggle",
                                    name = "Clickthrough",
                                    desc = "Makes BattleMender friendly plates ignore mouse interaction. Turn this off when you want friendly plates to be clickable again.",
                                    get = function() return CFG.friendlyClickthrough == true end,
                                    set = function(_, v) CFG.friendlyClickthrough = v and true or false; SaveRefreshInteraction() end,
                                },
                            },
                        },
                    },
                }

                -- Rename the module-facing key while keeping the internal Lua
                -- module name stable for compatibility with existing code.
                local auras = friendlyPlates.args.defensives or friendlyPlates.args.auras
                friendlyPlates.args.defensives = nil
                if auras then
                    auras.order = 30
                    auras.name = "Auras"
                    auras.childGroups = "tree"
                    auras.args = auras.args or {}

                    local auraGeneral = auras.args.general
                    if auraGeneral and auraGeneral.args then
                        local master = auraGeneral.args.enabled
                        local majorToggle = auraGeneral.args.major
                        local immunityToggle = auraGeneral.args.immunity
                        local objectivesToggle = auraGeneral.args.objectives
                        auras.args.general = nil

                        if master then
                            master.order = 2
                            master.name = "Enable Aura Displays"
                            master.width = "full"
                            auras.args.enabled = master
                        end

                        local objectives = auras.args.objectives
                        if objectives then
                            objectives.order = 10
                            objectives.name = "Objectives"
                            objectives.guiInline = nil
                            if objectivesToggle then objectives.args.enabled = objectivesToggle end
                            if objectives.args.enabled then
                                objectives.args.enabled.order = 1
                                objectives.args.enabled.name = "Enable Objectives"
                            end
                            objectives.args.test = {
                                order = 2,
                                type = "execute",
                                name = "Test Objectives",
                                desc = "Opens the shared Friendly Preview with an objective carrier selected.",
                                disabled = function() return InCombatLockdown and InCombatLockdown() end,
                                func = function() ShowFriendlyPreview("OBJECTIVE") end,
                            }
                        end

                        local major = auras.args.major
                        if major then
                            major.order = 20
                            major.name = "Major Defensives"
                            major.guiInline = nil
                            if majorToggle then
                                majorToggle.order = 1
                                majorToggle.name = "Enable Major Defensives"
                                major.args.enabled = majorToggle
                            end
                            major.args.test = {
                                order = 2,
                                type = "execute",
                                name = "Test Major Defensive",
                                desc = "Opens the shared Friendly Preview with the major-defensive badge enabled.",
                                disabled = function() return InCombatLockdown and InCombatLockdown() end,
                                func = function() ShowFriendlyPreview("MAJOR") end,
                            }
                        end

                        local immunity = auras.args.immunity
                        if immunity then
                            immunity.order = 30
                            immunity.name = "Immunities"
                            immunity.guiInline = nil
                            if immunityToggle then
                                immunityToggle.order = 1
                                immunityToggle.name = "Enable Immunities"
                                immunity.args.enabled = immunityToggle
                            end
                            immunity.args.test = {
                                order = 2,
                                type = "execute",
                                name = "Test Immunity",
                                desc = "Opens the shared Friendly Preview with the immunity overlay enabled.",
                                disabled = function() return InCombatLockdown and InCombatLockdown() end,
                                func = function() ShowFriendlyPreview("IMMUNITY") end,
                            }
                        end
                    end

                    -- The old dedicated Aura Preview block duplicated the Friendly
                    -- test controls. All test shortcuts now drive one preview.
                    auras.args.preview = nil
                    friendlyPlates.args.auras = auras
                end

                -- One test harness for the whole friendly plate. The former
                -- developer-only Test Mode page is replaced rather than nested
                -- beside multiple independent aura previews.
                friendlyPlates.args.testMode = nil
                friendlyPlates.args.preview = {
                    order = 90,
                    type = "group",
                    name = "Preview",
                    args = {
                        info = {
                            order = 1,
                            type = "description",
                            width = "full",
                            name = "One BattleMender-owned preview for friendly plate health, LoS, class/spec art, Objectives, and aura badges. It closes automatically in combat and when the options window closes.",
                        },
                        show = {
                            order = 5,
                            type = "execute",
                            name = "Show Preview",
                            disabled = function() return InCombatLockdown and InCombatLockdown() end,
                            func = function() ShowFriendlyPreview("CURRENT") end,
                        },
                        hide = {
                            order = 6,
                            type = "execute",
                            name = "Hide Preview",
                            func = function() if BM.Defensives and BM.Defensives.HidePreview then BM.Defensives.HidePreview(); NotifyOptionsChanged() end end,
                        },
                        state = {
                            order = 10,
                            type = "group",
                            name = BrandSection("Plate State"),
                            guiInline = true,
                            args = {
                                health = { order = 1, type = "range", name = "Health %", min = 0, max = 100, step = 1, get = function() return CFG.friendlyTestHealthPercent or 62 end, set = function(_, v) CFG.friendlyTestHealthPercent = v; SaveRefresh() end },
                                los = { order = 2, type = "toggle", name = "LoS / Faded State", get = function() return CFG.friendlyTestLOS == true end, set = function(_, v) CFG.friendlyTestLOS = v and true or false; SaveRefresh() end },
                                class = { order = 3, type = "select", name = "Class", values = FRIENDLY_TEST_CLASSES, get = function() return CFG.friendlyTestClass or "DEATHKNIGHT" end, set = function(_, v) CFG.friendlyTestClass = v or "DEATHKNIGHT"; SaveRefresh() end },
                                spec = { order = 4, type = "input", name = "Spec Texture ID", desc = "Uses Textures\\Specs\\<id>.tga.", get = function() return tostring(CFG.friendlyTestSpecID or 1467) end, set = function(_, v) CFG.friendlyTestSpecID = tonumber(v) or 1467; SaveRefresh() end },
                                healerControl = { order=5, type="toggle", name="Healer CC / Silence", desc="Simulates the separate hard-CC / silence badge on a healer preview; never affects live plates.", get=function() return CFG.friendlyTestHealerControl == true end, set=function(_, v) CFG.friendlyTestHealerControl = v; SaveRefresh() end },
                            },
                        },
                        features = {
                            order = 20,
                            type = "group",
                            name = BrandSection("Preview Features"),
                            guiInline = true,
                            args = {
                                objective = {
                                    order = 1, type = "select", name = "Objective", values = FRIENDLY_PREVIEW_OBJECTIVES,
                                    get = function() return CFG.friendlyPreviewObjective or "NONE" end,
                                    set = function(_, v) CFG.friendlyPreviewObjective = v or "NONE"; SaveRefresh() end,
                                },
                                aura = {
                                    order = 2, type = "select", name = "Aura", values = FRIENDLY_PREVIEW_AURAS,
                                    get = function() return CFG.friendlyPreviewAura or "NONE" end,
                                    set = function(_, v) CFG.friendlyPreviewAura = v or "NONE"; SaveRefresh() end,
                                },
                            },
                        },
                        position = {
                            order = 30,
                            type = "group",
                            name = BrandSection("Position"),
                            guiInline = true,
                            args = {
                                anchor = { order = 1, type = "select", name = "Anchor", values = ANCHOR_POINTS, get = function() return CFG.friendlyTestAnchorPoint or "CENTER" end, set = function(_, v) CFG.friendlyTestAnchorPoint = v; SaveRefresh() end },
                                x = { order = 2, type = "range", name = "X Offset", min = -600, max = 600, step = 1, get = function() return CFG.friendlyTestXOffset or 0 end, set = function(_, v) CFG.friendlyTestXOffset = v; SaveRefresh() end },
                                y = { order = 3, type = "range", name = "Y Offset", min = -400, max = 400, step = 1, get = function() return CFG.friendlyTestYOffset or 120 end, set = function(_, v) CFG.friendlyTestYOffset = v; SaveRefresh() end },
                            },
                        },
                    },
                }

                -- Developer-only wording now points to Friendly Plates. Preview
                -- is intentionally public because it is a configuration aid.
                local health = friendlyPlates.args.health
                if health then
                    health.desc = "Advanced missing-health texture, blend, and layer controls. Enable Developer Mode under Friendly Plates > General to edit."
                    health.disabled = DisabledUnlessDeveloper
                end
                for _, group in pairs(friendlyPlates.args) do
                    if type(group) == "table" and type(group.desc) == "string" then
                        group.desc = group.desc:gsub("Developer Mode on the General tab", "Developer Mode under Friendly Plates > General")
                        group.desc = group.desc:gsub("Developer Mode on the General page", "Developer Mode under Friendly Plates > General")
                    end
                end
            end
        end

        -------------------------------------------------
        -- Enemy Plates: put provider controls + BattleMender clickthrough in a
        -- proper General page instead of leaving leaf controls above the tree.
        -------------------------------------------------
        if enemyPlates and enemyPlates.args then
            enemyPlates.order = 30
            enemyPlates.childGroups = "tree"

            local enemyArgs = enemyPlates.args
            local enabled = enemyArgs.enabled
            local status = enemyArgs.status
            local hideNative = enemyArgs.hideNative
            local testButton = enemyArgs.testButton
            enemyArgs.enabled = nil
            enemyArgs.status = nil
            enemyArgs.hideNative = nil
            enemyArgs.testButton = nil

            enemyArgs.general = {
                order = 5,
                type = "group",
                name = "General",
                args = {
                    enabled = enabled,
                    status = status,
                    hideNative = hideNative,
                    clickthrough = {
                        order = 14,
                        type = "toggle",
                        name = "Clickthrough",
                        desc = "Makes BattleMender enemy plates ignore mouse interaction while BattleMender is the active enemy-plate provider.",
                        get = function() return CFG.enemyPlateClickthrough == true end,
                        set = function(_, v) CFG.enemyPlateClickthrough = v and true or false; SaveRefreshInteraction() end,
                    },
                    test = testButton,
                },
            }
            if enabled then enabled.order = 10 end
            if status then status.order = 11 end
            if hideNative then hideNative.order = 12 end
            if testButton then testButton.order = 20 end
        end

        -------------------------------------------------
        -- Compatibility: detection/provider handling only. No ElvUI repair and
        -- no ElvUI clickthrough configuration.
        -------------------------------------------------
        if compatibility and compatibility.args then
            compatibility.order = 40
            compatibility.name = "Compatibility"
            compatibility.childGroups = "tree"
            compatibility.args.elvui = nil
            compatibility.args.clickthrough = nil
            compatibility.args.info = {
                order = 2,
                type = "description",
                width = "full",
                name = "BattleMender reports provider conflicts here but no longer changes ElvUI nameplate interaction settings or repairs ElvUI SavedVariables.",
            }
            local providerHandling = compatibility.args.nameplateAddons
            if providerHandling then
                providerHandling.order = 10
                providerHandling.name = BrandSection("Provider Handling")
            end
        end

        -------------------------------------------------
        -- Profiles: management and text transfer belong under one branch.
        -------------------------------------------------
        local manageProfiles = options.args.profiles
        local transferProfiles = options.args.profileTransfer
        options.args.profiles = nil
        options.args.profileTransfer = nil

        if manageProfiles or transferProfiles then
            if manageProfiles then
                manageProfiles.order = 10
                manageProfiles.name = "Manage Profiles"
            end
            if transferProfiles then
                transferProfiles.order = 20
                transferProfiles.name = "Import / Export"
            end
            options.args.profiles = {
                order = 50,
                type = "group",
                name = "Profiles",
                childGroups = "tree",
                args = {
                    manage = manageProfiles,
                    transfer = transferProfiles,
                },
            }
        end

        -------------------------------------------------
        -- Remove horizontal tab navigation anywhere it remains. Existing inline
        -- visual sections stay inline; navigational groups become vertical trees.
        -------------------------------------------------
        local function Verticalize(group)
            if type(group) ~= "table" then return end
            if group.type == "group" and group.childGroups == "tab" then
                group.childGroups = "tree"
            end
            if type(group.args) == "table" then
                for _, child in pairs(group.args) do
                    Verticalize(child)
                end
            end
        end
        Verticalize(options)
    end

    return options
end

function BM.RegisterAceOptions()
    if OptionsRegistered then return true end

    local AC, ACD, AG = ResolveAce3()
    if not (AC and ACD and AG) then return false end

    RegisterAuraFilterCheckBox(AG)
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

    -- AceGUI's Frame container only provides a bottom Close button. Add the
    -- standard WoW title-bar X so the standalone BattleMender window can be
    -- dismissed from the expected top-right location. Hide the AceGUI widget
    -- normally so its existing OnClose cleanup path still handles Test Mode
    -- and defensive previews.
    if not frame.BattleMenderCloseButton then
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
        close:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
        close:SetScript("OnClick", function()
            if PlaySound then PlaySound(799) end
            if widget and widget.Hide then
                widget:Hide()
            else
                BM.CloseStandaloneOptions()
            end
        end)
        close:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Close")
                GameTooltip:Show()
            end
        end)
        close:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        frame.BattleMenderCloseButton = close
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

local function CaptureOptionsFrameGeometry(frame)
    if not frame or not frame.GetPoint then return nil end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return nil end
    return {
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
    }
end

local function RestoreOptionsFrameGeometry(frame, geometry)
    if not frame or not geometry then return end
    if geometry.width and geometry.height then
        frame:SetSize(geometry.width, geometry.height)
    end
    frame:ClearAllPoints()
    frame:SetPoint(
        geometry.point or "TOPLEFT",
        geometry.relativeTo or UIParent,
        geometry.relativePoint or geometry.point or "TOPLEFT",
        geometry.x or 0,
        geometry.y or 0
    )
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

        -- AceConfig may resize/re-anchor a reusable container while selecting a
        -- different top-level group. Preserve the exact outer geometry so the
        -- minimap left/right shortcuts open the same window in the same place.
        local preservedGeometry = nil
        if OptionsFrame.frame and not OptionsFrame.frame.BMDefaultPositionPending then
            preservedGeometry = CaptureOptionsFrameGeometry(OptionsFrame.frame)
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
        elseif preservedGeometry then
            RestoreOptionsFrameGeometry(OptionsFrame.frame, preservedGeometry)
        end

        -- AceConfig creates its child widgets during Open; reassert the outer
        -- theme on the following frame in case the dialog adjusted its layers.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if OptionsFrame and OptionsFrame.frame and OptionsFrame.frame:IsShown() then
                    ApplyWindowBranding(OptionsFrame)
                    if preservedGeometry then
                        RestoreOptionsFrameGeometry(OptionsFrame.frame, preservedGeometry)
                    end
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

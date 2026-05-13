-- Settings.lua
local AddOnName, Engine = ...

if not _G.ElvUI then return end
local E = unpack(_G.ElvUI)

local EP = LibStub and LibStub("LibElvUIPlugin-1.0", true)
if not EP then return end

local BM = BattleMender
local CFG = BM.CFG

local function SaveRefresh()
    if BM.SaveRefresh then BM.SaveRefresh() end
end

-- Shared Dropdown Values
local TEX_MODES = { ["SPEC"] = "Spec Icon", ["CLASS"] = "Class Icon", ["SOLID"] = "Solid", ["NONE"] = "Disabled" }
local TOP_TEX_MODES = { ["SPEC"] = "Spec Icon", ["SOLID"] = "Solid", ["NONE"] = "Disabled" }
local BLEND_MODES = { ["BLEND"] = "Normal", ["ADD"] = "Additive", ["MOD"] = "Multiply", ["DISABLE"] = "Raw" }
local ANCHOR_MODES = { ["TOP"] = "Top", ["CENTER"] = "Center", ["BOTTOM"] = "Bottom" }

-- Pulse Overlay Textures (Defined locally so load-order never breaks it!)
local PULSE_TEXTURES = { 
    ["Circle_AlphaGradient_In"] = "Gradient In", 
    ["Circle_AlphaGradient_Out"] = "Gradient Out", 
    ["Circle_Smooth2"] = "Smooth 2" 
}

-------------------------------------------------
-- Dynamic Status Checker for the UI
-------------------------------------------------
local function GetElvUIStatusText()
    local np = E.db.nameplates
    if not (np and np.units and np.units.FRIENDLY_PLAYER and np.units.FRIENDLY_PLAYER.health) then 
        return "|cffff0000Error: ElvUI Friendly Nameplates not found.|r" 
    end
    
    local h = np.units.FRIENDLY_PLAYER.health
    local conflicts = {}
    
    if h.enable == false then table.insert(conflicts, "Health Bars Disabled") end
    if h.useClassColor == true or h.colorClass == true then table.insert(conflicts, "Class Color") end
    if h.useClassificationColor == true or h.colorClassification == true then table.insert(conflicts, "Classification Color") end

    if #conflicts > 0 then
        local str = table.concat(conflicts, ", ")
        return "|cffff0000CONFLICT DETECTED:|r ElvUI is overriding visuals (" .. str .. ").\nPlease fix this in the Friendly Player Nameplate settings to prevent visual bugs."
    end
    
    return "|cff33ff99ElvUI Settings: Clean & Compatible|r"
end

-------------------------------------------------
-- Force ElvUI Size Sync
-------------------------------------------------
local function SyncElvUISize()
    if not (E and E.db and E.db.nameplates and E.db.nameplates.units and E.db.nameplates.units.FRIENDLY_PLAYER) then return end
    
    local np = E.db.nameplates.units.FRIENDLY_PLAYER
    local targetSize = CFG.clickSize or 60
    
    -- Only force an update if ElvUI is out of sync
    if np.clickableWidth ~= targetSize or np.clickableHeight ~= targetSize then
        np.clickableWidth = targetSize
        np.clickableHeight = targetSize
        
        -- Force ElvUI to apply the new sizes immediately
        if E.GetModule then
            local NP = E:GetModule("NamePlates")
            if NP and NP.ConfigureAll then
                NP:ConfigureAll()
            end
        end
    end
end

-------------------------------------------------
-- Options Blueprint
-------------------------------------------------
local function InsertOptions()
    E.Options.args.battlemender = {
        order = 100,
        type = "group",
        name = "|cff33ff99BattleMender|r",
        childGroups = "tab",
        args = {
            -- ==========================================
            -- 1. GENERAL TAB
            -- ==========================================
            general = {
                order = 1, type = "group", name = "General",
                args = {
                    status = { order = 1, type = "description", name = GetElvUIStatusText, fontSize = "medium" },
                    spacer = { order = 1.5, type = "description", name = " " },
                    
                    enable = { order = 2, type = "toggle", name = "Enable BattleMender", get = function() return CFG.enabled end, set = function(_, v) CFG.enabled = v; SaveRefresh() end },
                    showClickbox = { order = 3, type = "toggle", name = "Show Clickbox (Debug)", get = function() return CFG.showClickbox end, set = function(_, v) CFG.showClickbox = v; SaveRefresh() end },
                    
                    layoutGroup = {
                        order = 4, type = "group", name = "Sizing & Positioning", guiInline = true,
                        args = {
                            iconSize = { order = 1, type = "range", name = "Icon Size", min = 20, max = 100, step = 1, get = function() return CFG.iconSize end, set = function(_, v) CFG.iconSize = v; SaveRefresh() end },
                            clickSize = { order = 2, type = "range", name = "Clickbox Size", min = 30, max = 150, step = 1, get = function() return CFG.clickSize end, set = function(_, v) CFG.clickSize = v; if BM.SetFriendlyClickbox then BM.SetFriendlyClickbox() end; SaveRefresh() end },
                            anchorPoint = { order = 3, type = "select", name = "Anchor Point", values = ANCHOR_MODES, get = function() return CFG.anchorPoint end, set = function(_, v) CFG.anchorPoint = v; SaveRefresh() end },
                            anchorX = { order = 4, type = "range", name = "X Offset", min = -100, max = 100, step = 1, get = function() return CFG.anchorX end, set = function(_, v) CFG.anchorX = v; SaveRefresh() end },
                            anchorY = { order = 5, type = "range", name = "Y Offset", min = -100, max = 100, step = 1, get = function() return CFG.anchorY end, set = function(_, v) CFG.anchorY = v; SaveRefresh() end },
                        },
                    },
                    
                    cvarsGroup = {
                        order = 5, type = "group", name = "Blizzard & ElvUI Nameplate Settings", guiInline = true,
                        args = {
                            -- Stacking CVars (Global)
                            nameplateMotion = { order = 1, type = "toggle", name = "Stack Nameplates (Global)", desc = "WoW applies stacking to both Enemies and Friendlies globally.", get = function() return GetCVar("nameplateMotion") == "1" end, set = function(_, v) SetCVar("nameplateMotion", v and "1" or "0") end },
                            
                            -- Clickthroughs (Pushing directly to ElvUI)
                            clickThroughFriendly = { order = 2, type = "toggle", name = "Friendly Clickthrough", desc = "Prevents clicking on friendly nameplates.", get = function() return E.db.nameplates.units.FRIENDLY_PLAYER.clickThrough end, set = function(_, v) E.db.nameplates.units.FRIENDLY_PLAYER.clickThrough = v; E:GetModule("NamePlates"):ConfigureAll() end },
                            clickThroughEnemy = { order = 3, type = "toggle", name = "Enemy Clickthrough", desc = "Prevents clicking on enemy nameplates.", get = function() return E.db.nameplates.units.ENEMY_PLAYER.clickThrough end, set = function(_, v) E.db.nameplates.units.ENEMY_PLAYER.clickThrough = v; E:GetModule("NamePlates"):ConfigureAll() end },
                            
                            -- Overlaps
                            nameplateOverlapV = { order = 4, type = "range", name = "Vertical Overlap", min = 0.1, max = 1.5, step = 0.05, get = function() return tonumber(GetCVar("nameplateOverlapV")) or 1 end, set = function(_, v) SetCVar("nameplateOverlapV", v) end },
                            nameplateOverlapH = { order = 5, type = "range", name = "Horizontal Overlap", min = 0.1, max = 1.5, step = 0.05, get = function() return tonumber(GetCVar("nameplateOverlapH")) or 1 end, set = function(_, v) SetCVar("nameplateOverlapH", v) end },
                        }
                    },
                    
                    bgGroup = {
                        order = 6, type = "group", name = "Battleground Overrides", guiInline = true,
                        args = {
                            disableBGPortrait = { order = 1, type = "toggle", name = "Disable Enemy Portraits in BGs", desc = "Auto-disables ElvUI enemy portraits when entering a PvP instance, and restores them when leaving.", get = function() return CFG.disableBGPortrait end, set = function(_, v) CFG.disableBGPortrait = v; SaveRefresh() end },
                        }
                    }
                },
            },

            -- ==========================================
            -- 2. ADVANCED TAB
            -- ==========================================
            advanced = {
                order = 2, type = "group", name = "Advanced",
                childGroups = "tree", -- "tree" makes the Normal/Faded a left-side sub-menu
                args = {
                    -- ADVANCED: NORMAL
                    normalGroup = {
                        order = 1, type = "group", name = "Normal (In-Sight)",
                        args = {
                            healthGroup = {
                                order = 1, type = "group", name = "Vertical Status Bar & Background", guiInline = true,
                                args = {
                                    healthEnable = { order = 1, type = "toggle", name = "Enable Status Bar", get = function() return CFG.healthEnable end, set = function(_, v) CFG.healthEnable = v; SaveRefresh() end },
                                    healthAlpha = { order = 2, type = "range", name = "Bar Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.healthAlpha end, set = function(_, v) CFG.healthAlpha = v; SaveRefresh() end },
                                    healthBlendMode = { order = 3, type = "select", name = "Blend Mode", values = BLEND_MODES, get = function() return CFG.healthBlendMode end, set = function(_, v) CFG.healthBlendMode = v; SaveRefresh() end },
                                    healthColor = {
                                        order = 4, type = "color", name = "Color", hasAlpha = false,
                                        get = function() local c = CFG.healthColor or {r=1, g=1, b=1}; return c.r, c.g, c.b end,
                                        set = function(_, r, g, b) CFG.healthColor = {r=r, g=g, b=b}; SaveRefresh() end
                                    },
                                    healthClassColor = { order = 5, type = "toggle", name = "Use Class Color", get = function() return CFG.healthClassColor end, set = function(_, v) CFG.healthClassColor = v; SaveRefresh() end },
                                }
                            },
                            baseIconGroup = {
                                order = 2, type = "group", name = "Base Overlay Icon", guiInline = true,
                                args = {
                                    iconTextureMode = { order = 1, type = "select", name = "Texture Mode", values = TEX_MODES, get = function() return CFG.iconTextureMode end, set = function(_, v) CFG.iconTextureMode = v; SaveRefresh() end },
                                    iconBlendMode = { order = 2, type = "select", name = "Blend Mode", values = BLEND_MODES, get = function() return CFG.iconBlendMode end, set = function(_, v) CFG.iconBlendMode = v; SaveRefresh() end },
                                    iconAlpha = { order = 3, type = "range", name = "Base Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.iconAlpha end, set = function(_, v) CFG.iconAlpha = v; SaveRefresh() end },
                                    iconDesaturate = { order = 4, type = "toggle", name = "Desaturate Base", get = function() return CFG.iconDesaturate end, set = function(_, v) CFG.iconDesaturate = v; SaveRefresh() end },
                                    iconColor = {
                                        order = 5, type = "color", name = "Color", hasAlpha = false,
                                        get = function() local c = CFG.iconColor or {r=1, g=1, b=1}; return c.r, c.g, c.b end,
                                        set = function(_, r, g, b) CFG.iconColor = {r=r, g=g, b=b}; SaveRefresh() end
                                    },
                                    iconClassColor = { order = 6, type = "toggle", name = "Use Class Color", get = function() return CFG.iconClassColor end, set = function(_, v) CFG.iconClassColor = v; SaveRefresh() end },
                                }
                            },
                            topIconGroup = {
                                order = 3, type = "group", name = "Top Overlay Icon", guiInline = true,
                                args = {
                                    topIconEnable = { order = 1, type = "toggle", name = "Enable Top Icon", get = function() return CFG.topIconEnable end, set = function(_, v) CFG.topIconEnable = v; SaveRefresh() end },
                                    topIconTextureMode = { order = 2, type = "select", name = "Texture Mode", values = TOP_TEX_MODES, get = function() return CFG.topIconTextureMode end, set = function(_, v) CFG.topIconTextureMode = v; SaveRefresh() end },
                                    topIconBlendMode = { order = 3, type = "select", name = "Blend Mode", values = BLEND_MODES, get = function() return CFG.topIconBlendMode end, set = function(_, v) CFG.topIconBlendMode = v; SaveRefresh() end },
                                    topIconAlpha = { order = 4, type = "range", name = "Top Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.topIconAlpha end, set = function(_, v) CFG.topIconAlpha = v; SaveRefresh() end },
                                    topIconColor = {
                                        order = 5, type = "color", name = "Color", hasAlpha = false,
                                        get = function() local c = CFG.topIconColor or {r=1, g=1, b=1}; return c.r, c.g, c.b end,
                                        set = function(_, r, g, b) CFG.topIconColor = {r=r, g=g, b=b}; SaveRefresh() end
                                    },
                                    topIconClassColor = { order = 6, type = "toggle", name = "Use Class Color", get = function() return CFG.topIconClassColor end, set = function(_, v) CFG.topIconClassColor = v; SaveRefresh() end },
                                }
                            },
                            borderGroup = {
                                order = 4, type = "group", name = "Ring Border", guiInline = true,
                                args = {
                                    borderEnable = { order = 1, type = "toggle", name = "Enable Border", get = function() return CFG.borderEnable end, set = function(_, v) CFG.borderEnable = v; SaveRefresh() end },
                                    borderScale = { order = 2, type = "range", name = "Border Scale", min = 0.8, max = 1.5, step = 0.01, get = function() return CFG.borderScale end, set = function(_, v) CFG.borderScale = v; SaveRefresh() end },
                                    borderAlpha = { order = 3, type = "range", name = "Border Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.borderAlpha end, set = function(_, v) CFG.borderAlpha = v; SaveRefresh() end },
                                    borderColor = {
                                        order = 4, type = "color", name = "Color", hasAlpha = false,
                                        get = function() local c = CFG.borderColor or {r=1, g=1, b=1}; return c.r, c.g, c.b end,
                                        set = function(_, r, g, b) CFG.borderColor = {r=r, g=g, b=b}; SaveRefresh() end
                                    },
                                    borderClassColor = { order = 5, type = "toggle", name = "Use Class Color", get = function() return CFG.borderClassColor end, set = function(_, v) CFG.borderClassColor = v; SaveRefresh() end },
                                }
                            }
                        }
                    },
                    -- ADVANCED: FADED (LoS)
                    fadedGroup = {
                        order = 2, type = "group", name = "Faded (Line of Sight)",
                        args = {
                            losHealthGroup = {
                                order = 1, type = "group", name = "LoS Vertical Status Bar & Background", guiInline = true,
                                args = {
                                    losHealthAlpha = { order = 1, type = "range", name = "LoS Bar Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losHealthAlpha end, set = function(_, v) CFG.losHealthAlpha = v; SaveRefresh() end },
                                    losHealthBlendMode = { order = 2, type = "select", name = "LoS Blend Mode", values = BLEND_MODES, get = function() return CFG.losHealthBlendMode end, set = function(_, v) CFG.losHealthBlendMode = v; SaveRefresh() end },
                                }
                            },
                            losIconGroup = {
                                order = 2, type = "group", name = "LoS Overlay Icons", guiInline = true,
                                args = {
                                    losIconAlpha = { order = 1, type = "range", name = "LoS Base Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losIconAlpha end, set = function(_, v) CFG.losIconAlpha = v; SaveRefresh() end },
                                    losIconDesaturate = { order = 2, type = "toggle", name = "LoS Desaturate Base", get = function() return CFG.losIconDesaturate end, set = function(_, v) CFG.losIconDesaturate = v; SaveRefresh() end },
                                    spacer = { order = 3, type = "description", name = " " },
                                    losTopIconAlpha = { order = 4, type = "range", name = "LoS Top Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losTopIconAlpha end, set = function(_, v) CFG.losTopIconAlpha = v; SaveRefresh() end },
                                    losTopIconBlendMode = { order = 5, type = "select", name = "LoS Top Blend Mode", values = BLEND_MODES, get = function() return CFG.losTopIconBlendMode end, set = function(_, v) CFG.losTopIconBlendMode = v; SaveRefresh() end },
                                }
                            },
                            losBorderGroup = {
                                order = 3, type = "group", name = "LoS Ring Border", guiInline = true,
                                args = {
                                    losBorderAlpha = { order = 1, type = "range", name = "LoS Border Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losBorderAlpha end, set = function(_, v) CFG.losBorderAlpha = v; SaveRefresh() end },
                                }
                            }
                        }
                    }
                }
            },

            -- ==========================================
            -- 3. VISUALS TAB
            -- ==========================================
            visuals = {
                order = 3, type = "group", name = "Visuals",
                childGroups = "tree", -- "tree" makes Mouseover/Animations a left-side sub-menu
                args = {
                    -- VISUALS: MOUSEOVER
                    mouseoverGroup = {
                        order = 1, type = "group", name = "Mouseover Glows",
                        args = {
                            iconGlow = {
                                order = 1, type = "group", name = "Icon Glow (Top Icon)", guiInline = true,
                                args = {
                                    hoverTopEnable = { order = 1, type = "toggle", name = "Enable Icon Glow", get = function() return CFG.hoverTopEnable end, set = function(_, v) CFG.hoverTopEnable = v; SaveRefresh() end },
                                    hoverTopBrightness = { order = 2, type = "range", name = "Glow Brightness Peak", min = 0, max = 1, step = 0.05, get = function() return CFG.hoverTopBrightness end, set = function(_, v) CFG.hoverTopBrightness = v; SaveRefresh() end },
                                }
                            },
                            borderGlow = {
                                order = 2, type = "group", name = "Border Glow (Ring)", guiInline = true,
                                args = {
                                    hoverRingEnable = { order = 1, type = "toggle", name = "Enable Border Glow", get = function() return CFG.hoverRingEnable end, set = function(_, v) CFG.hoverRingEnable = v; SaveRefresh() end },
                                    hoverRingBrightness = { order = 2, type = "range", name = "Glow Brightness Peak", min = 0, max = 1, step = 0.05, get = function() return CFG.hoverRingBrightness end, set = function(_, v) CFG.hoverRingBrightness = v; SaveRefresh() end },
                                }
                            },
                            haloGlow = {
                                order = 3, type = "group", name = "Halo Glow (Background)", guiInline = true,
                                args = {
                                    haloEnable = { order = 1, type = "toggle", name = "Enable Halo Glow", get = function() return CFG.haloEnable end, set = function(_, v) CFG.haloEnable = v; SaveRefresh() end },
                                    haloGlowSizeScale = { order = 2, type = "range", name = "Halo Size Multiplier", min = 1, max = 4, step = 0.1, get = function() return CFG.haloGlowSizeScale end, set = function(_, v) CFG.haloGlowSizeScale = v; SaveRefresh() end },
                                    haloGlowAlpha = { order = 3, type = "range", name = "Halo Max Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.haloGlowAlpha end, set = function(_, v) CFG.haloGlowAlpha = v; SaveRefresh() end },
                                }
                            }
                        }
                    },
                    -- VISUALS: TEXTURE ANIMATIONS
                    textureAnimationsGroup = {
                        order = 2, type = "group", name = "Texture Animations",
                        args = {
                            normalPulse = {
                                order = 1, type = "group", name = "Damage Pulse (Normal)", guiInline = true,
                                args = {
                                    pulseEnable = { order = 1, type = "toggle", name = "Enable Normal Pulse", get = function() return CFG.pulseEnable end, set = function(_, v) CFG.pulseEnable = v; SaveRefresh() end },
                                    pulseSpeed = { order = 2, type = "range", name = "Pulse Speed", min = 0.1, max = 2, step = 0.1, get = function() return CFG.pulseSpeed end, set = function(_, v) CFG.pulseSpeed = v; SaveRefresh() end },
                                    pulseIntensity = { order = 3, type = "range", name = "Pulse Dim Intensity", min = 0.1, max = 1, step = 0.05, get = function() return CFG.pulseIntensity end, set = function(_, v) CFG.pulseIntensity = v; SaveRefresh() end },
                                    pulseOverlayEnable = { order = 4, type = "toggle", name = "Enable Pulse Overlay Layer", get = function() return CFG.pulseOverlayEnable end, set = function(_, v) CFG.pulseOverlayEnable = v; SaveRefresh() end },
                                    pulseOverlayAlpha = { order = 5, type = "range", name = "Overlay Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.pulseOverlayAlpha end, set = function(_, v) CFG.pulseOverlayAlpha = v; SaveRefresh() end },
                                }
                            },
                            losPulse = {
                                order = 2, type = "group", name = "Damage Pulse (Line of Sight)", guiInline = true,
                                args = {
                                    losPulseEnable = { order = 1, type = "toggle", name = "Enable LoS Pulse", get = function() return CFG.losPulseEnable end, set = function(_, v) CFG.losPulseEnable = v; SaveRefresh() end },
                                    losPulseSpeed = { order = 2, type = "range", name = "LoS Pulse Speed", min = 0.1, max = 2, step = 0.1, get = function() return CFG.losPulseSpeed end, set = function(_, v) CFG.losPulseSpeed = v; SaveRefresh() end },
                                    losPulseIntensity = { order = 3, type = "range", name = "LoS Pulse Dim Intensity", min = 0.1, max = 1, step = 0.05, get = function() return CFG.losPulseIntensity end, set = function(_, v) CFG.losPulseIntensity = v; SaveRefresh() end },
                                    losPulseOverlayEnable = { order = 4, type = "toggle", name = "Enable LoS Pulse Overlay", get = function() return CFG.losPulseOverlayEnable end, set = function(_, v) CFG.losPulseOverlayEnable = v; SaveRefresh() end },
                                    losPulseOverlayAlpha = { order = 5, type = "range", name = "LoS Overlay Alpha", min = 0, max = 1, step = 0.05, get = function() return CFG.losPulseOverlayAlpha end, set = function(_, v) CFG.losPulseOverlayAlpha = v; SaveRefresh() end },
                                }
                            }
                        }
                    }
                }
            }
        }
    }
end

EP:RegisterPlugin(AddOnName, InsertOptions)
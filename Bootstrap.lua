BattleMender = BattleMender or {}

-- Loaded last by the TOC. Keeps event registration out of Core.lua so that
-- Nameplates.lua has defined BattleMender.GetVisualFrame / ApplyToPlate first.
local ADDON = BattleMender.Frame
if ADDON then
    ADDON:SetScript("OnUpdate", BattleMender.OnUpdate)
    ADDON:SetScript("OnEvent", BattleMender.OnEvent)

    ADDON:RegisterEvent("PLAYER_ENTERING_WORLD")
    ADDON:RegisterEvent("PLAYER_LOGOUT")
    ADDON:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    ADDON:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    ADDON:RegisterEvent("GROUP_ROSTER_UPDATE")
    ADDON:RegisterEvent("PLAYER_TARGET_CHANGED")
    ADDON:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    ADDON:RegisterEvent("PLAYER_REGEN_DISABLED")
    ADDON:RegisterEvent("PLAYER_REGEN_ENABLED")
    ADDON:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ADDON:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    ADDON:RegisterEvent("INSPECT_READY")
    ADDON:RegisterEvent("UNIT_HEALTH")
    ADDON:RegisterEvent("UNIT_MAXHEALTH")
    ADDON:RegisterEvent("UNIT_FLAGS")
    ADDON:RegisterEvent("UNIT_FACTION")
    ADDON:RegisterEvent("UNIT_AURA")
    ADDON:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    ADDON:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    ADDON:RegisterEvent("UNIT_SPELLCAST_START")
    ADDON:RegisterEvent("UNIT_SPELLCAST_STOP")
    ADDON:RegisterEvent("UNIT_SPELLCAST_FAILED")
    ADDON:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    ADDON:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    ADDON:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    ADDON:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    ADDON:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    ADDON:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    ADDON:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
end

-- entry point for all lua code of the pack
-- more info on the lua API: https://github.com/black-sliver/PopTracker/blob/master/doc/PACKS.md#lua-interface
ENABLE_DEBUG_LOG = true

-- get current variant
local variant = Tracker.ActiveVariantUID
-- check variant info
IS_ITEMS_ONLY = variant:find("itemsonly")

print("Loaded variant: ", variant)
if ENABLE_DEBUG_LOG then
    print("Debug logging is enabled!")
end

-- Utility Script for helper functions etc.
ScriptHost:LoadScript("scripts/utils.lua")

-- Logic
ScriptHost:LoadScript("scripts/logic/logic_helper.lua")
ScriptHost:LoadScript("scripts/logic/logic.lua")

-- Items
Tracker:AddItems("items/items.json")
Tracker:AddItems("items/settings.json")

if not IS_ITEMS_ONLY then -- <--- use variant info to optimize loading
    -- Maps
    Tracker:AddMaps("maps/maps.json")
    -- Locations
    ScriptHost:LoadScript("scripts/locations.lua")
end


-- Layout
ScriptHost:LoadScript("scripts/layouts_import.lua")

-- Adds Watches for Item Grid Toggles
ScriptHost:AddWatchForCode("goal-settings", "set-gc-goal", toggle_settings)
ScriptHost:AddWatchForCode("goal-items", "set-gc-goal", toggle_itemgrid)
ScriptHost:AddWatchForCode("pipe-items", "set-pipe-traversal", toggle_itemgrid)
ScriptHost:AddWatchForCode("scroll-items", "set-scroll-mode", toggle_itemgrid)
ScriptHost:AddWatchForCode("scroll-main", "set-scroll-mode", toggle_maingrid)
ScriptHost:AddWatchForCode("midway-main", "set-shuffle-midways", toggle_maingrid)
ScriptHost:AddWatchForCode("midway-mario", "set-mario-castle-midway", toggle_midways)

-- AutoTracking for Poptracker
if PopVersion and PopVersion >= "0.26.0" then
    ScriptHost:LoadScript("scripts/autotracking.lua")
end

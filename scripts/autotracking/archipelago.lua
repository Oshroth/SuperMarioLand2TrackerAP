-- this is an example/ default implementation for AP autotracking
-- it will use the mappings defined in item_mapping.lua and location_mapping.lua to track items and locations via thier ids
-- it will also load the AP slot data in the global SLOT_DATA, keep track of the current index of on_item messages in CUR_INDEX
-- addition it will keep track of what items are local items and which one are remote using the globals LOCAL_ITEMS and GLOBAL_ITEMS
-- this is useful since remote items will not reset but local items might
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/coin_mapping.lua")

CUR_INDEX = -1

SLOT_DATA = {}
COIN_LOCATIONS = {}

function ForceUpdate()
    local update = Tracker:FindObjectForCode("update")
    if update == nil then
        return
    end
    update.Active = not update.Active
end

function OnClearHandler(slot_data)
    local clear_timer = os.clock()

    -- Disable tracker updates.
    Tracker.BulkUpdate = true
    -- Use a protected call so that tracker updates always get enabled again, even if an error occurred.
    local ok, err = pcall(OnClear, slot_data)
    -- Enable tracker updates again.
    if ok then
        -- Defer re-enabling tracker updates until the next frame, which doesn't happen until all received items/cleared
        -- locations from AP have been processed.
        local handlerName = "AP onClearHandler"
        local function frameCallback()
            ScriptHost:RemoveOnFrameHandler(handlerName)
            Tracker.BulkUpdate = false
            ForceUpdate()
            print(string.format("Time taken total: %.2f", os.clock() - clear_timer))
        end
        ScriptHost:AddOnFrameHandler(handlerName, frameCallback)
    else
        Tracker.BulkUpdate = false
        print("Error: OnClear failed:")
        print(err)
    end
end

function ClearCoins()
    for _, location in pairs(COIN_MAPPING_LOCATIONS) do
        COIN_LOCATIONS[location] = {}
    end
    for _, id in pairs(Archipelago.CheckedLocations) do
        local coin = COIN_MAPPING[id]
        if coin ~= nil then
            if COIN_LOCATIONS[coin[1]] == nil then
                COIN_LOCATIONS[coin[1]] = {}
            end
            table.insert(COIN_LOCATIONS[coin[1]], coin[2])
        end
    end
    for _, id in pairs(Archipelago.MissingLocations) do
        local coin = COIN_MAPPING[id]
        if coin ~= nil then
            if COIN_LOCATIONS[coin[1]] == nil then
                COIN_LOCATIONS[coin[1]] = {}
            end
            table.insert(COIN_LOCATIONS[coin[1]], coin[2])
        end
    end
    for level, coin_locations in pairs(COIN_LOCATIONS) do
        table.sort(coin_locations)
    end
end


function OnClear(slot_data)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called OnClear, slot_data:\n%s", dump_table(slot_data)))
    end
    SLOT_DATA = slot_data
    CUR_INDEX = -1
    COIN_LOCATIONS = {}

    ClearCoins()
    -- reset locations
    for _, location_array in pairs(LOCATION_MAPPING) do
        for _, location in pairs(location_array) do
            if location then
                if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                    print(string.format("OnClear: clearing location %s", location))
                end
                local location_obj = Tracker:FindObjectForCode(location)
                if location_obj then
                    if location:sub(1, 1) == "@" then
                        location_obj.AvailableChestCount = location_obj.ChestCount
                    else
                        location_obj.Active = false
                    end
                end
            end
        end
    end
    -- reset coin locations
    for _, location in pairs(COIN_MAPPING_LOCATIONS) do
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("OnClear: clearing coin location %s", location))
        end
        local location_obj = Tracker:FindObjectForCode(location)
        if location_obj then
            if location:sub(1, 1) == "@" then
                location_obj.AvailableChestCount = TableLength(COIN_LOCATIONS[location])
            else
                location_obj.Active = false
            end
        end
    end
    -- reset items
	for _, mapping_entry in pairs(ITEM_MAPPING) do
		for _, item_table in ipairs(mapping_entry) do
			if item_table then
				local item_code = item_table[1]
				local item_type = item_table[2]
                if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                    print(string.format("OnClear: clearing item %s of type %s", item_code, item_type))
                end
				if item_code then
					local item_obj = Tracker:FindObjectForCode(item_code)
                    if item_obj then
                        item_type = item_type or item_obj.Type
                        if item_type == "toggle" or item_type == "toggle-trap" then
                            item_obj.Active = false
                        elseif item_type == "progressive" or item_type == "progressive_toggle" then
                            item_obj.CurrentStage = 0
                            item_obj.Active = false
                        elseif item_type == "consumable" then
                            if item_obj.MinCount then
                                item_obj.AcquiredCount = item_obj.MinCount
                            else
                                item_obj.AcquiredCount = 0
                            end
                        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                            print(string.format("OnClear: unknown item type %s for code %s", item_type, item_code))
                        end
                    end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("OnClear: skipping item_table with no item_code"))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("OnClear: skipping empty item_table"))
			end
		end
	end
    AutoFill(slot_data)
end

function OnItem(index, item_id, item_name, player_number)
    if item_id > 128 then return end -- Ignore coin items
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called OnItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
    end
    if not AUTOTRACKER_ENABLE_ITEM_TRACKING then
        return
    end
    if index <= CUR_INDEX then
        return
    end
    CUR_INDEX = index
    local item = ITEM_MAPPING[item_id]
    if not item or not item[1] then
        print(string.format("OnItem: could not find item mapping for id %s", item_id))
        return
    end
    for _, item_pair in pairs(item) do
        local item_code = item_pair[1]
        local item_type = item_pair[2]
        local item_obj = Tracker:FindObjectForCode(item_code)
        if item_obj then
            item_type = item_type or item_obj.Type
            if item_type == "toggle" then
                item_obj.Active = true
            elseif item_type == "toggle-trap" then
                item_obj.Active = false
            elseif item_type == "progressive" or item_type == "progressive_toggle" then
                if item_obj.Active then
                    item_obj.CurrentStage = item_obj.CurrentStage + 1
                else
                    item_obj.Active = true
                end
            elseif item_type == "consumable" then
                item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment * (tonumber(item_pair[3]) or 1)
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("OnItem: unknown item type %s for code %s", item_type, item_code))
            end
        end
    end
end

-- called when a location gets cleared
function OnLocation(location_id, location_name)
    if COIN_MAPPING[location_id] ~= nil then
        OnCoinLocation(location_id)
        return
    end
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called OnLocation: %s, %s", location_id, location_name))
    end
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then
        print(string.format("OnLocation: could not find location mapping for id %s", location_id))
        return
    end

    for _, location in pairs(location_array) do
        local location_obj = Tracker:FindObjectForCode(location)
        if location_obj then
            if location:sub(1, 1) == "@" then
                location_obj.AvailableChestCount = location_obj.AvailableChestCount - 1
            else
                location_obj.Active = true
            end
        else
            print(string.format("OnLocation: could not find location_object for code %s", location))
        end
    end
    ForceUpdate()
end

-- called when a coin location gets cleared
function OnCoinLocation(locationId)
    local coin = COIN_MAPPING[locationId]
    local coin_obj = Tracker:FindObjectForCode(coin[1])
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called OnCoinLocation: %s, %s", locationId, dump_table(coin)))
    end
    RemoveValue(COIN_LOCATIONS[coin[1]], coin[2])
    if coin_obj then
        coin_obj.AvailableChestCount = TableLength(COIN_LOCATIONS[coin[1]])
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("OnCoinLocation: could not find object for code %s", coin[1]))
    end
end

function AutoFill(slot_data)
    if slot_data == nil then
        print("No slot data")
        return
    end

    local levelCodes = {
        [1] = "cancelautoscroll-mushroomzone",
        [2] = "cancelautoscroll-treezone1",
        [3] = "cancelautoscroll-treezone2",
        [4] = "cancelautoscroll-treezone4",
        [5] = "cancelautoscroll-treezone3",
        [6] = "cancelautoscroll-treezone5",
        [7] = "cancelautoscroll-pumpkinzone1",
        [8] = "cancelautoscroll-pumpkinzone2",
        [9] = "cancelautoscroll-pumpkinzone3",
        [10] = "cancelautoscroll-pumpkinzone4",
        [11] = "cancelautoscroll-mariozone1",
        [12] = "cancelautoscroll-mariozone2",
        [13] = "cancelautoscroll-mariozone3",
        [14] = "cancelautoscroll-mariozone4",
        [15] = "cancelautoscroll-turtlezone1",
        [16] = "cancelautoscroll-turtlezone2",
        [17] = "cancelautoscroll-turtlezone3",
        [18] = "cancelautoscroll-hippozone",
        [19] = "cancelautoscroll-spacezone1",
        [20] = "cancelautoscroll-spacezone2",
        [21] = "cancelautoscroll-macrozone1",
        [22] = "cancelautoscroll-macrozone2",
        [23] = "cancelautoscroll-macrozone3",
        [24] = "cancelautoscroll-macrozone4",
        -- Skip [25] = Mario's Castle
        [26] = "cancelautoscroll-sceniccourse",
        [27] = "cancelautoscroll-turtlezonesecretcourse",
        [28] = "cancelautoscroll-pumpkinzonesecretcourse1",
        [29] = "cancelautoscroll-spacezonesecretcourse",
        [30] = "cancelautoscroll-treezonesecretcourse",
        [31] = "cancelautoscroll-macrozonesecretcourse",
        [32] = "cancelautoscroll-pumpkinzonesecretcourse2"
    }

    if slot_data["shuffle_golden_coins"] then
        Tracker:FindObjectForCode("set-gc-goal").CurrentStage = slot_data["shuffle_golden_coins"]
    end
    if slot_data["required_golden_coins"] then
        Tracker:FindObjectForCode("set-gc-required").AcquiredCount = slot_data["required_golden_coins"]
    end
    if slot_data["shuffle_midway_bells"] then
        Tracker:FindObjectForCode("set-shuffle-midways").Active = slot_data["shuffle_midway_bells"]
    end
    if slot_data["marios_castle_midway_bell"] then
        Tracker:FindObjectForCode("set-mario-castle-midway").Active = slot_data["marios_castle_midway_bell"]
    end
    if slot_data["shuffle_pipe_traversal"] then
        Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage = slot_data["shuffle_pipe_traversal"]
    end
    if slot_data["coinsanity"] then
        Tracker:FindObjectForCode("set-coinsanity").Active = slot_data["coinsanity"]
    end
    if slot_data["turtle_zone_1_shark_count"] then
        Tracker:FindObjectForCode("set-tz1-sharks").AcquiredCount = slot_data["turtle_zone_1_shark_count"]
    end
    if slot_data["mario_zone_3_crane_count"] then
        Tracker:FindObjectForCode("set-mz3-claws").AcquiredCount = slot_data["mario_zone_3_crane_count"]
    end
    if slot_data["coin_fragments_required"] then
        Tracker:FindObjectForCode("set-mc-frag-required").AcquiredCount = slot_data["coin_fragments_required"]
    end
    if slot_data["auto_scroll_chances"] and slot_data["auto_scroll_chances"] == 0 then
        Tracker:FindObjectForCode("set-scroll-mode").CurrentStage = 6
    elseif slot_data["auto_scroll_mode"] then
        Tracker:FindObjectForCode("set-scroll-mode").CurrentStage = slot_data["auto_scroll_mode"]

        if slot_data["auto_scroll_levels"] then
            -- auto_scroll_levels values
            -- 0 - no scroll
            -- 1 - auto scroll
            -- 2 - auto scroll with cancel global/level item
            -- 3 - no scroll with scroll global/level trap
            local scrollLevels = slot_data["auto_scroll_levels"]

            for index, code in pairs(levelCodes) do
                if scrollLevels and (scrollLevels[index] == 0 or scrollLevels[index] == 3) then
                    Tracker:FindObjectForCode(code).Active = true
                else
                    Tracker:FindObjectForCode(code).Active = false
                end
            end

        end
    end
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", OnClearHandler)
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
    Archipelago:AddItemHandler("item handler", OnItem)
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
    Archipelago:AddLocationHandler("location handler", OnLocation)
end

-- Archipelago:AddSetReplyHandler("notify handler", onNotify)
-- Archipelago:AddRetrievedHandler("notify launch handler", onNotifyLaunch)

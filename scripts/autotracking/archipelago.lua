-- this is an example/ default implementation for AP autotracking
-- it will use the mappings defined in item_mapping.lua and location_mapping.lua to track items and locations via thier ids
-- it will also load the AP slot data in the global SLOT_DATA, keep track of the current index of on_item messages in CUR_INDEX
-- addition it will keep track of what items are local items and which one are remote using the globals LOCAL_ITEMS and GLOBAL_ITEMS
-- this is useful since remote items will not reset but local items might
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")

CUR_INDEX = -1

SLOT_DATA = {}

function onClearHandler(slot_data)
    local clear_timer = os.clock()

    -- Disable tracker updates.
    Tracker.BulkUpdate = true
    -- Use a protected call so that tracker updates always get enabled again, even if an error occurred.
    local ok, err = pcall(onClear, slot_data)
    -- Enable tracker updates again.
    if ok then
        -- Defer re-enabling tracker updates until the next frame, which doesn't happen until all received items/cleared
        -- locations from AP have been processed.
        local handlerName = "AP onClearHandler"
        local function frameCallback()
            ScriptHost:RemoveOnFrameHandler(handlerName)
            Tracker.BulkUpdate = false
            print(string.format("Time taken total: %.2f", os.clock() - clear_timer))
        end
        ScriptHost:AddOnFrameHandler(handlerName, frameCallback)
    else
        Tracker.BulkUpdate = false
        print("Error: onClear failed:")
        print(err)
    end
end

function onClear(slot_data)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
    end
    SLOT_DATA = slot_data
    CUR_INDEX = -1
    -- reset locations
    for _, location_array in pairs(LOCATION_MAPPING) do
        for _, location in pairs(location_array) do
            if location then
                if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                    print(string.format("onClear: clearing location %s", location))
                end
                local location_obj = Tracker:FindObjectForCode(location)
                if location_obj then
                    if location:sub(1, 1) == "@" then
                        location_obj.AvailableChestCount = location_obj.ChestCount
                    else
                        location_obj.Active = false
                    end
                elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                    print(string.format("onClear: could not find object for code %s", location))
                end
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
                    print(string.format("onClear: clearing item %s of type %s", item_code, item_type))
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
                            print(string.format("onClear: unknown item type %s for code %s", item_type, item_code))
                        end
                    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                        print(string.format("onClear: could not find object for code %s", item_code))
                    end
				elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
					print(string.format("onClear: skipping item_table with no item_code"))
				end
			elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
				print(string.format("onClear: skipping empty item_table"))
			end
		end
	end
    autoFill()
end

function onItem(index, item_id, item_name, player_number)
    if item_id > 128 then return end -- Ignore coin items
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
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
        print(string.format("onItem: could not find item mapping for id %s", item_id))
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
                print(string.format("onItem: unknown item type %s for code %s", item_type, item_code))
            end
        else
            print(string.format("onItem: could not find object for code %s", item_code[1]))
        end
    end
end

-- called when a location gets cleared
function onLocation(location_id, location_name)
    if location_id > 60 then return end -- Skip coinsanity
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then
        print(string.format("onLocation: could not find location mapping for id %s", location_id))
        return
    end

    for _, location in pairs(location_array) do
        local location_obj = Tracker:FindObjectForCode(location)
        -- print(location, location_obj)
        if location_obj then
            if location:sub(1, 1) == "@" then
                location_obj.AvailableChestCount = location_obj.AvailableChestCount - 1
            else
                location_obj.Active = true
            end
        else
            print(string.format("onLocation: could not find location_object for code %s", location))
        end
    end
end

-- this Autofill function is meant as an example on how to do the reading from slotdata and mapping the values to
-- your own settings
function autoFill()
    if SLOT_DATA == nil then
        print("No slot data")
        return
    end
    print(dump_table(SLOT_DATA))

    -- mapToggle={[0]=0,[1]=1,[2]=1,[3]=1,[4]=1}
    -- mapToggleReverse={[0]=1,[1]=0,[2]=0,[3]=0,[4]=0}
    -- mapTripleReverse={[0]=2,[1]=1,[2]=0}

    -- slotCodes = {
    --     map_name = {code="", mapping=mapToggle...}
    -- }
    -- for settings_name, settings_value in pairs(SLOT_DATA) do
    --     print(settings_name, settings_value)
    --     if slotCodes[settings_name] then
    --         item = Tracker:FindObjectForCode(slotCodes[settings_name].code)
    --         if item.Type == "toggle" then
    --             item.Active = slotCodes[settings_name].mapping[settings_value]
    --         else
    --             -- print(k,v,Tracker:FindObjectForCode(slotCodes[k].code).CurrentStage, slotCodes[k].mapping[v])
    --             item.CurrentStage = slotCodes[settings_name].mapping[settings_value]
    --         end
    --     end
    -- end
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClearHandler)
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
    Archipelago:AddItemHandler("item handler", onItem)
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
    Archipelago:AddLocationHandler("location handler", onLocation)
end

-- Archipelago:AddSetReplyHandler("notify handler", onNotify)
-- Archipelago:AddRetrievedHandler("notify launch handler", onNotifyLaunch)

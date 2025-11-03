-- from https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
-- dumps a table in a readable string
function dump_table(o, depth)
    if depth == nil then
        depth = 0
    end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. tabs2 .. '[' .. k .. '] = ' .. dump_table(v, depth + 1) .. ',\n'
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end

function has_value (t, val)
    for i, v in ipairs(t) do
        if v == val then return 1 end
    end
    return 0
end

function toggle_itemgrid()
    local fragments = Tracker:FindObjectForCode("set-gc-goal").CurrentStage == 2
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage
    local scrollMode = Tracker:FindObjectForCode("set-scroll-mode").CurrentStage
    local globalScroll = scrollMode == 1 or scrollMode == 3

    if pipeMode == 2 then
        if globalScroll then
            if fragments then
                Tracker:AddLayouts("layouts/items_fragments_split_scroll.json")
            else
                Tracker:AddLayouts("layouts/items_coins_split_scroll.json")
            end
        else
            if fragments then
                Tracker:AddLayouts("layouts/items_fragments_split.json")
            else
                Tracker:AddLayouts("layouts/items_coins_split.json")
            end
        end
    elseif pipeMode == 1 then
        if globalScroll then
            if fragments then
                Tracker:AddLayouts("layouts/items_fragments_single_scroll.json")
            else
                Tracker:AddLayouts("layouts/items_coins_single_scroll.json")
            end
        else
            if fragments then
                Tracker:AddLayouts("layouts/items_fragments_single.json")
            else
                Tracker:AddLayouts("layouts/items_coins_single.json")
            end
        end
    else
        if globalScroll then
            if fragments then
                Tracker:AddLayouts("layouts/items_fragments_scroll.json")
            else
                Tracker:AddLayouts("layouts/items_coins_scroll.json")
            end
        else
            if fragments then
                Tracker:AddLayouts("layouts/items_fragments.json")
            else
                Tracker:AddLayouts("layouts/items_coins.json")
            end
        end
    end
end

function toggle_maingrid()
    local midways = Tracker:FindObjectForCode("set-shuffle-midways").Active
    local scrollMode = Tracker:FindObjectForCode("set-scroll-mode").CurrentStage
    local levelScroll = scrollMode == 2 or scrollMode == 4 or scrollMode == 5

    if levelScroll then
        if midways then
            Tracker:AddLayouts("layouts/main_midway_scroll.json")
        else
            Tracker:AddLayouts("layouts/main_scroll.json")
        end
    else
        if midways then
            Tracker:AddLayouts("layouts/main_midway.json")
        else
            Tracker:AddLayouts("layouts/main.json")
        end
    end
end

function toggle_settings()
    if Tracker:FindObjectForCode("set-gc-goal").CurrentStage == 2 then
        Tracker:AddLayouts("layouts/settings_popup_fragments.json")
    else
        Tracker:AddLayouts("layouts/settings_popup_coins.json")
    end
end

function toggle_midways()
    if Tracker:FindObjectForCode("set-mario-castle-midway").Active then
        Tracker:AddLayouts("layouts/midways_mario.json")
    else
        Tracker:AddLayouts("layouts/midways.json")
    end
end
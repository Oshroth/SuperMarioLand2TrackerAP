-- put logic functions here using the Lua API: https://github.com/black-sliver/PopTracker/blob/master/doc/PACKS.md#lua-interface
-- don't be afraid to use custom logic functions. it will make many things a lot easier to maintain, for example by adding logging.
-- to see how this function gets called, check: locations/locations.json
-- example:
function has_more_then_n_consumable(n)
    local count = Tracker:ProviderCountForCode('consumable')
    local val = (count > tonumber(n))
    if ENABLE_DEBUG_LOG then
        print(string.format("called has_more_then_n_consumable: count: %s, n: %s, val: %s", count, n, val))
    end
    if val then
        return 1 -- 1 => access is in logic
    end
    return 0 -- 0 => no access
end

function no_scroll(levelCode)
    local scrollMode = Tracker:FindObjectForCode("set-scroll-mode").CurrentStage
    local levelNotScroll = has("cancelautoscroll-"..levelCode)
    if scrollMode == 6 then
        return true
    elseif scrollMode == 3 or scrollMode == 1 then
        return has("cancelautoscroll") or levelNotScroll
    else
        return levelNotScroll
    end
end

function has_pipe_up()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-up")
end

function has_pipe_down()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-down")
end

function has_pipe_left()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-left")
end

function has_pipe_right()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-right")
end

function has_midway(code)
    return has(code.."midwaybell") and has("set-shuffle-midways")
end

function has_castle_midway()
    return has("set-mario-castle-midway") and has_midway("mariocastle")
end

function has_goal()
    if Tracker:FindObjectForCode("set-gc-goal").CurrentStage == 2 then
        return has("mariocoinfragment", Tracker:FindObjectForCode("set-mc-frag-required").AcquiredCount)
    else
        return has("goalcoin", Tracker:FindObjectForCode("set-gc-required").AcquiredCount)
    end
end

function can_take_hit(count)
    if not count then
        return has("mushroom") or has("carrot") or has("fireflower")
    end
    local powerups = 0
    if has("mushroom") then
        powerups = powerups + 1
    end
    if has("carrot") or has("fireflower") then
        powerups = powerups + 1
    end
    count = tonumber(count)
    return powerups >= count
end

function can_spin()
    return has("mushroom") or has("fireflower")
end

function not_shuffle_midways()
    return not Tracker:FindObjectForCode("set-shuffle-midways").Active
end

function not_blocked_by_sharks()
    local sharks = Tracker:ProviderCountForCode("set-tz1-sharks")
    if sharks == 0 or has("carrot") then
        return true
    else
        return can_take_hit(sharks)
    end
end

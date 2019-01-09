local Event = require('__stdlib__/stdlib/event/event')
local table = require('__stdlib__/stdlib/utils/table')
local lib = require('__PickerAtheneum__/utils/lib')

local function summon_deconstruction_planner(event)
    local player = game.players[event.player_index]
    local stack = player.cursor_stack
    local tree_planner = event.input_name == 'picker-summon-trees-deconstruction-planner'
    if not stack.valid_for_read then
        local item = lib.find_item_in_inventory('deconstruction-planner', player.get_main_inventory(), {is_deconstruction_not_setup = true}) or 'deconstruction-planner'
        if not lib.set_or_swap_item(player, stack, item) then
            return
        end
        stack.trees_and_rocks_only = tree_planner
    elseif stack.is_deconstruction_item then
        if (#stack.entity_filters > 0 or #stack.tile_filters > 0) then
            local item = lib.find_item_in_inventory('deconstruction-planner', player.get_main_inventory(), {is_deconstruction_not_setup = true})
            if not lib.set_or_swap_item(player, stack, item or 'deconstruction-planner') then
                return
            end
        end
        stack.trees_and_rocks_only = tree_planner
    elseif stack.is_selection_tool or (stack.is_blueprint and not stack.is_blueprint_setup()) then
        local item = lib.find_item_in_inventory('deconstruction-planner', player.get_main_inventory(), {is_deconstruction_not_setup = true})
        if not lib.set_or_swap_item(player, stack, item or 'deconstruction-planner') then
            return
        end
        stack.trees_and_rocks_only = tree_planner
    end
end
Event.register({'picker-summon-deconstruction-planner', 'picker-summon-trees-deconstruction-planner'}, summon_deconstruction_planner)

local function toggle_filter_mode(event)
    local player = game.players[event.player_index]
    local stack = player.cursor_stack
    local mode = event.input_name == "picker-toggle-filter-mode" and "entity_filter_mode" or "tile_filter_mode"
    if stack.valid_for_read and stack.name == 'deconstruction-planner' then
        local whitelist = defines.deconstruction_item[mode].whitelist
        local blacklist = defines.deconstruction_item[mode].blacklist
        if stack[mode] == whitelist then
            stack[mode] = blacklist
            player.print({'deconstructor.'..mode ..'-blacklist'})
        else
            stack[mode] = whitelist
            player.print({'deconstructor.'..mode ..'-whitelist'})
        end
    end
end
Event.register({"picker-toggle-filter-mode", "picker-toggle-tile-filter-mode"}, toggle_filter_mode)

local tile_mode = table.invert(defines.deconstruction_item.tile_selection_mode)
local function cycle_tile_mode(event)
    local player = game.players[event.player_index]
    local stack = player.cursor_stack
    if stack.valid_for_read and stack.name == 'deconstruction-planner' then
        local next_mode = (stack.tile_selection_mode + 1 < table.size(tile_mode)) and (stack.tile_selection_mode + 1) or 0
        stack.tile_selection_mode = next_mode
        player.print({'deconstructor.tile-selection-mode', {'deconstructor.'..tile_mode[next_mode]}})
    end
end
Event.register("picker-cycle-tile-selection-mode", cycle_tile_mode)

local function pick_deconstruction_filter(event)
    local player = game.players[event.player_index]
    local stack = player.cursor_stack
    local selected = player.selected
    if selected and stack.valid_for_read and stack.name == 'deconstruction-planner' then
        if selected.type ~= 'resource' and selected.type ~= 'tree' and selected.type ~= 'simple-entity' then
            local first_free_slot
            for i = 1, stack.entity_filter_count, 1 do
                local filter = stack.get_entity_filter(i)
                if selected.name == filter then
                    stack.set_entity_filter(i, nil)
                    return
                end

                if not first_free_slot and not filter then
                    first_free_slot = i
                end
            end

            if first_free_slot then
                stack.set_entity_filter(first_free_slot, selected)
            else
                player.print({'deconstructor.no-empty-slots'})
            end
        end
    end
end
Event.register('picker-pick-deconstruction-filter', pick_deconstruction_filter)

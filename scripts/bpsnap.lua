--[[
    "name": "BlueprintExtensions",
    "title": "Blueprint Extensions",
    "author": "Dewin",
    "contact": "https://github.com/dewiniaid/BlueprintExtensions",
    "homepage": "https://github.com/dewiniaid/BlueprintExensions",
    "description": "Adds tools for updating and placing blueprints."
--]]
local Event = require('__stdlib__/stdlib/event/event')
local Inventory = require('__stdlib__/stdlib/entity/inventory')
local Position = require('__stdlib__/stdlib/area/position')
local Area = require('__stdlib__/stdlib/area/area')

local min, max = math.min, math.max
local table = require('__stdlib__/stdlib/utils/table')

local Snap = {}

local events = {
        ['picker-bp-snap-n'] = {-1, 0},
        ['picker-bp-snap-s'] = {1, 0},
        ['picker-bp-snap-w'] = {0, -1},
        ['picker-bp-snap-e'] = {0, 1},
        ['picker-bp-snap-center'] = {0, 0},
        ['picker-bp-snap-nw'] = {-1, -1},
        ['picker-bp-snap-ne'] = {-1, 1},
        ['picker-bp-snap-sw'] = {1, -1},
        ['picker-bp-snap-se'] = {1, 1}
    }



local function update_bounds(bound, point, min_edge, max_edge)
    min_edge = point + min_edge
    max_edge = point + max_edge
    if bound.min == nil then
        bound.min = point
        bound.max = point
        bound.min_edge = min_edge
        bound.max_edge = max_edge
        return
    end
    bound.min = min(bound.min, point)
    bound.max = max(bound.max, point)
    bound.min_edge = min(bound.min_edge, min_edge)
    bound.max_edge = max(bound.max_edge, max_edge)
end

function Snap.blueprint_bounds(bp)
    local prototypes = game.entity_prototypes

    local bounds = {
        x = {min_edge = nil, min = nil, mid = nil, max_edge = nil, max = nil},
        y = {min_edge = nil, min = nil, mid = nil, max_edge = nil, max = nil}
    }
    local align = 1

    local rect = {} -- Reduce GC churn by declaring this here and updating it in the loop rather than reinitializing
    -- every pass

    for _, entity in pairs(bp.get_blueprint_entities() or {}) do
        local rot = Snap.rotations[entity.direction or 0]
        local box = prototypes[entity.name].selection_box
        rect[1] = box.left_top.x
        rect[2] = box.left_top.y
        rect[3] = box.right_bottom.x
        rect[4] = box.right_bottom.y

        local x1 = rect[rot[1]]
        local y1 = rect[rot[2]]
        local x2 = rect[rot[3]]
        local y2 = rect[rot[4]]

        if x1 > x2 then
            x1, x2 = -x1, -x2
        end
        if y1 > y2 then
            y1, y2 = -y1, -y2
        end

        update_bounds(bounds.x, entity.position.x, x1, x2)
        update_bounds(bounds.y, entity.position.y, y1, y2)
        align = max(align, Snap.alignment_overrides[entity.name] or align)
    end

    for _, tile in pairs(bp.get_blueprint_tiles() or {}) do
        update_bounds(bounds.x, tile.position.x, -0.5, 0.5)
        update_bounds(bounds.y, tile.position.y, -0.5, 0.5)
    end

    return bounds, align
end

local function offset(t, xoff, yoff)
    for _, v in pairs(t) do
        if not v.position then
            return nil
        end

        v.position.x = v.position.x + xoff
        v.position.y = v.position.y + yoff
    end
    return t
end

function Snap.offset_blueprint(bp, xoff, yoff)
    local entities = bp.get_blueprint_entities()
    local tiles = bp.get_blueprint_tiles()

    if entities then
        bp.set_blueprint_entities(offset(entities, xoff, yoff))
    end
    if tiles then
        bp.set_blueprint_tiles(offset(tiles, xoff, yoff))
    end
end


local function calculate_offset(dir, bound, align)
    local o = (dir ~= nil and math.floor(((-bound.min_edge - (dir * (bound.max_edge - bound.min_edge))) / align)) * align) or 0
    if dir == 1 then
        -- The math works out to offset by the total width/height if we're aligning to max, but we want the max to
        -- end up under the cursor.
        return o + align
    end
    return o
end

function Snap.align_blueprint(bp, xdir, ydir)
    local bounds, align = Snap.blueprint_bounds(bp)
    local xoff = calculate_offset(xdir, bounds.x, align)
    local yoff = calculate_offset(ydir, bounds.y, align)
    return Snap.offset_blueprint(bp, xoff, yoff)
end

local function get_bounds(entities, tiles)
    local bounds = Area()
    local shift = 0

    local function outer_most(box)
        bounds.left_top.x = min(bounds.left_top.x, box.left_top.x)
            bounds.left_top.y  = min(bounds.left_top.y, box.left_top.y)
            bounds.right_bottom.x  = max(bounds.right_bottom.x, box.right_bottom.x)
            bounds.right_bottom.y = max(bounds.right_bottom.y, box.right_bottom.y)
    end


    for _, entity in pairs(entities) do
        local proto = game.entity_prototypes[entity.name]
        local box = proto.selection_box

        if proto.building_grid_bit_shift > 0 then
            shift = 1
        end

        if box then
            outer_most(Area(box))

        end
    end

    for _, tile in pairs(tiles) do
        outer_most(Position(tile.position):to_tile_area())
    end
    return bounds, shift
end

local function align_blueprint(entities, tiles, vector)
    local bounds, shift = get_bounds(entities, tiles)
    return bounds, shift
end

-- local function get_shift(entities)
--     for _, entity in pairs(entities) do
--         local proto = game.entity_prototypes[entity.name]
--         if proto and proto.building_grid_bit_shift > 0 then
--             return 1
--         end
--     end
--     return 0
-- end

local function on_snap(event)
    local player = game.get_player(event.player_index)
    local bp = Inventory.get_blueprint(player.cursor_stack, true)

    if bp then
        local player_settings = player.mod_settings

        local entities = bp.get_blueprint_entities() or {}
        local tiles = bp.get_blueprint_tiles() or {}

        local x_dir = player_settings['picker-bp-snap-horizontal-invert'].value and -1 or 1
        local y_dir = player_settings['picker-bp-snap-vertical-invert'].value and -1 or 1

        local vector = Position(events[event.input_name]) * {x_dir, y_dir}
        -- local x, y = table.unpack(events[event.input_name])
        -- x, y = x * invert_x, y * invert_y

        align_blueprint(entities, tiles, vector)
    end
end
Event.register(table.keys(events), on_snap)

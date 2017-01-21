-- Adapted from: https://github.com/lattejed/a-star-lua/blob/master/a-star.lua

-- ======================================================================
-- Copyright (c) 2012 RapidFire Studio Limited
-- All Rights Reserved.
-- http://www.rapidfirestudio.com

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ======================================================================

require 'stdlib/area/tile'
require 'libs/debug'
local HeapPriorityQueue = require 'libs/heapPriorityQueue'
 
global.grid_scale = 1
pathfinder = {}
pathfinder.__index = pathfinder

-- Partially search for a path on the given surface between the start_pos and goal_pos
-- If the search completes, the path object will be inside of the returned table { completed = true, path = { ... }}
-- If the search is not yet completed, the returned table will be { completed = false, ... }
-- Pathfinding can be resumed with pathfinder.resume_a_star
function pathfinder.partial_a_star(surface, start_pos, goal_pos, max_iterations, max_total_iterations)
    local pathfinding_data = pathfinder.get_pathfinding_data(surface, start_pos, goal_pos, max_total_iterations)
    return pathfinder.resume_a_star(pathfinding_data, max_iterations)
end

-- Resumes an uncomplete pathfinding search, given the partially completed data and max iterations
function pathfinder.resume_a_star(pathfinding_data, max_iterations)
    for i = 1, max_iterations do
        local result = pathfinder.step_a_star(pathfinding_data)
        if pathfinding_data.completed then
            return { completed = true, path = result }
        end
    end
    return pathfinding_data
end

-- Find a complete path on the given surface between the start_pos and goal_pos
function pathfinder.a_star(surface, start_pos, goal_pos, max_total_iterations)
    local pathfinding_data = pathfinder.get_pathfinding_data(surface, start_pos, goal_pos, max_total_iterations)
    while not pathfinding_data.completed do
        local result = pathfinder.step_a_star(pathfinding_data)
        if pathfinding_data.completed then
            return result
        end
    end
    return nil
end

function pathfinder.get_pathfinding_data(surface, start_pos, goal_pos, max_total_iterations)
    if not pathfinder.is_walkable(surface, goal_pos) then
        return { completed = true }
    end

    local start_tile = Tile.from_position(start_pos)
    local goal_tile = Tile.from_position(goal_pos)

    local closed_set = {}
    local start_key = pathfinder.node_key(start_tile)
    local open_set = {}
    open_set[start_key] = start_tile 
    local came_from = {}

    local g_score = {}

    local f_score = HeapPriorityQueue.new(function(a, b) 
        return a.f_score < b.f_score
    end, {})
    
    f_score:push(wrapFScore(start_key, pathfinder.heuristic_cost_estimate(start_tile, goal_tile)))
    g_score[start_key] = 0

    return
    {
        surface = surface,
        start_pos = start_tile,
        goal_pos = goal_tile,
        closed_set = closed_set,
        open_set = open_set,
        came_from = came_from,
        g_score = g_score,
        f_score = f_score,
        iterations = 0,
        max_total_iterations = max_total_iterations,
        completed = false
    }
end

function wrapFScore(key, f_score)
    return {key=key, f_score=f_score}
end
    
function pathfinder.step_a_star(data)
    if data.iterations > data.max_total_iterations then
        data.completed = true
        return nil
    end
    data.iterations = data.iterations + 1

    local current_key = nil
    repeat 
        local wrappedFScore = data.f_score:pop()
        current_key = wrappedFScore.key
        if current_key == nil then
            data.completed = true
            return nil
        end
    until data.open_set[current_key] ~= nil

    local current = data.open_set[current_key]
    if current.x == data.goal_pos.x and current.y == data.goal_pos.y then
        local path = pathfinder.unwind_path({}, data.came_from, data.goal_pos)
        table.insert(path, data.goal_pos)
        data.completed = true
        return path
    end

    data.open_set[current_key] = nil
    data.closed_set[current_key] = true

    local neighbors = pathfinder.neighbor_nodes(data.surface, current)
    for _, neighbor in pairs(neighbors) do
        local key = pathfinder.node_key(neighbor)
        if not data.closed_set[key] then
            local candidate_g_score = data.g_score[current_key] + pathfinder.heuristic_cost_estimate(current, neighbor)
            local neighbor_key = pathfinder.node_key(neighbor)
            if not data.open_set[key] or candidate_g_score < data.g_score[neighbor_key] then
                data.came_from[neighbor_key] = current
                data.g_score[neighbor_key] = candidate_g_score
                local f_score = data.g_score[neighbor_key] + pathfinder.heuristic_cost_estimate(neighbor, data.goal_pos)
                data.f_score:push(wrapFScore(neighbor_key, f_score))
                if not data.open_set[key] then
                    data.open_set[key] = neighbor
                end
            end
        end
    end
end

function pathfinder.node_key(pos)
    local key = bit32.bor(bit32.lshift(bit32.band(pos.x, 0xFFFF), 16), bit32.band(pos.y, 0xFFFF))
    return key
end

function pathfinder.heuristic_cost_estimate(nodeA, nodeB)
    local x = math.abs(nodeB.x - nodeA.x)
    local y = math.abs(nodeB.y - nodeA.y)
    local sqrt2 = 1.5 -- optimisation

    -- 8 directions:
    return math.max(x, y) + (sqrt2-1) * math.min(x, y)

    -- 4 directions : 
    --return x + y


    --return  + math.abs(nodeB.y - nodeA.y)
    --return (nodeB.x - nodeA.x)^2 + (nodeB.y - nodeA.y)^2
end

function pathfinder.neighbor_nodes(surface, center_node)
    local neighbors = {}
    local adjacent = {{0, 1}, {0, -1}, {1, 0}, {-1, 0}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
    for _, tuple in pairs(adjacent) do
        local x = center_node.x + tuple[1] * global.grid_scale
        local y = center_node.y + tuple[2] * global.grid_scale
        local position = {x = x, y = y}
        if pathfinder.is_walkable(surface, position) then
            table.insert(neighbors, position)
        end
    end
    return neighbors
end

-- todo: 
-- optionally check if enemies are close, don't want to accidentally path into them, but need to support hunting them
-- allow crossing gates (assume no circuit logic) and railways. Remember to block walking through enemy gates.
-- optionally support destroying certain entity types to create a path

-- might need to just get all entities in the tile and figure out what its bounding box looks like within this tile and determine how to path around it 
--      this would require changing pathing from being aligned to a 1x1 grid

function pathfinder.is_walkable(surface, position)
    Debug("Checking walkable for {" .. position.x .. ", " .. position.y .. "}")
    local tile = surface.get_tile(position.x, position.y)
    if surface.can_place_entity{name="transport-belt", position = tile.position} or surface.can_place_entity{name="express-transport-belt", position = tile.position} then
        return true
    end
    Debug("Can't place transport belt")
    if tile.collides_with("player-layer") then
        Debug("Collides with player layer")        
        return false
    end
    if surface.count_entities_filtered{area = {position, {position.x + global.grid_scale, position.y + global.grid_scale}}, type = "tree"} ~= 0 then
        Debug("Contains trees")
        return false
    end
    return true
end


function pathfinder.unwind_path(flat_path, map, current_node)
    local map_value = map[pathfinder.node_key(current_node)]
    if map_value then
        table.insert(flat_path, 1, map_value)
        return pathfinder.unwind_path(flat_path, map, map_value)
    else
        return flat_path
    end
end
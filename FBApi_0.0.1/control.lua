require 'util'
require 'libs/pathfinder'
require 'libs/debug'
require 'stdlib/event/event'

-- the task of optimising placement of a layout includes knowing efficient direct paths as well as paths that have value for secondary goals (a minor additional cost may be preferred)
-- also needs to know what paths will be made invalid given the actions to be performed

-- how about multiple api layers, so that fine control can be given, but also high level controls?

--[[ Current API:
	- WalkTo(player, x, y)
		directs the character to move directly towards the destination despite obstacles(as best we can with 8 directions)
	- WalkPath(player, path)
		directs the character to move along the path given
	- ShowPath(player, x, y)
		calculates a path and calls WalkPath
	

	 Planned Path API:
	- PathTo(player, x, y) 
		returns a path representing an approximation to the shortest path, including directions per tick, number of directions is cost of path
	- PathToReach(player, entity)
		returns a path representing an approximation to the shortest path to get in range of the given entity

	

-- some mechanism to figure out where expensive path blockers are, for commonly followed paths (trees that are cost effective to remove)
-- some mechanism to evaluate the path cost or value (concrete) of placing any entity onto the map

--]]

-- globals
global.destination = nil
global.path = nil
global.pathIndex = 2
global.eps = 0.15 -- careful of movement per tick getting high
global.tilePositionOffset = 0
global.walkingPlayer = nil
global.pathingPlayer = nil
global.previousPosition = nil
global.previousDirection = nil

--registrations
script.on_event(defines.events.on_tick, function()
 	HandlePathEvent();
 	HandleWalkEvent();
end)

-- event handlers
function HandleWalkEvent() 
	if global.destination == nil or global.walkingPlayer == nil then
		return
	end
	local player = game.players[global.walkingPlayer]	
	if ApproximatelyEqual(player.position.x, global.destination.x) and ApproximatelyEqual(player.position.y, global.destination.y) then
		global.destination = nil
		return
	end

	local walkingDirection = CalculateDestinationDirection(player.position, global.destination)

	player.walking_state = { walking = true, direction = walkingDirection}
	global.previousDirection = walkingDirection
	global.previousPosition = player.position
end

function HandlePathEvent()	
	if global.path == nil or #global.path == 0 then -- no path set
		return
	end
	if global.destination ~= nil then
		return
	end
	global.destination = nil
	local position = global.path[global.pathIndex]
	WalkToPosition(global.pathingPlayer, position.x, position.y)
	global.pathIndex = global.pathIndex+1
	if global.pathIndex > #global.path then
		global.path = nil
	end
end 

-- methods

function WalkToPosition(playerIndex, x, y)
	global.destination = {}
	global.destination.x = x + global.tilePositionOffset 
	global.destination.y = y + global.tilePositionOffset 
	global.walkingPlayer = playerIndex
end

function WalkAlongPath(playerIndex, path)
	global.pathIndex = 1
	global.path = path
	global.pathingPlayer = playerIndex
end

function FindPathTo(player_idx, x, y)
	Debug("Received request to {" .. x .. ", " .. y .. "}")
    local pos = game.players[player_idx].position
    local dest =  { x = pos.x + x, y = pos.y + y}
    local path = pathfinder.a_star(game.players[player_idx].surface, pos, dest , 10000)
    if path ~= nil then
        WalkAlongPath(player_idx, path)
    else
    	Debug("No Path Possible")
    end
end

function CalculateDestinationDirection(source, destination)
	if ApproximatelyEqual(source.x, destination.x) then
		if source.y > destination.y then
			return defines.direction.north
		else
			return defines.direction.south
		end
	else
		if source.x > destination.x then
			if ApproximatelyEqual(source.y, destination.y) then
				return defines.direction.west
			else
				if source.y > destination.y then
					return defines.direction.northwest
				else
					return defines.direction.southwest
				end
			end
		else
			if ApproximatelyEqual(source.y, destination.y) then
				return defines.direction.east
			else
				if source.y > destination.y then
					return defines.direction.northeast
				else
					return defines.direction.southeast
				end
			end
		end
	end
	return -1
end

function ApproximatelyEqualPositions(a, b)
	return ApproximatelyEqual(a.x, b.x) and ApproximatelyEqual(a.y, b.y) 
end

function ApproximatelyEqual(a, b)
	return math.abs(a - b) <= global.eps 
end

function LogPlayerPosition(player)
	Debug("Player at " .. player.position.x .. ", " .. player.position.y)
end


-- interfaces
remote.add_interface("FBApi", { WalkTo = WalkToPosition, WalkPath = WalkAlongPath, ShowPath = FindPathTo })
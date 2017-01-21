require 'stdlib/event/event'
require 'libs/debug'

global.testNumber = 1
global.ticksScheduled = 1

--todo can make parallel by using multiple player entities!
--this way of running tests will probably cause issues with save/load due to closures being lost


function ResetWorld(playerIndex)
	game.players[playerIndex].teleport({0, 0})

	local entitiesToDelete = game.players[playerIndex].surface.find_entities_filtered{area={{x=-25,y=-25}, {x=25, y=25}}}
	for k, v in pairs(entitiesToDelete) do
		if v.type ~= "player" then
			v.destroy()
		end
	end

	-- todo fill in water
end

function RunTest(playerIndex, performRemoteCall, ticksToWait, assertion, failureMessage)
	local testNumber = global.testNumber
	local tickToScheduleReset = math.max(global.ticksScheduled, game.tick) + 1

	Event.register(defines.events.on_tick, function() 
		if game.tick == tickToScheduleReset then
			ResetWorld(playerIndex)
		end
	end)
	

	local tickToScheduleRemoteCall = tickToScheduleReset + 60
	Event.register(defines.events.on_tick, function() 
		if game.tick == tickToScheduleRemoteCall then
			performRemoteCall()
		end
	end)

	local assertionTick = tickToScheduleRemoteCall + ticksToWait
	Event.register(defines.events.on_tick, function() 
		if game.tick == assertionTick then
			if not assertion() then
				Debug("Test Failed with message: " .. failureMessage)
			else 
				Debug("Test " .. testNumber ..  " passed")
			end
		end
	end)

	global.ticksScheduled = assertionTick + 1
	global.testNumber = testNumber + 1
end

-- assertion helpers
global.eps = 0.15
function ApproximatelyEqualPositions(a, b)
	return ApproximatelyEqual(a.x, b.x) and ApproximatelyEqual(a.y, b.y) 
end

function ApproximatelyEqual(a, b)
	return math.abs(a - b) <= global.eps 
end

-- Tests
function ShowPath_UnitDistance(playerIndex)
	Debug("ShowPath_UnitDistance Test")
	local positions = {{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}}
	for _, position in ipairs(positions) do
		ShowPathTo(playerIndex or 1, position[1], position[2])
	end
end

function ShowPathTo(playerIndex, x, y)
	CreateShowPathTest(playerIndex or 1, {x=x, y=y})
end

function CreateShowPathTest(playerIndex, position)
	local player = game.players[playerIndex]
	local function remoteCall()
		remote.call("FBApi", "ShowPath", playerIndex, position.x, position.y)
	end
	local function confirmMovementOccurred()
		return ApproximatelyEqualPositions(player.position, position)
	end
	local failureMessage = "Player position was expected to be {" .. position.x .. ", " .. position.y .. "} but was {" .. player.position.x .. ", " .. player.position.y .. "}"
	RunTest(playerIndex, remoteCall, 180, confirmMovementOccurred, failureMessage)
end

-- Manually run specific tests:
remote.add_interface("FBApiTest", { ShowPathUnit = ShowPath_UnitDistance, ShowPathTo = ShowPathTo })
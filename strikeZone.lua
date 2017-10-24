--[[
	according to test, spawned target cannot hold mission objective, also cannot be teleported.
	
	marker should be activated in the begining, then 
	move to target position, and show the mission objective.
	
	strike target must at ground level and with 0 meter high.
	
	so marker always exists but moves a lot. 
	before call strike, spawn marker target, let marker move to marker target.
	when marker is in position, recovery marker target, show the mission objective, 
	spawn strike target, then call strike.
	after strike, recovery strike target, hide mission objective.
	
	finally, recovery marker if condition allowed.
--]]

SCRIPT_NAME = "strikeZone"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("start")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["center"] = { --center of possible artillery strike zone. should be updated in code
            x = -1,
            z = -1
        }
        data["radius"] = 1000 --radius of possible strike zone
        data["strikeCenter"] = { --center of next artillery strike zone
            x = -1,
            z = -1
        }
        data["range"] = 100 --range of artillery strike
        data["params"] = { 
            army = 2,
            ammoSize = "howitzer",
            ammoType = "he",
            formation = "harassing",
            delay = 3600
        }
        data["interval"] = 3600 --interval of next strike. delay after 'start' is 3.6 seconds
        data["marker"] = {
            name = "",
            setName = "dangerMarkerSet",
            setID = -1,
            height = 100 --marker height
        }
        data["strikeLength"] = 45000 --duration of one strike. should be test and update in code
	else
        
	end
end

function log(message)
	OFP:displaySystemMessage(message)
end

function start()
	log("start")
    EDX:serialTimer("strike", data["interval"])
end

function updateStrikeCenter()
	log('updateStrikeCenter')
    local radius = math.random(1, data["radius"])
    local dir = math.random(0, 359)
    local rad = math.rad(dir)
    local dx = math.cos(rad) * radius
    local dz = math.sin(rad) * radius

    local center = data["center"]
    local strikeCenter = data["strikeCenter"]
    strikeCenter.x = center.x + dx
    strikeCenter.z = center.z - dz
end

function updateInterval()
	log('updateInterval')
    data["interval"] = math.rad(36, 60) * 1000
end

function strike(timerID)
	log('strike')
    math.randomseed(os.time())
    updateStrikeCenter()

    local center = data["strikeCenter"]
    local marker = data["marker"]
    --marker.setID = OFP:spawnEntitySetAtLocation(marker.setName, center.x, marker.height, center.z)
	marker.setID = OFP:activateEntitySet(marker.setName)
    updateInterval()
    --EDX:setTimer(timerID, data["interval"]) --strike only once for now
end

function onMarkerReady()
	log('onMarkerReady')
	--OFP:setObjectiveVisibility('objective', true)
    local args = data["params"]
    local target = data["marker"].name
    OFP:setInvulnerable(target, true)--for test
    log('target - '..target)
    OFP:callArtilleryStrike(args.army, target, args.ammoSize, args.ammoType, args.formation, args.delay)
    EDX:simpleTimer("onStrikeEnd", data["strikeLength"])
end

function onStrikeEnd(timerID)
	log('onStrikeEnd')
    EDX:deleteTimer(timerID)
    stop()
end

function stop()
	log('stop')
    --OFP:destroyEntitySet(data["marker"].setID)--for test
    data["marker"].setID = -1
end

function checkMarker(setName, setID, entities)
	log('checkMarker')
    if data["marker"].setID == setID then
        data["marker"].name = entities[1]
        onMarkerReady()
    end
end

function onSpawnedReady(setName, setID, entities)
    checkMarker(setName, setID, entities)
end


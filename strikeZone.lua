
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
            height = 8000 --marker height
        }
        data["strikeLength"] = 3600 --duration of one strike. should be test and update in code
	else
        
	end
end

function start()
    EDX:serialTimer(strike, data["interval"])
end

function updateStrikeCenter()
    local radius = math.random(1, data["radius"])
    local dir = math.random(0, 359)
    local dx = math.cos(math.rad(dir)) * radius
    local dz = math.sin(math.rad(dir)) * radius

    local center = data["center"]
    local strikeCenter = data["strikeCnter"]
    strikeCenter.x = center.x + dx
    strikeCenter.z = center.z - dz
end

function updateInterval()
    data["interval"] = math.rad(16, 60) * 1000
end

function strike(timerID)
    math.randomseed(os.time())
    updateStrikeCenter()

    local center = data["strikeCenter"]
    local marker = data["marker"]
    marker.setID = OFP:spawnEntitySetAtPosition(marker.setName, center.x, marker.height, center.z)

    updateInterval()
    EDX:setTimer(timerID, data["interval"])
end

function onMarkerReady()
    local args = data["params"]
    OFP:callArtilleryStrike(args.army, data["marker"].name, args.ammoSize, args.ammoType, args.formation, args.delay)
    EDX:simpleTimer("onStrikeEnd", data["strikeLength"])
end

function onStrikeEnd(timerID)
    EDX:deleteTimer(timerID)
    stop()
end

function stop()
    OFP:destroyEntitySet(data["marker"].setID)
    data["marker"].setID = -1
end

function checkMarker(setName, setID, entities)
    if data["marker"].setID == setID then
        data["marker"].name = entities[1]
        onMarkerReady()
    end
end

function onSpawnedReady(setName, setID, entities)
    checkMarker(setName, setID, entities)
end


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
        data["range"] = 300 --range of artillery strike
        data["params"] = { 
            army = 2,
            ammoSize = "howitzer",
            ammoType = "he",
            formation = "harassing",
            delay = 3600
        }
        data["marker"] = {
            name = "",
            setName = "dangerMarkerSet",
            setID = -1,
            height = 100 --marker height
        }
        data["markerTarget"] { --waypoint which marker should move to
            name = "",
            setName = "dangerMarkerTargetSet",
            setID = -1,
            ready = false
        }
        data["strikeTarget"] = { --reconpoint whick is strike target
            name = "",
            setName = "dangerStrikeTargetSet",
            setID = -1,
            ready = false
        }
        data["objective"] = "dangerObjective" --hide objective before game loading
        data["timers"] = {
            start = {
                name = "startStrike",
                delay = 1600, --delay before next strike
                id = -1
            },
            strike = {
                name = "strike",
                delay = 3600 --wait marker stable
            },
            finish = {
                name = "strikeEnd",
                delay = 46000 --duration of one strike
            }
        }
	else
        
	end
end

function log(message)
    EDX["logger"].log("[strikeZone] "..message)
end

function start()
	log("start")

    local objective = data["objective"]
    OFP:setObjectiveMarkerVisibility(objective, false)
    OFP:setObjectiveVisibility(objective, false)

    local marker = data["marker"]
    marker.setID = OFP:activateEntitySet(marker.setName)
end

function onMarkerReady()
    log("onMarkerReady")

    local marker = data["marker"].name
    OFP:setInvulnerable(marker, true)
    OFP:setArmy(marker, 2)
    OFP:setVehicleIgnoredByAI(marker, true)

    local startTimer = data["timers"].start
    startTimer.id = EDX:serialTimer(startTimer.name, startTimer.delay)
end

function startStrike(timerID)
	log('strike')
    math.randomseed(os.time())
    updateStrikeCenter()
    generateTargets()
    updateNextStrikeDelay()
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

function updateNextStrikeDelay()
	log('updateNextStrikeDelay')

    local startTimer = data["timers"].start
    startTimer.delay = math.rad(16, 60) * 1000
end

function generateTargets()
    local strikeCenter = data["strikeCenter"]
    
    local markerTarget = data["markerTarget"]
    markerTarget.ready = false
    markerTarget.setID = OFP:spawnEntitySetAtPosition(markerTarget.setName, strikeCenter.x, data["marker"].height, strikeCenter.z)
    
    local strikeTarget = data["strikeTarget"]
    strikeTarget.ready = false
    local strikeHeight = OFP:getTerrainHeight(strikeCenter.x, strikeCenter.z)
    if strikeHeight < 0 then
        strikeHeight = 0
    end 
    strikeTarget.setID = OFP:spawnEntitySetAtPosition(strikeTarget.setName, strikeCenter.x, strikeHeight, strikeCenter.z)
end

function onMarkerTargetReady()
    log("onMarkerTargetReady")

    local markerTarget = data["markerTarget"]
    markerTarget.ready = true
    OFP:rapidMove(data["marker"].name, markerTarget.name, "override")
end

--this should always get ready first
function onStrikeTargetReady()
    log("onStrikeTargetReady")

    data["strikeTarget"].ready = true
end

function onMarkerInPosition()
    log("onMarkerInPosition")

    EDX["promptManager"].prompt("STR_COMING")
    --wait for marker to stable
    local strikeTimer = data["timers"].strike
    EDX:simpleTimer(strikeTimer.name, strikeTimer.delay)
end

function strike(timerID)
    log("strike")

    EDX:deleteTimer(timerID)
    
    local objective = data["objective"]
    OFP:setObjectiveMarkerVisibility(objective, true)
    OFP:setObjectiveVisibility(objective, true)

    local args = data["params"]
    local target = data["strikeTarget"].name

    OFP:callArtilleryStrike(args.army, target, args.ammoSize, args.ammoType, args.formation, args.delay)

    local strikeFinishTimer = data["timers"].finish
    EDX:simpleTimer(strikeFinishTimer.name, strikeFinishTimer.delay)
end

function strikeEnd(timerID)
	log('strikeEnd')

    EDX:deleteTimer(timerID)
    onStrikeFinished()
end

function onStrikeFinished()
	log('onStrikeFinished')
    
    local objective = data["objective"]
    OFP:setObjectiveMarkerVisibility(objective, false)
    OFP:setObjectiveVisibility(objective, false)

    local markerTarget = data["markerTarget"]
    OFP:destroyEntitySet(markerTarget.setID)
    markerTarget.setID = -1
    markerTarget.name = ""
    markerTarget.ready = false

    local strikeTarget = data["stikeTarget"]
    OFP:destroyEntitySet(strikeTarget.setID)
    strikeTarget.setID = -1
    strikeTarget.name = ""
    strikeTarget.ready = false

    local startTimer = data["timers"].start
    EDX:setTimer(startTimer.id, startTimer.delay)
end

function checkMarker(setName, setID, entities)
	log('checkMarker')

    if data["marker"].setID == setID then
        data["marker"].name = entities[1]
        onMarkerReady()
    end
end

function checkMarkerTarget(setName, setID, entities)
    log("checkMarkerTarget")

    if data["markerTarget"].setID == setID then
        data["markerTarget"].name = entities[1]
        onMarkerTargetReady()
    end
end

function checkStrikeTarget(setName, setID, entities)
    log("checkStrikeTarget")

    if data["strikeTarget"].setID == setID then
        data["strikeTarget"].name = entities[1]
        onStrikeTargetReady()
    end
end

function checkMarkerInPosition(entity, waypoint)
    log("checkMarkerInPosition")

    if entity == data["marker"].name and waypoint == data["markerTarget"].name then
        onMarkerInPosition()
    end
end

function onSpawnedReady(setName, setID, entities)
    checkMarker(setName, setID, entities)
end

function onArriveAtWaypoint(entity, waypoint)
    checkMarkerInPosition(entity, waypoint)
end


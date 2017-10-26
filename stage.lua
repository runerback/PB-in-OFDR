--[[
in the begining all playables are standing on stage, and set to invulnerable. after all other things are ready,
spawn the carrier.
put a spawnpoint on stage, so player will be respawned on stage, and cannot move or fire
carrier fly from out of map range to another out of map range.
before carrier enter map range, show letterboxosd
when carrier enter map range, close letterboxosd, print welcome message
when carrier leaving map range (10 meters from boudage), disembark all passengers still in helicopter
despawn carrier and range zone when carrier travel to end
--]]

SCRIPT_NAME = "stage"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("startPlay")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["playables"] = { --all playables here
            
        }
        data["stageSetName"] = "stageSet"
        data["carrier"] = {
            name = "",
            setName = "carrierSet",
            setID = -1
        }
        data["carrierPath"] = { --in startUp
            name = "carrierp",
            startpoint = "carrierStartpoint",
            endpoint = "carrierEndpoint"
            }
        data["mapRange"] = {
            name = "",
            setName = "mapRangeZone",
            setID = -1
        }
        initializeStage()
	else
        
	end
end

function log(message)
    EDX["logger"].log("[stage] "..message)
end

function initializeStage()
    log("initializeStage")

    for _, playable in pairs(data["playables"]) do
        --detatch. confrimation needed
        log("detatching "..playable)
        local topEchelon = OFP:getParentEchelon(playable)
        log("top echelon - "..topEchelon)
        OFP:detatch(playable, topEchelon)
        log("detatched")
        local curEchelon = OFP:getParentEchelon(playable)
        log("current echelon - "..curEchelon)
        
        --army
        OFP:setArmy(playable, 2)
        --jumper
        OFP:addToGroup(playable, "chunt")
        --invulnerable
        OFP:setInvulnerable(playable, true)
        --register
        EDX["unitsManager"].register(playable)
    end
    OFP:activateEntitySet(data["stageSetName"])
    log("stage spawned")
    data["stageSetName"] = nil
    data["mapRange"].setID = OFP:activateEntitySet(data["mapRange"].setName)
end

--start game
function startPlay()
    log("startPlay")

    data["carrier"].setID = OFP:spawnEntitySetAtEntityLocation(data["carrier"].setName, data["carrierPath"].startpoint)
end

function onCarrierReady()
    log("onCarrierReady")

    local carrier = data["carrier"].name
    log("carrier - "..carrier)
    OFP:setInvulnerable(carrier, true)
    OFP:setVehicleMountableStatus(carrier, 1)
    local path = data["carrierPath"].name
    log("path - "..path)
    OFP:rapidMove(carrier, path, "addtofront")
    OFP:showLetterBoxOsd(true)
end

function checkCarrier(setName, setID, entities)
    log("checkCarrier")

    if data and data["carrier"].setID == setID then
        data["carrier"].name = entities[1]
        onCarrierReady()
    end
end

function checkMapRange(setName, setID, entities)
    log("checkMapRange")

    if data and data["mapRange"].setID == setID then
        data["mapRange"].name = entities[1]
        log("map range checked")
    end
end

function checkMapRangeState(zone, unit)
    log("checkMapRangeState")

    if zone == data["mapRange"].name and unit == data["carrier"].name then
        log("carrier hit map edge")
        return true
    end
    return false
end

function onEnter(zone, unit)
    if data and checkMapRangeState(zone, unit) == true then
        onEnterMap()
    end
end

function onEnterMap()
    log("onEnterMap")

    OFP:showLetterBoxOsd(false)
    EDX["promptManager"].prompt("GAME_START")
end

function onLeave(zone, unit)
    if data and checkMapRangeState(zone, unit) == true then
        onLeavingMap()
    end
end

function onLeavingMap()
    log("onLeavingMap")

    EDX["promptManager"].prompt("CARRIER_LEAVING")
    
    local _, ch, _ = OFP:getPosition(data["carrier"].name)
    log("carrier height - "..ch)
    for _, player in pairs(EDX["unitsManager"].getPlayers()) do
        if OFP:isAnyMounted(player) then
            local _, ph, _ = OFP:getPosition(player)
            log("["..player.."] height - "..ph)
            if ph > ch - 10 then
                log("kick out "..player)
                OFP:forceDismountVehicle(player, "override")
            end
        end
    end

    --recovery map range zone
    OFP:destroyEntitySet(data["mapRange"].setID)
    data["mapRange"] = nil
    log("map range recovered")
end

--recovery carrier
function checkCarrierEnd(unit, waypoint)
    log("checkCarrierEnd")

    OFP:destroyEntitySet(data["carrier"].setID)
    data["carrier"] = nil
    data["carrierPath"] = nil
    log("carrier recovered")
    onStageEnd()
end

--recovery
function onStageEnd()
    log("onStageEnd")

    for _, player in pairs(EDX["unitsManager"].getPlayers()) do
       OFP:removeFromGroup(player, "chunt")
    end
    log("players removed from jumper")
    EDX["dataManager"].Remove(SCRIPT_NAME)
    data = nil
    log("state data recovered")
end

function onArriveAtWaypoint(unit, waypoint)
    if data then
        checkCarrierEnd(unit, waypoint)
    end
end

function onSpawnedReady(setName, setID, entities)
    if data then 
        checkCarrier(setName, entities) 
    end
end


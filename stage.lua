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

function initializeStage()
    for _, playable in pairs(data["playables"]) do
        --detatch. confrimation needed
        local topEchelon = OFP:getParentEchelon(playable)
        
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
    data["stageSetName"] = nil
    data["mapRange"].setID = OFP:activateEntitySet(data["mapRange"].setName)
end

--start game
function startPlay()
    data["carrier"].setID = OFP:spawnEntitySetAtEntityLocation(data["carrier"].setName, data["carrierPath"].startpoint)
end

function onCarrierReady()
    local carrier = data["carrier"].name
    OFP:setInvulnerable(carrier, true)
    OFP:setVehicleMountableStatus(carrier, 1)
    OFP:rapidMove(carrier, data["carrierPath"].name, "addtofront")
    OFP:showLetterBoxOsd(true)
end

function checkCarrier(setName, setID, entities)
    if data and data["carrier"].setID == setID then
        data["carrier"].name = entities[1]
        onCarrierReady()
    end
end

function checkMapRange(setName, setID, entities)
    if data and data["mapRange"].setID == setID then
        data["mapRange"].name = entities[1]
    end
end

function checkMapRangeState(zone, unit)
    if zone == data["mapRange"].name and unit == data["carrier"].name then
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
    OFP:showLetterBoxOsd(false)
    EDX["promptManager"].prompt("GAME_START")
end

function onLeave(zone, unit)
    if data and checkMapRangeState(zone, unit) == true then
        onLeavingMap()
    end
end

function onLeavingMap()
    EDX["promptManager"].prompt("CARRIER_LEAVING")
    
    local _, ch, _ = OFP:getPosition(data["carrier"].name)
    for _, player in pairs(EDX["unitsManager"].getPlayers()) do
        if OFP:isAnyMounted(player) then
            local _, ph, _ = OFP:getPosition(player)
            if ph > ch - 10 then
                OFP:forceDismountVehicle(player, "override")
            end
        end
    end

    --recovery map range zone
    OFP:destroyEntitySet(data["mapRange"].setID)
    data["mapRange"] = nil
end

--recovery carrier
function checkCarrierEnd(unit, waypoint)
    OFP:destroyEntitySet(data["carrier"].setID)
    data["carrier"] = nil
    data["carrierPath"] = nil
    onStageEnd()
end

--recovery
function onStageEnd()
     for _, player in pairs(EDX["unitsManager"].getPlayers()) do
        OFP:removeFromGroup(player, "chunt")
     end
    EDX["dataManager"].Remove(SCRIPT_NAME)
    data = nil
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


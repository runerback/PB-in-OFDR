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
        data["playables"] = { --all playables here. format: echelon name - unit name
            ["e1"] = "ppp1",
            ["e2"] = "ppp2",
            ["e3"] = "ppp3",
            ["e4"] = "ppp4",
            ["e5"] = "ppp5"
        }
        data["stageSet"] = { --this should be recovered when carrier ready
        	setName = "stageSet",
        	setID = -1
        }
        data["carrier"] = {
            name = "",
            setName = "carrierSet",
            setID = -1,
            crew = "", --crew echelon name
            ready = false
        }
        data["carrierPath"] = { --in startUp
            name = "carrierp0p",
            startpoint = "carrierp0",
            endpoint = "carrierp1"
            }
        data["mapRange"] = {
            name = "",
            setName = "mapRangeSet",
            setID = -1
        }
	else
        
	end
end

function onMissionStart()
 	initializeStage()
end

function log(message)
    EDX["logger"].log("[stage] "..message)
end

function initializeStage()
    --log("initializeStage")

    for echelon, playable in pairs(data["playables"]) do
        --detatch. confrimation needed
        --log("detatching "..playable)
        local topEchelon = OFP:getParentEchelon(echelon)
        --log("top echelon - "..topEchelon)
		OFP:detach(echelon, topEchelon)
		--log("echelon detatched")
        OFP:detach(playable, echelon)
        --log("unit detatched")
        
        --army
        OFP:setArmy(playable, 0)
        --jumper
        OFP:addToGroup(playable, "chunt")
        --invulnerable
        OFP:setInvulnerable(playable, true)
        --register
        EDX["unitsManager"].register(playable)
    end
	--log("playables data ready")
	data["playables"] = nil
	
    data["stageSet"].setID = OFP:activateEntitySet(data["stageSet"].setName)
    --log("stage spawned")
    data["mapRange"].setID = OFP:activateEntitySet(data["mapRange"].setName)
end

--start game
function startPlay()
    --log("startPlay")

    data["carrier"].setID = OFP:spawnEntitySetAtEntityPosition(data["carrier"].setName, data["carrierPath"].startpoint)
end

function onCarrierReady()
    --log("onCarrierReady")

	data["carrier"].ready = true
    local carrier = data["carrier"].name
    --log("carrier - "..carrier)
    --log("carrier is "..OFP:getBroadUnitCategory(carrier))
    OFP:setVehicleMountableStatus(carrier, 1)
    OFP:setInvulnerable(carrier, true)
    local path = data["carrierPath"].name
    --log("path - "..path)
    --local driver = EDX:getDriver(carrier)
    --log("driver - "..driver)
    local crew = data["carrier"].crew
    --log("crew - "..crew)
    OFP:rapidMove(crew, path, "override")
    OFP:showLetterBoxOsd(true)
    
    OFP:destroyEntitySet(data["stageSet"].setID)
    data["stageSet"] = nil
end

function checkCarrier(setName, setID, entities)
    --log("checkCarrier")

    if data and data["carrier"].setID == setID then
    	local counter = 0
        for _, v in pairs(entities) do
        	if EDX:isAir(v) then
        		data["carrier"].name = v
        		counter = counter + 1
        	elseif OFP:isEchelon(v) then
        		data["carrier"].crew = v
        		counter = counter + 1
        	end
        	if counter == 2 then break end
        end
        onCarrierReady()
		return true
    end
	return false
end

function checkMapRange(setName, setID, entities)
    --log("checkMapRange")

    if data and data["mapRange"].setID == setID then
        data["mapRange"].name = entities[1]
        --log("map range checked")
		return true
    end
	return false
end

function checkMapRangeState(zone, unit)
    --log("checkMapRangeState - "..unit)
	
	--log("carrier ready - "..tostring(data["carrier"].ready))
	--log("zone - "..zone)
	--log("mapRange - "..data["mapRange"].name)
	if data["carrier"].ready == true then
	    if zone == data["mapRange"].name and unit == data["carrier"].name then
	        --log("carrier hit map edge")
	        return true
	    end
    end
    return false
end

function onEnter(zone, unit)
    if data and checkMapRangeState(zone, unit) == true then
        onEnterMap()
    end
end

function onEnterMap()
    --log("onEnterMap")

    OFP:showLetterBoxOsd(false)
    EDX["promptManager"].prompt("GAME_START")
end

function onLeave(zone, unit)
    if data and checkMapRangeState(zone, unit) == true then
        onLeavingMap()
    end
end

function onLeavingMap()
    --log("onLeavingMap")

    EDX["promptManager"].prompt("CARRIER_LEAVING")
    
    local _, ch, _ = OFP:getPosition(data["carrier"].name)
    --log("carrier height - "..ch)
    for _, player in pairs(EDX["unitsManager"].getPlayers()) do
        if OFP:isAnyMounted(player) then
            local _, ph, _ = OFP:getPosition(player)
            --log("["..player.."] height - "..ph)
            if ph > ch - 10 then
                --log("kick out "..player)
                OFP:forceDismountVehicle(player, "override")
            end
        end
    end

    --recovery map range zone
    OFP:destroyEntitySet(data["mapRange"].setID)
    data["mapRange"] = nil
    --log("map range recovered")
end

--recovery carrier
function checkCarrierEnd(unit, waypoint)
    --log("checkCarrierEnd")
    
	--log("unit - "..unit)
	--log("waypoint - "..waypoint)
	--log("endpoint - "..data["carrierPath"].endpoint)
	if waypoint == data["carrierPath"].endpoint and unit == data["carrier"].name then
		onCarrierEnd()
	end
end

function onCarrierEnd()
    --log("onCarrierEnd")
    
    OFP:destroyEntitySet(data["carrier"].setID)
    data["carrier"] = nil
    data["carrierPath"] = nil
    --log("carrier recovered")
    onStageEnd()
end

--recovery
function onStageEnd()
    --log("onStageEnd")

    for _, player in pairs(EDX["unitsManager"].getPlayers()) do
       OFP:removeFromGroup(player, "chunt")
    end
    --log("players removed from jumper")
    EDX["dataManager"].Remove(SCRIPT_NAME)
    data = nil
    --log("state data recovered")
end

function onArriveAtWaypoint(unit, waypoint)
    if data then
        checkCarrierEnd(unit, waypoint)
    end
end

function onSpawnedReady(setName, setID, entities)
    if data then 
    	if checkCarrier(setName, setID, entities) == false then
        	checkMapRange(setName, setID, entities)
        end
    end
end


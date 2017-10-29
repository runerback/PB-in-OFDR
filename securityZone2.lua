
--[[
each marker need both side of mission objective, so only can set center marker objective.
four corner of eight corner marker just show them on map, so players can check current security zone range directly.

security zone range works only when all markers are in position.

(no) first activate center marker and wait center marker in position. then spawn corner markers at their position.
activate center marker and spawn all other markers in position, then spawn all targets, move to them. 
this will make first step is same with in game steps, so extra code is saved.

when spawn markers, setName to setID then setID to entityName
--]]

SCRIPT_NAME = "securityZone"

onEDXInitialized = function()
	--get whether specified target is in sage zone
	scripts.mission.waypoints.registerFunction("isInside")
	--update zone
	scripts.mission.waypoints.registerFunction("update")
	--register callback Action. callback will be called when all markers are ready. 
	scripts.mission.waypoints.registerFunction("register") 
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
		data["markersPos"] = { 
			C = { x = 16000, z = -8050}, --change center here before publish
			--leave other values
			N = { x = 0, z = 0}, 
			NE = { x = 0, z = 0},
			E = { x = 0, z = 0},
			SE = { x = 0, z = 0},
			S = { x = 0, z = 0},
			SW = { x = 0, z = 0},
			W = { x = 0, z = 0},
			NW = { x = 0, z = 0}
		}
		
		data["markersReady"] = false
		data["markerReadyCount"] = 0
		data["markers"] = { --leave these values
			--setName. update to name in the begining
			C = "markerCSet",
			N = "markerNSet",
			NE = "markerNESet",
			E = "markerESet",
			SE = "markerSESet",
			S = "markerSSet",
			SW = "markerSWSet",
			W = "markerWSet",
			NW = "markerNWSet"
		}
		
		data["markerSetID"] = { }
		
		data["markersTargetReady"] = false
		data["markerTargetReadyCount"] = 0
		data["markerTargets"] = {
			C = { name = "c", setName = "markerTargetC", setID = -1 },
			N = { name = "n", setName = "markerTargetN", setID = -1 },
			NE = { name = "ne", setName = "markerTargetNE", setID = -1 },
			E = { name = "e", setName = "markerTargetE", setID = -1 },
			SE = { name = "se", setName = "markerTargetSE", setID = -1 },
			S = { name = "s", setName = "markerTargetS", setID = -1 },
			SW = { name = "sw", setName = "markerTargetSW", setID = -1 },
			W = { name = "w ", setName = "markerTargetW", setID = -1 },
			NW = { name = "nw", setName = "markerTargetNW", setID = -1 }
		}
		
		data["markersInPos"] = false
		data["markerInPosCount"] = 0
		
        data["range"] = 1000 --change zone range here
        data["workingData"] = { --store real range and center data. when markers are moving, use this value for IsInside function
        	range = 0,
        	center = { x = 0, z = 0 }
        }
		data["shrinkRatio"] = 0.1 --if value less than 1, means percent, else means real value
		data["canShrink"] = true
        data["markerAlt"] = 500 --height of marker(invisible helicopter)

        data["objective"] = {
            B = "securityObjB",
            R = "securityObjR"
        }
        data["callback"] = 0
		
        prepare()
	else
        
	end
end

function log(message)
    EDX["logger"].log("[securityZone] "..message)
end

function isInside(target)
	local x, _, z = OFP:getPosition(target)
	local workingData = data["workingData"]
	local range = workingData.range
	local center = workingData.center
    local inside = EDX:get2dDistance(center.x, center.z, x, z) < range
    if inside then
        log(target.." is safe")
    else
        log(target.." is not safe")
    end
    return inside
end

function register(callback)
	log("register - "..tostring(type(callback)))
	
	data["callback"] = callback
end

function prepare()
    log("prepare")

	updateCorners()
	updateWorkingData() --need to rename
	initializeMarkers()
end

function initializeMarkers()
    log("initializeMarkers")

    if data["markersReady"] == false then --spawn markers. setName to setID then setID to entityName
		--center marker
		local center = data["markers"]["C"]
		data["markers"]["C"] = OFP:activateEntitySet(center) 
		
		local cornersKey = { "N", "NE", "E", "SE", "S", "SW", "W", "NW"}
		for _, k in pairs(cornersKey) do
			local cornerMarker = data["markers"][k]
			local cornerPos = data["markersPos"][k]
			data["markers"][k] = OFP:spawnEntitySetAtLocation(cornerMarker, cornerPos.x, data["markerAlt"], cornerPos.z)
		end
	end
end

function onMarkersReady()
    --log("onMarkersReady")
    
    for _, v in pairs(data["markers"]) do
    	OFP:setInvulnerable(v, true)
    end

	data["markersReady"] = true
	data["markerReadyCount"] = nil

    generateMarkerTarget() --for initiation
end

function update()
    log("update")

	if data["canShrink"] == true then
		log("shrinking")
		updateWorkingData()
		if shrinkRange() == true then
			changeCenter()
        	updateCorners()
        
	        for _, objective in pairs(data["objective"]) do
	            OFP:setObjectiveMarkerVisibility(objective, false)
	            OFP:setObjectiveVisibility(objective, false)
	        end

			generateMarkerTarget()
		else
			data["canShrink"] = false
			log("cannot shrink any more")
			
			for _, v in pairs(data["markerSetID"]) do
				OFP:destroyEntitySet(v)
			end
			log("corner markers recovered")
		end
	end

    return data["canShrink"]
end

--if return false, stop shrink
function shrinkRange()
    --log("shrinkRange")
    
	local ratio = data["shrinkRatio"]
	local range = data["range"]
    local newRange
	if ratio >= 1 then
		newRange = range - ratio
	else
		newRange = range * (1 - ratio)
	end
    data["range"] = newRange
	log("range from ["..range.."] to ["..newRange.."]")

	return newRange > 36 --this will make corner markers to close
end

function changeCenter()
    --log("changeCenter")
    
    --math.randomseed(os.time()) set once
	local dir = math.random(0, 359)
    --log("direction - "..dir)
	
	local dist = 0
	local ratio = data["shrinkRatio"]
	local range = data["range"]
	if ratio >= 1 then
		dist = ratio
	else
		dist = range * ratio
	end
    --log("center moving distance - "..dist)
	
	local dx = dist * math.cos(math.rad(dir))
	local dz = dist * math.sin(math.rad(dir))

    --log("dx - "..dx..", dz - "..dz)
	
	local center = data["markersPos"].C

	center.x = center.x + dx
	center.z = center.z - dz
end

function updateCorners()
    --log("updateCorners")

	local center = data["markersPos"].C
	local centerX = center.x
	local centerZ = center.z
    log("center - ("..centerX..", "..centerZ..")")
	
	local range = data["range"]
	
	--[1]: cos, [2]: sin
	-- 45 - {  .7,  .7 } NE
	--135 - { -.7,  .7 } NW
	--225 - { -.7, -.7 } SW
	--315 - {  .7, -.7 } SE
	
	local n = data["markersPos"].N
	local ne = data["markersPos"].NE
	local e = data["markersPos"].E
	local se = data["markersPos"].SE
	local s = data["markersPos"].S
	local sw = data["markersPos"].SW
	local w = data["markersPos"].W
	local nw = data["markersPos"].NW
	
	n.x = centerX
	n.z = centerZ + range
	
	ne.x = centerX + range * .7
	ne.z = centerZ - range * .7
	
	e.x = centerX + range
	e.z = centerZ
	
	se.x = centerX + range * .7
	se.z = centerZ + range * .7
	
	s.x = centerX
	s.z = centerZ - range
	
	sw.x = centerX - range * .7
	sw.z = centerZ + range * .7
	
	w.x = centerX - range
	w.z = centerZ
	
	nw.x = centerX - range * .7
	nw.z = centerZ - range * .7
	
end

function updateWorkingData()
	--log("updateWorkingData")
	
	local workingData = data["workingData"]
	workingData.range = data["range"]
	
	local realCenter = workingData.center
	local center = data["markersPos"].C
	realCenter.x = center.x
	realCenter.z = center.z
end

function generateMarkerTarget()
    --log("generateMarkerTarget")
    
    data["markersTargetReady"] = false
	for k, v in pairs(data["markerTargets"]) do
		local target = v
		local pos = data["markersPos"][k]
		target.setID = OFP:spawnEntitySetAtLocation(target.setName, pos.x, data["markerAlt"], pos.z)
	end
end

function onMarkerTargetReady()
    --log("onMarkerTargetReady")
    
	data["markerTargetReadyCount"] = 0
	data["markersTargetReady"] = true
	
	data["markersInPos"] = false
	for k, v in pairs(data["markers"]) do
		local target = data["markerTargets"][k].name
		local marker = v
        --log("marker["..k.."] is moving")
		OFP:rapidMove(marker, target, "override")
	end
end

function onMarkersInPosition()
    --log("onMarkersInPosition")
    
	data["markerInPosCount"] = 0
	--log("markerInPosCount reset")
	
	updateWorkingData()
	
	for k, v in pairs(data["markerTargets"]) do
		local targetSetID = v.setID
		v.setID = -1
		OFP:destroyEntitySet(targetSetID)
	end
	--log("marker targets recovered")

    for _, objective in pairs(data["objective"]) do
        OFP:setObjectiveMarkerVisibility(objective, true)
        OFP:setObjectiveVisibility(objective, true)
    end
    
    log("ready")
    if data["callback"] then
    	data["callback"]()
    end
end

function checkMarkersState(setName, setID, entities)
    --log("checkMarkersState")
    
	if data["markersReady"] == false then
		local anyMarkerReady = false
        local markerReadyCount = data["markerReadyCount"]
		for key, _setID in pairs(data["markers"]) do
			if _setID == setID then
				data["markers"][key] = entities[1]
				markerReadyCount = markerReadyCount + 1
                data["markerReadyCount"] = markerReadyCount
				anyMarkerReady = true
                --log("marker ready count - "..markerReadyCount)
                if key ~= "C" then
                	table.insert(data["markerSetID"], setID)
                end
				break
			end
		end
		if anyMarkerReady == true and data["markerReadyCount"] == 9 then
			onMarkersReady()
		end
		return anyMarkerReady
	end
	return false
end

function checkMarkersTargetState(setName, setID, entities)
    --log("checkMarkersTargetState")
    
	if data["markersTargetReady"] == false then
		local anyMarkerTargetReady = false
        local markerTargetReadyCount = data["markerTargetReadyCount"]
		for k, v in pairs(data["markerTargets"]) do
			local target = v
			if target.setID == setID then
				target.name = entities[1]
				markerTargetReadyCount = markerTargetReadyCount + 1
                data["markerTargetReadyCount"] = markerTargetReadyCount
				anyMarkerTargetReady = true
                --log("marker target ready count - "..markerTargetReadyCount)
				break
			end
		end
		if anyMarkerTargetReady == true and data["markerTargetReadyCount"] == 9 then
			onMarkerTargetReady()
		end
		return anyMarkerTargetReady
	end
	return false
end

function checkMarkersInPosState(unit, waypoint)
    --log("checkMarkersInPosState")
    
	if data["markersInPos"] == false then
		local anyMarkerInPos = false
        local markerInPosCount = data["markerInPosCount"]
		for k, v in pairs(data["markers"]) do
			local target = data["markerTargets"][k].name
			local marker = v
			if unit == marker and waypoint == target then
				markerInPosCount = markerInPosCount + 1
                data["markerInPosCount"] = markerInPosCount
				anyMarkerInPos = true
                --log("marker in position count - "..markerInPosCount)
				break
			end
		end
		if anyMarkerInPos == true and data["markerInPosCount"] == 9 then
			onMarkersInPosition()
		end
		return anyMarkerInPos
	end
	return false
end

function onSpawnedReady(setName, setID, entities)
	if checkMarkersTargetState(setName, setID, entities) == false then
		checkMarkersState(setName, setID, entities)
	end
end

function onArriveAtWaypoint(unit, waypoint)
	checkMarkersInPosState(unit, waypoint)
end

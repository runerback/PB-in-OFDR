
SCRIPT_NAME = "securityZone"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("isInside")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
		data["markersPos"] = { 
			C = { x = 0, z = 0} --change center here
			N = { x = 0, z = 0}, --leave other values
			S = { x = 0, z = 0},
			W = { x = 0, z = 0},
			E = { x = 0, z = 0}
		}
		
		data["markersReady"] = false
		data["markerReadyCount"] = 0
		data["markers"] = { --leave these values
			C = "markerC",
			N = "markerN",
			S = "markerS",
			W = "markerW",
			E = "markerE"
		}
		
		data["markersTargetReady"] = false
		data["markerTargetReadyCount"] = 0
		data["markerTargets"] = {
			C = { name = "c", setName = "markerTargetC", setID = -1 },
			N = { name = "n", setName = "markerTargetN", setID = -1 },
			S = { name = "s", setName = "markerTargetS", setID = -1 },
			W = { name = "w ", setName = "markerTargetW", setID = -1 },
			E = { name = "e", setName = "markerTargetE", setID = -1 }
		}
		
		data["markersInPos"] = false
		data["markerInPosCount"] = 0
		data["markersState"] = {} --update in [onMarkersReady] function
		
        data["range"] = 1000 --change zone range here
		data["shrinkRatio"] = 0.1 --if value less than 1, means percent, else means real value
		data["canShrink"] = true
        data["markerAlt"] = 8000 --height of marker(invisible helicopter)
	else
        
	end
	prepare()
end

function isInside(target)
	local x, _, z = OFP:getPosition(target)
	local center = data["markersPos"].C
    return EDX:get2dDistance(center.x, center.z, x, z) < data["range"]
end

function updateCorners()
	local center = data["markersPos"].C
	local centerX = center.x
	local centerZ = center.z
	
	local range = data["range"]
	
	local n = data["markersPos"].N
	local s = data["markersPos"].S
	local w = data["markersPos"].W
	local e = data["markersPos"].E
	
	n.x = centerX
	n.z = centerZ + range
	
	s.x = centerX
	s.z = centerZ - range
	
	w.x = centerX - range
	w.z = centerZ
	
	e.x = centerX + range
	e.z = centerZ
end

--[[
if first run, spawn all five marker at their position
else, move them to target postion
--]]
function prepare()
	updateCorners()
	
	if data["markersReady"] == false then --spawn markers
		local keys = { "C", "N", "S", "W", "E" }
		for _, key in pairs(keys) do
			local pos = data["markersPos"][key]
			data["markers"][key] = OFP:spawnEntitySetAtLocation(data["markers"][key], pos.x, data["markerAlt"], pos.z)
		end
	end
end

--[[
update four-corner postion
--]]
function update()
	if data["canShrink"] == true and shrinkRange() == true then
		changeCenter()
		
		data["markersTargetReady"] = false
		for k, v in pairs(data["markerTargets"]) then
			local target = v
			local pos = data["markersPos"][k]
			target.setID = OFP:spawnEntitySetAtLocation(target.setName, pos.x, data["markerAlt"] pos.z)
		end
	else
		data["canShrink"] = false
	end
end

--if return false, stop shrink
function shrinkRange()
	local ratio = data["shrinkRatio"]
	local range = data["range"]
	if ratio > = 1 then
		data["range"] = range - ratio
	else
		data["range"] = range * (1 - ratio)
	end
	
	return data["range"] > 1
end

function changeCenter()
	local dir = math.random(0, 359)
	
	local dist = 0
	local ratio = data["shrinkRatio"]
	local range = data["range"]
	if ratio > = 1 then
		dist = ratio
	else
		dist = range * ratio
	end
	
	local dx = dist * math.cos(math.rad(dir))
	local dz = dist * math.sin(math.rad(dir))
	
	local center = data["markersPos"].C
	center.x = center.x + dx
	center.z = center.z - dz
end

function onMarkerTargetReady()
	data["markerTargetReadyCount"] = 0
	data["markersTargetReady"] = true
	
	data["markersInPos"] = false
	for k, v in pairs(data["markers"]) do
		local target = data["markerTargets"][k].name
		local marker = v
		OFP:rapidMove(marker, target, "override")
	end
end

function onMarkersReady()
	for _, v in pairs(data["markers"]) do
		data["markersState"][v] = false
	end
	
	data["markersReady"] = true
	data["markerReadyCount"] = nil
end

function onMarkersInPosition()
	data["markerInPosCount"] = 0
	
	for k, v in pairs(data["markerTargets"]) do
		local targetSetID = v.setID
		v.setID = -1
		OFP:destroyEntitySet(targetSetID)
	end
end

function checkMarkersState(setName, setID, entities)
	if data["markersReady"] == false then
		local anyMarkerReady = false
		for key, _setID in pairs(data["markers"]) do
			if _setID == setID then
				data["markers"][key] = entities[1]
				data["markerReadyCount"] = data["markerReadyCount"] + 1
				anyMarkerReady = true
				break
			end
		end
		if anyMarkerReady == true and data["markerReadyCount"] == 5 then
			onMarkersReady()
		end
	end
end

function checkMarkersTargetState(setName, setID, entities)
	if data["markersTargetReady"] == false then
		local anyMarkerTargetReady = false
		for k, v in pairs(data["markerTargets"]) do
			local target = v
			if target.setID == setID then
				target.name = entities[1]
				data["markerTargetReadyCount"] = data["markerTargetReadyCount"] + 1
				anyMarkerTargetReady = true
				break
			end
		end
		if anyMarkerTargetReady == true and data["markerTargetReadyCount"] == 5 then
			onMarkerTargetReady()
		end
	end
end

function checkMarkersInPosState(unit, waypoint)
	if data["markersInPos"] == false then
		local anyMarkerInPos = false
		for k, v in pairs(data["markers"]) do
			local target = data["markerTargets"][k].name
			local marker = v
			if unit == marker and waypoint == target then
				data["markerInPosCount"] = data["markerInPosCount"] + 1
				anyMarkerInPos = true
				break
			end
		end
		if anyMarkerInPos == true and data["markerInPosCount"] == 5 then
			onMarkersInPosition()
		end
	end
end

function onSpawnedReady(setName, setID, entities)
	checkMarkersState(setName, setID, entities)
	checkMarkersTargetState(setName, setID, entities)
end

function onArriveAtWaypoint(unit, waypoint)
	checkMarkersInPosState(unit, waypoint)
end





































--[[
help to adjust position of ammo crate markers in LiveLink mode

7(NW)	8(N)	9(NE)

4(W)	5(C)	6(E)

1(SW)	2(S)	3(SE)

0(Log)

Num5: 		confirm current marker position, and prepare to move to next marker
Num1 - 9:	spawn camera in specified direction of current marker.
			if current marker is confirmed, spawn camera around next marker.
			when camera is ready, change game camera on it.
Num0:		log current marker name and position.

playing particle effect on current marker repeatly.
--]]

SCRIPT_NAME = "materialMarkerHelper"

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["markerSetName"] = "materialset"
        data["markers"] = { }
		data["currentMarker"] = {
            name = "",
            index = 0,
			ready = false
        }
		data["camera"] = {
			setName = { "cameraset1", "cameraset2", "cameraset3", "cameraset4", "cameraset5", "cameraset6", "cameraset7", "cameraset8" }, --0 to 315
			setID = -1,
			pSetID = -1,
			name = "",
			ready = false
		}
		data["sync"] = {
			markerChanged = false,
			cameraCorner = 0
		}
		data["settings"] = { --camera settings
			height = 1, --camera distance to marker in vertical
			offset = 1	--camera distance to marker in horizontal
		}
		local processor = {
			name = "effectTaskProcessor",
			id = -1,
			interval = 6000,
			task = ""
		}
		processor.id = EDX:serialTimer(processor.name, -1, processor)
		data["processor"] = processor
		
		OFP:activateEntitySet(data["markerSetName"])
	else
	end
end

function log(message)
    EDX["logger"].log("[materialMarkerHelper] "..message)
end

function effectTaskProcessor(timerID, processor)
	OFP:doParticleEffect("effectName", processor.task)
	EDX:setTimer(timerID, processor.interval)
end

function onKeyPress( key)
	local id = tonumber(string.sub(key, -1))
	if id then
		if id == 5 then
			nextMarker()
		elseif id > 0 then
			local corner
			if id > 4 then
				corner = id - 1
			else
				corner = id
			end
			changeCamera(corner)
		else
			logCurrentMarker()
		end
	end
end

function nextMarker()
	log('next marker')
    local currentMarker = data["currentMarker"]
	currentMarker.ready = false
    local nextIndex = currentMarker.index+1
    local nextMarker = data["markers"][nextIndex]
    if nextMarker then
        currentMarker.name = nextMarker
        data["processor"].task = nextMarker
        OFP:selectCamera(nextMarker)
		currentMarker.ready = true
		data["sync"].markerChanged = true
		data["camera"].ready = true
		log('camera should change')
    else
        EDX:deleteTimer(data["processor"].id)
        log("all markers are travelled")
        EDX:simpleTimer("travelEnd", 6000)
    end
end

function logCurrentMarker()
	local currentMarker = data["currentMarker"]
	if currentMarker.ready then
		log("current marker - "..currentMarker.name)
	end
end

function travelEnd(timerID)
    EDX:deleteTimer(timerID)
    OFP:missionCompleted()
end

function changeCamera( corner) --each corner means 45 degrees, from 0 to 7
	log('changeCamera - '..corner)
	if data["currentMarker"].ready then
		log('1')
		if data["sync"].markerChanged then
			data["sync"].markerChanged = false
			data["sync"].cameraCorner = -1
			log('2')
		else
			log('3')
			if corner == data["sync"].cameraCorner then
				return
			else
				log('4')
				data["sync"].cameraCorner = corner
			end
		end
		log('5')
		local camera = data["camera"]
		if camera.ready then
			log('6')
			local nextSet = camera.setName[corner]
			if nextSet then
				log('7')
				local marker = data["currentMarker"].name
				log('8')
				
				local mx, my, mz = OFP:getPosition(marker)
				local dy = data["settings"].height
				
				--direction need check
				log('9')
				local dir = corner * 45
				local offset = data["settings"].offset
				local dx = math.cos(math.rad(dir)) * offset
				local dz = math.sin(math.rad(dir)) * offset
				
				log('10')
				camera.ready = false
				camera.setID = OFP:spawnEntitySetAtLocation(nextSet, mx + dx, my + dy, mz - dz)
				log('11')
			end
		end
	end
end

function onCameraReady()
	log('camera ready')
	local camera = data["camera"]
	if camera.pSetID >= 0 then
		OFP:destroyEntitySet(camera.pSetID)
		camera.pSetID = camera.setID
		OFP:selectCamera(camera.name)
		camera.ready = true
		log('camera should change')
	else
		camera.pSetID = camera.setID
	end
end

function onMarkersReady()
	log("markers ready")
	nextMarker()
end

function checkCamera(setID, entities)
	if setID == data["camera"].setID then
		data["camera"].name = entities[1]
		data["camera"].ready = true
		onCameraReady()
		return true
	end
	return false
end

function checkMarkers(setName, entities)
	if setName == data["markerSetName"] then
		for _, v in pairs(entities) do
			table.insert(data["markers"], v)
		end
		onMarkersReady()
		return true
	end
	return false
end

function onSpawnedReady(setName, setID, entities)
	if checkCamera(setID, entities) == false then
		checkMarkers(setName, entities)
	end
end
















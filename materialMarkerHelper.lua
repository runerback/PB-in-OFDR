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
        data["markerSetName"] = "materialSet"
        data["markers"] = { }
		data["currentMarker"] = {
            name = "",
            index = -1
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
		processor.id = EDX:serialTimer(process.name, -1, processor)
		data["processor"] = processor
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

end

function nextMarker()
    local currentMarker = data["currentMarker"]
    local nextIndex = currentMarker.index+1
    local nextMarker = data["markers"][nextIndex]
    if nextMarker then
        currentMarker.name = nextMarker
        data["processor"].task = nextMarker
        OFP:selectCamera(nextMarker)
    else
        EDX:deleteTimer(data["processor"].id)
        log("all markers are travelled")
        EDX:simpleTimer("travelEnd", 6000)
    end
end

function travelEnd(timerID)
    EDX:deleteTimer(timerID)
    OFP:missionCompleted()
end

function changeCamera( dir) --360 degree
    
end





















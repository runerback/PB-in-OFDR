SCRIPT_NAME = "materialManager"

onEDXInitialized = function()
	
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["materialMarkerSetName"] = "materialSet"
        data["materialMarkers"] = { }
        data["materialSets"] = { --all sets here
            
        }
        data["materials"] = { }
        data["vehicleSet"] = "vehicleSet"

        loadVehicles()
        initializeMaterialMarkers()
	else
	end
end

function log(message)
    EDX["logger"].log("[materialManager] "..message)
end

function loadVehicles()
    log("loadVehicles")

    OFP:activateEntitySet(data["vehicleSet"])
    data["vehicleSet"] = nil
end

function initializeMaterialMarkers()
    log("initializeMaterialMarkers")

    OFP:activateEntitySet(data["materialMarkerSetName"])
end

function onMaterialMarkersReady()
    log("onMaterialMarkersReady")

    data["materialMarkerSetName"] = nil

    buildMaterialMap()
    loadMaterials()
    --clean up
    data["materialMarkers"] = nil
    data["materialSets"] = nil
    data["materials"] = nil
    EDX["dataManager"].Remove(SCRIPT_NAME)
    data = nil
    EDX[SCRIPT_NAME] = nil
end

function buildMaterialMap()
    log("buildMaterialMap")

    --math.randomseed(os.time()) set once
    local map = {}
    local sets = {}
    
    for _, v in pairs(data["materialMarkers"]) do
        map[v] = ""
    end
    for _, v in pairs(data["materialSets"]) do
        table.insert(sets, v)
    end
    local setsCount = #sets
    for marker, _ in pairs(map) do
        map[marker] = sets[math.random(1, setsCount)]
    end
    data["materials"] = map
end

function loadMaterials()
    log("loadMaterials")

    for marker, setName in pairs(data["materials"]) do
        OFP:spawnEntitySetAtEntityLocation(setName, marker)
    end
end

function checkMaterials(setName, setID, entities)
    log("checkMaterials")

    if data and setName == data["materialMarkerSetName"] then
        for _, v in entities do
            table.insert(data["materialMarkers"], v)
        end
        onMaterialMarkersReady()
    end
end

function onSpawnedReady(setName, setID, entities)
    checkMaterials(setName, setID, entities)
end

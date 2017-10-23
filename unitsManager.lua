
SCRIPT_NAME = "promptManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("UNKNOWN")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["roster"] = {}
        data["AIs"] = {}
	else
        
	end
end

function register(unitName)
    data["roster"][unitName] = false
end

function filterAI()
    for unit, _ in pairs(data["roster"]) do
        if isAI(unit) then
            table.insert(data["AIs"], unit)
        end
    end
    for _, unit in pairs(data["AIs"]) do
        table.remove(data["roster"], unit)
        OFP:despawnEntity(unit)
    end
end


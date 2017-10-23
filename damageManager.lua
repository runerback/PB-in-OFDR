
SCRIPT_NAME = "damageManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("UNKNOWN")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        
	else
        
	end
end


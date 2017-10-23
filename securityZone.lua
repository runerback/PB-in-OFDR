
SCRIPT_NAME = "securityZone"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("UNKNOWN")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["center"] = {x=0, z=0}
        data["range"] = 0
        data["mark_alt"] = 8000
        data["outsiders"] = {}
        data["freq"] = 6000
        data["checker"] = EDX:serialTimer("check", 0)
	else
        
	end
end

function check(timer_id)
    EDX:setTimer(data["checker"], data["freq"])

end

function isInSecurityZone(target)
    
end

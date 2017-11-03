
SCRIPT_NAME = "logger"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("log")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
		data["_path"] = "./data_win/missions/kmp-union/cache/"
		
		initialize()
	else
	end
end

function initialize()
    local file = os.date("pb_%y%m%d_%H%M%S.log", os.time()) --kmp_yyMMdd_HHmmss.log
    local path = data["_path"]..file
    data["_path"] = path
    
    local f = io.open(path, "w")
    f:write("start logging...\n")
    f:close()
end

function log(message)
	OFP:displaySystemMessage(message)
	
    local file = io.open(data["_path"], "a")
    file:write(os.date("%H%M%S: ", os.time())..message..'\n')
    file:close()
end

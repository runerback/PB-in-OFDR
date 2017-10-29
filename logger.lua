
SCRIPT_NAME = "logger"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("log")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
		data["_path"] = "./data_win/missions/kmp-union/cache/"
        data["handler"] = -1
        --data["disposer"] = EDX:serialTimer("dispose", 16000)
        
		--initialize()
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
    
    open()
end

function open()
    if data["handler"] == -1 then
        data["handler"] = io.open(data["_path"], "a")
        EDX:setTimer(data["disposer"], 16000)
    end
end

function log(message)
	OFP:displaySystemMessage(message)
	
	--open()

	--[[
    local file = io.open(data["_path"], "a")
    file:write(os.date("%H%M%S: ", os.time())..message..'\n')
    file:close()
    --]]
    
   --local file = data["handler"]
    --file:write(os.date("%H%M%S: ", os.time())..message..'\n')
end

--release file handler every 16 seconds
function dispose(timerID)
    if data["handler"] ~= -1 then
        data["handler"]:close()
        data["handler"] = -1
    end
end

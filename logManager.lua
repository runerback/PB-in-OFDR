
SCRIPT_NAME = "logger"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("log")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data = {}
		data["_path"] = "./data_win/missions/kmp/cache/"
        data["handler"] = -1

        initialize()
        EDX:serialTimer("dispose", 16000)
	else
	end
end

function initialize()
    local file = os.date("kmp_%y%m%d_%H%M%S.log", os.time()) --kmp_yyMMdd_HHmmss.log
    data["_path"] = data["_path"]..file
end

function open()
    if data["handler"] == -1 then
        data["handler"] = io.open(data["_path"], "a")
    end
end

function log(message)
	OFP:displaySystemMessage(message)

    open()

    local file = data["handler"]
    file:write(os.date("%H%M%S: ", os.time())..message)
end

--release file handler every 16 seconds
function dispose(timerID)
    if data["handler"] ~= -1 then
        data["handler"]:close()
        data["handler"] = -1
    end
    EDX:setTimer(timerID, 16000)
end

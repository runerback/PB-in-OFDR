
SCRIPT_NAME = "promptManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("prompt")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
	else
	end
    loadInfos() --always reload resource after restart game
end

--data[language, global_index, resource]
function loadInfos()
    dofile("./data_win/missions/kmp/pb/resource.language")
    OFP:showPopup("current language", data[data.language])
    data["resource"] = data[data.language]
end

function prompt(key)
    return data["resource"][data["global_index"][key]]
end



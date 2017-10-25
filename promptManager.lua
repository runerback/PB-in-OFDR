
SCRIPT_NAME = "promptManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("prompt")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["resource"] = { }

        loadInfos()
	else
	end
end

--data[language, global_index, resource]
function loadInfos()
    dofile("./data_win/missions/kmp-union/pb/resource.language")
    local language = lang.language
    --OFP:showPopup("current language", language)

    local prompts = lang[language]
    for name, index in pairs(lang["global_index"]) do
        data["resource"][name] = prompts[index]
    end
    lang = nil
end

function prompt(key)
    local msg = data["resource"][key]
    if not msg then
        OFP:displaySystemMessage("cannot find propmt from key: "..key)
    else
        OFP:displaySystemMessage(msg)
    end
end



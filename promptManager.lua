
SCRIPT_NAME = "promptManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("prompt")
	
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["resource"] = { }

        loadInfos()
	else
	end
end

--data[language, global_index, resource]
function loadInfos()
    dofile("./data_win/missions/kmp/pb/resource.language")
    OFP:showPopup("current language", lang[lang.language])

    local prompts = lang[lang.language]
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




SCRIPT_NAME = "dataManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("IsFirstRun")
	scripts.mission.waypoints.registerFunction("AddOrUpdate")
	scripts.mission.waypoints.registerFunction("GetOrCreate")
	scripts.mission.waypoints.registerFunction("Remove")
	scripts.mission.waypoints.registerFunction("Save")
	
	if not data then
		--table is a reference type
		data = {}
		data["_path"] = "./data_win/missions/kmp-union/cache" --change this to your exported mission folder and stored data file name.
		data["_firstrun"] = true
	else
		--load()
	end
	scripts.mission.waypoints.simpleFunc("onDataReady", true)
end

onMissionStart = function()
	if not data then
		OFP:missionCompleted()
		return
	end
	data["_firstrun"] = false
end

IsFirstRun = function()
	return data["_firstrun"]
end

AddOrUpdate = function(name, value)
	if name == "_path" or name == "_fistrun" then
		OFP:displaySystemMessage("debug: cannot use system name as data name")
		return
	end
	data[name] = value
end

GetOrCreate = function(name)
	if name == "_path" or name == "_fistrun" then
		OFP:displaySystemMessage("debug: cannot use system name as data name")
		return nil
	end
	
	if not data[name] then
		data[name] = {}
	end
	return data[name]
end

Remove = function(name)
    if data[name] then
        data[name] = nil
    end
end

Save = function()
	EDX:saveTable(data, "data", data["_path"])
end

saveAfterReload = function()
	EDX:saveTable(data, "data", data["_path"].."_reloaded")
end

load = function()
	EDX:loadTable(data["_path"])
end

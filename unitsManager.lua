
SCRIPT_NAME = "unitsManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("register")
	scripts.mission.waypoints.registerFunction("getPlayers")
	scripts.mission.waypoints.registerFunction("removeAI")
	scripts.mission.waypoints.registerFunction("startCheck")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["roster"] = {} -- unitname <-> isOutside
		
        data["freq"] = 6000 --checking frequency
        local checkerID = EDX:serialTimer("checkOutsider", 100)
		EDX:disableTimer(checkerID)
		data["checkerID"] = checkerID
	else
        
	end
end

function log(message)
    EDX["logger"].log("[unitsManager] "..message)
end

function register(unitname)
    log("register - "..unitname)

	if not data["roster"][unitname] then
		data["roster"][unitname] = false
	end
end

function getPlayers()
    log("getPlayers")

    local players = {}
    for k, _ in data["roster"] do
        table.insert(players, k)
    end
    return players
end

function removeAI()
    log("removeAI")

	local AIs = {}
    for unit, _ in pairs(data["roster"]) do
        if OFP:isSecondaryPlayer(unit) == false and OFP:isPlayer(unit) == false then
            table.insert(AIs, unit)
        end
    end
    log("AI count - "..#AIs)
    for _, unit in pairs(AIs) do
        data["roster"][unit] = nil
        OFP:despawnEntity(unit)
    end
end

function startCheck()
    log("startCheck")

	for unitname, _ in data["roster"] do
        EDX["damageManager"].createModuleInfo(unit)
    end
	
	EDX:enableTimer(data["checkerID"])
end

function checkOutsider(timerID)
    log("checkOutsider")

	for unit, _ in pairs(data["roster"]) do
		if EDX["securityZone"].isInside(unit) == false then
			EDX["damageManager"].damage(unit)
		end
	end
    EDX:setTimer(data["checkerID"], data["freq"])
end

function tryRemove(unit)
    log("tryRemove - "..unit)

	if data["roster"][victim] then
		data["roster"][victim] = nil
		EDX["damageManager"].remove(victim)
	end
end

function onDeath(victim)
	tryRemove(victim)
end


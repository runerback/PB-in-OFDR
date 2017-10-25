
SCRIPT_NAME = "damageManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("createModuleInfo")
	scripts.mission.waypoints.registerFunction("damage")
	scripts.mission.waypoints.registerFunction("remove")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
		--[[
        data["modules"] = {
			{
				name = "chestzone",
				HP= 3
			},
			{
				name = "adbomenzone",
				HP = 3
			},
			{
				{
					name = "larmzone",
					HP = 6
				},
				{
					name = "rarmzone",
					HP = 6
				},
				{
					name = "llegzone",
					HP = 6
				},
				{
					name = "rlegzone",
					HP = 6
				}
			},
			{
				name = "headzone",
				HP = 6
			}
		}
		--]]
		data["modules"] = {
			"chestzone",
			"adbomenzone",
			{
				"larmzone",
				"rarmzone",
				"llegzone",
				"rlegzone"
			},
			"headzone"
		}
		data["damageInfo"] = { }
	else
        
	end
end

function log(message)
    EDX["logger"].log("[damageManager] "..message)
end

function createModuleInfo(unit)
    log("createModuleInfo")

	local hpMap = {
		3, 3, 6, 6, 6, 6, 6
	}
	local damageRatio = 0.1
	local damageStep = 1 --1 - chest; 2 - abdomen; 3 - random(larm, rarm, lleg, rleg); 4 - head
	local damageSpreadIndex = 0 --1-larm, 2-rarm, 3-lleg, 4-rleg; only used when damageStep is 3
	
	if not data["damageInfo"][unit] then
		data["damageInfo"][unit] = {
			["hps"] = hpMap,
			["ratio"] = damageRatio,
			["step"] = damageStep,
			["spreadIndex"] = damageSpreadIndex
		}
	else
		
	end
end

--poison can be accumulated, after large toxins the poison will spread, and damage will be more and more
function damage(unit)
    log("damage")

	if data["damageInfo"][unit] then
		local damageInfo = data["damageInfo"][unit]
		local damageStep = damageInfo.step
		local hps = damageInfo.hps
		local hp, moduleName
		if damageStep == 3 then
			local spreadStep = damageInfo.spreadIndex
			hp = hps[damageStep + spreadStep]
			moduleName = data["modules"][damageStep][spreadStep]
		else
			hp = hps[damageStep]
			moduleName = data["modules"][damageStep]
		end
		
		local damageRatio = damageInfo.ratio
		if hp > 0 then
			OFP:damage(unit, moduleName, damageRatio)
			return
		end
		
        math.randomseed(os.time())
		--move to next module
		if damageStep == 4 then --all hp run out
			OFP:damage(unit, "chestzone", 10) --kill target
			if OFP:isAlive(unit) then
				--local error = 100 / 0 --anti-cheating here
				OFP:dispalySystemMessage("someone is cheating")
			end
		else
			damageStep = damageStep + 1
			if damageStep == 3 then --spread only once
				local spreadStep = math.random(1, 4)
				damageInfo.spreadIndex = spreadStep
			end
			damageInfo.step = damageStep
			damageInfo.ratio = damageRatio * 1.1
		end
	end
end

function remove(unit)
    log("remove")

	if data["damageInfo"][unit] then
		data["damageInfo"][unit] = nil
	end
end

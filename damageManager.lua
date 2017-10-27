--[[
damage works only at damage point. such as damage chestzone of 3.0 three times to bleeding.
not simply add operation.

player is weak than AI, so test with player
chest zone: 3 - wounded 5 - bleeding 8 - incapacitated 10 - dead

so when hp run out, damage by 3 point
but if one turn not cause heavy damage, run it again
--]]

SCRIPT_NAME = "damageManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("createModuleInfo")
	scripts.mission.waypoints.registerFunction("damage")
	scripts.mission.waypoints.registerFunction("remove")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
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
        data["damage"] = 3
		data["damageInfo"] = { }
	else
        
	end
end

function log(message)
    EDX["logger"].log("[damageManager] "..message)
end

function createModuleInfo(unit)
    log("createModuleInfo - "..unit)

	local hpMap = {
		6, 9, 10, 10, 10, 10, 16
	}
	local damageRatio = 1.0
	local damageStep = 1 --1 - chest; 2 - abdomen; 3 - random(larm, rarm, lleg, rleg); 4 - head
	local damageSpreadIndex = 0 --1-larm, 2-rarm, 3-lleg, 4-rleg; only used when damageStep is 3
	
	if not data["damageInfo"][unit] then
		data["damageInfo"][unit] = {
			["hps"] = hpMap,
			["ratio"] = damageRatio,
			["step"] = damageStep,
			["spreadIndex"] = damageSpreadIndex
		}
        log("module info of ["..unit.."] created")
	else
		log("module info of ["..unit.."] already exists")
	end
end

--poison can be accumulated, after large toxins the poison will spread, and damage will be more and more
function damage(unit)
    log("damage - "..unit)

	if data["damageInfo"][unit] then
		local damageInfo = data["damageInfo"][unit]
		local damageStep = damageInfo.step
        log("damagerStep - "..damageStep)
		local hps = damageInfo.hps
		local moduleName
		local hpIndex = 0
		if damageStep == 3 then
			local spreadStep = damageInfo.spreadIndex
			hpIndex = damageStep + spreadStep
			moduleName = data["modules"][damageStep][spreadStep]
		else
			hpIndex = damageStep
			moduleName = data["modules"][damageStep]
		end
		local hp = hps[hpIndex]
        log("current HP - "..hp)
        log("current module name - "..moduleName)
		
		local damageRatio = damageInfo.ratio
        log("current damage ratio - "..damageRatio)		
		damageInfo.ratio = damageRatio * 1.01
			
		if hp > 0 then
            local dHP = data["damage"]
			OFP:damage(unit, moduleName, dHP)
			hps[hpIndex] = hp - damageRatio
            log("damaged")
			return
		end
		
        --math.randomseed(os.time()) set once
		--move to next module
		if damageStep == 4 then --all hp run out
            log("all hp run out")
			OFP:damage(unit, "chestzone", 16) --kill target
			if OFP:isAlive(unit) then
				--local error = 100 / 0 --anti-cheating here
				log("someone is cheating")
				remove(unit) --for test
            else
                log("wested")
			end
		else
			damageStep = damageStep + 1
            log("next step - "..damageStep)
			if damageStep == 3 then --spread only once
				local spreadStep = math.random(1, 4)
				damageInfo.spreadIndex = spreadStep
                log("spreading step - "..spreadStep)
			end
			damageInfo.step = damageStep
		end
	end
end

function remove(unit)
    log("remove - "..unit)

	if data["damageInfo"][unit] then
		data["damageInfo"][unit] = nil
	end
end

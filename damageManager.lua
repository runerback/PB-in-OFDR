--[[
damage works only at damage point. such as damage chestzone of 3.0 three times to bleeding.
not simply add operation.

player is weak than AI, so test with player
chest zone: 3 - wounded 5 - bleeding 8 - incapacitated 10 - dead

so when hp run out, damage by 3 point
but if one turn not cause heavy damage, run it again

every part min damage is different.

[name]		- [damage]	[bleeding]
chestzone 	- 	3			*3
adbomenzone - 	3			*4
armzone 	- 	1			*4
legzone 	- 	1			*4
headzone 	- 	4			*2
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
			[1] = {
				name = "chestzone",
				damage = 3,
				count = 3,
				hp = 6
			},
			[2] = {
				name = "abdomenzone",
				damage = 3,
				count = 4,
				hp = 9
			},
			[3] = {
				name = "larmzone",
				damage = 1,
				count = 4,
				hp = 10
			},
			[4] = {
				name = "rarmzone",
				damage = 1,
				count = 4,
				hp = 10
			},
			[5] = {
				name = "llegzone",
				damage = 1,
				count = 4,
				hp = 10
			},
			[6] = {
				name = "rlegzone",
				damage = 1,
				count = 4,
				hp = 10
			},
			[7] = {
				name = "headzone",
				damage = 4,
				count = 2,
				hp = 16
			}
		}
		data["damageInfo"] = { }
	else

	end
end

function log(message)
    EDX["logger"].log("[damageManager] "..message)
end

function createModuleInfo(unit)
    --log("createModuleInfo - "..unit)

	local hpMap = {}
	for _, v in pairs(data["modules"]) do
		local info = {
			hp = v.hp,
			count = v.count
		}
		table.insert(hpMap, info)
	end

	local damageRatio = 1.0
	local damageStep = 1 --1 - chest; 2 - abdomen; 3 - random(larm, rarm, lleg, rleg); 7 - head
	local damageSpreadIndex = 0 --1-larm, 2-rarm, 3-lleg, 4-rleg; only used when damageStep is 3

	if not data["damageInfo"][unit] then
		data["damageInfo"][unit] = {
			["hps"] = hpMap,
			["ratio"] = damageRatio,
			["step"] = damageStep,
			["spreadIndex"] = damageSpreadIndex
		}
        --log("module info of ["..unit.."] created")
	else
		--log("module info of ["..unit.."] already exists")
	end
end

--poison can be accumulated, after large toxins the poison will spread, and damage will be more and more
function damage(unit)
    --log("damage - "..unit)

	if data["damageInfo"][unit] then
		local damageInfo = data["damageInfo"][unit]

		local damageStep = damageInfo.step
        --log("damagerStep - "..damageStep)

		local hps = damageInfo.hps
		local moduleInfo

		local moduleIndex = 0
		if damageStep == 3 then
			moduleIndex = damageStep + damageInfo.spreadIndex
		else
			moduleIndex = damageStep
		end

		local hpInfo = hps[moduleIndex]
		local hp = hpInfo.hp
        --log("current HP - "..hp)

		local damageRatio = damageInfo.ratio
        --log("current damage ratio - "..damageRatio)
		damageInfo.ratio = damageRatio * 1.01

		if hp > 0 then
			hpInfo.hp = hp - damageRatio
			return
		end
		
		--log("hp run out")

		moduleInfo = data["modules"][moduleIndex]
		local moduleName = moduleInfo.name
        --log("current module name - "..moduleName)

		local damage = moduleInfo.damage
		OFP:damage(unit, moduleName, damage)
		--log("damaged - "..damage)

		local damageCount = hpInfo.count - 1
		--log("damage count remained - "..damageCount)
		hpInfo.count = damageCount

		if damageCount == 0 then
			--log("damage count run out")
		else
			hpInfo.hp = moduleInfo.hp
			--log("hp recovered")
			return
		end

		--move to next module
		if damageStep == 7 then --all hp run out
            --log("all hp run out")
			OFP:damage(unit, "chestzone", 10) --kill target
			if OFP:isAlive(unit) then
				--local error = 100 / 0 --anti-cheating here
				--log("someone is cheating")
				--remove(unit) --for test
            else
                --log("wested")
			end
		else
			if damageStep == 3 then
				damageStep = 7
				damageInfo.spreadIndex = 0
			else
				damageStep = damageStep + 1
			end
			damageInfo.step = damageStep
            --log("next step - "..damageStep)
			if damageStep == 3 then --spread only once
				local spreadStep = math.random(1, 4) - 1 --correct index offset
				damageInfo.spreadIndex = spreadStep
                --log("spreading step - "..spreadStep)
			end
		end
	end
end

function remove(unit)
    --log("remove - "..unit)

	if data["damageInfo"][unit] then
		data["damageInfo"][unit] = nil
	end
end

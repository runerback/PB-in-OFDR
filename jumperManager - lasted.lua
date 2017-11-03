
SCRIPT_NAME = "jumperManager"

onEDXInitialized = function()
    scripts.mission.waypoints.registerFunction("register")
    scripts.mission.waypoints.registerFunction("registerCompletion")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["completion"] = {} --store completion callbacks
        data["jumperTable"] = {}
        data["spawnedSet"] = {}
        data["deploy_chute_table"] = {"dep1","dep2","dep3","dep4","dep5","dep6","dep7","dep8"}
        data["timers"] = {
            chutedeploy = EDX:serialTimer("updateChuteState", -1)
        }
        --data["hid"] = OFP:activateEntitySet("hid")
    else
    end
end

function log(message)
    EDX["logger"].log("[jumperManager] "..message)
end

function registerCompletion(callback)
    table.insert(data["completion"], callback)
end

function register( jumperName) --this should be a single unit
    --log("register - "..jumperName)
	
	local jumper = string.lower(jumperName)
	if not data["jumperTable"][jumper] then
	    local jumperInfo = {
			chute_set = "",
	        bumper_gc_table = {},
	        bumper_delay = 0,
			bumper_setName = {},
			coordinate = { x = -1, y = -1, z = -1 },
			deploying = false,
			deployed = false,
	        chute_gc_table = {},
	        deploy_chute_index = 1,
	        extra = 0,
			height_from_surface = -1,
	        jump_height = -1,
	        jumped = false,
	        name = jumper,
	        --net = 0,
	        teth1 = false,
			tethes = {}
	    }
		data["jumperTable"][jumper] = jumperInfo
	
	    --log("jumper registered - "..jumper)
    end
end

function checkJumpState(vehicle, unit)
	--log("checkJumpState - "..vehicle..", "..unit)
    if data and EDX:isAir(vehicle) then
        local jumperInfo = data["jumperTable"][unit]
        if jumperInfo then
        	--log("jumper - "..jumperInfo.name)
            local jump_height = OFP:getHeight(vehicle)
            --log("jump height - "..jump_height)
            if jump_height >= 50 then
                jumperInfo.jump_height = jump_height
                jumperInfo.jumped = true
                onJumped(unit)
                return true
			else
				--log("jumper jumped too low - "..unit)
            end
        end
    end
    return false
end

function onJumped( jumper)
    --log("onJumped - "..jumper)

    OFP:setInvulnerable(jumper, true)
    EDX:setTimer(data["timers"].chutedeploy, 250)
end

function updateChuteState( timerID)
	--log("\n")
	--log("updateChuteState - "..tostring(timerID))
	local allJumped = false
	for jumper, jumperInfo in pairs(data["jumperTable"]) do
		if jumperInfo.jumped then
			updateChutedeploy( jumper, jumperInfo)
			allJumped = true
		end
	end
	if allJumped == false then
		EDX:disableTimer(timerID)
		log("timer disabled")
	else
		EDX:setTimer(timerID, 250)
	end
	--log("\n")
end

function updateChutedeploy( jumper, jumperInfo)
	--log("updateChutedeploy - "..jumper)
	
	local x, y, z = OFP:getPosition(jumper)
	--log("x - "..x..", y - "..y..", z - "..z)
	local terrain_height = OFP:getTerrainHeight(x, z)
	if terrain_height < 0 then
		terrain_height = 0
	end
	--log("terrain_height - "..terrain_height)
	local height_from_surface = math.floor(y - terrain_height)
	jumperInfo.height_from_surface = height_from_surface
	
	local coordinate = jumperInfo.coordinate
	coordinate.x = x
	coordinate.y = y
	coordinate.z = z
	--log("coordinate - done")
	
	local distance_fallen = jumperInfo.jump_height - height_from_surface
	--log("distance_fallen - "..distance_fallen)
	if distance_fallen >= 20 and height_from_surface <= 100 and 
		(jumperInfo.deployed == false and jumperInfo.deploying == false) then
		--log("height_from_surface - "..height_from_surface)
		
		jumperInfo.deploying = true
		jumperInfo.extra = 0
		jumperInfo.chute_set = data["deploy_chute_table"][jumperInfo.deploy_chute_index]
		--log("begin to deploy chute")
		deploychute(jumperInfo)
	end
end

function deploychute(jumperInfo)
	--log("deploychute - "..jumperInfo.name)
	if jumperInfo then	
		local chute_gc_table = jumperInfo.chute_gc_table
		if jumperInfo.deploy_chute_index > 2 then
			OFP:destroyEntitySet(chute_gc_table[1])
			table.remove(chute_gc_table, 1)
		end
		
		local bumper_gc_table = jumperInfo.bumper_gc_table
		local bumper_delay = jumperInfo.bumper_delay
		--log("bumper_delay - "..bumper_delay)
		if bumper_delay > 1 then
			OFP:destroyEntitySet(bumper_gc_table[1])
			table.remove(bumper_gc_table,1)
			jumperInfo.bumper_delay = bumper_delay - 1
		end
		
		if disengageChute(jumperInfo) == false then
			local coordinate = jumperInfo.coordinate
			local chute_set = jumperInfo.chute_set
			--log("chute_set - "..chute_set)
			local setID1 = OFP:spawnEntitySetAtLocation(jumperInfo.chute_set,coordinate.x, coordinate.y + jumperInfo.extra, coordinate.z)
			--log("setID1 - "..setID1)
			data["spawnedSet"][setID1] = jumperInfo
			if jumperInfo.teth1 then
				local setName = "teth1"
				jumperInfo.bumper_setName = setName
				local setID2 = OFP:spawnEntitySetAtLocation(setName, coordinate.x, coordinate.y-3, coordinate.z)
				--log("setID2 - "..setID2)
				data["spawnedSet"][setID2] = jumperInfo
			end
			--[[ max bumper here
			if jumperInfo.deploying then
				local deploy_index = jumperInfo.deploy_chute_index
				log("deploy_index - "..deploy_index)
				
				if deploy_index <= 2 then
					local setID = OFP:spawnEntitySetAtLocation("teth1",coordinate.x, coordinate.y-5, coordinate.z)
					--log("setID - "..setID)
					table.insert(jumperInfo.tethes, setID)
					spawnedSet[setID] = jumperInfo
				elseif deploy_index >= 7 then
					OFP:destroyEntitySet(jumperInfo.tethes[1])
					table.remove(jumperInfo.tethes, 1)
				end
				
				if deploy_index == 8 then
					jumperInfo.tethes = nil
				end
			end
			--]]
		else --finished
			local jumper = jumperInfo.name
			--log("jump finished - "..jumper)
			for _, finalChuteSetID in pairs(bumper_gc_table) do
				OFP:destroyEntitySet(finalChuteSetID)
			end
			jumperInfo.bumper_gc_table = nil
			
			for _, deployChuteSetID in pairs(chute_gc_table) do
				OFP:destroyEntitySet(deployChuteSetID)
			end
			jumperInfo.chute_gc_table = nil
			
			--[[
			for _, tethSetID in pairs(jumperInfo.tethes) do
				OFP:destroyEntitySet(tethSetID)
			end
			jumperInfo.tethes = nil
			--]]
			
			jumperInfo.coordinate = nil
			
			data["jumperTable"][jumper] = nil
			
			OFP:setInvulnerable(jumper, false)

            checkCompletionState()
		end
	end
end

--whether jump finished
function disengageChute(jumperInfo)
	--log("disengageChute - "..jumperInfo.name)
	if OFP:isAlive(jumperInfo.name) and jumperInfo.height_from_surface > 2 then
		--log("passed")
		return false
	end
	--log("not pass")
	return true
end

function checkCompletionState()
	if next(data["jumperTable"]) == nil then --all registered jumpers finished
		--log("all jumpers finished")
		
		EDX:deleteTimer(data["timers"].chutedeploy)
		data["timers"] = nil
		
		--OFP:destroyEntitySet(data["hid"])
		--data["hid"] = nil
		
		data["jumperTable"] = nil
		data["spawnedSet"] = nil
		data["deploy_chute_table"] = nil
		
		onCompleted(data["completion"])
		data["completion"] = nil
		
		data = nil
    end
end

function checkSpawnedSet(setName, setID)
	if data then
		local jumperInfo = data["spawnedSet"][setID]
		if jumperInfo then
			log("checkSpawnedSet - "..setName)
			--log("chute_set - "..jumperInfo.chute_set)
			if setName == jumperInfo.chute_set then
				if jumperInfo.deploying then
					local deploy_chute_index = jumperInfo.deploy_chute_index + 1
					--log("deploy_chute_index - "..deploy_chute_index)
					if deploy_chute_index <= 8 then --deploy_chute_table_count
						jumperInfo.extra = jumperInfo.extra + 0.8
						jumperInfo.chute_set = (data["deploy_chute_table"][deploy_chute_index])
						jumperInfo.deploy_chute_index = deploy_chute_index
					else
						--log("deploying finished")
						jumperInfo.deploying = false
						jumperInfo.deployed = true
						jumperInfo.chute_set = "cht1"
						jumperInfo.teth1 = true
					end
				end
				--[[
				if jumperInfo.deployed then
					jumperInfo.net = jumperInfo.net + 1
				end
				--]]
				table.insert(jumperInfo.chute_gc_table, setID)
				deploychute(jumperInfo)
			end
			
			if setName == jumperInfo.bumper_setName then
				jumperInfo.bumper_delay = jumperInfo.bumper_delay + 1
				table.insert(jumperInfo.bumper_gc_table, setID)
			end
			data["spawnedSet"][setID] = nil
			return true
		end
	end
	return false
end

function onCompleted(callbacks)
	log("onCompleted")
	
	for _, callback in pairs(callbacks) do
		callback()
	end
	EDX:disableRootEvents(SCRIPT_NAME)
end

function onDismount( vehicle, unit)
	checkJumpState(vehicle, unit)
end

function onSpawnedReady( setName, setID)
	checkSpawnedSet( setName, setID)
end

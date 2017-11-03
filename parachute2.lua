
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
            chutedeploy = EDX:serialTimer("chutedeploy", -1)
        }
        data["hid"] = OFP:activateEntitySet("hid")
    else
    end
end

function log(message)
    EDX["logger"].log("[jumperManager] "..message)
end

function registerCompletion(callback)
    table.insert(data["completion"], callback)
end

function register( jumperName)
    log("register - "..jumperName)

    local jumperInfo = {
		chute_set = "",
        container_chute_destroy_table = {},
		container_chute_set = {},
        container_delay = 0,
		coordinate = { x = -1, y = -1, z = -1 },
		deploying = false,
        deploy_chute_destroy_table = {},
        deploy_chute_index = 1,
        extra = 0,
		height_from_surface = -1,
        jump_height = -1,
        jumped = false,
        name = jumperName,
        net = 0,
        teth1 = false,
		tethes = {}
    }
	data["jumperTable"][jumperName] = jumperInfo

    log("jumper registered - "..jumperName)
end

function checkJumpState(vehicle, unit)
    if data and EDX:isAir(vehicle) then
        local jumperInfo = data["jumperTable"][unit]
        if jumperInfo then
            local jump_height = OFP:getHeight(vehicle)
            if jump_height >= 50 then
                jumperInfo.jump_height = jump_height
                jumperInfo.jumped = true
                onJumped(unit)
                return true
			else
				log("jumper jumped too low - "..unit)
            end
        end
    end
    return false
end

function onJumped( jumper)
    log("onJumped - "..jumper)

    OFP:setInvulnerable(jumper, true)
    EDX:setTimer(data["timers"].chutedeploy, 250)
end

function chutedeploy(timerID)
	local allJumped = false
	for jumper, jumperInfo in pairs(data["jumperTable"]) do
		if jumperInfo.jumped then
			updateChutedeploy( jumper, jumperInfo)
			allJumped = true
		end
	end
	if allJumped == false then
		EDX:disableTimer(timerID)
	else
		EDX:setTimer(timerID, 250)
	end
end

function updateChutedeploy( jumper, jumperInfo)
	local x, y, z = OFP:getPosition(jumper)
	local terrain_height = OFP:getTerrainHeight(x, z)
	if terrain_height < 0 then
		terrain_height = 0
	end
	local height_from_surface = math.floor(y - terrain_height)
	jumperInfo.height_from_surface = height_from_surface
	
	local coordinate = jumperInfo.coordinate
	coordinate.x = x
	coordinate.y = y
	coordinate.z = z
	
	local distance_fallen = jumperInfo.jump_height - height_from_surface
	if distance_fallen >= 20 and height_from_surface <= 60 and jumperInfo.deploying == false then
		jumperInfo.container_delay = 0
		jumperInfo.deploying = true
		jumperInfo.extra = 0
		jumperInfo.chute_set = data["deploy_chute_table"][jumperInfo.deploy_chute_index]
		
		deploychute(jumperInfo)
	end
end

function deploychute(jumperInfo)
	if jumperInfo then	
		local deploy_chute_destroy_table = jumperInfo.deploy_chute_destroy_table
		if jumperInfo.deploy_chute_index > 2 then
			OFP:destroyEntitySet(deploy_chute_destroy_table[1])
			table.remove(deploy_chute_destroy_table, 1)
		end
		
		local container_chute_destroy_table = jumperInfo.container_chute_destroy_table
		if jumperInfo.container_delay > 1 then
			OFP:destroyEntitySet(container_chute_destroy_table[1])
			table.remove(container_chute_destroy_table,1)
		end
		
		
		if disengageChute(jumperInfo) == false then
			local coordinate = jumperInfo.coordinate
			
			local setID1 = OFP:spawnEntitySetAtLocation(jumperInfo.chute_set,coordinate.x, coordinate.y + jumperInfo.extra, coordinate.z)
			data["spawnedSet"][setID] = jumperInfo
			if jumperInfo.teth1 then
				local setName = "teth1"
				jumperInfo.container_chute_set = setName
				local setID2 = OFP:spawnEntitySetAtLocation(setName, coordinate.x, coordinate.y-3, coordinate.z)
				data["spawnedSet"][setID2] = jumperInfo
			end
			
			local netIndex = jumperInfo.net
			if netIndex > 0 and netIndex < 9 then
				if netIndex <= 2 then
					local setID = OFP:spawnEntitySetAtLocation("teth1",coordinate.x, coordinate.y-5, coordinate.z)
					table.insert(jumperInfo.tethes, setID)
					spawnedSet[setID] = jumperInfo
				elseif netIndex >= 7 then
					OFP:destroyEntitySet(jumperInfo.tethes[1])
					table.remove(jumperInfo.tethes, 1)
				end
			end
		else --finished
			local jumper = jumperInfo.name
			log("jump finished - "..jumper)
			for _, finalChuteSetID in pairs(container_chute_destroy_table) do
				OFP:destroyEntitySet(finalChuteSetID)
			end
			jumperInfo.container_chute_destroy_table = nil
			
			for _, deployChuteSetID in pairs(deploy_chute_destroy_table) do
				OFP:destroyEntitySet(deployChuteSetID)
			end
			jumperInfo.deploy_chute_destroy_table = nil
			
			for _, tethSetID in pairs(jumperInfo.tethes) do
				OFP:destroyEntitySet(tethSetID)
			end
			jumperInfo.tethes = nil
			
			jumperInfo.coordinate = nil
			
			data["jumperTable"][jumper] = nil
			
			OFP:setInvulnerable(jumper, false)

            checkCompletionState()
		end
	end
end

--whether jump finished
function disengageChute(jumperInfo)
	if OFP:isAlive(jumperInfo.name) and jumperInfo.height_from_surface > 2 then
		return false
	end
	return true
end

function checkCompletionState()
	if next(data["jumperTable"]) == nil then --all registered jumpers finished
		log("all jumpers finished")
		
		EDX:deleteTimer(data["timers"].chutedeploy)
		data["timers"] = nil
		
		OFP:destroyEntitySet(data["hid"])
		data["hid"] = nil
		
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
			if setName == jumperInfo.chute_set then
				table.insert(jumperInfo.deploy_chute_destroy_table, setID)
				
				local deploy_chute_index = jumperInfo.deploy_chute_index
				if deploy_chute_index <= 8 then --deploy_chute_table_count
					jumperInfo.extra = jumperInfo.extra + 0.8
					deploy_chute_index = deploy_chute_index + 1
					jumperInfo.chute_set = (data["deploy_chute_table"][deploy_chute_index])
					jumperInfo.deploy_chute_index = deploy_chute_index
				else
					jumperInfo.chute_set = "cht1"
					jumperInfo.net = jumperInfo.net + 1
				end
				
				deploychute(jumperInfo)
			elseif setName == jumperInfo.container_chute_set then
				jumperInfo.container_delay = jumperInfo.container_delay + 1
				table.insert(jumperInfo.container_chute_destroy_table, setID)
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
end

function onDismount( vehicle, unit)
	checkJumpState(vehicle, unit)
end

function onSpawnedReady( setName, setID)
	checkSpawnedSet( setName, setID)
end

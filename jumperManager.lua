
SCRIPT_NAME = "jumperManager"

onEDXInitialized = function()
    scripts.mission.waypoints.registerFunction("register")
    scripts.mission.waypoints.registerFunction("registerCompletion")
    scripts.mission.waypoints.registerFunction("getRegisteredJumpers")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["completion"] = {} --store completion callbacks
        data["jumpers"] = {}
        data["setIndexes"] = {}
        data["deploy_chute_sets"] = {"dep1","dep2","dep3","dep4","dep5","dep6","dep7","dep8"}
        data["processor"] = {
        	jumper = {
        		name = "jumperTaskProcessor",
        		id = -1,
        		running = false,
        		interval = 250,
        		tasks = {}
        	}
        }
        data["disposing"] = false --if true, disable all Check functions
        
        data["bumperhidset"] = OFP:activateEntitySet("bumperhidset")
        initializeProcessors()
    else
    end
end

function log(message)
    EDX["logger"].log("[jumperManager] "..message)
end

--processor start
function initializeProcessors()
	for _, processor in pairs(data["processor"]) do
		processor.id = EDX:serialTimer(processor.name, -1, processor)
	end
end

function releaseProcessor(name)
    --log("releaseProcessor - "..name)

    if data and data["processor"] then
        local processor = data["processor"][name]
        if processor then
        	local timerID = processor.id
        	if processor.running then
        		EDX:disableTimer(timerID)
        	end
        	processor.tasks = nil
            EDX:deleteTimer(timerID)
            data["processor"][name] = nil
            --log("processor released - "..name)
        end
    end
end

function processorScheduler( name, key, task)
    --log("processorScheduler - "..name)

    if data and data["processor"] then
        local processor = data["processor"][name]
        processor.tasks[key] = task
        if processor and processor.running == false then
            processor.running = true
            --log("processor awaken - "..name..", "..processor.id)
            EDX:setTimer(processor.id, processor.interval)
        end
    end
end
--processor end

function registerCompletion(callback)
    table.insert(data["completion"], callback)
end

function register( jumperName) --this should be a single unit, a echelon or a group
    --log("register - "..jumperName)
	
	local jumper = string.lower(jumperName)
	if EDX:isSoldier(jumper) == false then
		local members = EDX:grpToTable(jumper)
		local _next = next(members)
		if _next == nil then
			log("cannot register jumper ["..tostring(jumper).."], this should be soldier, echelon or group")
		else
			for _, v in pairs(members) do
				--log("member - "..tostring(v))
				if v then
					register( v)
				end
			end
		end
		return
	end
	
	if not data["jumpers"][jumper] then
	    local jumperInfo = {
	        name = jumper,
	        --position data
			coordinate = { x = -1, y = -1, z = -1 },
			extra = 0,
			height_from_surface = -1,
	        jump_height = -1,
	        block_counter = 0, --counter to check whether jumper blocked such as jumped on building.
			--chute
			chute_set = "",
	        chute_gc_table = {},
	        chute_deploy_index = 1,
	        --bumper
	        bumper_gc_table = {},
	        max_bumper_setID = -1,
	        --state
	        jumped = false,
			deploying = false,
			deployed = false,
	        completed = false
	    }
		data["jumpers"][jumper] = jumperInfo
	
	    --log("jumper registered - "..jumper)
    end
end

function getRegisteredJumpers()
	local jumpers = {}
	for jumper, _ in pairs(data["jumpers"]) do
		table.insert(jumpers, jumper)
	end
	--log("retuning "..#jumpers.." jumper")
	return jumpers
end

function checkJumpState(vehicle, unit)
	--log("checkJumpState - "..vehicle..", "..unit)
    if data and EDX:isAir(vehicle) then
        local jumperInfo = data["jumpers"][unit]
        if jumperInfo then
        	--log("jumper - "..jumperInfo.name)
            local jump_height = OFP:getHeight(vehicle)
            --log("jump height - "..jump_height)
            if jump_height >= 50 then
                jumperInfo.jump_height = jump_height
                jumperInfo.jumped = true
                onJumped( jumperInfo)
                --return true
			else
				--log("jumper jumped too low - "..unit)
            end
        end
    end
    --return false
end

function onJumped( jumperInfo)
	local jumper = jumperInfo.name
    --log("onJumped - "..jumper)

    OFP:setInvulnerable(jumper, true)
	if not OFP:isPlayer(jumper) and not OFP:isSecondaryPlayer(jumper) then
		OFP:stop(jumper,"OVERRIDE")
	end
	
    processorScheduler( "jumper", jumper, jumperInfo)
end

function jumperTaskProcessor( processor, timerID)
	--log("jumperTaskProcessor")
	local tasks = processor.tasks
	local _next = next(tasks)
	if _next then
		for _, v in pairs(tasks) do
			updateJumperState( v)
		end
		EDX:setTimer(timerID, processor.interval)
	else
		log("empty jumper task queue")
		processor.running = false
	end
end

function updateJumperState( jumperInfo)
	if jumperInfo.jumped then
		updateChutedeploy( jumperInfo)
	end
end

--deploying chute, update position data
function updateChutedeploy( jumperInfo) 
	local jumper = jumperInfo.name
	--log("updateChutedeploy - "..jumper)
	local deployed = jumperInfo.deployed
	
	local x, y, z = OFP:getPosition(jumper)
	--log("x - "..x..", y - "..y..", z - "..z)
	local terrain_height = OFP:getTerrainHeight(x, z)
	if terrain_height < 0 then
		terrain_height = 0
	end
	--log("terrain_height - "..terrain_height)
	local height_from_surface = math.floor(y - terrain_height)
	if jumperInfo.height_from_surface == height_from_surface then --check whether jumper are blocked
		local block_counter = jumperInfo.block_counter
		block_counter = block_counter + 1
		--log("block counter - "..block_counter)
		if block_counter == 6 then
			log("jumper blocked - "..jumper)
			jumperInfo.completed = true
		else
			jumperInfo.block_counter = block_counter
		end
		return
	else
		jumperInfo.height_from_surface = height_from_surface
		--log("height from surface - "..height_from_surface)
		jumperInfo.block_counter = 0
	end
	
	local coordinate = jumperInfo.coordinate
	coordinate.x = x
	coordinate.y = y
	coordinate.z = z
	--log("coordinate updated - "..y)
	
	if deployed == true or jumperInfo.deploying == true then return end
	
	local distance_fallen = jumperInfo.jump_height - height_from_surface
	--log("distance_fallen - "..distance_fallen)
	if distance_fallen >= 20 and height_from_surface <= 100 then
		--log("height_from_surface - "..height_from_surface)
		jumperInfo.deploying = true
		jumperInfo.extra = 0
		jumperInfo.chute_set = data["deploy_chute_sets"][jumperInfo.chute_deploy_index]
		jumperInfo.jump_height = nil
		
		--log("begin to deploy chute")
		deploychute(jumperInfo)
	end
end

function deploychute(jumperInfo)
	--log("deploychute - "..jumperInfo.name)
	
	if jumperInfo.completed == false then
		if jumperInfo.height_from_surface <= 2 then
			jumperInfo.completed = true
		end
		
		local chute_gc_table = jumperInfo.chute_gc_table
		if chute_gc_table[2] then
			OFP:destroyEntitySet(chute_gc_table[1])
			table.remove(chute_gc_table, 1)
		end
		
		local bumper_gc_table = jumperInfo.bumper_gc_table
		if bumper_gc_table[2] then
			OFP:destroyEntitySet(bumper_gc_table[1])
			table.remove(bumper_gc_table, 1)
		end
		
		local coordinate = jumperInfo.coordinate
		if jumperInfo.deploying then
			local deploy_index = jumperInfo.chute_deploy_index
			--log("deploy_index - "..deploy_index)
			
			--deploying chute update
			if deploy_index <= 8 then
				jumperInfo.extra = jumperInfo.extra + 0.9
				jumperInfo.chute_set = data["deploy_chute_sets"][deploy_index]
				jumperInfo.chute_deploy_index = deploy_index + 1
			else
				--log("deploying finished")
				jumperInfo.extra = 7
				jumperInfo.deploying = false
				jumperInfo.deployed = true
				jumperInfo.chute_set = "chuteset"
			end
			
			--max bumper
			if deploy_index == 1 then
				--log("spawning max bumper")
				jumperInfo.max_bumper_setID = OFP:spawnEntitySetAtLocation("bumperset",coordinate.x, coordinate.y - 30, coordinate.z)
			elseif deploy_index == 8 then
				--log("recovering max bumper")
				OFP:destroyEntitySet(jumperInfo.max_bumper_setID)
				jumperInfo.max_bumper_setID = nil
			end
		else
			----bumpers
			local alt = coordinate.y - 4.6
			--log("alt - "..alt)
			local bumperSetID = OFP:spawnEntitySetAtLocation("bumperset", coordinate.x,  alt, coordinate.z)
			table.insert(bumper_gc_table, bumperSetID)
			--log("bumper setID - "..bumperSetID)
		end
		
		--chute
		local chuteSetID = OFP:spawnEntitySetAtLocation(jumperInfo.chute_set,coordinate.x, coordinate.y + jumperInfo.extra, coordinate.z)
		table.insert(chute_gc_table, chuteSetID)
		
		data["setIndexes"][chuteSetID] = jumperInfo
		--log("chute setID - "..chuteSetID)
	else
		recoverJumperInfo(jumperInfo)
		checkCompletionState()
	end
end

function recoverJumperInfo( jumperInfo)
		local jumper = jumperInfo.name
		--log("jump finished - "..jumper)
		
		OFP:setInvulnerable(jumper, false)
		
		--remove from processor
		data["processor"]["jumper"]["tasks"][jumper] = nil
		
		for _, bumperSetID in pairs(jumperInfo.bumper_gc_table) do
			OFP:destroyEntitySet(bumperSetID)
		end
		jumperInfo.bumper_gc_table = nil
		
		for _, chuteSetID in pairs(jumperInfo.chute_gc_table) do
			OFP:destroyEntitySet(chuteSetID)
		end
		jumperInfo.chute_gc_table = nil
		
		jumperInfo.coordinate = nil
		data["jumpers"][jumper] = nil
		--log("jumperInfo recovered - "..jumper)
end

function checkCompletionState()
	if next(data["jumpers"]) == nil then --all registered jumpers finished
		--log("all jumpers finished")
		
		data["disposing"] = true
		
		releaseProcessor("jumper")
		data["processor"] = nil
		
		OFP:destroyEntitySet(data["bumperhidset"])
		data["bumperhidset"] = nil
		
		data["jumpers"] = nil
		data["setIndexes"] = nil
		data["deploy_chute_sets"] = nil
		
		onCompleted(data["completion"])
		data["completion"] = nil
		
		data = nil
    end
end

function checkSpawnedSet(setName, setID)
	if data and data["disposing"] == false then
		local jumperInfo = data["setIndexes"][setID]
		if jumperInfo then
			if jumperInfo.completed then
				--log("checkSpawnedSet - "..jumperInfo.name.." completed")
			end
			--log("setID checked - "..setID)
			data["setIndexes"][setID] = nil
			--log("deploychute after spawned ready - "..setID)
			deploychute(jumperInfo)
		end
	end
end

function onCompleted(callbacks)
	--log("onCompleted")
	
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

function onDeath(victim)
	log("death - "..victim)
end


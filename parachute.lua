
SCRIPT_NAME =	"parachute"
logtofile = false

onEDXInitialized = function()
	jumperTable = {}
	spawnedSet = {}
	deploy_chute_table = {"dep1","dep2","dep3","dep4","dep5","dep6","dep7","dep8"}
	--OFP:addTimer("timeMech", 500) --callback no found
	--OFP:addTimer("hangCycle", 1000) --use EDX timer insteed
	hangChute = {} --move to here
	EDX:simpleTimer("hangCycle", 1000)
end

function onInitialized()
	EDX["dataManager"].Initialize()
end

function hangCycle(timerID)
	--OFP:displaySystemMessage("Hang cycle started")
	--if not hangChute then
		--hangChute = {}
	--end
	for i = 1, 50 do
		hangChute[OFP:spawnEntitySetAtLocation("cht1", 0, 0, 0)] = true
	end
	--OFP:addTimer("hangRemoval", 1000)
	--OFP:removeTimer("hangCycle")
	EDX:deleteTimer(timerID)
	EDX:serialTimer("hangRemoval", 1000)
end

function hangRemoval(timerID)
	local tableCount = 0
	for i,v in pairs(hangChute) do
		tableCount = tableCount + 1
		if v == "spawned" then
			OFP:destroyEntitySet(i)
			hangChute[i] = nil
			hasChutes = true
		end
	end
	if not hasChutes then
		OFP:removeTimer("hangRemoval")
		hangChute = nil
		numChutes = nil
		--OFP:displaySystemMessage("Hung chute process completed")
		EDX:distributeFunction("onParachuteReady")
	else
		OFP:setTimer("hangRemoval", 500)
		hasChutes = nil
	end
end

function chutedeploy()
	local haveJumpers = false
	for i,v in pairs(jumperTable) do
		local temp = v
		if not hid then
			hid=OFP:activateEntitySet("hid")
		end
		local x,y,z = OFP:getPosition(i)
		terrain_height = OFP:getTerrainHeight(x,z)
		height_from_ground = math.floor(y - terrain_height)
		distance_fallen = temp.jump_height - height_from_ground
		if distance_fallen >= 20 and height_from_ground <= 200 and temp.dep == 0 then
			temp.container_delay = 0
			temp.dep = 1;
			temp.extra = 0
			temp.chute_set = deploy_chute_table[temp.deploy_chute_index]
			jumperTable[i] = temp
			deploychute(i)
		end
		haveJumpers = true
	end
	if not haveJumpers then
		OFP:removeTimer("chutedeploy")
	else
		OFP:setTimer("chutedeploy", 250)
	end
end

function newJumper(unitName, jumpHeight)
	local temp = {}
	--temp.leader = tostring(OFP:getLeaderOfEchelon(OFP:getParentEchelon(unitName)))
	temp.jump_height = jumpHeight
	temp.count = 0
	temp.alt = 99999
	temp.dep = 0
	temp.teth = 0
	temp.teth2 = 0
	temp.teth3 = 0
	temp.net = 0
	temp.chute = ""
	temp.deploy_chute_index = 1
	temp.extra = 0
	temp.container_delay = 0
	temp.deploy_chute_destroy_table = {}
	temp.container_chute_destroy_table = {}
	jumperTable[unitName] = temp
end

function deploychute(jumperName)
	local temp = jumperTable[jumperName]
	local x,y,z = OFP:getPosition(jumperName)
	if temp.deploy_chute_index > 2 then
		OFP:destroyEntitySet(temp.deploy_chute_destroy_table[1])
		table.remove(temp.deploy_chute_destroy_table,1)
	end
	if temp.container_delay > 1 then
		OFP:destroyEntitySet(temp.container_chute_destroy_table[1])
		table.remove(temp.container_chute_destroy_table,1)
	end
	
	if not jumperTable[jumperName].onGround then
		if not disengageChute(jumperName) then
			spawnedSet[OFP:spawnEntitySetAtLocation(temp.chute_set,x,y + temp.extra,z)] = jumperName
			if temp.teth == 1 then
				temp.container_chute_set = "teth1"
				spawnedSet[OFP:spawnEntitySetAtLocation(temp.container_chute_set,x+0.0,y-3,z+0.0)] = jumperName
			end
		else
			for container_i = 1,#temp.container_chute_destroy_table do
				OFP:destroyEntitySet(temp.container_chute_destroy_table[container_i])
			end
			
			for chute_i = 1,#temp.deploy_chute_destroy_table do
				OFP:destroyEntitySet(temp.deploy_chute_destroy_table[chute_i])
			end	
			OFP:destroyEntitySet(temp.teth2)
			OFP:destroyEntitySet(temp.teth3)
			OFP:setInvulnerable(jumperName,false)
			OFP:clearCommandQueue(jumperName)
-- 			if temp.leader ~= jumperName then
-- 				OFP:attach(OFP:getParentEchelon(temp.leader), jumperName)
-- 			end
			temp.onGround = EDX:serialTimer("removeJumper", 1000, jumperName)
			--OFP:displaySystemMessage("CHUTE CLOSED")
			jumperTable[jumperName] = temp
			return
		end
		if temp.net==1 then
			temp.teth2=OFP:spawnEntitySetAtLocation("tethI2",x-0.8,y-8.1,z-2.3)
			spawnedSet[temp.teth2] = jumperName
		end
		if temp.net==2 then
			temp.teth3=OFP:spawnEntitySetAtLocation("tethI2",x-0.8,y-8.1,z-2.3)
			spawnedSet[temp.teth3] = jumperName
		end
		if temp.net==7 then
			OFP:destroyEntitySet(temp.teth2)
		end
		if temp.net==8 then
			OFP:destroyEntitySet(temp.teth3)
		end
		jumperTable[jumperName] = temp
	end
end

function removeJumper(jumperName, timerID)
	jumperTable[jumperName] = nil
	EDX:deleteTimer(timerID)
end

function onSpawnedReady( setName, setID, tableOfEntities, errorCode )
	if hangChute and hangChute[setID] then
		hangChute[setID] = "spawned"
		if not numChutes then
			numChutes = 0
		end
		numChutes = numChutes + 1
		if numChutes  < 4500 then
			hangChute[OFP:spawnEntitySetAtLocation("cht1", 0, 0, 0)] = true
		end
	end
	if spawnedSet[setID] then
		local jumperName = spawnedSet[setID]
		local temp = jumperTable[jumperName]
		if setName == temp.chute_set then
			table.insert(temp.deploy_chute_destroy_table,setID)
			if temp.deploy_chute_index <= #deploy_chute_table then
				temp.extra = temp.extra + 0.8
				temp.deploy_chute_index = temp.deploy_chute_index + 1
				temp.chute_set = (deploy_chute_table[temp.deploy_chute_index])
			end	
			if temp.deploy_chute_index > #deploy_chute_table then
				temp.teth = 1
				temp.chute_set = "cht1"
				temp.net = temp.net + 1
			end
			jumperTable[spawnedSet[setID]] = temp
			deploychute(jumperName)	
		end	
		if setName == temp.container_chute_set then
			temp.container_delay = temp.container_delay + 1
			table.insert(temp.container_chute_destroy_table,setID)
			jumperTable[spawnedSet[setID]] = temp
		end
		spawnedSet[setID] = nil
	end
end
 
function onDismount(vehicleName, unitName, echelonName)
	if OFP:isInGroup(unitName, "chutegroup") then
		local x,y,z = OFP:getPosition(vehicleName)
		terrain_height = OFP:getTerrainHeight(x,z)
		jump_height = y - terrain_height
		if jump_height >= 50 then
			 jumper = unitName
			 newJumper(unitName, jump_height)
-- 			 if unitName ~= jumperTable[unitName].leader then
-- 			 	OFP:detach(OFP:getParentEchelon(jumperTable[unitName].leader), unitName)
-- 			 end
			 OFP:setInvulnerable(jumper,true)
			 if not OFP:isPlayer(jumper) and not OFP:isSecondaryPlayer(jumper) then
			 	OFP:stop(jumper,"OVERRIDE")
			 end
			 OFP:addTimer("chutedeploy",250)
			-- OFP:displaySystemMessage("jumper jumped")
		end
	end
end

function disengageChute(unitName)
	if OFP:isAlive(unitName) then
		if not jumperTable[unitName] then
			jumperTable[unitName] = {}
			jumperTable[unitName].count = 0
			jumperTable[unitName].alt = 99999
		end
		local x,y,z = OFP:getPosition(unitName)
		local tHeight = OFP:getTerrainHeight(x,z)
		local altitude = y - tHeight
		if y <= 42 or altitude <= 2 then
			jumperTable[unitName] = nil
			return true
		else
			if jumperTable[unitName].count >= 20 then
				if jumperTable[unitName].alt - y <= 1 then
					jumperTable[unitName] = nil
					return true
				end
				jumperTable[unitName].alt = y
				jumperTable[unitName].count = 0
				--OFP:displaySystemMessage("count reset")
			else
				jumperTable[unitName].count = jumperTable[unitName].count + 1
			end
			return false
		end
	else
		return true
	end
end

----------------------------------------------------------------------------------------------------------------DEBUGGING FUNCTIONS

 -- to use the logger to debug your mission just create a log entry in your code like this log("your message")
 --Your message will be written to a file called "yourScriptName Log.txt" and can be found in your OFDR game directory
function log(message)
  if logtofile then
    local logFile = io.open("./"..SCRIPT_NAME.." Log.txt", "a+")
      if message ~= nil then
          logFile:write(os.date() .. ": " .. message .. "\n")
      else
            logFile:write(os.date() .. ": (nil)\n")
        end
      logFile:close()
  end
end
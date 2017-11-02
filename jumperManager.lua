
SCRIPT_NAME = "jumperManager"

onEDXInitialized = function()
    scripts.mission.waypoints.registerFunction("registerCompletedCallback")
    scripts.mission.waypoints.registerFunction("register")
end

function onDataReady()
	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
		data["completeCallback"] = -1
        data["hiddenSet"] = {
            setName = "hid",
            setID = -1 --recover this set after all jumpers hit ground. otherwise all original board on map are invisible too.
        }
        data["chuteSet"] = { "dep1","dep2","dep3","dep4","dep5","dep6","dep7","dep8" }
        data["boardSet"] = "" --need to check
        data["jumpers"] = {}
        data["jumperIndexes"] = {
            chute = { },
            board = { }
        }
        data["params"] = {
            minJumpHeight = 100,
            stepLength = 1
        }
        data["chuteTaskQueue"] = {}
        data["timers"] = {
            chuteTaskProcessor = {
                running = false,
                timerID = -1,
                interval = 250
            },
            jumperStateUpdator = {
                running = false,
                timerID = -1,
                interval = 1600 --set this a little longer
            }
        }
	else
	end
end

function log(message)
    EDX["logger"].log("[jumperManager] "..message)
end

function initializeTimers()
    data["timers"].chuteTaskProcessor.timerID = EDX:serialTimer("chuteTaskProcessor", -1)
    data["timers"].jumperStateUpdator.timerID = EDX:serialTimer("jumperStateUpdator", -1)
end

function registerCompletedCallback(callback)
    log("registerCompletedCallback - "..tostring(callback))
    data["completedCallback"] = callback
end

function register(jumperName)
    log("register - "..jumperName)

    local jh_x, jh_y, jh_z = OFP:getPosition(jumperName)
    local jh_t = OFP:getTerrainHeight(jh_x, jh_z)
    local jumperInfo = {
        basic = {
            name = jumperName,
            coordinate = {
                x = jh_x,
                z = jh_z
            },
            terrHeight = jh_t,
            height = jh_y,
            ["jumperInfo"] = 0
        },
        chute = {
            setIndex = 0,
            deploying = false,
            setID = -1,
            alt = -1,
            board = {
                setID = -1,
                alt = -1
            },
            ["jumperInfo"] = 0
        }
    }
    jumperInfo.basic.jumperInfo = jumperInfo
    jumperInfo.chute.jumperInfo = jumperInfo

    if data[jumperName] then
        local _jumperInfo = data[jumperName]
        _jumperInfo = nil
    end
    data["jumpers"][jumperName] = jumperInfo

    log("registered - "..jumperName)
end

function checkJumpState(vehicle, unit)
    log("checkJumpState - "..vehicle..", "..unit)

    if data["jumpers"][unit] then
        if EDX:isAir(vehicle) and OFP:getHeight(vehicle) > data["params"].minJumpHeight then
            onJumped(unit)
        end
    end
end

function onJumped(jumper)
    log("onJumped - "..jumper)

    local jumperInfo = data["jumpers"][jumper]

end

function jumperStateUpdator(timerID)
    
end

function updateJumperStates(jumperInfo)
    
end

function checkChuteState(setName, setID)
    log("checkChuteState - "..setName..", "..setID)

    if setName == "dep8" or (string.len(setName) == 4 and string.sub(setName, 1, 3) == "dep") then
        onChuteReady(data["jumperIndexes"]["chute"][setID])
        return true
    end
    return false
end

function onChuteReady(chuteInfo)
    log("onChuteReady - "..tostring(chuteInfo))

    --update chute deploy index
    local setIndex = chuteInfo.setIndex
    if chuteInfo.deploying then
        if chuteInfo.setIndex < 8 then
            setIndex = setIndex + 1
            chuteInfo.setIndex = setIndex
        else
            chuteInfo.deploying = false
        end
    end
    --EDX:setTimer(xxx, xxx, chuteInfo) --need to check. 
    --each jumper should have a single timer but this is too difficult
    --so the only way to do this is running a single timer, and use a queue to store updatingNeeded chuteInfo
    --when new item enqueue, start timer; when the queue is empty, freeze the timer
    table.insert(data["chuteTaskQueue"], chuteInfo)
    if data["timers"].chuteTaskProcessor.running == false then --awake processor
        EDX:enableTimer(data["timers"].chuteTaskProcessor.timerID)
    end
end

function chuteTaskProcessor(timerID)
    local tasks = data["chuteTaskQueue"]
    --need lock here
    for k, chuteInfo in pairs(tasks) do
        updateChuteSet(chuteInfo)
        table.remove(data["chuteTaskQueue"], k)
    end

    local processor = data["timers"].chuteTaskProcessor
    if #data["chuteTaskQueue"] == 0 then --sleep
        EDX:disableTimer(processor.timerID)
        processor.running = false
    else
        EDX:setTimer(processor.timerID, processor.interval)
    end
end

function updateChuteSet(chuteInfo)
    log("updateChuteSet -"..tostring(chuteInfo))
    
    --destroy old set
    OFP:destroyEntitySet(chuteInfo.setID)
    OFP:destroyEntitySet(chuteInfo.board.setID)
    log("chute sets recovered")

    local jumperIndexes = data["jumperIndexes"]

    --spawn new set
    local basicInfo = chuteInfo.jumperInfo.basic
    local boardInfo = chuteInfo.board
    local coor = basicInfo.coordinate --this should refresh each time. so the jumper can change hit point a little
    local stepLength = data["params"].stepLength
    
    local chuteIndex = chuteInfo.setIndex
    log("chuteIndex - "..chuteIndex)
    local chuteAlt = chuteInfo.alt + stepLength
    log("chuteAlt - "..chuteAlt)
    local chuteSetID = OFP:spawnEntitySetAtLocation(data["chuteSet"][chuteIndex], coor.x, chuteAlt, coor.z)
    chuteInfo.alt = chuteAlt
    chuteInfo.setID = chuteSetID
    jumperIndexes.chute[chuteSetID] = chuteInfo
    log("chuteSetID - "..chuteSetID)

    local boardAlt = boardInfo.alt + stepLength
    log("boardAlt - "..boardAlt)
    local boardSetID = OFP:spawnEntitySetAtLocation(data["boardSet"], coor.x, boardAlt, coor.z)
    boardInfo.alt = boardAlt
    boardInfo.setID = boardSetID
    jumperIndexes.board[boardSetID] = boardInfo;
    log("boardSetID - "..boardSetID)
end


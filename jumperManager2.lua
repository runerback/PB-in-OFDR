SCRIPT_NAME = "jumperManager"

onEDXInitialized = function()
	scripts.mission.waypoints.registerFunction("register")
	scripts.mission.waypoints.registerFunction("registerCompletion")
end

function onDataReady()
   	data = EDX["dataManager"].GetOrCreate(SCRIPT_NAME)
	if EDX["dataManager"].IsFirstRun() == true then
        data["completion"] = {} --store completion callbacks
        data["entitySets"] = {
            hidden = { --global
                setName = "hid",
                setID = -1
            },
            chute = { 
                setName = "cht1",
                deployings = { "dep1", "dep2", "dep3", "dep4", "dep5", "dep6", "dep7", "dep8" }
            },
            board = {
                setName = "teth1"
            }
        }
        data["jumpers"] = {}
        data["jumperIndexes"] = {
            chute = {},
            board = {}
        }
        data["taskQueue"] = {
            jumper = {
                position = {}
            },
            chute = {
                deploying = {},
                final = {}
            },
            board = {
                max = {},
                bumpers = {}
            }
        }
        data["processors"] = {
            jumper = {
                name = "jumperTaskProcessor",
                timerID = -1,
                interval = 3600,
                running = false
            },
            chute = {
                name = "chuteTaskProcessor",
                timerID = -1,
                interval = 1600,
                running = false
            },
            board = {
                name = "boardTaskProcessor",
                timerID = -1,
                interval = 1600,
                running = false
            }
        }
        data["params"] = {
            minJumpHeight = 100,
            stepLength = 1,
            fallingSpeed = 30.92, --need to test
            deployingHeight = 60
        }
    end
end

function log(message)
    EDX["logger"].log("[jumperManager] "..message)
end

function register( jumperName)
    log("register - "..jumperName)
    if not OFP:isUnit(jumperName) then return end
    if not data then return end
    if data["jumpers"][jumperName] then return end

    local basicInfo = {
        name = jumperName,
        coordinate = {
            x = -1,
            z = -1
        },
        terrHeight = -1,
        alt = -1,
        jumperInfo = -1
    }
    local chuteInfo = {
        deploying = false,
        deployingStep = -1,
        setID = -1,
        setName = -1,
        alt = -1,
        jumperInfo = -1
    }
    local boardInfo = {
        max = {
            setID = -1,
            alt = -1
        },
        bumpers = {},
        jumperInfo = -1
    }
    local jumperInfo = {
        jumper = basicInfo,
        chute = chuteInfo,
        board = boardInfo
    }
    basicInfo.jumperInfo = jumperInfo
    chuteInfo.jumperInfo = jumperInfo
    boardInfo.jumperInfo = jumperInfo

    data["jumpers"][jumperName] = jumperInfo
    log("jumper registered - "..jumperName)
end

function registerCompletion( callback)
    log("registerCompletion - "..tostring(callback))

    table.insert(data["completion"], callback)
end

function initializeProcessors()
    log("initializeProcessors")

    for _, processor in pairs(data["processors"]) do
        processor.timerID = EDX:serialTimer(processor.name, -1, processor)
    end

    log("processors initialized")
end

function releaseProcessor(name)
    log("releaseProcessor - "..name)

    if data and data["processors"] then
        local processor = data["processors"][name]
        if processor then
            EDX:deleteTimer(processor.timerID)
            data["processors"][name] = nil
            log("processor released - "..name)
        end
    end
end

function processorScheduler( name)
    log("processorScheduler - "..name)

    if data and data["processors"] then
        local processor = data["processors"][name]
        if processor and processor.running == false then
            processor.running = true
            log("processor awaken - "..name)
            EDX:setTimer(processor.name, 100) --make this async
        end
    end
end

function updateProcessorState(processor, sleep)
    log("updateProcessorState - "..processor.name.." : "..tostring(sleep))
    if sleep then
        processor.running = false
        EDX:disableTimer(processor.timerID)
    else
        EDX:setTimer(processor.timerID, processor.interval)
    end
end

function jumperTaskProcessor(timerID, processor)
    local jumperQueue = data["taskQueue"].jumper
    local tasks = jumperQueue.position
    for _, basicInfo in pairs(tasks) do
        updateJumperInfo( basicInfo)
    end
    tasks = {}

    updateProcessorState(processor, #jumperQueue.position == 0)
end

function chuteTaskProcessor(timerID, processor)
    local chuteQueue = data["taskQueue"].chute

    local deployingTasks = chuteQueue.deploying
    for _, chuteInfo in pairs(deployingTasks) do
        updateDeployingChuteSet( chuteInfo)
    end
    deployingTasks = {}

    local finalTasks = chuteQueue.final
    for _, chuteInfo in pairs(finalTasks) do
        updateFinalChuteSet( chuteInfo)
    end
    finalTasks = {}

    updateProcessorState(processor, #chuteQueue.deploying + #chuteQueue.final == 0)
end

function boardTaskProcessor(timerID, processor)
    local boardQueue = data["taskQueue"].board
    
    local maxTasks = boardQueue.max
    for _, boardInfo in pairs(maxTasks) do
        updateMaxBoardSet( boardInfo)
    end
    maxTasks = {}

    local bumpersTasks = boardQueue.bumpers
    for _, boardInfo in pairs(bumpersTasks) do
        updateBoardsSet(boardInfo)
    end
    bumpersTasks = {}

    updateProcessorState(processor, #boardQueue.max + #boardQueue.bumpers == 0)
end

function checkJumpState(vehicle, unit)
    if data then
        if data["jumpers"][unit] and EDX:isAir(vehicle) then
            if OFP:getHeight(vehicle) >= data["params"].minJumpHeight then
                onJumped(unit)
            end
        end
    end
    return false
end

function onJumped( jumperName)
    log("onJumped - "..jumperName)

    table.insert(data["taskQueue"].jumper.position, data["jumpers"][jumperName])
    processorScheduler("jumper")
end

function updateJumperInfo( basicInfo) --chute and bumper based on this
    log("updateJumperInfo - "..tostring(basicInfo))

    local jumper = basicInfo.name
    local _x, _y, _z = OFP:getPosition(jumper)
    basicInfo.alt = _y
    local coordinate = basicInfo.coordinate
    coordinate.x = _x
    coordinate.z = _z
    local terr = OFP:getTerrainHeight(_x, _z)
    basicInfo.terrHeight = terr

    if _y < data["params"].deployingHeight and _y > terr then
        local chuteInfo = basicInfo.jumperInfo.chute
        local alt = _y
        local deployingStep = chuteInfo.deployingStep
        local setID
        if deployingStep < 0 then
            deployingStep = 0
            chuteInfo.deploying = true
        end
        chuteInfo.alt = alt
        if chuteInfo.deploying then
            deployingStep = deployingStep + 1
            chuteInfo.deployingStep = deployingStep
            setID = OFP:spawnEntitySetAtLocation(
                data["entitySets"].chute.deployings[deployingStep], _x, alt, _z)
            if deployingStep == 8 then
                chuteInfo.deploying = false
            end
        else
            setID = OFP:spawnEntitySetAtLocation(
                data["entitySets"].chute.setName, _x, alt, _z)
        end
        chuteInfo.setID = setID
        data["jumperIndexes"].chute[setID] = chuteInfo
    end
end

function checkChuteState( setID)
    if data then
        local chuteInfo = data["jumperIndexes"].chute[setID]
        if chuteInfo then
            log("chute ready - "..setID)
            data["jumperIndexes"].chute[setID] = nil
            onChuteReady(chuteInfo)
            return true
        end
    end
    return false
end

function onChuteReady( chuteInfo)
    log("onChuteReady - "..tostring(chuteInfo))

    local basicInfo = chuteInfo.jumperInfo.jumper


    OFP:destroyEntitySet(chuteInfo.setID)
end

function updateDeployingChuteSet( chuteInfo)
    log("updateDeployingChuteSet - "..tostring(chuteInfo))


end

function updateFinalChuteSet( chuteInfo)
    log("updateFinalChuteSet - "..tostring(chuteInfo))


end

function checkBoardState( setID)
    if data then
        local boardInfo = data["jumperIndexes"].board[setID]
        if boardInfo then
            log("board ready - "..setID)
            data["jumperIndexes"].board[setID] = nil
            onBoardReady(boardInfo)
            return true
        end
    end
    return false
end

function onBoardReady( boardInfo)
    log("onBoardReady - "..tostring(boardInfo))


end

function updateMaxBoardSet( boardInfo)
    log("updateMaxBoardSet - "..tostring(boardInfo))


end

function updateBoardsSet( boardInfo)
    log("updateBoardsSet - "..tostring(boardInfo))


end

function checkHiddenSet( setID)
    if data and setID == data["entitySets"].hidden.setID then
        onHiddenSetReady()
        return true
    end
    return false
end

function onHiddenSetReady()
    log("onHiddenSetReady")
end

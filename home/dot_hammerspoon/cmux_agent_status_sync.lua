-- Keep Agent Board's idle markers and branch descriptions aligned with cmux metadata.

local module = {}

local cmuxPath = "/opt/homebrew/bin/cmux"
local syncPath = os.getenv("HOME") .. "/.local/bin/cmux-agent-status-sync"
local debounceDelay = 1
local branchSyncInterval = 30

local eventTask = nil
local syncTask = nil
local debounceTimer = nil
local branchTimer = nil
local terminal = false
local pendingSync = false
local pendingBranchSync = false
local failureNotified = false
local lastError = nil
local lastOutput = nil
local lastSyncAt = nil
local eventErrorOutput = ""

local function stopMonitoring()
    terminal = true
    pendingSync = false
    pendingBranchSync = false

    if debounceTimer then
        debounceTimer:stop()
        debounceTimer = nil
    end

    if branchTimer then
        branchTimer:stop()
        branchTimer = nil
    end

    if syncTask then
        syncTask:terminate()
        syncTask = nil
    end

    if eventTask then
        eventTask:terminate()
        eventTask = nil
    end
end

local function fail(message)
    if terminal then
        return
    end

    lastError = message
    stopMonitoring()

    if not failureNotified then
        failureNotified = true
        hs.notify.new({
            title = "cmux Agent Board sync stopped",
            informativeText = message,
        }):send()
    end
end

local runSync
local runBranchSync
local runTask

runTask = function(arguments)
    if terminal then
        return
    end

    if syncTask then
        pendingSync = true
        return
    end

    local completion = function(exitCode, stdout, stderr)
        syncTask = nil
        lastOutput = (stdout or "") .. (stderr or "")

        if exitCode ~= 0 then
            local detail = (stderr or ""):match("^%s*(.-)%s*$")
            if not detail or detail == "" then
                detail = "exit " .. tostring(exitCode)
            end
            fail("Reconciliation failed: " .. detail)
            return
        end

        lastSyncAt = os.date("%Y-%m-%d %H:%M:%S")
        if pendingSync then
            pendingSync = false
            runSync()
        elseif pendingBranchSync then
            pendingBranchSync = false
            runBranchSync()
        end
    end

    syncTask = hs.task.new(syncPath, completion, arguments)

    if not syncTask then
        fail("Could not create the reconciliation task")
        return
    end

    if not syncTask:start() then
        syncTask = nil
        fail("Could not start the reconciliation task")
    end
end

runSync = function()
    if terminal then
        return
    end

    pendingBranchSync = false

    if syncTask then
        pendingSync = true
        return
    end

    runTask({})
end

runBranchSync = function()
    if terminal then
        return
    end

    if syncTask then
        pendingBranchSync = true
        return
    end

    runTask({ "--branch-only" })
end

local function scheduleSync()
    if terminal then
        return
    end

    if debounceTimer then
        debounceTimer:stop()
    end

    debounceTimer = hs.timer.doAfter(debounceDelay, function()
        debounceTimer = nil
        runSync()
    end)
end

function module.start()
    if eventTask or syncTask or branchTimer then
        return true
    end

    if terminal then
        return false
    end

    eventTask = hs.task.new(
        cmuxPath,
        function(exitCode, _, stderr)
            eventTask = nil
            if terminal then
                return
            end

            local detail = (stderr or "") .. eventErrorOutput
            detail = detail:match("^%s*(.-)%s*$")
            if detail == "" then
                detail = "exit " .. tostring(exitCode)
            end
            fail("Event stream exited unexpectedly: " .. detail)
        end,
        function(_, stdout, stderr)
            if stderr and stderr ~= "" then
                eventErrorOutput = eventErrorOutput .. stderr
            end
            if stdout and stdout ~= "" then
                scheduleSync()
            end
            return true
        end,
        {
            "events",
            "--name", "sidebar.metadata.updated",
            "--name", "sidebar.metadata.cleared",
            "--no-ack",
            "--no-heartbeat",
        }
    )

    if not eventTask then
        fail("Could not create the cmux event task")
        return false
    end

    if not eventTask:start() then
        eventTask = nil
        fail("Could not start the cmux event task")
        return false
    end

    branchTimer = hs.timer.doEvery(branchSyncInterval, runBranchSync)
    if not branchTimer then
        fail("Could not create the branch reconciliation timer")
        return false
    end

    runSync()
    return true
end

function module.status()
    return {
        running = not terminal and eventTask ~= nil and branchTimer ~= nil,
        syncInFlight = syncTask ~= nil,
        pendingSync = pendingSync,
        lastSyncAt = lastSyncAt,
        lastError = lastError,
        lastOutput = lastOutput,
    }
end

return module

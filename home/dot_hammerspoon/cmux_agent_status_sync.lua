-- Keep Agent Board's stopped state aligned with cmux's live agent metadata.

local module = {}

local cmuxPath = "/opt/homebrew/bin/cmux"
local syncPath = os.getenv("HOME") .. "/.local/bin/cmux-agent-status-sync"
local reconcileInterval = 30
local debounceDelay = 0.25

local eventTask = nil
local syncTask = nil
local reconcileTimer = nil
local debounceTimer = nil
local terminal = false
local pendingSync = false
local failureNotified = false
local lastError = nil
local lastOutput = nil
local lastSyncAt = nil
local eventErrorOutput = ""

local function stopMonitoring()
    terminal = true
    pendingSync = false

    if debounceTimer then
        debounceTimer:stop()
        debounceTimer = nil
    end

    if reconcileTimer then
        reconcileTimer:stop()
        reconcileTimer = nil
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

runSync = function()
    if terminal then
        return
    end

    if syncTask then
        pendingSync = true
        return
    end

    syncTask = hs.task.new(syncPath, function(exitCode, stdout, stderr)
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
        end
    end)

    if not syncTask then
        fail("Could not create the reconciliation task")
        return
    end

    if not syncTask:start() then
        syncTask = nil
        fail("Could not start the reconciliation task")
    end
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
    if eventTask or reconcileTimer or syncTask then
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

    reconcileTimer = hs.timer.doEvery(reconcileInterval, runSync)
    runSync()
    return true
end

function module.status()
    return {
        running = not terminal and eventTask ~= nil and reconcileTimer ~= nil,
        syncInFlight = syncTask ~= nil,
        pendingSync = pendingSync,
        lastSyncAt = lastSyncAt,
        lastError = lastError,
        lastOutput = lastOutput,
    }
end

return module

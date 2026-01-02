-- Hammerspoon Configuration for Window Management
-- Manages different layouts for external and built-in displays

-- Enable Spotlight for better application name matching
hs.application.enableSpotlightForNameSearches(true)

-- Hotkey modifier
local hyper = {"alt", "ctrl"}

-- ============================================================================
-- LAYOUT CONFIGURATION
-- ============================================================================

-- External Display Layout (4-split configuration)
-- Left: 45% | Right: 55%
-- Each side: Top 20% | Bottom 80%
local externalLayout = {
    -- Split ratios
    leftWidth = 0.45,  -- Left side: 45%
    rightWidth = 0.55, -- Right side: 55%
    topHeight = 0.2,   -- Top area: 20%
    bottomHeight = 0.8, -- Bottom area: 80%

    -- Application assignments
    leftTop = "Sublime Text",    -- Left top (45% x 20%)
    leftBottom = "Google Chrome", -- Left bottom (45% x 80%)
    rightTop = "ghostty",         -- Right top (55% x 20%)
    rightBottom = "Cursor"        -- Right bottom (55% x 80%)
}

-- Built-in Display Layout
-- Most apps: fullscreen
-- Sublime Text & ghostty: top 20%
local builtInLayout = {
    topHeight = 0.2,  -- Top area for Sublime Text and ghostty: 20%

    -- Applications that use top 20%
    topApps = {
        "Sublime Text",
        "ghostty"
    },

    -- Applications that use fullscreen (everything else)
    fullscreenApps = {
        "Google Chrome",
        "Cursor"
    }
}

-- ============================================================================
-- APPLICATION NAMES
-- ============================================================================

-- Application names as they appear in the system
local apps = {
    chrome = "Google Chrome",
    sublime = "Sublime Text",
    cursor = "Cursor",
    ghostty = "ghostty"
}

-- Check if external display is connected
local function isExternalDisplayConnected()
    local screens = hs.screen.allScreens()

    -- If more than 1 screen, we have external display
    if #screens > 1 then
        return true
    end

    -- If only 1 screen, check if it's an external display (Studio Display, etc.)
    if #screens == 1 then
        local screen = screens[1]
        local name = screen:name()
        -- Check if the screen name indicates it's an external display
        if name and (string.find(name, "Studio Display") or
                     string.find(name, "LG") or
                     string.find(name, "Dell") or
                     string.find(name, "ASUS")) then
            print(string.format("Single external display detected: %s", name))
            return true
        end
    end

    return false
end

-- Get the built-in screen
local function getBuiltInScreen()
    local screens = hs.screen.allScreens()

    -- If multiple screens, find the one that's built-in
    if #screens > 1 then
        for _, screen in ipairs(screens) do
            local name = screen:name()
            if name and string.find(name, "Built%-in") then
                return screen
            end
        end
        -- If no "Built-in" found, return the smallest screen
        local smallest = nil
        local minPixels = math.huge
        for _, screen in ipairs(screens) do
            local mode = screen:currentMode()
            local pixels = mode.w * mode.h
            if pixels < minPixels then
                minPixels = pixels
                smallest = screen
            end
        end
        return smallest
    end

    -- If only one screen, return it
    return hs.screen.primaryScreen()
end

-- Get the external screen (largest non-built-in screen, or Studio Display in clamshell mode)
local function getExternalScreen()
    local screens = hs.screen.allScreens()

    -- If only 1 screen and it's an external display (clamshell mode)
    if #screens == 1 then
        local screen = screens[1]
        local name = screen:name()
        if name and (string.find(name, "Studio Display") or
                     string.find(name, "LG") or
                     string.find(name, "Dell") or
                     string.find(name, "ASUS")) then
            print(string.format("Using external display in clamshell mode: %s", name))
            return screen
        end
        return nil
    end

    -- If multiple screens, find the largest non-built-in screen
    if #screens > 1 then
        local builtIn = getBuiltInScreen()
        local external = nil
        local maxPixels = 0

        for _, screen in ipairs(screens) do
            if screen ~= builtIn then
                local mode = screen:currentMode()
                local pixels = mode.w * mode.h
                if pixels > maxPixels then
                    maxPixels = pixels
                    external = screen
                end
            end
        end
        return external
    end

    return nil
end

-- Get the first usable window for an application
local function getAppWindow(app, shouldCreateWindow)
    if not app then
        return nil
    end

    -- First, check if the app has any windows at all
    local windows = app:allWindows()
    print(string.format("    App has %d total windows", #windows))

    -- If no windows and we should create one, try to create a new window
    if #windows == 0 and shouldCreateWindow then
        print("    No windows found, attempting to create one...")
        app:activate(true) -- bring all windows forward
        hs.timer.usleep(300000) -- 300ms

        -- Try Cmd+N to create new window
        hs.eventtap.keyStroke({"cmd"}, "n", 0, app)
        hs.timer.usleep(800000) -- 800ms - wait for window creation

        -- Refresh windows list
        windows = app:allWindows()
        print(string.format("    After Cmd+N: %d windows", #windows))

        if #windows == 0 then
            print("    Still no windows, giving up")
            return nil
        end
    end

    -- Now try to find and prepare a window
    -- First, activate and unhide the app
    app:activate(true)
    app:unhide()
    hs.timer.usleep(200000) -- 200ms

    -- Try mainWindow first
    local window = app:mainWindow()
    if window then
        print("    Found mainWindow")
        if window:isMinimized() then
            print("    Unminimizing mainWindow")
            window:unminimize()
        end
        return window
    end

    -- Try focused window
    local focusedWindow = app:focusedWindow()
    if focusedWindow then
        print("    Found focusedWindow")
        if focusedWindow:isMinimized() then
            print("    Unminimizing focusedWindow")
            focusedWindow:unminimize()
        end
        return focusedWindow
    end

    -- Try all windows
    for i, win in ipairs(windows) do
        print(string.format("    Checking window %d: isMinimized=%s, isStandard=%s", i, tostring(win:isMinimized()), tostring(win:isStandard())))
        if win:isMinimized() then
            win:unminimize()
            hs.timer.usleep(100000)
        end
        if win:isStandard() then
            print(string.format("    Using window %d", i))
            return win
        end
    end

    -- Last resort: return first window
    if #windows > 0 then
        print("    Using first available window")
        local win = windows[1]
        if win:isMinimized() then
            win:unminimize()
        end
        return win
    end

    print("    No usable window found")
    return nil
end

-- Debug function to show running applications
local function showRunningApps()
    local runningApps = hs.application.runningApplications()
    local appNames = {}
    for _, app in ipairs(runningApps) do
        local window = getAppWindow(app, false) -- false = don't create window, just check
        if window then
            table.insert(appNames, app:name())
        end
    end
    hs.alert.show("Running apps with windows:\n" .. table.concat(appNames, "\n"))
    print("Running applications with windows:")
    for _, name in ipairs(appNames) do
        print("  - " .. name)
    end
end

-- Layout configuration for external display (4-split)
local function layoutExternalDisplay()
    local externalScreen = getExternalScreen()
    if not externalScreen then
        hs.alert.show("No external display detected")
        return
    end

    local frame = externalScreen:frame()
    print(string.format("External display frame: x=%d, y=%d, w=%d, h=%d", frame.x, frame.y, frame.w, frame.h))

    -- Calculate dimensions based on configuration
    local leftWidth = frame.w * externalLayout.leftWidth
    local rightWidth = frame.w * externalLayout.rightWidth
    local topHeight = frame.h * externalLayout.topHeight
    local bottomHeight = frame.h * externalLayout.bottomHeight

    -- Define 4-split layout positions
    local layouts = {
        -- Left top: Sublime Text (40% x 10%)
        [externalLayout.leftTop] = {
            x = frame.x,
            y = frame.y,
            w = leftWidth,
            h = topHeight
        },
        -- Left bottom: Chrome (40% x 90%)
        [externalLayout.leftBottom] = {
            x = frame.x,
            y = frame.y + topHeight,
            w = leftWidth,
            h = bottomHeight
        },
        -- Right top: ghostty (60% x 10%)
        [externalLayout.rightTop] = {
            x = frame.x + leftWidth,
            y = frame.y,
            w = rightWidth,
            h = topHeight
        },
        -- Right bottom: Cursor (60% x 90%)
        [externalLayout.rightBottom] = {
            x = frame.x + leftWidth,
            y = frame.y + topHeight,
            w = rightWidth,
            h = bottomHeight
        }
    }

    -- Apply layouts
    for appName, rect in pairs(layouts) do
        print(string.format("Attempting to position: %s", appName))
        local app = hs.application.get(appName)
        if app then
            print(string.format("  Found app: %s", appName))
            local window = getAppWindow(app, true) -- true = should create window if missing
            if window then
                print(string.format("  Found window for %s", appName))
                print(string.format("  Setting frame: x=%d, y=%d, w=%d, h=%d",
                    math.floor(rect.x), math.floor(rect.y),
                    math.floor(rect.w), math.floor(rect.h)))
                window:setFrame(rect, 0)
                hs.alert.show(string.format("Positioned %s", appName))
            else
                print(string.format("  Failed to get window for %s", appName))
                hs.alert.show(string.format("%s: Could not get window", appName))
            end
        else
            print(string.format("  %s is not running", appName))
            hs.alert.show(string.format("%s is not running", appName))
        end
    end
end

-- Layout configuration for built-in display
local function layoutBuiltInDisplay()
    local builtInScreen = getBuiltInScreen()
    local frame = builtInScreen:frame()
    print(string.format("Built-in display frame: x=%d, y=%d, w=%d, h=%d", frame.x, frame.y, frame.w, frame.h))

    local topHeight = frame.h * builtInLayout.topHeight

    -- Position apps that use top 10% (Sublime Text, ghostty)
    for _, appName in ipairs(builtInLayout.topApps) do
        print(string.format("Attempting to position (top 10%%): %s", appName))
        local app = hs.application.get(appName)
        if app then
            print(string.format("  Found app: %s", appName))
            local window = getAppWindow(app, true) -- true = should create window if missing
            if window then
                print(string.format("  Found window, positioning to top 10%%..."))
                window:setFrame({
                    x = frame.x,
                    y = frame.y,
                    w = frame.w,
                    h = topHeight
                }, 0)
                hs.alert.show(string.format("Positioned %s (top 10%%)", appName))
            else
                print(string.format("  Failed to get window for %s", appName))
            end
        else
            print(string.format("  %s is not running", appName))
        end
    end

    -- Position apps that use fullscreen (Chrome, Cursor)
    for _, appName in ipairs(builtInLayout.fullscreenApps) do
        print(string.format("Attempting to position (fullscreen): %s", appName))
        local app = hs.application.get(appName)
        if app then
            print(string.format("  Found app: %s", appName))
            local window = getAppWindow(app, true) -- true = should create window if missing
            if window and window:screen() == builtInScreen then
                print(string.format("  Positioning %s to fullscreen", appName))
                window:setFrame({
                    x = frame.x,
                    y = frame.y,
                    w = frame.w,
                    h = frame.h
                }, 0)
                hs.alert.show(string.format("Positioned %s (fullscreen)", appName))
            else
                if not window then
                    print(string.format("  Failed to get window for %s", appName))
                else
                    print(string.format("  %s is not on built-in display", appName))
                end
            end
        else
            print(string.format("  %s is not running", appName))
        end
    end
end

-- Smart layout: applies the correct layout based on display configuration
local function smartLayout()
    print("Checking display configuration...")
    local screenCount = #hs.screen.allScreens()
    print(string.format("Number of screens detected: %d", screenCount))

    if isExternalDisplayConnected() then
        print("External display detected, applying external layout")
        hs.alert.show("Applying external display layout")
        layoutExternalDisplay()
    else
        print("No external display, applying built-in layout")
        hs.alert.show("Applying built-in display layout")
        layoutBuiltInDisplay()
    end
end

-- Bind hotkeys
hs.hotkey.bind(hyper, "H", function()
    print("=== Smart Layout triggered ===")
    smartLayout()
end)

-- Separate hotkeys for each display
hs.hotkey.bind(hyper, "E", function()
    print("=== External Display Layout triggered ===")
    layoutExternalDisplay()
end)

hs.hotkey.bind(hyper, "I", function()
    print("=== Built-in Display Layout triggered ===")
    layoutBuiltInDisplay()
end)

-- Debug hotkey to show running apps
hs.hotkey.bind(hyper, "D", function()
    print("=== Debug: Showing running apps ===")
    showRunningApps()
end)

-- Test hotkey to check display information
hs.hotkey.bind(hyper, "T", function()
    print("=== Test: Checking Display Information ===")

    local screens = hs.screen.allScreens()
    print(string.format("Total screens detected: %d", #screens))

    for i, screen in ipairs(screens) do
        print(string.format("\nScreen %d:", i))
        print(string.format("  Name: %s", screen:name() or "unknown"))
        local mode = screen:currentMode()
        print(string.format("  Resolution: %dx%d", mode.w, mode.h))
        local frame = screen:frame()
        print(string.format("  Frame: x=%d, y=%d, w=%d, h=%d", frame.x, frame.y, frame.w, frame.h))
        local uuid = screen:getUUID()
        print(string.format("  UUID: %s", uuid or "none"))

        -- Check if this is the primary screen
        local primary = hs.screen.primaryScreen()
        if screen == primary then
            print("  ** This is the PRIMARY screen **")
        end
    end

    print("\n=== Checking external display detection ===")
    if isExternalDisplayConnected() then
        print("External display detected: YES")
        local ext = getExternalScreen()
        if ext then
            print(string.format("External screen name: %s", ext:name() or "unknown"))
        end
    else
        print("External display detected: NO")
    end
end)

-- Watch for display changes
local function displayWatcher()
    hs.alert.show("Display configuration changed")
    -- Optionally, auto-apply layout when displays change
    -- smartLayout()
end

local displayWatcherObj = hs.screen.watcher.new(displayWatcher)
displayWatcherObj:start()

-- Notification
hs.alert.show("Hammerspoon config loaded")
hs.notify.new({
    title = "Hammerspoon",
    informativeText = "Window management hotkeys:\n⌥⌃H - Smart layout\n⌥⌃E - External display layout\n⌥⌃I - Built-in display layout\n⌥⌃D - Debug (show running apps)\n⌥⌃T - Test display detection"
}):send()

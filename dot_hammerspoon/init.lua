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
-- Left: 50% | Right: 50%
-- Left side: Top 20% | Bottom 80%
-- Right side: Top 25% | Bottom 75%
local externalLayout = {
    -- Split ratios
    leftWidth = 0.5,   -- Left side: 50%
    rightWidth = 0.5,  -- Right side: 50%
    leftTopHeight = 0.2,     -- Left top area: 20%
    leftBottomHeight = 0.8,  -- Left bottom area: 80%
    rightTopHeight = 1.0,    -- Right top area: 100% (cmux full height)
    rightBottomHeight = 0.55, -- Right bottom area: 55%

    -- Application assignments
    leftTop = "Sublime Text",    -- Left top (45% x 20%)
    leftBottom = "Google Chrome", -- Left bottom (45% x 80%)
    rightTop = "cmux",            -- Right full height
    rightBottom = "Cursor"        -- Right bottom (overlaps cmux)
}

-- Built-in Display Layout
-- Most apps: fullscreen
local builtInLayout = {
    topHeight = 0.8,

    topApps = {
        "Sublime Text",
        "cmux"
    },

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
    cmux = "cmux"
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

-- Get all visible (non-minimized) windows for an application
local function getAppWindows(app)
    if not app then
        return {}
    end

    -- Use visibleWindows() to get only non-minimized, non-hidden windows
    local windows = app:visibleWindows()

    -- Filter to standard windows only (exclude panels, sheets, etc.)
    local usableWindows = {}
    for _, win in ipairs(windows) do
        if win:isStandard() then
            table.insert(usableWindows, win)
        end
    end

    return usableWindows
end

-- Layout configuration for external display (4-split)
-- Only affects windows currently on the external display
local function layoutExternalDisplay()
    local externalScreen = getExternalScreen()
    if not externalScreen then
        return
    end

    local frame = externalScreen:frame()

    -- Calculate dimensions based on configuration
    local leftWidth = frame.w * externalLayout.leftWidth
    local rightWidth = frame.w * externalLayout.rightWidth
    local leftTopHeight = frame.h * externalLayout.leftTopHeight
    local leftBottomHeight = frame.h * externalLayout.leftBottomHeight
    local rightTopHeight = frame.h * externalLayout.rightTopHeight
    local rightBottomHeight = frame.h * externalLayout.rightBottomHeight

    -- Define layout positions for external display
    local layouts = {
        -- Left top: Sublime Text
        [externalLayout.leftTop] = {
            x = frame.x,
            y = frame.y,
            w = leftWidth,
            h = leftTopHeight
        },
        -- Left bottom: Chrome
        [externalLayout.leftBottom] = {
            x = frame.x,
            y = frame.y + leftTopHeight,
            w = leftWidth,
            h = leftBottomHeight
        },
        -- Right: cmux (full height)
        [externalLayout.rightTop] = {
            x = frame.x + leftWidth,
            y = frame.y,
            w = rightWidth,
            h = rightTopHeight
        },
        -- Right bottom: Cursor (overlaps cmux)
        [externalLayout.rightBottom] = {
            x = frame.x + leftWidth,
            y = frame.y + frame.h - rightBottomHeight,
            w = rightWidth,
            h = rightBottomHeight
        }
    }

    -- Apply layouts only to windows on the external display
    for appName, rect in pairs(layouts) do
        local app = hs.application.get(appName)
        if app then
            local windows = getAppWindows(app)
            for _, window in ipairs(windows) do
                if window:screen() == externalScreen then
                    window:setFrame(rect, 0)
                end
            end
        end
    end
end

-- Layout configuration for built-in display
local function layoutBuiltInDisplay()
    local builtInScreen = getBuiltInScreen()
    local frame = builtInScreen:frame()
    local topHeight = frame.h * builtInLayout.topHeight

    -- Position apps that use top 20% (Sublime Text, ghostty)
    for _, appName in ipairs(builtInLayout.topApps) do
        local app = hs.application.get(appName)
        if app then
            local windows = getAppWindows(app)
            for _, window in ipairs(windows) do
                window:setFrame({
                    x = frame.x,
                    y = frame.y,
                    w = frame.w,
                    h = topHeight
                }, 0)
            end
        end
    end

    -- Position apps that use fullscreen (Chrome, Cursor)
    for _, appName in ipairs(builtInLayout.fullscreenApps) do
        local app = hs.application.get(appName)
        if app then
            local windows = getAppWindows(app)
            for _, window in ipairs(windows) do
                if window:screen() == builtInScreen then
                    window:setFrame({
                        x = frame.x,
                        y = frame.y,
                        w = frame.w,
                        h = frame.h
                    }, 0)
                end
            end
        end
    end
end

-- Smart layout: applies the correct layout based on display configuration
local function smartLayout()
    if isExternalDisplayConnected() then
        layoutExternalDisplay()
    else
        layoutBuiltInDisplay()
    end
end

-- Bind hotkeys
hs.hotkey.bind(hyper, "H", function()
    smartLayout()
end)

hs.hotkey.bind(hyper, "E", function()
    layoutExternalDisplay()
end)

hs.hotkey.bind(hyper, "I", function()
    layoutBuiltInDisplay()
end)

-- Toggle active window between external and built-in display (maximized)
hs.hotkey.bind(hyper, "J", function()
    local window = hs.window.focusedWindow()
    if not window then
        return
    end

    local externalScreen = getExternalScreen()
    local builtInScreen = getBuiltInScreen()

    if not externalScreen or not builtInScreen then
        return
    end

    local currentScreen = window:screen()
    local targetScreen

    if currentScreen == externalScreen then
        targetScreen = builtInScreen
    else
        targetScreen = externalScreen
    end

    local frame = targetScreen:frame()
    window:setFrame(frame, 0)
end)

-- Run a shell command in a new terminal surface within the current cmux workspace
local function runInNewCmuxTerminalSurface(cmd)
    local app = hs.application.frontmostApplication()
    if not app or app:name() ~= "cmux" then
        return
    end

    hs.eventtap.keyStroke({"cmd"}, "t")
    hs.timer.doAfter(0.20, function()
        hs.eventtap.keyStroke({"ctrl"}, "u")

        local prevClipboard = hs.pasteboard.getContents()
        hs.pasteboard.setContents(cmd)
        hs.eventtap.keyStroke({"cmd"}, "v")

        hs.timer.doAfter(0.05, function()
            hs.eventtap.keyStroke({}, "return")
            hs.timer.doAfter(0.05, function()
                if prevClipboard then
                    hs.pasteboard.setContents(prevClipboard)
                end
            end)
        end)
    end)
end

-- ============================================================================
-- CMUX BROWSER KEY OVERRIDES
-- ============================================================================

-- Intercept Cmd+W in cmux browser surfaces to close the VS Code editor tab
-- instead of closing the browser surface itself.
-- Requires code-server keybindings.json: {"key":"ctrl+w","command":"workbench.action.closeActiveEditor"}
local cmuxBrowserKeyOverride = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local app = hs.application.frontmostApplication()
    if not app or app:name() ~= "cmux" then
        return false
    end

    local flags = event:getFlags()
    local keyCode = event:getKeyCode()

    -- Cmd+W (keyCode 13 = W)
    if flags.cmd and not flags.alt and not flags.ctrl and not flags.shift and keyCode == 13 then
        local output = hs.execute("/opt/homebrew/bin/cmux identify --no-caller 2>/dev/null")
        if output then
            local data = hs.json.decode(output)
            if data and data.focused and data.focused.is_browser_surface then
                local ref = data.focused.surface_ref
                hs.execute("/opt/homebrew/bin/cmux browser press --surface " .. ref .. " 'Control+w' 2>/dev/null")
                return true -- consume the event
            end
        end
    end

    return false
end)
cmuxBrowserKeyOverride:start()

-- ============================================================================
-- DIFIT INTEGRATION
-- ============================================================================

-- Launch difit web review for current working tree (no split)
hs.hotkey.bind({"cmd", "shift"}, "G", function()
    local cmd = "difit working --no-open >/tmp/difit.log 2>&1 & " ..
        "for i in {1..20}; do nc -z localhost 4966 >/dev/null 2>&1 && break; sleep 0.05; done; " ..
        "cmux new-surface --type browser --url http://localhost:4966"

    runInNewCmuxTerminalSurface(cmd)
end)

-- Launch difit web review against fork base branch (no split)
hs.hotkey.bind({"cmd", "shift"}, "H", function()
    local cmd = "BASE_BRANCH=$(git config --get branch.$(git rev-parse --abbrev-ref HEAD).gh-merge-base); " ..
        "if [ -z \"$BASE_BRANCH\" ]; then BASE_BRANCH=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed \"s#^origin/##\"); fi; " ..
        "if [ -z \"$BASE_BRANCH\" ]; then BASE_BRANCH=main; fi; " ..
        "if git show-ref --verify --quiet \"refs/remotes/origin/$BASE_BRANCH\"; then TARGET=\"origin/$BASE_BRANCH\"; " ..
        "elif git show-ref --verify --quiet \"refs/heads/$BASE_BRANCH\"; then TARGET=\"$BASE_BRANCH\"; " ..
        "else TARGET=\"origin/main\"; fi; " ..
        "difit . \"$TARGET\" --no-open >/tmp/difit.log 2>&1 & " ..
        "for i in {1..20}; do nc -z localhost 4966 >/dev/null 2>&1 && break; sleep 0.05; done; " ..
        "cmux new-surface --type browser --url http://localhost:4966"

    runInNewCmuxTerminalSurface(cmd)
end)

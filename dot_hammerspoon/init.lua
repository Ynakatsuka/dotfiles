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
    topHeight = 0.25,   -- Top area: 25%
    bottomHeight = 0.75, -- Bottom area: 75%

    -- Application assignments
    leftTop = "Sublime Text",    -- Left top (45% x 20%)
    leftBottom = "Google Chrome", -- Left bottom (45% x 80%)
    rightTop = "ghostty",         -- Right top (55% x 20%)
    rightBottom = "Cursor"        -- Right bottom (55% x 80%)
}

-- Built-in Display Layout
-- Most apps: fullscreen
local builtInLayout = {
    topHeight = 0.4,

    topApps = {
        "Sublime Text",
        "ghostty"
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

-- Get all usable windows for an application
local function getAppWindows(app)
    if not app then
        return {}
    end

    local windows = app:allWindows()
    if #windows == 0 then
        return {}
    end

    -- Activate and unhide the app
    app:activate(true)
    app:unhide()

    -- Unminimize all windows
    for _, win in ipairs(windows) do
        if win:isMinimized() then
            win:unminimize()
        end
    end

    return windows
end

-- Layout configuration for external display (4-split)
local function layoutExternalDisplay()
    local externalScreen = getExternalScreen()
    if not externalScreen then
        return
    end

    local frame = externalScreen:frame()

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

    -- Apply layouts to all windows
    for appName, rect in pairs(layouts) do
        local app = hs.application.get(appName)
        if app then
            local windows = getAppWindows(app)
            for _, window in ipairs(windows) do
                window:setFrame(rect, 0)
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

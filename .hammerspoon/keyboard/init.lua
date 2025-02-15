--------------------------------------------------------------------------------
-- rtoshiro - https://github.com/rtoshiro
-- You should see: http://www.hammerspoon.org/docs/index.html
--------------------------------------------------------------------------------

function secondMonitor()
  local sec_monitor = ""
  -- hs.alert.show(main_monitor)
  for _, monitor in ipairs(hs.screen.allScreens()) do
--	hs.alert.show(monitor:name())
    if not (monitor:name() == main_monitor) then
      sec_monitor = monitor:name()
    end
  end
  return sec_monitor
  -- hs.alert.show(sec_monitor)
end


--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
local ctrl_alt = {"ctrl", "alt"}
local ctrl_cmd = {"ctrl", "cmd"}
local main_monitor = "Built-in Retina Display"
local second_monitor = secondMonitor()
local space = 1

--------------------------------------------------------------------------------
-- CONFIGURATIONS
--------------------------------------------------------------------------------
hs.window.animationDuration = 0

--------------------------------------------------------------------------------
-- LAYOUTS
-- SINTAX:
--  {
--    name = "App name" ou { "App name", "App name" }
--    func = function(index, win)
--      COMMANDS
--    end
--  },
--
-- It searches for application "name" and call "func" for each window object
--------------------------------------------------------------------------------
local layouts = {
  {
    name = {"Google Chrome"},
    func = function(index, win)
      if (#hs.screen.allScreens() > 1) then
        if( space == 1 ) then
          win:moveToScreen(hs.screen.get(second_monitor))
		  hs.window.right(win)
        else  -- second space
          win:moveToScreen(hs.screen.get(second_monitor))
          if( index%2 == 0 ) then
            hs.window.left(win)
          else
            hs.window.right(win)
          end
        end
      else
        if( space == 2 ) then
          if( index%2 == 0 ) then
            hs.window.left(win)
          else
            hs.window.right(win)
          end
		else
			win:maximize()
		end
      end
    end
  },
  {
    name = { "ghostty"},
    func = function(index, win)
      if (#hs.screen.allScreens() > 1) then
        win:moveToScreen(hs.screen.get(second_monitor))
        hs.window.left(win)
      else
        win:maximize()
      end
    end
  },
  {
    name = {"IntelliJ IDEA"},
    func = function(index, win)
      if (#hs.screen.allScreens() > 1) then
        win:moveToScreen(hs.screen.get(main_monitor))
        win:maximize()
      else
        win:maximize()
      end
    end
  },
  {
    name = { "thinkorswim"},
    func = function(index, win)
      win:moveToScreen(hs.screen.get(main_monitor))
      win:maximize()
    end
  },
  {
    name = "Finder",
    func = function(index, win)

      if (index == 1) then
        if (#hs.screen.allScreens() > 1) then
          win:moveToScreen(hs.screen.get(second_monitor))
        end

        hs.window.upLeft(win)
      elseif (index == 2) then
        if (#hs.screen.allScreens() > 1) then
          win:moveToScreen(hs.screen.get(second_monitor))
        end

        hs.window.downLeft(win)
      elseif (index == 3) then
        if (#hs.screen.allScreens() > 1) then
          win:moveToScreen(hs.screen.get(second_monitor))
        end

        hs.window.downRight(win)
      elseif (index == 4) then
        if (#hs.screen.allScreens() > 1) then
          win:moveToScreen(hs.screen.get(second_monitor))
        end

        hs.window.upRight(win)
      elseif (index == 5) then
        win:moveToScreen(hs.screen.get(main_monitor))

        hs.window.upLeft(win)
      elseif (index == 6) then
        win:moveToScreen(hs.screen.get(main_monitor))

        hs.window.downLeft(win)
      elseif (index == 7) then
        win:moveToScreen(hs.screen.get(main_monitor))

        hs.window.downRight(win)
      elseif (index == 8) then
        win:moveToScreen(hs.screen.get(main_monitor))

        hs.window.upRight(win)
      else
        win:close()
      end
    end
  },
  {
    name = {"player"},
    func = function(index, win)
      if (#hs.screen.allScreens() > 1) then
        win:moveToScreen(hs.screen.get(second_monitor))
      end
      local minFrame = hs.screen.minFrame(win:screen(), false)
      local screen = win:screen()
      local screen_frame = screen:frame()
      local frame = win:frame()
      if (index % 3 == 0) then
        frame.x = screen_frame.w - 200
        frame.y = (math.floor(index / 3) - 1) * (screen_frame.h / 2)
        frame.w = 260
        frame.h = screen_frame.h / 2
      end


      win:setFrame(frame)
    end
  },
}

local closeAll = {
  "Genymotion"
}

local openAll = {
  "ghostty",
  "IntelliJ IDEA",
  "Google Chrome",
}

newWindowWatcher = {
  "Sequel Pro",
  "SourceTree",
}

function config()
  hs.hotkey.bind(ctrl_cmd, "l", function()
    local win = hs.window.focusedWindow()
    hs.window.right(win)
  end)

  hs.hotkey.bind(ctrl_cmd, "h", function()
    local win = hs.window.focusedWindow()
    hs.window.left(win)
  end)

  --[[hs.hotkey.bind(ctrl_cmd, "k", function()
    local win = hs.window.focusedWindow()
    hs.window.up(win)
  end)

  hs.hotkey.bind(ctrl_cmd, "j", function()
    local win = hs.window.focusedWindow()
    hs.window.down(win)
  end)
  hs.hotkey.bind(ctrl_alt, "h", function()
    local win = hs.window.focusedWindow()
    hs.window.upLeft(win)
  end)

  hs.hotkey.bind(ctrl_alt, "j", function()
    local win = hs.window.focusedWindow()
    hs.window.downLeft(win)
  end)

  hs.hotkey.bind(ctrl_alt, "l", function()
    local win = hs.window.focusedWindow()
    hs.window.downRight(win)
  end)

  hs.hotkey.bind(ctrl_alt, "k", function()
    local win = hs.window.focusedWindow()
    hs.window.upRight(win)
  end)]]--

  hs.hotkey.bind(ctrl_cmd, "m", function()
    local win = hs.window.focusedWindow()
    win:maximize()
    --hs.window.maximize(win)
  end)

--[[
  hs.hotkey.bind(ctrl_cmd, "f", function()
    local win = hs.window.focusedWindow()
    if (win) then
      hs.window.fullscreenWidth(win)
    end
  end)

  hs.hotkey.bind(ctrl_cmd, "h", function()
    hs.hints.windowHints()
  end)]]--

  hs.hotkey.bind(ctrl_cmd, "k", function()
    local win = hs.window.focusedWindow()
    if (win) then
      win:moveToScreen(hs.screen.get(second_monitor))
    end
  end)

  hs.hotkey.bind(ctrl_cmd, "j", function()
    local win = hs.window.focusedWindow()
    if (win) then
      win:moveToScreen(hs.screen.get(main_monitor))
      --win:maximize()
    end
  end)

  hs.hotkey.bind(ctrl_cmd, "R", function()
    hs.reload()
    hs.alert.show("Config loaded")
--
--local win = hs.window.focusedWindow()
--    local app = win:application()
--
--          hs.alert.show(app:title())
--          
  end)

  --[[
  hs.hotkey.bind(ctrl_cmd, "P", function()
    hs.alert.show("Closing")
    for i,v in ipairs(closeAll) do
      local app = hs.application(v)
      if (app) then
        if (app.name) then
          hs.alert.show(app:name())
        end
        if (app.kill) then
        app:kill()
      end
      end
    end
  end)

  hs.hotkey.bind(ctrl_cmd, "2", function()
    hs.alert.show("Openning")
    for i,v in ipairs(openAll) do
      hs.alert.show(v)
      hs.application.open(v)
    end
  end)
  ]]--

  hs.hotkey.bind(ctrl_cmd, "1", function()
    space = 1
    applyLayouts(layouts)
    space = 0
  end)

  hs.hotkey.bind(ctrl_cmd, "2", function()
    space = 2
    applyLayouts(layouts)
    space = 0
  end)

  hs.hotkey.bind(ctrl_cmd, "0", function()
    local focusedWindow = hs.window.focusedWindow()
    local app = focusedWindow:application()
    if (app) then
      applyLayout(layouts, app)
    end
  end)
end
--------------------------------------------------------------------------------
-- END CONFIGURATIONS
--------------------------------------------------------------------------------










--------------------------------------------------------------------------------
-- METHODS - BECAREFUL :)
--------------------------------------------------------------------------------
function applyLayout(layouts, app)
  if (app) then
    local appName = app:title()

    for i, layout in ipairs(layouts) do
      if (type(layout.name) == "table") then
        for i, layAppName in ipairs(layout.name) do
          if (layAppName == appName) then
            hs.alert.show(appName)
          
            local wins = app:allWindows()
            local counter = 1
            for j, win in ipairs(wins) do
              if (win:isVisible() and layout.func) then
                layout.func(counter, win)
                counter = counter + 1
              end
            end
          end
        end
      elseif (type(layout.name) == "string") then
        if (layout.name == appName) then
          local wins = app:allWindows()
          local counter = 1
          for j, win in ipairs(wins) do
            if (win:isVisible() and layout.func) then
              layout.func(counter, win)
              counter = counter + 1
            end
          end
        end
      end
    end
  end
end

function applyLayouts(layouts)
  for i, layout in ipairs(layouts) do
    if (type(layout.name) == "table") then
      for i, appName in ipairs(layout.name) do
--        local app = hs.appfinder.appFromName(appName)
        local app = hs.application.find(appName)
--      hs.alert.show(app:title())
        if (app) then
          local wins = app:allWindows()
          local counter = 1
          for j, win in ipairs(wins) do
            if (win:isVisible() and layout.func) then
              layout.func(counter, win)
              counter = counter + 1
            end
          end
        end
      end
    elseif (type(layout.name) == "string") then
      local app = hs.appfinder.appFromName(layout.name)
      if (app) then
        local wins = app:allWindows()
        local counter = 1
        for j, win in ipairs(wins) do
          if (win:isVisible() and layout.func) then
            layout.func(counter, win)
            counter = counter + 1
          end
        end
      end
    end
  end
end

function hs.screen.get(screen_name)
  local allScreens = hs.screen.allScreens()
  for i, screen in ipairs(allScreens) do
    if screen:name() == screen_name then
      return screen
    end
  end
end

-- Returns the width of the smaller screen size
-- isFullscreen = false removes the toolbar
-- and dock sizes
function hs.screen.minWidth(isFullscreen)
  local min_width = math.maxinteger
  local allScreens = hs.screen.allScreens()
  for i, screen in ipairs(allScreens) do
    local screen_frame = screen:frame()
    if (isFullscreen) then
      screen_frame = screen:fullFrame()
    end
    min_width = math.min(min_width, screen_frame.w)
  end
  return min_width
end

-- isFullscreen = false removes the toolbar
-- and dock sizes
-- Returns the height of the smaller screen size
function hs.screen.minHeight(isFullscreen)
  local min_height = math.maxinteger
  local allScreens = hs.screen.allScreens()
  for i, screen in ipairs(allScreens) do
    local screen_frame = screen:frame()
    if (isFullscreen) then
      screen_frame = screen:fullFrame()
    end
    min_height = math.min(min_height, screen_frame.h)
  end
  return min_height
end

-- If you are using more than one monitor, returns X
-- considering the reference screen minus smaller screen
-- = (MAX_REFSCREEN_WIDTH - MIN_AVAILABLE_WIDTH) / 2
-- If using only one monitor, returns the X of ref screen
function hs.screen.minX(refScreen)
  local min_x = refScreen:frame().x
  local allScreens = hs.screen.allScreens()
  if (#allScreens > 1) then
    min_x = refScreen:frame().x + ((refScreen:frame().w - hs.screen.minWidth()) / 2)
  end
  return min_x
end

-- If you are using more than one monitor, returns Y
-- considering the focused screen minus smaller screen
-- = (MAX_REFSCREEN_HEIGHT - MIN_AVAILABLE_HEIGHT) / 2
-- If using only one monitor, returns the Y of focused screen
function hs.screen.minY(refScreen)
  local min_y = refScreen:frame().y
  local allScreens = hs.screen.allScreens()
  if (#allScreens > 1) then
    min_y = refScreen:frame().y + ((refScreen:frame().h - hs.screen.minHeight()) / 2)
  end
  return min_y
end

-- If you are using more than one monitor, returns the
-- half of minX and 0
-- = ((MAX_REFSCREEN_WIDTH - MIN_AVAILABLE_WIDTH) / 2) / 2
-- If using only one monitor, returns the X of ref screen
function hs.screen.almostMinX(refScreen)
  local min_x = refScreen:frame().x
  local allScreens = hs.screen.allScreens()
  if (#allScreens > 1) then
    min_x = refScreen:frame().x + (((refScreen:frame().w - hs.screen.minWidth()) / 2) - ((refScreen:frame().w - hs.screen.minWidth()) / 4))
  end
  return min_x
end

-- If you are using more than one monitor, returns the
-- half of minY and 0
-- = ((MAX_REFSCREEN_HEIGHT - MIN_AVAILABLE_HEIGHT) / 2) / 2
-- If using only one monitor, returns the Y of ref screen
function hs.screen.almostMinY(refScreen)
  local min_y = refScreen:frame().y
  local allScreens = hs.screen.allScreens()
  if (#allScreens > 1) then
    min_y = refScreen:frame().y + (((refScreen:frame().h - hs.screen.minHeight()) / 2) - ((refScreen:frame().h - hs.screen.minHeight()) / 4))
  end
  return min_y
end

-- Returns the frame of the smaller available screen
-- considering the context of refScreen
-- isFullscreen = false removes the toolbar
-- and dock sizes
function hs.screen.minFrame(refScreen, isFullscreen)
  --local result = {
  --  x = hs.screen.minX(refScreen),
  --  y = hs.screen.minY(refScreen),
   -- w = hs.screen.minWidth(isFullscreen),
    --h = hs.screen.minHeight(isFullscreen)
  --}
  local result = {
    x = refScreen:frame().x,
    y = refScreen:frame().y,
    w = refScreen:frame().w,
    h = refScreen:frame().h
  }
  return result
end

-- +-----------------+
-- |        |        |
-- |        |  HERE  |
-- |        |        |
-- +-----------------+
function hs.window.right(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  minFrame.x = minFrame.x + (minFrame.w/2)
  minFrame.w = minFrame.w/2
  win:setFrame(minFrame)
end

-- +-----------------+
-- |        |        |
-- |  HERE  |        |
-- |        |        |
-- +-----------------+
function hs.window.left(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  minFrame.w = minFrame.w/2
  win:setFrame(minFrame)
end

-- +-----------------+
-- |      HERE       |
-- +-----------------+
-- |                 |
-- +-----------------+
function hs.window.up(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  minFrame.h = minFrame.h/2
  win:setFrame(minFrame)
end

-- +-----------------+
-- |                 |
-- +-----------------+
-- |      HERE       |
-- +-----------------+
function hs.window.down(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  minFrame.y = minFrame.y + minFrame.h/2
  minFrame.h = minFrame.h/2
  win:setFrame(minFrame)
end

-- +-----------------+
-- |  HERE  |        |
-- +--------+        |
-- |                 |
-- +-----------------+
function hs.window.upLeft(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  minFrame.w = minFrame.w/2
  minFrame.h = minFrame.h/2
  win:setFrame(minFrame)
end

-- +-----------------+
-- |                 |
-- +--------+        |
-- |  HERE  |        |
-- +-----------------+
function hs.window.downLeft(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  win:setFrame({
    x = minFrame.x,
    y = minFrame.y + minFrame.h/2,
    w = minFrame.w/2,
    h = minFrame.h/2
  })
end

-- +-----------------+
-- |                 |
-- |        +--------|
-- |        |  HERE  |
-- +-----------------+
function hs.window.downRight(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  win:setFrame({
    x = minFrame.x + minFrame.w/2,
    y = minFrame.y + minFrame.h/2,
    w = minFrame.w/2,
    h = minFrame.h/2
  })
end

-- +-----------------+
-- |        |  HERE  |
-- |        +--------|
-- |                 |
-- +-----------------+
function hs.window.upRight(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  win:setFrame({
    x = minFrame.x + minFrame.w/2,
    y = minFrame.y,
    w = minFrame.w/2,
    h = minFrame.h/2
  })
end

-- +------------------+
-- |                  |
-- |    +--------+    +--> minY
-- |    |  HERE  |    |
-- |    +--------+    |
-- |                  |
-- +------------------+
-- Where the window's size is equal to
-- the smaller available screen size
function hs.window.fullscreenCenter(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  win:setFrame(minFrame)
end

-- +------------------+
-- |                  |
-- |  +------------+  +--> minY
-- |  |    HERE    |  |
-- |  +------------+  |
-- |                  |
-- +------------------+
function hs.window.fullscreenAlmostCenter(win)
  local offsetW = hs.screen.minX(win:screen()) - hs.screen.almostMinX(win:screen())
  win:setFrame({
    x = hs.screen.almostMinX(win:screen()),
    y = hs.screen.minY(win:screen()),
    w = hs.screen.minWidth(isFullscreen) + (2 * offsetW),
    h = hs.screen.minHeight(isFullscreen)
  })
end

-- It like fullscreen but with minY and minHeight values
-- +------------------+
-- |                  |
-- +------------------+--> minY
-- |       HERE       |
-- +------------------+--> minHeight
-- |                  |
-- +------------------+
function hs.window.fullscreenWidth(win)
  local minFrame = hs.screen.minFrame(win:screen(), false)
  win:setFrame({
    x = win:screen():frame().x,
    y = minFrame.y,
    w = win:screen():frame().w,
    h = minFrame.h
  })
end

windowWatcher = {}

function windowWatcherListener(element, event, watcher, userData) 
  local appName = userData.name
  local app = hs.application.find(appName)
  if (app) then
    applyLayout(layouts, app)
  end
end


function applicationWatcher(appName, eventType, appObject)
  if (eventType == hs.application.watcher.activated) then
    if (appName == "ghostty") then
      appObject:selectMenuItem({"Window", "Bring All to Front"})
    elseif (appName == "Finder") then
      appObject:selectMenuItem({"Window", "Bring All to Front"})
    end
  end

  if (eventType == hs.application.watcher.launched) then
    os.execute("sleep " .. tonumber(1))
    applyLayout(layouts, appObject)
    
    for i, aname in ipairs(newWindowWatcher) do
      if (appName == aname) then      
        if (not windowWatcher[aname]) then
          hs.alert.show("Watching " .. appName)
          windowWatcher[aname] = appObject:newWatcher(windowWatcherListener, { name = appName })
          windowWatcher[aname]:start({hs.uielement.watcher.windowCreated})
        end
      end
    end
  end
  
  if (eventType == hs.application.watcher.terminated) then  
    for i, aname in ipairs(newWindowWatcher) do
      if (appName == aname) then      
        if (windowWatcher[aname]) then
          hs.alert.show("Stop watching " .. appName)
          windowWatcher[aname]:stop()
          windowWatcher[aname] = nil
        end
      end
    end
  end
end


--require('keyboard.panes')
config()
--appWatcher = hs.application.watcher.new(applicationWatcher)
--appWatcher:start()

secondMonitor()


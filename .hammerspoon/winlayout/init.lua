local inspect = require("hs.inspect")
local log = hs.logger.new('init.lua', 'debug')

local focused = hs.window.focusedWindow()

local spaceOneLayout = {
	{"IntelliJ IDEA", nil, focused:screen(), hs.layout.right50, nil, nil },
	{"iTerm2", nil, focused:screen(), hs.layout.left50, nil, nil },
	{"Google Chrome", nil, hs.screen.primaryScreen(), hs.layout.maximized, nil, nil },
}
log:d( "%s", inspect( hs.screen.allScreens() ) )

local menu = hs.menubar.new()
local function setSpaceOneLayout()
  menu:setTitle("🖥1")
  menu:setTooltip("Single Screen Layout")
  log.debug(spaceOneLayout)
  hs.layout.apply(spaceOneLayout)
end

local function setSpaceTwoLayout()
  menu:setTitle("🖥2")
  menu:setTooltip("Triple Screen Layout")
  hs.layout.apply(spaceOneLayout)
end

local function enableMenu()
  menu:setTitle("🖥")
  menu:setTooltip("No Layout")
  menu:setMenu({
      { title = "Set space 1 layout", fn = setSpaceOneLayout },
      { title = "Set space 2 layout", fn = setSpaceTwoLayout },
  })
end

enableMenu()
-- hs.
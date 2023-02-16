--[[hs.hotkey.bind({"cmd", "alt", "ctrl"}, "W", function()
  hs.alert.show("Hello World!")
end)]]--

--[[hs.loadSpoon('Ki')                 -- initialize the plugin
spoon.Ki.workflowEvents = {...}    -- configure `spoon.Ki` here
spoon.Ki:start()                   -- enable keyboard shortcuts
]]--

--[[customBindings = {
	enlarge = {
		{{"ctrl", "alt", "shift"}, "up"},
	},
	shrink = {
		{{"ctrl", "alt", "shift"}, "down"},
	}
}]]--

--hs.loadSpoon( 'Lunette' )
--spoon.Lunette:bindHotkeys()
--hs.alert.show( spoon.Lunette:bindHotKeys() )
require('keyboard') -- Load Hammerspoon bits from https://github.com/jasonrudolph/keyboard

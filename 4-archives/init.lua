-- Load Extensions
local application = require "mjolnir.application"
local window      = require "mjolnir.window"
local hotkey      = require "mjolnir.hotkey"
local fnutils     = require "mjolnir.fnutils"
local alert       = require "mjolnir.alert"
local grid        = require "mjolnir.bg.grid"
local tiling	  = require "mjolnir.tiling"

-- Music controls
local spotify     = require "mjolnir.lb.spotify"
local audiodevice = require "mjolnir._asm.sys.audiodevice"
-- Sound and Notifications
local sound = require "mjolnir._asm.ui.sound"
local alert_sound = sound.get_byfile("alert.wav")
local tink_sound  = sound.get_byname("Tink") -- Not actually used, just as a nice example.
                                             -- More sounds in /System/Library/Sounds

-- Set up hotkey combinations
local mash      = {"cmd", "alt", "ctrl"}
local mashshift = {"cmd", "alt", "shift"}
-- Set grid size.
grid.GRIDWIDTH  = 12
grid.GRIDHEIGHT = 12
grid.MARGINX    = 0
grid.MARGINY    = 0

local function opendictionary()
  alert.show("Lexicon, at your service.", 0.75)
  application.launchorfocus("Dictionary")
end

local function incvert(win, inc)
	local winframe = win:frame()
	local scrframe = win:screen():frame()

	if inc == 1 then
		winframe.h = winframe.h*2
		winframe.y = winframe.y/2
	else
		winframe.h = winframe.h/2
		winframe.y = winframe.y*2
	end

    win:setframe(winframe)
end

local function inchorz(win, inc)
	local winframe = win:frame()
	local scrframe = win:screen():frame()
	local xinc = (winframe.x-scrframe.x)/2
	if xinc < 10 then
		xinc = 10
	end

	if inc == 1 then
		winframe.w = winframe.w+xinc
		winframe.x = winframe.x-xinc/2
	else
		winframe.w = winframe.w-xinc
		winframe.x = winframe.x+xinc/2
	end

    win:setframe(winframe)
end

local function movhorz(win, inc)
	local winframe = win:frame()
	local scrframe = win:screen():frame()

	if inc == 1 then
		if winframe.x < scrframe.x then
			winframe.x = scrframe.x
		else
			winframe.x = winframe.x + scrframe.w/3
		end
	else
		if winframe.x > scrframe.x then
			winframe.x = winframe.x-scrframe.w/3
		end
		if winframe.x < scrframe.x then
			winframe.x = scrframe.x
		end
	end

    win:setframe(winframe)
end


hotkey.bind(mash, 'D', opendictionary)

hotkey.bind(mash, ';', function() grid.snap(window.focusedwindow()) end)
hotkey.bind(mash, "'", function() fnutils.map(window.visiblewindows(), grid.snap) end)

hotkey.bind(mash,      '=', function() grid.adjustwidth(1) end)
hotkey.bind(mash,      '-', function() grid.adjustwidth(-1) end)
hotkey.bind(mashshift, '=', function() grid.adjustheight(1) end)
hotkey.bind(mashshift, '-', function() grid.adjustheight(-1) end)

hotkey.bind(mash, 'left',  function() inchorz( window.focusedwindow(), -1) end)
hotkey.bind(mash, 'right', function() inchorz( window.focusedwindow(), 1) end)
hotkey.bind(mash, "up", function() incvert( window.focusedwindow(), 1 ) end )
hotkey.bind(mash, 'down',    function() incvert( window.focusedwindow(), -1 ) end)

hotkey.bind(mashshift, 'left',  function() movhorz( window.focusedwindow(), -1) end)
hotkey.bind(mashshift, 'right', function() movhorz( window.focusedwindow(), 1) end)

hotkey.bind(mash,      'M', grid.maximize_window)
hotkey.bind(mashshift, 'M', function() window.focusedwindow():minimize() end)

hotkey.bind(mash,      'F', function() window.focusedwindow():setfullscreen(true) end)
hotkey.bind(mashshift, 'F', function() window.focusedwindow():setfullscreen(false) end)

hotkey.bind(mash, 'N', grid.pushwindow_nextscreen)
hotkey.bind(mash, 'P', grid.pushwindow_prevscreen)

hotkey.bind(mash, 'J', grid.pushwindow_down)
hotkey.bind(mash, 'K', grid.pushwindow_up)
hotkey.bind(mash, 'H', grid.pushwindow_left)
hotkey.bind(mash, 'L', grid.pushwindow_right)

hotkey.bind(mash, 'U', grid.resizewindow_taller)
hotkey.bind(mash, 'O', grid.resizewindow_wider)
hotkey.bind(mash, 'I', grid.resizewindow_thinner)
hotkey.bind(mash, 'Y', grid.resizewindow_shorter)

hotkey.bind(mashshift, 'space', spotify.displayCurrentTrack)
hotkey.bind(mashshift, 'P',     spotify.play)
hotkey.bind(mashshift, 'O',     spotify.pause)
hotkey.bind(mashshift, 'N',     spotify.next)
hotkey.bind(mashshift, 'I',     spotify.previous)

hotkey.bind(mashshift, 'T', function() alert.show(os.date("%A %b %d, %Y - %I:%M%p"), 4) end)

hotkey.bind(mashshift, ']', function() audiodevice.defaultoutputdevice():setvolume(audiodevice.current().volume + 5) end)
hotkey.bind(mashshift, '[', function() audiodevice.defaultoutputdevice():setvolume(audiodevice.current().volume - 5) end)

--alert_sound:play()
alert.show("Mjolnir, at your service.", 3)


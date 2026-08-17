local spaces = require('hs.spaces')

local function alert(message)
  hs.alert.show(message)
end

local function moveFocusedWindow(step)
  local window = hs.window.focusedWindow()
  if not window or not window:isStandard() or window:isFullScreen() then
    alert('Focus a normal, non-full-screen window')
    return
  end

  local orderedSpaces, spacesError = spaces.spacesForScreen(window:screen())
  if not orderedSpaces then
    alert(spacesError or 'Could not list desktops')
    return
  end

  local windowSpaces, windowSpacesError = spaces.windowSpaces(window)
  if not windowSpaces or #windowSpaces == 0 then
    alert(windowSpacesError or 'Could not identify the window desktop')
    return
  end

  local currentSpace = windowSpaces[1]
  local currentIndex

  for index, spaceID in ipairs(orderedSpaces) do
    if spaceID == currentSpace then
      currentIndex = index
      break
    end
  end

  if not currentIndex then
    alert('Could not identify the current desktop')
    return
  end

  local targetIndex = currentIndex + step
  while orderedSpaces[targetIndex]
      and spaces.spaceType(orderedSpaces[targetIndex]) ~= 'user' do
    targetIndex = targetIndex + step
  end

  if not orderedSpaces[targetIndex] then
    alert('No desktop in that direction')
    return
  end

  local zoomButtonRect = window:zoomButtonRect()
  if not zoomButtonRect then
    alert('Could not locate the window title bar')
    return
  end

  local cursorPosition = hs.mouse.getRelativePosition()
  local dragPoint = hs.geometry(zoomButtonRect):move({-1, -1}).topleft
  local direction = step < 0 and 'left' or 'right'
  local transitions = math.abs(targetIndex - currentIndex)
  local released = false
  local moveWaiter
  local moveTimeout

  local function releaseMouse(message)
    if released then return end
    released = true

    if moveWaiter and moveWaiter:running() then moveWaiter:stop() end
    if moveTimeout and moveTimeout:running() then moveTimeout:stop() end

    hs.eventtap.event.newMouseEvent(
      hs.eventtap.event.types.leftMouseUp,
      dragPoint
    ):post()
    hs.mouse.setRelativePosition(cursorPosition)

    if message then alert(message) end
  end

  hs.eventtap.event.newMouseEvent(
    hs.eventtap.event.types.leftMouseDown,
    dragPoint
  ):post()

  for _ = 1, transitions do
    hs.eventtap.keyStroke({'ctrl', 'fn'}, direction, 0)
  end

  moveWaiter = hs.timer.waitUntil(function()
    local updatedSpaces = spaces.windowSpaces(window)
    return updatedSpaces and updatedSpaces[1] ~= currentSpace
  end, function()
    releaseMouse()
  end, 0.05)

  moveTimeout = hs.timer.doAfter(2, function()
    releaseMouse('Desktop move timed out')
  end)
end

local modifiers = {'ctrl', 'alt', 'cmd'}

hs.hotkey.bind(modifiers, 'left', function()
  moveFocusedWindow(-1)
end)

hs.hotkey.bind(modifiers, 'right', function()
  moveFocusedWindow(1)
end)

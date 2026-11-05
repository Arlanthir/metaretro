local input = {}

local KEYS = {
  up = "up", down = "down", left = "left", right = "right",
  z = "a", ["return"] = "a", x = "b", escape = "b", backspace = "b",
  a = "x", s = "y", q = "l", w = "r",
  space = "start", tab = "select",
}

local BUTTONS = {
  dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
  a = "a", b = "b", x = "x", y = "y",
  leftshoulder = "l", rightshoulder = "r",
  start = "start", back = "select",
}

-- SDL names face buttons by position (Xbox layout); Nintendo-style devices print A/B and X/Y swapped.
local NINTENDO_BUTTONS = { a = "b", b = "a", x = "y", y = "x" }

local REPEATABLE = { up = true, down = true, left = true, right = true }
local REPEAT_DELAY = 0.35
local REPEAT_INTERVAL = 0.08

local held = {}
local down = {}
local handler = function() end
local clock = love and love.timer and love.timer.getTime or os.clock
local ignoreUntil = 0

function input.setHandler(fn)
  handler = fn
end

-- Drops presses for a while, e.g. ones queued while the app was blocked loading.
function input.ignoreFor(seconds)
  held = {}
  down = {}
  ignoreUntil = clock() + seconds
end

-- Stops held directions from repeating until they're pressed again; they still count as held.
function input.stopRepeats()
  held = {}
end

function input.setNintendoLayout(enabled)
  for button, action in pairs(NINTENDO_BUTTONS) do
    BUTTONS[button] = enabled and action or button
  end
end

local function press(action)
  if not action or clock() < ignoreUntil then return end
  down[action] = true
  if REPEATABLE[action] then
    held[action] = REPEAT_DELAY
  end
  handler(action)
end

local function release(action)
  if action then
    held[action] = nil
    down[action] = nil
  end
end

function input.isDown(action)
  return down[action] == true
end

function input.keypressed(key) press(KEYS[key]) end
function input.keyreleased(key) release(KEYS[key]) end
function input.gamepadpressed(_, button) press(BUTTONS[button]) end
function input.gamepadreleased(_, button) release(BUTTONS[button]) end

function input.update(dt)
  for action, remaining in pairs(held) do
    remaining = remaining - dt
    if remaining <= 0 then
      remaining = REPEAT_INTERVAL
      handler(action)
    end
    held[action] = remaining
  end
end

return input

-- Base for scenes where the player walks a tile map (the town and Home). The scene has x, y,
-- facing and steps; while a step is under way, `move` is { dx, dy, t, door? }. A step with `door`
-- walks into a doorway while the screen fades out, and leaves the player where they were.
local input = require("core.input")
local ui = require("ui")
local art = require("world.art")
local Confirm = require("scenes.confirm")

local Walker = {}
Walker.__index = Walker

local STEPS_PER_SECOND = 6
-- Walking into a door is slower, while the screen fades out; coming back fades in.
local DOOR_STEP_SPEED = 0.5
local FADE_IN_SECONDS = 0.25
-- Coming back redraws the town, which makes one long frame on the device; counting all of it
-- would finish the fade before it's ever drawn.
local FADE_MAX_STEP = 1 / 30
local TOAST_SECONDS = 4

Walker.DIRECTIONS = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
Walker.DIRECTION_ORDER = { "up", "down", "left", "right" }
Walker.OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

-- Makes `class` a kind of walking scene.
function Walker.extend(class)
  class.__index = class
  return setmetatable(class, Walker)
end

function Walker.heldDirection()
  for _, direction in ipairs(Walker.DIRECTION_ORDER) do
    if input.isDown(direction) then
      return direction
    end
  end
end

function Walker:facingTile()
  local d = Walker.DIRECTIONS[self.facing]
  return self.x + d[1], self.y + d[2]
end

function Walker:startStep(direction, door)
  local d = Walker.DIRECTIONS[direction]
  self.facing = direction
  self.move = { dx = d[1], dy = d[2], t = 0, door = door }
end

-- Fades in, as when coming back through a door.
function Walker:fadeInNow()
  self.fadeIn = 1
end

-- Advances the fade and the step under way. Returns the door step when it ends this frame (the
-- player turns around, back to the room they're leaving), or otherwise the direction to step in
-- next, if any. After a door, waits for the d-pad to be released so the player doesn't walk
-- straight back in.
function Walker:updateWalking(dt)
  if self.fadeIn then
    self.fadeIn = self.fadeIn - math.min(dt, FADE_MAX_STEP) / FADE_IN_SECONDS
    if self.fadeIn <= 0 then self.fadeIn = nil end
  end
  local move = self.move
  if move then
    move.t = move.t + dt * STEPS_PER_SECOND * (move.door and DOOR_STEP_SPEED or 1)
    if move.t < 1 then return end
    self.move = nil
    self.steps = self.steps + 1
    if move.door then
      self.facing = Walker.OPPOSITE[self.facing]
      self.waitForRelease = true
      return move
    end
    self.x, self.y = self.x + move.dx, self.y + move.dy
  end
  local direction = Walker.heldDirection()
  if self.waitForRelease then
    self.waitForRelease = direction ~= nil
    return
  end
  return nil, direction
end

function Walker:playerPixels()
  local move = self.move or { dx = 0, dy = 0, t = 0 }
  return (self.x - 1 + move.dx * move.t) * art.TILE, (self.y - 1 + move.dy * move.t) * art.TILE
end

function Walker:walkFrame()
  return self.move and self.steps * 2 + math.floor(self.move.t * 2) or 0
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

-- The view's top-left pixel on a `width` x `height` tile map: following the player, or centered
-- when the map fits on screen.
function Walker:camera(width, height)
  local px, py = self:playerPixels()
  local function axis(player, size, screen)
    if size <= screen then return -math.floor((screen - size) / 2) end
    return clamp(math.floor(player + art.TILE / 2 - screen / 2), 0, size - screen)
  end
  return axis(px, width * art.TILE, ui.WIDTH), axis(py, height * art.TILE, ui.HEIGHT)
end

function Walker:drawFade()
  local fade = self.move and self.move.door and self.move.t or self.fadeIn
  if fade then
    love.graphics.setColor(0, 0, 0, math.min(1, fade))
    love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEIGHT)
    love.graphics.setColor(1, 1, 1)
  end
end

-- Picks up the app's latest announcement (see app:announce) and counts down the one on show.
function Walker:updateToast(dt)
  local app = self.app
  if app.announcement then
    self.toast, self.toastTime = app.announcement, TOAST_SECONDS
    app.announcement = nil
  end
  if self.toast then
    self.toastTime = self.toastTime - dt
    if self.toastTime <= 0 then self.toast = nil end
  end
end

-- The wallet, with the announcement on show under it.
function Walker:drawStatus()
  ui.walletPanel(self.app.state.wallet)
  if self.toast then
    ui.messagePanel(self.toast, ui.WIDTH / 2, 48, "coin")
  end
end

function Walker:confirmQuit()
  Confirm.quit()
end

return Walker

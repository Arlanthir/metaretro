-- Base for scenes inside a building (see world/interior.lua): walking around the furniture and the
-- people standing there, and the front door back to town. Kinds of interior (Home, Museum) say
-- what the player can do there through these methods:
--   interact(piece, person)  A on the furniture piece or person faced
--   hintFor(piece, person)   the hint shown while facing them, or nil
--   live(piece)              drawn every frame instead of once, for pieces that come and go
--   absent(piece)            not there right now (not drawn, and free to walk on)
--   drawLive(piece, px, py)  draws a live piece (by default, as its furniture sprite)
--   drawOnTop(camX, camY)    anything else to draw over the furniture
-- People are { x, y, facing, look = { name, sprite } }; they stand still and face whoever talks to them.
-- `place` names the building, for the hint at the door.
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local interior = require("world.interior")
local Walker = require("scenes.walker")

local Interior = Walker.extend({})

local canvases = {} -- map -> Canvas: buildings never change, so each is drawn once

local function render(map, live)
  local tile = art.TILE
  local canvas = love.graphics.newCanvas(map.width * tile, map.height * tile)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(art.OUTSIDE_COLOR)
  love.graphics.setColor(1, 1, 1)
  for y = 1, map.height do
    for x = 1, map.width do
      local px, py = (x - 1) * tile, (y - 1) * tile
      local floor, wall = interior.floor(map, x, y), interior.wallPiece(map, x, y)
      if floor then art.floor(floor, x, y, px, py) end
      if wall then art.wall(wall, px, py) end
    end
  end
  for _, piece in ipairs(map.furniture) do
    if not live(piece) then art.furniture(piece.kind, (piece.x - 1) * tile, (piece.y - 1) * tile) end
  end
  love.graphics.setCanvas()
  return canvas
end

-- A new `class` scene in `map`, with the player at `spot` (the front door by default), fading in.
function Interior.new(class, app, map, spot, facing)
  spot = spot or map.start
  return setmetatable({ app = app, map = map, x = spot.x, y = spot.y, facing = facing or "up", steps = 0,
    fadeIn = 1, people = {} }, class)
end

function Interior:interact() end
function Interior:hintFor() end
function Interior:live() return false end
function Interior:absent() return false end
function Interior:drawOnTop() end

function Interior:drawLive(piece, px, py)
  art.furniture(piece.kind, px, py)
end

function Interior:enter()
  canvases[self.map] = canvases[self.map] or render(self.map, function(piece) return self:live(piece) end)
end

function Interior:personAt(x, y)
  for _, person in ipairs(self.people) do
    if person.x == x and person.y == y then return person end
  end
end

-- The furniture piece and person the player faces (either may be nil).
function Interior:facingThings()
  local x, y = self:facingTile()
  local piece = interior.furnitureAt(self.map, x, y)
  if piece and self:absent(piece) then piece = nil end
  return piece, self:personAt(x, y)
end

function Interior:facingExit()
  local x, y = self:facingTile()
  local exit = self.map.exit
  return self.facing == "down" and x == exit.x and y == exit.y
end

function Interior:step(direction)
  self.facing = direction
  local x, y = self:facingTile()
  if self:facingExit() then
    self:startStep("down", self.map.exit) -- back to town once the step ends
  elseif interior.isWalkable(self.map, x, y, function(piece) return self:absent(piece) end)
    and not self:personAt(x, y) then
    self:startStep(direction)
  end
end

function Interior:update(dt)
  self:updateToast(dt)
  local doorStep, direction = self:updateWalking(dt)
  if doorStep then
    scenes.pop()
  elseif direction then
    self:step(direction)
  end
end

function Interior:action(name)
  if name == "a" and not self.move then
    local piece, person = self:facingThings()
    if person then person.facing = Walker.OPPOSITE[self.facing] end
    if piece or person then self:interact(piece, person) end
  elseif name == "start" then
    self:confirmQuit()
  end
end

function Interior:draw()
  local map = self.map
  local camX, camY = self:camera(map.width, map.height)
  love.graphics.clear(art.OUTSIDE_COLOR)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(canvases[map], -camX, -camY)
  for _, piece in ipairs(map.furniture) do
    if self:live(piece) and not self:absent(piece) then
      self:drawLive(piece, (piece.x - 1) * art.TILE - camX, (piece.y - 1) * art.TILE - camY)
    end
  end
  self:drawOnTop(camX, camY)

  -- Whoever stands lower on screen is drawn in front.
  local px, py = self:playerPixels()
  local characters = { { y = py, draw = function()
    art.player(math.floor(px - camX), math.floor(py - camY), self.facing, self:walkFrame(), self.app.state.player)
  end } }
  for _, person in ipairs(self.people) do
    local x, y = (person.x - 1) * art.TILE, (person.y - 1) * art.TILE
    table.insert(characters, { y = y, draw = function() art.villager(person.look, x - camX, y - camY, person.facing) end })
  end
  table.sort(characters, function(a, b) return a.y < b.y end)
  for _, character in ipairs(characters) do character.draw() end
  self:drawFade()

  self:drawStatus()
  local hint = self:hintFor(self:facingThings()) or self:facingExit() and ("Down: leave %s"):format(self.place)
    or "Start: quit"
  ui.hintPanel(hint, ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Interior

-- Inside Home: the console in the living room opens the collection, and the front door leads
-- back to town.
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local home = require("world.home")
local Collection = require("scenes.collection")
local Walker = require("scenes.walker")

local Home = Walker.extend({})

local map = home.parse(require("world.homemap"))
local canvas -- the house never changes, so it's drawn once

local function render()
  local tile = art.TILE
  canvas = love.graphics.newCanvas(map.width * tile, map.height * tile)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(art.OUTSIDE_COLOR)
  love.graphics.setColor(1, 1, 1)
  for y = 1, map.height do
    for x = 1, map.width do
      local px, py = (x - 1) * tile, (y - 1) * tile
      local floor, wall = home.floor(map, x, y), home.wallPiece(map, x, y)
      if floor then art.floor(floor, x, y, px, py) end
      if wall then art.wall(wall, px, py) end
    end
  end
  for _, piece in ipairs(map.furniture) do
    art.furniture(piece.kind, (piece.x - 1) * tile, (piece.y - 1) * tile)
  end
  love.graphics.setCanvas()
end

function Home.new(app)
  -- In through the front door, fading in.
  return setmetatable({ app = app, x = map.start.x, y = map.start.y, facing = "up", steps = 0, fadeIn = 1 }, Home)
end

function Home:enter()
  if not canvas then render() end
end

function Home:facingConsole()
  local piece = home.furnitureAt(map, self:facingTile())
  return piece and piece.kind == "console"
end

function Home:facingExit()
  local x, y = self:facingTile()
  return self.facing == "down" and x == map.exit.x and y == map.exit.y
end

function Home:step(direction)
  self.facing = direction
  if self:facingExit() then
    self:startStep("down", map.exit) -- back to town once the step ends
  elseif home.isWalkable(map, self:facingTile()) then
    self:startStep(direction)
  end
end

function Home:update(dt)
  self:updateToast(dt)
  local doorStep, direction = self:updateWalking(dt)
  if doorStep then
    scenes.pop()
  elseif direction then
    self:step(direction)
  end
end

function Home:action(name)
  if name == "a" and self:facingConsole() and not self.move then
    scenes.push(Collection.new(self.app))
  elseif name == "start" then
    self:confirmQuit()
  end
end

function Home:draw()
  local camX, camY = self:camera(map.width, map.height)
  love.graphics.clear(art.OUTSIDE_COLOR)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(canvas, -camX, -camY)
  local px, py = self:playerPixels()
  art.player(math.floor(px - camX), math.floor(py - camY), self.facing, self:walkFrame())
  self:drawFade()

  self:drawStatus()
  local hint = self:facingConsole() and "A: play games" or self:facingExit() and "Down: leave Home" or "Start: quit"
  ui.hintPanel(hint, ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Home

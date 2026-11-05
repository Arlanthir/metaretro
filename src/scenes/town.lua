local input = require("core.input")
local log = require("core.log")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local town = require("world.town")
local Collection = require("scenes.collection")
local Confirm = require("scenes.confirm")
local Shop = require("scenes.shop")

local Town = {}
Town.__index = Town

local STEPS_PER_SECOND = 6
-- Walking into a door is slower, while the screen fades out; coming back fades in.
local DOOR_STEP_SPEED = 0.5
local FADE_IN_SECONDS = 0.25
local TOAST_SECONDS = 4
local DIRECTIONS = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}
local DIRECTION_ORDER = { "up", "down", "left", "right" }
local GROUND = { ["="] = "path", ["@"] = "path", ["~"] = "water" }

local function key(x, y)
  return x .. "," .. y
end

function Town.new(app)
  local map = app.town
  return setmetatable({
    app = app, map = map,
    x = map.start.x, y = map.start.y, facing = "down", steps = 0,
    toast = app.earned > 0 and ("+%d coins from play"):format(app.earned) or nil,
    toastTime = TOAST_SECONDS,
  }, Town)
end

function Town:enter()
  self:rebuild()
end

function Town:resume()
  self:rebuild()
  self.waitForRelease = true
  self.fadeIn = 1
end

-- Short text for the building's sign, and the full name used in hints.
function Town:label(building)
  if building.kind == "home" then return "Home", "Home" end
  if building.kind == "dealer" then return "Consoles", "Console Dealer" end
  if building.kind == "store" then return building.store.short, building.store.title end
  return "For sale", "Empty lot"
end

local function groundKind(map, x, y)
  return GROUND[town.tile(map, x, y)] or "grass"
end

-- Re-renders the static town (ground, trees and buildings) into a canvas after anything that changes it.
function Town:rebuild()
  local tile = art.TILE
  local map = self.map
  self.buildings = town.layout(map, self.app.state, self.app.stores)
  self.blocked = town.blockedTiles(self.buildings, art.buildingWidth)
  self.doors = {}
  for _, building in ipairs(self.buildings) do
    self.doors[key(building.door.x, building.door.y)] = building
  end

  -- Trees and buildings draw in row order so nearer ones overlap farther ones.
  local objects = {}
  self.trees = {}
  for y = 1, map.height do
    for x = 1, map.width do
      if town.tile(map, x, y) == "T" then
        self.trees[key(x, y)] = true
        table.insert(objects, { row = y, x = x, tree = true })
      end
    end
  end
  for _, building in ipairs(self.buildings) do
    local left, top = town.footprint(building.door)
    table.insert(objects, { row = top + town.BUILDING_HEIGHT - 1, x = left, building = building, top = top })
  end
  table.sort(objects, function(a, b)
    if a.row ~= b.row then return a.row < b.row end
    return a.x < b.x
  end)

  self.canvas = self.canvas or love.graphics.newCanvas(map.width * tile, map.height * tile)
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear()
  love.graphics.setColor(1, 1, 1)
  for y = 1, map.height do
    for x = 1, map.width do
      local kind = groundKind(map, x, y)
      art.ground(kind, function(nx, ny) return groundKind(map, nx, ny) == kind end, x, y, (x - 1) * tile, (y - 1) * tile)
    end
  end
  for _, object in ipairs(objects) do
    if object.tree then
      art.tree(object.x, object.row, (object.x - 1) * tile, (object.row - 1) * tile)
    else
      art.building(object.building, (self:label(object.building)), (object.x - 1) * tile, (object.top - 1) * tile,
        town.BUILDING_WIDTH * tile, ui.fonts.small)
    end
  end
  love.graphics.setCanvas()
end

function Town:facingTile()
  local d = DIRECTIONS[self.facing]
  return self.x + d[1], self.y + d[2]
end

function Town:facingBuilding()
  local building = self.doors[key(self:facingTile())]
  return building and building.kind ~= "lot" and building or nil
end

function Town:enterBuilding(building)
  if building.kind == "home" then
    scenes.push(Collection.new(self.app))
  elseif building.kind == "dealer" then
    scenes.push(Shop.dealer(self.app))
  else
    scenes.push(Shop.store(self.app, building.store))
  end
end

function Town:step(direction)
  self.facing = direction
  local targetX, targetY = self:facingTile()
  local building = self:facingBuilding()
  if building and direction == "up" then
    self:walkInto(building)
  elseif town.isWalkable(self.map, targetX, targetY, self.blocked) then
    self.move = { dx = targetX - self.x, dy = targetY - self.y, t = 0 }
  end
end

-- Steps onto the doorway; the building opens once the step ends (see Town:update).
function Town:walkInto(building)
  self.facing = "up"
  self.move = { dx = building.door.x - self.x, dy = building.door.y - self.y, t = 0, enter = building }
end

function Town:heldDirection()
  for _, direction in ipairs(DIRECTION_ORDER) do
    if input.isDown(direction) then
      return direction
    end
  end
end

function Town:update(dt)
  if self.app.announcement then
    self.toast, self.toastTime = self.app.announcement, TOAST_SECONDS
    self.app.announcement = nil
  end
  if self.toast then
    self.toastTime = self.toastTime - dt
    if self.toastTime <= 0 then self.toast = nil end
  end

  if self.fadeIn then
    self.fadeIn = self.fadeIn - dt / FADE_IN_SECONDS
    if self.fadeIn <= 0 then self.fadeIn = nil end
  end

  local move = self.move
  if move then
    move.t = move.t + dt * STEPS_PER_SECOND * (move.enter and DOOR_STEP_SPEED or 1)
    if move.t < 1 then return end
    self.move = nil
    self.steps = self.steps + 1
    if move.enter then
      -- The player stays outside the door, so they step out of it facing the street.
      self.facing = "down"
      self:enterBuilding(move.enter)
      return
    end
    self.x, self.y = self.x + move.dx, self.y + move.dy
  end

  local direction = self:heldDirection()
  -- After leaving a building, wait for the d-pad to be released so "up" doesn't walk straight back in.
  if self.waitForRelease then
    self.waitForRelease = direction ~= nil
    return
  end
  if direction then
    self:step(direction)
  end
end

function Town:action(name)
  if name == "start" then
    scenes.push(Confirm.new("Quit Metaretro?", function()
      log("quit confirmed by player")
      love.event.quit()
    end))
  end
end

function Town:playerPixels()
  local t = self.move and self.move.t or 0
  local dx, dy = self.move and self.move.dx or 0, self.move and self.move.dy or 0
  return (self.x - 1 + dx * t) * art.TILE, (self.y - 1 + dy * t) * art.TILE
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

function Town:draw()
  local px, py = self:playerPixels()
  local camX = clamp(math.floor(px + art.TILE / 2 - ui.WIDTH / 2), 0, self.map.width * art.TILE - ui.WIDTH)
  local camY = clamp(math.floor(py + art.TILE / 2 - ui.HEIGHT / 2), 0, self.map.height * art.TILE - ui.HEIGHT)

  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.canvas, -camX, -camY)
  local frame = self.move and self.steps * 2 + math.floor(self.move.t * 2) or 0
  local screenX, screenY = math.floor(px - camX), math.floor(py - camY)
  art.player(screenX, screenY, self.facing, frame)
  self:drawTreesInFront(camX, camY, screenX, screenY)

  local fade = self.move and self.move.enter and self.move.t or self.fadeIn
  if fade then
    love.graphics.setColor(0, 0, 0, math.min(1, fade))
    love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEIGHT)
  end

  self:drawHud()
end

-- Trees standing just below the player cover them with their crowns. They're redrawn only
-- over the player's sprite (at `screenX, screenY`), so they can't cover the trees in front of them.
function Town:drawTreesInFront(camX, camY, screenX, screenY)
  local move = self.move or { dx = 0, dy = 0 }
  love.graphics.setScissor(screenX, screenY - 4, art.TILE, art.TILE + 8)
  for y = math.min(self.y, self.y + move.dy), math.max(self.y, self.y + move.dy) do
    for x = math.min(self.x, self.x + move.dx) - 1, math.max(self.x, self.x + move.dx) + 1 do
      if self.trees[key(x, y + 1)] then
        art.tree(x, y + 1, (x - 1) * art.TILE - camX, y * art.TILE - camY)
      end
    end
  end
  love.graphics.setScissor()
end

function Town:drawHud()
  local wallet = self.app.state.wallet
  local width = ui.fonts.body:getWidth(tostring(wallet)) + 64
  ui.panel(ui.WIDTH - width - 6, 6, width, 38)
  ui.coins(wallet, ui.WIDTH - 26, 16)

  if self.toast then
    ui.messagePanel(self.toast, ui.WIDTH / 2, 48, "coin")
  end

  local building = self:facingBuilding()
  local hint = building and ("Up: enter %s"):format(select(2, self:label(building))) or "Start: quit"
  ui.hintPanel(hint, ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Town

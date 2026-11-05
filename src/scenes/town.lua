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
local TOAST_SECONDS = 4
local DIRECTIONS = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}
local DIRECTION_ORDER = { "up", "down", "left", "right" }
-- Doors and building bodies sit on grass; everything else draws as itself.
local GROUND = { ["="] = "=", ["@"] = "@", T = "T", ["~"] = "~" }

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
end

-- Short text for the building's sign, and the full name used in hints.
function Town:label(building)
  if building.kind == "home" then return "Home", "Home" end
  if building.kind == "dealer" then return "Consoles", "Console Dealer" end
  if building.kind == "store" then return building.store.short, building.store.title end
  return "For sale", "Empty lot"
end

-- Re-renders the static town (ground and buildings) into a canvas after anything that changes it.
function Town:rebuild()
  local tile = art.TILE
  self.buildings = town.layout(self.map, self.app.state, self.app.stores)
  self.doors = {}
  for _, building in ipairs(self.buildings) do
    self.doors[key(building.door.x, building.door.y)] = building
  end

  self.canvas = self.canvas or love.graphics.newCanvas(self.map.width * tile, self.map.height * tile)
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear()
  for y = 1, self.map.height do
    for x = 1, self.map.width do
      art.ground(GROUND[town.tile(self.map, x, y)] or ".", (x - 1) * tile, (y - 1) * tile, x, y)
    end
  end
  for _, building in ipairs(self.buildings) do
    local left, top = town.footprint(building.door)
    art.building(building, (self:label(building)), (left - 1) * tile, (top - 1) * tile,
      town.BUILDING_WIDTH, town.BUILDING_HEIGHT, building.door.x - left, ui.fonts.small)
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
    self:enterBuilding(building)
  elseif town.isWalkable(self.map, targetX, targetY) then
    self.move = { dx = targetX - self.x, dy = targetY - self.y, t = 0 }
  end
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

  if self.move then
    self.move.t = self.move.t + dt * STEPS_PER_SECOND
    if self.move.t < 1 then return end
    self.x, self.y = self.x + self.move.dx, self.y + self.move.dy
    self.move = nil
    self.steps = self.steps + 1
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
  if name == "a" then
    local building = self:facingBuilding()
    if building then self:enterBuilding(building) end
  elseif name == "start" then
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
  local walking = self.move and (self.steps + (self.move.t > 0.5 and 1 or 0)) % 2 or 0
  art.player(math.floor(px - camX), math.floor(py - camY), self.facing, walking)

  self:drawHud()
end

local function panel(x, y, w, h)
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", x, y, w, h, 6)
end

function Town:drawHud()
  love.graphics.setFont(ui.fonts.body)
  local wallet = ("%d coins"):format(self.app.state.wallet)
  local width = ui.fonts.body:getWidth(wallet) + 20
  panel(ui.WIDTH - width - 8, 8, width, 28)
  ui.setColor("coin")
  love.graphics.print(wallet, ui.WIDTH - width + 2, 13)

  if self.toast then
    panel(ui.WIDTH / 2 - 130, 44, 260, 28)
    ui.setColor("coin")
    love.graphics.printf(self.toast, ui.WIDTH / 2 - 130, 49, 260, "center")
  end

  local building = self:facingBuilding()
  local hint = building and ("A: enter %s"):format(select(2, self:label(building))) or "Start: quit"
  local hintWidth = ui.fonts.body:getWidth(hint) + 24
  panel(ui.WIDTH / 2 - hintWidth / 2, ui.HEIGHT - 38, hintWidth, 28)
  ui.setColor("text")
  love.graphics.printf(hint, 0, ui.HEIGHT - 33, ui.WIDTH, "center")
end

return Town

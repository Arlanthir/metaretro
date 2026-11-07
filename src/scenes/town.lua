local catalog = require("core.catalog")
local input = require("core.input")
local log = require("core.log")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local town = require("world.town")
local progression = require("core.progression")
local stores = require("core.stores")
local covers = require("services.covers")
local townsfolk = require("core.townsfolk")
local Collection = require("scenes.collection")
local Confirm = require("scenes.confirm")
local Dialog = require("scenes.dialog")
local GameDetail = require("scenes.gamedetail")
local Shop = require("scenes.shop")

local Town = {}
Town.__index = Town

local STEPS_PER_SECOND = 6
-- Walking into a door is slower, while the screen fades out; coming back fades in.
local DOOR_STEP_SPEED = 0.5
local FADE_IN_SECONDS = 0.25
local TOAST_SECONDS = 4
local VILLAGER_STEPS_PER_SECOND = 3
local VILLAGER_PAUSE = { 1.5, 4 } -- seconds between villager steps
local DIRECTIONS = {
  up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}
local DIRECTION_ORDER = { "up", "down", "left", "right" }
local GROUND = { ["="] = "path", ["@"] = "path", ["~"] = "water" }
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
local WELCOME = "Welcome to Metaretro! Play your games to earn coins, then spend them in the shops. "
  .. "The townsfolk always have a tip or two."

local function key(x, y)
  return x .. "," .. y
end

function Town.new(app)
  local map = app.town
  local villagers, villagerAt = {}, {}
  local tiles = townsfolk.startTiles(function(x, y) return town.tile(map, x, y) end, map.width, map.height, map.start)
  for _, entry in ipairs(townsfolk.dailyRoster(os.date("%Y-%m-%d"), tiles)) do
    -- Each villager stands on a tile, wanders around `home`, and waits `pause` seconds between steps.
    local villager = setmetatable({ x = entry.x, y = entry.y, home = { x = entry.x, y = entry.y },
      facing = "down", pause = love.math.random() * VILLAGER_PAUSE[2] }, { __index = entry.villager })
    table.insert(villagers, villager)
    villagerAt[key(villager.x, villager.y)] = villager
  end
  return setmetatable({
    app = app, map = map, villagers = villagers, villagerAt = villagerAt,
    x = map.start.x, y = map.start.y, facing = "down", steps = 0,
    toast = app.earned > 0 and ("+%d coins from play"):format(app.earned) or nil,
    toastTime = TOAST_SECONDS,
  }, Town)
end

function Town:enter()
  self:rebuild()
end

-- Back from a building (redrawn, faded in) or from a conversation (villagers go back to wandering).
function Town:resume()
  if self.inside then
    self.inside = false
    self:rebuild()
    self.waitForRelease = true
    self.fadeIn = 1
  end
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
  -- Billboards advertise games from today's store picks; drawn live since their images load later.
  self.ads = stores.featured(self.app.state, self.app.catalog, progression.timeline(self.app.catalog.systems),
    os.date("%Y-%m-%d"), #map.billboards, love.math.random, function(game) return ui.boxArt(game) ~= nil end)
  -- Load in the background what's likely to be seen first: the billboards, and the game Home
  -- opens on (its first console's first game), so entering Home shows its cover straight away.
  local images = {}
  for _, ad in ipairs(self.ads) do table.insert(images, ui.boxArt(ad.game)) end
  local homeSystem = catalog.ownedSystems(self.app.catalog)[1]
  local homeGame = homeSystem and self.app.catalog.bySystem[homeSystem.id].owned[1]
  if homeGame then
    table.insert(images, ui.boxArt(homeGame))
    table.insert(images, ui.fullImage(homeGame))
  end
  covers.prefetch(images)
  self.app:persist() -- featuring a store can roll its picks for the day
  -- Billboards without an ad aren't there at all: not drawn, and their tiles are walkable grass.
  self.billboardAt = {}
  for i, billboard in ipairs(map.billboards) do
    if self.ads[i] then
      for x = billboard.x, billboard.x + town.BILLBOARD_WIDTH - 1 do
        for y = billboard.y, billboard.y + town.BILLBOARD_HEIGHT - 1 do
          self.billboardAt[key(x, y)] = i
          self.blocked[key(x, y)] = true
        end
      end
    end
  end
  self.props = {}
  for _, prop in ipairs(map.props) do
    self.props[key(prop.x, prop.y)] = prop
    table.insert(objects, { row = prop.y, x = prop.x, prop = prop })
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
    elseif object.prop then
      art.prop(object.prop.kind, (object.x - 1) * tile, (object.row - 1) * tile)
    else
      art.building(object.building, (self:label(object.building)), (object.x - 1) * tile, (object.top - 1) * tile,
        town.BUILDING_WIDTH * tile, ui.fonts.sign)
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

function Town:facingVillager()
  return self.villagerAt[key(self:facingTile())]
end

local function finishVillagerStep(town, villager)
  local move = villager.move
  town.villagerAt[key(villager.x, villager.y)] = nil
  villager.x, villager.y, villager.move = villager.x + move.dx, villager.y + move.dy, nil
end

-- Villagers take a step in a random direction now and then, never onto the player or each other.
function Town:updateVillagers(dt)
  local map = self.map
  local playerMove = self.move or { dx = 0, dy = 0 }
  local playerTarget = key(self.x + playerMove.dx, self.y + playerMove.dy)
  local function tileAt(x, y) return town.tile(map, x, y) end
  for _, villager in ipairs(self.villagers) do
    if villager.move then
      villager.move.t = villager.move.t + dt * VILLAGER_STEPS_PER_SECOND
      if villager.move.t >= 1 then finishVillagerStep(self, villager) end
    else
      villager.pause = villager.pause - dt
      if villager.pause <= 0 then
        villager.pause = VILLAGER_PAUSE[1] + love.math.random() * (VILLAGER_PAUSE[2] - VILLAGER_PAUSE[1])
        local direction = DIRECTION_ORDER[love.math.random(#DIRECTION_ORDER)]
        local d = DIRECTIONS[direction]
        local x, y = villager.x + d[1], villager.y + d[2]
        local spot = key(x, y)
        villager.facing = direction
        if townsfolk.canWanderTo(tileAt, villager.home, x, y) and not self.villagerAt[spot]
          and spot ~= key(self.x, self.y) and spot ~= playerTarget then
          villager.move = { dx = d[1], dy = d[2], t = 0 }
          self.villagerAt[spot] = villager -- reserved while they walk there
        end
      end
    end
  end
end

function Town:villagerPixels(villager)
  local move = villager.move or { dx = 0, dy = 0, t = 0 }
  return (villager.x - 1 + move.dx * move.t) * art.TILE, (villager.y - 1 + move.dy * move.t) * art.TILE
end

function Town:talkTo(villager)
  local move = villager.move
  if move and key(villager.x, villager.y) == key(self:facingTile()) then
    -- Leaving the tile in front of the player: stay put instead.
    self.villagerAt[key(villager.x + move.dx, villager.y + move.dy)] = nil
    villager.move = nil
  elseif move then
    finishVillagerStep(self, villager)
  end
  villager.pause = VILLAGER_PAUSE[2]
  villager.facing = OPPOSITE[self.facing]
  local app = self.app
  local reply = townsfolk.talk(villager, {
    state = app.state, catalog = app.catalog, timeline = progression.timeline(app.catalog.systems),
    today = os.date("%Y-%m-%d"), random = love.math.random,
  })
  app:persist() -- store tips can roll the day's store picks
  local accept = reply.game and {
    hint = "show me",
    run = function() scenes.push(GameDetail.new(app, reply.game)) end,
  }
  scenes.push(Dialog.new(villager.name, art.portrait(villager), reply.text, accept))
end

function Town:enterBuilding(building)
  self.inside = true
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
  elseif town.isWalkable(self.map, targetX, targetY, self.blocked) and not self.villagerAt[key(targetX, targetY)] then
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

  self:updateVillagers(dt)

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
  local villager, prop = self:facingVillager(), self.props[key(self:facingTile())]
  if name == "a" and villager and not self.move then
    self:talkTo(villager)
  elseif name == "a" and prop and prop.kind == "sign" and not self.move then
    scenes.push(Dialog.new("Signpost", nil, WELCOME))
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
  local frame = self.move and self.steps * 2 + math.floor(self.move.t * 2) or 0
  local screenX, screenY = math.floor(px - camX), math.floor(py - camY)
  -- Characters and billboards lower on screen stand in front of the ones above them.
  local characters = { { y = py, draw = function() art.player(screenX, screenY, self.facing, frame) end } }
  self:addBillboards(characters, camX, camY)
  for _, villager in ipairs(self.villagers) do
    local vx, vy = self:villagerPixels(villager)
    local walkFrame = villager.move and math.floor(villager.move.t * 4) or 0
    table.insert(characters, { y = vy, draw = function()
      art.villager(villager, math.floor(vx - camX), math.floor(vy - camY), villager.facing, walkFrame)
    end })
  end
  table.sort(characters, function(a, b) return a.y < b.y end)
  for _, character in ipairs(characters) do character.draw() end
  self:drawTreesInFront(camX, camY, screenX, screenY)

  local fade = self.move and self.move.enter and self.move.t or self.fadeIn
  if fade then
    love.graphics.setColor(0, 0, 0, math.min(1, fade))
    love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEIGHT)
  end

  self:drawHud()
end

-- Adds the billboards on screen to `drawables`, sorted by the bottom row of their base so
-- characters walking behind a tall board are hidden by it.
function Town:addBillboards(drawables, camX, camY)
  for i, billboard in ipairs(self.map.billboards) do
    local px, py = (billboard.x - 1) * art.TILE - camX, (billboard.y - 1) * art.TILE - camY
    local onScreen = px > -4 * art.TILE and px < ui.WIDTH and py > -3 * art.TILE and py < ui.HEIGHT + 2 * art.TILE
    local ad = self.ads[i]
    if onScreen and ad then
      local path = ad and ui.boxArt(ad.game)
      local image = path and covers.get(path)
      table.insert(drawables, {
        y = (billboard.y + town.BILLBOARD_HEIGHT - 2) * art.TILE,
        draw = function() art.billboard(px, py, image, ad.game.name, ui.fonts.sign) end,
      })
    end
  end
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
  ui.walletPanel(self.app.state.wallet)

  if self.toast then
    ui.messagePanel(self.toast, ui.WIDTH / 2, 48, "coin")
  end

  local building, villager = self:facingBuilding(), self:facingVillager()
  local prop = self.props[key(self:facingTile())]
  local ad = self.ads[self.billboardAt[key(self:facingTile())] or 0]
  local hint = building and ("Up: enter %s"):format(select(2, self:label(building)))
    or ad and ("%s at the %s"):format(ad.game.name, ad.store.title)
    or villager and ("A: talk to %s"):format(villager.name)
    or prop and prop.kind == "sign" and "A: read sign" or "Start: quit"
  ui.hintPanel(hint, ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Town

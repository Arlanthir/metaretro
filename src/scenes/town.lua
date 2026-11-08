local catalog = require("core.catalog")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local town = require("world.town")
local progression = require("core.progression")
local stores = require("core.stores")
local covers = require("services.covers")
local townsfolk = require("core.townsfolk")
local Dialog = require("scenes.dialog")
local Home = require("scenes.home")
local House = require("scenes.house")
local Museum = require("scenes.museum")
local GameDetail = require("scenes.gamedetail")
local Advert = require("scenes.advert")
local Arcade = require("scenes.arcade")
local Mall = require("scenes.mall")
local Store = require("scenes.store")
local Walker = require("scenes.walker")

local Town = Walker.extend({})

local VILLAGER_STEPS_PER_SECOND = 3
local VILLAGER_PAUSE = { 1.5, 4 } -- seconds between villager steps
local GROUND = { ["="] = "path", ["@"] = "path", ["~"] = "water" }
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
  }, Town)
end

function Town:enter()
  self:rebuild()
end

-- Back from a building (redrawn, faded in) or from a conversation (villagers go back to wandering).
function Town:resume()
  if self.inside then
    self.inside, self.building, self.interior = false, nil, nil
    self:rebuild()
    self:fadeInNow()
  end
end

-- Short text for the building's sign, and the full name used in hints.
local LABELS = {
  home = { "Home", "Home" }, dealer = { "Consoles", "Console Dealer" }, museum = { "Museum", "Game Museum" },
  mall = { "Mall", "Mall" }, arcade = { "Arcade", "Arcade Club" },
}

-- Who lives in a house, or Granny Rose's.
local function resident(building)
  if building.kind == "grandma" then return townsfolk.GRANDMA end
  return building.kind == "house" and townsfolk.RESIDENTS[(building.index - 1) % #townsfolk.RESIDENTS + 1] or nil
end

-- The building's sign and its full name; houses have no sign.
function Town:label(building)
  local person = resident(building)
  if person then return nil, ("%s's house"):format(person.name) end
  return unpack(LABELS[building.kind])
end

local function groundKind(map, x, y)
  return GROUND[town.tile(map, x, y)] or "grass"
end

-- Re-renders the static town (ground, trees and buildings) into a canvas after anything that changes it.
function Town:rebuild()
  local tile = art.TILE
  local map = self.map
  self.buildings = town.layout(map)
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
    table.insert(objects, { row = building.door.y, x = left, building = building, top = top })
  end
  -- Billboards advertise games from today's store picks; drawn live since their images load later.
  self.ads = stores.featured(self.app.state, self.app.catalog, progression.timeline(self.app.catalog.systems),
    os.date("%Y-%m-%d"), #map.billboards, love.math.random, function(game) return ui.boxArt(game) ~= nil end)
  -- Load in the background what's likely to be seen first: the billboards, and the game the
  -- collection opens on (its first console's first game), so its cover shows straight away.
  local images = {}
  for _, ad in ipairs(self.ads) do table.insert(images, ui.boxArt(ad.game)) end
  local homeSystem = catalog.ownedSystems(self.app.catalog)[1]
  local homeGame = homeSystem and self.app.catalog.bySystem[homeSystem.id].owned[1]
  if homeGame then
    table.insert(images, ui.boxArt(homeGame))
    table.insert(images, ui.fullImage(homeGame))
  end
  table.insert(images, Home.cabinetArt(self.app))
  -- And what the mall's posters and the arcade's cabinets show, so they're there on the way in.
  for _, path in ipairs(Mall.adPaths(self.app)) do table.insert(images, path) end
  for _, path in ipairs(Arcade.artPaths(self.app)) do table.insert(images, path) end
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
      if self:isClosed(object.building) then
        local door = object.building.door
        art.closedDoor((door.x - 1) * tile, (door.y - 1) * tile)
      end
    end
  end
  love.graphics.setCanvas()
end

function Town:facingBuilding()
  local building = self.doors[key(self:facingTile())]
  return building
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
        local direction = Walker.DIRECTION_ORDER[love.math.random(#Walker.DIRECTION_ORDER)]
        local d = Walker.DIRECTIONS[direction]
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
  villager.facing = Walker.OPPOSITE[self.facing]
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

local OPEN = {
  home = Home.new, museum = Museum.new, mall = Mall.new, arcade = Arcade.new,
  dealer = function(app) return Store.new(app) end,
  house = function(app, building) return House.new(app, resident(building)) end,
}
OPEN.grandma = OPEN.house

-- Goes into `building`; `at` ({ x, y, facing }) optionally puts the player somewhere other than the door.
function Town:enterBuilding(building, at)
  local scene = OPEN[building.kind](self.app, building)
  self.inside, self.building, self.interior = true, building, scene
  if at then scene:placeAt(at) end
  scenes.push(scene)
end

-- Where the player is: in town, and in which building, where, if they're inside one. Saved when a
-- game launches, so Metaretro starts again there afterwards (see `restore`).
function Town:location()
  local here = { x = self.x, y = self.y, facing = self.facing }
  local scene = self.inside and self.interior
  if scene then
    here.building = key(self.building.door.x, self.building.door.y)
    here.inside = { x = scene.x, y = scene.y, facing = scene.facing }
  end
  return here
end

-- Back where `location` left the player, wherever it still makes sense (the town may have changed).
function Town:restore(location)
  local x, y = tonumber(location.x), tonumber(location.y)
  if x and y and town.isWalkable(self.map, x, y, self.blocked) and not self.villagerAt[key(x, y)] then
    self.x, self.y = x, y
    self.facing = Walker.DIRECTIONS[location.facing] and location.facing or "down"
  end
  local building = location.building and self.doors[location.building]
  local inFront = building and self.x == building.door.x and self.y == building.door.y + 1
  if inFront and not self:isClosed(building) and type(location.inside) == "table" then
    self.facing = "down"
    self:enterBuilding(building, location.inside)
  end
end

-- The console dealer opens once Professor Cork has given the player their first console, and the
-- mall once they have a console (and so a store).
function Town:isClosed(building)
  local state = self.app.state
  if building.kind == "dealer" then return not state.giftReceived end
  return building.kind == "mall" and next(state.ownedConsoles) == nil
end

-- A new game, or Continue, starts at home; walking out leaves the player at Home's door.
function Town:wakeUpAtHome()
  for _, building in ipairs(self.buildings) do
    if building.kind == "home" then
      self.x, self.y, self.facing = building.door.x, building.door.y + 1, "down"
      self:enterBuilding(building, Home.wakeUpSpot())
    end
  end
end

function Town:step(direction)
  self.facing = direction
  local targetX, targetY = self:facingTile()
  local building = self:facingBuilding()
  if building and direction == "up" then
    if not self:isClosed(building) then
      self:startStep("up", building) -- it opens once the step ends
    end
  elseif town.isWalkable(self.map, targetX, targetY, self.blocked) and not self.villagerAt[key(targetX, targetY)] then
    self:startStep(direction)
  end
end

function Town:update(dt)
  self:updateToast(dt)
  self:updateVillagers(dt)

  local doorStep, direction = self:updateWalking(dt)
  if doorStep then
    self:enterBuilding(doorStep.door)
  elseif direction then
    self:step(direction)
  end
end

-- The ad on the billboard the player faces, if any.
function Town:facingAd()
  return self.ads[self.billboardAt[key(self:facingTile())] or 0]
end

function Town:action(name)
  local villager, prop, ad = self:facingVillager(), self.props[key(self:facingTile())], self:facingAd()
  if name == "a" and villager and not self.move then
    self:talkTo(villager)
  elseif name == "a" and ad and not self.move then
    scenes.push(Advert.new(ad.game, ad.store))
  elseif name == "a" and prop and prop.kind == "sign" and not self.move then
    scenes.push(Dialog.new("Signpost", nil, WELCOME))
  elseif name == "start" then
    self:confirmQuit()
  end
end

function Town:draw()
  local px, py = self:playerPixels()
  local camX, camY = self:camera(self.map.width, self.map.height)

  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.canvas, -camX, -camY)
  local frame = self:walkFrame()
  local screenX, screenY = math.floor(px - camX), math.floor(py - camY)
  -- Characters and billboards lower on screen stand in front of the ones above them.
  local characters = { { y = py, draw = function() art.player(screenX, screenY, self.facing, frame, self.app.state.player) end } }
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

  self:drawFade()
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
  self:drawStatus()
  local building, villager = self:facingBuilding(), self:facingVillager()
  local prop = self.props[key(self:facingTile())]
  local ad = self:facingAd()
  local hint = building and self:isClosed(building) and ("The %s is closed"):format(select(2, self:label(building)))
    or building and ("Up: enter %s"):format(select(2, self:label(building)))
    or ad and ("A: %s at the %s"):format(ad.game.name, ad.store.title)
    or villager and ("A: talk to %s"):format(villager.name)
    or prop and prop.kind == "sign" and "A: read sign" or "Start: quit"
  ui.hintPanel(hint, ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Town

-- The mall: a corridor with every open store along it (see world/mall.lua), open to walk around in,
-- each with its clerk behind the counter; talking to one, or facing the counter in front of them,
-- opens that store's menu (scenes/shop.lua). Posters on the wall show games on sale in the stores
-- beside them; A shows one up close (scenes/advert.lua).
local progression = require("core.progression")
local stores = require("core.stores")
local covers = require("services.covers")
local art = require("world.art")
local interior = require("world.interior")
local mall = require("world.mall")
local scenes = require("core.scenes")
local ui = require("ui")
local Advert = require("scenes.advert")
local Interior = require("scenes.interior")
local Shop = require("scenes.shop")
local Walker = require("scenes.walker")

local Mall = Walker.extend({ place = "the mall" }, Interior)

local CLERKS = { "Villager5", "Villager6", "Village6", "EggGirl", "SorcererOrange" }
local layouts = {} -- by store count, so each layout is parsed and drawn once

local function layoutFor(count)
  if not layouts[count] then
    local layout = mall.layout(count)
    layouts[count] = { map = interior.parse(layout), ads = layout.ads }
  end
  return layouts[count]
end

-- A game on sale today in `store` to advertise: the first of its picks with box art.
local function advertised(app, store)
  local timeline = progression.timeline(app.catalog.systems)
  local offer = stores.offer(store, app.state, app.catalog, timeline, os.date("%Y-%m-%d"), love.math.random)
  for _, game in ipairs(offer) do
    if ui.boxArt(game) then return game end
  end
end

local function today(app)
  return mall.order(app.stores, os.date("%Y-%m-%d"))
end

-- Today's posters on the wall (see mall.layout), each with its store and game: { tiles, store, game }.
local function ads(app)
  local list, stores = {}, today(app)
  for _, ad in ipairs(layoutFor(#stores).ads) do
    local store = stores[ad.store]
    table.insert(list, { tiles = ad.tiles, store = store, game = store and advertised(app, store) })
  end
  return list
end

-- The posters' box art, for the town to load ahead so they show as soon as the player walks in.
-- Picking ads can roll a store's picks for the day, so the caller saves afterwards.
function Mall.adPaths(app)
  local paths = {}
  for _, ad in ipairs(ads(app)) do
    if ad.game then table.insert(paths, ui.boxArt(ad.game)) end
  end
  return paths
end

-- Each store's clerk, in today's order, with the counter they serve from.
function Mall.new(app)
  local stores = today(app)
  local map = layoutFor(#stores).map
  local self = Interior.new(Mall, app, map)
  self.ads = ads(app)
  for i, spot in ipairs(map.allSpots.clerk or {}) do
    local store = stores[i]
    local counter, facing = interior.counter(map, spot)
    table.insert(self.people, { x = spot.x, y = spot.y, facing = facing, store = store, counter = counter,
      look = { name = "Clerk", sprite = CLERKS[art.storeHash(store) % #CLERKS + 1] } })
  end
  app:persist()
  return self
end

-- The poster the player faces, from the corridor just below the wall.
function Mall:facingAd()
  local x, y = self:facingTile()
  if self.facing ~= "up" or y ~= mall.TOP_FRONT then return nil end
  for _, ad in ipairs(self.ads) do
    if ad.game and x >= ad.tiles[1] and x <= ad.tiles[2] then return ad end
  end
end

-- The store whose clerk, or counter in front of them, the player faces.
function Mall:facingStore(person)
  if person then return person.store end
  local x, y = self:facingTile()
  for _, clerk in ipairs(self.people) do
    if clerk.counter.x == x and clerk.counter.y == y then return clerk.store end
  end
end

function Mall:action(name)
  local ad = name == "a" and not self.move and self:facingAd()
  if ad then
    scenes.push(Advert.new(ad.game, ad.store))
  else
    Interior.action(self, name)
  end
end

function Mall:interact(_, person)
  local store = self:facingStore(person)
  if store then scenes.push(Shop.store(self.app, store)) end
end

function Mall:hintFor(_, person)
  local ad = self:facingAd()
  if ad then return ("A: %s at the %s"):format(ad.game.name, ad.store.title) end
  local store = self:facingStore(person)
  if store then return ("A: shop at the %s"):format(store.title) end
end

-- The posters, then each store's name on a plaque on its back wall.
function Mall:drawOnTop(camX, camY)
  for _, ad in ipairs(self.ads) do
    local path = ad.game and ui.boxArt(ad.game)
    local centerX = ((ad.tiles[1] + ad.tiles[2]) / 2 - 0.5) * art.TILE - camX
    art.poster(centerX, mall.TOP_FRONT * art.TILE - 2 - camY, path and covers.get(path) or nil)
  end
  for _, clerk in ipairs(self.people) do
    local y = clerk.counter.y > clerk.y and 4 or (self.map.height - 1) * art.TILE + 5
    art.sign(clerk.store.short, (clerk.x - 0.5) * art.TILE - camX, y - camY, ui.fonts.sign)
  end
end

return Mall

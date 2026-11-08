-- The mall: a corridor of storefronts, one per open store (see world/mall.lua), each leading into
-- that store (scenes/store.lua), with ad stands showing games on sale in the stores beside them.
local progression = require("core.progression")
local stores = require("core.stores")
local covers = require("services.covers")
local art = require("world.art")
local interior = require("world.interior")
local mall = require("world.mall")
local scenes = require("core.scenes")
local ui = require("ui")
local Interior = require("scenes.interior")
local Store = require("scenes.store")
local Walker = require("scenes.walker")

local Mall = Walker.extend({ place = "the mall" }, Interior)

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

-- Each ad stand of today's mall, with its store and game: { [piece] = { store, game } }.
local function ads(app)
  local layout = layoutFor(#app.stores)
  local byStand, index = {}, 0
  for _, piece in ipairs(layout.map.furniture) do
    if piece.kind == "adStand" then
      index = index + 1
      local store = app.stores[layout.ads[index]]
      byStand[piece] = { store = store, game = store and advertised(app, store) }
    end
  end
  return byStand
end

-- The ads' box art, for the town to load ahead so the posters show as soon as the player walks in.
-- Picking ads can roll a store's picks for the day, so the caller saves afterwards.
function Mall.adPaths(app)
  local paths = {}
  for _, ad in pairs(ads(app)) do
    if ad.game then table.insert(paths, ui.boxArt(ad.game)) end
  end
  return paths
end

function Mall.new(app)
  local self = Interior.new(Mall, app, layoutFor(#app.stores).map)
  self.stores = app.stores
  self.adAt = ads(app)
  app:persist()
  return self
end

function Mall:live(piece)
  return piece.kind == "adStand"
end

function Mall:drawLive(piece, px, py)
  local ad = self.adAt[piece]
  local path = ad and ad.game and ui.boxArt(ad.game)
  art.adStand(px, py, path and covers.get(path) or nil)
end

function Mall:hintFor(piece)
  local ad = piece and self.adAt[piece]
  if ad and ad.game then return ("%s at the %s"):format(ad.game.name, ad.store.title) end
end

function Mall:storeAt(door)
  for i, storefront in ipairs(self.map.storefronts) do
    if storefront == door then return self.stores[i] end
  end
end

function Mall:enterStorefront(door)
  scenes.push(Store.new(self.app, self:storeAt(door)))
end

function Mall:storefrontHint(door)
  return ("%s: enter the %s"):format(door.direction == "up" and "Up" or "Down", self:storeAt(door).title)
end

-- Each store's name on a plaque over its door: above the top wall, below the bottom one.
function Mall:drawOnTop(camX, camY)
  for i, door in ipairs(self.map.storefronts) do
    local centerX = (door.x - 0.5) * art.TILE - camX
    local y = door.direction == "up" and (door.y - 2) * art.TILE + 6 or door.y * art.TILE + 4
    art.sign(self.stores[i].short, centerX, y - camY, ui.fonts.sign)
  end
end

return Mall

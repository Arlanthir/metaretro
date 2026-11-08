-- The mall: a corridor of storefronts, one per open store (see world/mall.lua), each leading into
-- that store (scenes/store.lua).
local art = require("world.art")
local interior = require("world.interior")
local mall = require("world.mall")
local scenes = require("core.scenes")
local ui = require("ui")
local Interior = require("scenes.interior")
local Store = require("scenes.store")
local Walker = require("scenes.walker")

local Mall = Walker.extend({ place = "the mall" }, Interior)

local maps = {} -- by store count, so each layout is parsed and drawn once

function Mall.new(app)
  local stores = app.stores
  maps[#stores] = maps[#stores] or interior.parse(mall.layout(#stores))
  local self = Interior.new(Mall, app, maps[#stores])
  self.stores = stores
  return self
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

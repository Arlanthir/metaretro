-- Inside a store, or the console dealer: talking to the clerk behind the counter, or facing the
-- counter right in front of them, opens the store's menu (scenes/shop.lua).
local art = require("world.art")
local interior = require("world.interior")
local scenes = require("core.scenes")
local Interior = require("scenes.interior")
local Shop = require("scenes.shop")
local Walker = require("scenes.walker")

local Store = Walker.extend({}, Interior)

local map = interior.parse(require("world.storemap"))
local CLERKS = { "Villager5", "Villager6", "Village6", "EggGirl", "SorcererOrange" }
local DEALER_CLERK = "ManGreen"

-- `store` is one of core/stores' stores, or nil for the console dealer.
function Store.new(app, store)
  local self = Interior.new(Store, app, map)
  self.store = store
  self.place = store and ("the %s"):format(store.title) or "the Console Dealer"
  local sprite = store and CLERKS[art.storeHash(store) % #CLERKS + 1] or DEALER_CLERK
  local spot = map.spots.clerk
  self.people = { { x = spot.x, y = spot.y, facing = "down", look = { name = "Clerk", sprite = sprite } } }
  return self
end

-- The counter tile right in front of the clerk, where they serve from.
function Store:facingCounter()
  local x, y = self:facingTile()
  local clerk = map.spots.clerk
  return x == clerk.x and y == clerk.y + 1
end

function Store:interact(_, person)
  if person or self:facingCounter() then
    scenes.push(self.store and Shop.store(self.app, self.store) or Shop.dealer(self.app))
  end
end

function Store:hintFor(_, person)
  if person or self:facingCounter() then return "A: shop" end
end

return Store

-- Inside the console dealer: talking to the clerk behind the counter, or facing the counter right in
-- front of them, opens the dealer's menu (scenes/shop.lua).
local interior = require("world.interior")
local scenes = require("core.scenes")
local Interior = require("scenes.interior")
local Shop = require("scenes.shop")
local Walker = require("scenes.walker")

local Store = Walker.extend({ place = "the Console Dealer" }, Interior)

local map = interior.parse(require("world.storemap"))
local CLERK = { name = "Clerk", sprite = "ManGreen" }

function Store.new(app)
  local self = Interior.new(Store, app, map)
  local spot, facing = map.spots.clerk
  self.counter, facing = interior.counter(map)
  self.people = { { x = spot.x, y = spot.y, facing = facing, look = CLERK } }
  return self
end

function Store:facingCounter()
  local x, y = self:facingTile()
  return x == self.counter.x and y == self.counter.y
end

function Store:interact(_, person)
  if person or self:facingCounter() then scenes.push(Shop.dealer(self.app)) end
end

function Store:hintFor(_, person)
  if person or self:facingCounter() then return "A: shop" end
end

return Store

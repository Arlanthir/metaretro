-- Inside a house in town: a resident who gives hints about how Retro Town Story works, one after
-- another, or Granny Rose, who buys the player's games for her grandchildren (scenes/shop.lua).
local art = require("world.art")
local interior = require("world.interior")
local scenes = require("core.scenes")
local townsfolk = require("core.townsfolk")
local Dialog = require("scenes.dialog")
local Interior = require("scenes.interior")
local Shop = require("scenes.shop")
local Walker = require("scenes.walker")

local House = Walker.extend({}, Interior)

local map = interior.parse(require("world.housemap"))
local GRANDMA = "Oh, hello dear! My grandchildren love their games, but they finish them so fast. "
  .. "If you have any you're done with, I'll buy them for half what they cost."
local hintTurns = {} -- resident id -> hints given so far this run

-- `resident` is one of townsfolk.RESIDENTS, or townsfolk.GRANDMA.
function House.new(app, resident)
  local self = Interior.new(House, app, map)
  self.resident = resident
  self.place = ("%s's house"):format(resident.name)
  local spot = map.spots.resident
  self.people = { { x = spot.x, y = spot.y, facing = "down", look = resident } }
  return self
end

function House:interact(_, person)
  if not person then return end
  local resident = self.resident
  if resident == townsfolk.GRANDMA then
    scenes.push(Dialog.new(resident.name, art.portrait(resident), GRANDMA, {
      hint = "sell games",
      run = function() scenes.push(Shop.grandma(self.app)) end,
    }))
    return
  end
  local turn = (hintTurns[resident.id] or 0) + 1
  hintTurns[resident.id] = turn
  scenes.push(Dialog.new(resident.name, art.portrait(resident), resident.hints[(turn - 1) % #resident.hints + 1]))
end

function House:hintFor(_, person)
  if person then return ("A: talk to %s"):format(person.look.name) end
end

return House

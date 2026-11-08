-- The Arcade Club's cabinets: arcade games from the library (systems Metaretro otherwise leaves out
-- of stores and the collection), a new set every week. A play costs a coin and earns coins like
-- any other game.
local daily = require("core.daily")

local arcade = {}

arcade.SYSTEMS = {
  arcade = true, mame = true, fbneo = true, naomi = true, naomi2 = true, atomiswave = true,
  cps1 = true, cps2 = true, cps3 = true, model2 = true, model3 = true,
}
arcade.CABINETS = 4
arcade.PRICE = 1

local WEEK = 7 * 86400

-- The number of the week `time` falls in; weeks start on Monday (the epoch was a Thursday).
function arcade.week(time)
  return math.floor((time + 3 * 86400) / WEEK)
end

-- This week's games, one per cabinet (fewer when the library has fewer arcade games), the same all
-- week.
function arcade.cabinets(games, week)
  local pool = {}
  for _, game in ipairs(games) do
    if arcade.SYSTEMS[game.system] then table.insert(pool, game) end
  end
  table.sort(pool, function(a, b) return a.id < b.id end)
  local random = daily.random("arcade week " .. week)
  local picked = {}
  while #picked < arcade.CABINETS and #pool > 0 do
    table.insert(picked, table.remove(pool, random(#pool)))
  end
  return picked
end

return arcade

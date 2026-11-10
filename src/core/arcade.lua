-- The Arcade Club's cabinets: arcade games from the library (systems the game otherwise leaves out
-- of stores and the collection), a new set every week. A play costs a coin and earns coins like
-- any other game. The clerk sells the cabinets' games, to play for free on the player's own cabinet
-- at home; a cabinet whose game was bought (or whose ROM is missing) gets another one for the week.
local daily = require("core.daily")
local roms = require("core.roms")

local arcade = {}

arcade.SYSTEMS = {
  arcade = true, mame = true, fbneo = true, naomi = true, naomi2 = true, atomiswave = true,
  cps1 = true, cps2 = true, cps3 = true, model2 = true, model3 = true,
}
arcade.CABINETS = 4
arcade.PRICE = 1
arcade.GAME_PRICE = 100 -- to own a cabinet's game

local WEEK = 7 * 86400

-- The number of the week `time` falls in; weeks start on Monday (the epoch was a Thursday).
function arcade.week(time)
  return math.floor((time + 3 * 86400) / WEEK)
end

function arcade.isArcade(game)
  return arcade.SYSTEMS[game.system] == true
end

-- The arcade games of `games` that `owned` (a set of game ids) has, by name.
function arcade.owned(games, owned)
  local list = {}
  for _, game in ipairs(games) do
    if arcade.isArcade(game) and owned[game.id] then table.insert(list, game) end
  end
  table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  return list
end

-- This week's games, by cabinet: the same all week, and none of them in `owned` (a set of game ids):
-- a cabinet whose game is owned takes the week's next one instead. Cabinets stay empty when the
-- library runs out of arcade games.
function arcade.cabinets(games, week, owned)
  owned = owned or {}
  local pool = {}
  for _, game in ipairs(games) do
    if arcade.isArcade(game) then table.insert(pool, game) end
  end
  table.sort(pool, function(a, b) return a.id < b.id end)
  local random = daily.random("arcade week " .. week)
  local function draw() return #pool > 0 and table.remove(pool, random(#pool)) or nil end
  local picked = {}
  for i = 1, arcade.CABINETS do picked[i] = draw() end
  for i = 1, arcade.CABINETS do
    while picked[i] and (owned[picked[i].id] or not roms.present(picked[i])) do picked[i] = draw() end
  end
  return picked
end

-- Whether `owned` (a set of game ids, "system:path") has any arcade game: the player has a cabinet.
function arcade.ownsAny(owned)
  for id in pairs(owned) do
    if arcade.SYSTEMS[id:match("^(.-):")] then return true end
  end
  return false
end

-- Buys a cabinet's game for the player's own cabinet; returns true, or false and why not.
function arcade.buy(state, game)
  if state.owned[game.id] then return false, "already owned" end
  if state.wallet < arcade.GAME_PRICE then return false, "not enough coins" end
  state.wallet = state.wallet - arcade.GAME_PRICE
  state.owned[game.id] = true
  state.cabinetGame = game.id
  return true
end

return arcade

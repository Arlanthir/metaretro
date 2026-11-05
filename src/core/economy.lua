local economy = {}

economy.STARTER_WALLET = 100
economy.STARTER_GAMES = 3
economy.COINS_PER_MINUTE = 2
economy.SESSION_CAP_MINUTES = 120
economy.COINS_PER_RA_POINT = 1
economy.HARDCORE_MULTIPLIER = 2

local SYSTEM_TIER = {
  atari2600 = 1, nes = 1, gb = 1, gbc = 1, gamegear = 1, mastersystem = 1,
  snes = 2, megadrive = 2, gba = 2, pcengine = 2, neogeo = 2,
  n64 = 3, psx = 3, saturn = 3, nds = 3,
  dreamcast = 4, psp = 4,
}
local TIER_BASE = { 40, 60, 80, 100 }
local DEFAULT_TIER = 2

local function roundTo(value, step)
  return math.floor(value / step + 0.5) * step
end

-- ES ratings are 0..1; a well-rated game costs up to 25% more, a poorly rated one up to 25% less.
function economy.price(game)
  local base = TIER_BASE[SYSTEM_TIER[game.system] or DEFAULT_TIER]
  local rating = tonumber(game.rating)
  if rating then
    base = base * (0.75 + math.max(0, math.min(1, rating)) * 0.5)
  end
  return roundTo(base, 5)
end

function economy.playEarnings(seconds)
  local minutes = math.min(math.floor(math.max(0, seconds) / 60), economy.SESSION_CAP_MINUTES)
  return minutes * economy.COINS_PER_MINUTE
end

function economy.achievementEarnings(points, hardcore)
  local multiplier = hardcore and economy.HARDCORE_MULTIPLIER or 1
  return math.max(0, points) * economy.COINS_PER_RA_POINT * multiplier
end

function economy.buy(state, game)
  if state.owned[game.id] then
    return false, "already owned"
  end
  local cost = economy.price(game)
  if state.wallet < cost then
    return false, "not enough coins"
  end
  state.wallet = state.wallet - cost
  state.owned[game.id] = true
  return true
end

-- Prefers games the player has already played; fills the rest randomly.
-- `systems` optionally restricts the pack to a set of system ids.
function economy.grantStarterPack(state, games, random, systems)
  random = random or math.random
  local played, unplayed = {}, {}
  for _, game in ipairs(games) do
    if not systems or systems[game.system] then
      table.insert((tonumber(game.playcount) or 0) > 0 and played or unplayed, game)
    end
  end
  local granted = {}
  local function grant(game)
    state.owned[game.id] = true
    table.insert(granted, game)
  end
  for _, game in ipairs(played) do
    if #granted >= economy.STARTER_GAMES then break end
    grant(game)
  end
  while #granted < economy.STARTER_GAMES and #unplayed > 0 do
    grant(table.remove(unplayed, random(#unplayed)))
  end
  return granted
end

return economy

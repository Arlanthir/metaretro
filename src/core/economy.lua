local consoles = require("core.consoles")
local launchTitles = require("core.launchtitles")

local economy = {}

economy.STARTER_WALLET = 100
economy.STARTER_GAMES = 3
economy.COINS_PER_MINUTE = 2
economy.SESSION_CAP_MINUTES = 120
economy.COINS_PER_RA_POINT = 5
economy.HARDCORE_MULTIPLIER = 2
-- Achievements unlocked before Metaretro started tracking them pay this fraction, once.
economy.PAST_ACHIEVEMENT_RATE = 0.5

-- Base game price per console generation: 2nd gen costs 20, each later one 20 more.
economy.PRICE_PER_GENERATION = 20
local DEFAULT_GENERATION = 4

local function roundTo(value, step)
  return math.floor(value / step + 0.5) * step
end

-- ES ratings are 0..1; a well-rated game costs up to 25% more, a poorly rated one up to 25% less.
function economy.price(game)
  local console = consoles.get(game.system)
  local generation = console and console.generation or DEFAULT_GENERATION
  local base = (generation - 1) * economy.PRICE_PER_GENERATION
  local rating = tonumber(game.rating)
  if rating then
    base = base * (0.75 + math.max(0, math.min(1, rating)) * 0.5)
  end
  return roundTo(base, 5)
end

-- Granny Rose buys games back for half their price.
function economy.sellPrice(game)
  return math.floor(economy.price(game) / 2)
end

-- Sells an owned game back; returns true and the coins paid.
function economy.sell(state, game)
  if not state.owned[game.id] then
    return false, "not owned"
  end
  local coins = economy.sellPrice(game)
  state.owned[game.id] = nil
  state.wallet = state.wallet + coins
  return true, coins
end

function economy.playEarnings(seconds)
  local minutes = math.min(math.floor(math.max(0, seconds) / 60), economy.SESSION_CAP_MINUTES)
  return minutes * economy.COINS_PER_MINUTE
end

function economy.achievementEarnings(points, hardcore)
  local multiplier = hardcore and economy.HARDCORE_MULTIPLIER or 1
  return math.max(0, points) * economy.COINS_PER_RA_POINT * multiplier
end

economy.CONSOLE_PRICE_PER_GENERATION = 100

function economy.consolePrice(console)
  return console.generation * economy.CONSOLE_PRICE_PER_GENERATION
end

local function purchase(state, ownedSet, id, cost)
  if ownedSet[id] then
    return false, "already owned"
  end
  if state.wallet < cost then
    return false, "not enough coins"
  end
  state.wallet = state.wallet - cost
  ownedSet[id] = true
  return true
end

function economy.buy(state, game)
  if not state.ownedConsoles[game.system] then
    return false, "console not owned"
  end
  return purchase(state, state.owned, game.id, economy.price(game))
end

-- A new console comes with a starter pack picked from `games`; returns true and the granted games.
function economy.buyConsole(state, console, games, random)
  local ok, reason = purchase(state, state.ownedConsoles, console.id, economy.consolePrice(console))
  if not ok then
    return false, reason
  end
  return true, economy.grantStarterPack(state, games or {}, random, { [console.id] = true })
end

-- Professor Cork's gift: the console and its starter pack, for free. Returns the granted games.
function economy.giftConsole(state, console, games, random)
  state.ownedConsoles[console.id] = true
  state.giftReceived, state.giftConsole = true, console.id
  return economy.grantStarterPack(state, games or {}, random, { [console.id] = true })
end

local function releaseYear(game)
  return tonumber(game.releasedate and game.releasedate:sub(1, 4))
end

-- Each system's launch year: the first year with games in the list, but never before the console came out.
function economy.launchYears(games)
  local years = {}
  for _, game in ipairs(games) do
    local console, year = consoles.get(game.system), releaseYear(game)
    if console and year then
      years[game.system] = math.min(years[game.system] or math.huge, math.max(year, console.year))
    end
  end
  return years
end

-- Launch-window games came out in their system's launch year or the year after.
function economy.isLaunchTitle(game, launchYears)
  local launchYear, year = launchYears[game.system], releaseYear(game)
  return launchYear ~= nil and year ~= nil and year <= launchYear + 1
end

local function normalizeName(name)
  return (tostring(name or ""):lower():gsub("[^%w]", ""))
end

-- Matches the curated list by the strongest identifier both sides have:
-- ScreenScraper ID, then RetroAchievements ID, then normalized name.
function economy.isCuratedLaunchTitle(game)
  local name = normalizeName(game.name)
  for _, entry in ipairs(launchTitles[game.system] or {}) do
    local match
    if entry.screenscraper and game.screenscraperId then
      match = entry.screenscraper == game.screenscraperId
    elseif entry.retroachievements and game.cheevosId then
      match = entry.retroachievements == game.cheevosId
    else
      match = normalizeName(entry.name) == name
    end
    if match then return true end
  end
  return false
end

local JAPANESE = { jp = true, ja = true }

-- True when every listed language is Japanese; without languages, falls back to the region.
function economy.isJapaneseOnly(game)
  if not game.lang or game.lang == "" then
    return game.region ~= nil and JAPANESE[game.region] == true
  end
  for lang in game.lang:gmatch("[^,%s]+") do
    if not JAPANESE[lang] then return false end
  end
  return true
end

-- Picks STARTER_GAMES random games. Curated launch titles come first, then games from the launch
-- window, then the rest; Japanese-only games come last, so consoles whose library is mostly
-- Japanese (the PC Engine) still get a pack. `systems` optionally restricts the pack to a set of system ids.
function economy.grantStarterPack(state, games, random, systems)
  random = random or math.random
  local eligible, japanese = {}, {}
  for _, game in ipairs(games) do
    if (not systems or systems[game.system]) and not state.owned[game.id] then
      table.insert(economy.isJapaneseOnly(game) and japanese or eligible, game)
    end
  end
  -- The launch window counts from the first release that isn't Japanese-only.
  local launchYears = economy.launchYears(eligible)
  local curated, launch, rest = {}, {}, {}
  for _, game in ipairs(eligible) do
    local pool = economy.isCuratedLaunchTitle(game) and curated
      or economy.isLaunchTitle(game, launchYears) and launch or rest
    table.insert(pool, game)
  end
  local granted = {}
  for _, pool in ipairs({ curated, launch, rest, japanese }) do
    while #granted < economy.STARTER_GAMES and #pool > 0 do
      local game = table.remove(pool, random(#pool))
      state.owned[game.id] = true
      table.insert(granted, game)
    end
  end
  return granted
end

return economy

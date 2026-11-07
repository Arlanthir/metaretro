local economy = require("core.economy")
local json = require("lib.json")

local achievements = {}

local function earned(date)
  return type(date) == "string" and date ~= ""
end

-- Unlocks from before `since` (both "YYYY-MM-DD HH:MM:SS", UTC) pay a reduced rate.
local function rate(date, since)
  return date >= since and 1 or economy.PAST_ACHIEVEMENT_RATE
end

-- Pays for the unlocks in a RetroAchievements game progress response that haven't been paid yet.
-- Each achievement pays once for its unlock and once more for the hardcore bonus.
function achievements.credit(state, progress, since)
  local coins = 0
  for _, achievement in pairs(progress.Achievements or {}) do
    local id = tostring(achievement.ID)
    local paid = state.seenAchievements[id]
    local points = tonumber(achievement.Points) or 0
    if earned(achievement.DateEarned) and not paid then
      coins = coins + economy.achievementEarnings(points, false) * rate(achievement.DateEarned, since)
      paid = "softcore"
    end
    if earned(achievement.DateEarnedHardcore) and paid ~= "hardcore" then
      local bonus = economy.achievementEarnings(points, true) - economy.achievementEarnings(points, false)
      coins = coins + bonus * rate(achievement.DateEarnedHardcore, since)
      paid = "hardcore"
    end
    state.seenAchievements[id] = paid
  end
  coins = math.floor(coins + 0.5)
  state.wallet = state.wallet + coins
  if progress.ID then
    local gameId = tostring(progress.ID)
    state.achievementCoins[gameId] = (state.achievementCoins[gameId] or 0) + coins
  end
  return coins
end

-- Games scraped with RetroAchievements' ROM hash but no game id get the id from RetroAchievements'
-- per-console game lists. The cache is { fetched, ids }: fetched maps a RetroAchievements console
-- id (as a string) to when its list was fetched (epoch), and ids maps a lowercase ROM hash to a
-- game id. It's saved as plain lines ("fetched <console> <epoch>", "<hash> <id>"), which are much
-- cheaper than JSON to write on the device.
achievements.ID_CACHE = "cheevos.txt"
-- New achievement sets come out all the time, so a console's list is fetched again after this.
achievements.ID_LIST_DAYS = 7

function achievements.decodeIdCache(text)
  local cache = { fetched = {}, ids = {} }
  for line in (text or ""):gmatch("[^\n]+") do
    local console, at = line:match("^fetched (%d+) (%d+)$")
    if console then
      cache.fetched[console] = tonumber(at)
    else
      local hash, id = line:match("^(%x+) (%d+)$")
      if hash then cache.ids[hash] = tonumber(id) end
    end
  end
  return cache
end

function achievements.encodeIdCache(cache)
  local lines = {}
  for console, at in pairs(cache.fetched) do
    lines[#lines + 1] = "fetched " .. console .. " " .. at
  end
  for hash, id in pairs(cache.ids) do
    lines[#lines + 1] = hash .. " " .. id
  end
  return table.concat(lines, "\n") .. "\n"
end

-- Game ids by lowercase ROM hash, from an API_GetGameList response with hashes (h=1); nil if unreadable.
function achievements.hashIds(body)
  local ok, list = pcall(json.decode, body or "")
  if not ok or type(list) ~= "table" then return nil end
  local ids = {}
  for _, game in ipairs(list) do
    for _, hash in ipairs(type(game.Hashes) == "table" and game.Hashes or {}) do
      ids[hash:lower()] = tonumber(game.ID)
    end
  end
  return ids
end

-- Fills in each game's missing cheevosId from its hash. Returns the games it found ids for.
function achievements.resolveIds(games, ids)
  local found = {}
  for _, game in ipairs(games) do
    local id = not game.cheevosId and game.cheevosHash and ids[game.cheevosHash]
    if id then
      game.cheevosId = id
      table.insert(found, game)
    end
  end
  return found
end

-- RetroAchievements console ids whose game list is worth fetching: a game of theirs has a hash but
-- no id, and the list is missing or older than ID_LIST_DAYS. `consoleOf(systemId)` gives the
-- console id (nil for systems without achievements).
function achievements.consolesToRefresh(games, fetched, consoleOf, now)
  local wanted, list = {}, {}
  for _, game in ipairs(games) do
    local console = not game.cheevosId and game.cheevosHash and consoleOf(game.system)
    local at = console and fetched[tostring(console)]
    if console and not wanted[console] and (not at or now - at > achievements.ID_LIST_DAYS * 86400) then
      wanted[console] = true
      table.insert(list, console)
    end
  end
  table.sort(list)
  return list
end

return achievements

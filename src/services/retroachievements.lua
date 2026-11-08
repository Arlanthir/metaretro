-- Checks played games' RetroAchievements progress and pays for unlocks (see core/achievements.lua).
local achievements = require("core.achievements")
local catalog = require("core.catalog")
local consoles = require("core.consoles")
local http = require("services.http")
local json = require("lib.json")
local log = require("core.log")

local retroachievements = {}

-- Lives next to retrotownstory.love so players can edit it on the SD card.
retroachievements.CONFIG = "retroachievements.txt"
retroachievements.PROGRESS_URL = "https://retroachievements.org/API/API_GetGameInfoAndUserProgress.php?g=%d&u=%s&y=%s"
-- A console's games that have achievements, with their ROM hashes.
retroachievements.GAME_LIST_URL = "https://retroachievements.org/API/API_GetGameList.php?i=%d&h=1&f=1&y=%s"

-- Reads "key=value" lines; a line with only a key-like value counts as the API key.
function retroachievements.parseConfig(text)
  local config = {}
  for line in (text or ""):gmatch("[^\r\n]+") do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key then
      config[key:lower()] = value
    elseif line:match("^%s*%w+%s*$") then
      config.apikey = line:match("%w+")
    end
  end
  return config
end

local function readConfig()
  local file = io.open(love.filesystem.getSourceBaseDirectory() .. "/" .. retroachievements.CONFIG, "r")
  if not file then return nil end
  local text = file:read("*a")
  file:close()
  return retroachievements.parseConfig(text)
end

local function urlEncode(text)
  return (text:gsub("[^%w%-_%.~]", function(c) return ("%%%02X"):format(c:byte()) end))
end

-- Owned games played since the last launch get their achievements checked at the next sync.
-- Games with only a ROM hash wait for the sync to look up their id.
function retroachievements.queue(state, played)
  for _, game in ipairs(played) do
    if not state.owned[game.id] then
      log("retroachievements: played %s, not owned", game.name)
    elseif not game.cheevosId and game.cheevosHash then
      log("retroachievements: played %s, queued its ROM hash to look up its id", game.name)
      state.pendingAchievementHashes[game.cheevosHash] = true
    elseif not game.cheevosId then
      log("retroachievements: played %s, no RetroAchievements id or hash in its metadata", game.name)
    else
      log("retroachievements: played %s, queued game %d", game.name, game.cheevosId)
      state.pendingAchievementGames[tostring(game.cheevosId)] = true
    end
  end
end

-- Tracking counts from the first game session launched from the game (an epoch), or from now without sessions.
-- Times are "YYYY-MM-DD HH:MM:SS" in UTC, like RetroAchievements' dates, so they compare as strings.
function retroachievements.trackingSince(current, firstSession, now)
  local since = current ~= "" and current or os.date("!%Y-%m-%d %H:%M:%S", now)
  local first = firstSession and os.date("!%Y-%m-%d %H:%M:%S", firstSession)
  return first and first < since and first or since
end

-- Fetches every pending game in the background; games that fail (e.g. offline) stay pending.
-- First, owned consoles with games that have a ROM hash but no id get their game lists (see
-- core/achievements), which can turn pending hashes into games to check.
-- `firstSession` is the start epoch of the first game session launched from the game, if any.
function retroachievements.sync(app, firstSession)
  local state = app.state
  local config = readConfig()
  local credentials = app.backend.raCredentials and app.backend.raCredentials()
  local username = config and (config.username or credentials and credentials.username)
  if not (config and config.apikey and username) then
    log("retroachievements: no API key or username in %s, skipping", retroachievements.CONFIG)
    return
  end
  state.achievementsSince = retroachievements.trackingSince(state.achievementsSince, firstSession, os.time())
  app:persist()

  local total = 0
  local function check(gameId)
    http.get(retroachievements.PROGRESS_URL:format(tonumber(gameId), urlEncode(username), urlEncode(config.apikey)), function(body)
      local ok, progress = pcall(json.decode, body or "")
      if not ok or type(progress) ~= "table" or type(progress.Achievements) ~= "table" then
        log("retroachievements: couldn't check game %s, will retry next launch", gameId)
        return
      end
      local coins = achievements.credit(state, progress, state.achievementsSince)
      state.pendingAchievementGames[gameId] = nil
      app:persist()
      log("retroachievements: game %s paid %d coins", gameId, coins)
      total = total + coins
      if coins > 0 then
        app:announce(("+%d coins from achievements"):format(total))
      end
    end)
  end

  -- Pending hashes the cache already knows become games to check.
  local cache = app.cheevos
  local function promoteHashes()
    for hash in pairs(state.pendingAchievementHashes) do
      local id = cache.ids[hash]
      if id then
        state.pendingAchievementHashes[hash] = nil
        state.pendingAchievementGames[tostring(id)] = true
        log("retroachievements: ROM hash %s is game %d", hash, id)
      end
    end
  end
  promoteHashes()

  local count = 0
  for _ in pairs(state.pendingAchievementGames) do count = count + 1 end
  log("retroachievements: checking %d games as %s, counting unlocks since %s", count, username, state.achievementsSince)
  for gameId in pairs(state.pendingAchievementGames) do check(gameId) end

  local games = catalog.allGames(app.backend)
  local inLibrary = {}
  for _, game in ipairs(games) do
    if game.cheevosHash then inLibrary[game.cheevosHash] = true end
  end
  -- Only owned consoles' lists: every game that can show a trophy (collection, stores, billboards,
  -- TV, villagers) is on one. A console bought now gets its list at the next start.
  local function ownedConsoleOf(systemId)
    local console = state.ownedConsoles[systemId] and consoles.get(systemId)
    return console and console.ra
  end
  local wanted = achievements.consolesToRefresh(games, cache.fetched, ownedConsoleOf, os.time())
  if #wanted == 0 then
    -- Hashes with no id in fresh lists belong to games without achievements.
    if next(state.pendingAchievementHashes) then
      state.pendingAchievementHashes = {}
      app:persist()
    end
    return
  end
  log("retroachievements: looking up ids by ROM hash on %d consoles", #wanted)
  local remaining = #wanted
  for _, console in ipairs(wanted) do
    http.get(retroachievements.GAME_LIST_URL:format(console, urlEncode(config.apikey)), function(ids)
      remaining = remaining - 1
      if ids then
        cache.fetched[tostring(console)] = os.time()
        for hash, id in pairs(ids) do
          if inLibrary[hash] then cache.ids[hash] = id end
        end
        local found = achievements.resolveIds(games, ids)
        log("retroachievements: console %d gave ids to %d games", console, #found)
        local before = {}
        for gameId in pairs(state.pendingAchievementGames) do before[gameId] = true end
        -- Owned games that only now have an id have never had their unlocks checked.
        for _, game in ipairs(found) do
          if state.owned[game.id] then state.pendingAchievementGames[tostring(game.cheevosId)] = true end
        end
        promoteHashes()
        for gameId in pairs(state.pendingAchievementGames) do
          if not before[gameId] then check(gameId) end
        end
      else
        log("retroachievements: couldn't get console %d's game list, will retry next launch", console)
      end
      -- Hashes still waiting are looked up from the cache again at the next sync, so this doesn't
      -- need to save the (large) save file.
      if remaining == 0 then
        love.filesystem.write(achievements.ID_CACHE, achievements.encodeIdCache(cache))
      end
    end, "core.achievements:hashIds")
  end
end

return retroachievements

-- Checks played games' RetroAchievements progress and pays for unlocks (see core/achievements.lua).
local achievements = require("core.achievements")
local http = require("services.http")
local json = require("lib.json")
local log = require("core.log")

local retroachievements = {}

-- Lives next to metaretro.love so players can edit it on the SD card.
retroachievements.CONFIG = "retroachievements.txt"
retroachievements.PROGRESS_URL = "https://retroachievements.org/API/API_GetGameInfoAndUserProgress.php?g=%d&u=%s&y=%s"

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
function retroachievements.queue(state, played)
  for _, game in ipairs(played) do
    if not state.owned[game.id] then
      log("retroachievements: played %s, not owned", game.name)
    elseif not game.cheevosId then
      log("retroachievements: played %s, no RetroAchievements id in its metadata", game.name)
    else
      log("retroachievements: played %s, queued game %d", game.name, game.cheevosId)
      state.pendingAchievementGames[tostring(game.cheevosId)] = true
    end
  end
end

-- Tracking counts from Metaretro's first game session (an epoch), or from now without sessions.
-- Times are "YYYY-MM-DD HH:MM:SS" in UTC, like RetroAchievements' dates, so they compare as strings.
function retroachievements.trackingSince(current, firstSession, now)
  local since = current ~= "" and current or os.date("!%Y-%m-%d %H:%M:%S", now)
  local first = firstSession and os.date("!%Y-%m-%d %H:%M:%S", firstSession)
  return first and first < since and first or since
end

-- Fetches every pending game in the background; games that fail (e.g. offline) stay pending.
-- `firstSession` is the start epoch of Metaretro's first game session, if any.
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
  local count = 0
  for _ in pairs(state.pendingAchievementGames) do count = count + 1 end
  log("retroachievements: checking %d games as %s, counting unlocks since %s", count, username, state.achievementsSince)
  local total = 0
  for gameId in pairs(state.pendingAchievementGames) do
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
end

return retroachievements

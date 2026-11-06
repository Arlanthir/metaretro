local json = require("lib.json")
local economy = require("core.economy")

local save = {}

save.VERSION = 1
save.FILE = "save.json"

function save.defaults()
  return {
    version = save.VERSION,
    initialized = false,
    wallet = economy.STARTER_WALLET,
    owned = {},
    ownedConsoles = {},
    lots = {},
    offers = {},
    seenAchievements = {}, -- achievement id -> "softcore" or "hardcore" once paid
    achievementCoins = {}, -- RetroAchievements game id -> coins paid for its achievements
    achievementsSince = "", -- UTC time tracking started; earlier unlocks pay less
    pendingAchievementGames = {}, -- RetroAchievements game ids to check at the next sync
    creditedGametime = {},
    lastPlayed = {}, -- game id -> epoch of the last play Metaretro noticed
    consumedSessions = 0,
    settings = {},
  }
end

function save.migrate(data)
  local state = save.defaults()
  if type(data) ~= "table" then
    return state
  end
  for key, value in pairs(data) do
    if type(value) == type(state[key]) then
      state[key] = value
    end
  end
  state.version = save.VERSION
  return state
end

-- `fs` needs read(path) -> contents|nil and write(path, contents); love.filesystem fits.
function save.load(fs)
  local contents = fs.read(save.FILE)
  if not contents then
    return save.defaults()
  end
  local ok, data = pcall(json.decode, contents)
  return save.migrate(ok and data or nil)
end

function save.write(fs, state)
  return fs.write(save.FILE, json.encode(state))
end

return save

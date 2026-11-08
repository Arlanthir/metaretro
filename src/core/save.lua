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
    offers = {},
    seenAchievements = {}, -- achievement id -> "softcore" or "hardcore" once paid
    achievementCoins = {}, -- RetroAchievements game id -> coins paid for its achievements
    achievementsSince = "", -- UTC time tracking started; earlier unlocks pay less
    pendingAchievementGames = {}, -- RetroAchievements game ids to check at the next sync
    pendingAchievementHashes = {}, -- ROM hashes of played games whose id is still being looked up
    creditedGametime = {},
    lastPlayed = {}, -- game id -> epoch of the last play the game noticed
    consumedSessions = 0,
    settings = {},
    player = "boy", -- the look chosen in the intro: "boy" or "girl"
    introDone = false,
    giftOffered = false, -- Professor Cork has offered a console from his table
    giftReceived = false,
    giftConsole = "", -- the system id of the console he gave, if any
    cabinetGame = "", -- the arcade game last played or bought: its art adorns the cabinet at home
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
  -- Saves from before the intro already have their consoles: no intro, and no gift to wait for.
  if data.introDone == nil and data.initialized then
    state.introDone, state.giftOffered, state.giftReceived = true, true, true
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

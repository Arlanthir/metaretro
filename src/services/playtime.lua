local economy = require("core.economy")

local playtime = {}

playtime.LOG = "sessions.log"

-- The launcher appends one "<game id>\t<start epoch>\t<end epoch>" line per session.
function playtime.parseLog(text)
  local sessions = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local id, start, finish = line:match("^(.-)\t(%d+)\t(%d+)$")
    if id then
      table.insert(sessions, { id = id, start = tonumber(start), seconds = tonumber(finish) - tonumber(start) })
    end
  end
  return sessions
end

-- Each game's logged play from session `first` on (default: all of it), as EmulationStation counts
-- play: { [id] = { count, seconds, last } }. Sessions shorter than MIN_SECONDS add no time, and
-- `last` is when the latest one ended.
playtime.MIN_SECONDS = 10
function playtime.totals(sessions, first)
  local totals = {}
  for i = first or 1, #sessions do
    local session = sessions[i]
    local total = totals[session.id] or { count = 0, seconds = 0, last = 0 }
    total.count = total.count + 1
    if session.seconds >= playtime.MIN_SECONDS then total.seconds = total.seconds + session.seconds end
    total.last = math.max(total.last, session.start + session.seconds)
    totals[session.id] = total
  end
  return totals
end

-- Returns the coins earned and the games played since the last credit.
-- Play shows up in the game's session log and, on backends that track it, in the game's gametime
-- (which also covers play outside the game); each game pays for whichever shows more.
-- A game seen for the first time sets its gametime baseline instead of paying out its whole history.
function playtime.credit(state, backend, games, sessions)
  local fromSessions = {}
  for i = state.consumedSessions + 1, #sessions do
    local session = sessions[i]
    fromSessions[session.id] = (fromSessions[session.id] or 0) + economy.playEarnings(session.seconds)
  end
  local earned, played = 0, {}
  for _, game in ipairs(games) do
    local grown = 0
    if backend.tracksGametime then
      local credited = state.creditedGametime[game.id] or game.gametime
      grown = game.gametime - credited
      state.creditedGametime[game.id] = math.max(credited, game.gametime)
    end
    if fromSessions[game.id] or grown > 0 then
      earned = earned + math.max(fromSessions[game.id] or 0, economy.playEarnings(grown))
      table.insert(played, game)
    end
  end
  state.consumedSessions = #sessions
  state.wallet = state.wallet + earned
  return earned, played
end

return playtime

local economy = require("core.economy")

local playtime = {}

playtime.LOG = "sessions.log"

-- Metaretro.sh appends one "<game id>\t<start epoch>\t<end epoch>" line per session.
function playtime.parseLog(text)
  local sessions = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local id, start, finish = line:match("^(.-)\t(%d+)\t(%d+)$")
    if id then
      table.insert(sessions, { id = id, seconds = tonumber(finish) - tonumber(start) })
    end
  end
  return sessions
end

-- A game seen for the first time sets its baseline instead of paying out its whole history.
function playtime.credit(state, backend, games, sessions)
  local earned = 0
  if backend.tracksGametime then
    for _, game in ipairs(games) do
      local credited = state.creditedGametime[game.id] or game.gametime
      earned = earned + economy.playEarnings(game.gametime - credited)
      state.creditedGametime[game.id] = math.max(credited, game.gametime)
    end
  else
    for i = state.consumedSessions + 1, #sessions do
      earned = earned + economy.playEarnings(sessions[i].seconds)
    end
  end
  state.consumedSessions = #sessions
  state.wallet = state.wallet + earned
  return earned
end

return playtime

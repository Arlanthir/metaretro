-- Reads the game library and the save on a background thread (see libraryworker.lua), so the
-- title screen stays responsive while the gamelists are parsed.
local library = {}

local thread, channel
local games = {}

function library.start(backendName)
  channel = love.thread.getChannel("library")
  thread = love.thread.newThread("services/libraryworker.lua")
  thread:start(backendName)
end

-- Takes at most one message per call (turning a big one into Lua tables takes a while on the
-- device). Returns the listing once it's complete:
-- { systems, games = { [systemId] = games }, saved = the save's state, cheevos = the RetroAchievements
-- id cache (see core/achievements), timings, seconds }.
function library.poll()
  local err = thread:getError()
  if err then error("library worker: " .. err) end
  local message = channel:pop()
  if not message then return nil end
  if not message.done then
    games[message.system] = message.games
    return nil
  end
  message.games = games
  return message
end

return library

-- Every backend module returns a table with:
--   name                  string
--   tracksGametime        boolean, true when games carry a gametime the frontend keeps up to date
--   detect()              -> boolean, whether this backend applies to the running system
--   listSystems()         -> { { id, name }, ... }
--   listGames(systemId)   -> { game, ... } where game has at least id, system, path, name
--   useListing(listing)   takes { systems, games = { [systemId] = games } } as read on the library
--                         thread (services/library), instead of reading them again
--   launchCommand(game, controllers)
--                         -> shell command that runs the game and blocks until it exits;
--                            controllers is { { index, guid, name, buttons, hats, axes }, ... }
--   playStats(game)       -> { playcount, gametime (seconds) }
--   raCredentials()       -> { username } or nil

local CANDIDATES = { "backends.knulli", "backends.mock" }

local backend = {}

function backend.select(forced)
  if forced then
    return require("backends." .. forced)
  end
  for _, moduleName in ipairs(CANDIDATES) do
    local candidate = require(moduleName)
    if candidate.detect() then
      return candidate
    end
  end
end

return backend

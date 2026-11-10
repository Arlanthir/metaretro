local economy = require("core.economy")
local genres = require("core.genres")
local peripherals = require("core.peripherals")

local catalog = {}

function catalog.gameId(system, path)
  return system .. ":" .. path
end

function catalog.byName(a, b)
  return a.name:lower() < b.name:lower()
end
local byName = catalog.byName

-- Whether the player's settings show `game`: games that need a peripheral and Japanese-only games
-- are hidden unless the settings show them.
function catalog.isShown(game, settings)
  settings = settings or {}
  return (settings.showPeripheral or not peripherals.needsOne(game))
    and (settings.showJapanese or not economy.isJapaneseOnly(game))
end
local isShown = catalog.isShown

-- Returns { systems = {sorted system entries}, bySystem = { [id] = { owned = {...}, locked = {...} } } }.
-- `include(systemId)` optionally limits which systems appear, and games `settings` hide are left out.
-- Each game gets its genre `category`.
function catalog.build(backend, state, include, settings)
  local result = { systems = {}, bySystem = {} }
  for _, system in ipairs(backend.listSystems()) do
    local games = (not include or include(system.id)) and backend.listGames(system.id) or {}
    local owned, locked = {}, {}
    for _, game in ipairs(games) do
      if isShown(game, settings) then
        game.category = game.category or genres.categorize(game.genre)
        table.insert(state.owned[game.id] and owned or locked, game)
      end
    end
    if #owned + #locked > 0 then
      table.sort(owned, byName)
      table.sort(locked, byName)
      table.insert(result.systems, system)
      result.bySystem[system.id] = { owned = owned, locked = locked }
    end
  end
  table.sort(result.systems, function(a, b) return a.name < b.name end)
  return result
end

-- Every game in the library; with `settings`, only the ones they show.
function catalog.allGames(backend, settings)
  local games = {}
  for _, system in ipairs(backend.listSystems()) do
    for _, game in ipairs(backend.listGames(system.id)) do
      if not settings or isShown(game, settings) then table.insert(games, game) end
    end
  end
  return games
end

-- Returns how many games are owned and how many there are in total, across all systems.
function catalog.progress(built)
  local owned, total = 0, 0
  for _, games in pairs(built.bySystem) do
    owned = owned + #games.owned
    total = total + #games.owned + #games.locked
  end
  return owned, total
end

function catalog.ownedSystems(built)
  local systems = {}
  for _, system in ipairs(built.systems) do
    if #built.bySystem[system.id].owned > 0 then
      table.insert(systems, system)
    end
  end
  return systems
end

return catalog

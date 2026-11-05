local catalog = {}

function catalog.gameId(system, path)
  return system .. ":" .. path
end

local function byName(a, b)
  return a.name:lower() < b.name:lower()
end

-- Returns { systems = {sorted system entries}, bySystem = { [id] = { owned = {...}, locked = {...} } } }.
function catalog.build(backend, state)
  local result = { systems = {}, bySystem = {} }
  for _, system in ipairs(backend.listSystems()) do
    local owned, locked = {}, {}
    for _, game in ipairs(backend.listGames(system.id)) do
      table.insert(state.owned[game.id] and owned or locked, game)
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

function catalog.allGames(backend)
  local games = {}
  for _, system in ipairs(backend.listSystems()) do
    for _, game in ipairs(backend.listGames(system.id)) do
      table.insert(games, game)
    end
  end
  return games
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

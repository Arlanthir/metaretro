local catalog = require("core.catalog")
local save = require("core.save")

local function fakeBackend(library)
  local systems = {}
  for _, entry in ipairs(library) do
    table.insert(systems, { id = entry.id, name = entry.name })
  end
  return {
    listSystems = function() return systems end,
    listGames = function(systemId)
      for _, entry in ipairs(library) do
        if entry.id == systemId then
          local games = {}
          for _, name in ipairs(entry.games) do
            table.insert(games, { id = catalog.gameId(systemId, name), system = systemId, path = name, name = name })
          end
          return games
        end
      end
      return {}
    end,
  }
end

describe("catalog", function()
  local backend = fakeBackend({
    { id = "snes", name = "Super Nintendo", games = { "zelda", "Mario", "contra" } },
    { id = "empty", name = "Empty", games = {} },
    { id = "gba", name = "Game Boy Advance", games = { "metroid" } },
  })

  it("splits games into owned and locked, sorted by name", function()
    local state = save.defaults()
    state.owned[catalog.gameId("snes", "zelda")] = true
    local built = catalog.build(backend, state)

    local snes = built.bySystem.snes
    assert.same({ "zelda" }, { snes.owned[1].name })
    assert.same({ "contra", "Mario" }, { snes.locked[1].name, snes.locked[2].name })
  end)

  it("skips empty systems and sorts by name", function()
    local built = catalog.build(backend, save.defaults())
    assert.same({ "Game Boy Advance", "Super Nintendo" }, { built.systems[1].name, built.systems[2].name })
    assert.is_nil(built.bySystem.empty)
  end)

  it("lists only systems with owned games", function()
    local state = save.defaults()
    state.owned[catalog.gameId("gba", "metroid")] = true
    local owned = catalog.ownedSystems(catalog.build(backend, state))
    assert.equal(1, #owned)
    assert.equal("gba", owned[1].id)
  end)

  it("leaves out systems the include filter rejects", function()
    local built = catalog.build(backend, save.defaults(), function(id) return id ~= "gba" end)
    assert.same({ "Super Nintendo" }, { built.systems[1].name, built.systems[2] and built.systems[2].name })
    assert.is_nil(built.bySystem.gba)
  end)

  it("flattens all games", function()
    assert.equal(4, #catalog.allGames(backend))
  end)
end)

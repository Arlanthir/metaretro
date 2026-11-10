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
          for _, spec in ipairs(entry.games) do
            -- A name, or a table of the game's fields with its name.
            local game = type(spec) == "table" and spec or { name = spec }
            game.id, game.system, game.path = catalog.gameId(systemId, game.name), systemId, game.name
            table.insert(games, game)
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

  it("counts owned games out of all games", function()
    local state = save.defaults()
    state.owned[catalog.gameId("snes", "zelda")] = true
    state.owned[catalog.gameId("gba", "metroid")] = true
    assert.same({ 2, 4 }, { catalog.progress(catalog.build(backend, state)) })
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

describe("catalog settings", function()
  local backend = fakeBackend({
    { id = "nes", name = "NES", games = {
      "Mario", { name = "Duck Hunt" }, { name = "Gumshoe", genre = "Lightgun Shooter" },
      { name = "Kirby", lang = "jp" },
    } },
    { id = "pcengine", name = "PC Engine", games = { { name = "Bomberman", lang = "jp" } } },
  })

  local function names(games)
    local list = {}
    for _, game in ipairs(games) do table.insert(list, game.name) end
    table.sort(list)
    return list
  end

  it("hides games that need a peripheral and Japanese-only games by default", function()
    local built = catalog.build(backend, save.defaults())
    assert.same({ "Mario" }, names(built.bySystem.nes.locked))
    assert.is_nil(built.bySystem.pcengine) -- nothing left to show
  end)

  it("shows each group when its setting is on", function()
    local state = save.defaults()
    state.settings.showPeripheral = true
    assert.same({ "Duck Hunt", "Gumshoe", "Mario" }, names(catalog.build(backend, state).bySystem.nes.locked))
    state.settings = { showJapanese = true }
    assert.same({ "Kirby", "Mario" }, names(catalog.build(backend, state).bySystem.nes.locked))
  end)

  it("hides owned games too", function()
    local state = save.defaults()
    state.owned[catalog.gameId("nes", "Kirby")] = true
    assert.same({}, catalog.build(backend, state).bySystem.nes.owned)
  end)

  it("filters all games only when given settings", function()
    assert.equal(5, #catalog.allGames(backend))
    assert.same({ "Mario" }, names(catalog.allGames(backend, {})))
  end)
end)

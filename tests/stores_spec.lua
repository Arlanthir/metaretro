local save = require("core.save")
local stores = require("core.stores")

local function game(system, name, category)
  return { id = system .. ":" .. name, system = system, name = name, category = category }
end

local timeline = {
  { id = "nes", short = "NES" },
  { id = "snes", short = "SNES" },
}
local built = {
  bySystem = {
    nes = { owned = { game("nes", "Zelda", "adventure") }, locked = { game("nes", "Mario", "platform") } },
    snes = { owned = {}, locked = { game("snes", "Mario World", "platform"), game("snes", "F-Zero", "racing") } },
  },
}

local function ids(list)
  local result = {}
  for _, item in ipairs(list) do table.insert(result, item.id) end
  return result
end

describe("stores.list", function()
  it("lists owned consoles, then genres with games on those consoles", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    assert.same({ "nes", "genre:platform", "genre:adventure" }, ids(stores.list(state, built, timeline)))
  end)

  it("opens new genre stores when a console brings new genres", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    state.ownedConsoles.snes = true
    assert.same({ "nes", "snes", "genre:platform", "genre:adventure", "genre:racing" },
      ids(stores.list(state, built, timeline)))
  end)
end)

describe("stores.stock", function()
  it("sells a console's locked games", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    local nes = stores.list(state, built, timeline)[1]
    assert.same({ "nes:Mario" }, ids(stores.stock(nes, state, built, timeline)))
  end)

  it("sells a genre's locked games across owned consoles only, by name", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    local platform = { id = "genre:platform", kind = "genre", genre = { id = "platform" } }
    assert.same({ "nes:Mario" }, ids(stores.stock(platform, state, built, timeline)))
    state.ownedConsoles.snes = true
    assert.same({ "nes:Mario", "snes:Mario World" }, ids(stores.stock(platform, state, built, timeline)))
  end)
end)

describe("stores.offer", function()
  local manyGames = {}
  for i = 1, 12 do
    table.insert(manyGames, game("nes", ("Game %02d"):format(i), "platform"))
  end
  local bigBuilt = { bySystem = { nes = { owned = {}, locked = manyGames } } }
  local nesStore = { id = "nes", kind = "console", console = { id = "nes" } }
  local function first() return 1 end

  local function stateWithNes()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    return state
  end

  it("offers a few random games from the stock and reports the stock size", function()
    local state = stateWithNes()
    local games, rerolled, inStock = stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", first)
    assert.equal(stores.OFFER_SIZE, #games)
    assert.is_true(rerolled)
    assert.equal(12, inStock)
    assert.same({ "nes:Game 01", "nes:Game 02", "nes:Game 03", "nes:Game 04", "nes:Game 05" }, ids(games))
  end)

  it("keeps the same selection for the rest of the day", function()
    local state = stateWithNes()
    stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", first)
    local last = function(n) return n end
    local games, rerolled = stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", last)
    assert.is_false(rerolled)
    assert.same({ "nes:Game 01", "nes:Game 02", "nes:Game 03", "nes:Game 04", "nes:Game 05" }, ids(games))
  end)

  it("draws a new selection the next day", function()
    local state = stateWithNes()
    stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", first)
    local last = function(n) return n end
    local games, rerolled = stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-06", last)
    assert.is_true(rerolled)
    assert.same({ "nes:Game 08", "nes:Game 09", "nes:Game 10", "nes:Game 11", "nes:Game 12" }, ids(games))
  end)

  it("drops bought games from the day's selection without replacing them", function()
    local state = stateWithNes()
    stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", first)
    manyGames[1].bought = true
    local remaining = {}
    for i = 2, #manyGames do remaining[#remaining + 1] = manyGames[i] end
    local afterPurchase = { bySystem = { nes = { owned = { manyGames[1] }, locked = remaining } } }
    local games = stores.offer(nesStore, state, afterPurchase, timeline, "2026-11-05", first)
    assert.same({ "nes:Game 02", "nes:Game 03", "nes:Game 04", "nes:Game 05" }, ids(games))
  end)

  it("offers everything when the stock is small", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    local games = stores.offer(nesStore, state, built, timeline, "2026-11-05", first)
    assert.same({ "nes:Mario" }, ids(games))
  end)
end)

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
  local minimum = stores.MIN_GENRE_GAMES
  before_each(function() stores.MIN_GENRE_GAMES = 1 end)
  after_each(function() stores.MIN_GENRE_GAMES = minimum end)

  it("only opens genre stores with enough games across owned consoles", function()
    stores.MIN_GENRE_GAMES = 2
    local state = save.defaults()
    state.ownedConsoles.nes = true
    state.ownedConsoles.snes = true
    assert.same({ "nes", "snes", "genre:platform" }, ids(stores.list(state, built, timeline)))
  end)

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

  describe("with missing ROMs", function()
    local roms = require("core.roms")
    local missing = {}
    before_each(function()
      missing = {}
      roms.useCheck(function(g) return not missing[g.id] end)
    end)
    after_each(function() roms.useCheck(nil) end)

    it("draws another game in place of one whose ROM is missing", function()
      missing["nes:Game 02"] = true
      local games = stores.offer(nesStore, stateWithNes(), bigBuilt, timeline, "2026-11-05", first)
      assert.same({ "nes:Game 01", "nes:Game 03", "nes:Game 04", "nes:Game 05", "nes:Game 06" }, ids(games))
    end)

    -- A console store of `total` games where the first `deleted` have lost their ROMs, over two
    -- visits and the next day: always the same present games, never a missing one.
    local function storeOf(total, deleted)
      local stock = {}
      for i = 1, total do
        stock[i] = game("nes", ("Game %02d"):format(i), "platform")
        if i <= deleted then missing[stock[i].id] = true end
      end
      local storeBuilt = { bySystem = { nes = { owned = {}, locked = stock } } }
      local state = stateWithNes()
      local random = function(n) return math.random(n) end
      local today, again, inStock = stores.offer(nesStore, state, storeBuilt, timeline, "2026-11-05", random)
      local secondVisit, changed = stores.offer(nesStore, state, storeBuilt, timeline, "2026-11-05", random)
      local nextDay = stores.offer(nesStore, state, storeBuilt, timeline, "2026-11-06", random)
      assert.same(ids(today), ids(secondVisit))
      assert.is_false(changed)
      return ids(today), ids(nextDay), inStock
    end

    it("fills the offer from the games that are left: 10 games, 5 deleted", function()
      local today, nextDay, inStock = storeOf(10, 5)
      local present = { "nes:Game 06", "nes:Game 07", "nes:Game 08", "nes:Game 09", "nes:Game 10" }
      assert.same(present, today)
      assert.same(present, nextDay)
      assert.equal(5, inStock) -- a small store checks all its stock, so the count is exact
    end)

    it("offers the one game left: 5 games, 4 deleted", function()
      local today, nextDay, inStock = storeOf(5, 4)
      assert.same({ "nes:Game 05" }, today)
      assert.equal(1, inStock)
      assert.same({ "nes:Game 05" }, nextDay)
    end)

    it("offers nothing when every ROM is gone: 5 games, all deleted", function()
      local today, nextDay, inStock = storeOf(5, 5)
      assert.same({}, today)
      assert.same({}, nextDay)
      assert.equal(0, inStock)
    end)

    it("keeps the count after a restart the same day, without checking the missing game again", function()
      local stock = {}
      for i = 1, 6 do stock[i] = game("nes", ("Game %02d"):format(i), "platform") end
      missing["nes:Game 01"] = true
      local storeBuilt = { bySystem = { nes = { owned = {}, locked = stock } } }
      local state = stateWithNes()
      local _, _, inStock = stores.offer(nesStore, state, storeBuilt, timeline, "2026-11-05", first)
      assert.equal(5, inStock)
      -- A new run, with nothing known yet: the offered games are checked again, the missing one isn't.
      roms.useCheck(function(g)
        assert.are_not.equal("nes:Game 01", g.id)
        return true
      end)
      local games, changed, again = stores.offer(nesStore, state, storeBuilt, timeline, "2026-11-05", first)
      assert.equal(5, #games)
      assert.is_false(changed)
      assert.equal(5, again)
    end)

    it("doesn't open a store whose every ROM is gone", function()
      local state = stateWithNes()
      state.ownedConsoles.snes = true
      missing["snes:Mario World"], missing["snes:F-Zero"] = true, true
      local open = {}
      for _, store in ipairs(stores.list(state, built, timeline, "2026-11-05", first)) do open[#open + 1] = store.id end
      assert.same({ "nes" }, open)
      -- Without a day, it's the stores there could be.
      assert.equal(2, #stores.list(state, built, timeline))
    end)

    it("replaces a game whose ROM went missing during the day", function()
      local state = stateWithNes()
      stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", first)
      missing["nes:Game 03"] = true
      roms.useCheck(function(g) return not missing[g.id] end) -- forget what was checked
      local games, changed = stores.offer(nesStore, state, bigBuilt, timeline, "2026-11-05", first)
      assert.is_true(changed)
      assert.same({ "nes:Game 01", "nes:Game 02", "nes:Game 04", "nes:Game 05", "nes:Game 06" }, ids(games))
    end)
  end)

  it("offers everything when the stock is small", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    local games = stores.offer(nesStore, state, built, timeline, "2026-11-05", first)
    assert.same({ "nes:Mario" }, ids(games))
  end)
end)

describe("stores.featured", function()
  local minimum = stores.MIN_GENRE_GAMES
  before_each(function() stores.MIN_GENRE_GAMES = 1 end)
  after_each(function() stores.MIN_GENRE_GAMES = minimum end)

  local function first() return 1 end

  it("picks games from different stores, the same all day", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    state.ownedConsoles.snes = true
    local ads = stores.featured(state, built, timeline, "2026-11-06", 2, first)
    assert.equal(2, #ads)
    assert.are_not.equal(ads[1].store.id, ads[2].store.id)
    assert.are_not.equal(ads[1].game.id, ads[2].game.id)
    local again = stores.featured(state, built, timeline, "2026-11-06", 2, first)
    assert.same({ ads[1].game.id, ads[2].game.id }, { again[1].game.id, again[2].game.id })
  end)

  it("returns fewer ads when there's little for sale", function()
    local state = save.defaults()
    assert.same({}, stores.featured(state, built, timeline, "2026-11-06", 2, first))
    state.ownedConsoles.nes = true
    stores.MIN_GENRE_GAMES = 100
    assert.equal(1, #stores.featured(state, built, timeline, "2026-11-06", 2, first))
  end)

  it("fills the rest from the same stores when there are fewer stores than ads", function()
    local state = save.defaults()
    state.ownedConsoles.snes = true
    stores.MIN_GENRE_GAMES = 100
    local ads = stores.featured(state, built, timeline, "2026-11-06", 2, first)
    assert.same({ "snes", "snes" }, { ads[1].store.id, ads[2].store.id })
    assert.are_not.equal(ads[1].game.id, ads[2].game.id)
  end)

  it("only features games that pass the filter", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    state.ownedConsoles.snes = true
    local ads = stores.featured(state, built, timeline, "2026-11-06", 3, first,
      function(game) return game.name == "F-Zero" end)
    assert.equal(1, #ads)
    assert.equal("F-Zero", ads[1].game.name)
  end)
end)

describe("stores.onSale", function()
  local minimum = stores.MIN_GENRE_GAMES
  before_each(function() stores.MIN_GENRE_GAMES = 1 end)
  after_each(function() stores.MIN_GENRE_GAMES = minimum end)

  local function first() return 1 end

  it("lists each game in today's picks once, under the first store selling it", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    state.ownedConsoles.snes = true
    local sale = stores.onSale(state, built, timeline, "2026-11-06", first)
    local names, storeOf = {}, {}
    for _, item in ipairs(sale) do
      table.insert(names, item.game.name)
      storeOf[item.game.name] = item.store.id
    end
    table.sort(names)
    assert.same({ "F-Zero", "Mario", "Mario World" }, names)
    assert.equal("nes", storeOf.Mario) -- also in the Platform store, which comes later
  end)

  it("only lists games that pass the filter", function()
    local state = save.defaults()
    state.ownedConsoles.snes = true
    local sale = stores.onSale(state, built, timeline, "2026-11-06", first, function(game) return game.name == "F-Zero" end)
    assert.equal(1, #sale)
    assert.equal("F-Zero", sale[1].game.name)
  end)
end)

describe("the GotX store", function()
  local winners = {}
  for i = 1, 8 do winners[i] = { title = "Winner " .. i } end
  local library = {}
  for i = 1, 8 do library[i] = game("nes", ("Game %02d"):format(i), "platform") end
  local other = game("snes", "Not a winner", "platform")

  local function builtWith(currentPicks)
    local gameOf, winnersOf = {}, {}
    for i, winner in ipairs(winners) do
      gameOf[winner] = library[i]
      winnersOf[library[i].id] = { winner }
    end
    return {
      bySystem = { nes = { owned = {}, locked = library }, snes = { owned = {}, locked = { other } } },
      gotx = { current = currentPicks, gameOf = gameOf, winnersOf = winnersOf, loans = {} },
    }
  end

  local function storeIn(list)
    for _, store in ipairs(list) do
      if store.kind == "gotx" then return store end
    end
  end

  it("opens when GotX winners for the owned consoles are for sale", function()
    local state = save.defaults()
    assert.is_nil(storeIn(stores.list(state, builtWith({}), timeline)))
    state.ownedConsoles.snes = true
    assert.is_nil(storeIn(stores.list(state, builtWith({}), timeline)))
    state.ownedConsoles.nes = true
    local store = storeIn(stores.list(state, builtWith({}), timeline))
    assert.equal("GotX Store", store.title)
    assert.equal(8, #stores.stock(store, state, builtWith({}), timeline))
  end)

  it("offers the current picks first, then random winners", function()
    local state = save.defaults()
    state.ownedConsoles.nes = true
    local built = builtWith({ winners[7], winners[3] })
    local store = storeIn(stores.list(state, built, timeline))
    local last = function(n) return n end -- the random draws take the end of the stock
    stores.offer(store, state, built, timeline, "2026-11-05", last)
    assert.same({ "nes:Game 07", "nes:Game 03", "nes:Game 08", "nes:Game 06", "nes:Game 05" }, state.offers.gotx.ids)
  end)
end)

local economy = require("core.economy")
local save = require("core.save")

local function game(fields)
  fields.id = fields.id or (fields.system or "snes") .. ":" .. (fields.path or "./game.zip")
  fields.system = fields.system or "snes"
  return fields
end

describe("economy.price", function()
  it("uses the system tier as base price", function()
    assert.equal(40, economy.price(game({ system = "nes" })))
    assert.equal(100, economy.price(game({ system = "psp" })))
  end)

  it("falls back to the default tier for unknown systems", function()
    assert.equal(60, economy.price(game({ system = "unknown" })))
  end)

  it("scales with rating and rounds to 5", function()
    assert.equal(45, economy.price(game({ system = "snes", rating = "0" })))
    assert.equal(75, economy.price(game({ system = "snes", rating = 1 })))
    assert.equal(75, economy.price(game({ system = "snes", rating = 5 })))
  end)
end)

describe("economy.playEarnings", function()
  it("pays per whole minute", function()
    assert.equal(0, economy.playEarnings(59))
    assert.equal(20, economy.playEarnings(10 * 60 + 30))
  end)

  it("caps a single session", function()
    assert.equal(economy.SESSION_CAP_MINUTES * economy.COINS_PER_MINUTE, economy.playEarnings(24 * 3600))
  end)

  it("ignores negative durations", function()
    assert.equal(0, economy.playEarnings(-100))
  end)
end)

describe("economy.achievementEarnings", function()
  it("multiplies hardcore unlocks", function()
    assert.equal(10, economy.achievementEarnings(10, false))
    assert.equal(10 * economy.HARDCORE_MULTIPLIER, economy.achievementEarnings(10, true))
  end)
end)

describe("economy.buy", function()
  local function stateOwning(...)
    local state = save.defaults()
    for _, system in ipairs({ ... }) do
      state.ownedConsoles[system] = true
    end
    return state
  end

  it("deducts the price and marks the game owned", function()
    local state = stateOwning("nes")
    local g = game({ system = "nes" })
    assert.is_true(economy.buy(state, g))
    assert.equal(economy.STARTER_WALLET - 40, state.wallet)
    assert.is_true(state.owned[g.id])
  end)

  it("refuses games for consoles the player doesn't own", function()
    local state = stateOwning("nes")
    assert.same({ false, "console not owned" }, { economy.buy(state, game({ system = "snes" })) })
    assert.equal(economy.STARTER_WALLET, state.wallet)
  end)

  it("refuses owned games and insufficient funds", function()
    local state = stateOwning("nes", "psx")
    local g = game({ system = "nes" })
    state.owned[g.id] = true
    assert.same({ false, "already owned" }, { economy.buy(state, g) })

    state.wallet = 10
    assert.same({ false, "not enough coins" }, { economy.buy(state, game({ system = "psx" })) })
    assert.equal(10, state.wallet)
  end)
end)

describe("economy.buyConsole", function()
  local snes = { id = "snes", generation = 4 }

  it("prices consoles by generation", function()
    assert.equal(4 * economy.CONSOLE_PRICE_PER_GENERATION, economy.consolePrice(snes))
  end)

  it("deducts the price and marks the console owned", function()
    local state = save.defaults()
    state.wallet = 1000
    assert.is_true(economy.buyConsole(state, snes))
    assert.equal(1000 - economy.consolePrice(snes), state.wallet)
    assert.is_true(state.ownedConsoles.snes)
    assert.same({ false, "already owned" }, { economy.buyConsole(state, snes) })
  end)

  it("refuses when the player can't afford it", function()
    local state = save.defaults()
    assert.same({ false, "not enough coins" }, { economy.buyConsole(state, snes) })
    assert.is_nil(state.ownedConsoles.snes)
  end)
end)

describe("economy.grantStarterPack", function()
  local function first(n) return 1 end

  it("prefers already played games", function()
    local state = save.defaults()
    local games = {}
    for i = 1, 6 do
      table.insert(games, game({ path = "./" .. i, playcount = i == 5 and 2 or 0 }))
    end
    local granted = economy.grantStarterPack(state, games, first)
    assert.equal(economy.STARTER_GAMES, #granted)
    assert.equal(games[5], granted[1])
    assert.is_true(state.owned[games[5].id])
  end)

  it("only picks from the given systems", function()
    local state = save.defaults()
    local games = {
      game({ system = "dos", path = "./played", playcount = 5 }),
      game({ system = "gba", path = "./a" }),
      game({ system = "gba", path = "./b" }),
    }
    local granted = economy.grantStarterPack(state, games, first, { gba = true })
    assert.equal(2, #granted)
    assert.is_nil(state.owned[games[1].id])
  end)

  it("grants everything when the library is small", function()
    local state = save.defaults()
    local granted = economy.grantStarterPack(state, { game({ path = "./only" }) }, first)
    assert.equal(1, #granted)
  end)
end)

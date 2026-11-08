local economy = require("core.economy")
local save = require("core.save")

local function game(fields)
  fields.id = fields.id or (fields.system or "snes") .. ":" .. (fields.path or "./game.zip")
  fields.system = fields.system or "snes"
  return fields
end

describe("economy.price", function()
  it("bases the price on the console generation", function()
    assert.equal(20, economy.price(game({ system = "atari2600" })))
    assert.equal(40, economy.price(game({ system = "nes" })))
    assert.equal(100, economy.price(game({ system = "dreamcast" })))
    assert.equal(80, economy.price(game({ system = "gba" }))) -- a handheld, a generation down
    assert.equal(100, economy.price(game({ system = "psp" })))
  end)

  it("treats unknown systems as 4th generation", function()
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
    local perPoint = economy.COINS_PER_RA_POINT
    assert.equal(10 * perPoint, economy.achievementEarnings(10, false))
    assert.equal(10 * perPoint * economy.HARDCORE_MULTIPLIER, economy.achievementEarnings(10, true))
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

describe("economy.sell", function()
  it("buys an owned game back for half its price", function()
    local state = save.defaults()
    local g = game({ system = "nes" })
    state.owned[g.id] = true
    assert.equal(20, economy.sellPrice(g))
    assert.same({ true, 20 }, { economy.sell(state, g) })
    assert.equal(economy.STARTER_WALLET + 20, state.wallet)
    assert.is_nil(state.owned[g.id])
  end)

  it("rounds odd prices down and refuses games the player doesn't own", function()
    local state = save.defaults()
    local g = game({ system = "snes", rating = "0" })
    assert.equal(math.floor(economy.price(g) / 2), economy.sellPrice(g))
    assert.equal(22, economy.sellPrice(g))
    assert.same({ false, "not owned" }, { economy.sell(state, g) })
    assert.equal(economy.STARTER_WALLET, state.wallet)
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

  it("comes with a starter pack of that console's games", function()
    local state = save.defaults()
    local games = {
      game({ path = "./a" }), game({ path = "./b" }), game({ path = "./c" }), game({ path = "./d" }),
      game({ system = "nes", path = "./other" }),
    }
    state.owned[games[1].id] = true
    state.wallet = economy.consolePrice(snes)
    local ok, granted = economy.buyConsole(state, snes, games, function() return 1 end)
    assert.is_true(ok)
    assert.same({ games[2], games[3], games[4] }, granted)
    assert.is_nil(state.owned[games[5].id])
  end)

  it("refuses when the player can't afford it", function()
    local state = save.defaults()
    state.wallet = 0
    assert.same({ false, "not enough coins" }, { economy.buyConsole(state, snes) })
    assert.is_nil(state.ownedConsoles.snes)
  end)
end)

describe("economy.launchYears", function()
  it("uses the first year with games, but never before the console came out", function()
    local years = economy.launchYears({
      game({ system = "nes", releasedate = "19870101T000000" }),
      game({ system = "nes", releasedate = "19851018T000000" }),
      game({ system = "snes", releasedate = "19700101T000000" }),
      game({ system = "gba" }),
    })
    assert.same({ nes = 1985, snes = 1990 }, years)
  end)
end)

describe("economy.isLaunchTitle", function()
  local years = { snes = 1990 }

  it("accepts games from the launch year and the year after", function()
    assert.is_true(economy.isLaunchTitle(game({ releasedate = "19901121T000000" }), years))
    assert.is_true(economy.isLaunchTitle(game({ releasedate = "19911231T000000" }), years))
    assert.is_false(economy.isLaunchTitle(game({ releasedate = "19920101T000000" }), years))
  end)

  it("rejects undated games and systems without a launch year", function()
    assert.is_false(economy.isLaunchTitle(game({}), years))
    assert.is_false(economy.isLaunchTitle(game({ system = "dos", releasedate = "19900101T000000" }), years))
  end)
end)

describe("economy.isCuratedLaunchTitle", function()
  -- The curated list has snes F-Zero with ScreenScraper 2208 and RetroAchievements 252.
  it("matches by ScreenScraper ID first", function()
    assert.is_true(economy.isCuratedLaunchTitle(game({ name = "Whatever", screenscraperId = 2208 })))
    assert.is_false(economy.isCuratedLaunchTitle(game({ name = "F-Zero", screenscraperId = 99999 })))
  end)

  it("falls back to the RetroAchievements ID", function()
    assert.is_true(economy.isCuratedLaunchTitle(game({ name = "Whatever", cheevosId = 252 })))
    assert.is_false(economy.isCuratedLaunchTitle(game({ name = "F-Zero", cheevosId = 99999 })))
  end)

  it("falls back to the name, ignoring case and punctuation", function()
    assert.is_true(economy.isCuratedLaunchTitle(game({ name = "f zero" })))
    assert.is_false(economy.isCuratedLaunchTitle(game({ name = "F-Zero", system = "gba" })))
    assert.is_false(economy.isCuratedLaunchTitle(game({ name = "Super Mario Kart" })))
  end)
end)

describe("economy.isJapaneseOnly", function()
  it("checks every listed language", function()
    assert.is_true(economy.isJapaneseOnly(game({ lang = "jp", region = "jp" })))
    assert.is_false(economy.isJapaneseOnly(game({ lang = "en,jp", region = "jp" })))
    assert.is_false(economy.isJapaneseOnly(game({ lang = "en", region = "jp" })))
  end)

  it("falls back to the region when languages are missing", function()
    assert.is_true(economy.isJapaneseOnly(game({ region = "jp" })))
    assert.is_false(economy.isJapaneseOnly(game({ region = "us" })))
    assert.is_false(economy.isJapaneseOnly(game({})))
  end)
end)

describe("economy.grantStarterPack", function()
  local function first(n) return 1 end

  it("favors launch-window games, then fills up with the rest", function()
    local state = save.defaults()
    local games = {
      game({ path = "./late", releasedate = "19950101T000000" }),
      game({ path = "./launch", releasedate = "19901121T000000" }),
      game({ path = "./undated" }),
      game({ path = "./next-year", releasedate = "19910823T000000" }),
    }
    local granted = economy.grantStarterPack(state, games, first)
    assert.same({ games[2], games[4], games[1] }, granted)
  end)

  it("prefers curated launch titles over the launch window", function()
    local state = save.defaults()
    local games = {
      game({ path = "./window", name = "Window Game", releasedate = "19901121T000000" }),
      game({ path = "./curated", name = "SimCity", releasedate = "19911001T000000" }),
      game({ path = "./late", name = "Late Game", releasedate = "19950101T000000" }),
    }
    local granted = economy.grantStarterPack(state, games, first)
    assert.same({ games[2], games[1], games[3] }, granted)
  end)

  it("starts the launch window at the first non-Japanese release", function()
    local state = save.defaults()
    local games = {
      game({ system = "nes", path = "./famicom", lang = "jp", releasedate = "19830715T000000" }),
      game({ system = "nes", path = "./later", lang = "en", releasedate = "19900101T000000" }),
      game({ system = "nes", path = "./us-launch", lang = "en", releasedate = "19851018T000000" }),
    }
    local granted = economy.grantStarterPack(state, games, first)
    assert.same({ games[3], games[2], games[1] }, granted)
  end)

  it("only uses Japanese-only games once the others run out", function()
    local state = save.defaults()
    local games = {
      game({ path = "./jp", lang = "jp", releasedate = "19901121T000000" }),
      game({ path = "./en", lang = "en" }),
    }
    local granted = economy.grantStarterPack(state, games, first)
    assert.same({ games[2], games[1] }, granted)
  end)

  it("picks randomly, ignoring play history", function()
    local state = save.defaults()
    local games = {}
    for i = 1, 6 do
      table.insert(games, game({ path = "./" .. i, playcount = i == 5 and 2 or 0 }))
    end
    local granted = economy.grantStarterPack(state, games, first)
    assert.same({ games[1], games[2], games[3] }, granted)
    assert.is_nil(state.owned[games[5].id])
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

describe("economy.giftConsole", function()
  it("gives the console for free with its starter pack, and remembers the gift", function()
    local state = require("core.save").defaults()
    local games = {}
    for i = 1, 5 do table.insert(games, { id = "nes:" .. i, system = "nes", name = "Game " .. i }) end
    local wallet = state.wallet
    local granted = economy.giftConsole(state, { id = "nes" }, games, function() return 1 end)
    assert.is_true(state.ownedConsoles.nes)
    assert.equal(economy.STARTER_GAMES, #granted)
    assert.equal(wallet, state.wallet)
    assert.is_true(state.giftReceived)
    assert.equal("nes", state.giftConsole)
  end)
end)

describe("starter packs for consoles with Japanese games", function()
  local function games(system, count, lang)
    local list = {}
    for i = 1, count do table.insert(list, { id = system .. ":" .. i, system = system, name = "Game " .. i, lang = lang }) end
    return list
  end

  it("uses Japanese-only games when there's nothing else", function()
    local state = require("core.save").defaults()
    local granted = economy.grantStarterPack(state, games("pcengine", 5, "ja"), function() return 1 end, { pcengine = true })
    assert.equal(economy.STARTER_GAMES, #granted)
  end)

  it("still prefers games that aren't Japanese-only", function()
    local state = require("core.save").defaults()
    local list = games("pcengine", 5, "ja")
    for _, game in ipairs(games("pcengine-en", 3, "en")) do game.system = "pcengine"; table.insert(list, game) end
    local granted = economy.grantStarterPack(state, list, function() return 1 end, { pcengine = true })
    for _, game in ipairs(granted) do assert.equal("en", game.lang) end
  end)
end)

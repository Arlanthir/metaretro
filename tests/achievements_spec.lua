local achievements = require("core.achievements")
local economy = require("core.economy")
local save = require("core.save")

local SINCE = "2026-11-01 00:00:00"
local PER_POINT = economy.COINS_PER_RA_POINT

local function progress(list)
  local byId = {}
  for _, a in ipairs(list) do byId[tostring(a.ID)] = a end
  return { Achievements = byId }
end

describe("achievements.credit", function()
  it("pays new unlocks in full and older ones at the past rate", function()
    local state = save.defaults()
    state.wallet = 0
    local coins = achievements.credit(state, progress({
      { ID = 1, Points = 10, DateEarned = "2026-11-02 10:00:00" },
      { ID = 2, Points = 10, DateEarned = "2024-05-01 10:00:00" },
      { ID = 3, Points = 25 },
    }), SINCE)
    assert.equal((10 + 10 * economy.PAST_ACHIEVEMENT_RATE) * PER_POINT, coins)
    assert.equal(coins, state.wallet)
  end)

  it("keeps a running total per game", function()
    local state = save.defaults()
    local data = progress({ { ID = 1, Points = 10, DateEarned = "2026-11-02 10:00:00" } })
    data.ID = 508
    achievements.credit(state, data, SINCE)
    data.Achievements["2"] = { ID = 2, Points = 5, DateEarned = "2026-11-03 10:00:00" }
    achievements.credit(state, data, SINCE)
    assert.equal(15 * PER_POINT, state.achievementCoins["508"])
  end)

  it("pays each unlock only once", function()
    local state = save.defaults()
    local data = progress({ { ID = 1, Points = 10, DateEarned = "2026-11-02 10:00:00" } })
    achievements.credit(state, data, SINCE)
    assert.equal(0, achievements.credit(state, data, SINCE))
  end)

  it("pays the hardcore bonus, including for a later hardcore upgrade", function()
    local state = save.defaults()
    assert.equal(20 * PER_POINT, achievements.credit(state, progress({
      { ID = 1, Points = 10, DateEarned = "2026-11-02 10:00:00", DateEarnedHardcore = "2026-11-02 10:00:00" },
    }), SINCE))

    achievements.credit(state, progress({ { ID = 2, Points = 10, DateEarned = "2024-01-01 00:00:00" } }), SINCE)
    assert.equal(10 * PER_POINT, achievements.credit(state, progress({
      { ID = 2, Points = 10, DateEarned = "2024-01-01 00:00:00", DateEarnedHardcore = "2026-11-03 00:00:00" },
    }), SINCE))
    assert.equal("hardcore", state.seenAchievements["2"])
  end)

  it("rounds the total to whole coins", function()
    local state = save.defaults()
    assert.equal(math.floor(5 * PER_POINT * economy.PAST_ACHIEVEMENT_RATE + 0.5), achievements.credit(state, progress({
      { ID = 1, Points = 5, DateEarned = "2020-01-01 00:00:00" },
    }), SINCE))
  end)
end)

describe("achievements ids by ROM hash", function()
  local LIST = '[{"ID":14059,"Title":"Psychic World","Hashes":["52CFDDC12AF6A3A64030F62CCF6ACA83","AAA"]},'
    .. '{"ID":7,"Title":"No hashes"}]'

  it("reads a console's game list into ids by lowercase hash", function()
    assert.same({ ["52cfddc12af6a3a64030f62ccf6aca83"] = 14059, aaa = 14059 }, achievements.hashIds(LIST))
    assert.is_nil(achievements.hashIds("not json"))
  end)

  it("fills in missing ids from the hash, keeping the ones the scraper gave", function()
    local unknown = { system = "gamegear", cheevosHash = "52cfddc12af6a3a64030f62ccf6aca83" }
    local known = { system = "gamegear", cheevosId = 1, cheevosHash = "aaa" }
    local found = achievements.resolveIds({ unknown, known, { system = "gamegear" } }, achievements.hashIds(LIST))
    assert.same({ unknown }, found)
    assert.equal(14059, unknown.cheevosId)
    assert.equal(1, known.cheevosId)
  end)

  it("refreshes consoles with games missing an id, once their list is a week old", function()
    local consoleOf = function(system) return ({ gamegear = 15, nes = 7, snes = 3 })[system] end
    local games = {
      { system = "gamegear", cheevosHash = "a" }, { system = "gamegear", cheevosHash = "b" },
      { system = "nes", cheevosHash = "c" }, { system = "snes", cheevosHash = "d", cheevosId = 5 },
      { system = "dos", cheevosHash = "e" },
    }
    local now, day = 1000000, 86400
    assert.same({ 7, 15 }, achievements.consolesToRefresh(games, {}, consoleOf, now))
    assert.same({ 15 }, achievements.consolesToRefresh(games, { ["7"] = now - day }, consoleOf, now))
    assert.same({ 7, 15 }, achievements.consolesToRefresh(games, { ["7"] = now - 8 * day }, consoleOf, now))
  end)

  it("saves the id cache as lines and reads it back, starting empty without one", function()
    local cache = { fetched = { ["15"] = 1731000000 }, ids = { ["52cfddc1"] = 14059, abc = 9 } }
    assert.same(cache, achievements.decodeIdCache(achievements.encodeIdCache(cache)))
    assert.same({ fetched = {}, ids = {} }, achievements.decodeIdCache(nil))
    assert.same({ fetched = {}, ids = {} }, achievements.decodeIdCache("{broken"))
  end)
end)

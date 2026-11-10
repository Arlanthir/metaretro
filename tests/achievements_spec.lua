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

describe("achievements.list", function()
  local progress = { Achievements = {
    ["12"] = { ID = 12, Title = "Second", Description = "Do the second thing", Points = 10, BadgeName = "250336",
      DisplayOrder = 2, DateEarned = "2026-11-01 10:00:00", DateEarnedHardcore = "2026-11-01 10:00:00" },
    ["15"] = { ID = 15, Title = "First", Description = "Do the first thing", Points = 5, BadgeName = "250337",
      DisplayOrder = 1, DateEarned = "2026-11-02 10:00:00" },
    ["9"] = { ID = 9, Title = "Last", Description = "Locked", Points = 25, BadgeName = "250338", DisplayOrder = 3 },
  } }

  it("orders achievements for display, with whether and how each was unlocked", function()
    local totals = achievements.list(progress)
    local titles = {}
    for i, achievement in ipairs(totals.list) do titles[i] = achievement.title end
    assert.same({ "First", "Second", "Last" }, titles)
    assert.same({ true, false }, { totals.list[1].unlocked, totals.list[1].hardcore })
    assert.same({ true, true }, { totals.list[2].unlocked, totals.list[2].hardcore })
    assert.is_false(totals.list[3].unlocked)
    assert.equal("250338", totals.list[3].badge)
  end)

  it("adds up the set and what's unlocked", function()
    local totals = achievements.list(progress)
    assert.same({ 2, 40, 15 }, { totals.unlocked, totals.points, totals.pointsEarned })
  end)

  it("breaks display order ties by id", function()
    local totals = achievements.list({ Achievements = { { ID = 7, Title = "b" }, { ID = 3, Title = "a" } } })
    assert.same({ "a", "b" }, { totals.list[1].title, totals.list[2].title })
  end)
end)

describe("achievements.decodeProgress", function()
  it("decodes a progress response and rejects anything else", function()
    assert.same({ Achievements = {} }, achievements.decodeProgress('{"Achievements":{}}'))
    assert.is_nil(achievements.decodeProgress("<html>oops"))
    assert.is_nil(achievements.decodeProgress('{"error":"bad key"}'))
  end)
end)

describe("achievements.noteCompletion", function()
  local function progress(...)
    local list = {}
    for i, earnedOn in ipairs({ ... }) do list[i] = { ID = i, Points = 5, DateEarned = earnedOn or nil } end
    return { ID = 42, Achievements = list }
  end

  it("marks a game gold once its whole set is unlocked, and not before", function()
    local state = save.defaults()
    assert.is_false(achievements.noteCompletion(state, progress("2026-11-01 10:00:00", false)))
    assert.is_nil(state.completedAchievements["42"])
    assert.is_true(achievements.noteCompletion(state, progress("2026-11-01 10:00:00", "2026-11-02 10:00:00")))
    assert.equal("gold", achievements.trophy(state, { cheevosId = 42 }))
  end)

  it("takes the gold away when the set grows", function()
    local state = save.defaults()
    achievements.noteCompletion(state, progress("2026-11-01 10:00:00"))
    assert.is_true(achievements.noteCompletion(state, progress("2026-11-01 10:00:00", false)))
    assert.is_true(achievements.trophy(state, { cheevosId = 42 }))
  end)

  it("never makes an empty set gold", function()
    local state = save.defaults()
    assert.is_false(achievements.noteCompletion(state, progress()))
    assert.is_nil(achievements.trophy(state, {}))
  end)
end)

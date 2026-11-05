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

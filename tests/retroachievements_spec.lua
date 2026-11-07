local retroachievements = require("services.retroachievements")
local save = require("core.save")

describe("retroachievements.parseConfig", function()
  it("reads key=value lines", function()
    assert.same({ username = "Player", apikey = "abc123" },
      retroachievements.parseConfig("username = Player\r\napikey=abc123\n"))
  end)

  it("accepts a file with only the API key", function()
    assert.same({ apikey = "abc123" }, retroachievements.parseConfig("  abc123  \n"))
  end)
end)

describe("retroachievements.queue", function()
  it("queues owned games that have achievements", function()
    local state = save.defaults()
    local owned = { id = "gb:tetris", cheevosId = 508 }
    state.owned[owned.id] = true
    retroachievements.queue(state, { owned, { id = "gb:other", cheevosId = 9 }, { id = "gb:none" } })
    assert.same({ ["508"] = true }, state.pendingAchievementGames)
  end)

  it("queues the ROM hash of owned games with no id, to look it up", function()
    local state = save.defaults()
    local owned = { id = "gamegear:psychic", cheevosHash = "52cfddc12af6a3a64030f62ccf6aca83" }
    state.owned[owned.id] = true
    retroachievements.queue(state, { owned })
    assert.same({}, state.pendingAchievementGames)
    assert.same({ ["52cfddc12af6a3a64030f62ccf6aca83"] = true }, state.pendingAchievementHashes)
  end)
end)

describe("retroachievements.trackingSince", function()
  local now = os.time({ year = 2026, month = 11, day = 5, hour = 12 })
  local first = os.time({ year = 2026, month = 10, day = 1, hour = 12 })

  it("starts at the first game session", function()
    assert.equal(os.date("!%Y-%m-%d %H:%M:%S", first), retroachievements.trackingSince("", first, now))
  end)

  it("starts now without sessions", function()
    assert.equal(os.date("!%Y-%m-%d %H:%M:%S", now), retroachievements.trackingSince("", nil, now))
  end)

  it("moves an existing start back to the first session, never forward", function()
    assert.equal(os.date("!%Y-%m-%d %H:%M:%S", first), retroachievements.trackingSince("2026-11-05 10:00:00", first, now))
    assert.equal("2026-09-01 00:00:00", retroachievements.trackingSince("2026-09-01 00:00:00", first, now))
  end)
end)

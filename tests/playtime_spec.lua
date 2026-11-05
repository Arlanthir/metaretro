local economy = require("core.economy")
local playtime = require("services.playtime")
local save = require("core.save")

describe("playtime.parseLog", function()
  it("parses tab separated sessions and skips junk", function()
    local sessions = playtime.parseLog("snes:./a.sfc\t100\t700\ngarbage\ngba:./b\t0\t60\n")
    assert.same({ { id = "snes:./a.sfc", seconds = 600 }, { id = "gba:./b", seconds = 60 } }, sessions)
  end)

  it("handles a missing log", function()
    assert.same({}, playtime.parseLog(nil))
  end)
end)

describe("playtime.credit", function()
  local sessions = { { id = "a", seconds = 600 }, { id = "b", seconds = 120 } }

  it("pays for new sessions only on backends without gametime", function()
    local state = save.defaults()
    local backend = { tracksGametime = false }
    local earned = playtime.credit(state, backend, {}, sessions)
    assert.equal(economy.playEarnings(600) + economy.playEarnings(120), earned)
    assert.equal(economy.STARTER_WALLET + earned, state.wallet)
    assert.equal(0, playtime.credit(state, backend, {}, sessions))
  end)

  it("pays gametime growth and baselines games seen for the first time", function()
    local state = save.defaults()
    local backend = { tracksGametime = true }
    local game = { id = "a", gametime = 3600 }

    assert.equal(0, playtime.credit(state, backend, { game }, sessions))
    assert.equal(2, state.consumedSessions)

    game.gametime = 3600 + 900
    assert.equal(economy.playEarnings(900), playtime.credit(state, backend, { game }, sessions))
    assert.equal(0, playtime.credit(state, backend, { game }, sessions))
  end)

  it("never pays for gametime going backwards", function()
    local state = save.defaults()
    state.creditedGametime.a = 1000
    assert.equal(0, playtime.credit(state, { tracksGametime = true }, { { id = "a", gametime = 10 } }, {}))
    assert.equal(1000, state.creditedGametime.a)
  end)
end)

describe("launcher.request", function()
  it("writes the game id and command on separate lines", function()
    local launcher = require("services.launcher")
    local backend = { launchCommand = function(_, controllers) return "run " .. #controllers end }
    assert.equal("snes:./a\nrun 1\n", launcher.request(backend, { id = "snes:./a" }, { {} }))
  end)
end)

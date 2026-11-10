local economy = require("core.economy")
local playtime = require("services.playtime")
local save = require("core.save")

describe("playtime.parseLog", function()
  it("parses tab separated sessions and skips junk", function()
    local sessions = playtime.parseLog("snes:./a.sfc\t100\t700\ngarbage\ngba:./b\t0\t60\n")
    assert.same({ { id = "snes:./a.sfc", start = 100, seconds = 600 }, { id = "gba:./b", start = 0, seconds = 60 } }, sessions)
  end)

  it("handles a missing log", function()
    assert.same({}, playtime.parseLog(nil))
  end)
end)

describe("playtime.credit", function()
  local sessions = { { id = "a", seconds = 600 }, { id = "b", seconds = 120 } }
  local a, b = { id = "a", gametime = 0 }, { id = "b", gametime = 0 }

  it("pays for new sessions only", function()
    local state = save.defaults()
    local backend = { tracksGametime = false }
    local earned, played = playtime.credit(state, backend, { a, b }, sessions)
    assert.equal(economy.playEarnings(600) + economy.playEarnings(120), earned)
    assert.same({ a, b }, played)
    assert.equal(economy.STARTER_WALLET + earned, state.wallet)
    assert.equal(0, playtime.credit(state, backend, { a, b }, sessions))
  end)

  it("pays gametime growth and baselines games seen for the first time", function()
    local state = save.defaults()
    local backend = { tracksGametime = true }
    local game = { id = "c", gametime = 3600 }

    assert.equal(0, playtime.credit(state, backend, { game }, {}))
    game.gametime = 3600 + 900
    local earned, played = playtime.credit(state, backend, { game }, {})
    assert.equal(economy.playEarnings(900), earned)
    assert.same({ game }, played)
    assert.equal(0, playtime.credit(state, backend, { game }, {}))
  end)

  it("pays sessions on gametime backends whose gametime didn't move", function()
    local state = save.defaults()
    local backend = { tracksGametime = true }
    playtime.credit(state, backend, { a }, {})
    assert.equal(economy.playEarnings(600), playtime.credit(state, backend, { a }, { sessions[1] }))
  end)

  it("pays the larger of session time and gametime growth, not both", function()
    local state = save.defaults()
    local backend = { tracksGametime = true }
    local game = { id = "a", gametime = 0 }
    playtime.credit(state, backend, { game }, {})
    game.gametime = 900
    assert.equal(economy.playEarnings(900), playtime.credit(state, backend, { game }, { sessions[1] }))
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

describe("launcher.parseResume", function()
  local launcher = require("services.launcher")
  local json = require("lib.json")

  it("reads the game and where the player was", function()
    local location = { x = 4, y = 9, facing = "down", building = "10,16", inside = { x = 3, y = 5, facing = "left" } }
    assert.same({ game = "mame:./a", location = location },
      launcher.parseResume(json.encode({ game = "mame:./a", location = location })))
  end)

  it("reads the old plain game id, without a location", function()
    assert.same({ game = "snes:./a.sfc" }, launcher.parseResume("snes:./a.sfc"))
    assert.same({ game = "snes:./a" }, launcher.parseResume(json.encode({ game = "snes:./a", location = "x" })))
  end)
end)

describe("playtime.totals", function()
  local sessions = playtime.parseLog("snes:./a\t100\t700\ngba:./b\t0\t60\nsnes:./a\t1000\t1300\ngba:./b\t2000\t2005\n")

  it("adds up each game's sessions, with when the last one ended", function()
    assert.same({ ["snes:./a"] = { count = 2, seconds = 900, last = 1300 }, ["gba:./b"] = { count = 2, seconds = 60, last = 2005 } },
      playtime.totals(sessions))
  end)

  it("counts sessions too short for EmulationStation as plays without time", function()
    assert.same({ count = 1, seconds = 0, last = 2005 }, playtime.totals(sessions, 4)["gba:./b"])
  end)

  it("starts from the given session", function()
    assert.same({ ["snes:./a"] = { count = 1, seconds = 300, last = 1300 }, ["gba:./b"] = { count = 1, seconds = 0, last = 2005 } },
      playtime.totals(sessions, 3))
  end)
end)

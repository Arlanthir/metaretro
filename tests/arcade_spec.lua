local arcade = require("core.arcade")

local function games()
  local list = {}
  for i = 1, 10 do table.insert(list, { id = "fbneo:" .. i, system = "fbneo" }) end
  table.insert(list, { id = "snes:1", system = "snes" })
  return list
end

describe("arcade", function()
  it("gives a cabinet whose game's ROM is missing the week's next game", function()
    local roms = require("core.roms")
    local before = arcade.cabinets(games(), 2860)
    roms.useCheck(function(g) return g.id ~= before[1].id end)
    local after = arcade.cabinets(games(), 2860)
    roms.useCheck(nil)
    assert.are_not.equal(before[1].id, after[1].id)
    assert.same({ before[2], before[3], before[4] }, { after[2], after[3], after[4] })
  end)

  it("starts weeks on Monday", function()
    local sunday = os.time({ year = 2026, month = 11, day = 8, hour = 12 })
    local monday = os.time({ year = 2026, month = 11, day = 9, hour = 12 })
    local nextSunday = os.time({ year = 2026, month = 11, day = 15, hour = 12 })
    assert.equal(arcade.week(sunday) + 1, arcade.week(monday))
    assert.equal(arcade.week(monday), arcade.week(nextSunday))
  end)

  it("fills the cabinets with different arcade games, the same all week", function()
    local picked = arcade.cabinets(games(), 2860)
    assert.equal(arcade.CABINETS, #picked)
    local seen = {}
    for _, game in ipairs(picked) do
      assert.equal("fbneo", game.system)
      assert.is_nil(seen[game.id])
      seen[game.id] = true
    end
    assert.same(picked, arcade.cabinets(games(), 2860))
  end)

  it("changes the games from one week to the next", function()
    local different = false
    for week = 2861, 2866 do
      local a, b = arcade.cabinets(games(), 2860), arcade.cabinets(games(), week)
      for i = 1, #a do if a[i].id ~= b[i].id then different = true end end
    end
    assert.is_true(different)
  end)

  it("leaves cabinets empty when the library has few arcade games", function()
    assert.equal(1, #arcade.cabinets({ { id = "mame:1", system = "mame" }, { id = "nes:1", system = "nes" } }, 1))
  end)

  it("gives a cabinet whose game is owned the week's next game, leaving the others alone", function()
    local before = arcade.cabinets(games(), 2860)
    local owned = { [before[2].id] = true }
    local after = arcade.cabinets(games(), 2860, owned)
    assert.equal(before[1].id, after[1].id)
    assert.equal(before[3].id, after[3].id)
    assert.equal(before[4].id, after[4].id)
    assert.is_truthy(after[2])
    for _, game in ipairs(before) do assert.are_not.equal(game.id, after[2].id) end
    assert.same(after, arcade.cabinets(games(), 2860, owned))
  end)

  it("leaves a cabinet empty once every arcade game is owned", function()
    local owned = {}
    for i = 1, 10 do owned["fbneo:" .. i] = true end
    assert.is_nil(next(arcade.cabinets(games(), 2860, owned)))
  end)

  it("sells a cabinet's game, which then adorns the player's cabinet", function()
    local state = require("core.save").defaults()
    local game = { id = "fbneo:1", system = "fbneo" }
    assert.is_false(arcade.ownsAny(state.owned))
    state.wallet = arcade.GAME_PRICE + 5
    assert.is_true(arcade.buy(state, game))
    assert.equal(5, state.wallet)
    assert.equal("fbneo:1", state.cabinetGame)
    assert.is_true(arcade.ownsAny(state.owned))
    assert.same({ false, "already owned" }, { arcade.buy(state, game) })
    assert.same({ false, "not enough coins" }, { arcade.buy(state, { id = "fbneo:2", system = "fbneo" }) })
  end)

  it("lists the owned arcade games by name", function()
    local list = { { id = "mame:b", system = "mame", name = "beta" }, { id = "mame:a", system = "mame", name = "Alpha" },
      { id = "nes:a", system = "nes", name = "Aardvark" }, { id = "mame:c", system = "mame", name = "Gamma" } }
    local owned = { ["mame:b"] = true, ["mame:a"] = true, ["nes:a"] = true }
    local names = {}
    for _, game in ipairs(arcade.owned(list, owned)) do table.insert(names, game.name) end
    assert.same({ "Alpha", "beta" }, names)
    assert.is_false(arcade.ownsAny({ ["nes:./a"] = true }))
  end)
end)

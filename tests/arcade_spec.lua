local arcade = require("core.arcade")

local function games()
  local list = {}
  for i = 1, 10 do table.insert(list, { id = "fbneo:" .. i, system = "fbneo" }) end
  table.insert(list, { id = "snes:1", system = "snes" })
  return list
end

describe("arcade", function()
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
end)

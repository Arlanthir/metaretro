local daily = require("core.daily")

local function draws(text)
  local random, values = daily.random(text), {}
  for i = 1, 8 do values[i] = random(1000) end
  return values
end

describe("daily.random", function()
  after_each(function() daily.useSeed("") end)

  it("repeats the same picks for the same key", function()
    assert.same(draws("2026-11-10"), draws("2026-11-10"))
    assert.are_not.same(draws("2026-11-10"), draws("2026-11-11"))
  end)

  it("gives each player's seed its own picks on the same day", function()
    daily.useSeed("1a2b3c4d")
    local mine = draws("2026-11-10")
    assert.same(mine, draws("2026-11-10"))
    daily.useSeed("5e6f7a8b")
    assert.are_not.same(mine, draws("2026-11-10"))
  end)
end)

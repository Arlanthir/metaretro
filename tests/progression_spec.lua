local progression = require("core.progression")
local save = require("core.save")

local function systems(...)
  local list = {}
  for _, id in ipairs({ ... }) do
    table.insert(list, { id = id, name = id })
  end
  return list
end

local function ids(list)
  local result = {}
  for _, item in ipairs(list) do
    table.insert(result, item.id)
  end
  return result
end

local function stateOwning(...)
  local state = save.defaults()
  for _, id in ipairs({ ... }) do
    state.ownedConsoles[id] = true
  end
  return state
end

describe("progression.timeline", function()
  it("orders consoles by generation, then release year", function()
    local timeline = progression.timeline(systems("gba", "snes", "megadrive", "nes", "mastersystem"))
    assert.same({ "nes", "mastersystem", "megadrive", "snes", "gba" }, ids(timeline))
    assert.equal(4, timeline[3].generation)
    assert.equal(1988, timeline[3].year)
  end)

  it("leaves out computers, arcade and engines", function()
    assert.same({ "psx" }, ids(progression.timeline(systems("dos", "amiga500", "fbneo", "devilutionx", "psx"))))
  end)
end)

describe("progression.purchasable", function()
  local timeline = progression.timeline(systems("nes", "mastersystem", "snes", "megadrive", "psx", "n64", "gba"))

  it("offers the oldest generation to a player with no consoles", function()
    assert.same({ "nes", "mastersystem" }, ids(progression.purchasable(save.defaults(), timeline)))
  end)

  it("offers the rest of the current generation and all of the next", function()
    assert.same({ "mastersystem", "megadrive", "snes" }, ids(progression.purchasable(stateOwning("nes"), timeline)))
  end)

  it("keeps older consoles for sale after moving ahead", function()
    local forSale = ids(progression.purchasable(stateOwning("nes", "snes"), timeline))
    assert.same({ "mastersystem", "megadrive", "psx", "n64" }, forSale)
  end)

  it("skips generations missing from the library", function()
    local gappy = progression.timeline(systems("nes", "gba"))
    assert.same({ "gba" }, ids(progression.purchasable(stateOwning("nes"), gappy)))
  end)

  it("offers nothing once every console is owned", function()
    assert.same({}, ids(progression.purchasable(stateOwning("nes", "gba"), progression.timeline(systems("nes", "gba")))))
  end)
end)

describe("progression.currentGeneration", function()
  it("is the newest generation owned", function()
    local timeline = progression.timeline(systems("nes", "snes", "gba"))
    assert.equal(0, progression.currentGeneration(save.defaults(), timeline))
    assert.equal(6, progression.currentGeneration(stateOwning("nes", "gba"), timeline))
  end)
end)

describe("progression.syncOwnedConsoles", function()
  it("grants the console of every owned game", function()
    local state = save.defaults()
    state.owned["gba:./a.gba"] = true
    progression.syncOwnedConsoles(state, {
      { id = "gba:./a.gba", system = "gba" },
      { id = "snes:./b.sfc", system = "snes" },
    })
    assert.same({ gba = true }, state.ownedConsoles)
  end)
end)

describe("progression.giftChoices", function()
  it("puts the oldest consoles on the professor's table", function()
    local timeline = { { id = "a" }, { id = "b" }, { id = "c" }, { id = "d" } }
    assert.same({ { id = "a" }, { id = "b" }, { id = "c" } }, progression.giftChoices(timeline))
    assert.same({ { id = "a" } }, progression.giftChoices({ { id = "a" } }))
  end)
end)

describe("console sprites", function()
  it("has a drawing for every console", function()
    local looks = require("world.consolelooks")
    for line in io.lines("src/core/consoles.lua") do
      local id = line:match('^%s*%[?"?([%w]+)"?%]?%s*=%s*console%(')
      if id then assert.truthy(looks[id], id) end
    end
  end)
end)

describe("progression.mostPopular", function()
  it("ranks the library's consoles by units sold", function()
    local timeline = { { id = "nes", sold = 61.9 }, { id = "ps2", sold = 155 }, { id = "lynx", sold = 3 }, { id = "snes", sold = 49.1 } }
    local ids = {}
    for _, console in ipairs(progression.mostPopular(timeline, 3)) do table.insert(ids, console.id) end
    assert.same({ "ps2", "nes", "snes" }, ids)
    assert.equal(4, #timeline)
  end)

  it("has a rough units-sold figure for every console", function()
    local consoles = require("core.consoles")
    for line in io.lines("src/core/consoles.lua") do
      local id = line:match('^%s*%[?"?([%w]+)"?%]?%s*=%s*console%(')
      if id then assert.is_true(consoles.get(id).sold > 0, id) end
    end
  end)
end)

local save = require("core.save")
local town = require("world.town")

local map = town.parse(require("world.townmap"))

local function stateOwning(...)
  local state = save.defaults()
  for _, id in ipairs({ ... }) do
    state.ownedConsoles[id] = true
  end
  return state
end

local function console(id, generation)
  return { id = id, name = id, short = id, year = 1990, generation = generation or 4 }
end

describe("town map", function()
  it("has a start, home, dealer and store lots", function()
    assert.is_truthy(map.start)
    assert.equal(2, #map.fixed)
    assert.equal(22, #map.lots)
    assert.is_true(town.isWalkable(map, map.start.x, map.start.y))
  end)

  it("keeps every map row the same width", function()
    for _, row in ipairs(map.rows) do
      assert.equal(map.width, #row)
    end
  end)

  local doors = {}
  for _, building in ipairs(map.fixed) do table.insert(doors, building.door) end
  for _, lot in ipairs(map.lots) do table.insert(doors, lot.door) end

  it("gives every door a full building footprint", function()
    for _, door in ipairs(doors) do
      local left, top = town.footprint(door)
      for y = top, top + town.BUILDING_HEIGHT - 1 do
        for x = left, left + town.BUILDING_WIDTH - 1 do
          if x ~= door.x or y ~= door.y then
            assert.equal("B", town.tile(map, x, y), ("tile %d,%d of door %d,%d"):format(x, y, door.x, door.y))
          end
        end
      end
    end
  end)

  it("lets the player reach every door from below", function()
    for _, door in ipairs(doors) do
      assert.is_true(town.isWalkable(map, door.x, door.y + 1), ("below door %d,%d"):format(door.x, door.y))
    end
  end)

  it("treats outside the map, trees, water and buildings as solid", function()
    assert.is_false(town.isWalkable(map, 0, 0))
    assert.is_false(town.isWalkable(map, 1, 1))
    assert.is_false(town.isWalkable(map, map.fixed[1].door.x, map.fixed[1].door.y))
  end)
end)

describe("town.assignLots", function()
  local timeline = { console("nes", 3), console("snes"), console("megadrive") }

  it("gives owned consoles the first free lots in timeline order", function()
    local state = stateOwning("nes", "megadrive")
    town.assignLots(state, timeline, 22)
    assert.same({ nes = 1, megadrive = 2 }, state.lots)
  end)

  it("never moves existing stores", function()
    local state = stateOwning("nes", "megadrive")
    town.assignLots(state, timeline, 22)
    state.ownedConsoles.snes = true
    town.assignLots(state, timeline, 22)
    assert.same({ nes = 1, megadrive = 2, snes = 3 }, state.lots)
  end)

  it("leaves consoles without a lot once the town is full", function()
    local state = stateOwning("nes", "snes", "megadrive")
    town.assignLots(state, timeline, 2)
    assert.same({ nes = 1, snes = 2 }, state.lots)
  end)
end)

describe("town.layout", function()
  it("places stores on assigned lots and leaves the rest empty", function()
    local nes = console("nes", 3)
    local state = stateOwning("nes")
    state.lots.nes = 2
    local buildings = town.layout(map, state, { nes })
    assert.equal("home", buildings[1].kind)
    assert.equal("dealer", buildings[2].kind)
    assert.equal("lot", buildings[3].kind)
    assert.equal("store", buildings[4].kind)
    assert.equal(nes, buildings[4].console)
    assert.equal(2 + #map.lots, #buildings)
  end)
end)

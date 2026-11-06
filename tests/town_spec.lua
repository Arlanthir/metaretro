local save = require("core.save")
local town = require("world.town")

local map = town.parse(require("world.townmap"))

describe("town map", function()
  it("has a start, home, dealer and store lots", function()
    assert.is_truthy(map.start)
    assert.equal(2, #map.fixed)
    assert.equal(34, #map.lots)
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

  it("treats billboard spots as plots: solid only when blocked", function()
    local billboard = map.billboards[1]
    assert.is_false(town.isWalkable(map, billboard.x, billboard.y))
    assert.is_true(town.isWalkable(map, billboard.x, billboard.y, {}))
    assert.is_false(town.isWalkable(map, billboard.x, billboard.y, { [billboard.x .. "," .. billboard.y] = true }))
  end)

  it("frees plot tiles that no building covers", function()
    local home = { kind = "home", door = map.fixed[1].door }
    local lot = { kind = "lot", door = map.lots[1].door }
    local blocked = town.blockedTiles({ home, lot }, function() return 3 end)
    local left, top = town.footprint(home.door)
    assert.is_false(town.isWalkable(map, left + 2, top, blocked))
    assert.is_true(town.isWalkable(map, left + 3, top, blocked))
    assert.is_true(town.isWalkable(map, lot.door.x, lot.door.y, blocked))
    assert.is_false(town.isWalkable(map, 1, 1, blocked))
  end)
end)

describe("town.assignLots", function()
  local function store(id) return { id = id } end
  local list = { store("nes"), store("snes"), store("genre:rpg") }

  it("gives stores the first free lots in list order", function()
    local state = save.defaults()
    town.assignLots(state, { list[1], list[3] }, 34)
    assert.same({ nes = 1, ["genre:rpg"] = 2 }, state.lots)
  end)

  it("never moves existing stores", function()
    local state = save.defaults()
    town.assignLots(state, { list[1], list[3] }, 34)
    town.assignLots(state, list, 34)
    assert.same({ nes = 1, ["genre:rpg"] = 2, snes = 3 }, state.lots)
  end)

  it("leaves stores without a lot once the town is full", function()
    local state = save.defaults()
    town.assignLots(state, list, 2)
    assert.same({ nes = 1, snes = 2 }, state.lots)
  end)
end)

describe("town.layout", function()
  it("places stores on their lots and leaves the rest empty", function()
    local nes = { id = "nes", kind = "console" }
    local state = save.defaults()
    state.lots.nes = 2
    local buildings = town.layout(map, state, { nes })
    assert.equal("home", buildings[1].kind)
    assert.equal("dealer", buildings[2].kind)
    assert.equal("lot", buildings[3].kind)
    assert.equal("store", buildings[4].kind)
    assert.equal(nes, buildings[4].store)
    assert.equal(2 + #map.lots, #buildings)
  end)
end)

describe("townsfolk placement", function()
  local townsfolk = require("core.townsfolk")
  local map = town.parse(require("world.townmap"))

  it("starts villagers on spots they may stand on", function()
    local function tileAt(x, y) return town.tile(map, x, y) end
    assert.is_true(#townsfolk.SPOTS >= #townsfolk.KINDS)
    for _, spot in ipairs(townsfolk.SPOTS) do
      assert.is_true(townsfolk.canWanderTo(tileAt, spot, spot.x, spot.y), spot.x .. "," .. spot.y)
    end
  end)
end)

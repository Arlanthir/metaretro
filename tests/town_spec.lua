local town = require("world.town")

local map = town.parse(require("world.townmap"))

describe("town map", function()
  it("has a start, the town's buildings, Granny Rose's house and four residents' houses", function()
    assert.is_truthy(map.start)
    local kinds = {}
    for _, building in ipairs(map.fixed) do table.insert(kinds, building.kind) end
    assert.same({ "house", "dealer", "museum", "mall", "arcade", "grandma", "home", "house", "house", "house" }, kinds)
    assert.is_true(town.isWalkable(map, map.start.x, map.start.y))
  end)

  it("keeps every map row the same width", function()
    for _, row in ipairs(map.rows) do
      assert.equal(map.width, #row)
    end
  end)

  local doors = {}
  for _, building in ipairs(map.fixed) do table.insert(doors, building.door) end

  it("gives every door a full building footprint", function()
    for _, door in ipairs(doors) do
      local left, top = town.footprint(door)
      for y = top, door.y do
        for x = left, left + town.BUILDING_WIDTH - 1 do
          if x ~= door.x or y ~= door.y then
            assert.equal("B", town.tile(map, x, y), ("tile %d,%d of door %d,%d"):format(x, y, door.x, door.y))
          end
        end
      end
    end
  end)

  it("puts each door where its building's sprite draws the doorway", function()
    for _, building in ipairs(map.fixed) do
      assert.equal(building.door.x - 1, (town.footprint(building.door)), building.kind)
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
    local dealer
    for _, building in ipairs(map.fixed) do
      if building.kind == "dealer" then dealer = building end
    end
    local blocked = town.blockedTiles({ dealer }, function() return 3 end)
    local left, top = town.footprint(dealer.door)
    assert.is_false(town.isWalkable(map, left + 2, top, blocked))
    assert.is_true(town.isWalkable(map, left + 3, top, blocked))
    assert.is_false(town.isWalkable(map, 1, 1, blocked))
  end)
end)

describe("town.layout", function()
  it("has the town's fixed buildings; stores are in the mall", function()
    local kinds = {}
    for _, building in ipairs(town.layout(map)) do table.insert(kinds, building.kind) end
    assert.same({ "house", "dealer", "museum", "mall", "arcade", "grandma", "home", "house", "house", "house" }, kinds)
  end)
end)

describe("the console dealer", function()
  it("stands between the house on the left and the museum, a tile clear of the house", function()
    local dealer
    for _, building in ipairs(map.fixed) do
      if building.kind == "dealer" then dealer = building end
    end
    assert.same({ 10, 7 }, { dealer.door.x, dealer.door.y })
    assert.equal(".", town.tile(map, dealer.door.left - 1, dealer.door.y))
  end)
end)

describe("houses", function()
  local function find(kind)
    for _, building in ipairs(town.layout(map)) do
      if building.kind == kind then return building end
    end
  end

  it("numbers the houses, one per resident", function()
    local indexes = {}
    for _, building in ipairs(town.layout(map)) do
      if building.kind == "house" then table.insert(indexes, building.index) end
    end
    assert.same({ 1, 2, 3, 4 }, indexes)
    assert.equal(#require("core.townsfolk").RESIDENTS, #indexes)
  end)

  it("puts Granny Rose's house just left of Home, on the street south of the plaza", function()
    local home, grandma = find("home"), find("grandma")
    assert.equal(home.door.y, grandma.door.y)
    assert.is_true(grandma.door.x < home.door.x)
    for _, building in ipairs(town.layout(map)) do
      local x = building.door.x
      assert.is_false(building.door.y == home.door.y and x > grandma.door.x and x < home.door.x, building.kind)
    end
    assert.is_true(home.door.y > map.start.y)
  end)
end)

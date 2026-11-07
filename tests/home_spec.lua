local home = require("world.home")

local layout = require("world.homemap")
local map = home.parse(layout)

local function find(kind)
  for _, piece in ipairs(map.furniture) do
    if piece.kind == kind then return piece end
  end
end

-- Every tile the player can reach from the front door.
local function reachable()
  local seen, queue = { [map.start.x .. "," .. map.start.y] = true }, { map.start }
  while #queue > 0 do
    local tile = table.remove(queue)
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
      local x, y = tile.x + d[1], tile.y + d[2]
      if home.isWalkable(map, x, y) and not seen[x .. "," .. y] then
        seen[x .. "," .. y] = true
        table.insert(queue, { x = x, y = y })
      end
    end
  end
  return seen
end

local function nextToReachable(piece, seen)
  for y = piece.y - 1, piece.y + piece.height do
    for x = piece.x - 1, piece.x + piece.width do
      local inside = x >= piece.x and x < piece.x + piece.width and y >= piece.y and y < piece.y + piece.height
      local diagonal = (x < piece.x or x >= piece.x + piece.width) and (y < piece.y or y >= piece.y + piece.height)
      if not inside and not diagonal and seen[x .. "," .. y] then return true end
    end
  end
  return false
end

describe("home", function()
  it("starts the player just inside the front door", function()
    assert.equal("E", home.tile(map, map.exit.x, map.exit.y))
    assert.same({ x = map.exit.x, y = map.exit.y - 1 }, map.start)
    assert.is_true(home.isWalkable(map, map.start.x, map.start.y))
  end)

  it("keeps both layers the same size", function()
    assert.equal(#layout.rooms, #layout.furniture)
    for y, row in ipairs(layout.rooms) do
      assert.equal(#row, #layout.furniture[y], "row " .. y)
    end
  end)

  it("has the open space and bedroom furniture", function()
    for _, kind in ipairs({ "tv", "console", "sofa", "counter", "bed", "desk", "chair" }) do
      assert.truthy(find(kind), kind)
    end
    local tv = find("tv")
    assert.same({ 2, 2 }, { tv.width, tv.height })
    assert.equal(tv, home.furnitureAt(map, tv.x + 1, tv.y + 1))
  end)

  it("stands furniture on floor, reaching at most into the wall behind it", function()
    for _, piece in ipairs(map.furniture) do
      local bottom = piece.y + piece.height - 1
      for y = piece.y, bottom do
        for x = piece.x, piece.x + piece.width - 1 do
          local allowed = y == bottom and "[.,]" or "[.,#]"
          assert.truthy(home.tile(map, x, y):match(allowed), piece.kind .. " at " .. x .. "," .. y)
        end
      end
    end
  end)

  it("refuses furniture that doesn't fill its footprint", function()
    assert.has_error(function()
      home.parse({ rooms = { "...", "..." }, furniture = { ".v.", "..." } })
    end)
  end)

  it("lets the player reach every room and all the furniture", function()
    local seen = reachable()
    for _, piece in ipairs(map.furniture) do
      assert.is_true(nextToReachable(piece, seen), piece.kind)
    end
    for y = 1, map.height do
      for x = 1, map.width do
        if home.tile(map, x, y) == "." and not home.furnitureAt(map, x, y) then
          assert.is_true(seen[x .. "," .. y] == true, "floor at " .. x .. "," .. y)
        end
      end
    end
  end)

  it("gives every wall a piece, with ends beside doorways", function()
    for y = 1, map.height do
      for x = 1, map.width do
        if home.tile(map, x, y) == "#" then
          assert.truthy(home.wallPiece(map, x, y), x .. "," .. y)
          assert.truthy(home.floor(map, x, y), x .. "," .. y)
        end
      end
    end
    local rooms = { "#####", "#...#", "_...#", "#...#", "##E##" }
    local small = home.parse({ rooms = rooms, furniture = { ".....", ".....", ".....", ".....", "....." } })
    local expected = {
      { 1, 1, "topLeft" }, { 3, 1, "top" }, { 5, 1, "topRight" },
      { 1, 2, "leftBeforeGap" }, { 1, 4, "leftAfterGap" }, { 5, 3, "right" },
      { 1, 5, "bottomLeft" }, { 2, 5, "bottomBeforeGap" }, { 4, 5, "bottomAfterGap" }, { 5, 5, "bottomRight" },
    }
    for _, case in ipairs(expected) do
      assert.equal(case[3], home.wallPiece(small, case[1], case[2]))
    end
    assert.is_nil(home.wallPiece(small, 3, 3))
  end)

  it("builds a single wall between rooms side by side", function()
    local rooms = { "#####", "#.#.#", "#.#.#", "#._.#", "#.#.#", "#E###" }
    local small = home.parse({ rooms = rooms, furniture = { ".....", ".....", ".....", ".....", ".....", "....." } })
    local expected = {
      { 3, 1, "topJoin" }, { 3, 2, "between" }, { 3, 3, "betweenBeforeGap" }, { 3, 5, "betweenAfterGap" },
      { 3, 6, "bottomJoin" }, { 1, 2, "left" }, { 5, 2, "right" },
    }
    for _, case in ipairs(expected) do
      assert.equal(case[3], home.wallPiece(small, case[1], case[2]))
    end
  end)

  it("floors the kitchen and the rest differently", function()
    local counter = find("counter")
    assert.equal("kitchen", home.floor(map, counter.x, counter.y))
    local tv = find("tv")
    assert.equal("wood", home.floor(map, tv.x, tv.y))
    assert.is_nil(home.floor(map, 0, 0))
  end)
end)

local interior = require("world.interior")

local layout = require("world.homemap")
local map = interior.parse(layout)

local function find(kind)
  for _, piece in ipairs(map.furniture) do
    if piece.kind == kind then return piece end
  end
end

-- Every tile the player can reach from the front door of `m` (the house by default), around
-- `blocked` tiles ("x,y" keys) where someone stands.
local function reachable(m, blocked)
  m, blocked = m or map, blocked or {}
  local seen, queue = { [m.start.x .. "," .. m.start.y] = true }, { m.start }
  while #queue > 0 do
    local tile = table.remove(queue)
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
      local x, y = tile.x + d[1], tile.y + d[2]
      if interior.isWalkable(m, x, y) and not blocked[x .. "," .. y] and not seen[x .. "," .. y] then
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
    assert.equal("E", interior.tile(map, map.exit.x, map.exit.y))
    assert.same({ x = map.exit.x, y = map.exit.y - 1 }, map.start)
    assert.is_true(interior.isWalkable(map, map.start.x, map.start.y))
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
    assert.equal(tv, interior.furnitureAt(map, tv.x + 1, tv.y + 1))
  end)

  it("stands furniture on floor, reaching at most into the wall behind it", function()
    for _, piece in ipairs(map.furniture) do
      local bottom = piece.y + piece.height - 1
      for y = piece.y, bottom do
        for x = piece.x, piece.x + piece.width - 1 do
          local allowed = y == bottom and "[.,]" or "[.,#]"
          assert.truthy(interior.tile(map, x, y):match(allowed), piece.kind .. " at " .. x .. "," .. y)
        end
      end
    end
  end)

  it("refuses furniture that doesn't fill its footprint", function()
    assert.has_error(function()
      interior.parse({ rooms = { "...", "..." }, furniture = { ".v.", "..." } })
    end)
  end)

  it("lets the player reach every room and all the furniture", function()
    local seen = reachable()
    for _, piece in ipairs(map.furniture) do
      assert.is_true(nextToReachable(piece, seen), piece.kind)
    end
    for y = 1, map.height do
      for x = 1, map.width do
        if interior.tile(map, x, y) == "." and not interior.furnitureAt(map, x, y) then
          assert.is_true(seen[x .. "," .. y] == true, "floor at " .. x .. "," .. y)
        end
      end
    end
  end)

  it("gives every wall a piece, with ends beside doorways", function()
    for y = 1, map.height do
      for x = 1, map.width do
        if interior.tile(map, x, y) == "#" then
          assert.truthy(interior.wallPiece(map, x, y), x .. "," .. y)
          assert.truthy(interior.floor(map, x, y), x .. "," .. y)
        end
      end
    end
    local rooms = { "#####", "#...#", "_...#", "#...#", "##E##" }
    local small = interior.parse({ rooms = rooms, furniture = { ".....", ".....", ".....", ".....", "....." } })
    local expected = {
      { 1, 1, "topLeft" }, { 3, 1, "top" }, { 5, 1, "topRight" },
      { 1, 2, "leftBeforeGap" }, { 1, 4, "leftAfterGap" }, { 5, 3, "right" },
      { 1, 5, "bottomLeft" }, { 2, 5, "bottomBeforeGap" }, { 4, 5, "bottomAfterGap" }, { 5, 5, "bottomRight" },
    }
    for _, case in ipairs(expected) do
      assert.equal(case[3], interior.wallPiece(small, case[1], case[2]))
    end
    assert.is_nil(interior.wallPiece(small, 3, 3))
  end)

  it("builds a single wall between rooms side by side", function()
    local rooms = { "#####", "#.#.#", "#.#.#", "#._.#", "#.#.#", "#E###" }
    local small = interior.parse({ rooms = rooms, furniture = { ".....", ".....", ".....", ".....", ".....", "....." } })
    local expected = {
      { 3, 1, "topJoin" }, { 3, 2, "between" }, { 3, 3, "betweenBeforeGap" }, { 3, 5, "betweenAfterGap" },
      { 3, 6, "bottomJoin" }, { 1, 2, "left" }, { 5, 2, "right" },
    }
    for _, case in ipairs(expected) do
      assert.equal(case[3], interior.wallPiece(small, case[1], case[2]))
    end
  end)

  it("floors the kitchen and the rest differently", function()
    local counter = find("counter")
    assert.equal("kitchen", interior.floor(map, counter.x, counter.y))
    local tv = find("tv")
    assert.equal("wood", interior.floor(map, tv.x, tv.y))
    assert.is_nil(interior.floor(map, 0, 0))
  end)
end)

describe("home for a new game", function()
  it("wakes the player up next to the bed, somewhere they can walk", function()
    local spot = map.spots.wakeUp
    assert.truthy(spot)
    assert.is_true(interior.isWalkable(map, spot.x, spot.y))
    assert.is_true(reachable()[spot.x .. "," .. spot.y])
  end)

  it("lets the player walk where the console isn't yet", function()
    local console = find("console")
    assert.is_false(interior.isWalkable(map, console.x, console.y))
    local missing = function(piece) return piece.kind == "console" end
    assert.is_true(interior.isWalkable(map, console.x, console.y, missing))
  end)
end)

describe("museum", function()
  local museum = interior.parse(require("world.museummap"))
  local professor = museum.spots.professor
  local blocked = { [professor.x .. "," .. professor.y] = true }

  it("has the professor, his display table and a front door", function()
    assert.truthy(professor)
    assert.equal("E", interior.tile(museum, museum.exit.x, museum.exit.y))
    local displayTable
    for _, piece in ipairs(museum.furniture) do
      if piece.kind == "displayTable" then displayTable = piece end
    end
    assert.same({ 3, 1 }, { displayTable.width, displayTable.height })
  end)

  it("lets the player reach the professor and every console on the table", function()
    local seen = reachable(museum, blocked)
    assert.is_true(nextToReachable({ x = professor.x, y = professor.y, width = 1, height = 1 }, seen))
    for _, piece in ipairs(museum.furniture) do
      if piece.kind == "displayTable" then
        for x = piece.x, piece.x + piece.width - 1 do
          assert.is_true(seen[x .. "," .. (piece.y + 1)] == true, "in front of the console at " .. x)
        end
      end
      assert.is_true(nextToReachable(piece, seen), piece.kind)
    end
  end)

  it("gives every wall a piece and stands furniture on floor", function()
    for y = 1, museum.height do
      for x = 1, museum.width do
        if interior.tile(museum, x, y) == "#" then assert.truthy(interior.wallPiece(museum, x, y), x .. "," .. y) end
      end
    end
    for _, piece in ipairs(museum.furniture) do
      local bottom = piece.y + piece.height - 1
      for x = piece.x, piece.x + piece.width - 1 do
        assert.truthy(interior.tile(museum, x, bottom):match("[.,]"), piece.kind)
      end
    end
  end)
end)

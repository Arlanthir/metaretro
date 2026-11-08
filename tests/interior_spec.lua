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

-- A wall tile's pieces, quarter by quarter (see interior.wallPiece).
local function quarters(m, x, y)
  return table.concat(interior.wallPiece(m, x, y), " ")
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
    for _, kind in ipairs({ "tv", "console", "loveseat", "counter", "bed", "desk", "chair", "cabinet" }) do
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
      { 1, 1, "topLeft topLeft topLeft topLeft" }, { 3, 1, "top top top top" },
      { 5, 1, "topRight topRight topRight topRight" },
      { 1, 2, "left left leftBeforeGap leftBeforeGap" }, { 1, 4, "leftAfterGap leftAfterGap left left" },
      { 5, 3, "right right right right" }, { 1, 5, "bottomLeft bottomLeft bottomLeft bottomLeft" },
      { 2, 5, "bottom bottomBeforeGap bottom bottomBeforeGap" }, { 4, 5, "bottomAfterGap bottom bottomAfterGap bottom" },
    }
    for _, case in ipairs(expected) do
      assert.equal(case[3], quarters(small, case[1], case[2]), case[1] .. "," .. case[2])
    end
    assert.is_nil(interior.wallPiece(small, 3, 3))
  end)

  it("builds a single wall between rooms side by side", function()
    local rooms = { "#####", "#.#.#", "#.#.#", "#._.#", "#.#.#", "#E###" }
    local small = interior.parse({ rooms = rooms, furniture = { ".....", ".....", ".....", ".....", ".....", "....." } })
    local expected = {
      { 3, 1, "top top topRight topLeft" }, { 3, 2, "right left right left" },
      { 3, 3, "right left rightBeforeGap leftBeforeGap" }, { 3, 5, "rightAfterGap leftAfterGap right left" },
      { 3, 6, "bottomRight bottomLeft bottom bottom" },
    }
    for _, case in ipairs(expected) do
      assert.equal(case[3], quarters(small, case[1], case[2]), case[1] .. "," .. case[2])
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

describe("walls between rooms above and below each other", function()
  it("joins the wall between them to the walls at its ends", function()
    local rooms = { "######", "#.#..#", "#.####", "#.#..#", "##E###" }
    local small = interior.parse({ rooms = rooms, furniture = { "......", "......", "......", "......", "......" } })
    assert.equal("bottom bottom top top", quarters(small, 4, 3))
    assert.equal("right bottomLeft right topLeft", quarters(small, 3, 3))
    assert.equal("bottomRight right topRight right", quarters(small, 6, 3))
  end)
end)

describe("home's living room", function()
  it("keeps the console under the TV, between it and the loveseat", function()
    local tv, console, seat = find("tv"), find("console"), find("loveseat")
    assert.is_true(console.x >= tv.x and console.x < tv.x + tv.width)
    assert.equal(tv.x, seat.x)
    assert.is_true(tv.y < console.y and console.y < seat.y)
  end)

  it("has an office below the bedroom, with a wide desk and chair in its top-left corner and the cabinet by its right wall", function()
    local bed, desk, cabinet = find("bed"), find("wideDesk"), find("cabinet")
    assert.equal(2, desk.width)
    assert.is_true(desk.y > bed.y + bed.height)
    assert.equal("#", interior.tile(map, desk.x - 1, desk.y))
    assert.equal("#", interior.tile(map, desk.x, desk.y - 1))
    assert.equal("chair", interior.furnitureAt(map, desk.x, desk.y + 1).kind)
    assert.is_true(cabinet.x > desk.x and cabinet.y == desk.y)
    assert.equal("#", interior.tile(map, cabinet.x + cabinet.width, cabinet.y))
    assert.equal("#", interior.tile(map, cabinet.x + cabinet.width, cabinet.y + cabinet.height - 1))
  end)

  it("keeps the bedroom shorter than the living room", function()
    local bed = find("bed")
    local function rows(x)
      local count = 0
      for y = 1, map.height do
        if interior.tile(map, x, y) == "." then count = count + 1 end
      end
      return count
    end
    assert.is_true(rows(bed.x) < rows(find("console").x))
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

describe("store", function()
  local store = interior.parse(require("world.storemap"))
  local clerk = store.spots.clerk
  local blocked = { [clerk.x .. "," .. clerk.y] = true }

  it("has the clerk standing behind the counter", function()
    local counter, facing = interior.counter(store)
    assert.same({ x = clerk.x, y = clerk.y + 1 }, counter)
    assert.equal("down", facing)
    assert.equal("shopCounter", interior.furnitureAt(store, counter.x, counter.y).kind)
  end)

  it("lets the player reach the counter in front of the clerk, the clerk and every piece", function()
    local seen = reachable(store, blocked)
    assert.is_true(seen[clerk.x .. "," .. (clerk.y + 2)] == true)
    assert.is_true(nextToReachable({ x = clerk.x, y = clerk.y, width = 1, height = 1 }, seen))
    for _, piece in ipairs(store.furniture) do assert.is_true(nextToReachable(piece, seen), piece.kind) end
  end)
end)

describe("mall layout", function()
  local mall = require("world.mall")

  -- Every store's clerk, with the counter they serve from and the tile in front of it.
  local function clerks(map)
    local list = {}
    for _, spot in ipairs(map.allSpots.clerk or {}) do
      local counter, facing = interior.counter(map, spot)
      local front = { x = counter.x, y = counter.y + (facing == "down" and 1 or -1) }
      table.insert(list, { spot = spot, counter = counter, facing = facing, front = front })
    end
    return list
  end

  it("has a clerk per store, behind a counter the player can reach from the corridor", function()
    for _, count in ipairs({ 0, 1, 2, 5, 17, 40 }) do
      local map = interior.parse(mall.layout(count))
      local list = clerks(map)
      assert.equal(count, #list, count .. " stores")
      local blocked = {}
      for _, clerk in ipairs(list) do blocked[clerk.spot.x .. "," .. clerk.spot.y] = true end
      local seen = reachable(map, blocked)
      for _, clerk in ipairs(list) do
        assert.equal("shopCounter", interior.furnitureAt(map, clerk.counter.x, clerk.counter.y).kind)
        assert.is_true(seen[clerk.front.x .. "," .. clerk.front.y] == true, count .. " stores, clerk at " .. clerk.spot.x)
      end
      for y = 1, map.height do
        for x = 1, map.width do
          if interior.tile(map, x, y) == "#" then assert.truthy(interior.wallPiece(map, x, y), x .. "," .. y) end
        end
      end
    end
  end)

  it("puts the first half of the stores along the top side, open towards the corridor", function()
    local map = interior.parse(mall.layout(5))
    local facings = {}
    for _, clerk in ipairs(clerks(map)) do table.insert(facings, clerk.facing) end
    assert.same({ "down", "down", "down", "up", "up" }, facings)
  end)

  it("fits on screen with a few stores, and grows with them", function()
    local small, big = interior.parse(mall.layout(5)), interior.parse(mall.layout(30))
    assert.is_true(small.width * 32 <= 640 and small.height * 32 <= 432)
    assert.is_true(big.width > small.width)
  end)
end)

describe("bigger museum and arcade club", function()
  it("lets the player reach every glass case and cabinet from in front", function()
    for _, name in ipairs({ "museummap", "arcademap" }) do
      local m = interior.parse(require("world." .. name))
      local blocked = {}
      if m.spots.professor then blocked[m.spots.professor.x .. "," .. m.spots.professor.y] = true end
      local seen = reachable(m, blocked)
      local count = 0
      for _, piece in ipairs(m.furniture) do
        if piece.kind == "displayCase" or piece.kind == "cabinet" then
          count = count + 1
          -- Glass cases are faced from below; cabinets stand against the side walls, faced from beside.
          local fromX = piece.kind == "cabinet" and (piece.x < m.width / 2 and piece.x + piece.width or piece.x - 1)
            or piece.x
          local fromY = piece.kind == "cabinet" and piece.y or piece.y + piece.height
          assert.is_true(seen[fromX .. "," .. fromY] == true, name .. " " .. piece.kind .. " at " .. piece.x)
        end
      end
      assert.is_true(count >= 4, name)
    end
  end)
end)

describe("mall ads", function()
  local mall = require("world.mall")

  it("hangs a poster on the corridor's top wall after each top store, between the stores' openings", function()
    for _, count in ipairs({ 1, 2, 4, 9, 30 }) do
      local layout = mall.layout(count)
      local map = interior.parse(layout)
      assert.is_true(#layout.ads >= 1)
      for i, ad in ipairs(layout.ads) do
        assert.equal(i, ad.store)
        assert.is_true(ad.store <= math.ceil(count / 2))
        for x = ad.tiles[1], ad.tiles[2] do
          assert.equal("#", interior.tile(map, x, mall.TOP_FRONT), count .. " stores, tile " .. x)
          assert.equal(",", interior.tile(map, x, mall.TOP_FRONT + 1))
        end
      end
    end
  end)
end)

describe("arcade club clerk", function()
  it("stands behind the counter, which the player can reach", function()
    local club = interior.parse(require("world.arcademap"))
    local clerk = club.spots.clerk
    local counter, facing = interior.counter(club)
    assert.same({ x = clerk.x, y = clerk.y + 1 }, counter)
    assert.equal("down", facing)
    assert.equal("shopCounter", interior.furnitureAt(club, counter.x, counter.y).kind)
    local seen = reachable(club, { [clerk.x .. "," .. clerk.y] = true })
    assert.is_true(seen[counter.x .. "," .. (counter.y + 1)] == true)
  end)
end)

describe("museum entrance", function()
  it("puts the professor between the entrance and his table", function()
    local museum = interior.parse(require("world.museummap"))
    local professor = museum.spots.professor
    local displayTable
    for _, piece in ipairs(museum.furniture) do
      if piece.kind == "displayTable" then displayTable = piece end
    end
    assert.is_true(professor.y > displayTable.y)
    assert.is_true(professor.y < museum.start.y)
    -- Straight up from the door, the first thing the player meets is the professor.
    for y = museum.start.y, professor.y + 1, -1 do
      assert.is_true(interior.isWalkable(museum, museum.start.x, y), "tile " .. museum.start.x .. "," .. y)
    end
    assert.equal(museum.start.x, professor.x)
  end)
end)

describe("house", function()
  local layout = require("world.housemap")
  local house = interior.parse(layout)

  it("has a resident who can be reached from the front door", function()
    for y, row in ipairs(layout.rooms) do
      assert.equal(#row, #layout.furniture[y], "row " .. y)
    end
    local resident = house.spots.resident
    assert.truthy(resident)
    assert.is_true(interior.isWalkable(house, resident.x, resident.y))
    local seen = reachable(house, { [resident.x .. "," .. resident.y] = true })
    local around = 0
    for _, d in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
      if seen[(resident.x + d[1]) .. "," .. (resident.y + d[2])] then around = around + 1 end
    end
    assert.is_true(around > 0)
    for _, piece in ipairs(house.furniture) do
      assert.is_true(nextToReachable(piece, seen), piece.kind)
    end
  end)
end)

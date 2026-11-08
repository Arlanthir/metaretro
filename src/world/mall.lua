-- The mall's inside, laid out for however many stores are open (see world/interior.lua for the
-- legend): a tiled corridor with the stores open onto it, no doors, so they're all in view at once.
-- The first half of the stores line the corridor's top side, the rest its bottom side, after the way
-- out (E) at the bottom left. Each store is a small room with a block of shelves and its clerk (C)
-- behind the counter, facing the corridor through a wide opening. Stores are two tiles of wall apart,
-- and posters hang on those walls, on the corridor's side, between the top stores.
local mall = {}

mall.SPACING = 6 -- a store's width (4 tiles), with the two tiles of wall on its left
mall.MIN_SLOTS = 2 -- stores' places per side even when few are open, so the mall isn't a closet
mall.TOP_FRONT = 4 -- the row of the top stores' fronts, the corridor's top wall, where posters hang
mall.BOTTOM_FRONT = 8 -- the row of the bottom stores' fronts, the corridor's bottom wall
local HEIGHT = 12

-- The first floor column of the store in place `slot` along a side.
local function left(slot)
  return (slot - 1) * mall.SPACING + 2
end

-- The layout ({ rooms, furniture, ads }) for `count` stores. Store i's clerk is the i-th in reading
-- order: the top side's from left to right, then the bottom side's. `ads` lists the posters, each on
-- the wall after a top store, advertising it (the store to its left), as { store, tiles = { first,
-- last } }, the wall tiles it covers (it's centered on them).
function mall.layout(count)
  local topCount = math.ceil(count / 2)
  local bottomCount = count - topCount
  -- The bottom side's first place is the way out.
  local slots = math.max(mall.MIN_SLOTS, topCount, bottomCount + 1)
  local width = slots * mall.SPACING
  local rooms, furniture = {}, {}
  for y = 1, HEIGHT do
    rooms[y], furniture[y] = {}, {}
    for x = 1, width do rooms[y][x], furniture[y][x] = " ", "." end
  end
  local function fill(grid, x1, y1, x2, y2, char)
    for y = y1, y2 do
      for x = x1, x2 do grid[y][x] = char end
    end
  end
  local function put(grid, x, y, text)
    for i = 1, #text do grid[y][x + i - 1] = text:sub(i, i) end
  end

  fill(rooms, 1, mall.TOP_FRONT, width, mall.BOTTOM_FRONT, "#")
  fill(rooms, 2, mall.TOP_FRONT + 1, width - 1, mall.BOTTOM_FRONT - 1, ",")
  rooms[mall.BOTTOM_FRONT][4] = "E"

  -- A store: its walls, floor and opening, its shelves against the back wall and the clerk beside
  -- them, behind the counter. `x` is its first floor column; `back` and `front` its back and front
  -- walls' rows.
  local function store(x, back, front)
    local step = front > back and 1 or -1
    local top, bottom = math.min(back, front), math.max(back, front)
    fill(rooms, math.max(1, x - 2), top, x + 4, bottom, "#")
    fill(rooms, x, top + 1, x + 3, bottom - 1, ".")
    put(rooms, x + 1, front, "___")
    -- Shelves reach into the top wall, but stand on the floor against the bottom one.
    local shelves = step > 0 and back or back - 2
    put(furniture, x, shelves, "ff")
    put(furniture, x, shelves + 1, "ff")
    furniture[shelves + (step > 0 and 1 or 0)][x + 2] = "C"
    put(furniture, x + 2, front - step, "zz")
  end
  for i = 1, topCount do store(left(i), 1, mall.TOP_FRONT) end
  for i = 1, bottomCount do store(left(i + 1), HEIGHT, mall.BOTTOM_FRONT) end

  local ads = {}
  for i = 1, math.min(topCount, slots - 1) do
    local wall = left(i + 1) - 2
    table.insert(ads, { store = i, tiles = { wall, wall + 1 } })
  end

  -- A store's thick wall beside an empty place touches no room there: that side is outside.
  local function nearFloor(x, y)
    for dy = -1, 1 do
      for dx = -1, 1 do
        local row = rooms[y + dy]
        local tile = row and row[x + dx]
        if tile == "." or tile == "," then return true end
      end
    end
    return false
  end
  for y = 1, HEIGHT do
    for x = 1, width do
      if rooms[y][x] == "#" and not nearFloor(x, y) then rooms[y][x] = " " end
    end
  end

  local layout = { rooms = {}, furniture = {}, ads = ads }
  for y = 1, HEIGHT do
    layout.rooms[y], layout.furniture[y] = table.concat(rooms[y]), table.concat(furniture[y])
  end
  return layout
end

return mall

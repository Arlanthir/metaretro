-- Inside buildings (world/homemap.lua, world/housemap.lua...). Legend for the `rooms` rows:
--   #  wall          .  wooden floor     ,  kitchen floor     :  shop floor     (space)  outside
--   _  doorway between rooms             E  front door, in the bottom wall (walk down onto it to leave)
-- A wall between two rooms side by side is one tile thick.
-- The `furniture` rows place furniture (see FURNITURE); a piece fills its whole footprint with its letter.
-- Tall pieces against the top wall may reach into the wall row, covering the wall behind them.
-- They also mark spots (see SPOTS), where someone stands.
local interior = {}

interior.FURNITURE = {
  n = { kind = "counter", width = 2, height = 1 },
  u = { kind = "cupboard", width = 1, height = 2 },
  t = { kind = "table", width = 2, height = 1 },
  x = { kind = "stool", width = 1, height = 1 },
  v = { kind = "tv", width = 2, height = 2 },
  g = { kind = "console", width = 1, height = 1 },
  s = { kind = "sofa", width = 3, height = 1 },
  w = { kind = "loveseat", width = 2, height = 1 },
  f = { kind = "bookshelf", width = 2, height = 2 },
  p = { kind = "plant", width = 1, height = 2 },
  b = { kind = "bed", width = 2, height = 3 },
  k = { kind = "desk", width = 1, height = 1 },
  e = { kind = "wideDesk", width = 2, height = 1 },
  h = { kind = "chair", width = 1, height = 1 },
  r = { kind = "dresser", width = 2, height = 2 },
  l = { kind = "displayTable", width = 3, height = 1 },
  o = { kind = "orbStatue", width = 2, height = 2 },
  q = { kind = "frogStatue", width = 2, height = 2 },
  i = { kind = "pillar", width = 1, height = 3 },
  z = { kind = "shopCounter", width = 2, height = 1 },
  c = { kind = "displayCase", width = 1, height = 2 },
  a = { kind = "cabinet", width = 2, height = 3 },
}

interior.SPOTS = {
  P = "professor", -- where Professor Cork stands in the museum
  S = "wakeUp", -- where the player starts at home
  C = "clerk", -- where a store's clerk stands, behind the counter
  R = "resident", -- where whoever lives in a house stands
}

local FLOORS = { ["."] = "wood", [","] = "kitchen", [":"] = "shop", ["_"] = "wood", E = "wood" }
local ROOM = { ["."] = true, [","] = true, [":"] = true }
local GAP = { ["_"] = true, E = true }

local function key(x, y)
  return x .. "," .. y
end

function interior.tile(map, x, y)
  local row = map.rows[y]
  return row and x >= 1 and x <= #row and row:sub(x, x) or " "
end

-- Collects each letter's footprint, starting from its top-left tile.
local function placeFurniture(map, rows)
  local seen = {}
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local letter = row:sub(x, x)
      local spec = interior.FURNITURE[letter]
      if spec and not seen[key(x, y)] then
        local piece = { kind = spec.kind, x = x, y = y, width = spec.width, height = spec.height }
        for fy = y, y + spec.height - 1 do
          for fx = x, x + spec.width - 1 do
            if (rows[fy] or ""):sub(fx, fx) ~= letter then
              error(("%s at %d,%d should fill %dx%d tiles"):format(spec.kind, x, y, spec.width, spec.height))
            end
            seen[key(fx, fy)] = true
            map.furnitureAt[key(fx, fy)] = piece
          end
        end
        table.insert(map.furniture, piece)
      end
    end
  end
end

function interior.parse(layout)
  local rows = layout.rooms
  -- `spots` has each spot's first place; `allSpots` lists them all, in reading order.
  local map = { rows = rows, width = #rows[1], height = #rows, furniture = {}, furnitureAt = {}, spots = {},
    allSpots = {} }
  for y, row in ipairs(rows) do
    local x = row:find("E", 1, true)
    if x then
      map.exit = { x = x, y = y }
      map.start = { x = x, y = y - 1 }
    end
  end
  placeFurniture(map, layout.furniture)
  for y, row in ipairs(layout.furniture) do
    for x = 1, #row do
      local spot = interior.SPOTS[row:sub(x, x)]
      if spot then
        map.spots[spot] = map.spots[spot] or { x = x, y = y }
        map.allSpots[spot] = map.allSpots[spot] or {}
        table.insert(map.allSpots[spot], { x = x, y = y })
      end
    end
  end
  return map
end

local AROUND = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }

-- "wood" or "kitchen" under the tile, or nil outside. Walls and doorways take their room's floor,
-- which shows along a wall's inner edge and through a doorway.
function interior.floor(map, x, y)
  local tile = interior.tile(map, x, y)
  if tile ~= "#" and not GAP[tile] then return FLOORS[tile] end
  for _, d in ipairs(AROUND) do
    local neighbour = interior.tile(map, x + d[1], y + d[2])
    if ROOM[neighbour] then return FLOORS[neighbour] end
  end
end

-- The pieces of wall a wall tile is made of, one per quarter (top-left, top-right, bottom-left,
-- bottom-right), each named after the side of a room it closes ("top", "topLeft"...; see WALLS in
-- world/art.lua). A quarter closes the room next to it: above or below ("bottom", "top"), else beside
-- it ("right", "left"), else diagonally (a corner). Facing no room, it's the wall's outer edge, or an
-- outer corner where the wall turns. Beside a doorway, the wall's end ("BeforeGap" when the gap is to
-- the right or below, "AfterGap" otherwise). A wall two tiles thick is two walls side by side, each
-- closing its own room; "fill", the wall's plain top, is left for anything thicker. Nil when the tile
-- isn't wall next to a room.
local INNER_CORNER = { [-1] = { [-1] = "bottomRight", [1] = "topRight" }, [1] = { [-1] = "bottomLeft", [1] = "topLeft" } }
local OUTER_CORNER = { [-1] = { [-1] = "topLeft", [1] = "bottomLeft" }, [1] = { [-1] = "topRight", [1] = "bottomRight" } }

local function quarter(room, gap, wall, sx, sy)
  local function vertical(side) return side < 0 and "bottom" or "top" end
  local function horizontal(side) return side < 0 and "right" or "left" end
  -- The wall's end beside a doorway, unless the quarter's other side is more wall, turning a corner.
  if gap(sx, 0) then
    local side = room(0, sy) and sy or not wall(0, sy) and room(0, -sy) and -sy
    if side then return vertical(side) .. (sx > 0 and "BeforeGap" or "AfterGap") end
  end
  if gap(0, sy) then
    local side = room(sx, 0) and sx or not wall(sx, 0) and room(-sx, 0) and -sx
    if side then return horizontal(side) .. (sy > 0 and "BeforeGap" or "AfterGap") end
  end
  if room(0, sy) then return vertical(sy) end
  if room(sx, 0) then return horizontal(sx) end
  if room(sx, sy) then return INNER_CORNER[sx][sy] end
  local alongX, alongY = wall(sx, 0), wall(0, sy)
  if alongX and not alongY then return sy < 0 and "top" or "bottom" end
  if alongY and not alongX then return sx < 0 and "left" or "right" end
  if not alongX then return OUTER_CORNER[sx][sy] end
  if room(-sx, 0) or room(-sx, sy) then return horizontal(-sx) end
  if room(0, -sy) or room(sx, -sy) then return vertical(-sy) end
  return "fill"
end

function interior.wallPiece(map, x, y)
  if interior.tile(map, x, y) ~= "#" then return nil end
  local function room(dx, dy) return ROOM[interior.tile(map, x + dx, y + dy)] == true end
  local function gap(dx, dy) return GAP[interior.tile(map, x + dx, y + dy)] == true end
  local function wall(dx, dy)
    local tile = interior.tile(map, x + dx, y + dy)
    return tile == "#" or GAP[tile] == true
  end
  local rooms, last = 0, nil
  for _, d in ipairs(AROUND) do
    if room(d[1], d[2]) then rooms, last = rooms + 1, d end
  end
  if rooms == 0 then return nil end
  if rooms == 1 and last[1] ~= 0 and last[2] ~= 0 then
    -- A room's corner: the corner piece whole, which rounds off more than its quarters would.
    local corner = INNER_CORNER[last[1]][last[2]]
    return { corner, corner, corner, corner }
  end
  return {
    quarter(room, gap, wall, -1, -1), quarter(room, gap, wall, 1, -1),
    quarter(room, gap, wall, -1, 1), quarter(room, gap, wall, 1, 1),
  }
end

function interior.furnitureAt(map, x, y)
  return map.furnitureAt[key(x, y)]
end

-- The counter tile a clerk (spot C; the first one by default) serves from, in front of them (below,
-- or above), and the way the clerk faces it.
function interior.counter(map, clerk)
  clerk = clerk or map.spots.clerk
  local below = interior.furnitureAt(map, clerk.x, clerk.y + 1)
  local dy = below and below.kind == "shopCounter" and 1 or -1
  return { x = clerk.x, y = clerk.y + dy }, dy > 0 and "down" or "up"
end

-- Furniture low enough to walk over.
local LOW = { chair = true, stool = true }

-- Floor and doorways the player can stand on (the front door is left by walking onto it), chairs
-- and stools included. `absent(piece)` optionally says a piece isn't there (yet), so its tiles are free.
function interior.isWalkable(map, x, y, absent)
  local tile = interior.tile(map, x, y)
  local piece = map.furnitureAt[key(x, y)]
  local blocking = piece and not LOW[piece.kind] and not (absent and absent(piece))
  return (ROOM[tile] or tile == "_") and not blocking
end

return interior

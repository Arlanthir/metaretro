-- Inside buildings (world/homemap.lua, world/museummap.lua). Legend for the `rooms` rows:
--   #  wall          .  wooden floor     ,  kitchen floor     (space)  outside
--   _  doorway between rooms             E  front door (walk down onto it to leave)
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
  f = { kind = "bookshelf", width = 2, height = 2 },
  p = { kind = "plant", width = 1, height = 2 },
  b = { kind = "bed", width = 2, height = 3 },
  k = { kind = "desk", width = 1, height = 1 },
  h = { kind = "chair", width = 1, height = 1 },
  r = { kind = "dresser", width = 2, height = 2 },
  l = { kind = "displayTable", width = 3, height = 1 },
  o = { kind = "orbStatue", width = 2, height = 2 },
  q = { kind = "frogStatue", width = 2, height = 2 },
  i = { kind = "pillar", width = 1, height = 3 },
}

interior.SPOTS = {
  P = "professor", -- where Professor Cork stands in the museum
  S = "wakeUp", -- where a new game starts, at home
}

local FLOORS = { ["."] = "wood", [","] = "kitchen", ["_"] = "wood", E = "wood" }
local ROOM = { ["."] = true, [","] = true }
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
  local map = { rows = rows, width = #rows[1], height = #rows, furniture = {}, furnitureAt = {}, spots = {} }
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
      if spot then map.spots[spot] = { x = x, y = y } end
    end
  end
  return map
end

local AROUND = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }

-- "wood" or "kitchen" under the tile, or nil outside. Walls take their room's floor, which shows
-- along their inner edge.
function interior.floor(map, x, y)
  local tile = interior.tile(map, x, y)
  if tile ~= "#" then return FLOORS[tile] end
  for _, d in ipairs(AROUND) do
    local neighbour = interior.tile(map, x + d[1], y + d[2])
    if ROOM[neighbour] then return FLOORS[neighbour] end
  end
end

-- Which piece of wall goes on a wall tile, named after the side of the room it closes
-- ("top", "topLeft"...), or "between" for a wall with a room on its left and right, which meets
-- the outer walls at "topJoin" and "bottomJoin". Wall ends next to a doorway are "BeforeGap"
-- (the gap is to the right or below) or "AfterGap". Nil when the tile isn't wall next to a room.
function interior.wallPiece(map, x, y)
  if interior.tile(map, x, y) ~= "#" then return nil end
  local function room(dx, dy) return ROOM[interior.tile(map, x + dx, y + dy)] end
  local function gap(dx, dy) return GAP[interior.tile(map, x + dx, y + dy)] end
  local side = room(0, 1) and "top" or room(0, -1) and "bottom"
    or room(1, 0) and room(-1, 0) and "between" or room(1, 0) and "left" or room(-1, 0) and "right"
  if side == "top" or side == "bottom" then
    return side .. (gap(1, 0) and "BeforeGap" or gap(-1, 0) and "AfterGap" or "")
  elseif side then
    return side .. (gap(0, 1) and "BeforeGap" or gap(0, -1) and "AfterGap" or "")
  end
  if room(1, 1) and room(-1, 1) then return "topJoin" end
  if room(1, -1) and room(-1, -1) then return "bottomJoin" end
  return room(1, 1) and "topLeft" or room(-1, 1) and "topRight" or room(1, -1) and "bottomLeft"
    or room(-1, -1) and "bottomRight" or nil
end

function interior.furnitureAt(map, x, y)
  return map.furnitureAt[key(x, y)]
end

-- Floor and doorways the player can stand on (the front door is left by walking onto it).
-- `absent(piece)` optionally says a piece isn't there (yet), so its tiles are free.
function interior.isWalkable(map, x, y, absent)
  local tile = interior.tile(map, x, y)
  local piece = map.furnitureAt[key(x, y)]
  return (ROOM[tile] or tile == "_") and not (piece and not (absent and absent(piece)))
end

return interior

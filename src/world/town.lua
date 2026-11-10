-- Town map logic. Legend for the rows in world/townmap.lua:
--   .  grass        =  path        T  tree        ~  water        @  player start (path)
--   B  building     H  home door   D  console dealer door   M  game museum door   L  mall door
--   A  arcade club door   V  a resident's house door   G  Granny Rose's house door
--   $  signpost (readable)   %  crate   &  barrel   #  billboard (4x3 block of #)
--   X  the GotX board (a 10x3 block of X)
-- Every door sits on the bottom row of its building (a block of B, 4 wide and 3 tall, or taller for the
-- museum), where the building's sprite draws its doorway: one tile from the left edge.
local town = {}

town.BUILDING_WIDTH = 4
town.BILLBOARD_WIDTH, town.BILLBOARD_HEIGHT = 4, 3
town.BOARD_WIDTH, town.BOARD_HEIGHT = 10, 3

local WALKABLE = { ["."] = true, ["="] = true, ["@"] = true }
local FIXED = { H = "home", D = "dealer", M = "museum", L = "mall", A = "arcade", V = "house",
  G = "grandma" }
local PROPS = { ["$"] = "sign", ["%"] = "crate", ["&"] = "barrel" }

-- A door at (x, y), with its building's left edge and top: how far the "B" tiles reach left of it
-- and above it.
local function door(rows, x, y)
  local left, top = x, y
  while rows[y]:sub(left - 1, left - 1) == "B" do left = left - 1 end
  while rows[top - 1] and rows[top - 1]:sub(x, x) == "B" do top = top - 1 end
  return { x = x, y = y, left = left, top = top }
end

function town.parse(rows)
  local map = { rows = rows, width = #rows[1], height = #rows, fixed = {}, props = {}, billboards = {} }
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local tile = row:sub(x, x)
      if tile == "@" then
        map.start = { x = x, y = y }
      elseif PROPS[tile] then
        table.insert(map.props, { kind = PROPS[tile], x = x, y = y })
      elseif tile == "#" and row:sub(x - 1, x - 1) ~= "#" and (rows[y - 1] or ""):sub(x, x) ~= "#" then
        table.insert(map.billboards, { x = x, y = y }) -- top-left corner
      elseif tile == "X" and not map.board then
        map.board = { x = x, y = y } -- top-left corner
      elseif FIXED[tile] then
        table.insert(map.fixed, { kind = FIXED[tile], door = door(rows, x, y) })
      end
    end
  end
  return map
end

function town.tile(map, x, y)
  local row = map.rows[y]
  return row and x >= 1 and x <= #row and row:sub(x, x) or "T"
end

-- Plots: building and billboard spots, solid only where something actually stands.
local function isPlotTile(tile)
  return tile == "B" or tile == "#" or tile == "X" or FIXED[tile] ~= nil
end

-- `blocked` (from town.blockedTiles, plus any billboards in use) frees the parts of plots nothing
-- stands on; without it every plot tile blocks.
function town.isWalkable(map, x, y, blocked)
  local tile = town.tile(map, x, y)
  if WALKABLE[tile] then return true end
  return blocked ~= nil and isPlotTile(tile) and not blocked[x .. "," .. y]
end

-- Tiles covered by buildings; `widthOf(building)` gives each one's width in tiles.
function town.blockedTiles(buildings, widthOf)
  local blocked = {}
  for _, building in ipairs(buildings) do
    local left, top = town.footprint(building.door)
    for x = left, left + widthOf(building) - 1 do
      for y = top, building.door.y do
        blocked[x .. "," .. y] = true
      end
    end
  end
  return blocked
end

-- Top-left tile of the building whose door is at `door`.
-- A building's top-left tile, from its door.
function town.footprint(door)
  return door.left, door.top
end

-- Every building on the map: home, museum, dealer, mall, arcade club, Granny Rose's house and the
-- residents' houses (the stores are inside the mall). Houses are numbered in reading order, for their
-- look and resident.
function town.layout(map)
  local buildings, houses = {}, 0
  for _, building in ipairs(map.fixed) do
    local entry = { kind = building.kind, door = building.door }
    if building.kind == "house" then
      houses = houses + 1
      entry.index = houses
    end
    table.insert(buildings, entry)
  end
  return buildings
end

return town

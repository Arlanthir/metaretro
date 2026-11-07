-- Town map logic. Legend for the rows in world/townmap.lua:
--   .  grass        =  path        T  tree        ~  water        @  player start (path)
--   B  building     H  home door   D  console dealer door   M  game museum door
--   1-9, a-z  doors of store lots, in the order they get filled
--   $  signpost (readable)   %  crate   &  barrel   #  billboard (4x3 block of #)
-- Every door sits on the bottom row of a 4x3 building, one tile from its left edge.
local town = {}

town.BUILDING_WIDTH, town.BUILDING_HEIGHT = 4, 3
town.BILLBOARD_WIDTH, town.BILLBOARD_HEIGHT = 4, 3

local LOT_LABELS = "123456789abcdefghijklmnopqrstuvwxyz"
local WALKABLE = { ["."] = true, ["="] = true, ["@"] = true }
local FIXED = { H = "home", D = "dealer", M = "museum" }
local PROPS = { ["$"] = "sign", ["%"] = "crate", ["&"] = "barrel" }

function town.parse(rows)
  local map = { rows = rows, width = #rows[1], height = #rows, fixed = {}, lots = {}, props = {}, billboards = {} }
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local tile = row:sub(x, x)
      local lot = LOT_LABELS:find(tile, 1, true)
      if tile == "@" then
        map.start = { x = x, y = y }
      elseif PROPS[tile] then
        table.insert(map.props, { kind = PROPS[tile], x = x, y = y })
      elseif tile == "#" and row:sub(x - 1, x - 1) ~= "#" and (rows[y - 1] or ""):sub(x, x) ~= "#" then
        table.insert(map.billboards, { x = x, y = y }) -- top-left corner
      elseif FIXED[tile] then
        table.insert(map.fixed, { kind = FIXED[tile], door = { x = x, y = y } })
      elseif lot then
        map.lots[lot] = { door = { x = x, y = y } }
      end
    end
  end
  return map
end

function town.tile(map, x, y)
  local row = map.rows[y]
  return row and x >= 1 and x <= #row and row:sub(x, x) or "T"
end

-- Plots: building lots and billboard spots, solid only where something actually stands.
local function isPlotTile(tile)
  return tile == "B" or tile == "#" or FIXED[tile] ~= nil or LOT_LABELS:find(tile, 1, true) ~= nil
end

-- `blocked` (from town.blockedTiles, plus any billboards in use) frees the parts of plots nothing
-- stands on; without it every plot tile blocks.
function town.isWalkable(map, x, y, blocked)
  local tile = town.tile(map, x, y)
  if WALKABLE[tile] then return true end
  return blocked ~= nil and isPlotTile(tile) and not blocked[x .. "," .. y]
end

-- Tiles covered by actual buildings; `widthOf(building)` gives each one's width in tiles
-- (empty lots cover nothing).
function town.blockedTiles(buildings, widthOf)
  local blocked = {}
  for _, building in ipairs(buildings) do
    if building.kind ~= "lot" then
      local left, top = town.footprint(building.door)
      for x = left, left + widthOf(building) - 1 do
        for y = top, top + town.BUILDING_HEIGHT - 1 do
          blocked[x .. "," .. y] = true
        end
      end
    end
  end
  return blocked
end

-- Top-left tile of the building whose door is at `door`.
function town.footprint(door)
  return door.x - 1, door.y - town.BUILDING_HEIGHT + 1
end

-- Gives each store without a lot the first free one, in list order; existing stores never move.
function town.assignLots(state, storeList, lotCount)
  local taken = {}
  for _, index in pairs(state.lots) do
    taken[index] = true
  end
  for _, store in ipairs(storeList) do
    if not state.lots[store.id] then
      for index = 1, lotCount do
        if not taken[index] then
          state.lots[store.id] = index
          taken[index] = true
          break
        end
      end
    end
  end
end

-- Every building on the map: home, dealer, stores on their lots, and empty lots.
function town.layout(map, state, storeList)
  local byLot = {}
  for _, store in ipairs(storeList) do
    local index = state.lots[store.id]
    if index then
      byLot[index] = store
    end
  end
  local buildings = {}
  for _, building in ipairs(map.fixed) do
    table.insert(buildings, { kind = building.kind, door = building.door })
  end
  for index, lot in ipairs(map.lots) do
    local store = byLot[index]
    table.insert(buildings, { kind = store and "store" or "lot", door = lot.door, store = store })
  end
  return buildings
end

return town

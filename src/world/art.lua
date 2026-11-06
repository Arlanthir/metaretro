-- Town art from the Ninja Adventure asset pack (CC0, see assets/ninja-adventure/README.md).
-- Sprites are 16x16 pixel art drawn at 2x, so one map tile is art.TILE screen pixels.
local art = {}

art.TILE = 32
local SCALE = 2
local SOURCE = 16
local DIR = "assets/ninja-adventure/"

local images, quads = {}, {}

local function image(name)
  images[name] = images[name] or love.graphics.newImage(DIR .. name .. ".png")
  return images[name]
end

-- Draws the `columns` x `rows` tile region at (`column`, `row`) of a sheet, with its top-left at (x, y).
local function sprite(name, column, row, x, y, columns, rows)
  columns, rows = columns or 1, rows or 1
  local key = table.concat({ name, column, row, columns, rows }, ",")
  local img = image(name)
  quads[key] = quads[key] or love.graphics.newQuad(column * SOURCE, row * SOURCE, columns * SOURCE, rows * SOURCE,
    img:getDimensions())
  love.graphics.draw(img, quads[key], x, y, 0, SCALE, SCALE)
end

-- Autotile layout shared by the path and water sheets: a 3x3 blob, a horizontal strip below it,
-- a vertical strip to its right and a single tile. Keyed by which neighbours match: N=1, E=2, S=4, W=8.
local AUTOTILE = {
  [6] = { 0, 0 }, [14] = { 1, 0 }, [12] = { 2, 0 },
  [7] = { 0, 1 }, [15] = { 1, 1 }, [13] = { 2, 1 },
  [3] = { 0, 2 }, [11] = { 1, 2 }, [9] = { 2, 2 },
  [2] = { 0, 3 }, [10] = { 1, 3 }, [8] = { 2, 3 },
  [4] = { 3, 0 }, [5] = { 3, 1 }, [1] = { 3, 2 }, [0] = { 3, 3 },
}
local PATH = { sheet = "TilesetFloor", column = 0, row = 7 }
local WATER = { sheet = "TilesetWater", column = 0, row = 6 }
local GRASS = { "TilesetFloor", 0, 12 }
-- Mostly grass tufts, with the occasional flower.
local DECORATIONS = {
  { "TilesetFloor", 1, 12 }, { "TilesetFloor", 2, 12 }, { "TilesetFloor", 3, 12 }, { "TilesetFloor", 4, 12 },
  { "TilesetFloor", 2, 11 }, { "TilesetFloor", 3, 11 }, { "TilesetFloor", 1, 12 }, { "TilesetFloor", 3, 12 },
  { "TilesetNature", 0, 11 }, { "TilesetNature", 1, 11 }, { "TilesetNature", 3, 11 },
}
local DECORATION_CHANCE = 0.12
local TREES = { { 0, 0 }, { 0, 0 }, { 2, 0 } }

-- Buildings are 4x3 tiles with the door one tile in from the left; these sprites all match that.
local HOUSES = {
  home = { 0, 0, 4 },
  dealer = { 16, 0, 3 },
  console = { { 4, 0, 4 }, { 8, 0, 4 }, { 12, 0, 4 } },
  genre = { { 23, 0, 3 }, { 26, 0, 3 } },
}

-- Cloth banners (1x2 tiles) hung by store doors, one design per store (the pack's snake and skull
-- banners are left out as unfriendly for a shop).
local BANNERS = { { 22, 20 }, { 23, 20 }, { 24, 20 }, { 25, 20 }, { 27, 20 } }
local PROPS = {
  sign = { "TilesetElement", 0, 2 },
  crate = { "TilesetElement", 0, 0 },
  barrel = { "TilesetElement", 4, 0 },
}

local CHARACTER_COLUMNS = { down = 0, up = 1, left = 2, right = 3 }

-- A stable pseudo-random number in [0, 1) per tile, so decorations don't line up in patterns.
local function noise(x, y, salt)
  local value = math.sin(x * 12.9898 + y * 78.233 + (salt or 0) * 37.719) * 43758.5453
  return value - math.floor(value)
end

local function pick(list, x, y, salt)
  return list[math.floor(noise(x, y, salt) * #list) + 1]
end

local function autotile(set, matches, x, y, px, py)
  local mask = (matches(x, y - 1) and 1 or 0) + (matches(x + 1, y) and 2 or 0)
    + (matches(x, y + 1) and 4 or 0) + (matches(x - 1, y) and 8 or 0)
  local offset = AUTOTILE[mask]
  sprite(set.sheet, set.column + offset[1], set.row + offset[2], px, py)
end

-- Ground for one tile: `kind` is "path", "water" or "grass"; `matches(x, y)` tells whether a
-- neighbouring tile is the same kind, so paths and ponds get proper edges.
function art.ground(kind, matches, x, y, px, py)
  sprite(GRASS[1], GRASS[2], GRASS[3], px, py)
  if kind == "path" then
    autotile(PATH, matches, x, y, px, py)
  elseif kind == "water" then
    autotile(WATER, matches, x, y, px, py)
  elseif noise(x, y) < DECORATION_CHANCE then
    local decoration = pick(DECORATIONS, x, y, 1)
    sprite(decoration[1], decoration[2], decoration[3], px, py)
  end
end

function art.prop(kind, px, py)
  local prop = PROPS[kind]
  sprite(prop[1], prop[2], prop[3], px, py)
end

-- A 2x2 tree whose trunk stands on the tile at (px, py); its crown covers the tile above.
function art.tree(x, y, px, py)
  local tree = pick(TREES, x, y, 2)
  sprite("TilesetNature", tree[1], tree[2], px - art.TILE / 2, py - art.TILE, 2, 2)
end

local function storeHash(store)
  local sum = 0
  for i = 1, #store.id do
    sum = sum + store.id:byte(i) * i
  end
  return sum
end

local function house(building)
  if building.kind ~= "store" then
    return HOUSES[building.kind]
  end
  local pool = HOUSES[building.store.kind] or HOUSES.console
  return pool[storeHash(building.store) % #pool + 1]
end

-- How many tiles wide the building's sprite is (3 or 4).
function art.buildingWidth(building)
  return house(building)[3]
end

-- A plaque sized to the letters themselves rather than the font's full line height.
local function sign(text, centerX, y, font)
  local width, height = font:getWidth(text) + 10, 22
  local x = math.floor(centerX - width / 2)
  love.graphics.setColor(0.27, 0.16, 0.10)
  love.graphics.rectangle("fill", x - 2, y - 2, width + 4, height + 4, 3)
  love.graphics.setColor(0.98, 0.91, 0.74)
  love.graphics.rectangle("fill", x, y, width, height, 2)
  love.graphics.setColor(0.27, 0.16, 0.10)
  love.graphics.setFont(font)
  love.graphics.print(text, x + 5, math.floor(y + height / 2 - font:getAscent() * 0.65))
  love.graphics.setColor(1, 1, 1)
end

-- `x, y` is the building's top-left pixel and `width` its width in pixels.
function art.building(building, label, x, y, width, font)
  local tile = art.TILE
  if building.kind == "lot" then
    for column = 0, 3 do
      for row = 1, 2 do
        local inLot = function(cx, cy) return cx >= 0 and cx <= 3 and cy >= 1 and cy <= 2 end
        autotile(PATH, inLot, column, row, x + column * tile, y + row * tile)
      end
    end
    sign(label, x + width / 2, y + tile + 10, font)
    return
  end
  local look = house(building)
  sprite("TilesetHouse", look[1], look[2], x, y, look[3], 3)
  if building.kind == "store" then
    -- A banner hanging on the wall to the right of the door marks it as a shop.
    local banner = BANNERS[storeHash(building.store) % #BANNERS + 1]
    sprite("TilesetHouse", banner[1], banner[2], x + (look[3] - 1) * tile, y + tile, 1, 2)
  end
  sign(label, x + look[3] * tile / 2, y + 6, font)
end

-- A character from a 4-direction sheet (one column per direction, walk frames down the rows)
-- with its shadow; `frame` counts walk frames (0 when standing still).
function art.character(sheet, x, y, facing, frame)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.draw(image("Shadow"), x + 4, y + art.TILE - 10, 0, SCALE, SCALE)
  love.graphics.setColor(1, 1, 1)
  -- Most sheets have 4 walk frames, some only 2.
  local frames = math.min(4, image(sheet):getHeight() / SOURCE)
  sprite(sheet, CHARACTER_COLUMNS[facing], frame % frames, x, y - 4)
end

function art.player(x, y, facing, frame)
  art.character("Boy", x, y, facing, frame)
end

function art.villager(villager, x, y, facing, frame)
  art.character("villagers/" .. villager.sprite, x, y, facing, frame or 0)
end

-- The villager's portrait for dialogs, as an Image.
function art.portrait(villager)
  return image("villagers/" .. villager.sprite .. "Face")
end

return art

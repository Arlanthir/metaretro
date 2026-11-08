-- Town art from the Ninja Adventure asset pack (CC0, see assets/ninja-adventure/README.md).
-- Sprites are 16x16 pixel art drawn at 2x, so one map tile is art.TILE screen pixels.
local art = {}

art.TILE = 32
local SCALE = 2
local SOURCE = 16
local DIR = "assets/ninja-adventure/"

local images, quads = {}, {}

-- Sheets from the pack, or "metaretro/..." for Metaretro's own art in assets/metaretro.
local function image(name)
  local path = name:match("^metaretro/") and "assets/" .. name or DIR .. name
  images[name] = images[name] or love.graphics.newImage(path .. ".png")
  return images[name]
end

-- Draws the `width` x `height` region at source pixel (`left`, `top`) of a sheet, with its top-left at (x, y).
local function region(name, left, top, width, height, x, y)
  local key = table.concat({ name, left, top, width, height }, ",")
  local img = image(name)
  quads[key] = quads[key] or love.graphics.newQuad(left, top, width, height, img:getDimensions())
  love.graphics.draw(img, quads[key], x, y, 0, SCALE, SCALE)
end

-- Draws the `columns` x `rows` tile region at (`column`, `row`) of a sheet, with its top-left at (x, y).
local function sprite(name, column, row, x, y, columns, rows)
  columns, rows = columns or 1, rows or 1
  region(name, column * SOURCE, row * SOURCE, columns * SOURCE, rows * SOURCE, x, y)
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

-- The town's buildings: column, row, width and height (in tiles) of their sprite in TilesetHouse.
-- Their doors sit where world/townmap.lua says (where each sprite draws its doorway).
local HOUSES = {
  home = { 0, 0, 4, 3 },
  dealer = { 16, 0, 3, 3 },
  museum = { 25, 14, 4, 5 },
  mall = { 12, 0, 4, 3 },
  arcade = { 23, 0, 3, 3 },
}
-- Villagers' houses take these looks in turn.
local HOMES = { { 4, 0, 4, 3 }, { 19, 19, 3, 3 }, { 8, 0, 4, 3 }, { 26, 0, 3, 3 } }

local function look(building)
  if building.kind == "house" then return HOMES[(building.index - 1) % #HOMES + 1] end
  return HOUSES[building.kind]
end

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

-- A stable number per store, so each one always gets the same banner and clerk.
function art.storeHash(store)
  local sum = 0
  for i = 1, #store.id do
    sum = sum + store.id:byte(i) * i
  end
  return sum
end

-- How many tiles wide the building's sprite is (3 or 4).
function art.buildingWidth(building)
  return look(building)[3]
end

-- A store's cloth banner (1x2 tiles), hung by its door in the mall.
function art.banner(store, px, py)
  local banner = BANNERS[art.storeHash(store) % #BANNERS + 1]
  sprite("TilesetHouse", banner[1], banner[2], px, py, 1, 2)
end

-- A plaque sized to the letters themselves rather than the font's full line height.
function art.sign(text, centerX, y, font)
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
-- `label` is the sign over the door (none for villagers' houses).
function art.building(building, label, x, y, width, font)
  local house = look(building)
  sprite("TilesetHouse", house[1], house[2], x, y, house[3], house[4])
  if label then art.sign(label, x + house[3] * art.TILE / 2, y + 6, font) end
end

-- An ad stand in the mall (1x2 tiles at px, py): a framed board on a post, showing `image` (a game's
-- box art; nil while it loads or when there's none).
function art.adStand(px, py, image)
  love.graphics.setColor(0.36, 0.22, 0.13)
  love.graphics.rectangle("fill", px + 14, py + 40, 4, 22)
  love.graphics.rectangle("fill", px + 8, py + 60, 16, 4, 1)
  love.graphics.setColor(0.27, 0.16, 0.10)
  love.graphics.rectangle("fill", px + 1, py + 1, 30, 42, 3)
  love.graphics.setColor(0.98, 0.91, 0.74)
  love.graphics.rectangle("fill", px + 3, py + 3, 26, 38, 2)
  local x, y, w, h = px + 5, py + 5, 22, 34
  if image then
    local scale = math.min(w / image:getWidth(), h / image:getHeight())
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, math.floor(x + (w - image:getWidth() * scale) / 2),
      math.floor(y + (h - image:getHeight() * scale) / 2), 0, scale, scale)
  else
    love.graphics.setColor(0.13, 0.10, 0.08)
    love.graphics.rectangle("fill", x, y, w, h)
  end
  love.graphics.setColor(1, 1, 1)
end

-- A billboard on two posts standing on a 4x3-tile base at (px, py), advertising `title`.
-- The board takes the shape of `image` (the game's box art; nil/false while loading or when there's
-- none, which shows the title instead) and may rise above the base.
local BILLBOARD_MAX_W, BILLBOARD_MAX_H = 112, 108
local BILLBOARD_BOARD_BOTTOM = 66 -- from the top of the base

function art.billboard(px, py, image, title, font)
  local tile = art.TILE
  local centerX = px + 2 * tile
  local w, h = BILLBOARD_MAX_W, 64
  if image then
    local scale = math.min(BILLBOARD_MAX_W / image:getWidth(), BILLBOARD_MAX_H / image:getHeight())
    w, h = math.floor(image:getWidth() * scale), math.floor(image:getHeight() * scale)
  end
  local board = { x = math.floor(centerX - w / 2), y = py + BILLBOARD_BOARD_BOTTOM - h, w = w, h = h }

  love.graphics.setColor(0.36, 0.22, 0.13)
  for _, postX in ipairs({ centerX - 30, centerX + 22 }) do
    love.graphics.rectangle("fill", postX, board.y + board.h, 8, 3 * tile - BILLBOARD_BOARD_BOTTOM - 4)
  end
  love.graphics.setColor(0.27, 0.16, 0.10)
  love.graphics.rectangle("fill", board.x - 4, board.y - 4, board.w + 8, board.h + 8, 4)
  if image then
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, board.x, board.y, 0, board.w / image:getWidth(), board.h / image:getHeight())
  else
    love.graphics.setColor(0.13, 0.10, 0.08)
    love.graphics.rectangle("fill", board.x, board.y, board.w, board.h)
    love.graphics.setColor(0.98, 0.91, 0.74)
    love.graphics.setFont(font)
    love.graphics.printf(title, board.x + 6, board.y + 6, board.w - 12, "center")
  end
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

-- The player's look, as chosen in the intro ("boy" or "girl").
local PLAYER_SHEETS = { boy = "Boy", girl = "Girl" }

function art.player(x, y, facing, frame, look)
  art.character(PLAYER_SHEETS[look] or "Boy", x, y, facing, frame)
end

function art.villager(villager, x, y, facing, frame)
  art.character("villagers/" .. villager.sprite, x, y, facing, frame or 0)
end

-- Inside Home (see world/home.lua). Pieces of wall by home.wallPiece's names, from TilesetWallSimple.
local WALLS = {
  topLeft = { 0, 0 }, top = { 3, 0 }, topBeforeGap = { 1, 0 }, topAfterGap = { 2, 0 }, topRight = { 4, 0 },
  left = { 0, 1 }, leftBeforeGap = { 0, 2 }, leftAfterGap = { 0, 3 },
  right = { 4, 1 }, rightBeforeGap = { 4, 2 }, rightAfterGap = { 4, 3 },
  bottomLeft = { 0, 4 }, bottom = { 3, 4 }, bottomBeforeGap = { 1, 4 }, bottomAfterGap = { 2, 4 }, bottomRight = { 4, 4 },
  -- A wall between two rooms is the left half of one piece next to the right half of another.
  -- Where it meets an outer wall, that wall's straight piece covers the outer half (`top` or `bottom`).
  between = { left = "right", right = "left" },
  betweenBeforeGap = { left = "rightBeforeGap", right = "leftBeforeGap" },
  betweenAfterGap = { left = "rightAfterGap", right = "leftAfterGap" },
  topJoin = { left = "topRight", right = "topLeft", top = "top" },
  bottomJoin = { left = "bottomRight", right = "bottomLeft", bottom = "bottom" },
}
-- Floors repeat a `size` x `size` block of tiles from TilesetInteriorFloor, starting at `column, row`.
local FLOORS = { wood = { column = 11, row = 0, size = 3 }, kitchen = { column = 1, row = 1, size = 1 } }
-- Sheet, column, row, and size in tiles (1x1 when left out). `on` lists things standing on the
-- piece, as sheet, column, row and pixel offset. A one-tile sprite drawn wider has `widen`: the
-- source pixel columns (first, last + 1) repeated between its halves.
local FURNITURE = {
  counter = { "TilesetHouse", 17, 18, 2, 1, on = {
    { "TilesetElement", 0, 10, 2, -10 }, { "TilesetElement", 1, 10, art.TILE + 2, -6 },
  } },
  cupboard = { "TilesetElement", 1, 7, 1, 2 },
  table = { "TilesetElement", 14, 0, 2, 1, widen = { 6, 10 } },
  stool = { "TilesetElement", 5, 7 },
  tv = { "metaretro/Tv", 0, 0, 2, 2 },
  console = { "metaretro/Consoles", 0, 0 },
  sofa = { "metaretro/Sofa", 0, 0, 3, 1 },
  bookshelf = { "TilesetElement", 8, 7, 2, 2 },
  plant = { "TilesetElement", 0, 7, 1, 2 },
  bed = { "TilesetBed", 7, 3, 2, 3 },
  desk = { "TilesetElement", 10, 0 },
  chair = { "TilesetElement", 11, 0 },
  dresser = { "TilesetElement", 6, 7, 2, 2 },
  displayTable = { "TilesetElement", 2, 10, 3, 1 },
  orbStatue = { "TilesetHouse", 3, 15, 2, 2 },
  frogStatue = { "TilesetHouse", 3, 17, 2, 2 },
  pillar = { "TilesetHouse", 0, 15, 1, 3 },
  shopCounter = { "TilesetHouse", 17, 18, 2, 1 },
}
art.OUTSIDE_COLOR = { 0.08, 0.11, 0.11 } -- the black around the walls

-- The floor of tile (x, y); patterns line up with the living room's left wall.
function art.floor(kind, x, y, px, py)
  local floor = FLOORS[kind]
  sprite("TilesetInteriorFloor", floor.column + x % floor.size, floor.row + (y + 1) % floor.size, px, py)
end

function art.wall(piece, px, py)
  local wall = WALLS[piece]
  if wall.left then
    local left, right, half = WALLS[wall.left], WALLS[wall.right], SOURCE / 2
    region("TilesetWallSimple", left[1] * SOURCE, left[2] * SOURCE, half, SOURCE, px, py)
    region("TilesetWallSimple", right[1] * SOURCE + half, right[2] * SOURCE, half, SOURCE, px + art.TILE / 2, py)
    local top, bottom = WALLS[wall.top], WALLS[wall.bottom]
    if top then region("TilesetWallSimple", top[1] * SOURCE, top[2] * SOURCE, SOURCE, half, px, py) end
    if bottom then
      region("TilesetWallSimple", bottom[1] * SOURCE, bottom[2] * SOURCE + half, SOURCE, half, px, py + art.TILE / 2)
    end
  else
    sprite("TilesetWallSimple", wall[1], wall[2], px, py)
  end
end

local function widened(name, column, row, x, y, width, from, to)
  local left, top, half, slice = column * SOURCE, row * SOURCE, SOURCE / 2, to - from
  region(name, left, top, half, SOURCE, x, y)
  for i = 0, (width - 1) * SOURCE / slice - 1 do
    region(name, left + from, top, slice, SOURCE, x + (half + i * slice) * SCALE, y)
  end
  region(name, left + half, top, half, SOURCE, x + (width * SOURCE - half) * SCALE, y)
end

function art.furniture(kind, px, py)
  local piece = FURNITURE[kind]
  if piece.widen then
    widened(piece[1], piece[2], piece[3], px, py, piece[4], piece.widen[1], piece.widen[2])
  else
    sprite(piece[1], piece[2], piece[3], px, py, piece[4], piece[5])
  end
  for _, item in ipairs(piece.on or {}) do
    sprite(item[1], item[2], item[3], px + item[4], py + item[5])
  end
end

-- A shut door over a building's doorway (the console dealer, before the first console).
local CLOSED_DOOR = { "TilesetElement", 8, 13 }

function art.closedDoor(px, py)
  sprite(CLOSED_DOOR[1], CLOSED_DOOR[2], CLOSED_DOOR[3], px, py)
end

-- Consoles drawn after the real hardware (by scripts/draw-consoles), by system id: their column in
-- Consoles.png. Others get the generic console in column 0.
local CONSOLE_LOOKS = require("world.consolelooks")
art.TABLE_TOP = 12 -- how far up something standing on a table is drawn

function art.console(systemId, px, py)
  sprite("metaretro/Consoles", CONSOLE_LOOKS[systemId] or 0, 0, px, py)
end

-- The museum's glass case (1x2 tiles) at (px, py), with `systemId`'s console inside (or empty).
function art.displayCase(systemId, px, py)
  if systemId then art.console(systemId, px, py) end
  sprite("metaretro/DisplayCase", 0, 0, px, py, 1, 2)
end

-- Arcade cabinet `index` (1x2 tiles; four colors, repeating), seen from its side: facing right, or
-- left (mirrored) when `facingLeft`. `cover` (an Image, optional) fills its side panel, like side art.
local CABINET_PANEL = { x = 3, y = 3, width = 7, height = 27 } -- in the sprite's pixels, facing right

function art.cabinet(index, px, py, facingLeft, cover)
  local img = image("metaretro/Cabinets")
  local column = (index - 1) % 4
  local key = "cabinet" .. column
  quads[key] = quads[key] or love.graphics.newQuad(column * SOURCE, 0, SOURCE, 2 * SOURCE, img:getDimensions())
  love.graphics.draw(img, quads[key], facingLeft and px + art.TILE or px, py, 0, facingLeft and -SCALE or SCALE, SCALE)
  if not cover then return end
  local panel = CABINET_PANEL
  local left = facingLeft and SOURCE - panel.x - panel.width or panel.x
  local x, y, w, h = px + left * SCALE, py + panel.y * SCALE, panel.width * SCALE, panel.height * SCALE
  local scale = math.max(w / cover:getWidth(), h / cover:getHeight())
  love.graphics.setScissor(x, y, w, h)
  love.graphics.draw(cover, x + (w - cover:getWidth() * scale) / 2, y + (h - cover:getHeight() * scale) / 2, 0, scale, scale)
  love.graphics.setScissor()
end

-- The villager's portrait for dialogs, as an Image.
function art.portrait(villager)
  return image("villagers/" .. villager.sprite .. "Face")
end

return art

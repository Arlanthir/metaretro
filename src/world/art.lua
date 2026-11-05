-- Placeholder pixel-style art drawn with primitives. Swap for a real tileset later;
-- callers only rely on these functions and the tile size.
local art = {}

art.TILE = 32

local palette = {
  grass = { 0.36, 0.62, 0.31 },
  path = { 0.83, 0.72, 0.52 }, pathEdge = { 0.74, 0.62, 0.43 },
  trunk = { 0.45, 0.30, 0.18 }, leaves = { 0.17, 0.42, 0.20 }, leavesLight = { 0.24, 0.52, 0.25 },
  water = { 0.26, 0.50, 0.80 }, waterLight = { 0.45, 0.68, 0.92 },
  wall = { 0.93, 0.88, 0.78 }, wallShade = { 0.80, 0.74, 0.64 },
  door = { 0.40, 0.25, 0.15 }, window = { 0.55, 0.78, 0.95 },
  dirt = { 0.60, 0.46, 0.30 }, fence = { 0.85, 0.80, 0.70 },
  sign = { 0.20, 0.16, 0.12 }, signText = { 1, 0.95, 0.80 },
  skin = { 0.98, 0.80, 0.65 }, shirt = { 0.85, 0.25, 0.25 }, pants = { 0.20, 0.25, 0.55 }, hair = { 0.30, 0.18, 0.10 },
}

local ROOFS = {
  home = { 0.80, 0.30, 0.25 },
  dealer = { 0.45, 0.30, 0.70 },
}
local STORE_ROOFS = {
  { 0.20, 0.55, 0.75 }, { 0.85, 0.55, 0.15 }, { 0.25, 0.60, 0.40 },
  { 0.70, 0.25, 0.45 }, { 0.35, 0.40, 0.75 }, { 0.75, 0.70, 0.20 },
}

local function color(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end

local function rect(c, x, y, w, h)
  color(c)
  love.graphics.rectangle("fill", x, y, w, h)
end

local function grass(x, y, tx, ty)
  local t = art.TILE
  rect(palette.grass, x, y, t, t)
  if (tx * 7 + ty * 3) % 5 == 0 then
    rect(palette.leavesLight, x + 8, y + 12, 2, 4)
    rect(palette.leavesLight, x + 20, y + 22, 2, 4)
  end
end

function art.ground(tile, x, y, tx, ty)
  local t = art.TILE
  if tile == "=" or tile == "@" then
    rect(palette.path, x, y, t, t)
    rect(palette.pathEdge, x + 6, y + 10, 3, 3)
    rect(palette.pathEdge, x + 22, y + 24, 3, 3)
  elseif tile == "~" then
    rect(palette.water, x, y, t, t)
    rect(palette.waterLight, x + 6 + (tx % 2) * 10, y + 10, 10, 2)
  else
    grass(x, y, tx, ty)
    if tile == "T" then
      rect(palette.trunk, x + 13, y + 20, 6, 10)
      color(palette.leaves)
      love.graphics.circle("fill", x + 16, y + 14, 12)
      color(palette.leavesLight)
      love.graphics.circle("fill", x + 12, y + 10, 5)
    end
  end
end

local function sign(text, centerX, y, font)
  local width = font:getWidth(text) + 10
  rect(palette.sign, centerX - width / 2, y, width, font:getHeight() + 4)
  color(palette.signText)
  love.graphics.setFont(font)
  love.graphics.print(text, math.floor(centerX - font:getWidth(text) / 2), y + 2)
end

local function roofColor(building)
  if building.kind == "store" then
    local hash = 0
    for i = 1, #building.console.id do
      hash = hash + building.console.id:byte(i) * i
    end
    return STORE_ROOFS[hash % #STORE_ROOFS + 1]
  end
  return ROOFS[building.kind]
end

-- `x, y` is the building's top-left pixel; `doorColumn` is the door's offset in tiles.
function art.building(building, label, x, y, columns, rows, doorColumn, font)
  local t = art.TILE
  local width, height = columns * t, rows * t
  if building.kind == "lot" then
    rect(palette.dirt, x + 4, y + t, width - 8, height - t - 4)
    color(palette.fence)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x + 4, y + t, width - 8, height - t - 4)
    love.graphics.setLineWidth(1)
    sign(label, x + width / 2, y + t + 18, font)
    return
  end

  rect(palette.wall, x + 2, y + t, width - 4, height - t)
  rect(palette.wallShade, x + 2, y + height - 6, width - 4, 6)
  color(roofColor(building))
  love.graphics.polygon("fill", x - 2, y + t + 4, x + 10, y + 2, x + width - 10, y + 2, x + width + 2, y + t + 4)
  for column = 0, columns - 1 do
    if column ~= doorColumn then
      rect(palette.window, x + column * t + 8, y + height - t + 4, 16, 12)
    end
  end
  rect(palette.door, x + doorColumn * t + 6, y + height - t + 2, t - 12, t - 2)
  sign(label, x + width / 2, y + t + 4, font)
end

-- `step` alternates 0/1 while walking.
function art.player(x, y, facing, step)
  local bob = step == 1 and -2 or 0
  color({ 0, 0, 0 }, 0.25)
  love.graphics.ellipse("fill", x + 16, y + 29, 10, 4)
  rect(palette.pants, x + 10, y + 20 + bob, 5, 8 - bob)
  rect(palette.pants, x + 17, y + 20 + bob, 5, 8 - bob)
  rect(palette.shirt, x + 9, y + 12 + bob, 14, 10)
  rect(palette.skin, x + 10, y + 3 + bob, 12, 10)
  rect(palette.hair, x + 10, y + 2 + bob, 12, facing == "up" and 10 or 4)
  if facing == "down" then
    rect({ 0, 0, 0 }, x + 13, y + 8 + bob, 2, 2)
    rect({ 0, 0, 0 }, x + 18, y + 8 + bob, 2, 2)
  elseif facing == "left" then
    rect({ 0, 0, 0 }, x + 11, y + 8 + bob, 2, 2)
  elseif facing == "right" then
    rect({ 0, 0, 0 }, x + 19, y + 8 + bob, 2, 2)
  end
end

return art

local covers = require("services.covers")

local ui = {}

ui.WIDTH, ui.HEIGHT = 640, 480
ui.MARGIN = 16
ui.HEADER_HEIGHT = 40

ui.colors = {
  background = { 0.08, 0.07, 0.12 },
  panel = { 0.15, 0.13, 0.22 },
  highlight = { 0.95, 0.75, 0.25 },
  text = { 0.95, 0.94, 0.9 },
  muted = { 0.6, 0.58, 0.68 },
  coin = { 1.0, 0.85, 0.3 },
  trophy = { 0.52, 0.58, 0.72 },
}

function ui.load()
  ui.fonts = {
    small = love.graphics.newFont(12),
    body = love.graphics.newFont(15),
    title = love.graphics.newFont(20),
  }
end

function ui.setColor(name, alpha)
  local c = ui.colors[name]
  love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end

function ui.header(title, wallet)
  ui.setColor("panel")
  love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEADER_HEIGHT)
  love.graphics.setFont(ui.fonts.title)
  local coins = ("%d coins"):format(wallet)
  local titleWidth = ui.WIDTH - ui.MARGIN * 3 - ui.fonts.title:getWidth(coins)
  ui.setColor("text")
  love.graphics.print(ui.truncate(ui.fonts.title, title, titleWidth), ui.MARGIN, 9)
  ui.setColor("coin")
  love.graphics.printf(coins, 0, 9, ui.WIDTH - ui.MARGIN, "right")
end

function ui.footer(hint)
  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  love.graphics.printf(hint, ui.MARGIN, ui.HEIGHT - 22, ui.WIDTH - ui.MARGIN * 2, "center")
end

local truncated = setmetatable({}, { __mode = "k" })

-- Cuts `text` with "..." so it fits on one line of `maxWidth`; results are cached per font.
function ui.truncate(font, text, maxWidth)
  truncated[font] = truncated[font] or {}
  local key = maxWidth .. "\0" .. text
  local cached = truncated[font][key]
  if cached then return cached end
  local result = text
  if font:getWidth(text) > maxWidth then
    local low, high = 0, #text
    while low < high do
      local mid = math.ceil((low + high) / 2)
      if font:getWidth(text:sub(1, mid) .. "...") <= maxWidth then low = mid else high = mid - 1 end
    end
    -- Don't cut a multi-byte UTF-8 character in half.
    while low > 0 and text:byte(low + 1) and text:byte(low + 1) >= 0x80 and text:byte(low + 1) < 0xC0 do
      low = low - 1
    end
    result = text:sub(1, low):gsub("%s+$", "") .. "..."
  end
  truncated[font][key] = result
  return result
end

-- A small cup silhouette marking games with RetroAchievements.
function ui.trophy(x, y)
  ui.setColor("trophy")
  love.graphics.rectangle("fill", x + 2, y, 8, 5, 2)
  love.graphics.rectangle("fill", x + 3, y + 4, 6, 2)
  love.graphics.rectangle("fill", x, y + 1, 2, 3)
  love.graphics.rectangle("fill", x + 10, y + 1, 2, 3)
  love.graphics.rectangle("fill", x + 5, y + 6, 2, 3)
  love.graphics.rectangle("fill", x + 3, y + 9, 6, 2)
end

local STAR_SIZE, STAR_SPACING = 12, 14
local starTriangles

-- Five stars filled to `rating` (0..1, ES style) in half-star steps.
function ui.stars(x, y, rating)
  if not starTriangles then
    local points, r = {}, STAR_SIZE / 2
    for i = 0, 9 do
      local angle = -math.pi / 2 + i * math.pi / 5
      local radius = i % 2 == 0 and r or r * 0.45
      table.insert(points, r + math.cos(angle) * radius)
      table.insert(points, r + math.sin(angle) * radius)
    end
    starTriangles = love.math.triangulate(points)
  end
  local filled = math.floor(math.max(0, math.min(1, rating)) * 10 + 0.5) / 2
  for i = 0, 4 do
    local starX = x + i * STAR_SPACING
    for layer = 1, 2 do
      local fill = layer == 1 and 1 or math.max(0, math.min(1, filled - i))
      if fill > 0 then
        if layer == 1 then ui.setColor("muted", 0.35) else ui.setColor("highlight") end
        love.graphics.setScissor(starX, y, STAR_SIZE * fill, STAR_SIZE)
        for _, triangle in ipairs(starTriangles) do
          love.graphics.polygon("fill", starX + triangle[1], y + triangle[2], starX + triangle[3], y + triangle[4],
            starX + triangle[5], y + triangle[6])
        end
      end
    end
  end
  love.graphics.setScissor()
end

-- Draws a scrolling list; `label(item)` returns the text, an optional right-aligned value
-- and whether to mark the row with a trophy.
-- Returns the scroll offset that keeps the cursor visible.
function ui.list(items, cursor, scroll, x, y, width, height, label)
  local rowHeight = 24
  local visible = math.floor(height / rowHeight)
  scroll = math.max(math.min(scroll, cursor - 1), cursor - visible, 0)
  love.graphics.setFont(ui.fonts.body)
  for row = 1, math.min(visible, #items - scroll) do
    local index = scroll + row
    local rowY = y + (row - 1) * rowHeight
    if index == cursor then
      ui.setColor("highlight", 0.25)
      love.graphics.rectangle("fill", x, rowY, width, rowHeight, 4)
      ui.setColor("highlight")
    else
      ui.setColor("text")
    end
    local text, value, trophy = label(items[index])
    local valueWidth = value and ui.fonts.body:getWidth(value) + 12 or 0
    local trophyWidth = trophy and 18 or 0
    love.graphics.print(ui.truncate(ui.fonts.body, text, width - 16 - valueWidth - trophyWidth), x + 8, rowY + 4)
    if trophy then
      local r, g, b, a = love.graphics.getColor()
      ui.trophy(x + width - 8 - valueWidth - 14, rowY + 6)
      love.graphics.setColor(r, g, b, a)
    end
    if value then
      love.graphics.printf(value, x + 8, rowY + 4, width - 16, "right")
    end
  end
  return scroll
end

function ui.drawCover(path, x, y, width, height)
  local image = path and covers.get(path)
  if image then
    local scale = math.min(width / image:getWidth(), height / image:getHeight())
    local w, h = image:getWidth() * scale, image:getHeight() * scale
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, x + (width - w) / 2, y + (height - h) / 2, 0, scale, scale)
  else
    ui.setColor("panel")
    love.graphics.rectangle("fill", x, y, width, height, 6)
    ui.setColor("muted")
    love.graphics.setFont(ui.fonts.small)
    love.graphics.printf(image == nil and path and "loading..." or "no cover", x, y + height / 2 - 6, width, "center")
  end
end

function ui.year(game)
  return game.releasedate and game.releasedate:sub(1, 4) or "????"
end

return ui

local covers = require("services.covers")

-- Menu look: Ninja Adventure UI pieces (CC0) and the Jersey 10 font (OFL), see src/assets.
local ui = {}

ui.WIDTH, ui.HEIGHT = 640, 480
ui.MARGIN = 24 -- content inset from the screen edge, inside the content panel's frame
ui.HEADER_HEIGHT = 52 -- where content starts below the header bar
ui.FOOTER_HEIGHT = 44

ui.colors = {
  background = { 0.12, 0.14, 0.10 },
  panelFill = { 0.22, 0.19, 0.15 }, -- inside of framed panels
  panel = { 0.31, 0.27, 0.21 }, -- placeholders inside panels
  highlight = { 0.98, 0.58, 0.28 },
  selection = { 1.0, 0.68, 0.33 },
  text = { 0.96, 0.91, 0.79 },
  muted = { 0.72, 0.64, 0.52 },
  coin = { 1.0, 0.78, 0.32 },
  stars = { 1.0, 0.76, 0.22 },
  trophy = { 0.64, 0.70, 0.84 },
}

local SCALE = 2
local FRAME_SCALE = 1
local UI_DIR = "assets/ninja-adventure/ui/"
local images = {}

local function image(name)
  images[name] = images[name] or love.graphics.newImage(UI_DIR .. name .. ".png")
  return images[name]
end

local function font(size)
  local f = love.graphics.newFont("assets/fonts/Jersey10.ttf", size, "mono")
  -- Characters the pixel font lacks (e.g. kana) come from LÖVE's default font instead of boxes.
  f:setFallbacks(love.graphics.newFont(size))
  return f
end

local background

function ui.load()
  ui.fonts = { small = font(20), body = font(20), title = font(30) }
  -- Darkened grass from the town, so menus feel like they're laid over it.
  local grass = love.graphics.newImage("assets/ninja-adventure/TilesetFloor.png")
  local tile = love.graphics.newQuad(0, 192, 16, 16, grass:getDimensions())
  background = love.graphics.newCanvas(ui.WIDTH, ui.HEIGHT)
  love.graphics.setCanvas(background)
  love.graphics.setColor(0.38, 0.42, 0.34)
  for y = 0, ui.HEIGHT, 32 do
    for x = 0, ui.WIDTH, 32 do
      love.graphics.draw(grass, tile, x, y, 0, SCALE, SCALE)
    end
  end
  love.graphics.setCanvas()
  love.graphics.setColor(1, 1, 1)
end

function ui.setColor(name, alpha)
  local c = ui.colors[name]
  love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end

-- Nine-slice of the panel image: a wooden frame (6px left/top, 5px right/bottom at 1x) around white.
local PANEL_INSETS = { 6, 6, 5, 5 }
local panelQuads

local panelImage

-- The pack's panel with its white inside recoloured to `panelFill`.
local function loadPanel()
  local data = love.image.newImageData(UI_DIR .. "Panel.png")
  local fill = ui.colors.panelFill
  data:mapPixel(function(_, _, r, g, b, a)
    if r == 1 and g == 1 and b == 1 then return fill[1], fill[2], fill[3], a end
    return r, g, b, a
  end)
  return love.graphics.newImage(data)
end

function ui.panel(x, y, width, height)
  panelImage = panelImage or loadPanel()
  local img = panelImage
  local w, h = img:getDimensions()
  local l, t, r, b = unpack(PANEL_INSETS)
  if not panelQuads then
    panelQuads = {}
    local xs, ws = { 0, l, w - r }, { l, w - l - r, r }
    local ys, hs = { 0, t, h - b }, { t, h - t - b, b }
    for row = 1, 3 do
      for column = 1, 3 do
        panelQuads[(row - 1) * 3 + column] = love.graphics.newQuad(xs[column], ys[row], ws[column], hs[row], w, h)
      end
    end
  end
  local scale = FRAME_SCALE
  local innerW, innerH = width - (l + r) * scale, height - (t + b) * scale
  local columnX, columnW = { x, x + l * scale, x + width - r * scale }, { l, innerW / scale, r }
  local rowY, rowH = { y, y + t * scale, y + height - b * scale }, { t, innerH / scale, b }
  local sourceW, sourceH = { l, w - l - r, r }, { t, h - t - b, b }
  love.graphics.setColor(1, 1, 1)
  for row = 1, 3 do
    for column = 1, 3 do
      love.graphics.draw(img, panelQuads[(row - 1) * 3 + column], columnX[column], rowY[row], 0,
        scale * columnW[column] / sourceW[column], scale * rowH[row] / sourceH[row])
    end
  end
end

-- A spinning-coin icon (first frame) followed by the amount, right-aligned to `right`.
function ui.coins(amount, right, y)
  local text = tostring(amount)
  local f = ui.fonts.body
  local x = right - f:getWidth(text)
  love.graphics.setFont(f)
  ui.setColor("text")
  love.graphics.print(text, x, y)
  local coin = image("Coin")
  local quad = love.graphics.newQuad(0, 0, 10, 10, coin:getDimensions())
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(coin, quad, x - 24, y + (f:getHeight() - 20) / 2, 0, SCALE, SCALE)
  return x - 24
end

function ui.backdrop()
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(background, 0, 0)
end

-- Screen backdrop, header bar with the title and wallet, and the content panel below it.
function ui.header(title, wallet)
  ui.backdrop()
  ui.panel(4, ui.HEADER_HEIGHT - 4, ui.WIDTH - 8, ui.HEIGHT - ui.HEADER_HEIGHT - ui.FOOTER_HEIGHT + 4)
  ui.panel(4, 4, ui.WIDTH - 8, 44)
  local coinsLeft = ui.coins(wallet, ui.WIDTH - 22, 15)
  love.graphics.setFont(ui.fonts.title)
  ui.setColor("text")
  love.graphics.print(ui.truncate(ui.fonts.title, title, coinsLeft - 40), 20, 9)
end

-- Button names in hints map to their icons; "L/R" shows both shoulder buttons.
local BUTTON_ICONS = {
  A = { "ButtonA" }, B = { "ButtonB" }, X = { "ButtonX" }, Y = { "ButtonY" },
  ["L/R"] = { "ButtonLB", "ButtonRB" }, Up = { "DPadUp" }, Start = { "Start" }, Select = { "Select" },
}

-- Hints look like "A: buy   B: leave": entries separated by 2+ spaces, each "<button>: <label>".
local function parseHint(hint)
  local entries = {}
  for entry in (hint .. "  "):gmatch("(.-)%s%s+") do
    local button, label = entry:match("^(%S+):%s*(.*)$")
    if button and BUTTON_ICONS[button] then
      table.insert(entries, { icons = BUTTON_ICONS[button], label = label })
    elseif entry ~= "" then
      table.insert(entries, { icons = {}, label = entry })
    end
  end
  return entries
end

local function hintWidth(entries)
  local f, width = ui.fonts.small, 0
  for i, entry in ipairs(entries) do
    for _, icon in ipairs(entry.icons) do
      width = width + image(icon):getWidth() + 3
    end
    width = width + f:getWidth(entry.label) + (i < #entries and 18 or 0)
  end
  return width
end

local function drawHint(entries, x, centerY)
  local f = ui.fonts.small
  love.graphics.setFont(f)
  for _, entry in ipairs(entries) do
    for _, icon in ipairs(entry.icons) do
      local img = image(icon)
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(img, x, math.floor(centerY - img:getHeight() / 2))
      x = x + img:getWidth() + 3
    end
    ui.setColor("text")
    love.graphics.print(entry.label, x, math.floor(centerY - f:getHeight() / 2))
    x = x + f:getWidth(entry.label) + 18
  end
end

-- Full-width hint bar at the bottom of menu screens.
function ui.footer(hint)
  local entries = parseHint(hint)
  local top = ui.HEIGHT - ui.FOOTER_HEIGHT + 4
  ui.panel(4, top, ui.WIDTH - 8, ui.FOOTER_HEIGHT - 8)
  drawHint(entries, math.floor(ui.WIDTH / 2 - hintWidth(entries) / 2), top + (ui.FOOTER_HEIGHT - 8) / 2)
end

-- A hint in a panel just big enough for it, centred on `centerX` (used over the town).
function ui.hintPanel(hint, centerX, y)
  local entries = parseHint(hint)
  local width = hintWidth(entries) + 40
  ui.panel(math.floor(centerX - width / 2), y, width, 36)
  drawHint(entries, math.floor(centerX - width / 2) + 20, y + 18)
end

-- Text in a panel just big enough for it, centred on `centerX`.
function ui.messagePanel(text, centerX, y, colorName)
  local f = ui.fonts.body
  local width = f:getWidth(text) + 40
  ui.panel(math.floor(centerX - width / 2), y, width, 38)
  love.graphics.setFont(f)
  ui.setColor(colorName or "text")
  love.graphics.print(text, math.floor(centerX - f:getWidth(text) / 2), y + 10)
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
        if layer == 1 then ui.setColor("muted", 0.3) else ui.setColor("stars") end
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
  local f = ui.fonts.body
  love.graphics.setFont(f)
  for row = 1, math.min(visible, #items - scroll) do
    local index = scroll + row
    local rowY = y + (row - 1) * rowHeight
    local textY = rowY + math.floor((rowHeight - f:getHeight()) / 2)
    if index == cursor then
      ui.setColor("selection", 0.45)
      love.graphics.rectangle("fill", x, rowY, width, rowHeight, 3)
      ui.setColor("text")
      local centerY = rowY + rowHeight / 2
      love.graphics.polygon("fill", x + 6, centerY - 6, x + 6, centerY + 6, x + 13, centerY)
    end
    local text, value, trophy = label(items[index])
    local valueWidth = value and f:getWidth(value) + 12 or 0
    local trophyWidth = trophy and 18 or 0
    ui.setColor("text")
    love.graphics.print(ui.truncate(f, text, width - 28 - valueWidth - trophyWidth), x + 20, textY)
    if trophy then
      ui.trophy(x + width - 8 - valueWidth - 14, rowY + 6)
    end
    if value then
      ui.setColor("coin")
      love.graphics.printf(value, x + 8, textY, width - 16, "right")
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

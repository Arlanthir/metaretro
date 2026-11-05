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
}

local coverCache = {}

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
  ui.setColor("text")
  love.graphics.print(title, ui.MARGIN, 9)
  ui.setColor("coin")
  love.graphics.printf(("%d coins"):format(wallet), 0, 9, ui.WIDTH - ui.MARGIN, "right")
end

function ui.footer(hint)
  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  love.graphics.printf(hint, ui.MARGIN, ui.HEIGHT - 22, ui.WIDTH - ui.MARGIN * 2, "center")
end

-- Draws a scrolling list of labels; returns the scroll offset to keep the cursor visible.
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
    love.graphics.printf(label(items[index]), x + 8, rowY + 4, width - 16, "left")
  end
  return scroll
end

-- Covers live outside the LÖVE sandbox, so read them through io.
function ui.cover(path)
  if not path then return nil end
  if coverCache[path] == nil then
    local image = false
    local file = io.open(path, "rb")
    if file then
      local data = file:read("*a")
      file:close()
      local ok, result = pcall(function()
        return love.graphics.newImage(love.filesystem.newFileData(data, path))
      end)
      image = ok and result or false
    end
    coverCache[path] = image
  end
  return coverCache[path] or nil
end

function ui.drawCover(path, x, y, width, height)
  local image = ui.cover(path)
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
    love.graphics.printf("no cover", x, y + height / 2 - 6, width, "center")
  end
end

function ui.year(game)
  return game.releasedate and game.releasedate:sub(1, 4) or "????"
end

return ui

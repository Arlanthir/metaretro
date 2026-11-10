local scenes = require("core.scenes")
local battery = require("services.battery")
local ui = require("ui")
local Confirm = require("scenes.confirm")

-- A small menu over whatever is below: the Start menu (Settings, Quit), and Settings itself.
-- Items are { label, run(), value() (optional) }; an item with a value shows it on the right, and
-- Left/Right change it as A does. `onClose` (optional) runs when the menu closes.
local Menu = { drawBelow = true }
Menu.__index = Menu

function Menu.new(title, items, width, hint, onClose)
  return setmetatable({ title = title, items = items, width = width, hint = hint, onClose = onClose, cursor = 1 }, Menu)
end

local SETTINGS = {
  { key = "showPeripheral", label = "Light gun & peripheral games" },
  { key = "showJapanese", label = "Japanese-only games" },
}

-- Showing or hiding groups of games everywhere in town; applied when the player leaves Settings.
-- From the title screen too, before there's a game going.
function Menu.settings(app)
  local settings, before = app.settings, {}
  local items = {}
  for _, setting in ipairs(SETTINGS) do
    before[setting.key] = settings[setting.key] == true
    table.insert(items, {
      label = setting.label,
      value = function() return settings[setting.key] and "Shown" or "Hidden" end,
      run = function() settings[setting.key] = not settings[setting.key] end,
    })
  end
  return Menu.new("Settings", items, 480, "A: change   B: back", function()
    for _, setting in ipairs(SETTINGS) do
      if (settings[setting.key] == true) ~= before[setting.key] then return app:applySettings() end
    end
  end)
end

-- What Start opens, wherever the player walks, with the time and the battery under its options.
function Menu.pause(app)
  local menu = Menu.new("Menu", {
    { label = "Settings", run = function() scenes.push(Menu.settings(app)) end },
    { label = "Quit", run = Confirm.quit },
  }, 220, "A: choose   B: back")
  menu.status = true
  return menu
end

local STATUS_HEIGHT = 30

-- The clock on the left and the battery on the right (left out when there's no battery to read).
local function drawStatus(x, y, width)
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("muted")
  love.graphics.print(os.date("%H:%M"), x, y)
  local percent, charging = battery.get()
  if not percent then return end
  local label = ("%d%%"):format(percent)
  local labelX = x + width - ui.fonts.body:getWidth(label)
  love.graphics.print(label, labelX, y)
  ui.battery(labelX - 30, y + ui.iconOffset(12), percent, charging)
end

function Menu:leave()
  if self.onClose then self.onClose() end
end

function Menu:action(name)
  local item = self.items[self.cursor]
  if name == "up" then
    self.cursor = (self.cursor - 2) % #self.items + 1
  elseif name == "down" then
    self.cursor = self.cursor % #self.items + 1
  elseif name == "a" or (name == "left" or name == "right") and item.value then
    item.run()
  elseif name == "b" or name == "start" then
    scenes.pop()
  end
end

function Menu:draw()
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEIGHT)

  local listHeight = #self.items * ui.LIST_ROW
  local height = listHeight + 100 + (self.status and STATUS_HEIGHT or 0)
  local x, y = math.floor((ui.WIDTH - self.width) / 2), math.floor((ui.HEIGHT - height) / 2)
  ui.panel(x, y, self.width, height)
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("highlight")
  love.graphics.printf(self.title, x, y + 16, self.width, "center")
  ui.list(self.items, self.cursor, 0, x + 16, y + 52, self.width - 32, listHeight,
    function(item) return item.label, item.value and item.value() end)
  -- Down by the bottom of the panel, just above the hint, apart from the options.
  if self.status then drawStatus(x + 24, y + height - 52, self.width - 48) end
  ui.hintPanel(self.hint, ui.WIDTH / 2, y + height - 18)
end

return Menu

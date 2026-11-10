local scenes = require("core.scenes")
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
function Menu.settings(app)
  local settings, before = app.state.settings, {}
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

-- What Start opens, wherever the player walks.
function Menu.pause(app)
  return Menu.new("Menu", {
    { label = "Settings", run = function() scenes.push(Menu.settings(app)) end },
    { label = "Quit", run = Confirm.quit },
  }, 220, "A: choose   B: back")
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
  local height = listHeight + 100
  local x, y = math.floor((ui.WIDTH - self.width) / 2), math.floor((ui.HEIGHT - height) / 2)
  ui.panel(x, y, self.width, height)
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("highlight")
  love.graphics.printf(self.title, x, y + 16, self.width, "center")
  ui.list(self.items, self.cursor, 0, x + 16, y + 52, self.width - 32, listHeight,
    function(item) return item.label, item.value and item.value() end)
  ui.hintPanel(self.hint, ui.WIDTH / 2, y + height - 18)
end

return Menu

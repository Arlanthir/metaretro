local scenes = require("core.scenes")
local ui = require("ui")

local Confirm = { drawBelow = true }
Confirm.__index = Confirm

function Confirm.new(message, onConfirm)
  return setmetatable({ message = message, onConfirm = onConfirm }, Confirm)
end

-- A message with only an OK button.
function Confirm.notice(message)
  return Confirm.new(message, nil)
end

function Confirm:action(name)
  if name == "a" then
    scenes.pop()
    if self.onConfirm then self.onConfirm() end
  elseif name == "b" then
    scenes.pop()
  end
end

function Confirm:draw()
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEIGHT)

  local width = 360
  local _, lines = ui.fonts.body:getWrap(self.message, width - 32)
  local height = math.max(110, #lines * ui.fonts.body:getHeight() + 70)
  local x, y = (ui.WIDTH - width) / 2, (ui.HEIGHT - height) / 2
  ui.setColor("panel")
  love.graphics.rectangle("fill", x, y, width, height, 8)
  ui.setColor("highlight")
  love.graphics.rectangle("line", x, y, width, height, 8)

  love.graphics.setFont(ui.fonts.body)
  ui.setColor("text")
  love.graphics.printf(self.message, x + 16, y + 24, width - 32, "center")
  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  love.graphics.printf(self.onConfirm and "A: yes   B: no" or "A: OK", x, y + height - 30, width, "center")
end

return Confirm

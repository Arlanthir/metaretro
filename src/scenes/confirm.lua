local log = require("core.log")
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

-- Asks whether to quit Metaretro (Start, wherever the player is).
function Confirm.quit()
  scenes.push(Confirm.new("Quit Metaretro?", function()
    log("quit confirmed by player")
    love.event.quit()
  end))
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

  local width = 380
  local _, lines = ui.fonts.body:getWrap(self.message, width - 48)
  local height = math.max(120, #lines * ui.fonts.body:getHeight() + 84)
  local x, y = math.floor((ui.WIDTH - width) / 2), math.floor((ui.HEIGHT - height) / 2)
  ui.panel(x, y, width, height)

  love.graphics.setFont(ui.fonts.body)
  ui.setColor("text")
  love.graphics.printf(self.message, x + 24, y + 24, width - 48, "center")
  ui.hintPanel(self.onConfirm and "A: yes   B: no" or "A: OK", ui.WIDTH / 2, y + height - 18)
end

return Confirm

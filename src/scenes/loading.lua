local ui = require("ui")

-- Shows a message, then runs blocking work once that frame has been presented.
local Loading = {}
Loading.__index = Loading

function Loading.new(message, work)
  return setmetatable({ message = message, work = work, drawn = false }, Loading)
end

function Loading:update()
  if self.drawn and self.work then
    local work = self.work
    self.work = nil
    work()
  end
end

function Loading:draw()
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("muted")
  love.graphics.printf(self.message, 0, ui.HEIGHT / 2 - 8, ui.WIDTH, "center")
  self.drawn = true
end

return Loading

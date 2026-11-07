local ui = require("ui")

-- Shows a message, then runs blocking work once that frame has been presented and `ready()`
-- (optional) says it can start.
local Loading = {}
Loading.__index = Loading

function Loading.new(message, work, ready)
  return setmetatable({ message = message, work = work, ready = ready, drawn = false }, Loading)
end

function Loading:update()
  if self.drawn and self.work and (not self.ready or self.ready()) then
    local work = self.work
    self.work = nil
    work()
  end
end

function Loading:draw()
  ui.backdrop()
  ui.messagePanel(self.message, ui.WIDTH / 2, ui.HEIGHT / 2 - 19)
  self.drawn = true
end

return Loading

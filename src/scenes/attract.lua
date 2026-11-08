-- An arcade cabinet up close: the game's video plays on a loop like on the TV (or its screenshot
-- shows, or just its name). A plays the game for a coin; B steps back.
local scenes = require("core.scenes")
local covers = require("services.covers")
local video = require("services.video")
local ui = require("ui")

local Attract = {}
Attract.__index = Attract

-- `play` runs when the player presses A (it pays and launches the game).
function Attract.new(game, price, play)
  return setmetatable({ game = game, price = price, play = play }, Attract)
end

function Attract:enter()
  covers.prefetch({ ui.fullImage(self.game) })
  if self.game.video then video.play(self.game.video) else self.noVideo = true end
end

function Attract:update(dt)
  if self.noVideo then return end
  video.update(dt)
  local finished, failed = video.finished()
  if failed then
    video.stop()
    self.noVideo = true
  elseif finished then
    video.play(self.game.video) -- attract mode loops
  end
end

function Attract:leave()
  video.stop()
end

function Attract:action(name)
  if name == "a" then
    scenes.pop()
    self.play()
  elseif name == "b" then
    scenes.pop()
  end
end

function Attract:draw()
  love.graphics.clear(0, 0, 0)
  love.graphics.setColor(1, 1, 1)
  local frame = not self.noVideo and video.frame()
  local path = ui.fullImage(self.game)
  local image = frame or path and covers.get(path)
  if image then
    local scale = math.min(ui.WIDTH / image:getWidth(), (ui.HEIGHT - 120) / image:getHeight())
    if frame then scale = math.min(ui.WIDTH / video.WIDTH, ui.HEIGHT / video.HEIGHT) end
    love.graphics.draw(image, math.floor((ui.WIDTH - image:getWidth() * scale) / 2),
      math.floor((ui.HEIGHT - image:getHeight() * scale) / 2), 0, scale, scale)
  elseif self.noVideo then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("text")
    love.graphics.printf(self.game.name, 40, ui.HEIGHT / 2 - 10, ui.WIDTH - 80, "center")
  end
  ui.messagePanel(ui.truncate(ui.fonts.body, self.game.name, ui.WIDTH - 80), ui.WIDTH / 2, 8)
  ui.hintPanel(("A: play (%d coin)   B: back"):format(self.price), ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Attract

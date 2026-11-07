-- The TV at home: a nonstop reel of videos of the games on sale in town today, in random order.
local progression = require("core.progression")
local scenes = require("core.scenes")
local stores = require("core.stores")
local video = require("services.video")
local ui = require("ui")

local Tv = {}
Tv.__index = Tv

function Tv.new(app)
  local timeline = progression.timeline(app.catalog.systems)
  local reel = stores.onSale(app.state, app.catalog, timeline, os.date("%Y-%m-%d"), love.math.random,
    function(game) return game.video ~= nil end)
  app:persist() -- listing what's on sale can roll a store's picks for the day
  for i = #reel, 2, -1 do
    local j = love.math.random(i)
    reel[i], reel[j] = reel[j], reel[i]
  end
  return setmetatable({ reel = reel, index = 0 }, Tv)
end

function Tv:enter()
  self:next()
end

function Tv:next()
  if #self.reel == 0 then return end
  self.index = self.index % #self.reel + 1
  video.play(self.reel[self.index].game.video)
end

-- Moves on when a video ends. One that can't play (a missing file, or no ffmpeg) leaves the reel.
function Tv:update(dt)
  video.update(dt)
  local finished, failed = video.finished()
  if not finished then return end
  if failed then
    table.remove(self.reel, self.index)
    self.index = self.index - 1
    if #self.reel == 0 then
      video.stop()
      self.noSignal = true
      return
    end
  end
  self:next()
end

function Tv:action(name)
  if (name == "a" or name == "right") and #self.reel > 0 then
    self:next()
  elseif name == "b" then
    video.stop()
    scenes.pop()
  end
end

function Tv:draw()
  love.graphics.clear(0, 0, 0)
  local frame = video.frame()
  if frame then
    local scale = math.min(ui.WIDTH / video.WIDTH, ui.HEIGHT / video.HEIGHT)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(frame, math.floor((ui.WIDTH - video.WIDTH * scale) / 2),
      math.floor((ui.HEIGHT - video.HEIGHT * scale) / 2), 0, scale, scale)
  elseif #self.reel == 0 or self.noSignal then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("muted")
    local text = self.noSignal and "No signal." or "Nothing on TV today. The shops have no game videos."
    love.graphics.printf(text, 0, ui.HEIGHT / 2 - 10, ui.WIDTH, "center")
  end

  local item = self.reel[self.index]
  if item then
    local caption = ("%s at the %s"):format(item.game.name, item.store.title)
    ui.messagePanel(ui.truncate(ui.fonts.body, caption, ui.WIDTH - 80), ui.WIDTH / 2, 8)
  end
  ui.hintPanel(#self.reel > 0 and "A: next   B: turn off" or "B: turn off",
    ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Tv

-- An arcade cabinet up close, filling the screen: its marquee (the game's scraped marquee, or its
-- name), and its screen, which shows the game's screenshot until its video loads and then the video
-- on a loop, both fitted to the same 4:3 screen so one gives way to the other seamlessly. A plays
-- the game for a coin; B steps back.
local scenes = require("core.scenes")
local covers = require("services.covers")
local video = require("services.video")
local ui = require("ui")

local Attract = {}
Attract.__index = Attract

local SCREEN = { x = 96, y = 72, width = 448, height = 336 } -- 4:3, like the videos' frames
local MARQUEE = { x = 72, y = 8, width = 496, height = 52 }
-- Cabinet colors, matching the cabinets in the Arcade Club (scripts/draw-consoles).
local SIDES = { { 0.88, 0.22, 0.30 }, { 0.18, 0.41, 0.48 }, { 0.34, 0.53, 0.30 }, { 0.65, 0.38, 0.55 } }

-- `cabinet` is the cabinet's number (for its color); `play` runs when the player presses A.
function Attract.new(game, price, play, cabinet)
  return setmetatable({ game = game, price = price, play = play, side = SIDES[((cabinet or 1) - 1) % #SIDES + 1] }, Attract)
end

local function screenshot(game)
  return ui.fullImage(game)
end

function Attract:enter()
  covers.prefetch({ screenshot(self.game), self.game.marquee })
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

-- Draws `image` as large as fits in `box`, centered.
local function fit(image, box)
  local scale = math.min(box.width / image:getWidth(), box.height / image:getHeight())
  love.graphics.draw(image, math.floor(box.x + (box.width - image:getWidth() * scale) / 2),
    math.floor(box.y + (box.height - image:getHeight() * scale) / 2), 0, scale, scale)
end

function Attract:draw()
  love.graphics.clear(0.05, 0.05, 0.06)
  -- The cabinet: its sides, the marquee's lightbox, the bezel and the control panel.
  love.graphics.setColor(self.side)
  love.graphics.rectangle("fill", 0, 0, 56, ui.HEIGHT)
  love.graphics.rectangle("fill", ui.WIDTH - 56, 0, 56, ui.HEIGHT)
  love.graphics.setColor(0.98, 0.91, 0.74)
  love.graphics.rectangle("fill", MARQUEE.x - 4, MARQUEE.y - 4, MARQUEE.width + 8, MARQUEE.height + 8, 4)
  love.graphics.setColor(0.13, 0.10, 0.08)
  love.graphics.rectangle("fill", MARQUEE.x, MARQUEE.y, MARQUEE.width, MARQUEE.height)
  love.graphics.setColor(0.18, 0.17, 0.19)
  love.graphics.rectangle("fill", SCREEN.x - 16, SCREEN.y - 8, SCREEN.width + 32, SCREEN.height + 16, 10)
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("fill", SCREEN.x, SCREEN.y, SCREEN.width, SCREEN.height)
  love.graphics.setColor(0.22, 0.20, 0.24)
  love.graphics.rectangle("fill", 56, SCREEN.y + SCREEN.height + 12, ui.WIDTH - 112, ui.HEIGHT)
  love.graphics.setColor(0.88, 0.22, 0.30)
  love.graphics.circle("fill", 120, 456, 9)
  love.graphics.setColor(1, 0.88, 0.55)
  love.graphics.circle("fill", 520, 450, 7)
  love.graphics.setColor(0.47, 0.72, 0.81)
  love.graphics.circle("fill", 548, 458, 7)

  -- The marquee: its art, or the game's name.
  love.graphics.setColor(1, 1, 1)
  local marquee = self.game.marquee and covers.get(self.game.marquee)
  if marquee then
    fit(marquee, MARQUEE)
  else
    love.graphics.setFont(ui.fonts.title)
    ui.setColor("highlight")
    love.graphics.printf(ui.truncate(ui.fonts.title, self.game.name, MARQUEE.width - 16), MARQUEE.x,
      MARQUEE.y + MARQUEE.height / 2 - 12, MARQUEE.width, "center")
  end

  -- The screen: the video once it plays, the screenshot until then, or the name.
  love.graphics.setColor(1, 1, 1)
  local frame = not self.noVideo and video.frame()
  local path = screenshot(self.game)
  local image = frame or path and covers.get(path)
  if image then
    fit(image, SCREEN)
  else
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("text")
    love.graphics.printf(self.game.name, SCREEN.x + 16, SCREEN.y + SCREEN.height / 2 - 12, SCREEN.width - 32, "center")
  end
  ui.hintPanel(("A: play (%d coin)   B: back"):format(self.price), ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Attract

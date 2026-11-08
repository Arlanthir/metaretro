-- A new game's intro: Professor Cork welcomes the player, who picks how they look, then he sends
-- them off. It sits over Home, where the player wakes up once it's done.
local scenes = require("core.scenes")
local townsfolk = require("core.townsfolk")
local ui = require("ui")
local art = require("world.art")
local Dialog = require("scenes.dialog")
local Museum = require("scenes.museum")

local Intro = {}
Intro.__index = Intro

local WELCOME = {
  "Hello there! Welcome to the world of games!",
  "My name is Cork. Folks around here call me the Professor, and I look after the town's game museum.",
  "Games are everywhere in this world. Some people collect them, others just love to play them. Me? "
    .. "I've spent my whole life studying them.",
  "But that's enough about me. Tell me a little about yourself!",
}
local SEND_OFF = "Wonderful! Your own story with games starts today. A whole town of games is waiting for you. "
  .. "Off you go!"
local LOOKS = townsfolk.PLAYER_LOOKS
local PORTRAIT_SCALE = 4
local CHARACTER_SCALE = 2 -- on top of the sprite's own 2x
local WALK_FRAMES_PER_SECOND = 4

function Intro.new(app)
  return setmetatable({ app = app, look = 1, time = 0 }, Intro)
end

-- Shows `pages` one after another as the professor, then runs `after`.
function Intro:say(pages, after, index)
  index = index or 1
  local professor = Museum.PROFESSOR
  scenes.push(Dialog.new(professor.name, art.portrait(professor), pages[index], nil, function()
    if index < #pages then self:say(pages, after, index + 1) else after() end
  end))
end

function Intro:enter()
  self:say(WELCOME, function() self.choosing = true end)
end

function Intro:update(dt)
  self.time = self.time + dt
end

function Intro:action(name)
  if not self.choosing then return end
  if name == "left" or name == "right" then
    self.look = (self.look - 1 + (name == "right" and 1 or -1)) % #LOOKS + 1
  elseif name == "a" then
    self.choosing = false
    local state = self.app.state
    state.player = LOOKS[self.look]
    self:say({ SEND_OFF }, function()
      state.introDone = true
      self.app:persist()
      scenes.pop()
    end)
  end
end

function Intro:draw()
  ui.backdrop()
  love.graphics.setColor(1, 1, 1)
  local portrait = art.portrait(Museum.PROFESSOR)
  local size = portrait:getWidth() * PORTRAIT_SCALE
  ui.panel(math.floor((ui.WIDTH - size) / 2) - 12, 36, size + 24, size + 24)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(portrait, math.floor((ui.WIDTH - size) / 2), 48, 0, PORTRAIT_SCALE, PORTRAIT_SCALE)
  if not self.choosing then return end

  ui.messagePanel("Which one is you?", ui.WIDTH / 2, 236)
  local frame = math.floor(self.time * WALK_FRAMES_PER_SECOND)
  for i, look in ipairs(LOOKS) do
    local centerX = ui.WIDTH / 2 + (i - (#LOOKS + 1) / 2) * 130
    local boxSize = art.TILE * CHARACTER_SCALE + 24
    local x, y = math.floor(centerX - boxSize / 2), 296
    if i == self.look then
      ui.setColor("selection", 0.45)
      love.graphics.rectangle("fill", x, y, boxSize, boxSize, 6)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.push()
    love.graphics.translate(x + 12, y + 12)
    love.graphics.scale(CHARACTER_SCALE)
    art.player(0, 0, "down", i == self.look and frame or 0, look)
    love.graphics.pop()
  end
  ui.hintPanel("Left/Right: choose   A: that's me", ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Intro

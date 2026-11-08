-- The title screen: Continue (when there's a save), New Game or Quit, over the town panning slowly
-- by, with townsfolk strolling along its main street. The library is read in the background
-- meanwhile, so choosing usually goes straight to town (see `start` in main.lua).
local log = require("core.log")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local town = require("world.town")
local Confirm = require("scenes.confirm")
local Town = require("scenes.town")

local Title = {}
Title.__index = Title

local MENU_WIDTH = 220
local PAN_SECONDS = 60 -- one sweep across the town and back
local VIEW_TOP = art.TILE -- the town's rows from the north buildings to the plaza are in view
local STREET_Y = 192 -- where the main street is on screen, for the strollers
local STROLL_SPEED = 36 -- pixels per second
-- Who strolls by: the player, then some of the townsfolk, a little apart.
local STROLLERS = { "Villager4", "OldWoman", "Child", "Noble", "Cavegirl" }
local GAP = 150

-- `start(newGame)` begins the chosen game; `map` is the town (world/town.lua's parse).
function Title.new(hasSave, start, map)
  local options = {}
  if hasSave then table.insert(options, { label = "Continue", newGame = false }) end
  table.insert(options, { label = "New Game", newGame = true })
  table.insert(options, { label = "Quit", quit = true })
  return setmetatable({ options = options, cursor = 1, hasSave = hasSave, start = start, map = map, time = 0 }, Title)
end

function Title:enter()
  self.canvas = self.canvas or Town.paint(self.map, town.layout(self.map))
end

function Title:update(dt)
  self.time = self.time + dt
end

function Title:action(name)
  if name == "up" then
    self.cursor = (self.cursor - 2) % #self.options + 1
  elseif name == "down" then
    self.cursor = self.cursor % #self.options + 1
  elseif name == "a" then
    local option = self.options[self.cursor]
    if option.quit then
      log("quit from the title screen")
      love.event.quit()
    elseif option.newGame and self.hasSave then
      scenes.push(Confirm.new("Start a new game? Your coins, games and town will start over.",
        function() self.start(true) end))
    else
      self.start(option.newGame)
    end
  end
end

-- `text` at `scale` with a dark outline, centered across `width` on `y`'s line.
local function outlined(text, y, scale, color, width)
  local f = ui.fonts.title
  love.graphics.setFont(f)
  local x = math.floor(((width or ui.WIDTH) - f:getWidth(text) * scale) / 2)
  love.graphics.setColor(0.13, 0.09, 0.07)
  for dx = -1, 1 do
    for dy = -1, 2 do
      if dx ~= 0 or dy ~= 0 then love.graphics.print(text, x + dx * scale, y + dy * scale, 0, scale, scale) end
    end
  end
  love.graphics.setColor(color)
  love.graphics.print(text, x, y, 0, scale, scale)
end

-- The town sliding by: across and back, easing at each end.
function Title:drawTown()
  local width = self.canvas:getWidth() - ui.WIDTH
  local x = math.floor(width * (1 - math.cos(self.time / PAN_SECONDS * 2 * math.pi)) / 2)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.canvas, -x, -VIEW_TOP)
  -- Darker behind the logo and the menu, so they read clearly.
  love.graphics.setColor(0.05, 0.04, 0.03, 0.35)
  love.graphics.rectangle("fill", 0, 0, ui.WIDTH, ui.HEIGHT)
  for i = 0, 7 do
    love.graphics.setColor(0.05, 0.04, 0.03, 0.4 * (1 - i / 8))
    love.graphics.rectangle("fill", 0, i * 20, ui.WIDTH, 20)
  end
end

-- The player and a few townsfolk walking along the street, coming round again.
function Title:drawStrollers()
  local loop = ui.WIDTH + GAP * #STROLLERS
  local frame = math.floor(self.time * 6)
  for i = 0, #STROLLERS do
    local x = (self.time * STROLL_SPEED - i * GAP) % loop - art.TILE
    if i == 0 then
      art.player(math.floor(x), STREET_Y, "right", frame)
    else
      art.villager({ sprite = STROLLERS[i] }, math.floor(x), STREET_Y, "right", frame + i)
    end
  end
end

-- The font's letters start this far below where a line is printed, and capitals end this far down
-- (at 1x; "y" hangs a little lower).
local LETTERS_TOP, CAPITALS_BOTTOM = 8, 21

-- The game's name, "Retro Town" over a ribbon saying "Story", centered across `width`, its letters
-- from `top`; LOGO_HEIGHT tall. Also drawn for the port's art (scripts/port-art).
Title.LOGO_HEIGHT = 100
function Title.drawLogo(width, top)
  outlined("Retro Town", top - LETTERS_TOP * 3, 3, ui.colors.highlight, width)
  local storyWidth = ui.fonts.title:getWidth("Story") * 2 + 48
  local ribbonHeight = 44
  local ribbonX, ribbonY = math.floor((width - storyWidth) / 2), top + (CAPITALS_BOTTOM - LETTERS_TOP) * 3 + 14
  love.graphics.setColor(0.13, 0.09, 0.07)
  love.graphics.rectangle("fill", ribbonX - 3, ribbonY - 3, storyWidth + 6, ribbonHeight + 6, 4)
  love.graphics.setColor(0.55, 0.27, 0.16)
  love.graphics.rectangle("fill", ribbonX, ribbonY, storyWidth, ribbonHeight, 3)
  -- "Story"'s capitals centered on the ribbon.
  local letters = (CAPITALS_BOTTOM - LETTERS_TOP) * 2
  outlined("Story", ribbonY + math.floor((ribbonHeight - letters) / 2) - LETTERS_TOP * 2, 2, ui.colors.text, width)
end

function Title:draw()
  love.graphics.clear(ui.colors.background)
  self:drawTown()
  self:drawStrollers()
  Title.drawLogo(ui.WIDTH, 48)
  outlined("Play your games, grow your collection", 48 + Title.LOGO_HEIGHT + 4, 1, ui.colors.text)

  local rows = #self.options
  local height = rows * ui.LIST_ROW + 32
  local x, y = math.floor((ui.WIDTH - MENU_WIDTH) / 2), 268
  ui.panel(x, y, MENU_WIDTH, height)
  ui.list(self.options, self.cursor, 0, x + 16, y + 16, MENU_WIDTH - 32, height - 32,
    function(option) return option.label end)
end

return Title

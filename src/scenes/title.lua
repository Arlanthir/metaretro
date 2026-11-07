-- The title screen: Continue (when there's a save), New Game or Quit. The library is read in the
-- background meanwhile, so choosing usually goes straight to town (see `start` in main.lua).
local log = require("core.log")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local Confirm = require("scenes.confirm")

local Title = {}
Title.__index = Title

local LOGO_SCALE = 2 -- the pixel font stays crisp at whole multiples
local MENU_WIDTH = 220

-- `start(newGame)` begins the chosen game.
function Title.new(hasSave, start)
  local options = {}
  if hasSave then table.insert(options, { label = "Continue", newGame = false }) end
  table.insert(options, { label = "New Game", newGame = true })
  table.insert(options, { label = "Quit", quit = true })
  return setmetatable({ options = options, cursor = 1, hasSave = hasSave, start = start }, Title)
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

function Title:draw()
  ui.backdrop()
  local f = ui.fonts.title
  love.graphics.setFont(f)
  local logo = "Metaretro"
  local logoX = math.floor((ui.WIDTH - f:getWidth(logo) * LOGO_SCALE) / 2)
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.print(logo, logoX + LOGO_SCALE * 2, 92 + LOGO_SCALE * 2, 0, LOGO_SCALE, LOGO_SCALE)
  ui.setColor("highlight")
  love.graphics.print(logo, logoX, 92, 0, LOGO_SCALE, LOGO_SCALE)
  ui.setColor("text")
  love.graphics.printf("Play your games, grow your town", 0, 152, ui.WIDTH, "center")

  love.graphics.setColor(1, 1, 1)
  art.player(ui.WIDTH / 2 - art.TILE / 2, 196, "down", 0)

  local rows = #self.options
  local height = rows * (ui.LINE + 2) + 32
  local x, y = math.floor((ui.WIDTH - MENU_WIDTH) / 2), 260
  ui.panel(x, y, MENU_WIDTH, height)
  ui.list(self.options, self.cursor, 0, x + 16, y + 16, MENU_WIDTH - 32, height - 32,
    function(option) return option.label end)
end

return Title

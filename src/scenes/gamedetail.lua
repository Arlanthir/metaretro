local scenes = require("core.scenes")
local launcher = require("services.launcher")
local ui = require("ui")

local GameDetail = {}
GameDetail.__index = GameDetail

function GameDetail.new(app, game)
  return setmetatable({ app = app, game = game }, GameDetail)
end

function GameDetail:action(name)
  if name == "a" then
    launcher.launch(self.app.backend, self.game)
  elseif name == "b" then
    scenes.pop()
  end
end

local function formatPlaytime(seconds)
  seconds = tonumber(seconds) or 0
  return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

function GameDetail:draw()
  local game = self.game
  local stats = self.app.backend.playStats(game)
  ui.header(game.name, self.app.state.wallet)

  local top = ui.HEADER_HEIGHT + ui.MARGIN
  ui.drawCover(game.image or game.thumbnail, ui.MARGIN, top, 220, 300)

  local textX = ui.MARGIN * 2 + 220
  local textWidth = ui.WIDTH - textX - ui.MARGIN
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("muted")
  love.graphics.printf(table.concat({
    ("Year: %s"):format(ui.year(game)),
    ("Genre: %s"):format(game.genre or "?"),
    ("Developer: %s"):format(game.developer or "?"),
    ("Played: %d times, %s"):format(tonumber(stats.playcount) or 0, formatPlaytime(stats.gametime)),
  }, "\n"), textX, top, textWidth, "left")

  ui.setColor("text")
  love.graphics.setFont(ui.fonts.small)
  love.graphics.printf(game.desc or "", textX, top + 100, textWidth, "left")

  ui.footer("A: play   B: back")
end

return GameDetail

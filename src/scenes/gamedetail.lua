local consoles = require("core.consoles")
local scenes = require("core.scenes")
local launcher = require("services.launcher")
local ui = require("ui")

local GameDetail = {}
GameDetail.__index = GameDetail

-- `primary` is what A does: { hint, run(detail) }; owned games default to playing.
function GameDetail.new(app, game, primary)
  primary = primary or {
    hint = "play",
    run = function() launcher.launch(app.backend, game) end,
  }
  return setmetatable({ app = app, game = game, primary = primary }, GameDetail)
end

function GameDetail:action(name)
  if name == "a" then
    self.notice = self.primary.run(self)
  elseif name == "b" then
    scenes.pop()
  end
end

local function formatPlaytime(seconds)
  seconds = tonumber(seconds) or 0
  return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

function GameDetail:achievementsLine()
  local game = self.game
  if not game.cheevosId then
    return "Achievements: none known"
  elseif not self.app.state.owned[game.id] then
    return "Achievements: yes"
  end
  local coins = self.app.state.achievementCoins[tostring(game.cheevosId)]
  return coins and ("Achievements: %d coins earned"):format(coins) or "Achievements: none paid yet"
end

function GameDetail:draw()
  local game = self.game
  local stats = self.app.backend.playStats(game)
  local console = consoles.get(game.system)
  ui.header(game.name, self.app.state.wallet)

  local top = ui.HEADER_HEIGHT + 14
  ui.drawCover(game.image or game.thumbnail, ui.MARGIN, top, 220, 300)

  local textX = ui.MARGIN * 2 + 220
  local textWidth = ui.WIDTH - textX - ui.MARGIN
  local rating = tonumber(game.rating)
  -- One line each; `icon(x, y)` draws right after the line's text.
  local rows = {
    { ("Console: %s"):format(console and console.name or game.system) },
    { ("Year: %s"):format(ui.year(game)) },
    { ("Genre: %s"):format(game.genre or "?") },
    { ("Developer: %s"):format(game.developer or "?") },
    { rating and "Rating:" or "Rating: none", icon = rating and function(x, y) ui.stars(x, y, rating) end },
    { ("Played: %d times, %s"):format(tonumber(stats.playcount) or 0, formatPlaytime(stats.gametime)) },
    { self:achievementsLine(), icon = game.cheevosId and ui.trophy },
  }
  local lineHeight = ui.LINE
  love.graphics.setFont(ui.fonts.body)
  for i, row in ipairs(rows) do
    local y = top + (i - 1) * lineHeight
    local text = ui.truncate(ui.fonts.body, row[1], textWidth - (row.icon and 80 or 0))
    ui.setColor("muted")
    love.graphics.print(text, textX, y)
    if row.icon then
      row.icon(textX + ui.fonts.body:getWidth(text) + 8, y + ui.iconOffset(12))
    end
  end

  ui.setColor("text")
  love.graphics.setFont(ui.fonts.small)
  love.graphics.printf(game.desc or "", textX, top + #rows * lineHeight + 16, textWidth, "left")

  if self.notice then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("coin")
    love.graphics.printf(self.notice, ui.MARGIN, ui.HEIGHT - ui.FOOTER_HEIGHT - 32, ui.WIDTH - ui.MARGIN * 2, "center")
  end
  ui.footer(("A: %s   B: back"):format(self.primary.hint))
end

return GameDetail

local achievements = require("core.achievements")
local consoles = require("core.consoles")
local scenes = require("core.scenes")
local ui = require("ui")
local Achievements = require("scenes.achievements")

local GameDetail = {}
GameDetail.__index = GameDetail

-- `primary` is what A does: { hint, run(detail) }; owned games default to playing.
function GameDetail.new(app, game, primary)
  primary = primary or {
    hint = "play",
    run = function() return app:launch(game) end,
  }
  return setmetatable({ app = app, game = game, primary = primary, descScroll = 0, descMaxScroll = 0 }, GameDetail)
end

function GameDetail:action(name)
  if name == "a" then
    self.notice = self.primary.run(self)
  elseif name == "b" then
    scenes.pop()
  elseif name == "x" and self.game.cheevosId then
    scenes.push(Achievements.new(self.app, self.game))
  elseif name == "up" or name == "down" then
    local step = name == "up" and -1 or 1
    self.descScroll = math.max(0, math.min(self.descMaxScroll, self.descScroll + step))
  end
end

local function formatPlaytime(seconds)
  seconds = tonumber(seconds) or 0
  return ("%dh %02dm"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
end

local TROPHY_HEIGHT = 11
local BEFORE_WIDTH = 18 -- a leading icon (12px) and the gap after it

-- A pixel lower than centred on the capitals (it can't be exact at 11px): it reads better there.
local function drawTrophy(x, y, gold)
  ui.trophy(x, y + ui.iconOffset(TROPHY_HEIGHT) + 1, gold)
end

-- The achievements row: whether the game has any (with the trophy before it), and once it's owned,
-- the coins they've paid, as a coin icon and the amount.
function GameDetail:achievementsRow()
  local game = self.game
  local kind = achievements.trophy(self.app.state, game)
  local function trophy(x, y) drawTrophy(x, y, kind == "gold") end
  if not kind then
    return { "Achievements: none known" }
  elseif not self.app.state.owned[game.id] then
    return { "Achievements: yes", before = trophy }
  end
  -- A game RetroAchievements hasn't been asked about yet has no entry: it's earned nothing either.
  local coins = self.app.state.achievementCoins[tostring(game.cheevosId)] or 0
  return { "Achievements:", before = trophy, icon = function(x, y)
    ui.coin(x, y)
    ui.setColor("muted")
    love.graphics.print(("%d earned"):format(coins), x + 24, y)
  end }
end

function GameDetail:draw()
  local game = self.game
  local stats = self.app.backend.playStats(game)
  local console = consoles.get(game.system)
  ui.header(game.name, self.app.state.wallet)

  local top = ui.HEADER_HEIGHT + 14
  ui.drawCover(ui.fullImage(game), ui.MARGIN, top, 220, 300)

  local textX = ui.MARGIN * 2 + 220
  local textWidth = ui.WIDTH - textX - ui.MARGIN
  local rating = tonumber(game.rating)
  -- One line each; `before(x, y)` draws where the line starts, with its text after it, and `icon(x, y)`
  -- right after the text
  -- (`y` is the line's; icons centre themselves on it with ui.iconOffset).
  local rows = {
    { ("Console: %s"):format(console and console.name or game.system) },
    { ("Year: %s"):format(ui.year(game)) },
    { ("Genre: %s"):format(game.genre or "?") },
    { ("Developer: %s"):format(game.developer or "?") },
    { rating and "Rating:" or "Rating: none", icon = rating and function(x, y) ui.stars(x, y + ui.iconOffset(12), rating) end },
    { ("Played: %d times, %s"):format(tonumber(stats.playcount) or 0, formatPlaytime(stats.gametime)) },
    self:achievementsRow(),
  }
  local lineHeight = ui.LINE
  love.graphics.setFont(ui.fonts.body)
  for i, row in ipairs(rows) do
    local y = top + (i - 1) * lineHeight
    local x = textX
    if row.before then
      row.before(x, y)
      x = x + BEFORE_WIDTH
    end
    local text = ui.truncate(ui.fonts.body, row[1], textX + textWidth - x - (row.icon and 80 or 0))
    ui.setColor("muted")
    love.graphics.print(text, x, y)
    if row.icon then row.icon(x + ui.fonts.body:getWidth(text) + 8, y) end
  end

  local descTop = top + #rows * lineHeight + 16
  local descBottom = ui.HEIGHT - ui.FOOTER_HEIGHT - 12 - (self.notice and 32 or 0)
  self:drawDescription(textX, descTop, textWidth, descBottom - descTop)

  if self.notice then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("coin")
    love.graphics.printf(self.notice, ui.MARGIN, ui.HEIGHT - ui.FOOTER_HEIGHT - 32, ui.WIDTH - ui.MARGIN * 2, "center")
  end
  ui.footer(("A: %s   %s%sB: back"):format(self.primary.hint, self.descMaxScroll > 0 and "Up/Down: scroll   " or "",
    self.game.cheevosId and "X: achievements   " or ""))
end

-- The description, wrapped to `width` and scrolled with up/down when it's taller than `height`.
function GameDetail:drawDescription(x, y, width, height)
  local f = ui.fonts.small
  if not self.descLines then
    local _, lines = f:getWrap(self.game.desc or "", width - 14)
    self.descLines = lines
  end
  local visible = math.max(1, math.floor(height / ui.LINE))
  self.descMaxScroll = math.max(0, #self.descLines - visible)
  self.descScroll = math.min(self.descScroll, self.descMaxScroll)
  love.graphics.setFont(f)
  ui.setColor("text")
  for i = 1, math.min(visible, #self.descLines - self.descScroll) do
    love.graphics.print(self.descLines[self.descScroll + i], x, y + (i - 1) * ui.LINE)
  end
  -- Small arrows at the right edge show there's more text above or below.
  ui.setColor("highlight")
  local arrowX = x + width - 4
  if self.descScroll > 0 then
    love.graphics.polygon("fill", arrowX - 5, y + 8, arrowX + 5, y + 8, arrowX, y + 2)
  end
  if self.descScroll < self.descMaxScroll then
    local bottom = y + visible * ui.LINE
    love.graphics.polygon("fill", arrowX - 5, bottom - 8, arrowX + 5, bottom - 8, arrowX, bottom - 2)
  end
end

return GameDetail

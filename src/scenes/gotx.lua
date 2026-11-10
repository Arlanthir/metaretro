local arcade = require("core.arcade")
local gotx = require("core.gotx")
local roms = require("core.roms")
local scenes = require("core.scenes")
local ui = require("ui")
local Achievements = require("scenes.achievements")
local GameDetail = require("scenes.gamedetail")

-- The GotX board up close (A on it in town): the current picks of the retrohandhelds.gg community's
-- game club, each with whether the player owns it, has it on loan, or doesn't have it, and the
-- selected one's box art, when it was picked and on which systems.
local Gotx = {}
Gotx.__index = Gotx

function Gotx.new(app)
  return setmetatable({ app = app, cursor = 1, scroll = 0 }, Gotx)
end

function Gotx:picks()
  local info = self.app.catalog.gotx
  local picks = {}
  for i, winner in ipairs(info.current) do
    picks[i] = { winner = winner, game = info.gameOf[winner] }
  end
  return picks
end

function Gotx:status(pick)
  local game = pick.game
  if not game then return "not in library" end
  if self.app.state.owned[game.id] then return "owned" end
  if self.app.catalog.gotx.loans[game.id] then return "on loan" end
  if arcade.isArcade(game) and roms.present(game) then return "Arcade Club" end
  return roms.present(game) and "in library" or "ROM missing"
end

function Gotx:action(name)
  local picks = self:picks()
  local pick = picks[self.cursor]
  if name == "up" and #picks > 0 then
    self.cursor = (self.cursor - 2) % #picks + 1
  elseif name == "down" and #picks > 0 then
    self.cursor = self.cursor % #picks + 1
  elseif name == "a" and pick and pick.game then
    -- Owned and loaned picks can be played from here; the rest are only shown.
    local primary
    if not self.app:canPlay(pick.game) then primary = false end
    scenes.push(GameDetail.new(self.app, pick.game, primary))
  elseif name == "x" and pick and pick.game and pick.game.cheevosId then
    scenes.push(Achievements.new(self.app, pick.game))
  elseif name == "b" then
    scenes.pop()
  end
end

function Gotx:draw()
  ui.header("Games of the X", self.app.state.wallet)
  local picks = self:picks()
  love.graphics.setFont(ui.fonts.body)
  if #picks == 0 then
    ui.setColor("muted")
    love.graphics.printf("No GotX picks yet.", 0, 220, ui.WIDTH, "center")
    ui.footer("B: back")
    return
  end
  local theme = picks[1].winner.kind == "gotm" and picks[1].winner.theme
  ui.setColor("highlight")
  love.graphics.printf(theme and ("This month: %s"):format(theme) or "The picks of the moment", 0,
    ui.HEADER_HEIGHT + 6, ui.WIDTH, "center")
  ui.setColor("muted")
  love.graphics.setFont(ui.fonts.small)
  love.graphics.printf("retrohandhelds.gg's game club", 0, ui.HEADER_HEIGHT + 32, ui.WIDTH, "center")

  local listTop = ui.HEADER_HEIGHT + 68
  local listWidth = 360
  self.scroll = ui.list(picks, self.cursor, self.scroll, ui.MARGIN, listTop, listWidth, ui.HEIGHT - listTop - 60,
    function(pick) return pick.game and pick.game.name or pick.winner.title, self:status(pick) end)

  local pick = picks[self.cursor]
  local x = ui.MARGIN * 2 + listWidth
  local width = ui.WIDTH - x - ui.MARGIN
  ui.drawCover(pick.game and ui.boxArt(pick.game), x, listTop, width, 180)
  local winner = pick.winner
  local lines = { gotx.when(winner) }
  if winner.kind == "gotm" then table.insert(lines, ("Era: %s"):format(gotx.era(winner))) end
  if #winner.systems > 0 then table.insert(lines, table.concat(winner.systems, ", ")) end
  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  love.graphics.printf(table.concat(lines, "\n"), x, listTop + 188, width, "center")

  ui.footer(("%s%sB: back"):format(pick.game and "A: details   " or "",
    pick.game and pick.game.cheevosId and "X: achievements   " or ""))
end

return Gotx

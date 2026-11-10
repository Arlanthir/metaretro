local achievements = require("core.achievements")
local scenes = require("core.scenes")
local badges = require("services.badges")
local retroachievements = require("services.retroachievements")
local ui = require("ui")

-- A game's RetroAchievements set (X from game details): each achievement's badge, title, points,
-- description and whether it's unlocked (and in hardcore), scrolling a row at a time.
-- Opening an owned game's list also pays any of its unlocks not paid yet.
local Achievements = {}
Achievements.__index = Achievements

local ROW_HEIGHT = 80
local BADGE_SIZE = 64
local RIGHT_COLUMN = 100 -- points and status
local DESCRIPTION_LINES = 2

function Achievements.new(app, game)
  return setmetatable({ app = app, game = game, scroll = 0 }, Achievements)
end

function Achievements:enter()
  local app, game = self.app, self.game
  if not retroachievements.isSetUp(app) then
    self.message = "Set up RetroAchievements to see achievements (see the README)."
    return
  end
  self.message = "Loading achievements..."
  retroachievements.progress(app, game.cheevosId, function(progress)
    if not progress then
      self.message = "Couldn't reach RetroAchievements. Try again later."
      return
    end
    self.totals = achievements.list(progress)
    self.message = #self.totals.list == 0 and "This game has no achievements yet." or nil
    if app:canPlay(game) then
      local coins = retroachievements.credit(app, game.cheevosId, progress)
      if coins > 0 then app:announce(("+%d coins from achievements"):format(coins)) end
    end
  end)
end

function Achievements:leave()
  badges.release()
end

local function listTop() return ui.HEADER_HEIGHT + 40 end
local function visibleRows()
  return math.floor((ui.HEIGHT - ui.FOOTER_HEIGHT - 8 - listTop()) / ROW_HEIGHT)
end

function Achievements:maxScroll()
  return self.totals and math.max(0, #self.totals.list - visibleRows()) or 0
end

function Achievements:action(name)
  if name == "b" then
    scenes.pop()
  elseif name == "up" or name == "down" then
    self.scroll = math.max(0, math.min(self:maxScroll(), self.scroll + (name == "up" and -1 or 1)))
  end
end

-- The description wrapped to DESCRIPTION_LINES, the last one cut short when it runs on.
local function descriptionLines(achievement, width)
  if not achievement.lines then
    local f = ui.fonts.small
    local _, lines = f:getWrap(achievement.description, width)
    if #lines > DESCRIPTION_LINES then
      local rest = table.concat(lines, " ", DESCRIPTION_LINES)
      lines = { unpack(lines, 1, DESCRIPTION_LINES - 1) }
      table.insert(lines, ui.truncate(f, rest, width))
    end
    achievement.lines = lines
  end
  return achievement.lines
end

function Achievements:drawRow(achievement, y)
  local x = ui.MARGIN
  local image = badges.get(achievement.badge, not achievement.unlocked)
  if image then
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, x, y + 6, 0, BADGE_SIZE / image:getWidth(), BADGE_SIZE / image:getHeight())
  else
    ui.setColor("panel")
    love.graphics.rectangle("fill", x, y + 6, BADGE_SIZE, BADGE_SIZE, 4)
  end

  local textX = x + BADGE_SIZE + 14
  local right = ui.WIDTH - ui.MARGIN - 12
  local textWidth = right - RIGHT_COLUMN - textX
  love.graphics.setFont(ui.fonts.body)
  ui.setColor(achievement.unlocked and "text" or "muted")
  love.graphics.print(ui.truncate(ui.fonts.body, achievement.title, textWidth), textX, y + 2)
  ui.setColor("coin")
  love.graphics.printf(("%d pts"):format(achievement.points), right - RIGHT_COLUMN, y + 2, RIGHT_COLUMN, "right")
  if achievement.unlocked then
    ui.setColor("highlight")
    love.graphics.printf(achievement.hardcore and "Hardcore" or "Unlocked", right - RIGHT_COLUMN, y + 2 + ui.LINE,
      RIGHT_COLUMN, "right")
  end

  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  for i, line in ipairs(descriptionLines(achievement, textWidth)) do
    love.graphics.print(line, textX, y + 2 + i * ui.LINE)
  end
end

function Achievements:draw()
  local game = self.game
  ui.header(game.name, self.app.state.wallet)
  local totals = self.totals

  love.graphics.setFont(ui.fonts.body)
  if self.message then
    ui.setColor("muted")
    love.graphics.printf(self.message, ui.MARGIN, 220, ui.WIDTH - ui.MARGIN * 2, "center")
    ui.footer("B: back")
    return
  end

  ui.setColor("highlight")
  love.graphics.printf(("%d of %d unlocked  ·  %d of %d points"):format(totals.unlocked, #totals.list,
    totals.pointsEarned, totals.points), 0, ui.HEADER_HEIGHT + 6, ui.WIDTH, "center")

  local top, rows = listTop(), visibleRows()
  -- One row past the bottom too, so its badge is there when it scrolls in.
  for i = 1, rows + 1 do
    local achievement = totals.list[self.scroll + i]
    if not achievement then break end
    if i <= rows then
      self:drawRow(achievement, top + (i - 1) * ROW_HEIGHT)
    else
      badges.get(achievement.badge, not achievement.unlocked)
    end
  end

  -- Arrows at the right edge show there are more achievements above or below.
  ui.setColor("highlight")
  local arrowX = ui.WIDTH - ui.MARGIN - 2
  if self.scroll > 0 then
    love.graphics.polygon("fill", arrowX - 5, top + 8, arrowX + 5, top + 8, arrowX, top + 2)
  end
  if self.scroll < self:maxScroll() then
    local bottom = top + rows * ROW_HEIGHT
    love.graphics.polygon("fill", arrowX - 5, bottom - 8, arrowX + 5, bottom - 8, arrowX, bottom - 2)
  end
  ui.footer(self:maxScroll() > 0 and "Up/Down: scroll   B: back" or "B: back")
end

return Achievements

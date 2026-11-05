local catalog = require("core.catalog")
local scenes = require("core.scenes")
local ui = require("ui")
local GameDetail = require("scenes.gamedetail")

local Collection = {}
Collection.__index = Collection

function Collection.new(app)
  return setmetatable({ app = app, tab = 1, cursor = 1, scroll = 0 }, Collection)
end

function Collection:enter()
  self.systems = catalog.ownedSystems(self.app.catalog)
  self.tab = math.max(1, math.min(self.tab, #self.systems))
end

Collection.resume = Collection.enter

function Collection:games()
  local system = self.systems[self.tab]
  return system and self.app.catalog.bySystem[system.id].owned or {}
end

function Collection:changeTab(delta)
  if #self.systems == 0 then return end
  self.tab = (self.tab - 1 + delta) % #self.systems + 1
  self.cursor, self.scroll = 1, 0
end

function Collection:action(name)
  local games = self:games()
  if name == "left" or name == "l" then
    self:changeTab(-1)
  elseif name == "right" or name == "r" then
    self:changeTab(1)
  elseif name == "up" and #games > 0 then
    self.cursor = (self.cursor - 2) % #games + 1
  elseif name == "down" and #games > 0 then
    self.cursor = self.cursor % #games + 1
  elseif name == "a" and games[self.cursor] then
    scenes.push(GameDetail.new(self.app, games[self.cursor]))
  elseif name == "b" then
    scenes.pop()
  end
end

function Collection:draw()
  ui.header("Home", self.app.state.wallet)
  local system = self.systems[self.tab]
  if not system then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("muted")
    love.graphics.printf("Your collection is empty. Visit a store in town!", 0, 220, ui.WIDTH, "center")
    ui.footer("B: leave")
    return
  end

  love.graphics.setFont(ui.fonts.body)
  ui.setColor("highlight")
  love.graphics.printf(("<  %s  >"):format(system.name), 0, ui.HEADER_HEIGHT + 10, ui.WIDTH, "center")
  ui.setColor("muted")
  love.graphics.setFont(ui.fonts.small)
  love.graphics.printf(("%d / %d"):format(self.tab, #self.systems), 0, ui.HEADER_HEIGHT + 30, ui.WIDTH, "center")

  local games = self:games()
  local listTop = ui.HEADER_HEIGHT + 56
  local listWidth = 360
  self.scroll = ui.list(games, self.cursor, self.scroll, ui.MARGIN, listTop, listWidth, ui.HEIGHT - listTop - 32,
    function(game) return game.name end)

  local selected = games[self.cursor]
  if selected then
    local coverX = ui.MARGIN * 2 + listWidth
    ui.drawCover(selected.image or selected.thumbnail, coverX, listTop, ui.WIDTH - coverX - ui.MARGIN, 220)
    love.graphics.setFont(ui.fonts.small)
    ui.setColor("muted")
    love.graphics.printf(("%s  ·  %s"):format(ui.year(selected), selected.genre or "?"),
      coverX, listTop + 230, ui.WIDTH - coverX - ui.MARGIN, "center")
  end

  ui.footer("L/R: console   A: details   B: leave")
end

return Collection

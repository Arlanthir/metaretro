-- The player's games, a tab per system: the consoles' games (from the console at home), or the
-- arcade games (from the cabinet at home, see Collection.arcade). A opens a game's details, where it
-- can be played.
local achievements = require("core.achievements")
local arcade = require("core.arcade")
local catalog = require("core.catalog")
local scenes = require("core.scenes")
local ui = require("ui")
local Achievements = require("scenes.achievements")
local GameDetail = require("scenes.gamedetail")

local Collection = {}
Collection.__index = Collection

-- `shelf(app)` returns { title, tabWord, tabs = { { name, games, total } }, owned, total } (see the
-- two below); tabs only list systems with owned games.
function Collection.new(app, shelf)
  return setmetatable({ app = app, shelf = shelf or Collection.consoles, tab = 1, cursor = 1, scroll = 0 }, Collection)
end

function Collection.consoles(app)
  local built = app.catalog
  local tabs = {}
  -- The GotX picks on loan come first, on any console.
  local loans, seen = {}, {}
  for _, pick in ipairs(built.gotx.current) do
    local game = built.gotx.gameOf[pick]
    if game and built.gotx.loans[game.id] and not seen[game.id] then
      seen[game.id] = true
      table.insert(loans, game)
    end
  end
  if #loans > 0 then
    table.sort(loans, catalog.byName)
    table.insert(tabs, { name = "GotX loans", games = loans, total = #loans,
      note = "This month's GotX picks, yours to play for now" })
  end
  for _, system in ipairs(catalog.ownedSystems(built)) do
    local games = built.bySystem[system.id]
    table.insert(tabs, { name = system.name, games = games.owned, total = #games.owned + #games.locked })
  end
  local owned, total = catalog.progress(built)
  return { title = "Home", tabWord = "Console", tabs = tabs, owned = owned, total = total }
end

-- The arcade games the player bought at the Arcade Club, by system.
function Collection.arcade(app)
  local tabs, owned, total = {}, 0, 0
  for _, system in ipairs(app.backend.listSystems()) do
    if arcade.SYSTEMS[system.id] then
      local games = {}
      for _, game in ipairs(app.backend.listGames(system.id)) do
        if catalog.isShown(game, app.settings) then table.insert(games, game) end
      end
      local mine = arcade.owned(games, app.state.owned)
      if #mine > 0 then table.insert(tabs, { name = system.name, games = mine, total = #games }) end
      owned, total = owned + #mine, total + #games
    end
  end
  return { title = "Arcade cabinet", tabWord = "System", tabs = tabs, owned = owned, total = total }
end

function Collection:enter()
  self.shelved = self.shelf(self.app)
  self.tab = math.max(1, math.min(self.tab, #self.shelved.tabs))
end

Collection.resume = Collection.enter

function Collection:games()
  local tab = self.shelved.tabs[self.tab]
  return tab and tab.games or {}
end

function Collection:changeTab(delta)
  local count = #self.shelved.tabs
  if count == 0 then return end
  self.tab = (self.tab - 1 + delta) % count + 1
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
  elseif name == "x" and games[self.cursor] and games[self.cursor].cheevosId then
    scenes.push(Achievements.new(self.app, games[self.cursor]))
  elseif name == "b" then
    scenes.pop()
  end
end

function Collection:draw()
  local shelved = self.shelved
  local tabs = shelved.tabs
  ui.header(shelved.title, self.app.state.wallet)
  local tab = tabs[self.tab]
  if not tab then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("muted")
    love.graphics.printf("Your collection is empty. Visit a store in town!", 0, 220, ui.WIDTH, "center")
    ui.footer("B: leave")
    return
  end

  love.graphics.setFont(ui.fonts.body)
  ui.setColor("highlight")
  love.graphics.printf(("<  %s  >"):format(tab.name), 0, ui.HEADER_HEIGHT + 6, ui.WIDTH, "center")
  ui.setColor("muted")
  love.graphics.setFont(ui.fonts.small)
  local games = tab.games
  love.graphics.printf(tab.note or ("%s %d/%d  ·  %d/%d owned  ·  %d/%d in all"):format(shelved.tabWord,
    self.tab, #tabs, #games, tab.total, shelved.owned, shelved.total), 0, ui.HEADER_HEIGHT + 32, ui.WIDTH, "center")

  local listTop = ui.HEADER_HEIGHT + 68
  local listWidth = 360
  self.scroll = ui.list(games, self.cursor, self.scroll, ui.MARGIN, listTop, listWidth, ui.HEIGHT - listTop - 60,
    function(game) return game.name, nil, achievements.trophy(self.app.state, game) end)

  -- The first games of the neighbouring tabs are what L/R shows next.
  local neighbours = {}
  for _, delta in ipairs({ -1, 1 }) do
    local other = tabs[(self.tab - 1 + delta) % #tabs + 1]
    if other ~= tab then
      for i = 1, 3 do table.insert(neighbours, other.games[i]) end
    end
  end
  ui.prefetchAround(games, self.cursor, neighbours)

  local selected = games[self.cursor]
  if selected then
    local coverX = ui.MARGIN * 2 + listWidth
    ui.coverWithCaption(selected, coverX, listTop, ui.WIDTH - coverX - ui.MARGIN, 220)
  end

  ui.footer(("L/R: %s   A: details   %sB: leave"):format(shelved.tabWord:lower(),
    selected and selected.cheevosId and "X: achievements   " or ""))
end

return Collection

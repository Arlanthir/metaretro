local consoles = require("core.consoles")
local economy = require("core.economy")
local progression = require("core.progression")
local scenes = require("core.scenes")
local stores = require("core.stores")
local ui = require("ui")
local Confirm = require("scenes.confirm")
local GameDetail = require("scenes.gamedetail")

-- A shop sells one list of items; `stock(app)` returns { title, subtitle, items, consoles? }.
local Shop = {}
Shop.__index = Shop

function Shop.new(app, stock)
  return setmetatable({ app = app, stock = stock, cursor = 1, scroll = 0 }, Shop)
end

function Shop.dealer(app)
  return Shop.new(app, function()
    local timeline = progression.timeline(app.catalog.systems)
    return {
      title = "Console Dealer",
      subtitle = ("Your generation: %d"):format(progression.currentGeneration(app.state, timeline)),
      items = progression.purchasable(app.state, timeline),
      consoles = true,
    }
  end)
end

function Shop.store(app, store)
  return Shop.new(app, function()
    local items, rerolled, inStock = stores.offer(store, app.state, app.catalog,
      progression.timeline(app.catalog.systems), os.date("%Y-%m-%d"), love.math.random)
    if rerolled then
      app:persist()
    end
    return {
      title = store.title,
      subtitle = ("Today's picks from %d games in stock. New picks tomorrow!"):format(inStock),
      items = items,
      showConsole = store.kind == "genre",
    }
  end)
end

function Shop:enter()
  self:refresh()
end

function Shop:refresh()
  self.section = self.stock()
  self.cursor = math.max(1, math.min(self.cursor, #self.section.items))
end

function Shop:price(item)
  return self.section.consoles and economy.consolePrice(item) or economy.price(item)
end

-- Genre stores mix consoles, so their rows say which console each game is for.
function Shop:itemLabel(item)
  local console = self.section.showConsole and consoles.get(item.system)
  return console and ("[%s] %s"):format(console.short, item.name) or item.name
end

-- Returns a message when the purchase can't start; `onBought` runs after a confirmed purchase.
function Shop:buy(item, onBought)
  local price = self:price(item)
  if self.app.state.wallet < price then
    return ("You need %d more coins for %s."):format(price - self.app.state.wallet, item.name)
  end
  scenes.push(Confirm.new(("Buy %s for %d coins?"):format(item.name, price), function()
    local ok, result
    if self.section.consoles then
      ok, result = economy.buyConsole(self.app.state, item, self.app.catalog.bySystem[item.id].locked, love.math.random)
    else
      ok, result = economy.buy(self.app.state, item)
    end
    if not ok then
      self.notice = ("Can't buy %s: %s."):format(item.name, result)
      return
    end
    self.app:refresh()
    self:refresh()
    if self.section.consoles then
      self.notice = ("Bought %s! Its store opens in town."):format(item.name)
      scenes.push(Confirm.notice(self:starterPackMessage(item, result)))
    else
      self.notice = ("Bought %s!"):format(item.name)
    end
    if onBought then onBought() end
  end))
end

function Shop:starterPackMessage(console, games)
  if #games == 0 then
    return ("%s is yours!"):format(console.name)
  end
  local lines = { ("%s comes with:"):format(console.name), "" }
  for _, game in ipairs(games) do
    table.insert(lines, ui.truncate(ui.fonts.body, game.name, 320))
  end
  return table.concat(lines, "\n")
end

function Shop:showDetails(item)
  scenes.push(GameDetail.new(self.app, item, {
    hint = ("buy for %d coins"):format(self:price(item)),
    run = function() return self:buy(item, scenes.pop) end,
  }))
end

function Shop:action(name)
  local items = self.section.items
  local selected = items[self.cursor]
  if name == "up" and #items > 0 then
    self.cursor = (self.cursor - 2) % #items + 1
  elseif name == "down" and #items > 0 then
    self.cursor = self.cursor % #items + 1
  elseif name == "a" and selected and not self.section.consoles then
    self:showDetails(selected)
  elseif (name == "a" or name == "y") and selected then
    self.notice = self:buy(selected)
  elseif name == "b" then
    scenes.pop()
  end
end

function Shop:drawConsoleInfo(console, x, y, width)
  love.graphics.setFont(ui.fonts.title)
  ui.setColor("text")
  love.graphics.printf(console.name, x, y, width, "center")
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("muted")
  local games = self.app.catalog.bySystem[console.id]
  love.graphics.printf(("Released %d\nGeneration %d\n\n%d games in your library"):format(
    console.year, console.generation, #games.owned + #games.locked), x, y + 60, width, "center")
end

function Shop:draw()
  local section = self.section
  ui.header(section.title, self.app.state.wallet)
  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  love.graphics.printf(section.subtitle, 0, ui.HEADER_HEIGHT + 12, ui.WIDTH, "center")

  local listTop = ui.HEADER_HEIGHT + 40
  local listWidth = 360
  local listHeight = ui.HEIGHT - listTop - 56
  if #section.items == 0 then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("muted")
    love.graphics.printf(section.consoles and "No consoles for sale right now." or "Sold out for today!",
      ui.MARGIN, listTop + 20, listWidth, "center")
  else
    self.scroll = ui.list(section.items, self.cursor, self.scroll, ui.MARGIN, listTop, listWidth, listHeight,
      function(item) return self:itemLabel(item), ("%d c"):format(self:price(item)) end)
  end

  local selected = section.items[self.cursor]
  local panelX = ui.MARGIN * 2 + listWidth
  local panelWidth = ui.WIDTH - panelX - ui.MARGIN
  if selected and section.consoles then
    self:drawConsoleInfo(selected, panelX, listTop + 20, panelWidth)
  elseif selected then
    ui.drawCover(selected.image or selected.thumbnail, panelX, listTop, panelWidth, 220)
    love.graphics.setFont(ui.fonts.small)
    ui.setColor("muted")
    love.graphics.printf(("%s  ·  %s"):format(ui.year(selected), selected.genre or "Unknown genre"),
      panelX, listTop + 230, panelWidth, "center")
  end

  if self.notice then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("coin")
    love.graphics.printf(self.notice, ui.MARGIN, ui.HEIGHT - 48, ui.WIDTH - ui.MARGIN * 2, "center")
  end
  ui.footer(self.section.consoles and "A: buy   B: leave" or "A: details   Y: buy   B: leave")
end

return Shop

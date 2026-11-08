local arcade = require("core.arcade")
local catalog = require("core.catalog")
local consoles = require("core.consoles")
local economy = require("core.economy")
local progression = require("core.progression")
local scenes = require("core.scenes")
local stores = require("core.stores")
local townsfolk = require("core.townsfolk")
local ui = require("ui")
local Confirm = require("scenes.confirm")
local GameDetail = require("scenes.gamedetail")

-- A shop sells one list of items; `stock(app)` returns { title, subtitle?, items, footnote?,
-- consoles?, selling?, arcade? }; the footnote goes under the list. A `selling` shop is the other way round: it buys the player's games (Granny Rose). The
-- `arcade` one sells the Arcade Club's games, for the player's own cabinet.
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
      items = progression.purchasable(app.state, timeline),
      footnote = progression.moreToCome(app.state, timeline) and "Even more consoles yet to come!" or nil,
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
      subtitle = ("Today's picks of %d in stock · new ones tomorrow"):format(inStock),
      items = items,
      showConsole = store.kind == "genre",
    }
  end)
end

-- The Arcade Club's clerk sells this week's cabinet games; `games()` lists them by cabinet.
function Shop.arcade(app, games)
  return Shop.new(app, function()
    local items, cabinets = {}, games()
    for i = 1, arcade.CABINETS do
      if cabinets[i] then table.insert(items, cabinets[i]) end
    end
    return {
      title = "Arcade Club",
      subtitle = "This week's games, to play for free on your own cabinet",
      items = items,
      arcade = true,
    }
  end)
end

-- Granny Rose buys any owned game for half its price.
function Shop.grandma(app)
  return Shop.new(app, function()
    local games = townsfolk.ownedGames(app.catalog)
    table.sort(games, catalog.byName)
    return {
      title = "Granny Rose",
      subtitle = "Games for her grandchildren, at half price",
      items = games,
      showConsole = true,
      selling = true,
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
  if self.section.consoles then return economy.consolePrice(item) end
  if self.section.arcade then return arcade.GAME_PRICE end
  return self.section.selling and economy.sellPrice(item) or economy.price(item)
end

-- Genre stores mix consoles, so their rows say which console each game is for.
function Shop:itemLabel(item)
  local console = self.section.showConsole and consoles.get(item.system)
  return console and ("[%s] %s"):format(console.short, item.name) or item.name
end

-- Returns a message when the purchase can't start; `onBought` runs after a confirmed purchase.
function Shop:buy(item, onBought)
  local price = self:price(item)
  if self.section.selling then return self:sell(item, price, onBought) end
  if self.app.state.wallet < price then
    return ("You need %d more coins for %s."):format(price - self.app.state.wallet, item.name)
  end
  scenes.push(Confirm.new(("Buy %s for %d coins?"):format(item.name, price), function()
    local ok, result
    local firstCabinet = self.section.arcade and not arcade.ownsAny(self.app.state.owned)
    if self.section.consoles then
      ok, result = economy.buyConsole(self.app.state, item, self.app.catalog.bySystem[item.id].locked, love.math.random)
    elseif self.section.arcade then
      ok, result = arcade.buy(self.app.state, item)
    else
      ok, result = economy.buy(self.app.state, item)
    end
    if not ok then
      self.notice = ("Can't buy %s: %s."):format(item.name, result)
      return
    end
    self.app:refresh()
    self:refresh()
    if onBought then onBought() end -- before any notice, which then shows over the shop
    if self.section.consoles then
      self.notice = ("Bought %s! Its store opens in town."):format(item.name)
      scenes.push(Confirm.notice(ui.starterPackMessage(item, result)))
    elseif firstCabinet then
      self.notice = ("Bought %s!"):format(item.name)
      scenes.push(Confirm.notice(("%s is yours! Your very own arcade cabinet is waiting in your office at home.")
        :format(item.name)))
    elseif self.section.arcade then
      self.notice = ("Bought %s! Play it on your cabinet at home."):format(item.name)
    else
      self.notice = ("Bought %s!"):format(item.name)
    end
  end))
end

function Shop:sell(item, price, onSold)
  scenes.push(Confirm.new(("Sell %s for %d coins?"):format(item.name, price), function()
    if not economy.sell(self.app.state, item) then return end
    self.app:refresh()
    self:refresh()
    self.notice = ("Sold %s for %d coins!"):format(item.name, price)
    if onSold then onSold() end
  end))
end

function Shop:showDetails(item)
  scenes.push(GameDetail.new(self.app, item, {
    hint = ("%s for %d coins"):format(self.section.selling and "sell" or "buy", self:price(item)),
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
  love.graphics.printf(("Released %d\n\n%d titles"):format(console.year, #games.owned + #games.locked),
    x, y + 60, width, "center")
end

function Shop:draw()
  local section = self.section
  ui.header(section.title, self.app.state.wallet)
  love.graphics.setFont(ui.fonts.small)
  ui.setColor("muted")
  if section.subtitle then love.graphics.printf(section.subtitle, 0, ui.HEADER_HEIGHT + 8, ui.WIDTH, "center") end

  local listTop = ui.HEADER_HEIGHT + 44
  local listWidth = 360
  local listHeight = ui.HEIGHT - listTop - 84
  if #section.items == 0 then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("muted")
    local empty = section.consoles and "No consoles for sale right now."
      or section.selling and "You have no games to sell." or "Sold out for today!"
    love.graphics.printf(empty,
      ui.MARGIN, listTop + 20, listWidth, "center")
  else
    self.scroll = ui.list(section.items, self.cursor, self.scroll, ui.MARGIN, listTop, listWidth, listHeight,
      function(item) return self:itemLabel(item), ("%d c"):format(self:price(item)), item.cheevosId ~= nil end)
  end
  if section.footnote then
    local rowHeight = ui.LIST_ROW
    local rows = math.min(#section.items, math.floor(listHeight / rowHeight))
    love.graphics.setFont(ui.fonts.small)
    ui.setColor("highlight")
    love.graphics.printf(section.footnote, ui.MARGIN, listTop + math.max(rows, 2) * rowHeight + 10, listWidth, "center")
  end

  local selected = section.items[self.cursor]
  if not section.consoles then
    ui.prefetchAround(section.items, self.cursor)
  end
  local panelX = ui.MARGIN * 2 + listWidth
  local panelWidth = ui.WIDTH - panelX - ui.MARGIN
  if selected and section.consoles then
    self:drawConsoleInfo(selected, panelX, listTop + 20, panelWidth)
  elseif selected then
    ui.coverWithCaption(selected, panelX, listTop, panelWidth, 220)
  end

  if self.notice then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("coin")
    love.graphics.printf(self.notice, ui.MARGIN, ui.HEIGHT - ui.FOOTER_HEIGHT - 32, ui.WIDTH - ui.MARGIN * 2, "center")
  end
  ui.footer(self.section.consoles and "A: buy   B: leave"
    or ("A: details   Y: %s   B: leave"):format(self.section.selling and "sell" or "buy"))
end

return Shop

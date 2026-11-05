local economy = require("core.economy")
local progression = require("core.progression")
local scenes = require("core.scenes")
local ui = require("ui")
local Confirm = require("scenes.confirm")

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

function Shop.store(app, console)
  return Shop.new(app, function()
    local locked = app.catalog.bySystem[console.id].locked
    return {
      title = console.short .. " Store",
      subtitle = ("%d games for sale"):format(#locked),
      items = locked,
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

function Shop:buy(item)
  local price = self:price(item)
  if self.app.state.wallet < price then
    self.notice = ("You need %d more coins for %s."):format(price - self.app.state.wallet, item.name)
    return
  end
  scenes.push(Confirm.new(("Buy %s for %d coins?"):format(item.name, price), function()
    local buy = self.section.consoles and economy.buyConsole or economy.buy
    local ok, reason = buy(self.app.state, item)
    if ok then
      self.app:refresh()
      self:refresh()
      self.notice = self.section.consoles and ("Bought %s! Its store opens in town."):format(item.name)
        or ("Bought %s!"):format(item.name)
    else
      self.notice = ("Can't buy %s: %s."):format(item.name, reason)
    end
  end))
end

function Shop:action(name)
  local items = self.section.items
  if name == "up" and #items > 0 then
    self.cursor = (self.cursor - 2) % #items + 1
  elseif name == "down" and #items > 0 then
    self.cursor = self.cursor % #items + 1
  elseif name == "a" and items[self.cursor] then
    self:buy(items[self.cursor])
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
    love.graphics.printf(section.consoles and "No consoles for sale right now." or "Sold out!",
      ui.MARGIN, listTop + 20, listWidth, "center")
  else
    self.scroll = ui.list(section.items, self.cursor, self.scroll, ui.MARGIN, listTop, listWidth, listHeight,
      function(item) return item.name, ("%d c"):format(self:price(item)) end)
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
    love.graphics.printf(("%s  ·  %s"):format(ui.year(selected), selected.genre or "?"),
      panelX, listTop + 230, panelWidth, "center")
  end

  if self.notice then
    love.graphics.setFont(ui.fonts.body)
    ui.setColor("coin")
    love.graphics.printf(self.notice, ui.MARGIN, ui.HEIGHT - 48, ui.WIDTH - ui.MARGIN * 2, "center")
  end
  ui.footer("A: buy   B: leave")
end

return Shop

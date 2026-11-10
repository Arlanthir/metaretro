-- The Arcade Club: four cabinets along the side walls with this week's arcade games
-- (core/arcade.lua), their cover art on their sides. A shows a cabinet up close (scenes/attract.lua),
-- where a coin plays the game, launching it like the collection does. The clerk at the back explains
-- how it works and sells the cabinets' games (scenes/shop.lua).
local arcade = require("core.arcade")
local catalog = require("core.catalog")
local log = require("core.log")
local scenes = require("core.scenes")
local covers = require("services.covers")
local ui = require("ui")
local art = require("world.art")
local interior = require("world.interior")
local Attract = require("scenes.attract")
local Confirm = require("scenes.confirm")
local Dialog = require("scenes.dialog")
local Interior = require("scenes.interior")
local Shop = require("scenes.shop")
local Walker = require("scenes.walker")

local Arcade = Walker.extend({ place = "the Arcade Club" }, Interior)

local map = interior.parse(require("world.arcademap"))
local cabinets = {} -- in reading order: cabinet i runs this week's game i
for _, piece in ipairs(map.furniture) do
  if piece.kind == "cabinet" then table.insert(cabinets, piece) end
end

Arcade.CLERK = { name = "Clerk", sprite = "RobotGreen" }
local WELCOME = ("Welcome to the Arcade Club! Each play is %d coin, and new games come in every Monday. "
  .. "Fancy one of your own? I'll sell you any game here for %d coins, and a new one takes its place.")
  :format(arcade.PRICE, arcade.GAME_PRICE)

-- This week's games, by cabinet (see arcade.cabinets).
function Arcade.games(app)
  return arcade.cabinets(catalog.allGames(app.backend, app.state.settings), arcade.week(os.time()), app.state.owned)
end
local games = Arcade.games

-- Everything the Arcade Club shows of its games (side art, screenshots, marquees), for the town to
-- load ahead so it's ready when the player walks in.
function Arcade.artPaths(app)
  local paths = {}
  for _, game in pairs(games(app)) do
    table.insert(paths, ui.boxArt(game))
    table.insert(paths, ui.fullImage(game))
    table.insert(paths, game.marquee)
  end
  return paths
end

function Arcade.new(app)
  local self = Interior.new(Arcade, app, map)
  self.games = games(app)
  covers.prefetch(Arcade.artPaths(app))
  local spot, facing = map.spots.clerk
  self.counter, facing = interior.counter(map)
  self.people = { { x = spot.x, y = spot.y, facing = facing, look = Arcade.CLERK } }
  return self
end

-- Back from the clerk's shop, a bought game's cabinet has a new one.
function Arcade:resume()
  for _, game in pairs(self.games) do
    if self.app.state.owned[game.id] then
      self.games = games(self.app)
      covers.prefetch(Arcade.artPaths(self.app))
      return
    end
  end
end

function Arcade:facingCounter()
  local x, y = self:facingTile()
  return x == self.counter.x and y == self.counter.y
end

local function cabinetIndex(piece)
  for i, cabinet in ipairs(cabinets) do
    if cabinet == piece then return i end
  end
end

function Arcade:live(piece)
  return piece.kind == "cabinet"
end

-- Cabinets on the right wall face left, into the room.
function Arcade:drawLive(piece, px, py)
  local index = cabinetIndex(piece)
  local game = self.games[index]
  local path = game and ui.boxArt(game)
  art.cabinet(index, px, py, piece.x > map.width / 2, path and covers.get(path) or nil)
end

function Arcade:play(game)
  local app = self.app
  if app.state.wallet < arcade.PRICE then
    scenes.push(Confirm.notice("You need a coin to play."))
    return
  end
  app.state.wallet = app.state.wallet - arcade.PRICE
  app:persist()
  log("arcade: playing %s (%s)", game.name, game.system)
  app:launch(game)
end

function Arcade:interact(piece, person)
  if person or self:facingCounter() then
    scenes.push(Dialog.new(Arcade.CLERK.name, art.portrait(Arcade.CLERK), WELCOME, {
      hint = "buy a game",
      run = function() scenes.push(Shop.arcade(self.app, function() return games(self.app) end)) end,
    }))
    return
  end
  if not piece or piece.kind ~= "cabinet" then return end
  local game = self.games[cabinetIndex(piece)]
  if not game then
    scenes.push(Dialog.new("", nil, "This cabinet is out of order."))
    return
  end
  scenes.push(Attract.new(game, arcade.PRICE, function() self:play(game) end, cabinetIndex(piece)))
end

function Arcade:hintFor(piece, person)
  if person or self:facingCounter() then return "A: talk to the clerk" end
  if not piece or piece.kind ~= "cabinet" then return nil end
  local game = self.games[cabinetIndex(piece)]
  if not game then return "Out of order" end
  return ("A: %s"):format(ui.truncate(ui.fonts.body, game.name, 360))
end

return Arcade

-- The Arcade Club: four cabinets with this week's arcade games (core/arcade.lua). A coin plays one,
-- launching it like the collection does.
local arcade = require("core.arcade")
local catalog = require("core.catalog")
local log = require("core.log")
local scenes = require("core.scenes")
local launcher = require("services.launcher")
local ui = require("ui")
local art = require("world.art")
local interior = require("world.interior")
local Confirm = require("scenes.confirm")
local Dialog = require("scenes.dialog")
local Interior = require("scenes.interior")
local Walker = require("scenes.walker")

local Arcade = Walker.extend({ place = "the Arcade Club" }, Interior)

local map = interior.parse(require("world.arcademap"))
local cabinets = {} -- in reading order: cabinet i runs this week's game i
for _, piece in ipairs(map.furniture) do
  if piece.kind == "cabinet" then table.insert(cabinets, piece) end
end

function Arcade.new(app)
  local self = Interior.new(Arcade, app, map)
  self.games = arcade.cabinets(catalog.allGames(app.backend), arcade.week(os.time()))
  return self
end

local function cabinetIndex(piece)
  for i, cabinet in ipairs(cabinets) do
    if cabinet == piece then return i end
  end
end

function Arcade:live(piece)
  return piece.kind == "cabinet"
end

function Arcade:drawLive(piece, px, py)
  art.cabinet(cabinetIndex(piece), px, py)
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
  launcher.launch(app.backend, game)
end

function Arcade:interact(piece)
  if not piece or piece.kind ~= "cabinet" then return end
  local game = self.games[cabinetIndex(piece)]
  if not game then
    scenes.push(Dialog.new("", nil, "This cabinet is out of order."))
    return
  end
  scenes.push(Confirm.new(("Play %s for %d coin?"):format(game.name, arcade.PRICE), function() self:play(game) end))
end

function Arcade:hintFor(piece)
  if not piece or piece.kind ~= "cabinet" then return nil end
  local game = self.games[cabinetIndex(piece)]
  if not game then return "Out of order" end
  return ("A: play %s (%d coin)"):format(ui.truncate(ui.fonts.body, game.name, 320), arcade.PRICE)
end

return Arcade

-- Inside Home: the console in the living room opens the collection, and the TV shows videos of the
-- games on sale in town. The console only shows up once the player has one (Professor Cork's gift).
-- The arcade cabinet by the right wall shows up with the first game bought at the Arcade Club; it
-- plays the player's arcade games for free, and wears the art of the last one played or bought.
local arcade = require("core.arcade")
local catalog = require("core.catalog")
local covers = require("services.covers")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local progression = require("core.progression")
local townsfolk = require("core.townsfolk")
local interior = require("world.interior")
local Collection = require("scenes.collection")
local Interior = require("scenes.interior")
local Tv = require("scenes.tv")
local Walker = require("scenes.walker")

local Home = Walker.extend({ place = "Home" }, Interior)

local map = interior.parse(require("world.homemap"))

function Home.new(app)
  return Interior.new(Home, app, map)
end

-- Where the player starts at home (a new game, or Continue): in the middle of the living room.
function Home.wakeUpSpot()
  local spot = map.spots.wakeUp
  return { x = spot.x, y = spot.y, facing = "down" }
end

function Home:live(piece)
  return piece.kind == "console" or piece.kind == "cabinet"
end

function Home:absent(piece)
  local state = self.app.state
  if piece.kind == "console" then return next(state.ownedConsoles) == nil end
  return piece.kind == "cabinet" and not arcade.ownsAny(state.owned)
end

-- The art on the cabinet: the box art of the arcade game last played or bought, or of the first
-- one owned. Nil without a cabinet.
function Home.cabinetArt(app)
  local state = app.state
  if not arcade.ownsAny(state.owned) then return nil end
  local games = catalog.allGames(app.backend)
  for _, game in ipairs(games) do
    if game.id == state.cabinetGame then return ui.boxArt(game) end
  end
  local first = arcade.owned(games, state.owned)[1]
  return first and ui.boxArt(first)
end

-- The console under the TV: the one the player last played an owned game on; before any play,
-- the professor's gift, or for older saves the oldest console owned.
function Home:pickConsole()
  local state, catalog = self.app.state, self.app.catalog
  local game = townsfolk.lastPlayedGame(state, townsfolk.ownedGames(catalog))
  if game and state.ownedConsoles[game.system] then return game.system end
  if state.giftConsole ~= "" then return state.giftConsole end
  for _, console in ipairs(progression.timeline(catalog.systems)) do
    if state.ownedConsoles[console.id] then return console.id end
  end
end

-- Picked on the way in: playing a game restarts Metaretro, so it can't change while inside.
function Home:enter()
  Interior.enter(self)
  self.console = self:pickConsole()
  self.cabinetCover = Home.cabinetArt(self.app)
  if self.cabinetCover then covers.prefetch({ self.cabinetCover }) end
end

function Home:drawLive(piece, px, py)
  if piece.kind == "cabinet" then
    art.cabinet(1, px, py, true, self.cabinetCover and covers.get(self.cabinetCover) or nil)
  else
    art.console(self.console, px, py)
  end
end

function Home:interact(piece)
  if piece and piece.kind == "console" then
    scenes.push(Collection.new(self.app))
  elseif piece and piece.kind == "cabinet" then
    scenes.push(Collection.new(self.app, Collection.arcade))
  elseif piece and piece.kind == "tv" then
    scenes.push(Tv.new(self.app))
  end
end

function Home:hintFor(piece)
  if piece and piece.kind == "console" then return "A: play games" end
  if piece and piece.kind == "cabinet" then return "A: play arcade games" end
  if piece and piece.kind == "tv" then return "A: watch TV" end
end

return Home

-- Inside Home: the console in the living room opens the collection, and the TV shows videos of the
-- games on sale in town. The console only shows up once the player has one (Professor Cork's gift).
local scenes = require("core.scenes")
local interior = require("world.interior")
local Collection = require("scenes.collection")
local Interior = require("scenes.interior")
local Tv = require("scenes.tv")
local Walker = require("scenes.walker")

local Home = Walker.extend({ place = "Home" }, Interior)

local map = interior.parse(require("world.homemap"))

-- In through the front door, or (`wakeUp`, a new game) next to the bed.
function Home.new(app, wakeUp)
  return Interior.new(Home, app, map, wakeUp and map.spots.wakeUp, wakeUp and "down" or "up")
end

function Home:live(piece)
  return piece.kind == "console"
end

function Home:absent(piece)
  return piece.kind == "console" and next(self.app.state.ownedConsoles) == nil
end

function Home:interact(piece)
  if piece and piece.kind == "console" then
    scenes.push(Collection.new(self.app))
  elseif piece and piece.kind == "tv" then
    scenes.push(Tv.new(self.app))
  end
end

function Home:hintFor(piece)
  if piece and piece.kind == "console" then return "A: play games" end
  if piece and piece.kind == "tv" then return "A: watch TV" end
end

return Home

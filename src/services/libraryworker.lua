-- Runs in a love.thread: reads every system's games through the backend, and the save, the slow
-- parts of starting up. Sends one message per system so the main thread can take them a frame at
-- a time, then a last one with the systems, the save and how long it all took.
require("love.filesystem") -- lets require() find the game's modules, and reads the save
require("love.timer")
local achievements = require("core.achievements")
local save = require("core.save")

local backend = require("backends." .. ...)
local channel = love.thread.getChannel("library")
local started = love.timer.getTime()
local systems = backend.listSystems()
for _, system in ipairs(systems) do
  channel:push({ system = system.id, games = backend.listGames(system.id) })
end
channel:push({
  done = true, systems = systems, saved = save.load(love.filesystem),
  cheevos = achievements.decodeIdCache(love.filesystem.read(achievements.ID_CACHE)),
  timings = backend.timings, seconds = love.timer.getTime() - started,
})

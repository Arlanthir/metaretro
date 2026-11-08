local json = require("lib.json")
local log = require("core.log")

-- Metaretro.sh reads launch.txt after LÖVE exits: line 1 is the game id, line 2 the shell command.
local launcher = {}

launcher.FILE = "launch.txt"
-- Left for the next start, which then skips the title screen; Metaretro.sh restarts Metaretro after the game.
-- It holds the game's id and where the player was (see Town:location), as JSON.
launcher.RESUME_FILE = "resume.txt"

function launcher.connectedControllers()
  local controllers = {}
  for i, joystick in ipairs(love.joystick.getJoysticks()) do
    controllers[i] = {
      index = i - 1,
      guid = joystick:getGUID(),
      name = joystick:getName(),
      buttons = joystick:getButtonCount(),
      hats = joystick:getHatCount(),
      axes = joystick:getAxisCount(),
    }
  end
  return controllers
end

function launcher.request(backend, game, controllers)
  return game.id .. "\n" .. backend.launchCommand(game, controllers) .. "\n"
end

-- Launches `game` by quitting; `location` is where to put the player back afterwards.
function launcher.launch(backend, game, location)
  local request = launcher.request(backend, game, launcher.connectedControllers())
  log("launching: %s", request:match("\n(.-)\n"))
  love.filesystem.write(launcher.FILE, request)
  love.filesystem.write(launcher.RESUME_FILE, json.encode({ game = game.id, location = location }))
  love.event.quit()
end

-- The resume file's contents, as { game, location? }.
function launcher.parseResume(contents)
  local ok, data = pcall(json.decode, contents or "")
  if ok and type(data) == "table" then
    return { game = data.game, location = type(data.location) == "table" and data.location or nil }
  end
  return { game = contents } -- from before locations were saved: just the game's id
end

-- When Metaretro is starting again after a game it launched, what it left in the resume file (only once).
function launcher.consumeResume()
  if not love.filesystem.getInfo(launcher.RESUME_FILE) then return nil end
  local resume = launcher.parseResume(love.filesystem.read(launcher.RESUME_FILE))
  love.filesystem.remove(launcher.RESUME_FILE)
  return resume
end

return launcher

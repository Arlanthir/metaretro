local log = require("core.log")

-- Metaretro.sh reads launch.txt after LÖVE exits: line 1 is the game id, line 2 the shell command.
local launcher = {}

launcher.FILE = "launch.txt"
-- Left for the next start, which then skips the title screen; Metaretro.sh restarts Metaretro after the game.
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

function launcher.launch(backend, game)
  local request = launcher.request(backend, game, launcher.connectedControllers())
  log("launching: %s", request:match("\n(.-)\n"))
  love.filesystem.write(launcher.FILE, request)
  love.filesystem.write(launcher.RESUME_FILE, game.id)
  love.event.quit()
end

-- Whether Metaretro is starting again after a game it launched (only true once).
function launcher.consumeResume()
  if not love.filesystem.getInfo(launcher.RESUME_FILE) then return false end
  love.filesystem.remove(launcher.RESUME_FILE)
  return true
end

return launcher

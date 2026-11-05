local log = require("core.log")

-- Metaretro.sh reads launch.txt after LÖVE exits: line 1 is the game id, line 2 the shell command.
local launcher = {}

launcher.FILE = "launch.txt"

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
  love.event.quit()
end

return launcher

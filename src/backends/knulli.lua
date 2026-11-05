local consoles = require("core.consoles")
local gamelist = require("backends.gamelist")
local log = require("core.log")

local knulli = {
  name = "knulli",
  tracksGametime = true,
  romsDir = os.getenv("METARETRO_ROMS") or "/userdata/roms",
  confPath = os.getenv("METARETRO_BATOCERA_CONF") or "/userdata/system/batocera.conf",
}

local IGNORED = { ports = true }

local function readFile(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local contents = file:read("*a")
  file:close()
  return contents
end

local function exists(path)
  local file = io.open(path, "rb")
  if file then file:close() end
  return file ~= nil
end

local function shellQuote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local systems
local gamesBySystem = {}

function knulli.detect()
  return exists(knulli.confPath)
end

function knulli.listSystems()
  if systems then return systems end
  systems = {}
  local listing = io.popen("ls -1 " .. shellQuote(knulli.romsDir) .. " 2>/dev/null")
  for id in listing:lines() do
    if not IGNORED[id] and exists(knulli.romsDir .. "/" .. id .. "/gamelist.xml") then
      table.insert(systems, { id = id, name = consoles.get(id) and consoles.get(id).name or id })
    end
  end
  listing:close()
  return systems
end

local MEDIA_DIRS = { "images", "videos", "manuals", "media", "downloaded_images", "downloaded_videos" }
local PRUNE = "\\( -name " .. table.concat(MEDIA_DIRS, " -o -name ") .. " \\) -prune -o -print"

local clock = love and love.timer and love.timer.getTime or os.clock
knulli.timings = { read = 0, find = 0, parse = 0 }

local function timed(phase, fn, ...)
  local started = clock()
  local result = fn(...)
  knulli.timings[phase] = knulli.timings[phase] + clock() - started
  return result
end

-- One find per system is much cheaper on an SD card than opening every ROM; media folders are skipped.
local function filesUnder(dir)
  local paths = {}
  local listing = io.popen("find " .. shellQuote(dir) .. " " .. PRUNE .. " 2>/dev/null")
  for path in listing:lines() do
    paths[path] = true
  end
  listing:close()
  return paths
end

-- Like ES, ignore gamelist entries whose ROM is no longer on disk.
function knulli.listGames(systemId)
  if not gamesBySystem[systemId] then
    local systemDir = knulli.romsDir .. "/" .. systemId
    local xml = timed("read", readFile, systemDir .. "/gamelist.xml")
    local games = {}
    if xml then
      local present = timed("find", filesUnder, systemDir)
      local entries = timed("parse", gamelist.parse, xml, systemId, systemDir)
      for _, game in ipairs(entries) do
        if present[game.rom] then
          table.insert(games, game)
        end
      end
      if #games < #entries then
        log("%s: skipped %d gamelist entries with missing ROMs", systemId, #entries - #games)
      end
    end
    gamesBySystem[systemId] = games
  end
  return gamesBySystem[systemId]
end

knulli.inputDevicesPath = "/proc/bus/input/devices"

-- Maps device names to their /dev/input/eventN node.
function knulli.parseInputDevices(text)
  local devices = {}
  for block in (text .. "\n\n"):gmatch("(.-)\n\n") do
    local name = block:match('N: Name="(.-)"\n')
    local event = block:match("H: Handlers=[^\n]-(event%d+)")
    if name and event and not devices[name] then
      devices[name] = "/dev/input/" .. event
    end
  end
  return devices
end

-- Equivalent of ES's %CONTROLLERSCONFIG%, without which emulators get no input or hotkeys.
function knulli.controllersConfig(controllers, devices)
  local args = {}
  for player, controller in ipairs(controllers) do
    local function arg(name, value)
      table.insert(args, ("-p%d%s %s"):format(player, name, shellQuote(tostring(value))))
    end
    arg("index", controller.index)
    arg("guid", controller.guid)
    arg("name", controller.name)
    arg("nbbuttons", controller.buttons)
    arg("nbhats", controller.hats)
    arg("nbaxes", controller.axes)
    if devices[controller.name] then
      arg("devicepath", devices[controller.name])
    end
  end
  return table.concat(args, " ")
end

function knulli.launchCommand(game, controllers)
  local devices = knulli.parseInputDevices(readFile(knulli.inputDevicesPath) or "")
  return ("emulatorlauncher %s -system %s -rom %s"):format(
    knulli.controllersConfig(controllers or {}, devices), shellQuote(game.system), shellQuote(game.rom))
end

function knulli.playStats(game)
  return { playcount = game.playcount, gametime = game.gametime }
end

function knulli.raCredentials()
  local conf = readFile(knulli.confPath)
  local username = conf and ("\n" .. conf):match("\nglobal%.retroachievements%.username=([^\r\n]+)")
  return username and { username = username } or nil
end

return knulli

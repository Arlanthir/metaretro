local consoles = require("core.consoles")
local gamelist = require("backends.gamelist")
local log = require("core.log")

local knulli = {
  name = "knulli",
  tracksGametime = true,
  romsDir = os.getenv("RETROTOWNSTORY_ROMS") or "/userdata/roms",
  confPath = os.getenv("RETROTOWNSTORY_BATOCERA_CONF") or "/userdata/system/batocera.conf",
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

local clock = love and love.timer and love.timer.getTime or os.clock
knulli.timings = { read = 0, parse = 0, cache = 0, cached = 0, parsed = 0 }
knulli.cache = nil -- see useCache

local function timed(phase, fn, ...)
  local started = clock()
  local result = fn(...)
  knulli.timings[phase] = knulli.timings[phase] + clock() - started
  return result
end

-- Each system's gamelist stamp (modification time and size, with the ROMs folder), from one stat
-- for all of them: busybox's `-c` on the device, BSD's `-f` on a Mac.
local stamps
local function gamelistStamps()
  if stamps then return stamps end
  stamps = {}
  local files = shellQuote(knulli.romsDir) .. "/*/gamelist.xml"
  local listing = io.popen(("stat -c '%%Y %%s %%n' %s 2>/dev/null || stat -f '%%m %%z %%N' %s 2>/dev/null")
    :format(files, files))
  for line in listing:lines() do
    local mtime, size, path = line:match("^(%d+) (%d+) (.+)$")
    local system = path and path:match("([^/]+)/gamelist%.xml$")
    if system then stamps[system] = ("%s %s %s"):format(mtime, size, knulli.romsDir) end
  end
  listing:close()
  return stamps
end

-- A system's gamelist entries: from the cache when its gamelist hasn't changed, otherwise parsed
-- (and cached). Nil without a gamelist.
local function entriesFor(systemId, systemDir)
  local cache = knulli.cache
  local stamp = cache and gamelistStamps()[systemId]
  local entries = stamp and timed("cache", cache.get, cache, systemId, stamp)
  if entries then
    knulli.timings.cached = knulli.timings.cached + 1
    return entries
  end
  local xml = timed("read", readFile, systemDir .. "/gamelist.xml")
  if not xml then return nil end
  entries = timed("parse", gamelist.parse, xml, systemId, systemDir)
  knulli.timings.parsed = knulli.timings.parsed + 1
  if stamp then timed("cache", cache.put, cache, systemId, stamp, entries) end
  return entries
end

-- Every gamelist entry, including ones whose ROM is gone (gamelists keep stale entries): listing
-- every ROM folder took about a second at startup, so games are checked when they're handed out
-- instead (see hasRom and core/roms).
function knulli.listGames(systemId)
  if not gamesBySystem[systemId] then
    gamesBySystem[systemId] = entriesFor(systemId, knulli.romsDir .. "/" .. systemId) or {}
  end
  return gamesBySystem[systemId]
end

-- Whether the game's ROM (a file, or a folder for some systems) is on disk.
function knulli.hasRom(game)
  local file = io.open(game.rom, "rb")
  if file then file:close() return true end
  -- Opening a folder can fail; renaming a path to itself succeeds whenever it exists.
  if os.rename(game.rom, game.rom) then return true end
  log("%s: ROM missing (%s)", game.name, game.rom)
  return false
end

-- Keeps parsed gamelists in `cache` (a services/librarycache), so only changed ones are parsed.
function knulli.useCache(cache)
  knulli.cache = cache
end

-- Takes the systems and games read on the library thread, as { systems, games = { [id] = games } }.
function knulli.useListing(listing)
  systems, gamesBySystem = listing.systems, listing.games
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

-- EmulationStation's id for a game in its web API: the MD5 of the ROM's full path, in hex.
function knulli.esGameId(game)
  return love.data.encode("string", "hex", love.data.hash("md5", game.rom))
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

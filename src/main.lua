local backend = require("backends.backend")
local catalog = require("core.catalog")
local consoles = require("core.consoles")
local covers = require("services.covers")
local economy = require("core.economy")
local input = require("core.input")
local log = require("core.log")
local playtime = require("services.playtime")
local progression = require("core.progression")
local save = require("core.save")
local scenes = require("core.scenes")
local stores = require("core.stores")
local ui = require("ui")
local town = require("world.town")
local Loading = require("scenes.loading")
local Town = require("scenes.town")

local app = { town = town.parse(require("world.townmap")) }
local showFps = false
local screenshotIn -- dev aid: `--screenshot <seconds>` saves screenshot.png to the save dir, then quits

function app:persist()
  save.write(love.filesystem, self.state)
end

local function isConsole(systemId)
  return consoles.get(systemId) ~= nil
end

-- Rebuilds everything derived from the save after it changes, then saves it.
function app:refresh()
  self.catalog = catalog.build(self.backend, self.state, isConsole)
  self.stores = stores.list(self.state, self.catalog, progression.timeline(self.catalog.systems))
  town.assignLots(self.state, self.stores, #self.town.lots)
  self:persist()
end

local function argValue(args, flag)
  for i, value in ipairs(args) do
    if value == flag then
      return args[i + 1]
    end
  end
  return nil
end

local function loadLibrary(args)
  app.backend = backend.select(argValue(args, "--backend"))
  app.state = save.load(love.filesystem)
  local started = love.timer.getTime()
  local games = catalog.allGames(app.backend)
  local timings = app.backend.timings
  log("backend=%s systems=%d games=%d parsed in %.2fs%s",
    app.backend.name, #app.backend.listSystems(), #games, love.timer.getTime() - started,
    timings and (" (read %.2fs, find %.2fs, parse %.2fs)"):format(timings.read, timings.find, timings.parse) or "")
  app:refresh()
  if not app.state.initialized then
    -- New players start with the oldest console in their library and a few of its games.
    local starter = progression.timeline(app.catalog.systems)[1]
    if starter then
      app.state.ownedConsoles[starter.id] = true
      economy.grantStarterPack(app.state, games, love.math.random, { [starter.id] = true })
    end
    app.state.initialized = true
  end
  progression.syncOwnedConsoles(app.state, games)
  local sessions = playtime.parseLog(love.filesystem.read(playtime.LOG))
  app.earned = playtime.credit(app.state, app.backend, games, sessions)
  app:refresh()
  input.ignoreFor(0.5)
  scenes.switch(Town.new(app))
end

function love.quit()
  log("quit")
end

function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  ui.load()

  screenshotIn = tonumber(argValue(args, "--screenshot"))
  input.setNintendoLayout(argValue(args, "--layout") == "nintendo")
  input.setHandler(function(action)
    if action == "select" then
      showFps = not showFps
    else
      scenes.action(action)
    end
  end)
  scenes.switch(Loading.new("Loading your library...", function() loadLibrary(args) end))
end

function love.update(dt)
  covers.update()
  input.update(dt)
  scenes.update(dt)
  if screenshotIn then
    screenshotIn = screenshotIn - dt
    if screenshotIn <= 0 then
      screenshotIn = nil
      love.graphics.captureScreenshot(function(image)
        image:encode("png", "screenshot.png")
        love.event.quit()
      end)
    end
  end
end

function love.draw()
  love.graphics.clear(ui.colors.background)
  scenes.draw()
  if showFps then
    love.graphics.setFont(ui.fonts.small)
    love.graphics.setColor(0, 1, 0)
    love.graphics.print(("%d fps"):format(love.timer.getFPS()), 4, ui.HEIGHT - 16)
  end
end

love.keypressed = input.keypressed
love.keyreleased = input.keyreleased
love.gamepadpressed = input.gamepadpressed
love.gamepadreleased = input.gamepadreleased

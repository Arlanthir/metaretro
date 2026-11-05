local backend = require("backends.backend")
local catalog = require("core.catalog")
local economy = require("core.economy")
local input = require("core.input")
local log = require("core.log")
local playtime = require("services.playtime")
local save = require("core.save")
local scenes = require("core.scenes")
local ui = require("ui")
local Collection = require("scenes.collection")
local Loading = require("scenes.loading")

local app = {}
local showFps = false

function app:persist()
  save.write(love.filesystem, self.state)
end

local function argValue(args, flag)
  for i, value in ipairs(args) do
    if value == flag then
      return args[i + 1]
    end
  end
end

local function setOf(commaSeparated)
  if not commaSeparated then return nil end
  local set = {}
  for value in commaSeparated:gmatch("[^,]+") do
    set[value] = true
  end
  return set
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
  if not app.state.initialized then
    economy.grantStarterPack(app.state, games, nil, setOf(argValue(args, "--starter-systems")))
    app.state.initialized = true
  end
  local sessions = playtime.parseLog(love.filesystem.read(playtime.LOG))
  app.earned = playtime.credit(app.state, app.backend, games, sessions)
  app:persist()
  app.catalog = catalog.build(app.backend, app.state)
  input.ignoreFor(0.5)
  scenes.switch(Collection.new(app))
end

function love.quit()
  log("quit")
end

function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  ui.load()

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
  input.update(dt)
  scenes.update(dt)
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

local backend = require("backends.backend")
local achievements = require("core.achievements")
local arcade = require("core.arcade")
local catalog = require("core.catalog")
local consoles = require("core.consoles")
local covers = require("services.covers")
local daily = require("core.daily")
local http = require("services.http")
local input = require("core.input")
local launcher = require("services.launcher")
local library = require("services.library")
local log = require("core.log")
local playtime = require("services.playtime")
local progression = require("core.progression")
local retroachievements = require("services.retroachievements")
local save = require("core.save")
local scenes = require("core.scenes")
local selectbutton = require("core.selectbutton")
local stores = require("core.stores")
local ui = require("ui")
local version = require("core.version")
local town = require("world.town")
local Loading = require("scenes.loading")
local Intro = require("scenes.intro")
local Title = require("scenes.title")
local Town = require("scenes.town")

local app = { town = town.parse(require("world.townmap")) }
local showFps = false
local selectTracker = selectbutton.new()
local screenshotIn -- dev aid: `--screenshot <seconds>` saves screenshot.png to the save dir, then quits

function app:persist()
  save.write(love.filesystem, self.state)
end

-- Shows a short message where the player walks, in town or at home (now, or when they're back from a menu).
function app:announce(message)
  self.announcement = message
end

local function isConsole(systemId)
  return consoles.get(systemId) ~= nil
end

-- Rebuilds everything derived from the save after it changes.
function app:rebuild()
  self.catalog = catalog.build(self.backend, self.state, isConsole)
  self.stores = stores.list(self.state, self.catalog, progression.timeline(self.catalog.systems))
end

-- Rebuilds after the save changes, then saves it.
function app:refresh()
  self:rebuild()
  self:persist()
end

-- After Settings change which games are shown: the stores, collection and town follow at once.
-- Inside a building, the town catches up when the player walks out.
function app:applySettings()
  local settings = self.state.settings
  log("settings: peripheral games %s, Japanese-only games %s", settings.showPeripheral and "shown" or "hidden",
    settings.showJapanese and "shown" or "hidden")
  self:refresh()
  if self.townScene and not self.townScene.inside then self.townScene:rebuild() end
end

local function argValue(args, flag)
  for i, value in ipairs(args) do
    if value == flag then
      return args[i + 1]
    end
  end
  return nil
end

-- Takes the game list once the background thread has read it (see services/library).
local function adoptLibrary(listing)
  app.backend.useListing(listing)
  local count = 0
  for _, games in pairs(listing.games) do count = count + #games end
  local timings = listing.timings
  log("backend=%s systems=%d games=%d parsed in %.2fs%s", app.backend.name, #listing.systems, count, listing.seconds,
    timings and (" (read %.2fs, find %.2fs, parse %.2fs)"):format(timings.read, timings.find, timings.parse) or "")
end

-- Gives the frame back while setting up runs in the background (see `prepareSoon`).
local function pause()
  if coroutine.running() then coroutine.yield() end
end

-- Sets up the continued (or a new) game from the library and the save, without saving anything,
-- so the title screen can get the likely choice ready while it waits (see `start`).
local function prepare(newGame)
  local sessions = playtime.parseLog(love.filesystem.read(playtime.LOG))
  app.state = newGame and save.defaults() or app.listing.saved
  -- Settings are the player's, not the game's: they outlast a new game.
  if newGame then app.state.settings = app.listing.saved.settings end
  if app.state.seed == "" then app.state.seed = ("%08x"):format(love.math.random(0, 0x7fffffff)) end
  daily.useSeed(app.state.seed)
  app.announcement = nil
  if newGame then
    -- Play logged so far belongs to the previous game, and achievements count from now.
    app.state.consumedSessions = #sessions
  end
  local games = catalog.allGames(app.backend)
  app.cheevos = app.listing.cheevos
  achievements.resolveIds(games, app.cheevos.ids)
  -- New players get their first console from Professor Cork, in the museum.
  app.state.initialized = true
  progression.syncOwnedConsoles(app.state, games)
  local earned, played = playtime.credit(app.state, app.backend, games, sessions)
  if earned > 0 then app:announce(("+%d coins from play"):format(earned)) end
  for _, game in ipairs(played) do
    app.state.lastPlayed[game.id] = os.time()
  end
  retroachievements.queue(app.state, played)
  pause()
  app:rebuild()
  app.prepared = { newGame = newGame, firstSession = not newGame and sessions[1] and sessions[1].start or nil }
end

-- Starts preparing `newGame` a step per frame (see `love.update`), so the title screen keeps responding.
local function prepareSoon(newGame)
  app.preparing = { newGame = newGame, routine = coroutine.create(prepare) }
end

local function prepareStep()
  local routine = app.preparing.routine
  local ok, err = coroutine.resume(routine, app.preparing.newGame)
  if not ok then error(debug.traceback(routine, err), 0) end
  if coroutine.status(routine) == "dead" then app.preparing = nil end
end

local function isPrepared(newGame)
  return app.prepared ~= nil and app.prepared.newGame == newGame
end

-- Finishes setting up `newGame` now, carrying on from where the background left off.
local function prepareNow(newGame)
  if isPrepared(newGame) then return end
  if not (app.preparing and app.preparing.newGame == newGame) then prepareSoon(newGame) end
  while app.preparing do prepareStep() end
end

-- Launches `game`; Retro Town Story starts again where the player is now once it's over. An arcade game
-- puts its art on the player's cabinet at home.
function app:launch(game)
  if arcade.isArcade(game) then
    self.state.cabinetGame = game.id
    self:persist()
  end
  launcher.launch(self.backend, game, self.townScene and self.townScene:location())
end

-- `location` (optional, see Town:location) is where the player was when they launched a game.
local function enterTown(location)
  app:persist()
  retroachievements.sync(app, app.prepared.firstSession)
  input.ignoreFor(0.5)
  local town = Town.new(app)
  app.townScene = town
  scenes.switch(town)
  if not app.state.introDone then
    -- A new game: meet Professor Cork, then wake up at home.
    town:wakeUpAtHome()
    scenes.push(Intro.new(app))
  elseif location then
    town:restore(location)
  else
    town:wakeUpAtHome() -- Continue
  end
end

-- Continues (or starts a new game) right away when it's ready; otherwise shows a loading message
-- until the library is read and the game set up.
local function start(newGame, location)
  app.started = true
  if isPrepared(newGame) then
    enterTown(location)
    return
  end
  scenes.switch(Loading.new("Loading your library...", function()
    prepareNow(newGame)
    enterTown(location)
  end, function() return app.listing ~= nil end))
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
      -- Ten quick presses: a cheat for coins, once the game has started.
      if selectbutton.tap(selectTracker, love.timer.getTime()) and app.townScene then
        app.state.wallet = app.state.wallet + selectbutton.CHEAT_COINS
        app:persist()
        app:announce(("+%d coins"):format(selectbutton.CHEAT_COINS))
        log("cheat: +%d coins", selectbutton.CHEAT_COINS)
      end
    else
      scenes.action(action)
    end
  end)
  -- A direction held while walking through a door shouldn't keep scrolling the screen it opens.
  scenes.onChange = input.stopRepeats

  app.backend = backend.select(argValue(args, "--backend"))
  library.start(app.backend.name)
  log("Retro Town Story %s started with: %s", version, table.concat(args, " "))
  app.hasSave = love.filesystem.getInfo(save.FILE) ~= nil
  -- Back from a game it launched: straight back to where the player was.
  local resume = launcher.consumeResume()
  if resume and app.hasSave then
    log("resuming after %s", tostring(resume.game))
    start(false, resume.location)
  else
    scenes.switch(Title.new(app.hasSave, start, app.town))
  end
end

function love.update(dt)
  if not app.listing then
    app.listing = library.poll()
    if app.listing then
      adoptLibrary(app.listing)
      -- Get the title screen's first option ready: Continue, or New Game without a save.
      if not app.started then prepareSoon(not app.hasSave) end
    end
  elseif app.preparing and not app.started then
    prepareStep()
  end
  covers.update()
  http.update()
  input.update(dt)
  if selectbutton.hold(selectTracker, dt, input.isDown("select")) then showFps = not showFps end
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
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 4, 4, 56, 18, 4)
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print(("%d fps"):format(love.timer.getFPS()), 10, 7)
  end
end

love.keypressed = input.keypressed
love.keyreleased = input.keyreleased
love.gamepadpressed = input.gamepadpressed
love.gamepadreleased = input.gamepadreleased

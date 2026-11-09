
-- scripts/port-art: appended to a copy of src/main.lua by scripts/port-art.sh, which sets PORT_ART_OUT
-- (where the images go). Runs on the mock backend, with its own save so the desktop one is left alone.
-- The billboards show box art drawn here, for the mock games: no real game's art in the port's images.
love.filesystem.setIdentity("retrotownstory-port-art")
local json = require("lib.json")
local scenes = require("core.scenes")
local ui = require("ui")
local art = require("world.art")
local town = require("world.town")
local covers = require("services.covers")
local Title = require("scenes.title")
local Town = require("scenes.town")
local Shop = require("scenes.shop")

local OUT = assert(os.getenv("PORT_ART_OUT"), "PORT_ART_OUT is not set")

-- A player well into their collection, back in town from a game, on the main street: the Console
-- Dealer, the museum and the mall in view, as on the title screen.
local state = require("core.save").defaults()
state.introDone, state.giftOffered, state.giftReceived, state.giftConsole = true, true, true, "nes"
state.initialized, state.wallet = true, 1350
for _, id in ipairs({ "nes", "snes", "gba", "megadrive" }) do state.ownedConsoles[id] = true end
love.filesystem.write("save.json", json.encode(state))
love.filesystem.write("resume.txt", json.encode({ game = "port-art", location = { x = 17, y = 9, facing = "down" } }))

local function write(name, imageData)
  local file = assert(io.open(OUT .. "/" .. name, "wb"))
  file:write(imageData:encode("png"):getString())
  file:close()
  print("wrote " .. OUT .. "/" .. name)
end

-- Made-up box art for a mock game: its title over one of the pack's characters, on a colored box.
local BOX_COLORS = { { 0.18, 0.41, 0.48 }, { 0.55, 0.27, 0.16 }, { 0.34, 0.53, 0.30 }, { 0.65, 0.38, 0.55 } }
local BOX_HEROES = { "Knight", "Samurai", "Princess", "Hunter", "Monk", "Eskimo" }

local function drawBox(game, i)
  local width, height = 120, 168
  local canvas = love.graphics.newCanvas(width, height)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(BOX_COLORS[i % #BOX_COLORS + 1])
  love.graphics.setColor(0.98, 0.91, 0.74)
  love.graphics.rectangle("fill", 0, 0, width, 34)
  love.graphics.setColor(0.13, 0.09, 0.07)
  love.graphics.rectangle("line", 1, 1, width - 2, height - 2)
  love.graphics.setFont(ui.fonts.body)
  love.graphics.printf(game.name:gsub(" %u%a+$", ""), 4, 2, width - 8, "center")
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.translate(width / 2 - art.TILE, 52)
  love.graphics.scale(2)
  art.villager({ sprite = BOX_HEROES[i % #BOX_HEROES + 1] }, 0, 0, "down")
  love.graphics.pop()
  love.graphics.pop()
  local path = love.filesystem.getSaveDirectory() .. ("/box%d.png"):format(i)
  local file = assert(io.open(path, "wb"))
  file:write(canvas:newImageData():encode("png"):getString())
  file:close()
  return path
end

local function boxArt()
  local i = 0
  for _, system in ipairs(app.backend.listSystems()) do
    for _, game in ipairs(app.backend.listGames(system.id)) do
      i = i + 1
      game.thumbnail = drawBox(game, i)
    end
  end
  app.townScene:rebuild()
end

-- Box art for the port: the town behind the logo, and the player with some townsfolk, at twice the size.
local function cover()
  local width, height = 480, 640
  local canvas = love.graphics.newCanvas(width, height)
  local map = app.town
  local view = Town.paint(map, town.layout(map), { signs = false })
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(ui.colors.background)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(view, -17 * art.TILE * 2, -art.TILE * 2, 0, 2, 2)
  for i = 0, 11 do
    love.graphics.setColor(0.05, 0.04, 0.03, 0.7 * (1 - i / 12))
    love.graphics.rectangle("fill", 0, i * 20, width, 20)
  end
  Title.drawLogo(width, 40)
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.translate(width / 2 - 5 * art.TILE, height - 5 * art.TILE)
  love.graphics.scale(2)
  art.player(2 * art.TILE, 0, "down", 0)
  -- Two townsfolk either side, the nearer ones a little lower.
  for i, sprite in ipairs({ "OldWoman", "Child", "Samurai", "Princess" }) do
    local x = (i <= 2 and i - 1 or i) * art.TILE
    art.villager({ sprite = sprite }, x, (i == 2 or i == 3) and 8 or 0, "down")
  end
  love.graphics.pop()
  love.graphics.pop()
  return canvas:newImageData()
end

local function logo()
  local canvas = love.graphics.newCanvas(400, Title.LOGO_HEIGHT + 8)
  love.graphics.push("all")
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  Title.drawLogo(400, 6)
  love.graphics.pop()
  return canvas:newImageData()
end

-- Buying games: a store's menu, with today's picks, their prices and the selected one's box art.
local function shop()
  local store = app.stores[1]
  for _, candidate in ipairs(app.stores) do
    if candidate.id == "snes" then store = candidate end
  end
  local scene = Shop.store(app, store)
  scenes.push(scene)
  scene.cursor = 2
end

local function capture(name)
  return function()
    love.graphics.captureScreenshot(function(image) write(name, image) end)
  end
end

local STEPS = {
  boxArt,
  function() end, function() end, function() end, -- covers load
  capture("screenshot.png"),
  shop,
  function() end, function() end, -- covers load
  capture("screenshot-shop.png"),
  scenes.pop,
  function()
    write("cover.png", cover())
    write("logo.png", logo())
  end,
}
local baseUpdate, frame, step, inTown = love.update, 0, 0, false
function love.update(dt)
  baseUpdate(dt)
  covers.update()
  frame = frame + 1
  inTown = inTown or (app.townScene ~= nil and scenes.stack[#scenes.stack] == app.townScene)
  if inTown and frame % 30 == 0 then
    step = step + 1
    if STEPS[step] then STEPS[step]() else love.event.quit() end
  end
  if frame > 3000 then
    print("port-art: gave up waiting for town")
    love.event.quit()
  end
end

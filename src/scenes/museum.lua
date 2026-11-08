-- The game museum next to Home, where Professor Cork gives new players their first console:
-- once he's offered it, the player picks one of the oldest consoles in the library from his table.
local art = require("world.art")
local economy = require("core.economy")
local interior = require("world.interior")
local progression = require("core.progression")
local scenes = require("core.scenes")
local ui = require("ui")
local Confirm = require("scenes.confirm")
local Dialog = require("scenes.dialog")
local Interior = require("scenes.interior")
local Walker = require("scenes.walker")

local Museum = Walker.extend({ place = "the museum" }, Interior)

local map = interior.parse(require("world.museummap"))
local displayTable
local cases = {} -- the glass cases, in reading order: best-selling console first
for _, piece in ipairs(map.furniture) do
  if piece.kind == "displayTable" then displayTable = piece end
  if piece.kind == "displayCase" then table.insert(cases, piece) end
end

Museum.PROFESSOR = { name = "Professor Cork", sprite = "Master" }
local OFFER = "I've been studying and enjoying games for all my life. I want you to start a game journey of "
  .. "your own, so I'll gift you a console! You can have one. Go on, choose!"
local AFTER = "I hope you try out those games and develop a taste for getting more. "
  .. "Come find me when your collection grows!"
local CHOSEN = "Ah, the %s! A fine choice. Take good care of it!"
local NOT_YET = "These must be the professor's consoles. Maybe I should talk to him first."

function Museum.new(app)
  local self = Interior.new(Museum, app, map)
  local spot = map.spots.professor
  self.people = { { x = spot.x, y = spot.y, facing = "down", look = Museum.PROFESSOR } }
  self.exhibits = progression.mostPopular(progression.timeline(app.catalog.systems), #cases)
  return self
end

function Museum:live(piece)
  return piece.kind == "displayCase"
end

-- The console in a glass case, if the library has enough consoles to fill it.
function Museum:exhibit(piece)
  for i, case in ipairs(cases) do
    if case == piece then return self.exhibits[i] end
  end
end

function Museum:drawLive(piece, px, py)
  local console = self:exhibit(piece)
  art.displayCase(console and console.id, px, py)
end

local function describe(console)
  local sold = console.sold >= 1 and ("%g million"):format(console.sold)
    or ("%d thousand"):format(math.floor(console.sold * 1000 + 0.5))
  return ("The %s, from %d. About %s sold."):format(console.name, console.year, sold)
end

-- The console on the table at (x, y), unless it's the one already given away.
function Museum:consoleAt(x, y)
  if y ~= displayTable.y then return nil end
  local state = self.app.state
  local choices = progression.giftChoices(progression.timeline(self.app.catalog.systems))
  local console = choices[x - displayTable.x + 1]
  if console and not (state.giftReceived and state.giftConsole == console.id) then return console end
end

function Museum:say(text)
  local professor = Museum.PROFESSOR
  scenes.push(Dialog.new(professor.name, art.portrait(professor), text))
end

function Museum:give(console)
  local app = self.app
  local games = economy.giftConsole(app.state, console, app.catalog.bySystem[console.id].locked, love.math.random)
  app:refresh()
  -- The pack shows first; the professor speaks once it's closed.
  self:say(CHOSEN:format(console.name))
  scenes.push(Confirm.notice(ui.starterPackMessage(console, games)))
end

function Museum:interact(piece, person)
  local state = self.app.state
  local exhibit = piece and piece.kind == "displayCase" and self:exhibit(piece)
  if exhibit then
    scenes.push(Dialog.new("", nil, describe(exhibit)))
    return
  end
  if person then
    if state.giftReceived then
      self:say(AFTER)
    else
      state.giftOffered = true
      self.app:persist()
      self:say(OFFER)
    end
    return
  end
  local console = piece.kind == "displayTable" and self:consoleAt(self:facingTile())
  if not console or state.giftReceived then return end
  if not state.giftOffered then
    scenes.push(Dialog.new("", nil, NOT_YET))
  else
    scenes.push(Confirm.new(("Take the %s?"):format(console.name), function() self:give(console) end))
  end
end

function Museum:hintFor(piece, person)
  if person then return ("A: talk to %s"):format(person.look.name) end
  local exhibit = piece and piece.kind == "displayCase" and self:exhibit(piece)
  if exhibit then return ("A: look at the %s"):format(exhibit.short) end
  local console = piece and piece.kind == "displayTable" and self:consoleAt(self:facingTile())
  if not console then return nil end
  local state = self.app.state
  if state.giftOffered and not state.giftReceived then return ("A: take the %s"):format(console.short) end
  return ("The %s"):format(console.name)
end

function Museum:drawOnTop(camX, camY)
  for x = displayTable.x, displayTable.x + displayTable.width - 1 do
    if self:consoleAt(x, displayTable.y) then
      local console = self:consoleAt(x, displayTable.y)
      art.console(console.id, (x - 1) * art.TILE - camX, (displayTable.y - 1) * art.TILE - art.TABLE_TOP - camY)
    end
  end
end

return Museum

local catalog = require("core.catalog")

local SYSTEMS = {
  { id = "nes", name = "Nintendo Entertainment System" },
  { id = "snes", name = "Super Nintendo" },
  { id = "gba", name = "Game Boy Advance" },
  { id = "megadrive", name = "Mega Drive" },
  { id = "psx", name = "PlayStation" },
}

local TITLES = {
  "Pixel Quest", "Turbo Racer", "Dungeon Delve", "Star Blaster", "Puzzle Tower",
  "Ninja Run", "Kart Mayhem", "Haunted Manor", "Sky Pirates", "Mecha Duel",
}
local GENRES = { "Platform", "Racing", "RPG", "Shooter", "Puzzle", "Action" }

local function makeGames(system, index)
  local games = {}
  for i, title in ipairs(TITLES) do
    local path = ("./%s %d.zip"):format(title, i)
    table.insert(games, {
      id = catalog.gameId(system.id, path),
      system = system.id,
      path = path,
      name = ("%s %s"):format(title, ({ "", "II", "III", "DX", "Advance" })[index]):gsub("%s+$", ""),
      desc = ("A mock %s game used while developing Metaretro on the desktop."):format(GENRES[(i + index) % #GENRES + 1]:lower()),
      genre = GENRES[(i + index) % #GENRES + 1],
      releasedate = ("19%02d0101T000000"):format(85 + (i + index * 2) % 15),
      developer = "Mock Studios",
      rating = ((i * 7 + index) % 10) / 10,
      playcount = (i == index) and 1 or 0,
      gametime = 0,
    })
  end
  return games
end

local gamesBySystem = {}
for index, system in ipairs(SYSTEMS) do
  gamesBySystem[system.id] = makeGames(system, index)
end

local mock = { name = "mock", tracksGametime = false }

function mock.detect()
  return true
end

function mock.listSystems()
  return SYSTEMS
end

function mock.listGames(systemId)
  return gamesBySystem[systemId] or {}
end

function mock.launchCommand(game)
  return ("echo 'Launching %s (%s)'; sleep 2"):format(game.name:gsub("'", ""), game.system)
end

function mock.playStats(game)
  return { playcount = game.playcount, gametime = game.gametime }
end

function mock.raCredentials()
  return nil
end

return mock

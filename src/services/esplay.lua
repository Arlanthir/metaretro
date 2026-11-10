local http = require("services.http")
local json = require("lib.json")
local log = require("core.log")
local playtime = require("services.playtime")

-- Tells EmulationStation about play started here, as it records the games it launches itself: one
-- more play per session, the session's time, and when it was last played. Games launched from Retro
-- Town Story bypass ES, so without this its play counts, times and "last played" never move.
-- Goes through ES's local web API, which keeps ES's copy of the gamelist up to date and saves it
-- in ES's own way; writing gamelist.xml behind a running ES's back could be lost or clash with it.
local esplay = {}

esplay.URL = "http://127.0.0.1:1234/systems/%s/games/%s"
-- How many lines of sessions.log ES has been told about; kept apart from the save, so a New Game
-- doesn't tell ES about old play again.
esplay.FILE = "es-sessions.txt"

-- ES's date format, in local time like ES's own.
local function esDate(epoch)
  return os.date("%Y%m%dT%H%M%S", epoch)
end

-- Sends the sessions ES hasn't heard of yet (`sessions` is playtime.parseLog's). `onGame(game, total)`
-- runs for each game ES took the play of. Once every game is done, the log counts as sent; if ES didn't
-- answer, it's all tried again next time.
function esplay.sync(backend, games, sessions, onGame)
  if not backend.esGameId then return end
  local sent = tonumber(love.filesystem.read(esplay.FILE) or "") or 0
  if sent > #sessions then sent = 0 end -- the log was cleared
  if sent == #sessions then return end
  local byId = {}
  for _, game in ipairs(games) do byId[game.id] = game end

  local waiting, failed = 0, false
  local function finish()
    waiting = waiting - 1
    if waiting == 0 and not failed then love.filesystem.write(esplay.FILE, tostring(#sessions)) end
  end
  local function post(game, total)
    local url = esplay.URL:format(game.system, backend.esGameId(game))
    http.get(url, function(body, status)
      local ok, current = pcall(json.decode, body or "")
      if status == 404 then
        log("es: %s isn't in EmulationStation's %s list, skipped", game.name, game.system)
        return finish()
      elseif not ok or type(current) ~= "table" then
        log("es: no answer from EmulationStation (%s)", tostring(status))
        failed = true
        return finish()
      end
      local update = {
        playcount = tostring((tonumber(current.playcount) or 0) + total.count),
        gametime = tostring((tonumber(current.gametime) or 0) + total.seconds),
        lastplayed = esDate(total.last),
      }
      http.post(url, json.encode(update), function(_, postStatus)
        if postStatus == 200 or postStatus == 201 then
          log("es: %s now played %s times, %ss", game.name, update.playcount, update.gametime)
          game.playcount, game.gametime = tonumber(update.playcount), tonumber(update.gametime)
          game.lastplayed = update.lastplayed
          onGame(game, total)
        else
          log("es: EmulationStation didn't take %s's play (%s)", game.name, tostring(postStatus))
          failed = true
        end
        finish()
      end)
    end)
  end

  for id, total in pairs(playtime.totals(sessions, sent + 1)) do
    if byId[id] then
      waiting = waiting + 1
      post(byId[id], total)
    end
  end
  if waiting == 0 then love.filesystem.write(esplay.FILE, tostring(#sessions)) end
end

return esplay

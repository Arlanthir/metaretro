-- GotX ("Games of the X"): the retrohandhelds.gg community's game club picks. Each month has its
-- Games of the Month (one per era: before 1996, 1996-2001, 2002 and later), each quarter a Game of
-- the Quarter (an RPG), each Saturday a RetroBits game, and each year its Games of the Year. The
-- winners come from the GotX Randomizer's database (see assets/gotx/winners.sql), as tab-separated
-- lines; they're matched to the library by ScreenScraper id, or by title for the few without one.
local arcade = require("core.arcade")
local roms = require("core.roms")

local gotx = {}

-- The winners the game ships with (scripts/update-gotx.sh), and the newer ones it downloads
-- into the save folder (services/gotxsync).
gotx.SHIPPED = "assets/gotx/winners.tsv"
gotx.DOWNLOADED = "gotx.tsv"

local KINDS = {
  gotm = { name = "Game of the Month", period = "month" },
  rpg = { name = "Game of the Quarter", period = "quarter" },
  retro = { name = "RetroBits", period = "week" },
  goty = { name = "Game of the Year", period = "year" },
  gotwoty = { name = "RetroBits of the Year", period = "year" },
}
gotx.KINDS = KINDS

local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December" }

local function normalize(name)
  return (tostring(name or ""):lower():gsub("[^%w]", ""))
end

-- `{"Super Nintendo"}` or `{NES," GBA"}` (the database's list syntax) as { "Super Nintendo" } or { "NES", "GBA" }.
local function systems(field)
  local list = {}
  for item in field:gsub("^{", ""):gsub("}$", ""):gmatch("[^,]+") do
    local name = item:gsub('"', ""):match("^%s*(.-)%s*$")
    if name ~= "" then table.insert(list, name) end
  end
  return list
end

local FIELDS = { "kind", "date", "theme", "usa", "eu", "japan", "world", "other", "system", "year", "screenscraper",
  "genre", "hours" }

-- The winners in a winners.tsv, oldest first: { kind, date ("YYYY-MM-DD"), theme, title, titles,
-- systems, year, screenscraperId, genre, hours }. Lines of unknown kinds are skipped.
function gotx.parse(text)
  local winners = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local row, i = {}, 0
    for value in (line .. "\t"):gmatch("([^\t]*)\t") do
      i = i + 1
      row[FIELDS[i] or i] = value
    end
    if KINDS[row.kind] and (row.date or ""):match("^%d%d%d%d%-%d%d%-%d%d") then
      local titles = {}
      for _, field in ipairs({ "usa", "world", "eu", "other", "japan" }) do
        if row[field] and row[field] ~= "" then table.insert(titles, row[field]) end
      end
      table.insert(winners, {
        kind = row.kind,
        date = row.date:sub(1, 10),
        theme = row.theme ~= "" and row.theme or nil,
        title = titles[1] or "?",
        titles = titles,
        systems = systems(row.system or ""),
        year = tonumber(row.year),
        screenscraperId = tonumber(row.screenscraper),
        genre = systems(row.genre or "")[1],
        hours = tonumber(row.hours),
      })
    end
  end
  return winners
end

-- The newest date in `winners`, to tell which copy of the data is the most recent.
function gotx.latestDate(winners)
  local latest = ""
  for _, winner in ipairs(winners) do
    if winner.date > latest then latest = winner.date end
  end
  return latest
end

-- The picks of the moment on `today`: the latest month's Games of the Month (oldest era first),
-- the latest Game of the Quarter and the latest RetroBits.
function gotx.current(winners, today)
  local latest = {}
  for _, winner in ipairs(winners) do
    local period = KINDS[winner.kind].period
    if period ~= "year" and winner.date <= today and winner.date >= (latest[winner.kind] or "") then
      latest[winner.kind] = winner.date
    end
  end
  local picks = {}
  for _, kind in ipairs({ "gotm", "rpg", "retro" }) do
    local group = {}
    for _, winner in ipairs(winners) do
      if winner.kind == kind and winner.date == latest[kind] then table.insert(group, winner) end
    end
    table.sort(group, function(a, b) return (a.year or 0) < (b.year or 0) end)
    for _, winner in ipairs(group) do table.insert(picks, winner) end
  end
  return picks
end

local function addDays(date, days)
  local year, month, day = date:match("^(%d+)-(%d+)-(%d+)")
  return os.date("%Y-%m-%d", os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) + days,
    hour = 12 }))
end

local function quarter(date)
  local year, month = date:match("^(%d+)-(%d+)")
  return ("%s-Q%d"):format(year, math.floor((tonumber(month) - 1) / 3) + 1)
end

-- Whether new picks are due on `today` that `winners` doesn't have yet: a RetroBits a week after
-- the latest one's Saturday, Games of the Month in a month after the latest one's, or a Game of the
-- Quarter in a later quarter. Dates are the picks' own weeks and months, not when they were added.
function gotx.due(winners, today)
  local latest = {}
  for _, winner in ipairs(winners) do
    if winner.date > (latest[winner.kind] or "") then latest[winner.kind] = winner.date end
  end
  if not latest.retro or addDays(latest.retro, 7) <= today then return true end
  if not latest.gotm or latest.gotm:sub(1, 7) < today:sub(1, 7) then return true end
  return latest.rpg ~= nil and quarter(latest.rpg) < quarter(today)
end

-- "Game of the Month, November 2026", "RetroBits, the week of 31 October 2026",
-- "Game of the Quarter, Q4 2026" or "Game of the Year 2024".
function gotx.when(winner)
  local year, month, day = winner.date:match("^(%d+)-(%d+)-(%d+)")
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  local period, name = KINDS[winner.kind].period, KINDS[winner.kind].name
  if period == "month" then
    return ("%s, %s %d"):format(name, MONTHS[month], year)
  elseif period == "week" then
    return ("%s, the week of %d %s %d"):format(name, day, MONTHS[month], year)
  elseif period == "quarter" then
    return ("%s, Q%d %d"):format(name, math.floor((month - 1) / 3) + 1, year)
  end
  -- Games of the Year are picked in the new year, for the one before.
  return ("%s %d"):format(name, month <= 6 and year - 1 or year)
end

-- What a winner was, to finish "Did you know <game> was ...": "Game of the Month in November 2026",
-- "the RetroBits pick for the week of 31 October 2026", "Game of the Quarter in Q4 2026" or
-- "a Game of the Year for 2024".
function gotx.title(winner)
  local when = gotx.when(winner)
  local name, rest = when:match("^(.-), (.+)$")
  if not name then return "a " .. when:gsub("(%d+)$", "for %1") end
  if winner.kind == "retro" then return "the RetroBits pick for " .. rest end
  return ("%s in %s"):format(name, rest)
end

-- A Game of the Month's era, from its year.
function gotx.era(winner)
  local year = winner.year or 0
  return year < 1996 and "before 1996" or year <= 2001 and "1996 to 2001" or "2002 and later"
end

-- The library game each winner is, as { [winner] = game }: by ScreenScraper id, or by any of the
-- winner's titles for the few without one. `games` is every game in the library.
function gotx.match(winners, games)
  local byId, byName = {}, {}
  for _, game in ipairs(games) do
    if game.screenscraperId and not byId[game.screenscraperId] then byId[game.screenscraperId] = game end
    local name = normalize(game.name)
    if name ~= "" and not byName[name] then byName[name] = game end
  end
  local matched = {}
  for _, winner in ipairs(winners) do
    local game = winner.screenscraperId and byId[winner.screenscraperId]
    if not game and not winner.screenscraperId then
      for _, title in ipairs(winner.titles) do
        game = byName[normalize(title)]
        if game then break end
      end
    end
    matched[winner] = game
  end
  return matched
end

-- Everything the town needs from GotX on `today`, given the built catalog and the library's arcade
-- games (which the catalog leaves out): { winners, current (the picks of the moment), gameOf
-- ({ [winner] = library game }), winnersOf ({ [game id] = its winners }), loans ({ [game id] =
-- winner }) }. Current console picks in the library that the player doesn't own, and whose ROM is
-- there, are on loan: playable like owned games, on any console, until the next pick of their kind.
-- Arcade picks aren't loaned: they stand in the Arcade Club instead (see arcade.cabinets).
function gotx.attach(winners, built, state, today, arcadeGames)
  local games = {}
  for _, game in ipairs(arcadeGames or {}) do table.insert(games, game) end
  for _, entry in pairs(built.bySystem) do
    for _, group in ipairs({ entry.owned, entry.locked }) do
      for _, game in ipairs(group) do table.insert(games, game) end
    end
  end
  local gameOf, winnersOf = gotx.match(winners, games), {}
  for _, winner in ipairs(winners) do
    local game = gameOf[winner]
    if game then
      winnersOf[game.id] = winnersOf[game.id] or {}
      table.insert(winnersOf[game.id], winner)
    end
  end
  local current, loans = gotx.current(winners, today), {}
  for _, winner in ipairs(current) do
    local game = gameOf[winner]
    if game and not arcade.isArcade(game) and not state.owned[game.id] and roms.present(game) then
      loans[game.id] = winner
    end
  end
  return { winners = winners, current = current, gameOf = gameOf, winnersOf = winnersOf, loans = loans }
end

return gotx

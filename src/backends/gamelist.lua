local catalog = require("core.catalog")

local gamelist = {}

local FIELDS = {}
for _, field in ipairs({
  "path", "name", "desc", "image", "thumbnail", "marquee", "video",
  "releasedate", "developer", "publisher", "genre", "players",
  "rating", "playcount", "lastplayed", "gametime", "hidden", "lang", "region", "cheevosId", "cheevosHash",
}) do
  FIELDS[field] = true
end
local MEDIA = { image = true, thumbnail = true, marquee = true, video = true }

local ENTITIES = { amp = "&", lt = "<", gt = ">", quot = '"', apos = "'" }

local function utf8char(code)
  if code < 0x80 then
    return string.char(code)
  elseif code < 0x800 then
    return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
  elseif code < 0x10000 then
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
  end
  return string.char(0xF0 + math.floor(code / 0x40000), 0x80 + math.floor(code / 0x1000) % 0x40,
    0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

local function decode(text)
  return (text:gsub("&(#?)([xX]?)(%w+);", function(hash, hex, name)
    if hash == "#" then
      local code = tonumber(name, hex ~= "" and 16 or 10)
      return code and utf8char(code)
    end
    return ENTITIES[hex .. name]
  end))
end

local function resolve(systemDir, path)
  if path:sub(1, 2) == "./" then
    return systemDir .. "/" .. path:sub(3)
  elseif path:sub(1, 1) ~= "/" then
    return systemDir .. "/" .. path
  end
  return path
end

function gamelist.parse(xml, systemId, systemDir)
  local games = {}
  for attributes, body in xml:gmatch("<game%f[%s>]([^>]*)>(.-)</game>") do
    local game = { system = systemId }
    -- Single pass over the entry's child elements; %1 matches the closing tag.
    for field, value in body:gmatch("<([%w_]+)>(.-)</%1>") do
      if FIELDS[field] then
        if value:find("&", 1, true) then
          value = decode(value)
        end
        game[field] = MEDIA[field] and resolve(systemDir, value) or value
      end
    end
    if game.path and game.hidden ~= "true" then
      game.hidden = nil
      game.name = game.name or game.path:match("([^/]+)$")
      game.id = catalog.gameId(systemId, game.path)
      game.rom = resolve(systemDir, game.path)
      game.playcount = tonumber(game.playcount) or 0
      game.gametime = tonumber(game.gametime) or 0
      game.cheevosId = tonumber(game.cheevosId)
      -- RetroAchievements' hash of the ROM; scrapers often fill it in without the id.
      game.cheevosHash = game.cheevosHash and game.cheevosHash:lower()
      -- The id attribute belongs to whichever scraper filled the entry; only trust ScreenScraper's.
      if body:find('<scrap name="ScreenScraper"', 1, true) then
        game.screenscraperId = tonumber(attributes:match('id="(%d+)"'))
      end
      table.insert(games, game)
    end
  end
  return games
end

return gamelist

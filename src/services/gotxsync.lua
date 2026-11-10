local gotx = require("core.gotx")
local http = require("services.http")
local log = require("core.log")

-- Keeps the GotX winners up to date: when a new pick is due (see gotx.due), at most once a day,
-- downloads the GotX Randomizer's database
-- (github.com/blakekl/gotx-randomizer, MIT), keeps only the winners with sqlite3 (the query in
-- assets/gotx/winners.sql) as gotx.tsv in the save folder, and deletes the database, which also
-- holds community members' data that isn't kept.
local gotxsync = {}

gotxsync.URL = "https://raw.githubusercontent.com/blakekl/gotx-randomizer/main/src/gotx-randomizer.sqlite"
gotxsync.STAMP = "gotx-fetched.txt" -- the day the winners were last downloaded ("YYYY-MM-DD")

local function quote(text)
  return "'" .. text:gsub("'", "'\\''") .. "'"
end

-- Fetches newer winners when a pick is due and none was downloaded today (a failed download tries
-- again at the next start); `onNewer(winners)` runs when they're newer than `current` (the winners
-- in use).
function gotxsync.sync(current, onNewer)
  local today = os.date("%Y-%m-%d")
  if not gotx.due(current, today) or love.filesystem.read(gotxsync.STAMP) == today then return end
  local dir = love.filesystem.getSaveDirectory()
  local database, query = dir .. "/gotx.sqlite", dir .. "/gotx.sql"
  log("gotx: fetching the winners")
  http.download(gotxsync.URL, database, function(ok)
    if not ok then
      log("gotx: couldn't download the GotX database, will retry next start")
      return
    end
    love.filesystem.write("gotx.sql", love.filesystem.read("assets/gotx/winners.sql"))
    local command = ("sqlite3 -readonly -separator '\t' %s < %s 2>/dev/null"):format(quote(database), quote(query))
    http.run(command, function(output)
      os.remove(database)
      os.remove(query)
      love.filesystem.write(gotxsync.STAMP, today)
      local winners = gotx.parse(output)
      if #winners == 0 then
        log("gotx: couldn't read the GotX database (is sqlite3 there?), will retry next start")
        return
      end
      love.filesystem.write(gotx.DOWNLOADED, output)
      log("gotx: %d winners, the latest from %s", #winners, gotx.latestDate(winners))
      if gotx.latestDate(winners) > gotx.latestDate(current) then onNewer(winners) end
    end)
  end)
end

return gotxsync

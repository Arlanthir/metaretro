-- Parsed gamelists, kept in the save folder so a start only parses the gamelists that changed.
-- One file per system, written as Lua (loading it is far quicker than parsing XML without the JIT),
-- with the key it was made from: the backend's stamp of the gamelist (its modification time and
-- size) and `version`, which changes with the parser. Any change to either parses the system again,
-- so the cache never needs clearing by hand; a broken or missing file is just a miss.
local librarycache = {}

librarycache.DIR = "library"
-- Bump when the file layout below changes.
local FORMAT = 1

local function quote(value)
  return type(value) == "string" and ("%q"):format(value) or tostring(value)
end

function librarycache.encode(key, games)
  local parts = { "return ", quote(key), ",{\n" }
  for _, game in ipairs(games) do
    parts[#parts + 1] = "{"
    for field, value in pairs(game) do
      parts[#parts + 1] = ("[%q]=%s,"):format(field, quote(value))
    end
    parts[#parts + 1] = "},\n"
  end
  parts[#parts + 1] = "}\n"
  return table.concat(parts)
end

-- The key and games in an encoded cache, or nil when it can't be read.
function librarycache.decode(text)
  local chunk = text and load(text, "=librarycache", "t", {})
  if not chunk then return nil end
  local ok, key, games = pcall(chunk)
  if ok and type(key) == "string" and type(games) == "table" then return key, games end
  return nil
end

local Cache = {}
Cache.__index = Cache

-- `fs` needs read, write and createDirectory (love.filesystem fits).
function librarycache.new(fs, version)
  fs.createDirectory(librarycache.DIR)
  return setmetatable({ fs = fs, version = FORMAT .. ":" .. tostring(version) }, Cache)
end

local function fileFor(system)
  return ("%s/%s.lua"):format(librarycache.DIR, system)
end

-- The system's games when the cache was made from the same `stamp`, or nil.
function Cache:get(system, stamp)
  local key, games = librarycache.decode(self.fs.read(fileFor(system)))
  if key == self.version .. "|" .. stamp then return games end
  return nil
end

function Cache:put(system, stamp, games)
  self.fs.write(fileFor(system), librarycache.encode(self.version .. "|" .. stamp, games))
end

return librarycache

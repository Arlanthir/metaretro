local librarycache = require("services.librarycache")

local function memoryFs()
  local files = {}
  return {
    files = files,
    read = function(path) return files[path] end,
    write = function(path, contents) files[path] = contents return true end,
    createDirectory = function() return true end,
  }
end

local games = {
  { id = "snes:./a.sfc", name = 'Quote " back\\slash', desc = "Two\nlines\r\nand a tab\t", playcount = 3, rating = "0.8" },
  { id = "snes:./b.sfc", name = "Pokémon 「ポケモン」", cheevosId = 1234, gametime = 0 },
}

describe("librarycache", function()
  it("gives back exactly the games it was given, for the same stamp", function()
    local cache = librarycache.new(memoryFs(), "parser1")
    cache:put("snes", "100 2048 /roms", games)
    assert.same(games, cache:get("snes", "100 2048 /roms"))
  end)

  it("misses when the gamelist's stamp changed", function()
    local cache = librarycache.new(memoryFs(), "parser1")
    cache:put("snes", "100 2048 /roms", games)
    assert.is_nil(cache:get("snes", "101 2048 /roms"))
    assert.is_nil(cache:get("gba", "100 2048 /roms"))
  end)

  it("misses when the parser changed", function()
    local fs = memoryFs()
    librarycache.new(fs, "parser1"):put("snes", "100 2048 /roms", games)
    assert.is_nil(librarycache.new(fs, "parser2"):get("snes", "100 2048 /roms"))
  end)

  it("treats a broken file as a miss", function()
    local fs = memoryFs()
    local cache = librarycache.new(fs, "parser1")
    fs.files["library/snes.lua"] = "return 'half a file"
    assert.is_nil(cache:get("snes", "100 2048 /roms"))
    fs.files["library/snes.lua"] = "os.exit(1)"
    assert.is_nil(cache:get("snes", "100 2048 /roms"))
  end)
end)

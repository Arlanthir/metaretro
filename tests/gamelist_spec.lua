local gamelist = require("backends.gamelist")

local function fixture(path)
  local file = assert(io.open("tests/fixtures/" .. path, "rb"))
  local contents = file:read("*a")
  file:close()
  return contents
end

describe("gamelist.parse", function()
  local games = gamelist.parse(fixture("roms/snes/gamelist.xml"), "snes", "/userdata/roms/snes")

  it("skips hidden games and folders", function()
    assert.equal(2, #games)
  end)

  it("reads metadata and numeric stats", function()
    local game = games[1]
    assert.equal("snes:./Super Metroid (USA).sfc", game.id)
    assert.equal("Super Metroid", game.name)
    assert.equal("0.95", game.rating)
    assert.equal(3, game.playcount)
    assert.equal(5400, game.gametime)
  end)

  it("decodes named and numeric entities", function()
    assert.equal("Samus & the baby Metroid é❤", games[1].desc)
  end)

  it("resolves relative rom and media paths against the system folder", function()
    assert.equal("/userdata/roms/snes/Super Metroid (USA).sfc", games[1].rom)
    assert.equal("/userdata/roms/snes/images/Super Metroid (USA)-image.png", games[1].image)
    assert.equal("/userdata/roms/snes/media/thumb.png", games[1].thumbnail)
  end)

  it("falls back to the file name and zero stats", function()
    assert.equal("No Metadata.sfc", games[2].name)
    assert.equal(0, games[2].playcount)
    assert.equal(0, games[2].gametime)
  end)
end)

local knulli = require("backends.knulli")

knulli.romsDir = "tests/fixtures/roms"
knulli.confPath = "tests/fixtures/batocera.conf"
knulli.inputDevicesPath = "tests/fixtures/input_devices"

describe("knulli backend", function()
  it("detects batocera.conf", function()
    assert.is_true(knulli.detect())
  end)

  it("lists systems with a gamelist, skipping ports", function()
    local ids = {}
    for _, system in ipairs(knulli.listSystems()) do
      ids[system.id] = system.name
    end
    assert.same({ gba = "Game Boy Advance", snes = "Super Nintendo" }, ids)
  end)

  it("lists games of a system, skipping entries whose ROM is missing", function()
    local games = knulli.listGames("snes")
    assert.equal(1, #games)
    assert.equal("Super Metroid", games[1].name)
    assert.equal(1, #knulli.listGames("gba"))
    assert.same({}, knulli.listGames("missing"))
  end)

  local pad = { index = 0, guid = "1900abcd", name = "H700 Gamepad", buttons = 15, hats = 1, axes = 4 }

  it("maps input device names to event nodes", function()
    local devices = knulli.parseInputDevices(io.open("tests/fixtures/input_devices"):read("*a"))
    assert.same({ ["axp20x-pek"] = "/dev/input/event0", ["H700 Gamepad"] = "/dev/input/event3" }, devices)
  end)

  it("builds the controllers config ES passes to emulatorlauncher", function()
    local other = { index = 1, guid = "05", name = "USB Pad", buttons = 10, hats = 0, axes = 2 }
    assert.equal(table.concat({
      "-p1index '0' -p1guid '1900abcd' -p1name 'H700 Gamepad' -p1nbbuttons '15' -p1nbhats '1' -p1nbaxes '4'",
      "-p1devicepath '/dev/input/event3'",
      "-p2index '1' -p2guid '05' -p2name 'USB Pad' -p2nbbuttons '10' -p2nbhats '0' -p2nbaxes '2'",
    }, " "), knulli.controllersConfig({ pad, other }, { ["H700 Gamepad"] = "/dev/input/event3" }))
  end)

  it("builds a quoted emulatorlauncher command with controllers", function()
    local game = { system = "snes", rom = "/userdata/roms/snes/It's.sfc" }
    local command = knulli.launchCommand(game, { pad })
    assert.matches("^emulatorlauncher %-p1index '0' ", command)
    assert.matches("%-p1devicepath '/dev/input/event3' %-system 'snes' %-rom '/userdata/roms/snes/It'\\''s%.sfc'$", command)
  end)

  it("reads the RetroAchievements username", function()
    assert.same({ username = "retroplayer" }, knulli.raCredentials())
  end)
end)

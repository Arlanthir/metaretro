local gotx = require("core.gotx")

local function line(...)
  return table.concat({ ... }, "\t")
end

local TSV = table.concat({
  line("gotm", "2026-10-01", "Spooktober 2026", "Castlevania", "", "", "", "", '{NES," GBA"}', "1986", "1268", "{Platform}", "6.0"),
  line("rpg", "2026-10-01", "GotQ 16", "", "", "", "Xenogears", "", "{PS1}", "1998", "19298", "{RPG}", "60.0"),
  line("retro", "2026-10-24", "Retro Bits 2026-10-24", "The Flintstones", "", "", "", "", "{NES}", "1991", "1512", "", ""),
  line("retro", "2026-10-31", "Retro Bits 2026-10-31", "", "", "", "Magician Lord", "", "{Neo-Geo}", "1990", "37602", "", ""),
  line("gotm", "2026-11-01", "Novemb-her 2026", "Tomb Raider", "", "Tomb Raiders", "", "", "{PSX}", "1996", "19268", "{Action}", "15.0"),
  line("gotm", "2026-11-01", "Novemb-her 2026", "Shantae", "", "", "", "", "{GBC}", "2002", "36998", "{Platform}", "9.0"),
  line("gotm", "2026-11-01", "Novemb-her 2026", "Super Mario Bros. 2", "", "", "", "", "{NES}", "1988", "1248", "", "3.0"),
  line("goty", "2025-01-15", "GotY 2024", "Chrono Trigger", "", "", "", "", '{"Super Nintendo"}', "1995", "", "", ""),
  line("nomination", "2026-11-01", "ignored"),
}, "\n")

describe("gotx", function()
  local winners = gotx.parse(TSV)

  it("reads the winners, with their titles and systems", function()
    assert.equal(8, #winners)
    assert.same({ "NES", "GBA" }, winners[1].systems)
    assert.equal("Xenogears", winners[2].title)
    assert.same({ "Tomb Raider", "Tomb Raiders" }, winners[5].titles)
    assert.same({ 1268, 6 }, { winners[1].screenscraperId, winners[1].hours })
    assert.equal("2026-11-01", gotx.latestDate(winners))
  end)

  it("picks the latest month's games, oldest era first, then the quarter's and the week's", function()
    local titles = {}
    for i, winner in ipairs(gotx.current(winners, "2026-11-10")) do titles[i] = winner.title end
    assert.same({ "Super Mario Bros. 2", "Tomb Raider", "Shantae", "Xenogears", "Magician Lord" }, titles)
  end)

  it("ignores picks dated after today", function()
    local titles = {}
    for i, winner in ipairs(gotx.current(winners, "2026-10-25")) do titles[i] = winner.title end
    assert.same({ "Castlevania", "Xenogears", "The Flintstones" }, titles)
  end)

  it("says when a winner was picked", function()
    assert.equal("Game of the Month, November 2026", gotx.when(winners[5]))
    assert.equal("RetroBits, the week of 31 October 2026", gotx.when(winners[4]))
    assert.equal("Game of the Quarter, Q4 2026", gotx.when(winners[2]))
    assert.equal("Game of the Year 2024", gotx.when(winners[8]))
    assert.equal("Game of the Month in November 2026", gotx.title(winners[5]))
    assert.equal("the RetroBits pick for the week of 31 October 2026", gotx.title(winners[4]))
    assert.equal("Game of the Quarter in Q4 2026", gotx.title(winners[2]))
    assert.equal("a Game of the Year for 2024", gotx.title(winners[8]))
    assert.same({ "before 1996", "1996 to 2001", "2002 and later" },
      { gotx.era(winners[7]), gotx.era(winners[5]), gotx.era(winners[6]) })
  end)

  it("matches winners to the library by ScreenScraper id, or by title without one", function()
    local library = {
      { id = "psx:tr", name = "Tomb Raider (USA)", screenscraperId = 19268 },
      { id = "nes:smb2", name = "Some other name", screenscraperId = 1248 },
      { id = "snes:ct", name = "Chrono Trigger" },
      { id = "gbc:shantae", name = "Shantae" }, -- right title, but the winner has an id it lacks
    }
    local matched = gotx.match(winners, library)
    assert.equal("psx:tr", matched[winners[5]].id)
    assert.equal("nes:smb2", matched[winners[7]].id)
    assert.equal("snes:ct", matched[winners[8]].id)
    assert.is_nil(matched[winners[6]])
  end)
end)

describe("gotx.attach", function()
  local save = require("core.save")
  local winners = gotx.parse(table.concat({
    table.concat({ "retro", "2026-10-31", "Retro Bits", "", "", "", "Magician Lord", "", "{Neo-Geo}", "1990", "37602", "", "" }, "\t"),
    table.concat({ "gotm", "2026-11-01", "Novemb-her 2026", "Shantae", "", "", "", "", "{GBC}", "2002", "36998", "", "" }, "\t"),
  }, "\n"))
  local shantae = { id = "gbc:shantae", system = "gbc", name = "Shantae", screenscraperId = 36998 }
  local magician = { id = "fbneo:maglord", system = "fbneo", name = "Magician Lord", screenscraperId = 37602 }
  local built = { bySystem = { gbc = { owned = {}, locked = { shantae } } } }

  it("loans current console picks, and matches arcade ones without loaning them", function()
    local info = gotx.attach(winners, built, save.defaults(), "2026-11-10", { magician })
    assert.equal(magician, info.gameOf[winners[1]])
    assert.is_nil(info.loans[magician.id])
    assert.equal(winners[2], info.loans[shantae.id])
  end)

  it("doesn't loan what the player owns", function()
    local state = save.defaults()
    state.owned[shantae.id] = true
    assert.is_nil(gotx.attach(winners, built, state, "2026-11-10", {}).loans[shantae.id])
  end)
end)

describe("gotx.due", function()
  local function winners(...)
    local list = {}
    for i, entry in ipairs({ ... }) do list[i] = { kind = entry[1], date = entry[2] } end
    return list
  end
  local upToDate = winners({ "gotm", "2026-11-01" }, { "rpg", "2026-10-01" }, { "retro", "2026-11-07" })

  it("is due a week after the latest RetroBits' Saturday", function()
    assert.is_false(gotx.due(upToDate, "2026-11-13"))
    assert.is_true(gotx.due(upToDate, "2026-11-14"))
  end)

  it("is due in a new month, or a new quarter", function()
    local list = winners({ "gotm", "2026-11-01" }, { "rpg", "2026-10-01" }, { "retro", "2026-11-28" })
    assert.is_false(gotx.due(list, "2026-11-30"))
    assert.is_true(gotx.due(list, "2026-12-01"))
    local quarterBehind = winners({ "gotm", "2027-01-01" }, { "rpg", "2026-10-01" }, { "retro", "2027-01-02" })
    assert.is_true(gotx.due(quarterBehind, "2027-01-03"))
  end)

  it("is due with nothing at all", function()
    assert.is_true(gotx.due({}, "2026-11-10"))
  end)
end)

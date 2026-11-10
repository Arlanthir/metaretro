local save = require("core.save")
local townsfolk = require("core.townsfolk")
local town = require("world.town")

local function game(id, fields)
  fields = fields or {}
  fields.id, fields.system, fields.name = id, fields.system or "snes", fields.name or id
  return fields
end

local function first(n) return 1 end

describe("townsfolk", function()
  local state
  before_each(function() state = save.defaults() end)

  local map = town.parse(require("world.townmap"))
  local function tileAt(x, y) return town.tile(map, x, y) end
  local tiles = townsfolk.startTiles(tileAt, map.width, map.height, map.start)
  local function distance(a, b) return math.abs(a.x - b.x) + math.abs(a.y - b.y) end

  it("brings one villager of each kind each day, spread over town", function()
    for day = 1, 30 do
      local roster = townsfolk.dailyRoster(("2026-11-%02d"):format(day), tiles)
      assert.equal(#townsfolk.KINDS, #roster)
      local kinds = {}
      for i, entry in ipairs(roster) do
        kinds[entry.villager.kind] = true
        assert.is_true(townsfolk.canWanderTo(tileAt, entry, entry.x, entry.y))
        assert.is_true(distance(entry, map.start) >= townsfolk.START_CLEARANCE)
        for j = i + 1, #roster do
          assert.is_true(distance(entry, roster[j]) >= townsfolk.MIN_SPACING)
        end
      end
      for _, kind in ipairs(townsfolk.KINDS) do assert.is_true(kinds[kind], kind) end
    end
  end)

  it("keeps the same roster all day and changes it across days", function()
    local function names(day)
      local list = {}
      for _, entry in ipairs(townsfolk.dailyRoster(day, tiles)) do
        table.insert(list, entry.villager.id .. "@" .. entry.x .. "," .. entry.y)
      end
      return table.concat(list, " ")
    end
    assert.equal(names("2026-11-06"), names("2026-11-06"))
    local different = false
    for day = 7, 14 do
      if names(("2026-11-%02d"):format(day)) ~= names("2026-11-06") then different = true end
    end
    assert.is_true(different)
  end)

  it("starts villagers in many different places over a month", function()
    local seen, count = {}, 0
    for day = 1, 30 do
      for _, entry in ipairs(townsfolk.dailyRoster(("2026-11-%02d"):format(day), tiles)) do
        local spot = entry.x .. "," .. entry.y
        if not seen[spot] then seen[spot], count = true, count + 1 end
      end
    end
    assert.is_true(count > 100, count)
  end)

  it("leaves a villager out when no tile is far enough from the others", function()
    local roster = townsfolk.dailyRoster("2026-11-06", { { x = 1, y = 1 }, { x = 2, y = 1 } })
    assert.equal(1, #roster)
  end)

  it("has several villagers of each kind, each with a sprite and portrait", function()
    local perKind, ids = {}, {}
    for _, villager in ipairs(townsfolk.CAST) do
      assert.is_nil(ids[villager.id], villager.id)
      ids[villager.id] = true
      perKind[villager.kind] = (perKind[villager.kind] or 0) + 1
      for _, suffix in ipairs({ "", "Face" }) do
        local path = "src/assets/ninja-adventure/villagers/" .. villager.sprite .. suffix .. ".png"
        local file = io.open(path, "rb")
        assert.truthy(file, path)
        file:close()
      end
    end
    for _, kind in ipairs(townsfolk.KINDS) do assert.equal(4, perKind[kind], kind) end
  end)

  it("has residents with hints and Granny Rose at home, none of them out in town", function()
    local inTown = {}
    for _, villager in ipairs(townsfolk.CAST) do inTown[villager.sprite] = true end
    local people = { townsfolk.GRANDMA }
    for _, resident in ipairs(townsfolk.RESIDENTS) do
      assert.is_true(#resident.hints >= 3, resident.name)
      for _, hint in ipairs(resident.hints) do assert.is_nil(hint:find("%", 1, true), hint) end
      table.insert(people, resident)
    end
    for _, person in ipairs(people) do
      assert.is_nil(inTown[person.sprite], person.name)
      for _, suffix in ipairs({ "", "Face" }) do
        local path = "src/assets/ninja-adventure/villagers/" .. person.sprite .. suffix .. ".png"
        local file = io.open(path, "rb")
        assert.truthy(file, path)
        file:close()
      end
    end
  end)

  it("lets villagers wander only on nearby grass that isn't under a tree", function()
    local rows = { "....", "..T.", "...." }
    local function tileAt(x, y) local row = rows[y]; return row and row:sub(x, x) or "T" end
    local home = { x = 1, y = 1 }
    assert.is_true(townsfolk.canWanderTo(tileAt, home, 2, 1))
    assert.is_false(townsfolk.canWanderTo(tileAt, home, 3, 1)) -- the tree below would cover them
    assert.is_false(townsfolk.canWanderTo(tileAt, home, 3, 2)) -- the tree itself
    assert.is_false(townsfolk.canWanderTo(tileAt, home, 4, 3)) -- too far from home
  end)

  it("gives every villager several lines with the right placeholders for their kind", function()
    local arguments = { genre = 2, storeTip = 2 }
    for _, villager in ipairs(townsfolk.CAST) do
      assert.is_true(#villager.suggest >= 2 and #villager.none >= 2, villager.name)
      local expected = arguments[villager.kind] or 1
      for _, line in ipairs(villager.suggest) do
        local _, count = line:gsub("%%s", "")
        assert.equal(expected, count, villager.name .. ": " .. line)
      end
      for _, line in ipairs(villager.none) do
        assert.is_nil(line:find("%", 1, true), villager.name .. ": " .. line)
      end
    end
  end)

  it("knows when a game was last played from the backend or our own record", function()
    assert.equal(0, townsfolk.lastPlayed(state, game("a")))
    assert.equal(20241003122910, townsfolk.lastPlayed(state, game("a", { lastplayed = "20241003T122910" })))
    state.lastPlayed.a = os.time({ year = 2026, month = 1, day = 2, hour = 3, min = 4, sec = 5 })
    assert.equal(20260102030405, townsfolk.lastPlayed(state, game("a", { lastplayed = "20241003T122910" })))
  end)

  it("finds owned games that were never played", function()
    local fresh, counted, timed, ours = game("fresh"), game("counted", { playcount = 2 }), game("timed", { gametime = 60 }), game("ours")
    state.lastPlayed.ours = 100
    assert.same({ fresh }, townsfolk.neverPlayed(state, { fresh, counted, timed, ours }))
  end)

  it("lists played games from the longest ago", function()
    local old = game("old", { lastplayed = "20200101T000000" })
    local recent = game("recent", { lastplayed = "20250101T000000" })
    local middle = game("middle", { lastplayed = "20230101T000000" })
    assert.same({ old, middle }, townsfolk.forgotten(state, { recent, game("never"), old, middle }, 2))
  end)

  it("finds games with achievements that haven't paid out", function()
    local paid, unpaid = game("paid", { cheevosId = 1 }), game("unpaid", { cheevosId = 2 })
    state.achievementCoins["1"] = 50
    assert.same({ unpaid }, townsfolk.uncashedAchievements(state, { paid, unpaid, game("none") }))
  end)

  it("groups games by category in category order", function()
    local rpg, platform = game("r", { category = "rpg" }), game("p", { category = "platform" })
    local groups = townsfolk.byCategory({ rpg, platform })
    assert.same({ "platform", "rpg" }, { groups[1].category.id, groups[2].category.id })
  end)

  it("recommends an owned game, or says something when there's nothing to recommend", function()
    local unplayed = game("unplayed", { name = "Super Metroid" })
    local catalog = { systems = { { id = "snes" } }, bySystem = { snes = { owned = { unplayed }, locked = {} } } }
    local context = { state = state, catalog = catalog, timeline = {}, today = "2026-11-06", random = first }
    state.ownedConsoles.snes = true
    local tomo = townsfolk.CAST[1]
    local reply = townsfolk.talk(tomo, context)
    assert.equal(unplayed, reply.game)
    assert.truthy(reply.text:find("Super Metroid", 1, true))

    catalog.bySystem.snes.owned = {}
    for _, villager in ipairs(townsfolk.CAST) do
      local line = townsfolk.talk(villager, context)
      assert.is_nil(line.game)
      assert.truthy(#line.text > 0)
    end
  end)
end)

describe("townsfolk.spriteFor", function()
  it("gives a villager who looks like the player the other look of that kind", function()
    assert.equal("Villager3", townsfolk.spriteFor("Villager3", "boy"))
    assert.equal("Boy", townsfolk.spriteFor("Villager3", "boyDark"))
    assert.equal("Girl", townsfolk.spriteFor("Princess", "girlDark"))
    assert.equal("Princess", townsfolk.spriteFor("Princess", "girl"))
    assert.equal("OldMan", townsfolk.spriteFor("OldMan", "boyDark"))
  end)

  it("has a sprite and portrait for every look", function()
    for _, look in ipairs(townsfolk.PLAYER_LOOKS) do
      for _, suffix in ipairs({ "", "Face" }) do
        local path = "src/assets/ninja-adventure/villagers/" .. townsfolk.playerSprite(look) .. suffix .. ".png"
        local file = io.open(path, "rb")
        assert.truthy(file, path)
        file:close()
      end
    end
  end)
end)

describe("townsfolk before the first console", function()
  it("sends the player to Professor Cork in the museum, whoever they talk to", function()
    local context = { state = save.defaults(), catalog = { systems = {}, bySystem = {} }, timeline = {},
      today = "2026-11-06", random = first }
    for _, villager in ipairs(townsfolk.CAST) do
      local reply = townsfolk.talk(villager, context)
      assert.is_nil(reply.game)
      assert.truthy(reply.text:find("Professor Cork", 1, true), villager.name)
      assert.truthy(reply.text:find("museum", 1, true), villager.name)
    end
  end)
end)

describe("townsfolk.lastPlayedGame", function()
  it("finds the game played most recently by either record", function()
    local state = save.defaults()
    local old = { id = "nes:old", system = "nes", lastplayed = "20240101T120000" }
    local recent = { id = "snes:recent", system = "snes", lastplayed = "20250101T120000" }
    local ours = { id = "gb:ours", system = "gb" }
    assert.equal(recent, townsfolk.lastPlayedGame(state, { old, recent, ours }))
    state.lastPlayed[ours.id] = os.time({ year = 2026, month = 1, day = 1, hour = 12 })
    assert.equal(ours, townsfolk.lastPlayedGame(state, { old, recent, ours }))
  end)

  it("finds nothing when no game has been played", function()
    assert.is_nil(townsfolk.lastPlayedGame(save.defaults(), { { id = "nes:new", system = "nes" } }))
  end)
end)

describe("townsfolk on GotX", function()
  local function info(current, past)
    local winners, gameOf = {}, {}
    for _, list in ipairs({ past, current }) do
      for _, entry in ipairs(list) do
        table.insert(winners, entry.winner)
        gameOf[entry.winner] = entry.game
      end
    end
    local currentWinners = {}
    for i, entry in ipairs(current) do currentWinners[i] = entry.winner end
    return { winners = winners, current = currentWinners, gameOf = gameOf, loans = {}, winnersOf = {} }
  end

  local function talk(gotxInfo, random)
    local state = save.defaults()
    state.ownedConsoles.nes = true
    local catalog = { systems = {}, bySystem = { nes = { owned = {}, locked = {} } }, gotx = gotxInfo }
    return townsfolk.talk(townsfolk.CAST[1], { state = state, catalog = catalog, timeline = {}, today = "2026-11-10",
      random = random })
  end

  local shantae = { id = "gbc:shantae", name = "Shantae" }
  local sm64 = { id = "n64:sm64", name = "Super Mario 64" }
  local monthPick = { winner = { kind = "gotm", date = "2026-11-01", theme = "Novemb-her 2026", title = "Shantae" },
    game = shantae }
  local pastPick = { winner = { kind = "gotm", date = "2020-08-01", title = "Super Mario 64" }, game = sm64 }

  it("mentions a current pick in the library, with the month's theme", function()
    local reply = talk(info({ monthPick }, {}), function() return 1 end)
    assert.equal(shantae, reply.game)
    assert.truthy(reply.text:find("Novemb-her 2026", 1, true))
    assert.truthy(reply.text:find("Shantae", 1, true))
  end)

  it("tells trivia about a past winner in the library", function()
    local reply = talk(info({}, { pastPick }), function() return 1 end)
    assert.equal(sm64, reply.game)
    assert.truthy(reply.text:find("Super Mario 64 was Game of the Month in August 2020", 1, true))
  end)

  it("keeps to the usual topics most of the time", function()
    local reply = talk(info({ monthPick }, { pastPick }), function(n) return n end)
    assert.is_nil(reply.game) -- the usual topic, with nothing to recommend in this library
  end)
end)

describe("townsfolk's GotX trivia", function()
  local winner = { kind = "retro", date = "2026-10-31", title = "Magician Lord" }
  local game = { id = "fbneo:maglord", name = "Magician Lord" }
  local info = { winners = { winner }, current = {}, gameOf = { [winner] = game }, loans = {}, winnersOf = {} }

  local function lines(owned)
    local state = save.defaults()
    state.ownedConsoles.nes = true
    if owned then state.owned[game.id] = true end
    local seen = {}
    -- Every choice of line, with the GotX topic always picked first.
    for choice = 1, #townsfolk.GOTX_TRIVIA + #townsfolk.GOTX_TRIVIA_OWNED do
      local calls = 0
      local random = function(n)
        calls = calls + 1
        if calls == 1 then return 1 end -- talk about GotX
        return math.min(choice, n)
      end
      local catalog = { systems = {}, bySystem = { nes = { owned = {}, locked = {} } }, gotx = info }
      seen[townsfolk.talk(townsfolk.CAST[1], { state = state, catalog = catalog, timeline = {}, today = "2026-11-10",
        random = random }).text] = true
    end
    return seen
  end

  it("never says the player has a game they don't own", function()
    for text in pairs(lines(false)) do assert.is_nil(text:find("You've got", 1, true), text) end
  end)

  it("can say so when they do", function()
    local said = false
    for text in pairs(lines(true)) do said = said or text:find("You've got", 1, true) ~= nil end
    assert.is_true(said)
  end)
end)

local save = require("core.save")

local function memoryFs(files)
  files = files or {}
  return {
    files = files,
    read = function(path) return files[path] end,
    write = function(path, contents) files[path] = contents return true end,
  }
end

describe("save", function()
  it("returns defaults when there is no save file", function()
    assert.same(save.defaults(), save.load(memoryFs()))
  end)

  it("round-trips state", function()
    local fs = memoryFs()
    local state = save.defaults()
    state.wallet = 42
    state.owned["nes:./a.zip"] = true
    save.write(fs, state)
    assert.same(state, save.load(fs))
  end)

  it("recovers from corrupt files", function()
    assert.same(save.defaults(), save.load(memoryFs({ [save.FILE] = "{not json" })))
  end)

  it("fills missing fields and drops mistyped ones on migrate", function()
    local state = save.migrate({ version = 0, wallet = "lots", owned = { x = true } })
    assert.equal(save.defaults().wallet, state.wallet)
    assert.same({ x = true }, state.owned)
    assert.same({}, state.seenAchievements)
    assert.equal(save.VERSION, state.version)
  end)
end)

describe("save settings", function()
  it("start empty, so everything they cover is hidden", function()
    assert.same({}, save.loadSettings(memoryFs()))
  end)

  it("round-trip through their own file, apart from the save", function()
    local fs = memoryFs()
    save.writeSettings(fs, { showJapanese = true })
    assert.same({ showJapanese = true }, save.loadSettings(fs))
    assert.is_nil(save.load(fs).settings)
  end)

  it("fall back to empty on a broken file", function()
    local fs = memoryFs()
    fs.write(save.SETTINGS_FILE, "{oops")
    assert.same({}, save.loadSettings(fs))
  end)
end)

describe("save migration for the intro", function()
  it("starts new games before the intro", function()
    local state = save.defaults()
    assert.is_false(state.introDone)
    assert.is_false(state.giftReceived)
    assert.equal("boy", state.player)
  end)

  it("skips the intro and the gift for saves from before them", function()
    local state = save.migrate({ initialized = true, ownedConsoles = { nes = true } })
    assert.is_true(state.introDone)
    assert.is_true(state.giftOffered)
    assert.is_true(state.giftReceived)
  end)

  it("keeps a save made during the intro in the intro", function()
    local state = save.migrate({ initialized = true, introDone = false })
    assert.is_false(state.introDone)
  end)
end)

describe("version", function()
  it("is a major.minor.patch number", function()
    assert.truthy(require("core.version"):match("^%d+%.%d+%.%d+$"))
  end)
end)

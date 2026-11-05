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

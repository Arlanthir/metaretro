local scenes = require("core.scenes")

describe("scenes.draw", function()
  local drawn
  local function scene(name, drawBelow)
    return { drawBelow = drawBelow, draw = function() table.insert(drawn, name) end }
  end

  before_each(function() drawn = {} end)

  it("draws only the top scene normally", function()
    scenes.switch(scene("town"))
    scenes.push(scene("shop"))
    scenes.draw()
    assert.same({ "shop" }, drawn)
  end)

  it("draws the scene under an overlay first", function()
    scenes.switch(scene("town"))
    scenes.push(scene("shop"))
    scenes.push(scene("confirm", true))
    scenes.draw()
    assert.same({ "shop", "confirm" }, drawn)
  end)
end)

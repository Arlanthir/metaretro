local input = require("core.input")

describe("input", function()
  local actions
  before_each(function()
    actions = {}
    input.setHandler(function(action) table.insert(actions, action) end)
  end)

  local function pressAll()
    for _, button in ipairs({ "a", "b", "x", "y", "start" }) do
      input.gamepadpressed(nil, button)
      input.gamepadreleased(nil, button)
    end
  end

  it("maps SDL buttons by position by default", function()
    input.setNintendoLayout(false)
    pressAll()
    assert.same({ "a", "b", "x", "y", "start" }, actions)
  end)

  it("swaps face buttons for Nintendo-style devices", function()
    input.setNintendoLayout(true)
    pressAll()
    assert.same({ "b", "a", "y", "x", "start" }, actions)
    input.setNintendoLayout(false)
  end)

  it("drops presses while ignoring input", function()
    input.ignoreFor(1000)
    input.keypressed("z")
    input.ignoreFor(0)
    input.keypressed("x")
    assert.same({ "b" }, actions)
  end)

  it("keeps the keyboard unaffected", function()
    input.setNintendoLayout(true)
    input.keypressed("z")
    assert.same({ "a" }, actions)
    input.setNintendoLayout(false)
  end)
end)

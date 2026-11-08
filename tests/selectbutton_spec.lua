local selectbutton = require("core.selectbutton")

describe("selectbutton", function()
  it("pays out on the tenth quick press, then starts counting again", function()
    local tracker = selectbutton.new()
    for i = 1, selectbutton.TAPS - 1 do assert.is_false(selectbutton.tap(tracker, i * 0.2)) end
    assert.is_true(selectbutton.tap(tracker, selectbutton.TAPS * 0.2))
    assert.is_false(selectbutton.tap(tracker, selectbutton.TAPS * 0.2 + 0.1))
  end)

  it("starts over after a pause between presses", function()
    local tracker = selectbutton.new()
    local now = 0
    for _ = 1, selectbutton.TAPS - 1 do
      now = now + 0.2
      selectbutton.tap(tracker, now)
    end
    now = now + selectbutton.TAP_GAP + 0.1
    assert.is_false(selectbutton.tap(tracker, now))
  end)

  it("toggles once per hold, after holding long enough", function()
    local tracker = selectbutton.new()
    assert.is_false(selectbutton.hold(tracker, 1.5, true))
    assert.is_true(selectbutton.hold(tracker, 0.6, true))
    assert.is_false(selectbutton.hold(tracker, 5, true))
    assert.is_false(selectbutton.hold(tracker, 0.1, false))
    assert.is_false(selectbutton.hold(tracker, 1.9, true))
    assert.is_true(selectbutton.hold(tracker, 0.2, true))
  end)
end)

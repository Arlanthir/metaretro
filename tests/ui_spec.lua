local ui = require("ui")

-- Every byte is 7px wide, so widths are easy to reason about.
local font = { getWidth = function(_, text) return #text * 7 end }

describe("ui.truncate", function()
  it("leaves text that fits alone", function()
    assert.equal("Tetris", ui.truncate(font, "Tetris", 100))
  end)

  it("cuts long text with an ellipsis within the width", function()
    local result = ui.truncate(font, "The Legend of Zelda: A Link to the Past", 140)
    assert.equal("The Legend of Zelda...", ui.truncate(font, "The Legend of Zelda: A Link to the Past", 154))
    assert.is_true(font:getWidth(result) <= 140)
    assert.equal("...", result:sub(-3))
  end)

  it("drops trailing spaces before the ellipsis", function()
    assert.equal("Super...", ui.truncate(font, "Super Mario Bros", 63))
  end)

  it("never splits a multi-byte character", function()
    -- At 49px "Pok" plus the first byte of "é" would fit; the cut must back off to "Pok".
    assert.equal("Pok...", ui.truncate(font, "Pokémon Stadium", 49))
    assert.equal("Poké...", ui.truncate(font, "Pokémon Stadium", 56))
  end)
end)

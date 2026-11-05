local genres = require("core.genres")

describe("genres.categorize", function()
  it("uses the top level of ScreenScraper's 'Main / Sub' genres", function()
    assert.equal("shooter", genres.categorize("Shoot'em Up / Vertical"))
    assert.equal("sports", genres.categorize("Sports / Football (Soccer)"))
    assert.equal("platform", genres.categorize("Platform"))
  end)

  it("keeps commas that are part of a genre name", function()
    assert.equal("racing", genres.categorize("Racing, Driving"))
    assert.equal("racing", genres.categorize("Race, Driving / Boat"))
  end)

  it("merges stray spellings and related genres", function()
    assert.equal("rpg", genres.categorize("Role-Playing"))
    assert.equal("puzzle", genres.categorize("Thinking"))
    assert.equal("fighting", genres.categorize("Beat'em Up"))
    assert.equal("tabletop", genres.categorize("Asiatic board game / Mahjong"))
  end)

  it("puts missing and unknown genres in other", function()
    assert.equal("other", genres.categorize(nil))
    assert.equal("other", genres.categorize("Compilation / Fishing"))
    assert.equal("other", genres.categorize("Something New"))
  end)

  it("has a category entry for every id it returns", function()
    for _, genre in ipairs({ "Platform", "Puzzle", "Music and Dancing", "Casino", nil }) do
      assert.is_truthy(genres.get(genres.categorize(genre)))
    end
  end)
end)

describe("genres in the example gamelists", function()
  local OTHER_ON_PURPOSE = {
    Compilation = true, Educational = true, ["Casual Game"] = true, Various = true, Adults = true,
  }

  it("map every top-level genre to a specific category", function()
    local unmapped = {}
    local listing = io.popen("ls example-data/*/gamelist.xml 2>/dev/null")
    for path in listing:lines() do
      local file = assert(io.open(path, "rb"))
      for genre in file:read("*a"):gmatch("<genre>(.-)</genre>") do
        local top = genres.topLevel(genre)
        if genres.categorize(genre) == "other" and not OTHER_ON_PURPOSE[top] then
          unmapped[top] = true
        end
      end
      file:close()
    end
    listing:close()
    assert.same({}, unmapped)
  end)
end)

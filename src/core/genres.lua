-- Groups ScreenScraper genres ("Main / Sub") into the categories genre stores specialize in.
local genres = {}

genres.CATEGORIES = {
  { id = "platform", name = "Platformers", short = "Platform" },
  { id = "rpg", name = "Role-Playing", short = "RPG" },
  { id = "adventure", name = "Action & Adventure", short = "Adventure" },
  { id = "fighting", name = "Fighting", short = "Fighting" },
  { id = "shooter", name = "Shooters", short = "Shooters" },
  { id = "racing", name = "Racing", short = "Racing" },
  { id = "sports", name = "Sports", short = "Sports" },
  { id = "puzzle", name = "Puzzle & Quiz", short = "Puzzle" },
  { id = "strategy", name = "Strategy & Simulation", short = "Strategy" },
  { id = "tabletop", name = "Tabletop", short = "Tabletop" },
  { id = "music", name = "Music", short = "Music" },
  { id = "other", name = "Miscellaneous", short = "Misc" },
}

local BY_ID = {}
for _, category in ipairs(genres.CATEGORIES) do
  BY_ID[category.id] = category
end

-- Top-level ScreenScraper genre -> category id, including the stray spellings seen in real gamelists.
local TOP_LEVEL = {
  ["Platform"] = "platform",
  ["Role Playing Game"] = "rpg", ["Role-Playing"] = "rpg",
  ["Action"] = "adventure", ["Adventure"] = "adventure",
  ["Fighting"] = "fighting", ["Beat'em Up"] = "fighting",
  ["Shoot'em Up"] = "shooter", ["Shooter"] = "shooter", ["Lightgun Shooter"] = "shooter",
  ["Racing, Driving"] = "racing", ["Race, Driving"] = "racing",
  ["Sports"] = "sports", ["Sports with animals"] = "sports", ["Hunting and Fishing"] = "sports",
  ["Puzzle"] = "puzzle", ["Puzzle-Game"] = "puzzle", ["Thinking"] = "puzzle", ["Quiz"] = "puzzle",
  ["Strategy"] = "strategy", ["Simulation"] = "strategy",
  ["Board game"] = "tabletop", ["Asiatic board game"] = "tabletop", ["Casino"] = "tabletop",
  ["Playing cards"] = "tabletop", ["Pinball"] = "tabletop",
  ["Music and Dancing"] = "music",
}

function genres.topLevel(genre)
  return genre and (genre:match("^(.-)%s*/") or genre:match("^%s*(.-)%s*$")) or nil
end

function genres.categorize(genre)
  return TOP_LEVEL[genres.topLevel(genre)] or "other"
end

function genres.get(id)
  return BY_ID[id]
end

return genres

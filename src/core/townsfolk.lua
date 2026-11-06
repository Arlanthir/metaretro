-- Villagers in town and what they recommend when you talk to them.
local genres = require("core.genres")
local stores = require("core.stores")

local townsfolk = {}

-- Everyone who might be in town. Each day one villager of each kind shows up (see dailyRoster).
-- `sprite` names art in assets/ninja-adventure/villagers. `suggest` takes the game's name (the genre
-- kind also gets the category first, the store kind the store first); `none` is for nothing to suggest.
townsfolk.CAST = {
  { id = "tomo", name = "Grandpa Tomo", sprite = "OldMan", kind = "neverPlayed",
    suggest = "Back in my day we finished what we bought! You've never even started %s. Give it a go!",
    none = "You've played every game you own? Hmph. Kids these days... well done." },
  { id = "bram", name = "Bram", sprite = "Villager", kind = "neverPlayed",
    suggest = "You bought %s and never played it? That's like baking bread and not eating it!",
    none = "Not a single unplayed game? I wish my bakery shelves were that tidy." },
  { id = "pip", name = "Pip", sprite = "Villager4", kind = "genre",
    suggest = "I'm crazy about %s right now! Have you tried %s? It's one of yours!",
    none = "Buy some games and I'll tell you which ones I love!" },
  { id = "juno", name = "Juno", sprite = "Villager3", kind = "genre",
    suggest = "Everyone at school is into %s lately. You've got %s, why not try it?",
    none = "Your shelf is empty! Go get some games already." },
  { id = "sensei", name = "Sensei", sprite = "Master", kind = "achievements",
    suggest = "%s hides achievements you have not claimed. Seek them, and coins will follow.",
    none = "Every challenge in your collection has paid its reward. Your training is complete... for now." },
  { id = "kai", name = "Brother Kai", sprite = "Monk", kind = "achievements",
    suggest = "Patience brings rewards. %s still holds achievements waiting for you.",
    none = "There are no rewards left to seek. Rest, and find new games." },
  { id = "rose", name = "Granny Rose", sprite = "OldWoman", kind = "forgotten",
    suggest = "Oh dear, it's been ages since you played %s. Old friends like to be visited!",
    none = "Play a few games, dear, and I'll remind you of the ones you miss." },
  { id = "mia", name = "Mia", sprite = "Woman", kind = "forgotten",
    suggest = "Remember %s? You haven't played it in forever!",
    none = "Once you've played a few games, I'll tell you which ones you're neglecting." },
  { id = "scout", name = "Scout", sprite = "Inspector", kind = "storeTip",
    suggest = "Psst! The %s has %s in today's picks. Don't tell anyone I told you.",
    none = "Nothing worth a tip today. Check back tomorrow!" },
  { id = "timmy", name = "Timmy", sprite = "Child", kind = "storeTip",
    suggest = "Guess what! The %s has %s today! I saw it through the window!",
    none = "The stores are boring today. Nothing new!" },
}

townsfolk.KINDS = { "neverPlayed", "genre", "achievements", "forgotten", "storeTip" }

-- Grass tiles villagers start the day on; they wander up to WANDER_RADIUS tiles from there.
townsfolk.SPOTS = {
  { x = 20, y = 4 }, { x = 24, y = 11 }, { x = 6, y = 11 }, { x = 16, y = 18 },
  { x = 30, y = 10 }, { x = 10, y = 3 }, { x = 33, y = 18 }, { x = 12, y = 25 },
}
townsfolk.WANDER_RADIUS = 2

-- A small deterministic generator, so a given day always has the same villagers in the same spots.
local function seededRandom(text)
  local seed = 0
  for i = 1, #text do
    seed = (seed * 31 + text:byte(i)) % 2147483647
  end
  return function(n)
    seed = (seed * 48271) % 2147483647
    return seed % n + 1
  end
end

-- Today's villagers: one of each kind, each on its own spot, as { villager, x, y }.
function townsfolk.dailyRoster(day)
  local random = seededRandom(day)
  local spots = {}
  for i, spot in ipairs(townsfolk.SPOTS) do spots[i] = spot end
  local roster = {}
  for _, kind in ipairs(townsfolk.KINDS) do
    local candidates = {}
    for _, villager in ipairs(townsfolk.CAST) do
      if villager.kind == kind then table.insert(candidates, villager) end
    end
    local spot = table.remove(spots, random(#spots))
    table.insert(roster, { villager = candidates[random(#candidates)], x = spot.x, y = spot.y })
  end
  return roster
end

-- Whether a villager whose spot is `home` may step onto (x, y): grass only (so streets and doors
-- stay clear), near home, and not right above a tree whose crown would cover them.
function townsfolk.canWanderTo(tileAt, home, x, y)
  return tileAt(x, y) == "." and tileAt(x, y + 1) ~= "T"
    and math.abs(x - home.x) + math.abs(y - home.y) <= townsfolk.WANDER_RADIUS
end

function townsfolk.ownedGames(built)
  local games = {}
  for _, system in ipairs(built.systems) do
    for _, game in ipairs(built.bySystem[system.id].owned) do
      table.insert(games, game)
    end
  end
  return games
end

-- When the game was last played as a YYYYMMDDhhmmss number (0 if never): the later of the
-- backend's lastplayed and Metaretro's own record of play.
function townsfolk.lastPlayed(state, game)
  local fromBackend = game.lastplayed and tonumber(game.lastplayed:gsub("T", ""):sub(1, 14)) or 0
  local ours = state.lastPlayed[game.id]
  local fromMetaretro = ours and tonumber(os.date("%Y%m%d%H%M%S", ours)) or 0
  return math.max(fromBackend, fromMetaretro)
end

local function played(state, game)
  return (tonumber(game.playcount) or 0) > 0 or (tonumber(game.gametime) or 0) > 0
    or townsfolk.lastPlayed(state, game) > 0
end

function townsfolk.neverPlayed(state, games)
  local result = {}
  for _, game in ipairs(games) do
    if not played(state, game) then table.insert(result, game) end
  end
  return result
end

-- The `count` played games that have gone the longest without being played.
function townsfolk.forgotten(state, games, count)
  local result = {}
  for _, game in ipairs(games) do
    if played(state, game) then table.insert(result, game) end
  end
  table.sort(result, function(a, b) return townsfolk.lastPlayed(state, a) < townsfolk.lastPlayed(state, b) end)
  for i = #result, (count or 5) + 1, -1 do
    result[i] = nil
  end
  return result
end

function townsfolk.uncashedAchievements(state, games)
  local result = {}
  for _, game in ipairs(games) do
    if game.cheevosId and not state.achievementCoins[tostring(game.cheevosId)] then
      table.insert(result, game)
    end
  end
  return result
end

-- Games grouped by genre category, as { { category, games }, ... } in category order.
function townsfolk.byCategory(games)
  local groups, byId = {}, {}
  for _, game in ipairs(games) do
    local id = game.category or "other"
    if not byId[id] then
      byId[id] = { category = genres.get(id), games = {} }
    end
    table.insert(byId[id].games, game)
  end
  for _, category in ipairs(genres.CATEGORIES) do
    if byId[category.id] then table.insert(groups, byId[category.id]) end
  end
  return groups
end

local function pick(list, random)
  return #list > 0 and list[random(#list)] or nil
end

-- What `villager` says: { text, game? }. With a game, the player can open it from the dialog.
-- `context` has state, catalog, timeline, today and random.
function townsfolk.talk(villager, context)
  local state, random = context.state, context.random
  local owned = townsfolk.ownedGames(context.catalog)
  local kind = villager.kind
  local game, text

  if kind == "neverPlayed" then
    game = pick(townsfolk.neverPlayed(state, owned), random)
    text = game and villager.suggest:format(game.name)
  elseif kind == "genre" then
    local group = pick(townsfolk.byCategory(owned), random)
    game = group and pick(group.games, random)
    text = game and villager.suggest:format(group.category.name, game.name)
  elseif kind == "achievements" then
    game = pick(townsfolk.uncashedAchievements(state, owned), random)
    text = game and villager.suggest:format(game.name)
  elseif kind == "forgotten" then
    game = pick(townsfolk.forgotten(state, owned), random)
    text = game and villager.suggest:format(game.name)
  elseif kind == "storeTip" then
    local store = pick(stores.list(state, context.catalog, context.timeline), random)
    local offer = store and stores.offer(store, state, context.catalog, context.timeline, context.today, random)
    local tip = offer and pick(offer, random)
    -- A tip points at a store; there's nothing to open from the dialog.
    return { text = tip and villager.suggest:format(store.title, tip.name) or villager.none }
  end
  return { game = game, text = text or villager.none }
end

return townsfolk

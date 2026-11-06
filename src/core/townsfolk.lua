-- Villagers in town and what they recommend when you talk to them.
local daily = require("core.daily")
local genres = require("core.genres")
local stores = require("core.stores")

local townsfolk = {}

-- Everyone who might be in town. Each day one villager of each kind shows up (see dailyRoster).
-- `sprite` names art in assets/ninja-adventure/villagers. Each talk picks one of the `suggest` lines,
-- which take the game's name (the genre kind gets the category first, the store kind the store first),
-- or one of the `none` lines when there's nothing to suggest.
townsfolk.CAST = {
  { id = "tomo", name = "Grandpa Tomo", sprite = "OldMan", kind = "neverPlayed",
    suggest = {
      "Back in my day we finished what we bought! You've never even started %s. Give it a go!",
      "%s is gathering dust on your shelf. Games are for playing, youngster!",
      "When I was your age, I'd have played %s till my thumbs hurt. You haven't even tried it!",
    },
    none = {
      "You've played every game you own? Hmph. Kids these days... well done.",
      "Not one unplayed game. My generation would be proud.",
    } },
  { id = "bram", name = "Bram", sprite = "Villager", kind = "neverPlayed",
    suggest = {
      "You bought %s and never played it? That's like baking bread and not eating it!",
      "Fresh out of the box: %s! Well, it would be, if you ever opened it.",
      "A game unplayed is a loaf unbaked. Give %s a try!",
    },
    none = {
      "Not a single unplayed game? I wish my bakery shelves were that tidy.",
      "Everything you own has been played. Now that's a well-stocked pantry!",
    } },
  { id = "pip", name = "Pip", sprite = "Villager4", kind = "genre",
    suggest = {
      "I'm crazy about %s right now! Have you tried %s? It's one of yours!",
      "%s games are the best! You should play %s, you already have it!",
      "Ooh, I've been dreaming about %s. Play %s and tell me everything!",
    },
    none = {
      "Buy some games and I'll tell you which ones I love!",
      "No games yet? The shops are just down the road!",
    } },
  { id = "juno", name = "Juno", sprite = "Villager3", kind = "genre",
    suggest = {
      "Everyone at school is into %s lately. You've got %s, why not try it?",
      "My friends won't stop talking about %s. Have you played %s?",
      "If you like %s, %s is right there in your collection!",
    },
    none = {
      "Your shelf is empty! Go get some games already.",
      "I'd recommend something, but you don't have anything yet!",
    } },
  { id = "sensei", name = "Sensei", sprite = "Master", kind = "achievements",
    suggest = {
      "%s hides achievements you have not claimed. Seek them, and coins will follow.",
      "A true master would return to %s. Its challenges still await you.",
      "The path to wealth runs through %s. Its achievements remain unclaimed.",
    },
    none = {
      "Every challenge in your collection has paid its reward. Your training is complete... for now.",
      "You have claimed all there is to claim. Find new games, and new challenges.",
    } },
  { id = "kai", name = "Brother Kai", sprite = "Monk", kind = "achievements",
    suggest = {
      "Patience brings rewards. %s still holds achievements waiting for you.",
      "I meditated on %s today. Its achievements are calling to you.",
      "Some treasures take effort. %s has achievements you have yet to earn.",
    },
    none = {
      "There are no rewards left to seek. Rest, and find new games.",
      "Your collection holds no unclaimed rewards. Be at peace.",
    } },
  { id = "rose", name = "Granny Rose", sprite = "OldWoman", kind = "forgotten",
    suggest = {
      "Oh dear, it's been ages since you played %s. Old friends like to be visited!",
      "Whatever happened to %s? You used to play it, didn't you?",
      "I was just thinking about %s. You should give it another go, dear.",
    },
    none = {
      "Play a few games, dear, and I'll remind you of the ones you miss.",
      "You haven't played anything yet? Go on, have some fun!",
    } },
  { id = "mia", name = "Mia", sprite = "Woman", kind = "forgotten",
    suggest = {
      "Remember %s? You haven't played it in forever!",
      "Feeling nostalgic? %s has been waiting for you.",
      "It's been a while since %s. Want to pick it up again?",
    },
    none = {
      "Once you've played a few games, I'll tell you which ones you're neglecting.",
      "Nothing to be nostalgic about yet. Go make some memories!",
    } },
  { id = "scout", name = "Scout", sprite = "Inspector", kind = "storeTip",
    suggest = {
      "Psst! The %s has %s in today's picks. Don't tell anyone I told you.",
      "My sources say the %s got %s in today. Act fast!",
      "Word on the street: %s, %s. You didn't hear it from me.",
    },
    none = {
      "Nothing worth a tip today. Check back tomorrow!",
      "The shops are quiet today. My sources have nothing.",
    } },
  { id = "timmy", name = "Timmy", sprite = "Child", kind = "storeTip",
    suggest = {
      "Guess what! The %s has %s today! I saw it through the window!",
      "I wish I had coins! The %s is selling %s today!",
      "Mom says no, but the %s has %s! You should get it!",
    },
    none = {
      "The stores are boring today. Nothing new!",
      "I checked every shop window. Nothing cool today.",
    } },
}

townsfolk.KINDS = { "neverPlayed", "genre", "achievements", "forgotten", "storeTip" }

-- Grass tiles villagers start the day on; they wander up to WANDER_RADIUS tiles from there.
townsfolk.SPOTS = {
  { x = 20, y = 4 }, { x = 24, y = 11 }, { x = 6, y = 11 }, { x = 16, y = 18 },
  { x = 30, y = 10 }, { x = 10, y = 3 }, { x = 33, y = 18 }, { x = 12, y = 25 },
}
townsfolk.WANDER_RADIUS = 2

-- Today's villagers: one of each kind, each on its own spot, as { villager, x, y }.
function townsfolk.dailyRoster(day)
  local random = daily.random(day)
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
    text = game and pick(villager.suggest, random):format(game.name)
  elseif kind == "genre" then
    local group = pick(townsfolk.byCategory(owned), random)
    game = group and pick(group.games, random)
    text = game and pick(villager.suggest, random):format(group.category.name, game.name)
  elseif kind == "achievements" then
    game = pick(townsfolk.uncashedAchievements(state, owned), random)
    text = game and pick(villager.suggest, random):format(game.name)
  elseif kind == "forgotten" then
    game = pick(townsfolk.forgotten(state, owned), random)
    text = game and pick(villager.suggest, random):format(game.name)
  elseif kind == "storeTip" then
    local store = pick(stores.list(state, context.catalog, context.timeline), random)
    local offer = store and stores.offer(store, state, context.catalog, context.timeline, context.today, random)
    local tip = offer and pick(offer, random)
    -- A tip points at a store; there's nothing to open from the dialog.
    return { text = tip and pick(villager.suggest, random):format(store.title, tip.name) or pick(villager.none, random) }
  end
  return { game = game, text = text or pick(villager.none, random) }
end

return townsfolk

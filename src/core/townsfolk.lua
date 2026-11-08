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
  { id = "hawk", name = "Hawk", sprite = "Hunter", kind = "neverPlayed",
    suggest = {
      "A good hunter never leaves gear unused. %s is still in its wrapping!",
      "I tracked down an unplayed game on your shelf: %s. Go get it!",
      "%s has never been played. Even my old traps see more action!",
    },
    none = {
      "Not one unplayed game? There's nothing left for me to track down.",
      "Every game you own has been played. Fine hunting!",
    } },
  { id = "hiro", name = "Farmer Hiro", sprite = "OldMan3", kind = "neverPlayed",
    suggest = {
      "Seeds don't grow in the sack, friend. Sit yourself down with %s!",
      "You've got %s and never played it? That's a field left fallow!",
      "Reap what you've sown! %s is still waiting to be played.",
    },
    none = {
      "Every game played? Your fields are all harvested. Good work!",
      "Nothing left unplayed. Now that's a tidy farm.",
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
  { id = "amara", name = "Princess Amara", sprite = "Princess", kind = "genre",
    suggest = {
      "At the palace we only talk about %s. You simply must play %s!",
      "I hereby declare %s the finest kind of game. Play %s, by royal order!",
      "My royal tutor says %s games build character. Do try %s!",
    },
    none = {
      "No games at all? Even the palace jester has a few!",
      "Your shelf is bare! Visit the shops, then come and see me.",
    } },
  { id = "ula", name = "Ula", sprite = "Cavegirl", kind = "genre",
    suggest = {
      "Ula like %s! %s is good game. You play!",
      "%s games make Ula happy. Go play %s!",
      "%s best kind of game! Ula see %s in your cave. Play it!",
    },
    none = {
      "You have no games? Ula have more games than you, and Ula have rocks.",
      "Empty cave! Go get games from shops.",
    } },
  { id = "sensei", name = "Sensei", sprite = "Monk2", kind = "achievements",
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
  { id = "ronin", name = "Ronin", sprite = "Samurai", kind = "achievements",
    suggest = {
      "An unfinished duel brings no honor. Return to %s and claim its achievements.",
      "%s still holds challenges. A warrior does not leave them unanswered.",
      "The blade is sharpened by practice. %s has achievements left to earn.",
    },
    none = {
      "Every challenge has been met with honor. Rest your blade, for now.",
      "No achievements remain unclaimed. Seek new battles in new games.",
    } },
  { id = "gareth", name = "Sir Gareth", sprite = "Knight", kind = "achievements",
    suggest = {
      "A quest awaits! %s has achievements no hero has claimed.",
      "By my sword! %s still has glory left to win. Onward!",
      "The realm whispers of %s and its unclaimed achievements. Will you answer?",
    },
    none = {
      "All quests completed! The realm salutes you, hero.",
      "There is no glory left to claim. Find new games, and new quests!",
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
  { id = "yuki", name = "Yuki", sprite = "Eskimo", kind = "forgotten",
    suggest = {
      "Brr! %s has been left out in the cold. Go warm it up!",
      "Remember %s? It's been frozen on your shelf for ages.",
      "Ice keeps things fresh, but not forever. Time to thaw out %s!",
    },
    none = {
      "Nothing's been left out in the cold yet. Go play something!",
      "Play a few games and I'll tell you which ones are freezing over.",
    } },
  { id = "bo", name = "Captain Bo", sprite = "OldMan2", kind = "forgotten",
    suggest = {
      "Ahoy! You haven't sailed back to %s in a long while.",
      "Every ship returns to port. Isn't it time you returned to %s?",
      "I remember the days you played %s. Hoist the sails and go back!",
    },
    none = {
      "No voyages logged yet! Set sail with a game first.",
      "Once you've played a few games, I'll tell you which ports you've forgotten.",
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
  { id = "percy", name = "Lord Percy", sprite = "Noble", kind = "storeTip",
    suggest = {
      "Between us, the %s has %s today. I'd buy it myself, but I own three already.",
      "I've been browsing the %s. %s caught my eye. Quite the find!",
      "A gentleman notices these things: the %s is selling %s today.",
    },
    none = {
      "The shops have nothing worthy of my attention today.",
      "Nothing of note in the shops today. How dreadfully dull.",
    } },
  { id = "gus", name = "Gus", sprite = "Villager2", kind = "storeTip",
    suggest = {
      "Just dropped off a crate at the %s. %s, said the label!",
      "Delivery day! The %s just got %s in stock.",
      "My back's sore from carrying boxes to the %s. One of them was %s!",
    },
    none = {
      "No deliveries today. The shops have the same old stock.",
      "Quiet day on my route. Nothing new in the shops.",
    } },
}

townsfolk.KINDS = { "neverPlayed", "genre", "achievements", "forgotten", "storeTip" }

-- Villagers start the day on a random grass tile and wander up to WANDER_RADIUS tiles from there.
-- Starting tiles are at least MIN_SPACING apart, so they spread over town, and START_CLEARANCE
-- away from the player's start.
townsfolk.WANDER_RADIUS = 2
townsfolk.MIN_SPACING = 8
townsfolk.START_CLEARANCE = 3

local function distance(a, b)
  return math.abs(a.x - b.x) + math.abs(a.y - b.y)
end

-- Grass only (so streets and doors stay clear), and not right above a tree whose crown would cover them.
local function canStand(tileAt, x, y)
  return tileAt(x, y) == "." and tileAt(x, y + 1) ~= "T"
end

-- Every tile a villager may start the day on, in map order.
function townsfolk.startTiles(tileAt, width, height, start)
  local tiles = {}
  for y = 1, height do
    for x = 1, width do
      local tile = { x = x, y = y }
      if canStand(tileAt, x, y) and distance(tile, start) >= townsfolk.START_CLEARANCE then
        table.insert(tiles, tile)
      end
    end
  end
  return tiles
end

-- Today's villagers: one of each kind on a random tile from `tiles`, as { villager, x, y }.
-- A villager is left out only when no tile is far enough from the others.
function townsfolk.dailyRoster(day, tiles)
  local random = daily.random(day)
  local free = {}
  for i, tile in ipairs(tiles) do free[i] = tile end
  local roster = {}
  for _, kind in ipairs(townsfolk.KINDS) do
    local candidates = {}
    for _, villager in ipairs(townsfolk.CAST) do
      if villager.kind == kind then table.insert(candidates, villager) end
    end
    local villager = candidates[random(#candidates)]
    while #free > 0 do
      local tile = table.remove(free, random(#free))
      local spaced = true
      for _, other in ipairs(roster) do
        if distance(tile, other) < townsfolk.MIN_SPACING then spaced = false end
      end
      if spaced then
        table.insert(roster, { villager = villager, x = tile.x, y = tile.y })
        break
      end
    end
  end
  return roster
end

-- Whether a villager whose spot is `home` may step onto (x, y).
function townsfolk.canWanderTo(tileAt, home, x, y)
  return canStand(tileAt, x, y) and distance(home, { x = x, y = y }) <= townsfolk.WANDER_RADIUS
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

-- Of `games`, the one played most recently (by either record), or nil when none has been played.
function townsfolk.lastPlayedGame(state, games)
  local latest, latestTime = nil, 0
  for _, game in ipairs(games) do
    local time = townsfolk.lastPlayed(state, game)
    if time > latestTime then latest, latestTime = game, time end
  end
  return latest
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

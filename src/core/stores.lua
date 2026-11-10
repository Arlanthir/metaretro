local catalog = require("core.catalog")
local daily = require("core.daily")
local genres = require("core.genres")
local roms = require("core.roms")

-- Stores in town: one per owned console, plus a genre store for every category with enough games on
-- those consoles (a tiny genre would offer the same few games every day).
-- Store ids double as lot keys in the save: console stores use the system id, genre stores "genre:<id>".
local stores = {}

-- Games of a category, owned or not, the owned consoles need before its genre store opens.
stores.MIN_GENRE_GAMES = 30

-- The stores open today: one per owned console, a genre store for every category with enough games,
-- and the GotX store when GotX winners are for sale (see core/gotx; `built.gotx`). With `today` (and
-- `random`, to draw offers not drawn yet), a store whose stock turns out to be all missing ROMs (see
-- stores.offer) doesn't open at all.
function stores.list(state, built, timeline, today, random)
  local list, stocked = {}, {}
  for _, console in ipairs(timeline) do
    if state.ownedConsoles[console.id] then
      table.insert(list, { id = console.id, kind = "console", console = console,
        short = console.short, title = console.short .. " Store" })
      local games = built.bySystem[console.id]
      for _, group in ipairs({ games.owned, games.locked }) do
        for _, game in ipairs(group) do
          stocked[game.category] = (stocked[game.category] or 0) + 1
        end
      end
    end
  end
  for _, category in ipairs(genres.CATEGORIES) do
    if (stocked[category.id] or 0) >= stores.MIN_GENRE_GAMES then
      table.insert(list, { id = "genre:" .. category.id, kind = "genre", genre = category,
        short = category.short, title = category.name .. " Store" })
    end
  end
  local gotxStore = { id = "gotx", kind = "gotx", short = "GotX", title = "GotX Store" }
  if built.gotx and #stores.stock(gotxStore, state, built, timeline) > 0 then table.insert(list, gotxStore) end
  if not today then return list end
  local open = {}
  for _, store in ipairs(list) do
    if select(3, stores.offer(store, state, built, timeline, today, random)) > 0 then table.insert(open, store) end
  end
  return open
end

-- Games a store has for sale: a console's, a genre's on the owned consoles, or the GotX winners
-- on the owned consoles.
function stores.stock(store, state, built, timeline)
  if store.kind == "console" then
    return built.bySystem[store.console.id].locked
  end
  local items = {}
  for _, console in ipairs(timeline) do
    if state.ownedConsoles[console.id] then
      for _, game in ipairs(built.bySystem[console.id].locked) do
        if store.kind == "gotx" and built.gotx.winnersOf[game.id] or store.genre and game.category == store.genre.id then
          table.insert(items, game)
        end
      end
    end
  end
  table.sort(items, catalog.byName)
  return items
end

stores.OFFER_SIZE = 5
-- Stores with at most this many games check them all once a day, for an exact stock count.
stores.EXACT_STOCK = 50

-- A store's daily selection: up to OFFER_SIZE random games from its stock (the GotX store puts the
-- current picks first), saved in `state.offers`
-- so it stays put until `today` changes. Bought games just drop out of the day's selection; a game
-- whose ROM is missing (see core/roms), or that left the stock unbought (hidden by Settings), gives
-- its place to another draw, so the store stays full.
-- The missing games the draws come across are kept with the offer for the day, and left out of the
-- stock count. A small store (up to EXACT_STOCK games) has the rest of its stock checked too, so its
-- count is exact; a big one's count leaves out only the missing games its draws met.
-- Returns the offered games, whether the selection changed (so the caller can save), and how many
-- games the store has in stock.
function stores.offer(store, state, built, timeline, today, random)
  local stock = stores.stock(store, state, built, timeline)
  local byId = {}
  for _, game in ipairs(stock) do byId[game.id] = game end

  local offer = state.offers[store.id]
  local rerolled = not offer or offer.day ~= today
  local missing = {}
  for _, id in ipairs(not rerolled and offer.missing or {}) do missing[id] = true end
  local found = false
  local function present(game)
    if missing[game.id] then return false end
    if roms.present(game) then return true end
    missing[game.id], found = true, true
    return false
  end

  -- A bought game stays in the day's ids (shown no more); one that left the stock otherwise, hidden
  -- by Settings for instance, is dropped for good and another drawn instead, so a store keeps its
  -- OFFER_SIZE games but never gets more draws than if the setting had been on all day.
  local ids, wanted = {}, rerolled and stores.OFFER_SIZE or 0
  for _, id in ipairs(rerolled and {} or offer.ids) do
    local gone = byId[id] == nil and not state.owned[id]
    if gone or byId[id] and not present(byId[id]) then
      wanted = wanted + 1
    else
      table.insert(ids, id)
    end
  end
  local replaced = not rerolled and wanted > 0
  if wanted > 0 then
    local taken, pool = {}, {}
    for _, id in ipairs(ids) do taken[id] = true end
    for _, game in ipairs(stock) do
      if not taken[game.id] and not missing[game.id] then table.insert(pool, game) end
    end
    -- The GotX store's current picks come before any random ones.
    if rerolled and store.kind == "gotx" then
      for _, winner in ipairs(built.gotx.current) do
        local game = built.gotx.gameOf[winner]
        for i, candidate in ipairs(pool) do
          if wanted > 0 and game and candidate == game then
            table.remove(pool, i)
            if present(game) then
              table.insert(ids, game.id)
              wanted = wanted - 1
            end
            break
          end
        end
      end
    end
    while wanted > 0 and #pool > 0 do
      local game = table.remove(pool, random(#pool))
      if present(game) then
        table.insert(ids, game.id)
        wanted = wanted - 1
      end
    end
    if rerolled and #stock <= stores.EXACT_STOCK then
      for _, game in ipairs(pool) do present(game) end
    end
  end
  local changed = rerolled or found or replaced
  if changed then
    local missingIds = {}
    for id in pairs(missing) do table.insert(missingIds, id) end
    table.sort(missingIds)
    state.offers[store.id] = { day = today, ids = ids, missing = missingIds }
  end

  local games, inStock = {}, #stock
  for _, id in ipairs(ids) do
    if byId[id] then
      table.insert(games, byId[id])
    end
  end
  for id in pairs(missing) do
    if byId[id] then inStock = inStock - 1 end
  end
  table.sort(games, catalog.byName)
  return games, changed, inStock
end

-- Every game in today's store picks, as { game, store }, each game once (under the first store
-- that offers it). `eligible(game)` optionally filters games; `random` is only used to roll new picks.
function stores.onSale(state, built, timeline, today, random, eligible)
  local sale, seen = {}, {}
  for _, store in ipairs(stores.list(state, built, timeline, today, random)) do
    for _, game in ipairs((stores.offer(store, state, built, timeline, today, random))) do
      if not seen[game.id] and (not eligible or eligible(game)) then
        seen[game.id] = true
        table.insert(sale, { game = game, store = store })
      end
    end
  end
  return sale
end

-- Up to `count` games from today's store picks to advertise, as { game, store }: different stores
-- first, then more games from the same stores if there are fewer stores than ads. The choice depends
-- only on the day; `random` is only used to roll new picks. `eligible(game)` optionally filters games.
function stores.featured(state, built, timeline, today, count, random, eligible)
  local pickDaily = daily.random("featured " .. today)
  local order = {}
  for _, store in ipairs(stores.list(state, built, timeline, today, random)) do
    table.insert(order, pickDaily(#order + 1), store)
  end
  local featured, seen = {}, {}
  local added = true
  while #featured < count and added do
    added = false
    for _, store in ipairs(order) do
      local candidates = {}
      for _, game in ipairs((stores.offer(store, state, built, timeline, today, random))) do
        if not seen[game.id] and (not eligible or eligible(game)) then table.insert(candidates, game) end
      end
      if #featured < count and #candidates > 0 then
        local game = candidates[pickDaily(#candidates)]
        seen[game.id] = true
        table.insert(featured, { game = game, store = store })
        added = true
      end
    end
  end
  return featured
end

return stores

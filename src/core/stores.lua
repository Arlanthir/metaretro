local catalog = require("core.catalog")
local genres = require("core.genres")

-- Stores in town: one per owned console, plus a genre store for every category with enough games on
-- those consoles (a tiny genre would offer the same few games every day).
-- Store ids double as lot keys in the save: console stores use the system id, genre stores "genre:<id>".
local stores = {}

-- Games of a category, owned or not, the owned consoles need before its genre store opens.
stores.MIN_GENRE_GAMES = 30

function stores.list(state, built, timeline)
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
  return list
end

-- Games a store has for sale.
function stores.stock(store, state, built, timeline)
  if store.kind == "console" then
    return built.bySystem[store.console.id].locked
  end
  local items = {}
  for _, console in ipairs(timeline) do
    if state.ownedConsoles[console.id] then
      for _, game in ipairs(built.bySystem[console.id].locked) do
        if game.category == store.genre.id then
          table.insert(items, game)
        end
      end
    end
  end
  table.sort(items, catalog.byName)
  return items
end

stores.OFFER_SIZE = 5

-- A store's daily selection: up to OFFER_SIZE random games from its stock, saved in `state.offers`
-- so it stays put until `today` changes. Bought games just drop out of the day's selection.
-- Returns the offered games, whether a new selection was drawn (so the caller can save),
-- and how many games the store has in stock overall.
function stores.offer(store, state, built, timeline, today, random)
  local stock = stores.stock(store, state, built, timeline)
  local byId, pool = {}, {}
  for i, game in ipairs(stock) do
    byId[game.id] = game
    pool[i] = game
  end

  local offer = state.offers[store.id]
  local rerolled = not offer or offer.day ~= today
  if rerolled then
    offer = { day = today, ids = {} }
    while #offer.ids < stores.OFFER_SIZE and #pool > 0 do
      table.insert(offer.ids, table.remove(pool, random(#pool)).id)
    end
    state.offers[store.id] = offer
  end

  local games = {}
  for _, id in ipairs(offer.ids) do
    if byId[id] then
      table.insert(games, byId[id])
    end
  end
  table.sort(games, catalog.byName)
  return games, rerolled, #stock
end

return stores

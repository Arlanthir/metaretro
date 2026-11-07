local consoles = require("core.consoles")

local progression = {}

local function chronological(a, b)
  if a.generation ~= b.generation then return a.generation < b.generation end
  if a.year ~= b.year then return a.year < b.year end
  return a.name < b.name
end

-- The library's consoles, oldest generation first; non-console systems are left out.
function progression.timeline(systems)
  local timeline = {}
  for _, system in ipairs(systems) do
    local info = consoles.get(system.id)
    if info then
      table.insert(timeline, {
        id = system.id, name = system.name, short = info.short, year = info.year, generation = info.generation,
      })
    end
  end
  table.sort(timeline, chronological)
  return timeline
end

progression.GIFT_CHOICES = 3

-- The consoles on Professor Cork's table: the oldest in the library.
function progression.giftChoices(timeline)
  local choices = {}
  for i = 1, math.min(progression.GIFT_CHOICES, #timeline) do
    choices[i] = timeline[i]
  end
  return choices
end

function progression.currentGeneration(state, timeline)
  local current = 0
  for _, console in ipairs(timeline) do
    if state.ownedConsoles[console.id] then
      current = math.max(current, console.generation)
    end
  end
  return current
end

-- Unowned consoles up to the next generation present in the library, so gaps never block progress.
function progression.purchasable(state, timeline)
  local current = progression.currentGeneration(state, timeline)
  local limit = current
  for _, console in ipairs(timeline) do
    if console.generation > current then
      limit = console.generation
      break
    end
  end
  local forSale = {}
  for _, console in ipairs(timeline) do
    if not state.ownedConsoles[console.id] and console.generation <= limit then
      table.insert(forSale, console)
    end
  end
  return forSale
end

-- Owning a game implies owning its system, so older saves never lose access to their games.
function progression.syncOwnedConsoles(state, games)
  for _, game in ipairs(games) do
    if state.owned[game.id] then
      state.ownedConsoles[game.system] = true
    end
  end
end

return progression

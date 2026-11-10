-- Whether a game's ROM is still on disk. Gamelists keep entries for ROMs that were deleted; instead
-- of listing every ROM folder at startup (about a second on the device), a game is checked when it's
-- about to be handed out: offered in a store, put in an arcade cabinet, given in a starter pack, or
-- launched. Each game is checked once per run, and files don't come and go mid-run, so picks that
-- skip missing games stay the same all session.
local roms = {}

local function always() return true end
local check, known = always, {}

-- `check(game)` tells whether the game's ROM is there (the backend's hasRom); nil trusts every game.
function roms.useCheck(fn)
  check, known = fn or always, {}
end

function roms.present(game)
  local present = known[game.id]
  if present == nil then
    present = check(game) and true or false
    known[game.id] = present
  end
  return present
end

return roms

local genres = require("core.genres")

-- Games that can't be played without a peripheral the handheld lacks: a light gun, R.O.B.,
-- paddles, a steering wheel, a mat, a microphone or a mouse.
local peripherals = {}

-- Besides ScreenScraper's "Lightgun Shooter" genre, these games by system, as the start of their
-- names (lowercase letters and digits only), so regional suffixes still match.
local NAMES = {
  atari2600 = { "blackjack", "breakout", "canyonbomber", "casino", "circusatari", "demonstodiamonds", "indy500",
    "kaboom", "nightdriver", "steeplechase", "streetracer", "superbreakout", "videoolympics", "warlords" },
  colecovision = { "turbo" },
  nes = { "barkerbillstrickshooting", "danceaerobics", "duckhunt", "familyfunfitness",
    "familytrainer", "freedomforce", "gotcha", "gumshoe", "gyromite", "hogansalley", "karaokestudio",
    "mechanizedattack", "shootingrange", "shortorder", "stackup", "streetcop", "supermoguratataki",
    "superteamgames", "totheearth", "wildgunman", "worldclasstrackmeet" },
  snes = { "battleclash", "bazookablitzkrieg", "mariopaint", "marioandwario", "mariowario", "metalcombat",
    "superscope6", "xzone", "yoshissafari" },
  mastersystem = { "marksmanshooting", "shootinggallery" },
}

local function normalize(name)
  return (tostring(name or ""):lower():gsub("[^%w]", ""))
end

function peripherals.needsOne(game)
  if genres.topLevel(game.genre) == "Lightgun Shooter" then return true end
  local name = normalize(game.name)
  for _, prefix in ipairs(NAMES[game.system] or {}) do
    if name:sub(1, #prefix) == prefix then return true end
  end
  return false
end

return peripherals

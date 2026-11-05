local economy = require("core.economy")

local achievements = {}

local function earned(date)
  return type(date) == "string" and date ~= ""
end

-- Unlocks from before `since` (both "YYYY-MM-DD HH:MM:SS", UTC) pay a reduced rate.
local function rate(date, since)
  return date >= since and 1 or economy.PAST_ACHIEVEMENT_RATE
end

-- Pays for the unlocks in a RetroAchievements game progress response that haven't been paid yet.
-- Each achievement pays once for its unlock and once more for the hardcore bonus.
function achievements.credit(state, progress, since)
  local coins = 0
  for _, achievement in pairs(progress.Achievements or {}) do
    local id = tostring(achievement.ID)
    local paid = state.seenAchievements[id]
    local points = tonumber(achievement.Points) or 0
    if earned(achievement.DateEarned) and not paid then
      coins = coins + economy.achievementEarnings(points, false) * rate(achievement.DateEarned, since)
      paid = "softcore"
    end
    if earned(achievement.DateEarnedHardcore) and paid ~= "hardcore" then
      local bonus = economy.achievementEarnings(points, true) - economy.achievementEarnings(points, false)
      coins = coins + bonus * rate(achievement.DateEarnedHardcore, since)
      paid = "hardcore"
    end
    state.seenAchievements[id] = paid
  end
  coins = math.floor(coins + 0.5)
  state.wallet = state.wallet + coins
  if progress.ID then
    local gameId = tostring(progress.ID)
    state.achievementCoins[gameId] = (state.achievementCoins[gameId] or 0) + coins
  end
  return coins
end

return achievements

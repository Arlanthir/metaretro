-- Deterministic randomness keyed by text (usually today's date), so daily picks stay put all day.
local daily = {}

-- Returns random(n) -> 1..n, the same sequence every time for the same `text`.
function daily.random(text)
  local seed = 0
  for i = 1, #text do
    seed = (seed * 31 + text:byte(i)) % 2147483647
  end
  return function(n)
    seed = (seed * 48271) % 2147483647
    return seed % n + 1
  end
end

return daily

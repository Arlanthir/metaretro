-- Deterministic randomness keyed by text (usually today's date), so daily picks stay put all day.
local daily = {}

local MODULUS = 2147483647 -- 2^31 - 1, for a Park-Miller generator

-- Returns random(n) -> 1..n, the same sequence every time for the same `text`.
function daily.random(text)
  -- FNV-style hash, so texts that differ by one character (consecutive dates) start far apart.
  local seed = 2166136261 % MODULUS
  for i = 1, #text do
    seed = (seed * 16777619 + text:byte(i) * 2654435761) % MODULUS
  end
  if seed == 0 then seed = 1 end
  local function nextValue()
    seed = (seed * 48271) % MODULUS
    return seed
  end
  -- The first values still echo the seed; skip them.
  for _ = 1, 8 do nextValue() end
  return function(n)
    -- The high bits are the well-mixed ones, so scale instead of taking a remainder.
    return math.floor(nextValue() / MODULUS * n) + 1
  end
end

return daily

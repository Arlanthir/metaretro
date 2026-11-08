-- The mall's inside, laid out for however many stores are open: a corridor with a storefront door
-- (S) per store, alternating between the top and the bottom wall, and the way out (E) at the
-- bottom left. An empty row above and below holds the stores' name plaques. See
-- world/interior.lua for the legend.
local mall = {}

mall.SPACING = 4 -- tiles from one storefront to the next along a wall
mall.MIN_SLOTS = 2 -- storefronts per wall even when few stores are open, so the mall isn't a closet

local function door(index, top)
  -- The bottom wall's doors start further right, clear of the way out.
  return (top and 3 or 5) + (index - 1) * mall.SPACING
end

-- The layout ({ rooms, furniture }) for `count` stores. Store i's door is the i-th storefront in
-- reading order: the top wall's from left to right, then the bottom wall's.
function mall.layout(count)
  local topCount = math.ceil(count / 2)
  local slots = math.max(mall.MIN_SLOTS, topCount)
  local width = slots * mall.SPACING + 3
  local function row(fill, edge)
    return edge .. fill:rep(width - 2) .. edge
  end
  local top, bottom = row("#", "#"), row("#", "#")
  local function place(line, x, letter) return line:sub(1, x - 1) .. letter .. line:sub(x + 1) end
  for i = 1, topCount do top = place(top, door(i, true), "S") end
  for i = 1, count - topCount do bottom = place(bottom, door(i, false), "S") end
  bottom = place(bottom, 2, "E")
  local floor = row(".", "#")
  local outside = (" "):rep(width)
  local empty = ("."):rep(width)
  return {
    rooms = { outside, top, floor, floor, floor, bottom, outside },
    furniture = { empty, empty, empty, empty, empty, empty, empty },
  }
end

return mall

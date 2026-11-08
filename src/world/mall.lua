-- The mall's inside, laid out for however many stores are open (see world/interior.lua for the
-- legend): a corridor with a storefront door (S) per store along its top and bottom walls, and the
-- way out (E) at the bottom left. Wooden floor runs in front of the shops and a tiled aisle down the
-- middle, where each gap between two top storefronts holds an ad stand, a plant or a bench. The
-- empty rows above and below hold the stores' name plaques.
local mall = {}

mall.SPACING = 4 -- tiles from one storefront to the next along a wall
mall.MIN_SLOTS = 2 -- storefronts per wall even when few stores are open, so the mall isn't a closet
mall.MAX_ADS = 3

local function door(index, top)
  -- The bottom wall's doors start further right, clear of the way out.
  return (top and 3 or 5) + (index - 1) * mall.SPACING
end

-- The layout ({ rooms, furniture, ads }) for `count` stores. Store i's door is the i-th storefront in
-- reading order: the top wall's from left to right, then the bottom wall's. `ads` lists, for each ad
-- stand in reading order, the store whose games it advertises (the top store to its left).
function mall.layout(count)
  local topCount = math.ceil(count / 2)
  local slots = math.max(mall.MIN_SLOTS, topCount)
  local width = slots * mall.SPACING + 3
  local function row(fill, edge) return edge .. fill:rep(width - 2) .. edge end
  local function place(line, x, text) return line:sub(1, x - 1) .. text .. line:sub(x + #text) end

  local top, bottom = row("#", "#"), row("#", "#")
  for i = 1, topCount do top = place(top, door(i, true), "S") end
  for i = 1, count - topCount do bottom = place(bottom, door(i, false), "S") end
  bottom = place(bottom, 2, "E")
  local wood, aisle = row(".", "#"), "#." .. (","):rep(width - 4) .. ".#"
  local outside = (" "):rep(width)

  -- Decorations, centered in the gap after top storefront g: ads in every other gap first.
  local empty = ("."):rep(width)
  local upper, lower, middle = empty, empty, empty
  local ads = {}
  for g = 1, slots - 1 do
    local x = door(g, true) + 2
    if g % 2 == 1 and #ads < mall.MAX_ADS and g + 1 <= topCount then
      upper, lower = place(upper, x, "d"), place(lower, x, "d")
      table.insert(ads, g)
    elseif g % 2 == 0 then
      upper, lower = place(upper, x, "p"), place(lower, x, "p")
    else
      middle = place(middle, x - 1, "sss")
    end
  end
  return {
    rooms = { outside, top, wood, aisle, aisle, aisle, wood, bottom, outside },
    furniture = { empty, empty, empty, upper, lower, middle, empty, empty, empty },
    ads = ads,
  }
end

return mall

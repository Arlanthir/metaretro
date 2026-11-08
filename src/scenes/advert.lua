-- A billboard's or poster's ad up close, filling the screen: the game's box art as large as fits,
-- and which store sells it. A or B steps back.
local scenes = require("core.scenes")
local covers = require("services.covers")
local ui = require("ui")

local Advert = {}
Advert.__index = Advert

local ART = { width = ui.WIDTH - 2 * ui.MARGIN, top = 24, bottom = ui.HEIGHT - 96 }

-- `game` is on sale in `store` (one of core/stores' stores).
function Advert.new(game, store)
  return setmetatable({ game = game, store = store }, Advert)
end

function Advert:action(name)
  if name == "a" or name == "b" then scenes.pop() end
end

function Advert:draw()
  love.graphics.clear(0.05, 0.05, 0.06)
  local path = ui.boxArt(self.game)
  local image = path and covers.get(path)
  local height = ART.bottom - ART.top
  if image then
    local scale = math.min(ART.width / image:getWidth(), height / image:getHeight())
    local w, h = image:getWidth() * scale, image:getHeight() * scale
    local x, y = math.floor((ui.WIDTH - w) / 2), math.floor(ART.top + (height - h) / 2)
    love.graphics.setColor(0.27, 0.16, 0.10)
    love.graphics.rectangle("fill", x - 6, y - 6, w + 12, h + 12, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(image, x, y, 0, scale, scale)
  end
  local caption = ("%s at the %s"):format(self.game.name, self.store.title)
  ui.messagePanel(ui.truncate(ui.fonts.body, caption, ui.WIDTH - 2 * ui.MARGIN - 40), ui.WIDTH / 2, ART.bottom + 8)
  ui.hintPanel("B: back", ui.WIDTH / 2, ui.HEIGHT - 44)
end

return Advert

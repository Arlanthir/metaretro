local scenes = require("core.scenes")
local ui = require("ui")

-- A villager talking: portrait, name and text that types itself out at the bottom of the screen.
-- `accept` ({ hint, run }) is optional; without it A just closes the dialog.
local Dialog = { drawBelow = true }
Dialog.__index = Dialog

local CHARACTERS_PER_SECOND = 60
local HEIGHT = 140

local function characters(text)
  local list = {}
  for character in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    table.insert(list, character)
  end
  return list
end

function Dialog.new(name, portrait, text, accept)
  return setmetatable({ name = name, portrait = portrait, text = text, total = #characters(text), shown = 0,
    accept = accept }, Dialog)
end

function Dialog:finished()
  return self.shown >= self.total
end

function Dialog:update(dt)
  self.shown = math.min(self.total, self.shown + dt * CHARACTERS_PER_SECOND)
end

function Dialog:action(name)
  if name == "a" and not self:finished() then
    self.shown = self.total
  elseif name == "a" then
    scenes.pop()
    if self.accept then self.accept.run() end
  elseif name == "b" then
    scenes.pop()
  end
end

function Dialog:draw()
  local x, y, width = 8, ui.HEIGHT - HEIGHT - 8, ui.WIDTH - 16
  ui.panel(x, y, width, HEIGHT)
  local portraitSize = self.portrait:getWidth() * 2
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(self.portrait, x + 14, y + 14, 0, 2, 2)

  local textX = x + 14 + portraitSize + 14
  local textWidth = x + width - 16 - textX
  love.graphics.setFont(ui.fonts.body)
  ui.setColor("highlight")
  love.graphics.print(self.name, textX, y + 10)
  -- Wrapped once up front, so words don't jump to the next line while they're typed out.
  if not self.lines then
    local _, lines = ui.fonts.body:getWrap(self.text, textWidth)
    self.lines = {}
    self.total = 0
    for i, line in ipairs(lines) do
      self.lines[i] = characters(line)
      self.total = self.total + #self.lines[i]
    end
  end
  ui.setColor("text")
  local remaining = math.floor(self.shown)
  for i, line in ipairs(self.lines) do
    if remaining <= 0 then break end
    love.graphics.print(table.concat(line, "", 1, math.min(#line, remaining)), textX, y + 10 + i * ui.LINE)
    remaining = remaining - #line
  end

  if self:finished() then
    local hint = self.accept and ("A: %s   B: bye"):format(self.accept.hint) or "A: OK"
    ui.hintPanel(hint, x + width - 110, y - 22)
  end
end

return Dialog

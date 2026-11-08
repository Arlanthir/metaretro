-- Draws Metaretro's console sprites: 16x16 pixel art after the real hardware, in the Ninja Adventure
-- palette. Writes src/assets/metaretro/Consoles.png (one console per column) and
-- src/world/consolelooks.lua (system id -> column); never edit those by hand. Also draws the museum's
-- glass display case (DisplayCase.png) and the Arcade Club's cabinets, seen from the side
-- (Cabinets.png, 4 colors).
--
-- Usage, from the repository: love scripts/draw-consoles src
-- A preview with names lands in this script's LÖVE save folder (preview.png).
--
-- Home consoles sit in rows 0-10 (bottom outline on row 10). Their controller sits in rows 12-15,
-- one empty row below, joined by a single black pixel of cable on row 11 (none for wireless ones).
-- Handhelds have no controller and can use the whole tile.

local P = {
  k = "141b1b", D = "3b3643", b = "4e484a", g = "695953", w = "8e7c73", c = "abc2bc", W = "f2eaf1",
  h = "b8dce5", m = "548789", s = "2d697b", u = "79b8ce", B = "4a5270", r = "e0394c", R = "8f3e56",
  o = "d78b4a", d = "965340", t = "f1c471", y = "ffe18d", O = "ffbc75", n = "ef914f", G = "74a334",
  H = "56864c", l = "adbc3a", e = "8d977f", E = "5f7160", p = "a5608b", L = "d3a2c0", V = "543c52",
}

local sheet, column

local function px(x, y, c, alpha)
  if x >= 0 and y >= 0 and x < 16 and y < sheet:getHeight() then
    local hex = P[c]
    sheet:setPixel(column * 16 + x, y, tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
      tonumber(hex:sub(5, 6), 16) / 255, alpha or 1)
  end
end
local function rect(x1, y1, x2, y2, c, alpha) for y = y1, y2 do for x = x1, x2 do px(x, y, c, alpha) end end end
local function box(x1, y1, x2, y2, fill, line) rect(x1, y1, x2, y2, line or "k"); rect(x1 + 1, y1 + 1, x2 - 1, y2 - 1, fill) end
local function cross(x, y, c) px(x, y, c); px(x - 1, y, c); px(x + 1, y, c); px(x, y - 1, c); px(x, y + 1, c) end
-- Rounds a box's corners off (leaves them see-through).
local function round(x1, y1, x2, y2)
  for _, p in ipairs({ { x1, y1 }, { x2, y1 }, { x1, y2 }, { x2, y2 } }) do
    sheet:setPixel(column * 16 + p[1], p[2], 0, 0, 0, 0)
  end
end

-- A cartridge standing in the console's top slot.
local function cart(x1, x2, top, bottom, shell, label)
  box(x1, top, x2, bottom, shell)
  if label then rect(x1 + 1, top + 1, x2 - 1, top + 2, label) end
end

-- A controller on rows 12-15 from x, `width` wide: a d-pad (2x2) on the left and `buttons` (colors)
-- staggered on the right. `cable` is the column of the cable pixel, or false when it's wireless.
local function pad(x, width, shell, buttons, options)
  options = options or {}
  local cable = options.cable == nil and x + math.floor(width / 2) or options.cable
  if cable then px(cable, 11, "k") end
  box(x, 12, x + width - 1, 15, shell)
  if options.face then rect(x + 1, 13, x + width - 2, 14, options.face) end
  rect(x + 1, 13, x + 2, 14, options.dpad or "k")
  for i, c in ipairs(buttons or {}) do
    px(x + width - 1 - i, i % 2 == 1 and 14 or 13, c)
  end
  if options.round then round(x, 12, x + width - 1, 15) end
end

-- A joystick on rows 12-15: a base with the stick's top and a fire button.
local function joystick(x, shell, stick, button)
  px(x + 2, 11, "k")
  box(x, 12, x + 4, 15, shell)
  px(x + 2, 13, stick)
  px(x + 3, 14, button)
end

-- A keypad controller (early consoles): rows of keys, plus a disc or knob.
local function keypad(x, shell, keys, knob)
  px(x + 2, 11, "k")
  box(x, 12, x + 5, 15, shell)
  px(x + 1, 13, keys); px(x + 3, 13, keys); px(x + 1, 14, keys); px(x + 3, 14, keys)
  px(x + 4, 13, knob)
end

-- A handheld's screen: `bezel` around a `screen` color with a lighter top row.
local function screen(x1, y1, x2, y2, bezel, color, shine)
  box(x1, y1, x2, y2, color, bezel)
  if shine then rect(x1 + 1, y1 + 1, x2 - 1, y1 + 1, shine) end
end

local DRAW = {}

DRAW.generic = function()
  cart(5, 10, 1, 5, "r", "y")
  box(1, 4, 14, 10, "W"); rect(2, 5, 13, 5, "c"); rect(4, 5, 11, 6, "b"); rect(2, 9, 13, 9, "c")
  px(12, 7, "r"); rect(3, 8, 5, 8, "B")
  pad(8, 7, "B", { "r", "y" }, { dpad = "D" })
end

-- Second generation
DRAW.channelf = function()
  box(0, 3, 15, 10, "k")
  rect(2, 4, 4, 5, "b"); rect(11, 4, 13, 5, "b")           -- controllers stored at the back
  rect(6, 4, 9, 4, "y")                                     -- cartridge slot
  rect(1, 7, 14, 9, "o"); rect(1, 8, 14, 8, "d")            -- woodgrain front
  px(9, 11, "k"); box(7, 12, 11, 15, "k"); px(9, 13, "o")   -- the grip with its knob
end
DRAW.atari2600 = function()
  cart(5, 10, 0, 4, "k", "o")
  box(0, 3, 15, 10, "k")
  rect(1, 4, 14, 4, "D"); rect(1, 6, 14, 6, "D")
  px(2, 5, "c"); px(4, 5, "c"); px(11, 5, "c"); px(13, 5, "c")
  rect(1, 7, 14, 9, "o"); rect(1, 8, 14, 8, "d"); px(5, 7, "d"); px(10, 9, "d")
  joystick(9, "k", "b", "r")
end
DRAW.o2em = function()
  box(0, 2, 15, 10, "k")
  rect(1, 3, 14, 4, "c"); px(12, 3, "k")                    -- silver top, cartridge slot
  for x = 2, 13, 2 do px(x, 6, "W"); px(x, 8, "W") end      -- the keyboard
  joystick(9, "k", "b", "r")
end
DRAW.intellivision = function()
  box(0, 4, 15, 10, "d")
  rect(1, 5, 14, 6, "t")                                     -- gold top
  rect(1, 7, 14, 9, "o"); rect(1, 8, 14, 8, "d")
  px(2, 5, "k"); px(13, 5, "k")
  keypad(9, "t", "k", "d")
end
DRAW.atari5200 = function()
  box(0, 3, 15, 10, "k")
  rect(1, 4, 14, 5, "c"); rect(5, 4, 10, 4, "k")             -- silver band and the big cartridge slot
  rect(1, 7, 14, 7, "D"); rect(1, 9, 14, 9, "D")
  keypad(9, "k", "c", "r")
end
DRAW.colecovision = function()
  box(0, 4, 15, 10, "k")
  rect(1, 5, 14, 5, "c"); rect(1, 7, 14, 7, "c")            -- silver ridges
  rect(6, 4, 9, 4, "b")
  px(2, 9, "r"); px(3, 9, "y"); px(4, 9, "G"); px(5, 9, "s")  -- the striped logo
  keypad(9, "k", "c", "r")
end
DRAW.vectrex = function()
  box(3, 0, 12, 10, "k")
  rect(4, 1, 11, 8, "D")
  px(5, 6, "W"); px(6, 5, "W"); px(7, 4, "W"); px(8, 3, "W"); px(9, 4, "W"); px(10, 5, "W")  -- vector lines
  px(7, 9, "b"); px(8, 9, "b")
  px(7, 11, "k"); box(3, 12, 12, 15, "k"); px(5, 13, "b")
  px(8, 14, "c"); px(9, 13, "c"); px(10, 14, "c"); px(11, 13, "c")
end

-- Third generation
DRAW.nes = function()
  box(0, 4, 15, 10, "c")
  rect(1, 5, 14, 5, "W"); rect(1, 6, 14, 6, "c")
  rect(1, 7, 14, 9, "b"); rect(3, 7, 12, 7, "g")             -- dark front with the cartridge flap
  rect(2, 5, 4, 5, "r")
  px(2, 8, "r"); px(12, 8, "k"); px(14, 8, "k")
  pad(6, 9, "c", { "r", "r" }, { face = "b" })
end
DRAW.sg1000 = function()
  cart(5, 10, 0, 4, "k", "W")
  box(0, 3, 15, 10, "k")
  rect(1, 4, 14, 7, "W"); rect(1, 6, 14, 6, "c")
  rect(1, 9, 14, 9, "r")
  pad(8, 8, "k", { "r" }, { dpad = "b" })
end
DRAW.mastersystem = function()
  cart(4, 11, 0, 4, "b", "W")
  box(0, 4, 15, 10, "D")
  rect(1, 6, 14, 6, "r"); rect(1, 8, 14, 8, "r")
  rect(1, 9, 14, 9, "k"); px(13, 5, "r")
  pad(7, 9, "D", { "W", "W" }, { dpad = "b" })
end
DRAW.fds = function()
  box(1, 0, 14, 5, "W"); rect(2, 4, 13, 4, "R"); px(12, 1, "r")  -- the Famicom on top
  box(0, 5, 15, 10, "r"); rect(3, 7, 12, 7, "k"); rect(4, 8, 11, 8, "y")  -- disk drive with a disk going in
  pad(7, 8, "R", { "t", "t" }, { dpad = "k" })
end
DRAW.atari7800 = function()
  box(0, 3, 15, 10, "k")
  rect(1, 4, 14, 5, "c"); rect(5, 3, 10, 3, "k")
  rect(1, 7, 14, 7, "n"); rect(1, 8, 14, 8, "r")
  joystick(9, "k", "b", "r")
end

-- Fourth generation
DRAW.pcengine = function()
  box(2, 3, 13, 10, "W")
  rect(3, 5, 12, 5, "c"); rect(3, 7, 12, 7, "c")
  px(3, 4, "r"); px(4, 4, "r")
  rect(6, 8, 9, 9, "y"); rect(6, 9, 9, 9, "o")               -- HuCard
  pad(8, 7, "W", { "k", "k" }, { dpad = "b" })
end
DRAW.pcenginecd = function()
  box(0, 3, 15, 10, "W")
  rect(2, 4, 9, 9, "c"); rect(3, 5, 8, 8, "h"); round(2, 4, 9, 9)  -- the CD lid
  box(10, 4, 14, 8, "W"); rect(11, 6, 13, 6, "c")              -- the PC Engine docked beside it
  pad(8, 7, "W", { "k", "k" }, { dpad = "b" })
end
DRAW.supergrafx = function()
  box(0, 3, 15, 10, "c")
  rect(1, 4, 14, 6, "b"); rect(2, 5, 13, 5, "D")
  rect(6, 8, 9, 9, "y")
  px(13, 8, "r")
  pad(8, 7, "c", { "k", "k" }, { dpad = "b" })
end
DRAW.megadrive = function()
  cart(5, 10, 0, 5, "b", "W")
  box(0, 4, 15, 10, "D")
  rect(4, 5, 11, 9, "b"); rect(5, 6, 10, 8, "D"); rect(5, 5, 10, 5, "k")
  px(1, 6, "r"); px(2, 6, "W")
  px(2, 8, "r"); rect(12, 8, 14, 8, "c")
  pad(7, 9, "D", { "B", "B", "B" }, { dpad = "b" })
end
DRAW.snes = function()
  cart(4, 11, 0, 5, "c", "W")
  box(0, 4, 15, 10, "c")
  rect(1, 5, 14, 6, "W")
  px(2, 7, "b"); px(13, 7, "b")
  px(6, 8, "r"); px(7, 8, "y"); px(8, 8, "G"); px(9, 8, "s")
  pad(7, 9, "c", { "r", "y", "s", "G" }, { dpad = "b" })
end
DRAW.neogeo = function()
  cart(3, 12, 0, 4, "k", "r")
  box(0, 3, 15, 10, "k")
  rect(1, 5, 14, 5, "D"); rect(2, 7, 13, 7, "t")             -- "MAX 330 MEGA"
  px(2, 9, "c"); px(13, 9, "c")
  px(9, 11, "k"); box(7, 12, 15, 15, "k")                    -- the arcade stick
  px(8, 13, "r"); px(10, 14, "r"); px(11, 13, "y"); px(12, 14, "G"); px(13, 13, "s")
end
DRAW.segacd = function()
  box(1, 0, 14, 5, "D"); rect(5, 1, 10, 4, "b"); rect(6, 2, 9, 3, "D")  -- the Mega Drive on top
  box(0, 5, 15, 10, "D"); rect(3, 7, 12, 7, "b"); px(2, 9, "r"); px(13, 9, "s")  -- CD unit with its tray
  pad(7, 9, "D", { "B", "B", "B" }, { dpad = "b" })
end
DRAW.sega32x = function()
  box(3, 0, 12, 3, "D"); px(5, 1, "r"); px(10, 1, "n")        -- the 32X mushroom
  rect(6, 4, 9, 4, "k")
  box(0, 5, 15, 10, "D"); rect(4, 6, 11, 9, "b"); rect(5, 7, 10, 8, "D")
  px(1, 7, "r")
  pad(7, 9, "D", { "B", "B", "B" }, { dpad = "b" })
end
DRAW.neogeocd = function()
  box(0, 3, 15, 10, "k")
  rect(2, 4, 10, 9, "D"); rect(4, 5, 8, 8, "b"); round(2, 4, 10, 9)  -- top-loading lid
  px(13, 5, "t"); px(13, 7, "c")
  pad(7, 9, "k", { "r", "y", "G", "s" }, { dpad = "b" })
end
DRAW.lynx = function()
  box(0, 4, 15, 12, "D"); round(0, 4, 15, 12)
  screen(4, 5, 11, 11, "k", "m", "u")
  cross(2, 8, "b")
  px(13, 7, "c"); px(14, 9, "c")
end
DRAW.gb = function()
  box(4, 0, 11, 15, "c")
  screen(5, 1, 10, 7, "b", "e", "E")
  cross(6, 10, "k")
  px(9, 10, "R"); px(10, 9, "R")
  px(7, 13, "b"); px(8, 13, "b")
  rect(5, 14, 6, 14, "g")
end
DRAW.gamegear = function()
  box(0, 5, 15, 12, "D"); round(0, 5, 15, 12)
  rect(1, 5, 14, 5, "k")
  screen(4, 6, 11, 11, "k", "s", "u")
  cross(2, 9, "b")
  px(13, 8, "B"); px(14, 9, "B"); px(13, 10, "u")
end

-- Fifth generation
DRAW["3do"] = function()
  box(0, 3, 15, 10, "k")
  rect(1, 4, 14, 4, "D"); rect(1, 6, 14, 6, "D")
  rect(3, 8, 11, 8, "b")                                      -- front tray
  px(13, 5, "r"); px(14, 5, "G"); px(13, 6, "s")             -- the logo
  pad(7, 9, "k", { "c", "c", "c" }, { dpad = "b" })
end
DRAW.jaguar = function()
  cart(5, 10, 0, 4, "k", "r")
  box(0, 3, 15, 10, "k"); round(0, 3, 15, 10)
  rect(1, 5, 14, 5, "D"); rect(2, 7, 13, 7, "r")
  px(9, 11, "k"); box(6, 12, 15, 15, "k")                    -- big pad with a keypad
  rect(7, 13, 8, 14, "b"); px(10, 13, "c"); px(11, 14, "c"); px(12, 13, "c"); px(14, 14, "r")
end
DRAW.psx = function()
  box(0, 3, 15, 10, "c")
  rect(2, 4, 8, 9, "h"); rect(3, 5, 7, 8, "W"); round(2, 4, 8, 9)  -- round CD lid
  px(11, 5, "b"); px(13, 5, "b"); px(12, 7, "b")
  px(11, 9, "r"); px(12, 9, "y"); px(13, 9, "G"); px(14, 9, "s")
  pad(7, 9, "c", { "r", "G", "L", "s" }, { dpad = "b" })
end
DRAW.saturn = function()
  box(0, 3, 15, 10, "D")
  rect(2, 4, 11, 8, "b"); rect(3, 5, 10, 7, "k"); round(2, 4, 11, 8)  -- oval CD lid
  px(13, 5, "c"); px(13, 7, "c")
  rect(2, 9, 6, 9, "s")                                      -- blue logo
  pad(7, 9, "b", { "c", "c", "c" }, { dpad = "k" })
end
DRAW.pcfx = function()
  box(4, 0, 11, 10, "W")
  rect(5, 2, 10, 2, "b"); rect(5, 4, 10, 4, "c"); rect(5, 6, 10, 6, "c"); rect(5, 8, 10, 8, "c")
  px(10, 9, "r")
  pad(8, 7, "W", { "k", "k" }, { dpad = "b", cable = 9 })
end
DRAW.virtualboy = function()
  box(1, 1, 14, 6, "D")
  rect(3, 3, 5, 4, "r"); rect(10, 3, 12, 4, "r")             -- eyepieces
  rect(5, 7, 5, 9, "b"); rect(10, 7, 10, 9, "b"); rect(3, 10, 12, 10, "b")  -- the stand
  px(7, 11, "k"); box(3, 12, 12, 15, "b")
  rect(4, 13, 5, 14, "k"); rect(10, 13, 11, 14, "k"); px(7, 13, "r"); px(8, 14, "r")
end
DRAW.n64 = function()
  cart(4, 11, 0, 4, "b", "W")
  box(0, 3, 15, 10, "D")
  rect(2, 5, 13, 5, "b")
  px(7, 6, "r"); px(8, 6, "y"); px(7, 7, "G"); px(8, 7, "s")  -- the logo
  px(3, 9, "k"); px(6, 9, "k"); px(9, 9, "k"); px(12, 9, "k")  -- four controller ports
  pad(6, 9, "b", { "s", "G", "y" }, { dpad = "k" })
end
DRAW.gbc = function()
  box(4, 0, 11, 15, "p")
  screen(5, 1, 10, 7, "D", "u", "h")
  cross(6, 10, "V")
  px(9, 10, "V"); px(10, 9, "V")
  px(7, 13, "V"); px(8, 13, "V")
end
DRAW.ngp = function()
  box(1, 4, 14, 12, "c"); round(1, 4, 14, 12)
  screen(5, 5, 10, 11, "k", "e", "E")
  rect(2, 8, 3, 9, "b")                                      -- the clicky stick
  px(12, 8, "k"); px(13, 9, "k")
end
DRAW.ngpc = function()
  box(1, 4, 14, 12, "s"); round(1, 4, 14, 12)
  screen(5, 5, 10, 11, "k", "m", "u")
  rect(2, 8, 3, 9, "c")
  px(12, 8, "W"); px(13, 9, "W")
end
DRAW.wswan = function()
  box(0, 4, 15, 12, "c"); round(0, 4, 15, 12)
  screen(3, 5, 11, 11, "k", "e", "E")
  px(1, 7, "b"); px(1, 9, "b"); px(2, 8, "b")
  px(13, 8, "D"); px(14, 10, "D")
end
DRAW.wswanc = function()
  box(0, 4, 15, 12, "u"); round(0, 4, 15, 12)
  screen(3, 5, 11, 11, "k", "m", "h")
  px(1, 7, "B"); px(1, 9, "B"); px(2, 8, "B")
  px(13, 8, "B"); px(14, 10, "B")
end

-- Sixth generation
DRAW.dreamcast = function()
  box(0, 3, 15, 10, "W")
  rect(3, 4, 12, 8, "h"); rect(4, 5, 11, 7, "W"); round(3, 4, 12, 8)  -- big round lid
  px(7, 6, "n"); px(8, 6, "n"); px(8, 5, "n"); px(9, 6, "n")  -- the swirl
  rect(2, 9, 13, 9, "c")
  pad(7, 9, "W", { "r", "s", "y", "G" }, { dpad = "b" })
end
DRAW.ps2 = function()
  box(0, 4, 15, 10, "k")
  rect(1, 5, 14, 5, "D"); rect(1, 7, 14, 7, "D")
  rect(6, 6, 14, 6, "b")                                      -- disc tray
  px(2, 9, "s"); px(3, 9, "s")                                -- blue logo
  pad(7, 9, "D", { "r", "G", "L", "s" }, { dpad = "b" })
end
DRAW.gamecube = function()
  rect(4, 0, 11, 1, "V")                                      -- the handle
  box(3, 1, 12, 10, "p")
  rect(4, 2, 11, 6, "V"); rect(5, 3, 10, 5, "p"); round(4, 2, 11, 6)  -- disc lid
  px(7, 8, "W"); px(8, 8, "W")
  pad(7, 9, "p", { "G", "r", "y" }, { dpad = "V" })
end
DRAW.xbox = function()
  box(0, 3, 15, 10, "k")
  rect(1, 4, 14, 4, "D")
  px(6, 5, "l"); px(9, 5, "l"); px(7, 6, "G"); px(8, 6, "G"); px(6, 7, "l"); px(9, 7, "l")  -- the X jewel
  rect(2, 9, 13, 9, "D")
  pad(6, 10, "k", { "l", "r", "s", "y" }, { dpad = "D" })
end
DRAW.pokemini = function()
  box(4, 3, 11, 13, "u"); round(4, 3, 11, 13)
  screen(5, 4, 10, 8, "B", "e", "E")
  px(6, 10, "B"); px(9, 10, "r"); px(10, 11, "r")
end
DRAW.gba = function()
  box(0, 4, 15, 12, "p"); round(0, 4, 15, 12)
  rect(1, 4, 3, 4, "V"); rect(12, 4, 14, 4, "V")             -- shoulder buttons
  screen(4, 5, 11, 11, "D", "m", "u")
  cross(2, 8, "V")
  px(13, 7, "V"); px(14, 9, "V")
end

-- Seventh generation and later
DRAW.nds = function()
  box(2, 0, 13, 7, "W"); screen(3, 1, 12, 6, "c", "m", "u")   -- top screen
  box(2, 8, 13, 15, "W"); screen(5, 9, 10, 14, "c", "m", "u")  -- touch screen
  cross(3, 11, "b"); px(12, 10, "b"); px(12, 12, "b")
end
DRAW.psp = function()
  box(0, 4, 15, 11, "k"); round(0, 4, 15, 11)
  screen(3, 5, 12, 10, "k", "m", "u")
  cross(1, 7, "b")
  px(14, 6, "G"); px(14, 8, "r"); px(13, 9, "b")
end
DRAW.xbox360 = function()
  box(0, 3, 15, 10, "W")
  rect(1, 4, 2, 9, "c"); rect(13, 4, 14, 9, "c")             -- vents on the sides
  rect(4, 6, 11, 6, "c")                                      -- disc tray
  px(12, 4, "G"); px(12, 5, "l")                              -- ring of light
  pad(6, 10, "W", { "G", "r", "s", "y" }, { dpad = "b", cable = false })
end
DRAW.wii = function()
  box(1, 4, 14, 9, "W")
  rect(3, 6, 11, 6, "u")                                      -- the glowing disc slot
  px(12, 6, "c")
  box(9, 12, 15, 15, "W"); px(10, 13, "b"); px(12, 13, "c"); px(14, 14, "u")  -- the Wii Remote
end
DRAW.ps3 = function()
  box(0, 4, 15, 10, "k"); round(0, 4, 15, 10)
  rect(1, 5, 14, 6, "D"); rect(2, 8, 12, 8, "b")
  px(14, 8, "c")
  pad(6, 10, "D", { "r", "G", "L", "s" }, { dpad = "b", cable = false })
end
DRAW["3ds"] = function()
  box(2, 0, 13, 7, "B"); screen(3, 1, 12, 6, "k", "m", "u")
  box(2, 8, 13, 15, "B"); screen(5, 9, 10, 13, "k", "m", "u")
  px(3, 9, "c"); cross(3, 12, "k")
  px(12, 10, "y"); px(11, 11, "r")
end
DRAW.psvita = function()
  box(0, 4, 15, 12, "k"); round(0, 4, 15, 12)
  screen(3, 5, 12, 11, "k", "s", "u")
  px(1, 6, "b"); px(1, 10, "b"); px(14, 10, "b")             -- two sticks and a d-pad
  px(14, 6, "G"); px(13, 7, "r")
end
DRAW.wiiu = function()
  box(0, 3, 15, 9, "k")
  rect(1, 4, 14, 4, "D"); rect(3, 6, 10, 6, "s")
  box(2, 12, 13, 15, "k"); rect(4, 13, 11, 14, "m"); rect(4, 13, 11, 13, "u")  -- the GamePad
  px(3, 13, "b"); px(12, 14, "b")
end
DRAW.switch = function()
  box(0, 4, 2, 12, "u"); round(0, 4, 2, 12)                  -- left Joy-Con
  box(13, 4, 15, 12, "r"); round(13, 4, 15, 12)              -- right Joy-Con
  box(2, 4, 13, 12, "k"); screen(3, 5, 12, 11, "k", "m", "u")
  px(1, 6, "k"); px(14, 9, "k")
end

-- The museum's glass display case (16x32), drawn over a console standing in its top half: tinted
-- glass with a glint, on a wooden plinth with a little name plate.
local function displayCase()
  rect(1, 1, 14, 14, "h", 0.22)
  rect(0, 0, 15, 0, "k"); rect(0, 0, 0, 15, "k"); rect(15, 0, 15, 15, "k")
  px(3, 2, "W", 0.8); px(4, 3, "W", 0.8); px(5, 4, "W", 0.6); px(3, 4, "W", 0.6)
  rect(0, 15, 15, 15, "c")
  box(0, 16, 15, 31, "o"); rect(1, 17, 14, 17, "O"); rect(1, 19, 14, 19, "d"); rect(1, 29, 14, 29, "d")
  rect(6, 23, 9, 24, "y")
end

-- An arcade cabinet seen from its side (16x32), facing right: the marquee overhang, the recessed
-- screen, the control panel with its joystick, and the coin door. The big side panel (columns 3-9,
-- rows 3-29, see art.cabinet) is where the game's cover art goes, like real side art.
local CABINET_SHAPE = { -- rows, then the body's columns on them
  { 0, 1, 2, 12 }, { 2, 5, 2, 13 }, { 6, 13, 2, 10 }, { 14, 16, 2, 14 }, { 17, 31, 2, 12 },
}
local function cabinet(side, glow)
  local filled = {}
  for _, part in ipairs(CABINET_SHAPE) do
    for y = part[1], part[2] do
      for x = part[3], part[4] do filled[y * 16 + x] = true; px(x, y, side) end
    end
  end
  for y = 0, 31 do                                            -- outline: body pixels next to the outside
    for x = 0, 15 do
      if filled[y * 16 + x] then
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local nx, ny = x + d[1], y + d[2]
          if nx < 0 or nx > 15 or ny < 0 or ny > 31 or not filled[ny * 16 + nx] then px(x, y, "k") end
        end
      end
    end
  end
  rect(12, 2, 12, 5, "y"); rect(11, 3, 11, 4, glow)          -- the lit marquee, seen edge-on
  rect(10, 6, 10, 13, "m"); px(10, 7, "u")                    -- the screen's glow at the front
  rect(11, 14, 13, 14, "b"); px(13, 13, "r"); px(12, 13, "k") -- control panel and joystick
  rect(11, 20, 11, 27, "D"); px(11, 23, "y")                  -- coin door
  rect(3, 3, 9, 29, "D")                                      -- the side panel, under the art
end
local CABINETS = { { "r", "n" }, { "s", "u" }, { "H", "l" }, { "p", "L" } }

-- The order of the columns; the generic console is column 0.
local ORDER = {
  "generic",
  "channelf", "atari2600", "o2em", "intellivision", "atari5200", "colecovision", "vectrex",
  "nes", "sg1000", "mastersystem", "fds", "atari7800",
  "pcengine", "pcenginecd", "supergrafx", "megadrive", "snes", "neogeo", "segacd", "sega32x", "neogeocd",
  "lynx", "gb", "gamegear",
  "3do", "jaguar", "psx", "saturn", "pcfx", "virtualboy", "n64", "gbc", "ngp", "ngpc", "wswan", "wswanc",
  "dreamcast", "ps2", "gamecube", "xbox", "pokemini", "gba",
  "nds", "psp", "xbox360", "wii", "ps3", "3ds", "psvita", "wiiu", "switch",
}

local function write(path, contents)
  local file = assert(io.open(path, "wb"))
  file:write(contents)
  file:close()
end

function love.load(args)
  local ok, err = pcall(function()
    local src = assert(args[1], "usage: love scripts/draw-consoles src")
    sheet = love.image.newImageData(#ORDER * 16, 16)
    for i, id in ipairs(ORDER) do
      column = i - 1
      assert(DRAW[id], "no drawing for " .. id)(id)
    end
    write(src .. "/assets/metaretro/Consoles.png", sheet:encode("png"):getString())
    local consoles = sheet

    sheet, column = love.image.newImageData(16, 32), 0
    displayCase()
    write(src .. "/assets/metaretro/DisplayCase.png", sheet:encode("png"):getString())
    sheet = love.image.newImageData(16 * #CABINETS, 32)
    for i, colors in ipairs(CABINETS) do
      column = i - 1
      cabinet(colors[1], colors[2])
    end
    write(src .. "/assets/metaretro/Cabinets.png", sheet:encode("png"):getString())
    sheet = consoles

    local lines = { "-- Generated by scripts/draw-consoles; never edit by hand.",
      "-- Each console's column in assets/metaretro/Consoles.png (column 0 is the generic console).",
      "return {" }
    for i = 2, #ORDER do
      local id = ORDER[i]
      local key = id:match("^%a[%w_]*$") and id or ('["%s"]'):format(id)
      table.insert(lines, ("  %s = %d,"):format(key, i - 1))
    end
    table.insert(lines, "}")
    write(src .. "/world/consolelooks.lua", table.concat(lines, "\n") .. "\n")

    -- Preview: every console at 5x with its id, on the museum floor's color.
    local image = love.graphics.newImage(sheet)
    image:setFilter("nearest", "nearest")
    local perRow, scale = 9, 5
    local cellW, cellH = 16 * scale + 16, 16 * scale + 24
    local canvas = love.graphics.newCanvas(perRow * cellW + 8, math.ceil(#ORDER / perRow) * cellH + 8)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.93, 0.80, 0.55)
    for i, id in ipairs(ORDER) do
      local x, y = ((i - 1) % perRow) * cellW + 8, math.floor((i - 1) / perRow) * cellH + 4
      love.graphics.setColor(0, 0, 0)
      love.graphics.print(id, x, y)
      love.graphics.setColor(1, 1, 1)
      love.graphics.draw(image, love.graphics.newQuad((i - 1) * 16, 0, 16, 16, image:getDimensions()),
        x, y + 18, 0, scale, scale)
    end
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", "preview.png")
    print(("Drew %d consoles; preview in %s/preview.png"):format(#ORDER, love.filesystem.getSaveDirectory()))
  end)
  if not ok then print(err) end
  love.event.quit()
end

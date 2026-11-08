-- Consoles and handhelds known to the progression, keyed by ES system id.
-- Systems missing here (computers, arcade, engines) stay out of the console timeline.
local consoles = {}

-- `ra` is the console's RetroAchievements id, for consoles that have achievements. `sold` is roughly
-- how many million were sold worldwide (two models sold as one, like the Game Boy and Game Boy
-- Color, are split roughly; tiny ones are guesses), only good enough to rank consoles by popularity.
local function console(name, short, year, generation, ra, sold)
  return { name = name, short = short, year = year, generation = generation, ra = ra, sold = sold }
end

-- A handheld counts a generation below its own (`generation` is the historical one): its games can't
-- compete in complexity with those of the home consoles of its time. The Switch, a home console too,
-- counts as one.
local function handheld(name, short, year, generation, ra, sold)
  local entry = console(name, short, year, generation - 1, ra, sold)
  entry.handheld = true
  return entry
end

local KNOWN = {
  channelf = console("Fairchild Channel F", "Channel F", 1976, 2, 57, 0.25),
  atari2600 = console("Atari 2600", "Atari 2600", 1977, 2, 25, 30),
  o2em = console("Magnavox Odyssey 2", "Odyssey 2", 1978, 2, 23, 2),
  intellivision = console("Intellivision", "Intellivision", 1979, 2, 45, 3),
  atari5200 = console("Atari 5200", "Atari 5200", 1982, 2, nil, 1),
  colecovision = console("ColecoVision", "Coleco", 1982, 2, 44, 2),
  vectrex = console("Vectrex", "Vectrex", 1982, 2, 46, 0.5),
  nes = console("Nintendo Entertainment System", "NES", 1983, 3, 7, 61.9),
  sg1000 = console("Sega SG-1000", "SG-1000", 1983, 3, 33, 0.4),
  mastersystem = console("Master System", "Master System", 1985, 3, 11, 13),
  fds = console("Famicom Disk System", "Famicom Disk", 1986, 3, 81, 4.4),
  atari7800 = console("Atari 7800", "Atari 7800", 1986, 3, 51, 3.8),
  pcengine = console("PC Engine", "PC Engine", 1987, 4, 8, 10),
  pcenginecd = console("PC Engine CD", "PCE CD", 1988, 4, 76, 1.9),
  megadrive = console("Mega Drive", "Mega Drive", 1988, 4, 1, 30.8),
  gb = handheld("Game Boy", "Game Boy", 1989, 4, 4, 64),
  lynx = handheld("Atari Lynx", "Lynx", 1989, 4, 13, 3),
  supergrafx = console("SuperGrafx", "SuperGrafx", 1989, 4, 8, 0.08),
  snes = console("Super Nintendo", "SNES", 1990, 4, 3, 49.1),
  gamegear = handheld("Game Gear", "Game Gear", 1990, 4, 15, 10.6),
  neogeo = console("Neo Geo", "Neo Geo", 1990, 4, nil, 1),
  segacd = console("Sega CD", "Sega CD", 1991, 4, 9, 2.2),
  sega32x = console("Sega 32X", "32X", 1994, 4, 10, 0.8),
  neogeocd = console("Neo Geo CD", "Neo Geo CD", 1994, 4, 56, 0.57),
  ["3do"] = console("3DO", "3DO", 1993, 5, 43, 2),
  jaguar = console("Atari Jaguar", "Jaguar", 1993, 5, 17, 0.15),
  psx = console("PlayStation", "PlayStation", 1994, 5, 12, 102.5),
  saturn = console("Saturn", "Saturn", 1994, 5, 39, 9.3),
  pcfx = console("PC-FX", "PC-FX", 1994, 5, 49, 0.1),
  virtualboy = handheld("Virtual Boy", "Virtual Boy", 1995, 5, 28, 0.77),
  n64 = console("Nintendo 64", "N64", 1996, 5, 2, 32.9),
  gbc = handheld("Game Boy Color", "GB Color", 1998, 5, 6, 49),
  ngp = handheld("Neo Geo Pocket", "NGP", 1998, 5, 14, 0.5),
  ngpc = handheld("Neo Geo Pocket Color", "NGP Color", 1999, 5, 14, 1.5),
  wswan = handheld("WonderSwan", "WonderSwan", 1999, 5, 53, 2),
  wswanc = handheld("WonderSwan Color", "WS Color", 2000, 5, 53, 1.5),
  dreamcast = console("Dreamcast", "Dreamcast", 1998, 6, 40, 9.1),
  ps2 = console("PlayStation 2", "PS2", 2000, 6, 21, 155),
  gba = handheld("Game Boy Advance", "GBA", 2001, 6, 5, 81.5),
  gamecube = console("GameCube", "GameCube", 2001, 6, 16, 21.7),
  xbox = console("Xbox", "Xbox", 2001, 6, nil, 24),
  pokemini = handheld("Pokémon Mini", "Poké Mini", 2001, 6, 24, 0.5),
  nds = handheld("Nintendo DS", "DS", 2004, 7, 18, 154),
  psp = handheld("PlayStation Portable", "PSP", 2004, 7, 41, 80),
  xbox360 = console("Xbox 360", "Xbox 360", 2005, 7, nil, 84),
  wii = console("Wii", "Wii", 2006, 7, 19, 101.6),
  ps3 = console("PlayStation 3", "PS3", 2006, 7, nil, 87.4),
  ["3ds"] = handheld("Nintendo 3DS", "3DS", 2011, 8, nil, 76),
  psvita = handheld("PlayStation Vita", "PS Vita", 2011, 8, nil, 15),
  wiiu = console("Wii U", "Wii U", 2012, 8, nil, 13.6),
  switch = console("Nintendo Switch", "Switch", 2017, 8, nil, 150),
}

function consoles.get(systemId)
  return KNOWN[systemId]
end

return consoles

-- Consoles and handhelds known to the progression, keyed by ES system id.
-- Systems missing here (computers, arcade, engines) stay out of the console timeline.
local consoles = {}

local function console(name, short, year, generation)
  return { name = name, short = short, year = year, generation = generation }
end

local KNOWN = {
  channelf = console("Fairchild Channel F", "Channel F", 1976, 2),
  atari2600 = console("Atari 2600", "Atari 2600", 1977, 2),
  o2em = console("Magnavox Odyssey 2", "Odyssey 2", 1978, 2),
  intellivision = console("Intellivision", "Intellivision", 1979, 2),
  atari5200 = console("Atari 5200", "Atari 5200", 1982, 2),
  colecovision = console("ColecoVision", "Coleco", 1982, 2),
  vectrex = console("Vectrex", "Vectrex", 1982, 2),
  nes = console("Nintendo Entertainment System", "NES", 1983, 3),
  sg1000 = console("Sega SG-1000", "SG-1000", 1983, 3),
  mastersystem = console("Master System", "Master System", 1985, 3),
  fds = console("Famicom Disk System", "Famicom Disk", 1986, 3),
  atari7800 = console("Atari 7800", "Atari 7800", 1986, 3),
  pcengine = console("PC Engine", "PC Engine", 1987, 4),
  pcenginecd = console("PC Engine CD", "PCE CD", 1988, 4),
  megadrive = console("Mega Drive", "Mega Drive", 1988, 4),
  gb = console("Game Boy", "Game Boy", 1989, 4),
  lynx = console("Atari Lynx", "Lynx", 1989, 4),
  supergrafx = console("SuperGrafx", "SuperGrafx", 1989, 4),
  snes = console("Super Nintendo", "SNES", 1990, 4),
  gamegear = console("Game Gear", "Game Gear", 1990, 4),
  neogeo = console("Neo Geo", "Neo Geo", 1990, 4),
  segacd = console("Sega CD", "Sega CD", 1991, 4),
  sega32x = console("Sega 32X", "32X", 1994, 4),
  neogeocd = console("Neo Geo CD", "Neo Geo CD", 1994, 4),
  ["3do"] = console("3DO", "3DO", 1993, 5),
  jaguar = console("Atari Jaguar", "Jaguar", 1993, 5),
  psx = console("PlayStation", "PlayStation", 1994, 5),
  saturn = console("Saturn", "Saturn", 1994, 5),
  pcfx = console("PC-FX", "PC-FX", 1994, 5),
  virtualboy = console("Virtual Boy", "Virtual Boy", 1995, 5),
  n64 = console("Nintendo 64", "N64", 1996, 5),
  gbc = console("Game Boy Color", "GB Color", 1998, 5),
  ngp = console("Neo Geo Pocket", "NGP", 1998, 5),
  ngpc = console("Neo Geo Pocket Color", "NGP Color", 1999, 5),
  wswan = console("WonderSwan", "WonderSwan", 1999, 5),
  wswanc = console("WonderSwan Color", "WS Color", 2000, 5),
  dreamcast = console("Dreamcast", "Dreamcast", 1998, 6),
  ps2 = console("PlayStation 2", "PS2", 2000, 6),
  gba = console("Game Boy Advance", "GBA", 2001, 6),
  gamecube = console("GameCube", "GameCube", 2001, 6),
  xbox = console("Xbox", "Xbox", 2001, 6),
  pokemini = console("Pokémon Mini", "Poké Mini", 2001, 6),
  nds = console("Nintendo DS", "DS", 2004, 7),
  psp = console("PlayStation Portable", "PSP", 2004, 7),
  xbox360 = console("Xbox 360", "Xbox 360", 2005, 7),
  wii = console("Wii", "Wii", 2006, 7),
  ps3 = console("PlayStation 3", "PS3", 2006, 7),
  ["3ds"] = console("Nintendo 3DS", "3DS", 2011, 8),
  psvita = console("PlayStation Vita", "PS Vita", 2011, 8),
  wiiu = console("Wii U", "Wii U", 2012, 8),
  switch = console("Nintendo Switch", "Switch", 2017, 8),
}

function consoles.get(systemId)
  return KNOWN[systemId]
end

return consoles

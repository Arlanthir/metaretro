#!/bin/bash
# PortMaster launcher. Runs Metaretro, then any game it asked to launch, then Metaretro again.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi
source "$controlfolder/control.txt"
[ -f "$controlfolder/mod_${CFW_NAME}.txt" ] && source "$controlfolder/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/metaretro"
export XDG_DATA_HOME="$GAMEDIR/conf"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
SAVEDIR="$XDG_DATA_HOME/love/metaretro"
mkdir -p "$SAVEDIR"
cd "$GAMEDIR" || exit 1
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# PortMaster's bundled LÖVE runtime; sets $LOVE_RUN, $LOVE_BINARY and $LOVE_GPTK.
source "$controlfolder/runtimes/love_11.5/love.txt"
$GPTOKEYB "$LOVE_GPTK" &

while true; do
  pm_platform_helper "$LOVE_BINARY"
  # TEMP: starter pack limited to GBA while testing launches; remove once launching is verified.
  $LOVE_RUN "$GAMEDIR/metaretro.love" --layout nintendo --starter-systems gba
  [ -f "$SAVEDIR/launch.txt" ] || break

  game_id=$(sed -n 1p "$SAVEDIR/launch.txt")
  game_cmd=$(sed -n 2p "$SAVEDIR/launch.txt")
  rm -f "$SAVEDIR/launch.txt"

  start=$(date +%s)
  sh -c "$game_cmd"
  printf '%s\t%s\t%s\n' "$game_id" "$start" "$(date +%s)" >> "$SAVEDIR/sessions.log"
done

pm_finish

#!/bin/bash
# PortMaster launcher for Retro Town Story. Runs the game, then any game it asked to launch, then the
# game again. Its files live in ports/metaretro/ (the name it had before; saves are kept there).

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

# Shows the port in EmulationStation with its name and art (gameinfo.xml), through ES's web API on
# this device. PortMaster does this when it installs a port; this covers copying the files over by
# hand. Once per gameinfo.xml.
es_post() {
  curl -s -m 5 -o /dev/null -w "%{http_code}" -H "Content-Type: application/xml" --data-binary "$2" \
    "http://127.0.0.1:1234/$1/ports" 2>/dev/null || echo "failed"
}
registered="$XDG_DATA_HOME/gameinfo.registered"
if [ -f "$GAMEDIR/gameinfo.xml" ] && ! cmp -s "$GAMEDIR/gameinfo.xml" "$registered"; then
  status=$(es_post addgames "@$GAMEDIR/gameinfo.xml")
  echo "[metaretro.sh] registering with EmulationStation: $status"
  case "$status" in 200|201) cp "$GAMEDIR/gameinfo.xml" "$registered" ;; esac
fi

# PortMaster's bundled LÖVE runtime; sets $LOVE_RUN, $LOVE_BINARY and $LOVE_GPTK.
source "$controlfolder/runtimes/love_11.5/love.txt"

while true; do
  # gptokeyb only while Metaretro runs, so its quit combo can't fire during a game.
  $GPTOKEYB "$LOVE_GPTK" &
  gptokeyb_pid=$!
  pm_platform_helper "$LOVE_BINARY"
  $LOVE_RUN "$GAMEDIR/metaretro.love" --layout nintendo
  echo "[metaretro.sh] metaretro exited with status $?"
  kill "$gptokeyb_pid" 2>/dev/null
  [ -f "$SAVEDIR/launch.txt" ] || break

  game_id=$(sed -n 1p "$SAVEDIR/launch.txt")
  game_cmd=$(sed -n 2p "$SAVEDIR/launch.txt")
  rm -f "$SAVEDIR/launch.txt"

  start=$(date +%s)
  sh -c "$game_cmd"
  echo "[metaretro.sh] game exited with status $?"
  printf '%s\t%s\t%s\n' "$game_id" "$start" "$(date +%s)" >> "$SAVEDIR/sessions.log"
done

pm_finish

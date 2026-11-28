#!/bin/bash
# PORTMASTER: pockimusi.zip, Pockimusi.sh

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

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/pockimusi"

cd $GAMEDIR
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

source $controlfolder/runtimes/"love_11.5"/love.txt

# Keep saves in the port folder: conf/love/pockimusi/session_a.txt and
# session_b.txt (set here, after PortMaster has used XDG_DATA_HOME to find itself)
export XDG_DATA_HOME="$GAMEDIR/conf"
mkdir -p "$XDG_DATA_HOME"

# The app used to be PocketGroove in ports/pocketgroove: on the first launch,
# bring its saves along (the game then copies them to the new save folder)
OLDDIR="/$directory/ports/pocketgroove/conf/love/pocketgroove"
if [ -d "$OLDDIR" ] && [ ! -d "$XDG_DATA_HOME/love/pockimusi" ] && [ ! -d "$XDG_DATA_HOME/love/pocketgroove" ]; then
  mkdir -p "$XDG_DATA_HOME/love"
  cp -r "$OLDDIR" "$XDG_DATA_HOME/love/pocketgroove"
fi

$GPTOKEYB "$LOVE_GPTK" -c "$GAMEDIR/controls.gptk" &
pm_platform_helper "$LOVE_BINARY"

$LOVE_RUN "$GAMEDIR/Pockimusi.love"

pm_finish

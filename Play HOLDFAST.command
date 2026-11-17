#!/bin/bash
# Start the playable demo directly, without Godot's embedded editor/debug controls.
set -e
holdfast_root="$(cd -- "$(dirname -- "$0")" && pwd)"
holdfast_engine='/Applications/Godot.app/Contents/MacOS/Godot'
if [ ! -x "$holdfast_engine" ]; then
  echo 'Godot was not found in Applications. Install Godot.app there, then try again.'
  read -r -p 'Press Return to close. ' holdfast_reply
  exit 1
fi
if [ ! -f "$holdfast_root/holdfast/project.godot" ]; then
  echo 'Keep this launcher beside the holdfast project folder.'
  read -r -p 'Press Return to close. ' holdfast_reply
  exit 1
fi
exec "$holdfast_engine" --path "$holdfast_root/holdfast" --rendering-method gl_compatibility --rendering-driver opengl3

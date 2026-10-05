#!/usr/bin/env bash
set -euo pipefail

base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validation_dir="${base}/dist/validation"
home="/tmp/atlasos-062-dock-smoke-home"
launcher="/tmp/atlasos-062-dock-smoke-ui"
mkdir -p "${validation_dir}" "${home}/Documents"
cp "${base}/config/includes.chroot/usr/local/bin/atlasos-ui" "${launcher}"
cp "${base}/config/includes.chroot/usr/local/bin/atlasos_diagnostics.py" "${launcher%/*}/atlasos_diagnostics.py"
trap 'rm -f "${launcher}" "${launcher%/*}/atlasos_diagnostics.py"' EXIT
sed -i 's/openTool(view)$/openTool(view, True)/' "${launcher}"
export HOME="${home}" QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
export ATLASOS_UI_PATH="${base}/config/includes.chroot/usr/local/share/atlasos/ui/Main.qml"
export ATLASOS_LESSON_DATA="${base}/config/includes.chroot/usr/local/share/atlasos/ui/data/lessons.json"

capture() {
  local size="$1" scenario="$2" mode="${3:-screen}" display_mode="${4:-}" tag=""
  if [[ -n "${display_mode}" ]]; then tag="-${display_mode}"; fi
  if [[ "${mode}" == "window" ]]; then tag="${tag}-window"; fi
  local name="${scenario}${tag}-${size}"
  if [[ "${size}" == "1366x768" ]]; then
    export ATLASOS_SCREENSHOT="${validation_dir}/atlasos-062-dock-${name}.png"
  else
    export ATLASOS_SCREENSHOT="${validation_dir}/atlasos-062-dock-${name}-screen.png"
  fi
  export ATLASOS_WINDOW_SIZE="${size}" ATLASOS_VALIDATE_DOCK=1
  export ATLASOS_VALIDATE_DOCK_SCENARIO="${scenario}" ATLASOS_VALIDATE_DOCK_CAPTURE="${mode}"
  if [[ -n "${display_mode}" ]]; then export ATLASOS_VALIDATE_DISPLAY_MODE="${display_mode}"; else unset ATLASOS_VALIDATE_DISPLAY_MODE; fi
  echo "Dock scenario ${scenario} at ${size}"
  xvfb-run -a -s "-screen 0 ${size}x24" python3 "${launcher}"
}

# Full-screen captures at the priority laptop geometry: no app, one, two, three,
# grouped app windows, minimized app, and unknown icon fallback.
for scenario in empty single two three grouped minimized unknown; do
  capture 1366x768 "${scenario}" screen
done

# Geometry/responsiveness and board-mode screenshots at the other target sizes.
capture 1920x1080 three screen
capture 1366x768 three screen board
capture 1280x720 three screen

# A dedicated tight-window capture confirms that the dock's own QWindow is capsule-sized.
capture 1366x768 three window

# Render the Atlas context menu with a grouped application to inspect its layout.
export ATLASOS_VALIDATE_DOCK_CONTEXT_MENU=1
capture 1366x768 context screen
unset ATLASOS_VALIDATE_DOCK_CONTEXT_MENU

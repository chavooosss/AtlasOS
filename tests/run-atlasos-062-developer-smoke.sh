#!/usr/bin/env bash
set -euo pipefail

base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home="/tmp/atlasos-062-developer-home"
launcher="/tmp/atlasos-062-developer-ui"
size="${1:-1366x768}"
mkdir -p "${home}/Documents" "${base}/dist/validation"
cp "${base}/config/includes.chroot/usr/local/bin/atlasos-ui" "${launcher}"
cp "${base}/config/includes.chroot/usr/local/bin/atlasos_diagnostics.py" "${launcher%/*}/atlasos_diagnostics.py"
trap 'rm -f "${launcher}" "${launcher%/*}/atlasos_diagnostics.py"' EXIT
sed -i 's/openTool(view)$/openTool(view, True)/' "${launcher}"
export HOME="${home}" QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software
export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
export ATLASOS_UI_PATH="${base}/config/includes.chroot/usr/local/share/atlasos/ui/Main.qml"
export ATLASOS_LESSON_DATA="${base}/config/includes.chroot/usr/local/share/atlasos/ui/data/lessons.json"
export ATLASOS_WINDOW_SIZE="${size}"
export ATLASOS_SCREENSHOT="${base}/dist/validation/atlasos-062-developer-center-${size}.png"
export ATLASOS_VALIDATE_VIEW=settings
export ATLASOS_VALIDATE_SETTINGS_SECTION="${ATLASOS_VALIDATE_SETTINGS_SECTION:-developer}"

xvfb-run -a -s "-screen 0 ${size}x24" python3 "${launcher}"
test -s "${ATLASOS_SCREENSHOT}"
echo "Developer Center QML smoke passed: ${ATLASOS_SCREENSHOT}"

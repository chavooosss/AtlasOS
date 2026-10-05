#!/bin/sh
# Project-local live-build dispatch shim.
# Keep the system dispatcher responsible for normal commands. Only the
# Ubuntu-specific binary_syslinux stage uses the locally patched helper.
set -eu

case "${1-}" in
  binary_syslinux)
    shift
    : "${ATLASOS_LOCAL_LIVE_BUILD_HELPER:?local live-build helper is not configured}"
    [ -x "$ATLASOS_LOCAL_LIVE_BUILD_HELPER" ] || {
      echo "AtlasOS local live-build helper is missing or not executable: $ATLASOS_LOCAL_LIVE_BUILD_HELPER" >&2
      exit 127
    }
    exec "$ATLASOS_LOCAL_LIVE_BUILD_HELPER" "$@"
    ;;
  *)
    # Never set LIVE_BUILD on the generic /usr/bin/lb wrapper. Its own
    # initialization must load the standard function library in its process.
    unset LIVE_BUILD
    exec /usr/bin/lb "$@"
    ;;
esac

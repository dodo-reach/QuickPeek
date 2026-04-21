#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"

APP_NAME="QuickPeek"
BUNDLE_ID="com.dodo-reach.QuickPeek"
PROJECT_PATH="QuickPeek.xcodeproj"
SCHEME="QuickPeek"
CONFIGURATION="Debug"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

configure_developer_dir() {
  if /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    return
  fi

  local candidates=(
    "/Applications/Xcode.app/Contents/Developer"
    "/Applications/Xcode-beta.app/Contents/Developer"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      export DEVELOPER_DIR="$candidate"
      return
    fi
  done

  cat >&2 <<'EOF'
Xcode is required to build QuickPeek.
Install Xcode and either:
  1. open it once, then run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
  2. or set `DEVELOPER_DIR` to a valid Xcode.app/Contents/Developer path
EOF
  exit 1
}

kill_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
}

open_app() {
  /usr/bin/open -na "$APP_BUNDLE" || "$APP_EXECUTABLE" >/dev/null 2>&1 &
}

configure_developer_dir
kill_app
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

APP_NAME="QuickPeek"
PROJECT_PATH="QuickPeek.xcodeproj"
SCHEME="QuickPeek"
CONFIGURATION="Release"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/build/release"
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-macOS.zip"

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

  echo "Xcode is required to package QuickPeek." >&2
  exit 1
}

configure_developer_dir

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

/usr/bin/xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Expected app bundle missing at $APP_BUNDLE" >&2
  exit 1
fi

# Strip Finder/APFS metadata so the public zip does not contain `._*` files.
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_BUNDLE" "$ZIP_PATH"

echo "Packaged $ZIP_PATH"

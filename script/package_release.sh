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

  echo "Xcode is required to package QuickPeek." >&2
  exit 1
}

configure_developer_dir
cd "$ROOT_DIR"

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
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ENABLE_CODE_COVERAGE=NO \
  ENABLE_HARDENED_RUNTIME=YES \
  build

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Expected app bundle missing at $APP_BUNDLE" >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_BUNDLE/Contents/Info.plist")
ZIP_PATH="$DIST_DIR/$APP_NAME-v$VERSION-macOS.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ARCHITECTURES=$(/usr/bin/lipo -archs "$APP_EXECUTABLE")
for architecture in arm64 x86_64; do
  if [[ " $ARCHITECTURES " != *" $architecture "* ]]; then
    echo "Expected $architecture in release executable, found: $ARCHITECTURES" >&2
    exit 1
  fi
done

# Strip Finder/APFS metadata so the public zip does not contain `._*` files.
/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/ditto -c -k --keepParent --norsrc --noextattr --noqtn --noacl "$APP_BUNDLE" "$ZIP_PATH"
/usr/bin/unzip -tq "$ZIP_PATH"

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "Packaged QuickPeek $VERSION ($BUILD_NUMBER)"
echo "  App:      $APP_BUNDLE"
echo "  Archive:  $ZIP_PATH"
echo "  Checksum: $CHECKSUM_PATH"
echo "  Archs:    $ARCHITECTURES"
echo "  Signing:  ad hoc (not notarized)"

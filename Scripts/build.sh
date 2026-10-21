#!/bin/zsh
set -eu
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
swift build -c release --product NZBRelay
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/Build/NZBPort.app"
mkdir -p "$PROJECT_DIR/Build"
ICON_BUILD_DIR="$(mktemp -d "$PROJECT_DIR/Build/IconAssets.XXXXXX")"
trap 'rm -r "$ICON_BUILD_DIR"' EXIT
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/NZBRelay" "$APP_DIR/Contents/MacOS/NZBRelay"
xcrun strip -S "$APP_DIR/Contents/MacOS/NZBRelay"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
if [[ -n "${NZBPORT_BUNDLE_ID:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $NZBPORT_BUNDLE_ID" "$APP_DIR/Contents/Info.plist"
fi
swift "$PROJECT_DIR/Scripts/RenderBrand.swift" "$PROJECT_DIR/Resources"
cp "$PROJECT_DIR/Resources/BrandMark.png" "$APP_DIR/Contents/Resources/BrandMark.png"
RESOURCE_BUNDLE="NZBRelay_RelayCore.bundle"
if [[ -d "$APP_DIR/Contents/Resources/$RESOURCE_BUNDLE" ]]; then
    rm -r "$APP_DIR/Contents/Resources/$RESOURCE_BUNDLE"
fi
cp -R "$BIN_DIR/$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/$RESOURCE_BUNDLE"
xcrun actool "$PROJECT_DIR/Resources/NZBPort.icon" \
    --compile "$ICON_BUILD_DIR" --platform macosx \
    --minimum-deployment-target 26.0 --app-icon NZBPort \
    --output-partial-info-plist "$ICON_BUILD_DIR/IconInfo.plist" \
    --output-format human-readable-text
cp "$ICON_BUILD_DIR/Assets.car" "$ICON_BUILD_DIR/NZBPort.icns" "$APP_DIR/Contents/Resources/"
/usr/libexec/PlistBuddy -c 'Merge '"$ICON_BUILD_DIR/IconInfo.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
plutil -lint "$APP_DIR/Contents/Info.plist"
printf '%s\n' "$APP_DIR"

#!/bin/bash
#
# Builds a signed and notarized AgentOffice.dmg for GitHub Releases.
#
#   scripts/release.sh
#
# Needs, once per Mac:
#   - A "Developer ID Application" certificate in the login keychain
#   - Notary credentials saved in the keychain:
#       xcrun notarytool store-credentials agentoffice-notary --apple-id <Apple ID> --team-id <Team ID>
#
# No password is read from this script or the repository. notarytool reads the
# credentials from the keychain profile, whose name can be changed with NOTARY_PROFILE.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="AgentOffice.xcodeproj"
SCHEME="AgentOfficeMac"
APP_NAME="AgentOffice"
NOTARY_PROFILE="${NOTARY_PROFILE:-agentoffice-notary}"
BUILD_DIR="build/release"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit 1; }

setting() {
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | awk -v key="$1" '$1 == key { print $3; exit }'
}

step "Checking the setup"
[ -z "$(git status --porcelain)" ] || fail "Commit or stash your changes first, so the build matches a commit."
VERSION="$(setting MARKETING_VERSION)"
TEAM_ID="$(setting DEVELOPMENT_TEAM)"
[ -n "$VERSION" ] && [ -n "$TEAM_ID" ] || fail "Could not read the version or team from the project."
security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($TEAM_ID)" \
  || fail "No Developer ID Application certificate for team $TEAM_ID in the keychain."
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || fail "No notary credentials named $NOTARY_PROFILE. See the top of this script."
echo "Version $VERSION, team $TEAM_ID, commit $(git rev-parse --short HEAD)"

ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
STAGING="$BUILD_DIR/dmg"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

step "Archiving"
xcodebuild archive \
  -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -quiet

step "Exporting with Developer ID"
cat > "$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -quiet
APP="$EXPORT_DIR/$APP_NAME.app"
[ -d "$APP" ] || APP="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.app' | head -1)"
[ -d "$APP" ] || fail "The export did not produce an app."
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -q "Authority=Developer ID Application" || fail "The app is not signed with Developer ID."

step "Making the disk image"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' -v team="($TEAM_ID)" '/Developer ID Application/ && index($2, team) { print $2; exit }')"
codesign --sign "$IDENTITY" --timestamp "$DMG"

step "Notarizing (this usually takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

step "Checking what Gatekeeper sees"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

step "Done"
echo "$DMG"
shasum -a 256 "$DMG"

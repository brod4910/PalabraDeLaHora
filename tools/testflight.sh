#!/usr/bin/env bash
# Builds, signs and uploads Palabra to TestFlight from the command line, using an App Store
# Connect API key instead of the Apple ID signed into Xcode (whose cached team state can block
# "iOS App Store" profiles). Run it on your Mac, from the repo root:
#
#   export ASC_KEY_ID=ABC123DEF4             # App Store Connect → Users and Access → Integrations
#   export ASC_ISSUER_ID=69a6de7e-...        #   → App Store Connect API → Team Keys
#   export ASC_KEY_PATH=~/Downloads/AuthKey_ABC123DEF4.p8   # the .p8 you downloaded (keep it private)
#   tools/testflight.sh
#
# What it does: picks a new build number (date + time), bundles the recorded voice if you have one,
# archives the app (Release), lets Xcode create the distribution certificate and App Store profiles
# with the API key, and uploads the build to App Store Connect. It ends up under TestFlight after
# Apple's processing (10–30 min). The key is passed to xcodebuild only; it's never printed or saved.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?Set ASC_KEY_ID (the Key ID of the API key)}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (shown above the keys list in App Store Connect)}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
KEY_PATH="${KEY_PATH/#\~/$HOME}"
[[ -f "$KEY_PATH" ]] || { echo "API key file not found: $KEY_PATH (set ASC_KEY_PATH)"; exit 1; }

TEAM=$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]\{10\}' PalabraDeLaHora.xcodeproj/project.pbxproj | awk '{print $3}' || true)
[[ -n "$TEAM" ]] || { echo "No team in the project: python3 tools/gen_xcodeproj.py --team YOURTEAMID"; exit 1; }
BUILD=$(date +%Y%m%d%H%M)
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
mkdir -p build
LOG=build/testflight.log
: > "$LOG"

if [[ -d tools/.cache/audio/${PALABRA_VOICE:-Paloma} ]]; then
  echo "▸ Bundling the recorded voice (${PALABRA_VOICE:-Paloma})"
  python3 tools/generate_audio.py --export --voice "${PALABRA_VOICE:-Paloma}" | tail -1
fi

fail() {
  echo
  echo "✗ $1 failed. The errors (full log: $LOG):"
  grep -E "error:|Error Domain|requires a provisioning|agreement|not have permission|No profiles|No signing" "$LOG" \
    | sed 's/^/   /' | sort -u | head -20
  exit 1
}

echo "▸ Archiving (team $TEAM, build $BUILD) — a few minutes"
rm -rf build/PalabraDeLaHora.xcarchive
xcodebuild -project PalabraDeLaHora.xcodeproj -scheme PalabraDeLaHora -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/PalabraDeLaHora.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD" DEVELOPMENT_TEAM="$TEAM" "${AUTH[@]}" archive >>"$LOG" 2>&1 || fail "Archive"

# Xcode 15.3+ calls the method app-store-connect; older versions app-store.
XCODE_MAJOR=$(xcodebuild -version | awk 'NR==1{split($2,v,"."); print v[1]*100+v[2]}')
METHOD=$([[ $XCODE_MAJOR -ge 1503 ]] && echo app-store-connect || echo app-store)
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$METHOD</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$TEAM</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "▸ Signing and uploading to App Store Connect"
rm -rf build/export
xcodebuild -exportArchive -archivePath build/PalabraDeLaHora.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export "${AUTH[@]}" >>"$LOG" 2>&1 || fail "Upload"

echo "✓ Uploaded build $BUILD. It appears under TestFlight in App Store Connect after processing (10–30 min)."

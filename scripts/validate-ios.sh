#!/usr/bin/env bash
# Run on macOS with Xcode installed, from the repository root:
# bash scripts/validate-ios.sh
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Xcode validation requires macOS. No iOS build was run." >&2
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install/select Xcode first." >&2
  exit 2
fi
cd "$(dirname "$0")/.."

echo "Xcode version:"
xcodebuild -version
echo "Running native ARAM selection, filtering and lifecycle tests..."
swift test --parallel

echo "Checking the LeagueDex project and available schemes..."
xcodebuild -list -project LeagueDex.xcodeproj

echo "Resolving Swift Package dependencies..."
xcodebuild -resolvePackageDependencies -project LeagueDex.xcodeproj -scheme LeagueDex

for configuration in Debug Release; do
  echo "Building LeagueDex for iOS Simulator: $configuration"
  xcodebuild \
    -project LeagueDex.xcodeproj \
    -scheme LeagueDex \
    -configuration "$configuration" \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
done

echo "Both simulator builds succeeded. Device UI/accessibility tests still need manual execution."

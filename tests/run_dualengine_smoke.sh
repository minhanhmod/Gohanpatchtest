#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT
swiftc -swift-version 5 -parse-as-library \
  ThreeOneOSFive/helpers/GHPatchEngineCoordinator.swift \
  ThreeOneOSFive/helpers/GHAirLiftProvider.swift \
  tests/../ThreeOneOSFive/helpers/GHInstalledPatchEngine.swift \
  tests/DualEngineWiringTests.swift -o "$TMPDIR_TEST/wiring"
"$TMPDIR_TEST/wiring"
swiftc -swift-version 5 ThreeOneOSFive/helpers/GHLocalDevReadiness.swift \
  tests/IOS27ReadinessTests.swift -o "$TMPDIR_TEST/readiness"
swiftc -swift-version 5 ThreeOneOSFive/helpers/GHLocalDevReadiness.swift \
  tests/FinalGateVerify.swift -o "$TMPDIR_TEST/final-gate"
"$TMPDIR_TEST/final-gate"
"$TMPDIR_TEST/readiness"
swiftc -swift-version 5 ThreeOneOSFive/helpers/GHLocalDevReadiness.swift \
  tests/FinalGateVerify.swift -o "$TMPDIR_TEST/final-gate"
"$TMPDIR_TEST/final-gate"
swiftc -swift-version 5 ThreeOneOSFive/helpers/SupportPolicy.swift \
  tests/SupportPolicyVerify.swift -o "$TMPDIR_TEST/policy"
"$TMPDIR_TEST/policy"
# Syntax only: full iOS type check and IPA build require macOS + Xcode.
find ThreeOneOSFive -type f -name '*.swift' -print0 | while IFS= read -r -d '' file; do
  swiftc -frontend -parse "$file"
done
# Verify the new Swift source is actually in the Xcode build phase.
python3 tests/check_localdev_probe_wiring.py
plutil -lint ThreeOneOSFive.xcodeproj/project.pbxproj
echo 'PASS: smoke tests, all Swift syntax, Xcode project plist'

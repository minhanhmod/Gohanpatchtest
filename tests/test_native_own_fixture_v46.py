from pathlib import Path
r=Path(__file__).resolve().parents[1]
bridge=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.m').read_text()
header=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.h').read_text()
swift=(r/'ThreeOneOSFive/helpers/GHV46NativeWriteReadiness.swift').read_text()
view=(r/'ThreeOneOSFive/ContentView.swift').read_text()
pbx=(r/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'al_exploit_write_dir' in bridge and 'al_exploit_write_dir' in (r/'Frameworks/AirliftFFI.xcframework/ios-arm64/Headers/airlift.h').read_text()
assert 'GHRunNativeOwnFixtureWrite' in header and 'GHRunNativeOwnFixtureWrite' in swift
assert 'GHV46NativeFixtures' in bridge and 'GHV46NativeFixtures' in swift
assert 'initWithUUIDString' in bridge and 'gh_check_own_fixture_root(root)' in bridge
assert 'staged.count == 1' in bridge and 'gh_v46_fixture.dat' in bridge
assert 'nativeSession.sessionValid(for: vault)' in swift and 'v45.allSandboxChecksPassed' in swift
assert 'self.restoreVerified' in swift and 'backupBytes.write' in swift
assert 'settingsNativeOwnWriteSection' in view and 'nativeOwnWrite.safeReport' in view
assert 'GHV46NativeWriteReadiness.swift in Sources' in pbx
assert 'GHNativeOwnFixtureBridge.m in Sources' in pbx
assert 'GHNativeOwnFixtureBridge.h' in (r/'ThreeOneOSFive/ThreeOneOSFive-Bridging-Header.h').read_text()
assert 'GHV46NativeWriteAssessment.swift in Sources' in pbx
assert 'NO_THIRD_PARTY_WRITE' in swift
print('PASS v4.6 native fixture static wiring and guard checks')

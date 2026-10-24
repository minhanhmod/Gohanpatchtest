from pathlib import Path
r=Path(__file__).resolve().parents[1]
h=(r/'ThreeOneOSFive/helpers/GHNativePairingBridge.h').read_text()
m=(r/'ThreeOneOSFive/helpers/GHNativePairingBridge.m').read_text()
s=(r/'ThreeOneOSFive/helpers/GHNativePairingSession.swift').read_text()
u=(r/'ThreeOneOSFive/ContentView.swift').read_text()
p=(r/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
v=(r/'ThreeOneOSFive/helpers/GHPairingVault.swift').read_text()
assert 'GHRunNativeOwnContainerReadProbe' in h and 'al_find_app_container' in m
assert 'currentAppBundleID isEqualToString:selfBundle' in m
assert 'native isEqualToString:home' in m
assert 'contentsOfDirectoryAtPath:home' in m
assert 'al_exploit_write_dir' not in m and 'al_exploit_run' not in m
assert 'GHSessionAssessment.passed' in s
assert 'sessionPassed && verifiedCredentialRevision == vault.credentialRevision' in s
assert 'credentialRevision = UUID()' in v
assert 'GHSessionAssessment.swift in Sources' in p
assert 'testOwnContainerReadOnly(vault: pairingVault)' in u
assert 'AIRLIFT_PATCH_DRIVER_MISSING' in u
assert 'V44_READ_ONLY_PREREQUISITES_OK_PATCH_DRIVER_MISSING' in u
assert 'V3.3 legacy TCP comparison only' in u
print('test_native_session_v44: PASS')

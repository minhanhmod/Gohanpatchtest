from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = (root / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'AirliftFFI.xcframework in Frameworks' in p
assert 'GHNativeFFIProbe.m in Sources' in p
assert 'GHNativeFFIReadiness.swift in Sources' in p
assert 'GHPairingVault.swift in Sources' in p
assert 'HEADER_SEARCH_PATHS' in p
assert 'NSLocalNetworkUsageDescription' in (root/'ThreeOneOSFive/Info.plist').read_text()
c = (root/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'settingsNativeFFISection' in c and '.fileImporter(' in c
assert 'NATIVE_FFI_CALL_OK_ONLY' in (root/'ThreeOneOSFive/helpers/GHNativeFFIReadiness.swift').read_text()
# Never register an AirLift writer just because a static lib links
provider = (root/'ThreeOneOSFive/helpers/GHAirLiftProvider.swift').read_text()
assert 'driverFactory' in provider
assert 'driverFactory =' not in provider
wrapper = (root/'ThreeOneOSFive/helpers/GHNativeFFIProbe.m').read_text()
assert 'al_set_target_host' in wrapper
assert 'al_exploit_' not in wrapper
print('PASS: safe native link integration v4')

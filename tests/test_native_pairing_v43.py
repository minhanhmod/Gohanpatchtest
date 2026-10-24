from pathlib import Path
import plistlib
r=Path(__file__).resolve().parents[1]
pbx=(r/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
assert 'GHNativePairingBridge.m in Sources' in pbx
assert 'GHNativePairingSession.swift in Sources' in pbx
assert '#import "helpers/GHNativePairingBridge.h"' in (r/'ThreeOneOSFive/ThreeOneOSFive-Bridging-Header.h').read_text()
assert '_remotepairing-pairable-host._tcp' in plistlib.load((r/'ThreeOneOSFive/Info.plist').open('rb'))['NSBonjourServices']
objc=(r/'ThreeOneOSFive/helpers/GHNativePairingBridge.m').read_text()
assert 'al_pairing_run_host' in objc and 'al_syslog_stream_start' in objc
assert 'al_exploit_write_dir' not in objc and 'al_exploit_inject_folder' not in objc
assert 'al_pairing_result_free' in objc and 'al_syslog_stream_stop' in objc
swift=(r/'ThreeOneOSFive/helpers/GHNativePairingSession.swift').read_text()
assert 'GHRunNativeReadOnlySessionProbe' in swift
assert 'presentedPIN' in swift
assert 'NATIVE_SYSLOG_EVENT_RECEIVED_NO_CONTENT' in swift
assert 'NATIVE_PAIRING_RETURNED_SUCCESS_RECORD_STORED' in swift
assert 'GHNativePairingSession' in (r/'ThreeOneOSFive/ContentView.swift').read_text()
assert 'GHAirLiftProvider.driverFactory != nil' in (r/'ThreeOneOSFive/helpers/GHInstalledPatchEngine.swift').read_text()
print('native_pairing_v43_static_checks: PASS')

from pathlib import Path
base = Path(__file__).resolve().parents[1]
bridge = (base / 'ThreeOneOSFive/helpers/GHNativePairingBridge.m').read_text()
header = (base / 'ThreeOneOSFive/helpers/GHNativePairingBridge.h').read_text()
fixture = (base / 'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.m').read_text()
swift = (base / 'ThreeOneOSFive/helpers/GHNativePairingSession.swift').read_text()
ui = (base / 'ThreeOneOSFive/ContentView.swift').read_text()
assert 'GHApplyAppNewRouteHints' in bridge and 'al_set_target_hosts' in bridge
assert 'GHSetAppNewRouteMode' in header and 'al_clear_target_hosts()' in bridge
assert 'int32_t routeRC = GHApplyAppNewRouteHints();' in fixture
assert 'AL_ERROR_HOST_ROUTING_FAILED' in fixture
assert 'gh_session_redacted_error' in bridge
assert 'finished(NO, -2, @\"AL_SESSION_ALREADY_RUNNING\")' in bridge
assert 'finalBlock(NO, -3, @\"AL_SESSION_ALLOCATION_FAILED\")' in bridge
assert 'finalBlock(observed, rc, errorClass)' in bridge
assert 'Session native error class (redacted)' in swift
assert 'GHAppNewRouteTrialEnabled' in ui
assert 'GHSetAppNewRouteMode(appNewRouteTrialEnabled)' in ui
assert 'AIRLIFT_PATCH_DRIVER_MISSING' in ui
assert 'nativeOwnWriteAcknowledged' in ui and 'v46NativePreconditionsReady' in ui
assert 'return airtrafficSuccess || true' not in bridge
assert 'generateLocalPairingFile' not in bridge
print('PASS: AppNew route trial wiring, session error redaction, and native write safety gates')

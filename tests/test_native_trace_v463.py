from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.m').read_text()
h=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.h').read_text()
s=(r/'ThreeOneOSFive/helpers/GHV46NativeWriteReadiness.swift').read_text()
assert 'gh_redacted_native_trace, &trace, &nativeError' in m
assert 'pthread_mutex_lock' in m
assert 'AL_TRACE_NO_LOG_CALLBACKS' in m
assert 'AL_TRACE_HINT_DEVICE_SERVICE' in m
assert 'nativeTraceHint' in h and 'nativeTraceHint' in s
assert 'Native trace hint (redacted):' in s
assert 'completion(rc == 0, rc, errorClass, traceSummary)' in m
assert 'al_exploit_write_dir(pairing.UTF8String' in m
assert 'gh_check_own_fixture_root(root)' in m
assert 'NO_THIRD_PARTY_WRITE' in s
assert 'NSLog(' not in m and 'printf(' not in m
print('PASS v4.6.3 redacted native stage trace wiring')

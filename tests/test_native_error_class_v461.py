from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.m').read_text()
h=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.h').read_text()
s=(r/'ThreeOneOSFive/helpers/GHV46NativeWriteReadiness.swift').read_text()
assert 'nativeErrorCategory' in h and 'nativeErrorCategory' in s
assert 'gh_native_error_class(nativeError, rc)' in m
assert m.index('gh_native_error_class(nativeError, rc)') < m.index('al_string_free(nativeError)')
assert 'completion(rc == 0, rc, errorClass, traceSummary)' in m
assert 'AL_ERROR_PAIRING_OR_AUTH' in m and 'AL_ERROR_TUNNEL_OR_NETWORK' in m
assert 'AL_ERROR_PERMISSION_OR_TARGET' in m and 'AL_ERROR_UNCLASSIFIED' in m
assert 'GHRunNativeOwnFixtureWrite(pairingPath, root.path) { [self] accepted, rc, errorCategory, traceHint in' in s
assert 'Native error class (redacted):' in s
assert 'AL_ERROR_NOT_PROVIDED' in m
# Only a fixed class crosses the bridge, never a native error string.
assert 'completion(rc == 0, rc, nativeError)' not in m
print('PASS v4.6.1 redacted native error categorization wiring')

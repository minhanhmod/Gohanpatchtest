from pathlib import Path
r=Path(__file__).resolve().parents[1]
bridge=(r/'ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.m').read_text()
swift=(r/'ThreeOneOSFive/helpers/GHV46NativeWriteReadiness.swift').read_text()
# The source SHA check happens before the native call, never on third-party files.
assert 'stagingSHA256Verified = Self.sha(try Data(contentsOf: stageFile)) == replacementDigest' in swift
assert swift.index('stagingSHA256Verified =') < swift.index('GHRunNativeOwnFixtureWrite(pairingPath, root.path)')
assert 'Local staging SHA256 verified:' in swift
# The former generic token "file" (including e.g. FileService) must not diagnose a broken source path.
assert '@"file"' not in bridge
assert 'AL_ERROR_DEVICE_SERVICE' in bridge
assert 'AL_ERROR_NATIVE_SOURCE_REFERENCE' in bridge
assert 'AL_ERROR_NATIVE_TARGET_REFERENCE' in bridge
assert 'AL_ERROR_NATIVE_PATH_UNRESOLVED' in bridge
assert 'AL_ERROR_INVALID_NATIVE_ARGUMENT' in bridge
assert bridge.index('AL_ERROR_DEVICE_SERVICE') < bridge.index('AL_ERROR_NATIVE_SOURCE_REFERENCE')
assert 'gh_native_error_class(nativeError, rc)' in bridge
assert bridge.index('gh_native_error_class(nativeError, rc)') < bridge.index('al_string_free(nativeError)')
assert 'NO_THIRD_PARTY_WRITE' in swift
print('PASS v4.6.2 local staging SHA and refined allowlisted FFI errors')

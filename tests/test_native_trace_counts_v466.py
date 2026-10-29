from pathlib import Path
root = Path(__file__).resolve().parents[1]
bridge = (root / "ThreeOneOSFive/helpers/GHNativeOwnFixtureBridge.m").read_text()
swift = (root / "ThreeOneOSFive/helpers/GHV46NativeWriteReadiness.swift").read_text()
workflow = (root / ".github/workflows/build-goohan-ipa.yml").read_text()
# The callback must never retain raw trace lines or emit them to analytics.
assert 'gh_redacted_native_trace, &trace, &nativeError' in bridge
assert 'uint32_t categories[6]' in bridge
assert 'uint32_t transitions' in bridge
assert 'trace->categories[hint]++' in bridge
assert 'gh_trace_category(first)' in bridge and 'gh_trace_category(last)' in bridge
assert 'AL_TRACE_COUNTS_AUTH_' in bridge
assert 'AL_TRACE_EVENTS_%u' in bridge and 'AL_TRACE_TRANSITIONS_%u' in bridge
assert 'trace->events < 9999' in bridge
assert 'gh_native_error_class(nativeError, rc)' in bridge
assert 'NSLog(' not in bridge and 'printf(' not in bridge
assert 'GHRunNativeOwnFixtureWrite(pairingPath, root.path)' in swift
assert 'nativeTraceBreakdown' in swift and 'nativePhase' in swift
assert 'Native phase:' in swift and 'Native call duration ms:' in swift
assert 'self.restoreVerified' in swift and 'v45.allSandboxChecksPassed' in swift
assert 'test_native_trace_counts_v466.py' in workflow
assert 'NO_THIRD_PARTY_WRITE' in swift
print('PASS v4.6.6 bounded redacted trace counters, phase, restore safety, workflow')

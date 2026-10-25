from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
view = (root / 'ThreeOneOSFive/ContentView.swift').read_text()
sandbox = (root / 'ThreeOneOSFive/helpers/GHOwnSandboxTransactionReadiness.swift').read_text()
native = (root / 'ThreeOneOSFive/helpers/GHV46NativeWriteReadiness.swift').read_text()
workflow = (root / '.github/workflows/build-goohan-ipa.yml').read_text()

def block_between(first: str, second: str) -> str:
    assert first in view and second in view
    return view.split(first,1)[1].split(second,1)[0]

v45 = block_between('private var settingsTransactionSection:', 'private var settingsNativeOwnWriteSection:')
v46 = block_between('private var settingsNativeOwnWriteSection:', 'private var settingsBeta5ComparisonSection:')
foundation_gate = block_between('private var v45SandboxPreconditionsReady:', 'private var v46NativePreconditionsReady:')
native_gate = block_between('private var v46NativePreconditionsReady:', 'private var v46NativeBlockerText:')

assert v45.count('ownSandboxTransaction.run(') == 3
assert v45.count('.disabled(!v45SandboxPreconditionsReady || ownSandboxTransaction.isRunning)') == 3
# IMPORTANT: Foundation own-sandbox test must be independent of native pairing/session.
assert 'sessionValid(for:' not in foundation_gate
assert 'ownContainerCode' not in foundation_gate
assert 'nativeOwnWrite.isRunning' in foundation_gate
assert 'os.majorVersion == 27' in foundation_gate
assert 'al_exploit_' not in sandbox
assert 'GHV45OwnSandboxFixtures' in sandbox
# Native write must retain the strict session + own-container + rollback prerequisites.
assert 'pairingSession.sessionValid(for: pairingVault)' in native_gate
assert 'NATIVE_OWN_CONTAINER_READ_ONLY_OK' in native_gate
assert '!v46NativePreconditionsReady' in v46
assert '!ownSandboxTransaction.allSandboxChecksPassed' in v46
assert 'nativeOwnWriteAcknowledged' in v46
assert 'nativeSession.sessionValid(for: vault)' in native
assert 'v45.allSandboxChecksPassed' in native
assert 'AIRLIFT_PATCH_DRIVER_MISSING' in native
assert 'test_independent_sandbox_gate_v464.py' in workflow
print('PASS: v4.6.4 sandbox test independent, AirLift native still gated')

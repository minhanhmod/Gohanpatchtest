from pathlib import Path
r = Path(__file__).resolve().parents[1]
core = (r/'ThreeOneOSFive/helpers/GHOwnSandboxTransactionCore.swift').read_text()
wrapper = (r/'ThreeOneOSFive/helpers/GHOwnSandboxTransactionReadiness.swift').read_text()
ui = (r/'ThreeOneOSFive/ContentView.swift').read_text()
project = (r/'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
workflow = (r/'.github/workflows/build-goohan-ipa.yml').read_text()
assert 'FOUNDATION_ATOMIC_WRITE_NOT_AIRLIFT' in core
assert 'GooHan' not in core or 'test' in core.lower()
assert 'al_exploit_' not in core and 'al_exploit_' not in wrapper
assert 'UIDocumentPicker' not in core and 'ContainerStore' not in core
assert 'REFUSED_EXISTING_TEST_DIRECTORY' in core
assert 'GHV45OwnSandboxFixtures' in wrapper
assert 'SHA256.hash(data:' in wrapper
assert '.afterVerifiedBackup' in wrapper and '.afterReplacementWrite' in wrapper
assert 'v45SandboxPreconditionsReady' in ui
assert 'ownSandboxTransaction.safeReport' in ui
assert ui.count('settingsTransactionSection') == 2
for name in ('GHOwnSandboxTransactionCore.swift', 'GHOwnSandboxTransactionReadiness.swift'):
    assert f'{name} in Sources' in project
    assert f'{name} */ = {{isa = PBXFileReference' in project
assert 'GHOwnSandboxTransactionCoreTests.swift' in workflow
assert 'test_own_sandbox_v45.py' in workflow
print('test_own_sandbox_v45: PASS')

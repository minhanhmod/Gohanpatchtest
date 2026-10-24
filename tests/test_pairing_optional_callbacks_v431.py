"""Reject known optional Objective-C callback regressions before Xcode build."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "ThreeOneOSFive/helpers/GHNativePairingSession.swift").read_text()
assert "GHStartNativeOnDevicePairing" in source
assert "guard let id = id, !id.isEmpty, let txt = txt" in source
assert "guard let pin = pin, !pin.isEmpty" in source
assert 'nativeResultPath: nativePath ?? ""' in source
assert "nonisolated func netServiceDidPublish" in source
assert "nonisolated func netService(_ sender: NetService, didNotPublish" in source
assert "NATIVE_PIN_CALLBACK_INVALID" in source
assert "BONJOUR_INVALID_NATIVE_CALLBACK" in source
print("pairing_optional_callbacks_v431: PASS")

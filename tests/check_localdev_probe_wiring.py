from pathlib import Path
project = Path("ThreeOneOSFive.xcodeproj/project.pbxproj").read_text()
helper = Path("ThreeOneOSFive/helpers/GHLocalDevProbe.swift").read_text()
content = Path("ThreeOneOSFive/ContentView.swift").read_text()
plist = Path("ThreeOneOSFive/Info.plist").read_text()
assert "GHLocalDevProbe.swift in Sources" in project
assert "GHLocalDevProbe.swift */ = {isa = PBXFileReference" in project
assert "@StateObject private var localDevProbe" in content
assert "localDevProbe.check()" in content
assert "LocalDev TCP probe:" in content
assert "NSLocalNetworkUsageDescription" in plist
assert "LOCAL_TCP_PORT_REACHABLE_ONLY" in helper
assert "LOCAL_TCP_PORT_NOT_DETECTED" in helper
assert "AirliftFFI" not in helper
print("PASS: iOS27 TCP diagnostic wiring, no native write provider claimed")

assert "10.7.0.3" in helper and "49152" in helper
assert "GHFinalTestGate" in Path("ThreeOneOSFive/helpers/GHLocalDevReadiness.swift").read_text()
assert "3105: pairing báo Sẵn sàng" in content
assert "finalGate.report" in content

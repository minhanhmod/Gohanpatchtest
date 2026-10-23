"""Regression check for AirliftFFI duplicate Clang module (Xcode 16.4).

Xcode copies the headers and module.modulemap of a linked static XCFramework
into its build Products/include search path automatically. Including the same
XCFramework source Headers directory in HEADER_SEARCH_PATHS produces two module
maps with `module AirliftFFI` and prevents Swift bridging header compilation.
"""
from pathlib import Path
import re
import plistlib

root = Path(__file__).resolve().parents[1]
project = (root / 'ThreeOneOSFive.xcodeproj/project.pbxproj').read_text()
modulemap_path = root / 'Frameworks/AirliftFFI.xcframework/ios-arm64/Headers/module.modulemap'
assert modulemap_path.exists()
assert modulemap_path.read_text().count('module AirliftFFI') == 1
assert project.count('AirliftFFI.xcframework in Frameworks') >= 2
assert 'Frameworks/AirliftFFI.xcframework/ios-arm64/Headers' not in project, (
    'Do not add explicit HEADER_SEARCH_PATHS for Xcode-managed AirliftFFI.xcframework'
)
# No other ad-hoc Swift/Clang flags should load this same module map again.
assert not re.search(r'-fmodule-map-file[^\n]*AirliftFFI', project)
assert not re.search(r'-I[^\n]*AirliftFFI.xcframework/ios-arm64/Headers', project)
probe = (root / 'ThreeOneOSFive/helpers/GHNativeFFIProbe.m').read_text()
assert '#import <airlift.h>' in probe
with (root/'Frameworks/AirliftFFI.xcframework/Info.plist').open('rb') as handle:
    info = plistlib.load(handle)
assert any(x.get('HeadersPath') == 'Headers' for x in info['AvailableLibraries'])
print('PASS: one Xcode-managed module search path for AirliftFFI (v4.2)')

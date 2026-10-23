from pathlib import Path
from zipfile import ZipFile
import hashlib
import subprocess
root = Path(__file__).resolve().parents[1]
base = root / 'Frameworks/AirliftFFI.xcframework/ios-arm64'
a = base / 'libairlift_ffi.a.zip'
assert a.is_file() and a.stat().st_size < 25*1024*1024
with ZipFile(a) as z:
    assert z.namelist() == ['libairlift_ffi.a']
    info = z.getinfo('libairlift_ffi.a')
    assert info.file_size == 66673680
    assert hashlib.sha256(z.read('libairlift_ffi.a')).hexdigest() == 'a239572c8018c3965fc4b23e008f0874dd35e34dd5b9f70149f4a154abf72a0f'
for workflow in ['build-goohan-ipa.yml', 'objective-c-xcode.yml']:
    content = (root / '.github/workflows' / workflow).read_text()
    assert 'run: python3 scripts/restore_airlift.py' in content
    assert content.index('run: python3 scripts/restore_airlift.py') < content.index('xcodebuild')
print('PASS: GitHub web compatible compressed AirLift archive and build steps')

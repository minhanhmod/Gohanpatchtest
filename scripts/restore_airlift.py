#!/usr/bin/env python3
"""Restore the vendored AirLift arm64 static archive before Xcode tests/build.

The repository stores libairlift_ffi.a.zip (15 MB), rather than the original
66 MB .a which cannot be uploaded through GitHub's web UI. This script does
not download network content, use external credentials, or invoke AirLift.
"""
from pathlib import Path
import hashlib
import sys
import tempfile
import os
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'Frameworks/AirliftFFI.xcframework/ios-arm64/libairlift_ffi.a'
ARCHIVE = LIB.with_name(LIB.name + '.zip')
EXPECTED_SHA256 = 'a239572c8018c3965fc4b23e008f0874dd35e34dd5b9f70149f4a154abf72a0f'
EXPECTED_SIZE = 66673680


def valid(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size != EXPECTED_SIZE:
        return False
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest() == EXPECTED_SHA256


def main() -> int:
    if valid(LIB):
        print(f'PASS: AirLift native library verified: {EXPECTED_SHA256}')
        return 0
    if not ARCHIVE.is_file():
        print(f'ERROR: Missing compressed library: {ARCHIVE.relative_to(ROOT)}', file=sys.stderr)
        return 1
    if ARCHIVE.stat().st_size > 25 * 1024 * 1024:
        print('ERROR: Compressed library unexpectedly large', file=sys.stderr)
        return 1
    try:
        with zipfile.ZipFile(ARCHIVE) as zipf:
            infos = zipf.infolist()
            if len(infos) != 1 or infos[0].filename != LIB.name or infos[0].file_size != EXPECTED_SIZE:
                raise ValueError('archive layout or uncompressed size mismatch')
            LIB.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=LIB.parent, prefix='.airlift-', delete=False) as tmp:
                tmp_file = Path(tmp.name)
                with zipf.open(infos[0]) as src:
                    while True:
                        block = src.read(1024 * 1024)
                        if not block:
                            break
                        tmp.write(block)
        if not valid(tmp_file):
            raise ValueError('uncompressed library SHA256 mismatch')
        os.replace(tmp_file, LIB)
        print(f'PASS: Restored AirLift library ({EXPECTED_SIZE} bytes), SHA256={EXPECTED_SHA256}')
        return 0
    except Exception as exc:
        print(f'ERROR: AirLift library restore failed: {exc}', file=sys.stderr)
        return 1
    finally:
        if 'tmp_file' in locals():
            tmp_file.unlink(missing_ok=True)


if __name__ == '__main__':
    sys.exit(main())

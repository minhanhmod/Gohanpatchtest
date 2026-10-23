# AirliftFFI provenance and safety

- Source: the user-provided `proxyapp-main.zip`, path `proxyapp-main/AppNew/Frameworks/AirliftFFI.xcframework`.
- ARM64 static lib size: 66,673,680 bytes.
- SHA-256: `a239572c8018c3965fc4b23e008f0874dd35e34dd5b9f70149f4a154abf72a0f`.
- C API header included unchanged from user archive.
- No matching Rust source code exists in the provided archive. Audit provenance and binary before distributing.
- Swift bridge only calls `al_set_target_host` and `al_clear_target_hosts` as a harmless FFI-link test. It does **not** call AirTraffic sandbox-escape or filesystem write functions.
- No pairing handshake implementation or authorization claim. Pairing file import is opt-in and local only.
- The original GooHan dual-engine writer remains unavailable on unverified iOS 27 builds.
- License review necessary: GooHan/3105 code appears under GPL-3.0, AirCard Rust library provenance and dependencies must be reviewed.

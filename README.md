# GooHan Patch Native v5.4 – Server-side License

Source includes modified components originally based on YangJiiii/3105 (GPL-3.0); see LICENSE and CREDITS_AND_LICENSE.md.

- Native iOS client: ThreeOneOSFive
- Backend & Web Admin: server/main.py
- Tests: tests/
- GitHub Actions IPA build: .github/workflows/build-goohan-ipa.yml

Security: server-side activation, expiry, revocation, per-device limits and authenticated patch distribution. No client-only key comparison. Session and activation key stored in iOS Keychain. Offline access to new patch packages is disabled. Local restore of prior patch state remains available after license expiry.

No IPA can be made impossible to reverse-engineer. Licensing limits online services, not what a fully modified local client can display. App Attest, if added in future, requires compatible Apple entitlements and valid provisioning.


**GitHub web upload (v4.1):** Xem `README_WEB_UPLOAD_V4_1_VI.md`. Thư viện AirLift được nén `.a.zip` và Actions giải nén tự động.


## AirLift v4.6.6 (experimental)
See [README_IOS27_NATIVE_TRACE_V4_6_6_VI.md](README_IOS27_NATIVE_TRACE_V4_6_6_VI.md). This version collects bounded redacted callback stage counts for an own-app disposable test fixture. It does **not** enable third-party patch writes or fix the AirLift `rc=1` failure.

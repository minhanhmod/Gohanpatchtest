# Apple Feedback Assistant — Developer Compatibility Investigation (Draft)

**Report category:** Developer tools / iOS app behavior investigation (the current evidence does not establish an Apple OS defect).

## Summary

A third-party iOS app-data patch manager (`GooHan Patch`) behaves differently from another build (`3105 2.1 Beta 5`) when attempting the same *user-authorized* operation. The primary observed failures are pre-write application-container discovery on iOS 18.6, and an application-side OS-build compatibility guard on iOS 27.0. We are requesting guidance on *supported, documented APIs* for user-authorized file access and on collecting appropriate iOS diagnostics. We are not asserting that Apple has an OS defect based solely on this comparison.

## Observations (from end-user reports, not independently reproduced here)

| System | Build | GooHan outcome | Comparison |
| --- | --- | --- | --- |
| iOS 18.6.0 | 22G86 | `DevicePatchService` selected; preflight cannot resolve target container; no write attempted | Same-device 3105 result not verified |
| iOS 27.0 | 24A435 | app-side `SupportPolicy` rejects before engine runs | User reports 3105 Beta 5 operation succeeds without manual pair-file import |
| iOS 27.0 | 24A437 | app-side `SupportPolicy` rejects before engine runs | User reports 3105 Beta 5 operation succeeds without manual pair-file import |

## Binary comparison (static inspection; no exploitation performed)

| Property | 3105 2.1 Beta 5 IPA | GooHan v5.3 IPA |
| --- | --- | --- |
| Bundle ID | `com.apple.mobile.MobileHouseArrest` | `com.apple.mobile.MobileHouseArrest` |
| App version | 2.1 (12) | 5.3 (8) |
| SDK | iphoneos26.2 | iphoneos18.5 |
| Binary markers | `AirLiftPatchTransaction`, `AirLiftPatchWriteDescriptor`, `CoreDevice FileService`, `RPPairing` | `DevicePatchService`, MHA-C2; AirLift markers not found |

IPA SHA-256:
- 3105 2.1 Beta 5: `363127d73d091c97a2d40aa6d77b0daee90351d963e92cedcd9881c693660552`
- GooHan v5.3: `8e9b1b817f9af895aac6618d7f4c4813128fa4f047af8fd06148c07aa93a21e6`

Note: an SDK or binary string difference **does not** establish causality or a permissions vulnerability. The private AirLift implementation is not present in the GooHan repository.

## Non-invasive reproduction and data collection (test devices only)

1. Record the exact device model, iOS version/build, app bundle version, signing method and installed-app status (omit device IDs from this report unless securely requested by Apple).
2. Start GooHan with a fresh app session. Open the built-in diagnostic report.
3. On iOS 18.6 observe the prewrite result and record whether app-session access status is `Not attempted`, `OK` or `FAILED`. **Do not proceed to changes when preflight fails.**
4. On the two iOS 27 builds, observe that GooHan rejects the build *before* contacting the patch engine.
5. Capture console/sysdiagnose using Apple's documented process, redact tokens, pairing records, paths and user data, and submit via a private official channel.

## Expected behavior / questions to Apple

- For a third-party app distributed outside the App Store, is there a documented, authorized route to obtain access to **its own** files or user-selected documents on these builds?
- Which supported CoreDevice/Files APIs can an app developer use without relying on private entitlement tricks or sandbox bypasses?
- Which diagnostic categories are most useful when file access is denied by the OS?

## Limitations / next steps

- No cross-app access PoC is included or claimed here.
- The GooHan iOS 27 guard is a third-party application decision and by itself is **not** an Apple bug.
- To submit as a security vulnerability, separately demonstrate a permission-boundary violation in a controlled environment and report only through Apple Security Research, privately.

Report using: https://feedbackassistant.apple.com/ or the Apple Feedback Assistant app.

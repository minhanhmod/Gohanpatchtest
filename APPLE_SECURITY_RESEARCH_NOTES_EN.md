# Apple Security Research — Private Evidence Checklist

**Only use this route if you independently confirm that an Apple security boundary can be crossed without authorization.** The existing GooHan logs do **not** establish that condition. Reports about GooHan rejecting a build or using a missing adapter are application bugs, not Apple security vulnerabilities.

Record privately:

- Test device and exact iOS build, test account and controlled target application.
- The security boundary you believe was crossed; what data/control became reachable; expected permission decision.
- Reliable reproduction, observable proof without personal data, and whether the device was already paired or otherwise trusted.
- Prerequisites: provisioning/signing, Developer Mode, passcode, iOS settings; whether pairing happened automatically.
- Impact and cleanup/restore confirmation. Include relevant error codes and sanitized logs.

Never attach or publish pairing records, cert private keys, game/user data, raw container paths, passwords, or exploit payloads in public GitHub issues or open chats. Use the private Apple portal, and let Apple request sensitive artifacts through secure intake.

Submit: https://security.apple.com/ and consult https://security.apple.com/bounty/guidelines/.

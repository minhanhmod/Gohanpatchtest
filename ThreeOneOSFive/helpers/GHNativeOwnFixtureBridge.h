#import <Foundation/Foundation.h>
#import <stdint.h>
// v4.6 isolated test: invokes native AirLift ONLY for a freshly created fixture
// inside this app's own Application Support/GHV46NativeFixtures/<UUID>/target.
// No arbitrary bundle ID, file path or third-party write is accepted.
// Return code 0 does NOT prove the file was updated; Swift verifies the digest.
typedef void (^GHOwnFixtureWriteFinishedBlock)(BOOL nativeAccepted,
                                                int32_t nativeReturnCode);
FOUNDATION_EXPORT void GHRunNativeOwnFixtureWrite(NSString *pairingPath,
                                                   NSString *fixtureRoot,
                                                   GHOwnFixtureWriteFinishedBlock finished);

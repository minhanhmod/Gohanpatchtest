#import <Foundation/Foundation.h>
#include <stdint.h>

// All callbacks are delivered on the main queue. No pairing record contents,
// device identifiers, target paths, or native error text enter diagnostic logs.
typedef void (^GHPairReadyBlock)(NSString *serviceID, uint16_t port, NSDictionary<NSString *, NSData *> *txt);
typedef void (^GHPairPINBlock)(NSString *pin);
typedef void (^GHPairFinishedBlock)(BOOL nativeSuccess, NSString *localResultPath, int32_t nativeReturnCode);
typedef void (^GHSessionFinishedBlock)(BOOL querySucceeded, int32_t nativeReturnCode);

FOUNDATION_EXPORT void GHStartNativeOnDevicePairing(NSString *outputPath,
                                                      GHPairReadyBlock ready,
                                                      GHPairPINBlock pin,
                                                      GHPairFinishedBlock finished);
// Run a short authenticated syslog stream probe without retaining/logging ANY lines.
// A stream callback is evidence of a reachable service, not file write access.
// Failure can mean no tunnel, invalid pairing, no service, or an iOS restriction.
FOUNDATION_EXPORT void GHRunNativeReadOnlySessionProbe(NSString *pairingPath,
                                                         GHSessionFinishedBlock finished);

// Native FileService lookup limited to the CURRENT application's own bundle ID.
// Caller must already have a passing read-only session probe. Only booleans
// and native return codes leave the bridge, never paths or raw credentials.
typedef void (^GHOwnContainerFinishedBlock)(BOOL resolvedToOwnSandbox,
                                              BOOL directoryReadSucceeded,
                                              int32_t nativeReturnCode);
FOUNDATION_EXPORT void GHRunNativeOwnContainerReadProbe(NSString *pairingPath,
                                                         NSString *currentAppBundleID,
                                                         GHOwnContainerFinishedBlock finished);

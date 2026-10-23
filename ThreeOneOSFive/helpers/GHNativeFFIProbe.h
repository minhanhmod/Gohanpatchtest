#import <Foundation/Foundation.h>
#include <stdint.h>
// This API checks that the embedded AirLift native library links and can be called.
// It does not pair, enumerate containers, or perform any privileged write.
FOUNDATION_EXPORT int32_t GHNativeLibrarySmokeTest(void);

#import "GHNativeFFIProbe.h"
#import <airlift.h>
int32_t GHNativeLibrarySmokeTest(void) {
    // Only a local host-routing configuration smoke test. NOT an AirLift connection.
    int32_t status = al_set_target_host("10.7.0.1");
    al_clear_target_hosts();
    return status;
}

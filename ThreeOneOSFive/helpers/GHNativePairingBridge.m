#import "GHNativePairingBridge.h"
#import <airlift.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>

@interface GHPairCallbackContext : NSObject
@property (nonatomic, copy) GHPairReadyBlock ready;
@property (nonatomic, copy) GHPairPINBlock pin;
@end
@implementation GHPairCallbackContext
@end

static void gh_pair_host_ready(void *ctx, const char *serviceID, uint16_t port,
                               const char *const *keys, const char *const *vals, size_t count) {
    if (ctx == NULL || serviceID == NULL) { return; }
    GHPairCallbackContext *context = (__bridge GHPairCallbackContext *)ctx;
    NSString *service = [NSString stringWithUTF8String:serviceID];
    if (service.length == 0 || port == 0) { return; }
    NSMutableDictionary<NSString *, NSData *> *txt = [NSMutableDictionary dictionary];
    if (keys && vals && count <= 64) {
        for (size_t i = 0; i < count; i++) {
            if (!keys[i] || !vals[i]) { continue; }
            NSString *key = [NSString stringWithUTF8String:keys[i]];
            NSString *value = [NSString stringWithUTF8String:vals[i]];
            if (key && value && key.length > 0 && key.length < 256) {
                txt[key] = [value dataUsingEncoding:NSUTF8StringEncoding];
            }
        }
    }
    NSDictionary *snapshot = [txt copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (context.ready) { context.ready(service, port, snapshot); }
    });
}

static void gh_pair_pin_ready(const char *pin, void *ctx) {
    if (ctx == NULL || pin == NULL) { return; }
    GHPairCallbackContext *context = (__bridge GHPairCallbackContext *)ctx;
    NSString *value = [NSString stringWithUTF8String:pin];
    if (!value || value.length > 32) { return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (context.pin) { context.pin(value); }
    });
}

void GHStartNativeOnDevicePairing(NSString *outputPath,
                                  GHPairReadyBlock ready,
                                  GHPairPINBlock pin,
                                  GHPairFinishedBlock finished) {
    if (outputPath.length == 0 || !finished) { return; }
    GHPairCallbackContext *context = [GHPairCallbackContext new];
    context.ready = [ready copy];
    context.pin = [pin copy];
    void *rawContext = (__bridge_retained void *)context;
    NSString *destination = [outputPath copy];
    GHPairFinishedBlock finalBlock = [finished copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        ALPairResult out = {0};
        // A genuine native host handshake; unlike fake pairing files, only an
        // rc==0 result can be considered. File and authentication still tested separately.
        int32_t rc = al_pairing_run_host("0.0.0.0", 0, "GooHan Test", "Mac17,7",
                                         destination.UTF8String, NULL,
                                         gh_pair_host_ready, gh_pair_pin_ready,
                                         rawContext, &out);
        NSString *issuedPath = out.pairing_file_path ? [NSString stringWithUTF8String:out.pairing_file_path] : @"";
        if (!issuedPath) { issuedPath = @""; }
        al_pairing_result_free(&out);
        CFBridgingRelease(rawContext);
        dispatch_async(dispatch_get_main_queue(), ^{
            finalBlock(rc == 0, issuedPath, rc);
        });
    });
}

// Only a boolean is stored from syslog callbacks; no lines ever leave this FFI bridge.
typedef struct { atomic_bool sawLine; } GHStreamProbeContext;
static atomic_bool gh_stream_active = false;
static atomic_ulong gh_stream_generation = 0;
static void gh_stream_line(void *ctx, const char *line) {
    if (ctx && line && line[0]) {
        GHStreamProbeContext *probe = (GHStreamProbeContext *)ctx;
        atomic_store(&probe->sawLine, true);
    }
}

void GHRunNativeReadOnlySessionProbe(NSString *pairingPath,
                                     GHSessionFinishedBlock finished) {
    if (pairingPath.length == 0 || !finished) { return; }
    bool wasActive = false;
    if (!atomic_compare_exchange_strong(&gh_stream_active, &wasActive, true)) {
        dispatch_async(dispatch_get_main_queue(), ^{ finished(NO, -2); });
        return;
    }
    unsigned long generation = atomic_fetch_add(&gh_stream_generation, 1) + 1;
    NSString *pairPath = [pairingPath copy];
    GHSessionFinishedBlock finalBlock = [finished copy];
    GHStreamProbeContext *context = calloc(1, sizeof(GHStreamProbeContext));
    if (!context) {
        atomic_store(&gh_stream_active, false);
        dispatch_async(dispatch_get_main_queue(), ^{ finalBlock(NO, -3); });
        return;
    }
    atomic_init(&context->sawLine, false);

    // The native stream blocks. Request a stop after five seconds; if native
    // cancellation fails it may remain blocked on its background queue.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (atomic_load(&gh_stream_active) && atomic_load(&gh_stream_generation) == generation) {
            al_syslog_stream_stop();
        }
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        char *error = NULL;
        int32_t rc = al_syslog_stream_start(pairPath.UTF8String, gh_stream_line, context, &error);
        BOOL observed = atomic_load(&context->sawLine);
        if (error) { al_string_free(error); } // Do not surface private device details.
        free(context);
        atomic_store(&gh_stream_active, false);
        dispatch_async(dispatch_get_main_queue(), ^{
            finalBlock(observed, rc);
        });
    });
}

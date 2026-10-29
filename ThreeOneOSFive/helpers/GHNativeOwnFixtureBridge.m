#import "GHNativeOwnFixtureBridge.h"
#import "GHNativePairingBridge.h"
#import <airlift.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
// --------------------- v4.6 isolated native write probe --------------------
// This entrypoint never accepts a destination directory or arbitrary bundle ID.
// The ONLY write target is a fresh, UUID-named folder below GooHan's OWN home.
// It is a diagnostic for a disposable fixture, not a patch writer.
static atomic_bool gh_own_fixture_write_active = false;

static BOOL gh_regular_small_file(NSFileManager *fm, NSString *path) {
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    NSNumber *size = attrs[NSFileSize];
    return [attrs[NSFileType] isEqualToString:NSFileTypeRegular] &&
           size != nil && size.unsignedLongLongValue > 0 && size.unsignedLongLongValue <= 4096;
}

static BOOL gh_real_directory(NSFileManager *fm, NSString *path) {
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    return [attrs[NSFileType] isEqualToString:NSFileTypeDirectory];
}

static BOOL gh_check_own_fixture_root(NSString *fixtureRoot) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appHome = [NSHomeDirectory() stringByResolvingSymlinksInPath];
    NSString *allowedParent = [[appHome stringByAppendingPathComponent:@"Library/Application Support/GHV46NativeFixtures"] stringByStandardizingPath];
    NSString *resolvedParent = [[fixtureRoot stringByDeletingLastPathComponent] stringByResolvingSymlinksInPath];
    NSString *resolvedRoot = [fixtureRoot stringByResolvingSymlinksInPath];
    NSString *component = fixtureRoot.lastPathComponent;
    if (appHome.length == 0 || ![resolvedParent isEqualToString:allowedParent] ||
        ![resolvedRoot isEqualToString:[allowedParent stringByAppendingPathComponent:component]] ||
        [[NSUUID alloc] initWithUUIDString:component] == nil) { return NO; }
    NSString *stage = [fixtureRoot stringByAppendingPathComponent:@"stage"];
    NSString *target = [fixtureRoot stringByAppendingPathComponent:@"target"];
    NSString *stagedFile = [stage stringByAppendingPathComponent:@"gh_v46_fixture.dat"];
    NSString *targetFile = [target stringByAppendingPathComponent:@"gh_v46_fixture.dat"];
    NSString *backup = [fixtureRoot stringByAppendingPathComponent:@"gh_v46_fixture.backup"];
    if (!gh_real_directory(fm, allowedParent) || !gh_real_directory(fm, fixtureRoot) ||
        !gh_real_directory(fm, stage) || !gh_real_directory(fm, target) ||
        !gh_regular_small_file(fm, stagedFile) || !gh_regular_small_file(fm, targetFile) ||
        !gh_regular_small_file(fm, backup)) { return NO; }
    // No symlink/redirect in the fixture tree. Do not allow an attacker-controlled
    // nested component to redirect the opaque native library outside our sandbox.
    for (NSString *p in @[stage, target, stagedFile, targetFile, backup]) {
        NSString *resolved = [p stringByResolvingSymlinksInPath];
        if (![resolved isEqualToString:[p stringByStandardizingPath]]) { return NO; }
    }
    NSArray<NSString *> *staged = [fm contentsOfDirectoryAtPath:stage error:nil];
    return staged.count == 1 && [staged.firstObject isEqualToString:@"gh_v46_fixture.dat"];
}

// Turn opaque Rust error text into allowlisted diagnostic classes. Raw error
// text may contain private paths, device identifiers or pairing information;
// NEVER send it to Swift, logs, Admin or analytics.
static NSString *gh_native_error_class(const char *nativeError, int32_t rc) {
    if (rc == 0) { return @"AL_ERROR_NONE"; }
    if (!nativeError || !nativeError[0]) { return @"AL_ERROR_NOT_PROVIDED"; }
    size_t count = strnlen(nativeError, 4096);
    if (count == 4096) { return @"AL_ERROR_TEXT_TOO_LONG"; }
    NSString *message = [[NSString alloc] initWithBytes:nativeError
                                                  length:count
                                                encoding:NSUTF8StringEncoding];
    if (!message) { return @"AL_ERROR_TEXT_UNREADABLE"; }
    NSString *lower = message.lowercaseString;
    // Order matters: specific authentication failures before generic network.
    for (NSString *token in @[@"pairing", @"pair", @"credential", @"authentication", @"handshake", @"trust"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_PAIRING_OR_AUTH"; }
    }
    for (NSString *token in @[@"permission", @"denied", @"not permitted", @"sandbox", @"unauthorized"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_PERMISSION_OR_TARGET"; }
    }
    for (NSString *token in @[@"connection", @"connect", @"tunnel", @"network", @"timeout", @"timed out", @"dial", @"transport", @"rsd"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_TUNNEL_OR_NETWORK"; }
    }
    // FileService/Lockdown is a device-service failure, not automatically a
    // missing *local* source file. Check these before interpreting path errors.
    for (NSString *token in @[@"lockdown", @"afc", @"fileservice", @"file service", @"coredevice", @"service unavailable", @"service not available"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_DEVICE_SERVICE"; }
    }
    // Only categorize paths when the native diagnostic is specific. In v4.6.1
    // the generic word 'file' matched nearly everything, giving a false sense
    // of certainty that the local staging path was wrong.
    for (NSString *token in @[@"source_dir", @"source directory", @"source folder", @"source path", @"source file", @"staging directory"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_NATIVE_SOURCE_REFERENCE"; }
    }
    for (NSString *token in @[@"target_dir", @"target directory", @"target folder", @"target path", @"destination path"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_NATIVE_TARGET_REFERENCE"; }
    }
    for (NSString *token in @[@"no such file", @"not found", @"not a directory", @"file does not exist"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_NATIVE_PATH_UNRESOLVED"; }
    }
    for (NSString *token in @[@"invalid argument", @"invalid parameter", @"bad argument"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_INVALID_NATIVE_ARGUMENT"; }
    }
    for (NSString *token in @[@"airtraffic", @"exploit", @"canary", @"write failed"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_NATIVE_WRITE_STAGE"; }
    }
    return @"AL_ERROR_UNCLASSIFIED";
}


// Optional FFI trace callback. It stores ONLY allowlisted stage hints and a
// capped event count. Raw log text may include pairing credentials or paths;
// it is never retained, printed, uploaded, or passed to Swift.
// Keep only bounded aggregate counters. Never store a native callback line.
// Class IDs: 0=other, 1=auth, 2=network, 3=device service,
// 4=permission, 5=native write. These are clues, not proven root causes.
typedef struct {
    pthread_mutex_t lock;
    uint32_t events;
    uint32_t categories[6];
    uint32_t transitions;
    int firstHint;
    int lastHint;
} GHNativeTrace;

static int gh_native_trace_hint(const char *message) {
    if (!message) { return 0; }
    size_t n = strnlen(message, 4096);
    if (n == 0 || n == 4096) { return 0; }
    @autoreleasepool {
        NSString *s = [[[NSString alloc] initWithBytes:message length:n
                                            encoding:NSUTF8StringEncoding] lowercaseString];
        if (!s) { return 0; }
        // Hints describe a log line, NOT the proven root cause of failure.
        for (NSString *key in @[@"pairing", @"authentication", @"handshake", @"credential"]) {
            if ([s containsString:key]) { return 1; }
        }
        for (NSString *key in @[@"tunnel", @"network", @"connect", @"transport", @"rsd"]) {
            if ([s containsString:key]) { return 2; }
        }
        for (NSString *key in @[@"fileservice", @"file service", @"lockdown", @"coredevice", @"afc"]) {
            if ([s containsString:key]) { return 3; }
        }
        for (NSString *key in @[@"permission", @"denied", @"unauthorized", @"sandbox"]) {
            if ([s containsString:key]) { return 4; }
        }
        for (NSString *key in @[@"write", @"copy", @"canary", @"exploit", @"airtraffic"]) {
            if ([s containsString:key]) { return 5; }
        }
        return 0;
    }
}

static void gh_redacted_native_trace(void *context, const char *message) {
    if (!context) { return; }
    GHNativeTrace *trace = (GHNativeTrace *)context;
    int hint = gh_native_trace_hint(message);
    if (hint < 0 || hint > 5) { hint = 0; }
    pthread_mutex_lock(&trace->lock);
    if (trace->events < 9999) {
        if (trace->events == 0) { trace->firstHint = hint; }
        else if (trace->lastHint != hint && trace->transitions < 9999) {
            trace->transitions++;
        }
        trace->events++;
        if (trace->categories[hint] < 9999) { trace->categories[hint]++; }
        trace->lastHint = hint;
    }
    pthread_mutex_unlock(&trace->lock);
}

static NSString *gh_trace_category(int hint) {
    switch (hint) {
        case 1: return @"AUTH";
        case 2: return @"NETWORK";
        case 3: return @"SERVICE";
        case 4: return @"PERMISSION";
        case 5: return @"WRITE";
        default: return @"OTHER";
    }
}

// Existing hint prefix preserved for the v4.6.3 UI/tests, with v4.6.6
// aggregate counters appended. Every token is allowlisted; no raw text.
static NSString *gh_trace_summary(GHNativeTrace *trace) {
    uint32_t events, counts[6], transitions;
    int first, last;
    pthread_mutex_lock(&trace->lock);
    events = trace->events;
    memcpy(counts, trace->categories, sizeof(counts));
    transitions = trace->transitions;
    first = trace->firstHint;
    last = trace->lastHint;
    pthread_mutex_unlock(&trace->lock);
    NSString *hint;
    if (events == 0) { hint = @"AL_TRACE_NO_LOG_CALLBACKS"; }
    else {
        switch (last) {
            case 1: hint = @"AL_TRACE_HINT_PAIRING_OR_AUTH"; break;
            case 2: hint = @"AL_TRACE_HINT_TUNNEL_OR_NETWORK"; break;
            case 3: hint = @"AL_TRACE_HINT_DEVICE_SERVICE"; break;
            case 4: hint = @"AL_TRACE_HINT_PERMISSION"; break;
            case 5: hint = @"AL_TRACE_HINT_NATIVE_WRITE"; break;
            default: hint = @"AL_TRACE_LOGS_SEEN_UNCLASSIFIED"; break;
        }
    }
    return [NSString stringWithFormat:
        @"%@|AL_TRACE_EVENTS_%u|AL_TRACE_FIRST_%@|AL_TRACE_LAST_%@|AL_TRACE_COUNTS_AUTH_%u_NET_%u_SERVICE_%u_PERMISSION_%u_WRITE_%u_OTHER_%u|AL_TRACE_TRANSITIONS_%u",
        hint, events, gh_trace_category(first), gh_trace_category(last),
        counts[1], counts[2], counts[3], counts[4], counts[5], counts[0], transitions];
}

void GHRunNativeOwnFixtureWrite(NSString *pairingPath,
                                NSString *fixtureRoot,
                                GHOwnFixtureWriteFinishedBlock finished) {
    if (!finished) { return; }
    // A second writer cannot start while an opaque native call is in-flight.
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gh_own_fixture_write_active, &expected, true)) {
        dispatch_async(dispatch_get_main_queue(), ^{ finished(NO, -31, @"CALL_ALREADY_IN_FLIGHT", @"AL_TRACE_NOT_RUN"); });
        return;
    }
    NSString *pairing = [pairingPath copy];
    NSString *root = [fixtureRoot copy];
    GHOwnFixtureWriteFinishedBlock completion = [finished copy];
    NSString *home = [NSHomeDirectory() stringByResolvingSymlinksInPath];
    NSString *expectedPair = [home stringByAppendingPathComponent:@"Library/Application Support/GHLocalPairing/pairing.record"];
    // A credential may only come from GooHan's existing private pairing vault.
    if (pairing.length == 0 ||
        ![[pairing stringByResolvingSymlinksInPath] isEqualToString:expectedPair] ||
        !gh_check_own_fixture_root(root)) {
        atomic_store(&gh_own_fixture_write_active, false);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, -30, @"LOCAL_FIXTURE_GUARD_REJECTED", @"AL_TRACE_NOT_RUN"); });
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int32_t rc = -30;
        NSString *errorClass = @"LOCAL_FIXTURE_GUARD_REJECTED";
        NSString *traceSummary = @"AL_TRACE_NOT_RUN";
        // Revalidate immediately before crossing the FFI boundary. Never accept
        // a destination path from a package, server, web view or user input.
        if (gh_check_own_fixture_root(root)) {
            NSString *staging = [root stringByAppendingPathComponent:@"stage"];
            NSString *destination = [root stringByAppendingPathComponent:@"target"];
            char *nativeError = NULL;
            GHNativeTrace trace = {0};
            pthread_mutex_init(&trace.lock, NULL);
            int32_t routeRC = GHApplyAppNewRouteHints();
            if (routeRC == 0) {
                rc = al_exploit_write_dir(pairing.UTF8String,
                                          staging.UTF8String,
                                          destination.UTF8String,
                                          gh_redacted_native_trace, &trace, &nativeError);
                errorClass = gh_native_error_class(nativeError, rc);
            } else {
                rc = -41;
                errorClass = @"AL_ERROR_HOST_ROUTING_FAILED";
            }
            // Collect allowlisted signals BEFORE releasing native memory.
            traceSummary = gh_trace_summary(&trace);
            pthread_mutex_destroy(&trace.lock);
            if (nativeError) { al_string_free(nativeError); }
        }
        atomic_store(&gh_own_fixture_write_active, false);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(rc == 0, rc, errorClass, traceSummary);
        });
    });
}

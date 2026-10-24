#import "GHNativeOwnFixtureBridge.h"
#import <airlift.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
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
    for (NSString *token in @[@"not found", @"no such file", @"source", @"directory", @"path", @"file"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_SOURCE_OR_PATH"; }
    }
    for (NSString *token in @[@"lockdown", @"afc", @"service unavailable", @"service not available"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_DEVICE_SERVICE"; }
    }
    for (NSString *token in @[@"airtraffic", @"exploit", @"canary", @"write failed"]) {
        if ([lower containsString:token]) { return @"AL_ERROR_NATIVE_WRITE_STAGE"; }
    }
    return @"AL_ERROR_UNCLASSIFIED";
}

void GHRunNativeOwnFixtureWrite(NSString *pairingPath,
                                NSString *fixtureRoot,
                                GHOwnFixtureWriteFinishedBlock finished) {
    if (!finished) { return; }
    // A second writer cannot start while an opaque native call is in-flight.
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gh_own_fixture_write_active, &expected, true)) {
        dispatch_async(dispatch_get_main_queue(), ^{ finished(NO, -31, @"CALL_ALREADY_IN_FLIGHT"); });
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
        dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, -30, @"LOCAL_FIXTURE_GUARD_REJECTED"); });
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int32_t rc = -30;
        NSString *errorClass = @"LOCAL_FIXTURE_GUARD_REJECTED";
        // Revalidate immediately before crossing the FFI boundary. Never accept
        // a destination path from a package, server, web view or user input.
        if (gh_check_own_fixture_root(root)) {
            NSString *staging = [root stringByAppendingPathComponent:@"stage"];
            NSString *destination = [root stringByAppendingPathComponent:@"target"];
            char *nativeError = NULL;
            rc = al_exploit_write_dir(pairing.UTF8String,
                                      staging.UTF8String,
                                      destination.UTF8String,
                                      NULL, NULL, &nativeError);
            // Collect error class BEFORE freeing; never propagate Rust error text.
            errorClass = gh_native_error_class(nativeError, rc);
            if (nativeError) { al_string_free(nativeError); }
        }
        atomic_store(&gh_own_fixture_write_active, false);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(rc == 0, rc, errorClass);
        });
    });
}

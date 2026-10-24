#import "GHNativeOwnFixtureBridge.h"
#import <airlift.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
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

void GHRunNativeOwnFixtureWrite(NSString *pairingPath,
                                NSString *fixtureRoot,
                                GHOwnFixtureWriteFinishedBlock finished) {
    if (!finished) { return; }
    // A second writer cannot start while an opaque native call is in-flight.
    bool expected = false;
    if (!atomic_compare_exchange_strong(&gh_own_fixture_write_active, &expected, true)) {
        dispatch_async(dispatch_get_main_queue(), ^{ finished(NO, -31); });
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
        dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, -30); });
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int32_t rc = -30;
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
            if (nativeError) { al_string_free(nativeError); }
        }
        atomic_store(&gh_own_fixture_write_active, false);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(rc == 0, rc);
        });
    });
}

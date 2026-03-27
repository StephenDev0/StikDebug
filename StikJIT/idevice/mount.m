//
//  mount1.m
//  StikDebug
//
//  Created by s s on 2025/12/6.
//
#include "mount.h"
#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"
@import Foundation;

NSError* makeError(int code, NSString* msg);

size_t getMountedDeviceCount(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSError** error) {
    ImageMounterHandle *client = NULL;
    IdeviceFfiError *err = image_mounter_connect_rsd(adapter, handshake, &client);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return 0;
    }

    plist_t *devices = NULL;
    size_t deviceLength = 0;
    err = image_mounter_copy_devices(client, &devices, &deviceLength);
    image_mounter_free(client);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return 0;
    }

    for (int i = 0; i < (int)deviceLength; i++) {
        plist_free(devices[i]);
    }
    idevice_data_free((uint8_t *)devices, deviceLength * sizeof(plist_t));
    return deviceLength;
}

int mountPersonalDDI(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString* imagePath, NSString* trustcachePath, NSString* manifestPath, NSError** error) {
    NSData *image         = [NSData dataWithContentsOfFile:imagePath];
    NSData *trustcache    = [NSData dataWithContentsOfFile:trustcachePath];
    NSData *buildManifest = [NSData dataWithContentsOfFile:manifestPath];
    if (!image || !trustcache || !buildManifest) {
        *error = makeError(1, @"Failed to read one or more files");
        return 1;
    }

    // Get UniqueChipID via lockdownd over RSD (no session start needed - tunnel handles auth)
    LockdowndClientHandle *lockdownClient = NULL;
    IdeviceFfiError *err = lockdownd_connect_rsd(adapter, handshake, &lockdownClient);
    if (err) {
        *error = makeError(6, @(err->message));
        idevice_error_free(err);
        return 6;
    }

    plist_t uniqueChipIDPlist = NULL;
    err = lockdownd_get_value(lockdownClient, "UniqueChipID", NULL, &uniqueChipIDPlist);
    lockdownd_client_free(lockdownClient);
    if (err) {
        *error = makeError(8, @(err->message));
        idevice_error_free(err);
        return 8;
    }

    uint64_t uniqueChipID = 0;
    plist_get_uint_val(uniqueChipIDPlist, &uniqueChipID);
    plist_free(uniqueChipIDPlist);

    ImageMounterHandle *mounterClient = NULL;
    err = image_mounter_connect_rsd(adapter, handshake, &mounterClient);
    if (err) {
        *error = makeError(9, @(err->message));
        idevice_error_free(err);
        return 9;
    }

    // TODO: image_mounter_mount_personalized still requires an IdeviceProviderHandle.
    // The FFI needs an RSD variant (e.g. image_mounter_mount_personalized_rsd) that
    // takes an AdapterHandle instead.
    *error = makeError(10, @"mount_personalized not yet available over RSD tunnels");
    image_mounter_free(mounterClient);
    return 10;
}

@implementation JITEnableContext(DDI)

- (NSUInteger)getMountedDeviceCount:(NSError**)error {
    [self ensureTunnelWithError:error];
    if (*error) { return 0; }
    return getMountedDeviceCount(adapter, handshake, error);
}

- (NSInteger)mountPersonalDDIWithImagePath:(NSString*)imagePath trustcachePath:(NSString*)trustcachePath manifestPath:(NSString*)manifestPath error:(NSError**)error {
    [self ensureTunnelWithError:error];
    if (*error) { return 0; }
    return mountPersonalDDI(adapter, handshake, imagePath, trustcachePath, manifestPath, error);
}

@end

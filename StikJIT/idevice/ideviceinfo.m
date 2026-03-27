//
//  ideviceinfo.c
//  StikDebug
//
//  Created by Stephen on 8/2/25.
//

#include <stdlib.h>
#include <arpa/inet.h>
#include "ideviceinfo.h"
#include "idevice.h"
#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"
@import Foundation;

NSError* makeError(int code, NSString* msg);
LockdowndClientHandle* ideviceinfo_c_init(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSError** error) {
    LockdowndClientHandle *g_client = NULL;
    IdeviceFfiError *err = lockdownd_connect_rsd(adapter, handshake, &g_client);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return NULL;
    }

    // No session start needed - RSD tunnel handles authentication
    return g_client;
}

char *ideviceinfo_c_get_xml(LockdowndClientHandle* g_client, NSError** error) {
    if (!g_client) {
        return NULL;
    }

    void *plist_obj = NULL;
    struct IdeviceFfiError *err = lockdownd_get_value(g_client, NULL, NULL, &plist_obj);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return NULL;
    }

    char *xml = NULL;
    uint32_t xml_len = 0;
    if (plist_to_xml(plist_obj, &xml, &xml_len) != 0 || !xml) {
        plist_free(plist_obj);
        return NULL;
    }
    plist_free(plist_obj);
    return xml;
}

@implementation JITEnableContext(DeviceInfo)

- (LockdowndClientHandle*)ideviceInfoInit:(NSError**)error {
    [self ensureTunnelWithError:error];
    if (*error) { return nil; }
    return ideviceinfo_c_init(adapter, handshake, error);
}

- (char*)ideviceInfoGetXMLWithLockdownClient:(LockdowndClientHandle*)lockdownClient error:(NSError**)error {
    [self ensureTunnelWithError:error];
    if (*error) { return NULL; }
    return ideviceinfo_c_get_xml(lockdownClient, error);
}
@end

//
//  IDeviceJSBridgeInstallationProxy.m
//  StikJIT
//
//  Created by s s on 2025/4/25.
//
@import Foundation;
@import JavaScriptCore;
#import "JSSupport.h"

struct InstallationProxyCallbackContext {
    int callbackId;
    JSContext* context;
};

void installationProxyCallback(uint64_t progress, struct InstallationProxyCallbackContext* context) {
    [context->context evaluateScript:[NSString stringWithFormat:@"handle_installation_proxy_js_callback(%d, %llu)", context->callbackId, progress]];
}

@implementation IDeviceJSBridge (InstallationProxy)

- (void)installation_proxy_connectWithBody:(NSDictionary *)body replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
    NSError* heartbeatErr = nil;
    [JITEnableContext.shared ensureHeartbeatWithError:&heartbeatErr];
    if(heartbeatErr) {
        replyHandler(nil, heartbeatErr.localizedDescription);
        return;
    }
    
    IdeviceProviderHandle* provider = [JITEnableContext.shared getTcpProviderHandle];
    
    InstallationProxyClientHandle *client = NULL;
    IdeviceFfiError* err = installation_proxy_connect(provider, &client);
    if (err) {
        replyHandler(nil, [self errFreeFromIdeviceFfiError:err]);
        return;
    }
    int handleId = [self registerIdeviceHandle:client freeFunc:(void*)installation_proxy_client_free];
    replyHandler(@(handleId), nil);
}

- (void)installation_proxy_get_appsWithBody:(NSDictionary *)body replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
    
    int clientId = [body[@"client"] intValue];
    if(!handles[@(clientId)] || handles[@(clientId)].freeFunc != installation_proxy_client_free) {
        replyHandler(nil, @"Invalid client handle");
        return;
    }
    IDeviceHandle* clientHandleObj = handles[@(clientId)];
    InstallationProxyClientHandle* client = clientHandleObj.handle;
    NSString* applicationType = body[@"application_type"];
    if(![applicationType isKindOfClass:NSString.class]) {
        applicationType = nil;
    }
    
    NSArray* bundleIdentifiers = body[@"bundle_identifiers"];
    
    int bundleIdentifiersCount;
    const char** bundleIdentifiersCharArr = cstrArrFromNSArray(bundleIdentifiers, &bundleIdentifiersCount);
    void *apps = NULL;
    size_t apps_len = 0;
    IdeviceFfiError* err = installation_proxy_get_apps(client, [applicationType UTF8String], bundleIdentifiersCharArr, bundleIdentifiersCount, &apps, &apps_len);
    if(bundleIdentifiersCharArr){
        free(bundleIdentifiersCharArr);
    }
    if (err) {
        replyHandler(nil, [self errFreeFromIdeviceFfiError:err]);
        return;
    }
    
    plist_t *app_list = (plist_t *)apps;
    do {
        NSMutableArray* ans = [[NSMutableArray alloc] init];
        for(int i = 0; i < apps_len; ++i) {
            NSError* err2 = 0;
            NSDictionary* appDict = dictionaryFromPlist(app_list[i], &err2);

            if(err2) {
                replyHandler(nil, @"failed to parse plist data");
                break;
            }
            [ans addObject:appDict];
        }
        replyHandler(ans, nil);
    } while(0);

    for(int i = 0; i < apps_len; ++i) {
        plist_free(app_list[i]);
    }
}

- (void)installation_proxy_installWithBody:(NSDictionary *)body replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
        

    int clientId = [body[@"client"] intValue];
    if(!handles[@(clientId)] || handles[@(clientId)].freeFunc != installation_proxy_client_free) {
        replyHandler(nil, @"Invalid client handle");
        return;
    }
    IDeviceHandle* clientHandleObj = handles[@(clientId)];
    InstallationProxyClientHandle* client = clientHandleObj.handle;
    
    NSString* packagePath = body[@"package_path"];
    if(![packagePath isKindOfClass:NSString.class]) {
        replyHandler(nil, @"Invalid package path");
        return;
    }
    
    NSDictionary* optionsDict = body[@"options"];
    plist_t optionsPlist = 0;
    if([optionsDict isKindOfClass:NSDictionary.class]) {
        NSError* error = 0;
        NSData* optionsNSData = plistDataFromDictionary(optionsDict, &error);
        if(error) {
            replyHandler(nil, [NSString stringWithFormat:@"failed to parse options %@", error.localizedDescription]);
            return;
        }
        plist_from_memory((void*)[optionsNSData bytes], (uint32_t)[optionsNSData length], &optionsPlist, 0);
    }
    
    int callbackId = [body[@"callback_id"] intValue];
    IdeviceFfiError* err = 0;
    if(callbackId == -1) {
        err = installation_proxy_install(client, [packagePath UTF8String], optionsPlist);
    } else {
        struct InstallationProxyCallbackContext context;
        context.callbackId = callbackId;
        context.context = self->context;
        err = installation_proxy_install_with_callback(client, [packagePath UTF8String], optionsPlist, (void (*)(uint64_t, void *))installationProxyCallback, &context);

    }
    
    if(optionsPlist) {
        plist_free(optionsPlist);
    }
    
    if(err) {
        replyHandler(nil, [self errFreeFromIdeviceFfiError:err]);
        return;
    }
    replyHandler(@YES, nil);
}

- (void)installation_proxy_upgradeWithBody:(NSDictionary *)body replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
        

    int clientId = [body[@"client"] intValue];
    if(!handles[@(clientId)] || handles[@(clientId)].freeFunc != installation_proxy_client_free) {
        replyHandler(nil, @"Invalid client handle");
        return;
    }
    IDeviceHandle* clientHandleObj = handles[@(clientId)];
    InstallationProxyClientHandle* client = clientHandleObj.handle;
    
    NSString* packagePath = body[@"package_path"];
    if(![packagePath isKindOfClass:NSString.class]) {
        replyHandler(nil, @"Invalid package path");
        return;
    }
    
    NSDictionary* optionsDict = body[@"options"];
    plist_t optionsPlist = 0;
    if([optionsDict isKindOfClass:NSDictionary.class]) {
        NSError* error = 0;
        NSData* optionsNSData = plistDataFromDictionary(optionsDict, &error);
        if(error) {
            replyHandler(nil, [NSString stringWithFormat:@"failed to parse options %@", error.localizedDescription]);
            return;
        }
        plist_from_memory((void*)[optionsNSData bytes], (uint32_t)[optionsNSData length], &optionsPlist, 0);
    }
    
    int callbackId = [body[@"callback_id"] intValue];
    IdeviceFfiError* err = 0;
    if(callbackId == -1) {
        err = installation_proxy_upgrade(client, [packagePath UTF8String], optionsPlist);
    } else {
        struct InstallationProxyCallbackContext context;
        context.callbackId = callbackId;
        context.context = self->context;
        err = installation_proxy_upgrade_with_callback(client, [packagePath UTF8String], optionsPlist, (void (*)(uint64_t, void *))installationProxyCallback, &context);

    }
    
    if(optionsPlist) {
        plist_free(optionsPlist);
    }
    
    if(err) {
        replyHandler(nil, [self errFreeFromIdeviceFfiError:err]);
        return;
    }
    replyHandler(@YES, nil);
}

- (void)installation_proxy_uninstallWithBody:(NSDictionary *)body replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
        

    int clientId = [body[@"client"] intValue];
    if(!handles[@(clientId)] || handles[@(clientId)].freeFunc != installation_proxy_client_free) {
        replyHandler(nil, @"Invalid client handle");
        return;
    }
    IDeviceHandle* clientHandleObj = handles[@(clientId)];
    InstallationProxyClientHandle* client = clientHandleObj.handle;
    
    NSString* bundleId = body[@"bundle_id"];
    if(![bundleId isKindOfClass:NSString.class]) {
        replyHandler(nil, @"Invalid bundle id");
        return;
    }
    
    NSDictionary* optionsDict = body[@"options"];
    plist_t optionsPlist = 0;
    if([optionsDict isKindOfClass:NSDictionary.class]) {
        NSError* error = 0;
        NSData* optionsNSData = plistDataFromDictionary(optionsDict, &error);
        if(error) {
            replyHandler(nil, [NSString stringWithFormat:@"failed to parse options %@", error.localizedDescription]);
            return;
        }
        plist_from_memory((void*)[optionsNSData bytes], (uint32_t)[optionsNSData length], &optionsPlist, 0);
    }
    
    int callbackId = [body[@"callback_id"] intValue];
    IdeviceFfiError* err = 0;
    if(callbackId == -1) {
        err = installation_proxy_uninstall(client, [bundleId UTF8String], optionsPlist);
    } else {
        struct InstallationProxyCallbackContext context;
        context.callbackId = callbackId;
        context.context = self->context;
        err = installation_proxy_uninstall_with_callback(client, [bundleId UTF8String], optionsPlist, (void (*)(uint64_t, void *))installationProxyCallback, &context);

    }
    
    if(optionsPlist) {
        plist_free(optionsPlist);
    }
    
    if(err) {
        replyHandler(nil, [self errFreeFromIdeviceFfiError:err]);
        return;
    }
    replyHandler(@YES, nil);
}

- (void)installation_proxy_browseWithBody:(NSDictionary *)body replyHandler:(nonnull void (^)(id _Nullable, NSString * _Nullable))replyHandler {
    
    int clientId = [body[@"client"] intValue];
    if(!handles[@(clientId)] || handles[@(clientId)].freeFunc != installation_proxy_client_free) {
        replyHandler(nil, @"Invalid client handle");
        return;
    }
    IDeviceHandle* clientHandleObj = handles[@(clientId)];
    InstallationProxyClientHandle* client = clientHandleObj.handle;
    
    NSDictionary* optionsDict = body[@"options"];
    plist_t optionsPlist = 0;
    if([optionsDict isKindOfClass:NSDictionary.class]) {
        NSError* error = 0;
        NSData* optionsNSData = plistDataFromDictionary(optionsDict, &error);
        if(error) {
            replyHandler(nil, [NSString stringWithFormat:@"failed to parse options %@", error.localizedDescription]);
            return;
        }
        plist_from_memory((void*)[optionsNSData bytes], (uint32_t)[optionsNSData length], &optionsPlist, 0);
    }
    
    plist_t *app_list = NULL;
    size_t apps_len = 0;
    IdeviceFfiError* err = installation_proxy_browse(client, optionsPlist, &app_list, &apps_len);

    if (err) {
        replyHandler(nil, [self errFreeFromIdeviceFfiError:err]);
        return;
    }
    
    do {
        NSMutableArray* ans = [[NSMutableArray alloc] init];
        for(int i = 0; i < apps_len; ++i) {
            NSError* err2 = 0;
            NSDictionary* appDict = dictionaryFromPlist(app_list[i], &err2);

            if(err2) {
                replyHandler(nil, @"failed to parse plist data");
                break;
            }
            [ans addObject:appDict];
        }
        replyHandler(ans, nil);
    } while(0);

    for(int i = 0; i < apps_len; ++i) {
        plist_free(app_list[i]);
    }
    
    
}

@end

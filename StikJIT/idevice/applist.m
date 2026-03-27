//
//  applist.c
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

#import "idevice.h"
#include <arpa/inet.h>
#include <stdlib.h>
#include <string.h>
#import "applist.h"
#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"

NSError* makeError(int code, NSString* msg);
static NSString *extractAppName(plist_t app)
{
    plist_t displayNameNode = plist_dict_get_item(app, "CFBundleDisplayName");
    if (displayNameNode) {
        char *displayNameC = NULL;
        plist_get_string_val(displayNameNode, &displayNameC);
        if (displayNameC && displayNameC[0] != '\0') {
            NSString *displayName = [NSString stringWithUTF8String:displayNameC];
            plist_mem_free(displayNameC);
            return displayName;
        }
        plist_mem_free(displayNameC);
    }

    plist_t nameNode = plist_dict_get_item(app, "CFBundleName");
    if (nameNode) {
        char *nameC = NULL;
        plist_get_string_val(nameNode, &nameC);
        if (nameC && nameC[0] != '\0') {
            NSString *name = [NSString stringWithUTF8String:nameC];
            plist_mem_free(nameC);
            return name;
        }
        plist_mem_free(nameC);
    }

    return @"Unknown";
}

static BOOL nodeContainsHiddenTag(plist_t tagsNode)
{
    if (!tagsNode || plist_get_node_type(tagsNode) != PLIST_ARRAY) {
        return NO;
    }

    uint32_t tagsCount = plist_array_get_size(tagsNode);
    for (uint32_t i = 0; i < tagsCount; i++) {
        plist_t tagNode = plist_array_get_item(tagsNode, i);
        if (!tagNode || plist_get_node_type(tagNode) != PLIST_STRING) {
            continue;
        }
        char *tagC = NULL;
        plist_get_string_val(tagNode, &tagC);
        if (!tagC) {
            continue;
        }
        BOOL isHidden = (strcmp(tagC, "hidden") == 0 || strcmp(tagC, "hidden-system-app") == 0);
        free(tagC);
        if (isHidden) {
            return YES;
        }
    }
    return NO;
}

static BOOL isHiddenSystemApp(plist_t app)
{
    plist_t typeNode = plist_dict_get_item(app, "ApplicationType");
    BOOL isSystemType = NO;
    if (typeNode && plist_get_node_type(typeNode) == PLIST_STRING) {
        char *typeC = NULL;
        plist_get_string_val(typeNode, &typeC);
        if (typeC) {
            if (strcmp(typeC, "System") == 0 || strcmp(typeC, "HiddenSystemApp") == 0) {
                isSystemType = YES;
            }
            free(typeC);
        }
    }

    if (!isSystemType) {
        return NO;
    }

    plist_t hiddenNode = plist_dict_get_item(app, "IsHidden");
    if (hiddenNode && plist_get_node_type(hiddenNode) == PLIST_BOOLEAN) {
        uint8_t hidden = 0;
        plist_get_bool_val(hiddenNode, &hidden);
        if (hidden) {
            return YES;
        }
    }

    plist_t tagsNode = plist_dict_get_item(app, "SBAppTags");
    if (nodeContainsHiddenTag(tagsNode)) {
        return YES;
    }

    return NO;
}

static NSDictionary<NSString*, NSString*> *buildAppDictionary(void *apps,
                                                             size_t count,
                                                             BOOL requireGetTaskAllow,
                                                             BOOL (^filter)(plist_t app))
{
    NSMutableDictionary<NSString*, NSString*> *result = [NSMutableDictionary dictionaryWithCapacity:count];

    for (size_t i = 0; i < count; i++) {
        plist_t app = ((plist_t *)apps)[i];
        plist_t ent = plist_dict_get_item(app, "Entitlements");

        if (requireGetTaskAllow) {
            if (!ent) continue;
            plist_t tnode = plist_dict_get_item(ent, "get-task-allow");
            if (!tnode) continue;

            uint8_t isAllowed = 0;
            plist_get_bool_val(tnode, &isAllowed);
            if (!isAllowed) continue;
        }

        if (filter && !filter(app)) {
            continue;
        }

        plist_t bidNode = plist_dict_get_item(app, "CFBundleIdentifier");
        if (!bidNode) continue;

        char *bidC = NULL;
        plist_get_string_val(bidNode, &bidC);
        if (!bidC || bidC[0] == '\0') {
            plist_mem_free(bidC);
            continue;
        }

        NSString *bundleID = [NSString stringWithUTF8String:bidC];
        plist_mem_free(bidC);

        result[bundleID] = extractAppName(app);
    }

    return result;
}

static NSArray<NSDictionary*>* getSideloadedApps(AdapterHandle *adapter,
                         RsdHandshakeHandle *handshake,
                         NSString **error) {
    InstallationProxyClientHandle *client = NULL;
    IdeviceFfiError* err = installation_proxy_connect_rsd(adapter, handshake, &client);
    if (err) {
        *error = [NSString stringWithFormat:@"Failed to connect to installation proxy: %s", err->message];
        idevice_error_free(err);
        return nil;
    }

    plist_t *apps = NULL;
    size_t count = 0;
    err = installation_proxy_get_apps(client, NULL, NULL, 0, (void*)&apps, &count);
    if (err) {
        *error = [NSString stringWithFormat:@"Failed to get apps: %s", err->message];
        idevice_error_free(err);
        installation_proxy_client_free(client);
        return nil;
    }
    
    NSMutableArray<NSDictionary*>* result = [NSMutableArray new];

    for (size_t i = 0; i < count; i++) {
        plist_t app = ((plist_t *)apps)[i];
        
        plist_t profileValidatedNode = 0;
        if(!(profileValidatedNode = plist_dict_get_item(app, "ProfileValidated"))) {
            continue;
        }
        
        char* bin = 0;
        uint32_t size = 0;
        plist_to_bin(app, &bin, &size);
        if(!bin || size == 0) {
            continue;
        }
        
        NSData* d = [NSData dataWithBytes:bin length:size];
        NSError* err;
        NSDictionary* dict = [NSPropertyListSerialization propertyListWithData:d options:0 format:nil error:&err];
        plist_mem_free(bin);
        
        if(err) {
            continue;
        }
        
        [result addObject:dict];
        
    }
    
    installation_proxy_client_free(client);
    for(int i = 0; i < count; ++i) {
        plist_free(apps[i]);
    }
    idevice_data_free((uint8_t *)apps, sizeof(plist_t)*count);
    
    return result;
}

static NSDictionary<NSString*, NSString*> *performAppQuery(AdapterHandle *adapter,
                                                           RsdHandshakeHandle *handshake,
                                                           BOOL requireGetTaskAllow,
                                                           NSString **error,
                                                           BOOL (^filter)(plist_t app))
{
    InstallationProxyClientHandle *client = NULL;
    IdeviceFfiError* err = installation_proxy_connect_rsd(adapter, handshake, &client);
    if (err) {
        *error = [NSString stringWithFormat:@"Failed to connect to installation proxy: %s", err->message];
        idevice_error_free(err);
        return nil;
    }

    plist_t *apps = NULL;
    size_t count = 0;
    err = installation_proxy_get_apps(client, NULL, NULL, 0, (void*)&apps, &count);
    if (err) {
        *error = [NSString stringWithFormat:@"Failed to get apps: %s", err->message];
        idevice_error_free(err);
        installation_proxy_client_free(client);
        return nil;
    }

    NSDictionary<NSString*, NSString*> *result = buildAppDictionary(apps, count, requireGetTaskAllow, filter);
    installation_proxy_client_free(client);
    for(int i = 0; i < count; ++i) {
        plist_free(apps[i]);
    }
    idevice_data_free((uint8_t *)apps, sizeof(plist_t)*count);
    return result;
}

NSDictionary<NSString*, NSString*>* list_installed_apps(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString** error) {
    return performAppQuery(adapter, handshake, YES, error, nil);
}

NSDictionary<NSString*, NSString*>* list_all_apps(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString** error) {
    return performAppQuery(adapter, handshake, NO, error, nil);
}

NSDictionary<NSString*, NSString*>* list_hidden_system_apps(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString** error) {
    return performAppQuery(adapter, handshake, NO, error, ^BOOL(plist_t app) {
        return isHiddenSystemApp(app);
    });
}

UIImage* getAppIcon(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString* bundleID, NSString** error) {
    SpringBoardServicesClientHandle *client = NULL;
    IdeviceFfiError *err = springboard_services_connect_rsd(adapter, handshake, &client);
    if (err) {
        *error = [NSString stringWithUTF8String:err->message ?: "Failed to connect to SpringBoard Services"];
        idevice_error_free(err);
        return nil;
    }

    void *pngData = NULL;
    size_t dataLen = 0;
    err = springboard_services_get_icon(client, [bundleID UTF8String], &pngData, &dataLen);
    if (err) {
        *error = [NSString stringWithUTF8String:err->message ?: "Failed to get app icon"];
        idevice_error_free(err);
        springboard_services_free(client);
        return nil;
    }

    NSData *data = [NSData dataWithBytes:pngData length:dataLen];
    free(pngData);
    UIImage *icon = [UIImage imageWithData:data];

    springboard_services_free(client);
    return icon;
}

@implementation JITEnableContext(App)

- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return nil;
    }

    NSString* errorStr = nil;
    NSDictionary<NSString*, NSString*>* apps = list_installed_apps(adapter, handshake, &errorStr);
    if (errorStr) {
        *error = [self errorWithStr:errorStr code:-17];
        return nil;
    }
    return apps;
}

- (NSDictionary<NSString*, NSString*>*)getAllAppsWithError:(NSError**)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return nil;
    }

    NSString* errorStr = nil;
    NSDictionary<NSString*, NSString*>* apps = list_all_apps(adapter, handshake, &errorStr);
    if (errorStr) {
        *error = [self errorWithStr:errorStr code:-17];
        return nil;
    }
    return apps;
}

- (NSDictionary<NSString*, NSString*>*)getHiddenSystemAppsWithError:(NSError**)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return nil;
    }

    NSString* errorStr = nil;
    NSDictionary<NSString*, NSString*>* apps = list_hidden_system_apps(adapter, handshake, &errorStr);
    if (errorStr) {
        *error = [self errorWithStr:errorStr code:-17];
        return nil;
    }
    return apps;
}

- (NSArray<NSDictionary*>*)getSideloadedAppsWithError:(NSError**)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return nil;
    }

    NSString* errorStr = nil;
    NSArray<NSDictionary*>* apps = getSideloadedApps(adapter, handshake, &errorStr);
    if (errorStr) {
        *error = [self errorWithStr:errorStr code:-17];
        return nil;
    }
    return apps;
}

- (UIImage*)getAppIconWithBundleId:(NSString*)bundleId error:(NSError**)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return nil;
    }

    NSString* errorStr = nil;
    UIImage* icon = getAppIcon(adapter, handshake, bundleId, &errorStr);
    if (errorStr) {
        *error = [self errorWithStr:errorStr code:-17];
        return nil;
    }
    return icon;
}

@end

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

static NSString *extractAppName(plist_t app)
{
    plist_t displayNameNode = plist_dict_get_item(app, "CFBundleDisplayName");
    if (displayNameNode) {
        char *displayNameC = NULL;
        plist_get_string_val(displayNameNode, &displayNameC);
        if (displayNameC && displayNameC[0] != '\0') {
            NSString *displayName = [NSString stringWithUTF8String:displayNameC];
            free(displayNameC);
            return displayName;
        }
        free(displayNameC);
    }

    plist_t nameNode = plist_dict_get_item(app, "CFBundleName");
    if (nameNode) {
        char *nameC = NULL;
        plist_get_string_val(nameNode, &nameC);
        if (nameC && nameC[0] != '\0') {
            NSString *name = [NSString stringWithUTF8String:nameC];
            free(nameC);
            return name;
        }
        free(nameC);
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
            free(bidC);
            continue;
        }

        NSString *bundleID = [NSString stringWithUTF8String:bidC];
        free(bidC);

        result[bundleID] = extractAppName(app);
    }

    return result;
}

static NSDictionary<NSString*, NSString*> *performAppQuery(IdeviceProviderHandle *provider,
                                                           BOOL requireGetTaskAllow,
                                                           NSString **error,
                                                           BOOL (^filter)(plist_t app))
{
    InstallationProxyClientHandle *client = NULL;
    if (installation_proxy_connect(provider, &client)) {
        *error = @"Failed to connect to installation proxy";
        return nil;
    }

    void *apps = NULL;
    size_t count = 0;
    if (installation_proxy_get_apps(client, NULL, NULL, 0, &apps, &count)) {
        installation_proxy_client_free(client);
        *error = @"Failed to get apps";
        return nil;
    }

    NSDictionary<NSString*, NSString*> *result = buildAppDictionary(apps, count, requireGetTaskAllow, filter);
    installation_proxy_client_free(client);
    return result;
}

NSDictionary<NSString*, NSString*>* list_installed_apps(IdeviceProviderHandle* provider, NSString** error) {
    return performAppQuery(provider, YES, error, nil);
}

NSDictionary<NSString*, NSString*>* list_all_apps(IdeviceProviderHandle* provider, NSString** error) {
    return performAppQuery(provider, NO, error, nil);
}

NSDictionary<NSString*, NSString*>* list_hidden_system_apps(IdeviceProviderHandle* provider, NSString** error) {
    return performAppQuery(provider, NO, error, ^BOOL(plist_t app) {
        return isHiddenSystemApp(app);
    });
}

UIImage* getAppIcon(IdeviceProviderHandle* provider, NSString* bundleID, NSString** error) {
    SpringBoardServicesClientHandle *client = NULL;
    if (springboard_services_connect(provider, &client)) {
        *error = @"Failed to connect to SpringBoard Services";
        return nil;
    }

    void *pngData = NULL;
    size_t dataLen = 0;
    if (springboard_services_get_icon(client, [bundleID UTF8String], &pngData, &dataLen)) {
        springboard_services_free(client);
        *error = @"Failed to get app icon";
        return nil;
    }

    NSData *data = [NSData dataWithBytes:pngData length:dataLen];
    free(pngData);
    UIImage *icon = [UIImage imageWithData:data];

    springboard_services_free(client);
    return icon;
}

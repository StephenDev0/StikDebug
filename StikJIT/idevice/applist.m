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

NSDictionary<NSString*, NSString*>* list_installed_apps(IdeviceProviderHandle* provider, NSString** error) {
    InstallationProxyClientHandle *client = NULL;
    if (installation_proxy_connect_tcp(provider, &client)) {
        *error = @"Failed to connect to installation proxy";
        return nil;
    }

    void *apps = NULL;
    size_t count = 0;
    if (installation_proxy_get_apps(client, "User", NULL, 0, &apps, &count)) {
        installation_proxy_client_free(client);
        *error = @"Failed to get apps";
        return nil;
    }

    NSMutableDictionary<NSString*, NSString*> *result = [NSMutableDictionary dictionaryWithCapacity:count];

    for (size_t i = 0; i < count; i++) {
        plist_t app = ((plist_t *)apps)[i];
        plist_t ent = plist_dict_get_item(app, "Entitlements");
        if (!ent) continue;

        plist_t tnode = plist_dict_get_item(ent, "get-task-allow");
        if (!tnode) continue;

        uint8_t isAllowed = 0;
        plist_get_bool_val(tnode, &isAllowed);
        if (!isAllowed) continue;

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

        NSString *appName = @"Unknown";
        plist_t nameNode = plist_dict_get_item(app, "CFBundleName");
        if (nameNode) {
            char *nameC = NULL;
            plist_get_string_val(nameNode, &nameC);
            if (nameC && nameC[0] != '\0') {
                appName = [NSString stringWithUTF8String:nameC];
            }
            free(nameC);
        }

        result[bundleID] = appName;
    }

    installation_proxy_client_free(client);
    return result;
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

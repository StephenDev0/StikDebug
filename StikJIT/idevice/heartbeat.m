// Jackson Coxson
// heartbeat.c

#include "idevice.h"
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/_types/_u_int64_t.h>
#include <CoreFoundation/CoreFoundation.h>
#include <limits.h>
#include "heartbeat.h"


bool isHeartbeat = false;
NSDate* lastHeartbeatDate = nil;

void startHeartbeat(IdevicePairingFile* pairing_file, IdeviceProviderHandle** provider, bool* isHeartbeat, HeartbeatCompletionHandlerC completion, LogFuncC logger) {
    
    *isHeartbeat = true;
    // Initialize logger
    idevice_init_logger(Debug, Disabled, NULL);
    
    // Create the socket address (replace with your device's IP)
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(LOCKDOWN_PORT);
    inet_pton(AF_INET, "10.7.0.2", &addr.sin_addr);
    
    IdeviceFfiError* err = idevice_tcp_provider_new((struct sockaddr *)&addr, pairing_file,
                                                    "ExampleProvider", provider);
    if (err != NULL) {
        fprintf(stderr, "Failed to create TCP provider: [%d] %s", err->code,
                err->message);
        idevice_pairing_file_free(pairing_file);
        idevice_error_free(err);
        *isHeartbeat = false;
        return;
    }
    
    // Connect to installation proxy
    HeartbeatClientHandle *client = NULL;
    err = heartbeat_connect(*provider, &client);
    if (err != NULL) {
        fprintf(stderr, "Failed to connect to installation proxy: [%d] %s",
                err->code, err->message);
        idevice_provider_free(*provider);
        idevice_error_free(err);
        *isHeartbeat = false;
        return;
    }
    
    
    completion(0, "Heartbeat Completed");
    
    u_int64_t current_interval = 15;
    while (1) {
        // Get the new interval
        u_int64_t new_interval = 0;
        err = heartbeat_get_marco(client, current_interval, &new_interval);
        if (err != NULL) {
            fprintf(stderr, "Failed to get marco: [%d] %s", err->code, err->message);
            heartbeat_client_free(client);
            idevice_error_free(err);
            *isHeartbeat = false;
            return;
        }
        current_interval = new_interval + 5;
        
        // Reply
        err = heartbeat_send_polo(client);
        if (err != NULL) {
            fprintf(stderr, "Failed to get marco: [%d] %s", err->code, err->message);
            heartbeat_client_free(client);
            idevice_error_free(err);
            *isHeartbeat = false;
            return;
        }
    }
}

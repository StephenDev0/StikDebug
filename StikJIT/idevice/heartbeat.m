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

void startHeartbeat(IdevicePairingFile* pairing_file, TcpProviderHandle** provider, int* heartbeatSessionId, HeartbeatCompletionHandlerC completion, LogFuncC logger) {
    int currentSessionId = *heartbeatSessionId;
    
    isHeartbeat = true;
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    if (inet_pton(AF_INET, "10.7.0.1", &addr.sin_addr) <= 0) {
        logger("DEBUG: Error converting IP address.");
        isHeartbeat = false;
        return;
    }
    logger("DEBUG: Socket address created for IP 10.7.0.1");
    
    IdeviceErrorCode err = IdeviceSuccess;
    
    logger("DEBUG: Creating TCP provider...");
    err = idevice_tcp_provider_new((struct sockaddr *)&addr, pairing_file,
                                   "ExampleProvider", provider);
    if (err != IdeviceSuccess) {
        logger("DEBUG: Failed to create TCP provider: %d", err);
        completion(err, "Failed to create TCP provider");
        isHeartbeat = false;
        return;
    }
    logger("DEBUG: TCP provider created successfully.");
    
    logger("DEBUG: Connecting to heartbeat...");
    HeartbeatClientHandle *client = NULL;
    err = heartbeat_connect_tcp(*provider, &client);
    if (err != IdeviceSuccess) {
        completion(err, "Failed to connect to Heartbeat");
        logger("DEBUG: Failed to connect to installation proxy: %d", err);
        isHeartbeat = false;
        return;
    }
    logger("DEBUG: Connected to heartbeat successfully.");
    
    completion(0, "Heartbeat Completed");
    
    u_int64_t current_interval = 15;
    while (1) {
        if(*heartbeatSessionId != currentSessionId) {
            break;
        }
        
        u_int64_t new_interval = 0;
        logger("DEBUG: Sending heartbeat with current interval: %llu seconds...", current_interval);
        err = heartbeat_get_marco(client, current_interval, &new_interval);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to get marco: %d", err);
            isHeartbeat = false;
            heartbeat_client_free(client);
            return;
        }
        logger("DEBUG: Received new interval: %llu seconds.", new_interval);
        current_interval = new_interval + 5;
        
        logger("DEBUG: Sending polo reply...");
        err = heartbeat_send_polo(client);
        if (err != IdeviceSuccess) {
            logger("DEBUG: Failed to send polo: %d", err);
            isHeartbeat = false;
            heartbeat_client_free(client);
            return;
        }
        logger("DEBUG: Polo reply sent successfully.");
        lastHeartbeatDate = [NSDate date];
        isHeartbeat = true;
    }
}

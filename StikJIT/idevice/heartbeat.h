//
//  heartbeat.h
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

// heartbeat.h
#ifndef HEARTBEAT_H
#define HEARTBEAT_H
#include "idevice.h"

typedef void (^HeartbeatCompletionHandlerC)(int result, const char *message);
typedef void (^LogFuncC)(const char* message, ...);

extern bool isHeartbeat;

void startHeartbeat(const char* ipAddr, IdevicePairingFile* pairintFile, TcpProviderHandle** provider, int* heartbeatSessionId, HeartbeatCompletionHandlerC completion, LogFuncC logger);

#endif /* HEARTBEAT_H */

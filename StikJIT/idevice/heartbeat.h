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

void startHeartbeat(IdevicePairingFile* pairintFile, TcpProviderHandle** provider, int* heartbeatSessionId, HeartbeatCompletionHandlerC completion, LogFuncC logger);
void setHeartbeatIP(const char* ip);

#endif /* HEARTBEAT_H */

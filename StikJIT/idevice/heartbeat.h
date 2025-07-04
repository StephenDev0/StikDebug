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
@import Foundation;

typedef void (^HeartbeatCompletionHandlerC)(int result, const char *message);
typedef void (^LogFuncC)(const char* message, ...);

extern bool isHeartbeat;
extern NSDate* lastHeartbeatDate;

void startHeartbeat(IdevicePairingFile* pairintFile, IdeviceProviderHandle** provider, bool* isHeartbeat, HeartbeatCompletionHandlerC completion, LogFuncC logger);

#endif /* HEARTBEAT_H */

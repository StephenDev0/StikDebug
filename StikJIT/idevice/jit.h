//
//  jit.h
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

// jit.h
#ifndef JIT_H
#define JIT_H
#include "idevice.h"

typedef void (^LogFuncC)(const char* message, ...);
typedef void (^DebugAppCallback)(int pid, struct DebugProxyAdapterHandle* debug_proxy, dispatch_semaphore_t semaphore);
int debug_app(TcpProviderHandle* tcp_provider, const char *bundle_id, LogFuncC logger, DebugAppCallback callback);
IdeviceErrorCode debug_proxy_send_command2(struct DebugProxyAdapterHandle *handle, struct DebugserverCommandHandle *command, char **response);
int debug_app_pid(TcpProviderHandle* tcp_provider, int pid, LogFuncC logger, DebugAppCallback callback);

#endif /* JIT_H */

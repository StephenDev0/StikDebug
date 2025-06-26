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
int debug_app(TcpProviderHandle* provider, const char *bundle_id, LogFuncC logger);
int debug_app_pid(TcpProviderHandle* provider, int pid, LogFuncC logger);

int start_debug_session(TcpProviderHandle* provider, const char *bundle_id, LogFuncC logger);
int start_debug_session_pid(TcpProviderHandle* provider, int pid, LogFuncC logger);
void detach_debug_session(LogFuncC logger);

#endif /* JIT_H */

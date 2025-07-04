//
//  JSSupport.h
//  StikJIT
//
//  Created by s s on 2025/4/24.
//
@import WebKit;
@import JavaScriptCore;
#include "../idevice/jit.h"

NSString* handleJSContextSendDebugCommand(JSContext* context, NSString* commandStr, DebugProxyHandle* debugProxy);

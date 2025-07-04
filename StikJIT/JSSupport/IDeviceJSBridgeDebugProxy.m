//
//  IDeviceJSBridgeDebugProxy.m
//  StikJIT
//
//  Created by s s on 2025/4/25.
//
@import Foundation;
@import JavaScriptCore;
#import "JSSupport.h"
#import "../idevice/JITEnableContext.h"
#import "../idevice/idevice.h"
#include "../idevice/jit.h"

NSString* handleJSContextSendDebugCommand(JSContext* context, NSString* commandStr, DebugProxyAdapterHandle* debugProxy) {
    DebugserverCommandHandle* command = 0;

    command = debugserver_command_new([commandStr UTF8String], NULL, 0);

    char* attach_response = 0;
    IdeviceErrorCode err = debug_proxy_send_command2(debugProxy, command, &attach_response);
    debugserver_command_free(command);
    if (err != IdeviceSuccess) {
        context.exception = [JSValue valueWithObject:[NSString stringWithFormat:@"error code %d", err] inContext:context];
        return nil;
    }
    NSString* commandResponse = nil;
    if(attach_response) {
        commandResponse = @(attach_response);
    }
    idevice_string_free(attach_response);
    return commandResponse;
}

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

NSString* handleJSContextSendDebugCommand(JSContext* context, NSString* commandStr, DebugProxyHandle* debugProxy) {
    DebugserverCommandHandle* command = 0;

    command = debugserver_command_new([commandStr UTF8String], NULL, 0);

    char* attach_response = 0;
    IdeviceFfiError* err = debug_proxy_send_command(debugProxy, command, &attach_response);
    debugserver_command_free(command);
    if (err) {
        context.exception = [JSValue valueWithObject:[NSString stringWithFormat:@"error code %d, msg %s", err->code, err->message] inContext:context];
        idevice_error_free(err);
        return nil;
    }
    NSString* commandResponse = nil;
    if(attach_response) {
        commandResponse = @(attach_response);
    }
    idevice_string_free(attach_response);
    return commandResponse;
}

// 0 <= val <= 15
char u8toHexChar(uint8_t val) {
    if(val < 10) {
        return val + '0';
    } else {
        return val + 87;
    }
}

void calcAndWriteCheckSum(char* commandStart) {
    uint8_t sum = 0;
    char* cur = commandStart;
    for(; *cur != '#'; ++cur) {
        sum += *cur;
    }
    cur[1] = u8toHexChar((sum & 0xf0) >> 4);
    cur[2] = u8toHexChar(sum & 0xf);
}

// support up to 9 digit
void writeAddress(char* writeStart, uint64_t addr) {
    writeStart[0] = u8toHexChar((addr & 0xf00000000) >> 32);
    writeStart[1] = u8toHexChar((addr & 0xf0000000) >> 28);
    writeStart[2] = u8toHexChar((addr & 0xf000000) >> 24);
    writeStart[3] = u8toHexChar((addr & 0xf00000) >> 20);
    writeStart[4] = u8toHexChar((addr & 0xf0000) >> 16);
    writeStart[5] = u8toHexChar((addr & 0xf000) >> 12);
    writeStart[6] = u8toHexChar((addr & 0xf00) >> 8);
    writeStart[7] = u8toHexChar((addr & 0xf0) >> 4);
    writeStart[8] = u8toHexChar((addr & 0xf));
}

// you need to free generated buffer
char* getBulkMemWriteCommand(uint64_t startAddr, uint64_t JITPagesSize, uint32_t* commandCountOut, uint32_t* bufferLengthOut) {
    // $M10c128000,1:69#12
    uint32_t commandCount = (uint32_t)(JITPagesSize >> 14);
    uint32_t commandBufferSize = commandCount * 19;
    *commandCountOut = commandCount;
    *bufferLengthOut = commandBufferSize;
    char* buffer = malloc(commandBufferSize + 1);
    char* bufferEnd = buffer + commandBufferSize;
    buffer[commandBufferSize] = 0;
    
    uint64_t curAddr = startAddr;
    for(char* curBufferPtr = buffer; curBufferPtr < bufferEnd; curBufferPtr += 19) {
        curBufferPtr[0] = '$';
        curBufferPtr[1] = 'M';
        curBufferPtr[11] = ',';
        curBufferPtr[12] = '1';
        curBufferPtr[13] = ':';
        curBufferPtr[14] = '6';
        curBufferPtr[15] = '9';
        curBufferPtr[16] = '#';
        writeAddress(curBufferPtr + 2, curAddr);
        calcAndWriteCheckSum(curBufferPtr + 1);
        curAddr += 16384;
    }
    return buffer;
}

NSString* handleJITPageWrite(JSContext* context, uint64_t startAddr, uint64_t JITPagesSize, DebugProxyHandle* debugProxy) {
    uint32_t bufferLength = 0;
    uint32_t commandCount = 0;
    char* commandBuffer = getBulkMemWriteCommand(startAddr, JITPagesSize, &commandCount, &bufferLength);
    // we send 1024 commands at a time
    for(int curCommand = 0; curCommand < commandCount; curCommand += 1024) {
        uint32_t commandsToSend = (commandCount - curCommand > 1024) ? 1024 : (commandCount - curCommand);
        IdeviceFfiError* err = debug_proxy_send_raw(debugProxy, (const uint8_t *)commandBuffer + curCommand * 19, commandsToSend * 19);
        if(err) {
            context.exception = [JSValue valueWithObject:[NSString stringWithFormat:@"error code %d, msg %s", err->code, err->message] inContext:context];
            free(commandBuffer);
            idevice_error_free(err);
            return nil;
        }
        
        for(int i = 0; i < commandsToSend; ++i) {
            char* response = 0;
            IdeviceFfiError* err = debug_proxy_read_response(debugProxy, &response);
            if(response) {
                idevice_string_free(response);
            }
            if(err) {
                context.exception = [JSValue valueWithObject:[NSString stringWithFormat:@"error code %d, msg %s", err->code, err->message] inContext:context];
                free(commandBuffer);
                idevice_error_free(err);
                return nil;
            }
        }
    }
    free(commandBuffer);
    return @"OK";
}

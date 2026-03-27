//
//  JITEnableContext.m
//  StikJIT
//
//  Created by s s on 2025/3/28.
//
#include "idevice.h"
#include <arpa/inet.h>
#include <signal.h>
#include <stdlib.h>

#include "jit.h"
#include "applist.h"
#include "profiles.h"

#include "JITEnableContext.h"
#import "StikDebug-Swift.h"
#include <os/lock.h>
#import <pthread.h>

static JITEnableContext* sharedJITContext = nil;

@implementation JITEnableContext {
    NSError* lastTunnelError;
    os_unfair_lock tunnelLock;
    BOOL tunnelConnecting;
    dispatch_semaphore_t tunnelSemaphore;
}

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedJITContext = [[JITEnableContext alloc] init];
    });
    return sharedJITContext;
}

- (instancetype)init {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* docPathUrl = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL* logURL = [docPathUrl URLByAppendingPathComponent:@"idevice_log.txt"];
    idevice_init_logger(Info, Debug, (char*)logURL.path.UTF8String);
    syslogQueue = dispatch_queue_create("com.stik.syslogrelay.queue", DISPATCH_QUEUE_SERIAL);
    syslogStreaming = NO;
    syslogClient = NULL;
    dispatch_queue_attr_t qosAttr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
    processInspectorQueue = dispatch_queue_create("com.stikdebug.processInspector", qosAttr);

    tunnelLock = OS_UNFAIR_LOCK_INIT;
    tunnelConnecting = NO;
    tunnelSemaphore = NULL;
    lastTunnelError = nil;

    return self;
}

- (NSError*)errorWithStr:(NSString*)str code:(int)code {
    return [NSError errorWithDomain:@"StikJIT"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: str }];
}

- (LogFuncC)createCLogger:(LogFunc)logger {
    return ^(const char* format, ...) {
        va_list args;
        va_start(args, format);
        NSString* fmt = [NSString stringWithCString:format encoding:NSASCIIStringEncoding];
        NSString* message = [[NSString alloc] initWithFormat:fmt arguments:args];

        if ([message containsString:@"ERROR"] || [message containsString:@"Error"]) {
            [[LogManagerBridge shared] addErrorLog:message];
        } else if ([message containsString:@"WARNING"] || [message containsString:@"Warning"]) {
            [[LogManagerBridge shared] addWarningLog:message];
        } else if ([message containsString:@"DEBUG"]) {
            [[LogManagerBridge shared] addDebugLog:message];
        } else {
            [[LogManagerBridge shared] addInfoLog:message];
        }

        if (logger) {
            logger(message);
        }
        va_end(args);
    };
}

- (RpPairingFileHandle*)getPairingFileWithError:(NSError**)error {
    NSFileManager* fm = [NSFileManager defaultManager];
    NSURL* docPathUrl = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL* pairingFileURL = [docPathUrl URLByAppendingPathComponent:@"pairingFile.plist"];

    if (![fm fileExistsAtPath:pairingFileURL.path]) {
        *error = [self errorWithStr:@"Pairing file not found!" code:-17];
        return nil;
    }

    RpPairingFileHandle* pairingFile = NULL;
    IdeviceFfiError* err = rp_pairing_file_read(pairingFileURL.fileSystemRepresentation, &pairingFile);
    if (err) {
        *error = [self errorWithStr:@"Failed to read pairing file!" code:err->code];
        idevice_error_free(err);
        return nil;
    }
    return pairingFile;
}

- (BOOL)startTunnel:(NSError**)err {
    os_unfair_lock_lock(&tunnelLock);

    // If tunnel is already being created, wait for it to complete
    if (tunnelConnecting) {
        dispatch_semaphore_t waitSemaphore = tunnelSemaphore;
        os_unfair_lock_unlock(&tunnelLock);

        if (waitSemaphore) {
            dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_FOREVER);
            dispatch_semaphore_signal(waitSemaphore);
        }
        *err = lastTunnelError;
        return *err == nil;
    }

    // Mark tunnel as connecting
    tunnelConnecting = YES;
    tunnelSemaphore = dispatch_semaphore_create(0);
    dispatch_semaphore_t completionSemaphore = tunnelSemaphore;
    os_unfair_lock_unlock(&tunnelLock);

    RpPairingFileHandle* pairingFile = [self getPairingFileWithError:err];
    if (*err) {
        os_unfair_lock_lock(&tunnelLock);
        tunnelConnecting = NO;
        tunnelSemaphore = NULL;
        os_unfair_lock_unlock(&tunnelLock);
        dispatch_semaphore_signal(completionSemaphore);
        return NO;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(49152);

    NSString* deviceIP = [[NSUserDefaults standardUserDefaults] stringForKey:@"customTargetIP"];
    inet_pton(AF_INET, (deviceIP && deviceIP.length > 0) ? [deviceIP UTF8String] : "10.7.0.1", &addr.sin_addr);

    AdapterHandle *newAdapter = NULL;
    RsdHandshakeHandle *newHandshake = NULL;
    IdeviceFfiError *ffiErr = tunnel_create_rppairing(
        (const idevice_sockaddr *)&addr,
        sizeof(addr),
        "StikDebug",
        pairingFile,
        NULL,
        NULL,
        &newAdapter,
        &newHandshake
    );
    rp_pairing_file_free(pairingFile);

    if (ffiErr) {
        *err = [self errorWithStr:[NSString stringWithUTF8String:ffiErr->message ?: "Failed to create tunnel"]
                             code:ffiErr->code];
        lastTunnelError = *err;
        idevice_error_free(ffiErr);
    } else {
        // Clean up old tunnel if any
        if (handshake) { rsd_handshake_free(handshake); }
        if (adapter) { adapter_free(adapter); }
        adapter = newAdapter;
        handshake = newHandshake;
        lastTunnelError = nil;
    }

    os_unfair_lock_lock(&tunnelLock);
    tunnelConnecting = NO;
    tunnelSemaphore = NULL;
    os_unfair_lock_unlock(&tunnelLock);
    dispatch_semaphore_signal(completionSemaphore);

    return *err == nil;
}

- (BOOL)ensureTunnelWithError:(NSError**)err {
    if (!adapter || !handshake) {
        return [self startTunnel:err];
    }
    return YES;
}

- (void)dealloc {
    [self stopSyslogRelay];
    if (handshake) {
        rsd_handshake_free(handshake);
    }
    if (adapter) {
        adapter_free(adapter);
    }
}

@end

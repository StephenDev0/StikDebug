//
//  jit.c
//  StikJIT
//
//  Created by Stephen on 3/27/25.
//

// Jackson Coxson

#include <arpa/inet.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <limits.h>

#include "jit.h"
#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"

// MARK: - Shared debug session

typedef struct {
    RemoteServerHandle *remote_server;
    DebugProxyHandle   *debug_proxy;
} DebugSession;

static void debug_session_free(DebugSession *s) {
    if (s->debug_proxy)   { debug_proxy_free(s->debug_proxy);     s->debug_proxy   = NULL; }
    if (s->remote_server) { remote_server_free(s->remote_server); s->remote_server = NULL; }
}

// Connects to the device using the existing adapter+handshake and sets up the debug proxy.
// Returns 0 on success; cleans up any partial state and returns 1 on failure.
static int connect_debug_session(AdapterHandle *adapter, RsdHandshakeHandle *handshake, DebugSession *out) {
    memset(out, 0, sizeof(*out));
    IdeviceFfiError *err = NULL;

    err = remote_server_connect_rsd(adapter, handshake, &out->remote_server);
    if (err) { idevice_error_free(err); return 1; }

    err = debug_proxy_connect_rsd(adapter, handshake, &out->debug_proxy);
    if (err) { idevice_error_free(err); debug_session_free(out); return 1; }

    return 0;
}

// MARK: - Debug server commands

void runDebugServerCommand(int pid,
                           DebugProxyHandle* debug_proxy,
                           RemoteServerHandle* remote_server,
                           LogFuncC logger,
                           DebugAppCallback callback) {
    // Enable QStartNoAckMode
    char *disableResponse = NULL;
    debug_proxy_send_ack(debug_proxy);
    debug_proxy_send_ack(debug_proxy);
    DebugserverCommandHandle *disableAckCommand = debugserver_command_new("QStartNoAckMode", NULL, 0);
    IdeviceFfiError* err = debug_proxy_send_command(debug_proxy, disableAckCommand, &disableResponse);
    debugserver_command_free(disableAckCommand);
    logger("QStartNoAckMode result = %s, err = %d", disableResponse, err);
    idevice_string_free(disableResponse);
    debug_proxy_set_ack_mode(debug_proxy, false);

    if (callback) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        callback(pid, debug_proxy, remote_server, semaphore);
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        err = debug_proxy_send_raw(debug_proxy, "\x03", 1);
        usleep(500);
    } else {
        char attach_command[64];
        snprintf(attach_command, sizeof(attach_command), "vAttach;%" PRIx64, pid);

        DebugserverCommandHandle *attach_cmd = debugserver_command_new(attach_command, NULL, 0);
        if (attach_cmd == NULL) {
            logger("Failed to create attach command");
            return;
        }

        char *attach_response = NULL;
        err = debug_proxy_send_command(debug_proxy, attach_cmd, &attach_response);
        debugserver_command_free(attach_cmd);
        if (err) {
            logger("Failed to attach to process: %d", err->code);
            idevice_error_free(err);
        } else if (attach_response != NULL) {
            logger("Attach response: %s", attach_response);
            idevice_string_free(attach_response);
        }
    }

    // Send detach command
    DebugserverCommandHandle *detach_cmd = debugserver_command_new("D", NULL, 0);
    if (detach_cmd == NULL) {
        logger("Failed to create detach command");
    } else {
        char *detach_response = NULL;
        err = debug_proxy_send_command(debug_proxy, detach_cmd, &detach_response);
        debugserver_command_free(detach_cmd);
        if (err) {
            logger("Failed to detach from process: %d", err->code);
            idevice_error_free(err);
        } else if (detach_response != NULL) {
            logger("Detach response: %s", detach_response);
            idevice_string_free(detach_response);
        }
    }
}

// MARK: - Public entry points

int debug_app(AdapterHandle* adapter, RsdHandshakeHandle* handshake, const char *bundle_id, LogFuncC logger, DebugAppCallback callback) {
    DebugSession session;
    if (connect_debug_session(adapter, handshake, &session) != 0) return 1;

    ProcessControlHandle *process_control = NULL;
    IdeviceFfiError *err = process_control_new(session.remote_server, &process_control);
    if (err) {
        idevice_error_free(err);
        debug_session_free(&session);
        return 1;
    }

    uint64_t pid = 0;
    err = process_control_launch_app(process_control, bundle_id, NULL, 0, NULL, 0, true, false, &pid);
    if (err) {
        idevice_error_free(err);
        process_control_free(process_control);
        debug_session_free(&session);
        return 1;
    }

    runDebugServerCommand((int)pid, session.debug_proxy, session.remote_server, logger, callback);

    process_control_free(process_control);
    debug_session_free(&session);
    logger("Debug session completed");
    return 0;
}

int debug_app_pid(AdapterHandle* adapter, RsdHandshakeHandle* handshake, int pid, LogFuncC logger, DebugAppCallback callback) {
    DebugSession session;
    if (connect_debug_session(adapter, handshake, &session) != 0) return 1;

    runDebugServerCommand(pid, session.debug_proxy, session.remote_server, logger, callback);

    debug_session_free(&session);
    logger("Debug session completed");
    return 0;
}

int launch_app_via_proxy(AdapterHandle* adapter, RsdHandshakeHandle* handshake, const char *bundle_id, LogFuncC logger) {
    IdeviceFfiError* err = NULL;

    RemoteServerHandle *remote_server = NULL;
    ProcessControlHandle *process_control = NULL;
    uint64_t pid = 0;
    int result = 1;

    err = remote_server_connect_rsd(adapter, handshake, &remote_server);
    if (err) { idevice_error_free(err); goto cleanup; }

    err = process_control_new(remote_server, &process_control);
    if (err) { idevice_error_free(err); goto cleanup; }

    err = process_control_launch_app(process_control, bundle_id, NULL, 0, NULL, 0, false, true, &pid);
    if (err) {
        idevice_error_free(err);
        if (logger) logger("Failed to launch app: %s", bundle_id);
        goto cleanup;
    }

    if (logger) logger("Launched app (PID %llu)", pid);
    result = 0;

cleanup:
    if (process_control) process_control_free(process_control);
    if (remote_server)   remote_server_free(remote_server);
    return result;
}


@implementation JITEnableContext(JIT)

- (BOOL)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger jsCallback:(DebugAppCallback)jsCallback {
    NSError* err = nil;
    [self ensureTunnelWithError:&err];
    if (err) {
        logger(err.localizedDescription);
        return NO;
    }
    return debug_app(adapter, handshake, [bundleID UTF8String], [self createCLogger:logger], jsCallback) == 0;
}

- (BOOL)debugAppWithPID:(int)pid logger:(LogFunc)logger jsCallback:(DebugAppCallback)jsCallback {
    NSError* err = nil;
    [self ensureTunnelWithError:&err];
    if (err) {
        logger(err.localizedDescription);
        return NO;
    }
    return debug_app_pid(adapter, handshake, pid, [self createCLogger:logger], jsCallback) == 0;
}

- (BOOL)launchAppWithoutDebug:(NSString*)bundleID logger:(LogFunc)logger {
    NSError* err = nil;
    [self ensureTunnelWithError:&err];
    if (err) {
        logger(err.localizedDescription);
        return NO;
    }
    return launch_app_via_proxy(adapter, handshake, [bundleID UTF8String], [self createCLogger:logger]) == 0;
}

@end

//
//  process.m
//  StikDebug
//
//  Created by s s on 2025/12/12.
//

#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"
@import Foundation;

// MARK: - Shared AppService session

typedef struct {
    AppServiceHandle   *appService;
} AppServiceSession;

static void app_service_session_free(AppServiceSession *s) {
    if (s->appService) { app_service_free(s->appService);      s->appService = NULL; }
}

// Connects to the device via the existing adapter+handshake → AppService.
// Returns 0 on success; cleans up any partial state and returns 1 on failure.
static int connect_app_service(AdapterHandle *adapter,
                                RsdHandshakeHandle *handshake,
                                AppServiceSession *out,
                                JITEnableContext *ctx,
                                NSError **outError)
{
    memset(out, 0, sizeof(*out));
    IdeviceFfiError *ffiError = NULL;

    ffiError = app_service_connect_rsd(adapter, handshake, &out->appService);
    if (ffiError) {
        *outError = [ctx errorWithStr:[NSString stringWithUTF8String:ffiError->message ?: "Unable to open AppService"]
                                 code:ffiError->code];
        idevice_error_free(ffiError);
        return 1;
    }

    return 0;
}

// MARK: - JITEnableContext(Process)

@implementation JITEnableContext(Process)

- (NSArray<NSDictionary*>*)fetchProcessesViaAppServiceWithError:(NSError **)error {
    [self ensureTunnelWithError:error];
    if (*error) { return nil; }

    AppServiceSession session;
    if (connect_app_service(adapter, handshake, &session, self, error) != 0) { return nil; }

    ProcessTokenC *processes = NULL;
    uintptr_t count = 0;
    IdeviceFfiError *ffiError = app_service_list_processes(session.appService, &processes, &count);

    NSMutableArray *result = nil;
    if (ffiError) {
        if (error) {
            *error = [self errorWithStr:[NSString stringWithUTF8String:ffiError->message ?: "Failed to list processes"]
                                   code:ffiError->code];
        }
        idevice_error_free(ffiError);
    } else {
        result = [NSMutableArray arrayWithCapacity:count];
        for (uintptr_t idx = 0; idx < count; idx++) {
            ProcessTokenC proc = processes[idx];
            NSMutableDictionary *entry = [NSMutableDictionary dictionary];
            entry[@"pid"] = @(proc.pid);
            if (proc.executable_url) {
                entry[@"path"] = [NSString stringWithUTF8String:proc.executable_url];
            }
            [result addObject:entry];
        }
        if (processes && count > 0) {
            app_service_free_process_list(processes, count);
        }
    }

    app_service_session_free(&session);
    return result;
}

- (NSArray<NSDictionary*>*)_fetchProcessListLocked:(NSError**)error {
    [self ensureTunnelWithError:error];
    if (*error) { return nil; }
    return [self fetchProcessesViaAppServiceWithError:error];
}

- (NSArray<NSDictionary*>*)fetchProcessListWithError:(NSError**)error {
    __block NSArray *result = nil;
    __block NSError *localError = nil;
    dispatch_sync(processInspectorQueue, ^{
        result = [self _fetchProcessListLocked:&localError];
    });
    if (error && localError) {
        *error = localError;
    }
    return result;
}

- (BOOL)killProcessWithPID:(int)pid error:(NSError **)error {
    [self ensureTunnelWithError:error];
    if (*error) { return NO; }

    AppServiceSession session;
    if (connect_app_service(adapter, handshake, &session, self, error) != 0) { return NO; }

    SignalResponseC *signalResponse = NULL;
    IdeviceFfiError *ffiError = app_service_send_signal(session.appService, (uint32_t)pid, SIGKILL, &signalResponse);

    BOOL success = NO;
    if (ffiError) {
        if (error) {
            *error = [self errorWithStr:[NSString stringWithUTF8String:ffiError->message ?: "Failed to kill process"]
                                   code:ffiError->code];
        }
        idevice_error_free(ffiError);
    } else {
        success = YES;
    }

    if (signalResponse) { app_service_free_signal_response(signalResponse); }
    app_service_session_free(&session);
    return success;
}

@end

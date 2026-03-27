//
//  syslog.m
//  StikDebug
//
//  Created by s s on 2025/12/12.
//

#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"

@implementation JITEnableContext(Syslog)

- (void)startSyslogRelayWithHandler:(SyslogLineHandler)lineHandler
                             onError:(SyslogErrorHandler)errorHandler
{
    NSError* error = nil;
    [self ensureTunnelWithError:&error];
    if(error) {
        errorHandler(error);
        return;
    }
    if (!lineHandler || syslogStreaming) {
        return;
    }

    syslogStreaming = YES;
    syslogLineHandler = [lineHandler copy];
    syslogErrorHandler = [errorHandler copy];

    __weak typeof(self) weakSelf = self;
    dispatch_async(syslogQueue, ^{
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        SyslogRelayClientHandle *client = NULL;
        IdeviceFfiError *err = syslog_relay_connect_rsd(strongSelf->adapter, strongSelf->handshake, &client);
        if (err != NULL) {
            NSString *message = err->message ? [NSString stringWithCString:err->message encoding:NSASCIIStringEncoding] : @"Failed to connect to syslog relay";
            NSError *nsError = [strongSelf errorWithStr:message code:err->code];
            idevice_error_free(err);
            [strongSelf handleSyslogFailure:nsError];
            return;
        }

        strongSelf->syslogClient = client;

        while (strongSelf && strongSelf->syslogStreaming) {
            char *message = NULL;
            IdeviceFfiError *nextErr = syslog_relay_next(client, &message);
            if (nextErr != NULL) {
                NSString *errMsg = nextErr->message ? [NSString stringWithCString:nextErr->message encoding:NSASCIIStringEncoding] : @"Syslog relay read failed";
                NSError *nsError = [strongSelf errorWithStr:errMsg code:nextErr->code];
                idevice_error_free(nextErr);
                if (message) { idevice_string_free(message); }
                [strongSelf handleSyslogFailure:nsError];
                client = NULL;
                break;
            }

            if (!message) {
                continue;
            }

            NSString *line = [NSString stringWithCString:message encoding:NSUTF8StringEncoding];
            idevice_string_free(message);
            if (!line || !strongSelf->syslogLineHandler) {
                continue;
            }

            SyslogLineHandler handlerCopy = strongSelf->syslogLineHandler;
            if (handlerCopy) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handlerCopy(line);
                });
            }
        }

        if (client) {
            syslog_relay_client_free(client);
        }

        strongSelf->syslogClient = NULL;
        strongSelf->syslogStreaming = NO;
        strongSelf->syslogLineHandler = nil;
        strongSelf->syslogErrorHandler = nil;
    });
}

- (void)stopSyslogRelay {
    if (!syslogStreaming) {
        return;
    }

    syslogStreaming = NO;
    syslogLineHandler = nil;
    syslogErrorHandler = nil;

    dispatch_async(syslogQueue, ^{
        if (self->syslogClient) {
            syslog_relay_client_free(self->syslogClient);
            self->syslogClient = NULL;
        }
    });
}

- (void)handleSyslogFailure:(NSError *)error {
    syslogStreaming = NO;
    if (syslogClient) {
        syslog_relay_client_free(syslogClient);
        syslogClient = NULL;
    }
    SyslogErrorHandler errorCopy = syslogErrorHandler;
    syslogLineHandler = nil;
    syslogErrorHandler = nil;

    if (errorCopy) {
        dispatch_async(dispatch_get_main_queue(), ^{
            errorCopy(error);
        });
    }
}



@end

//
//  JITEnableContext.h
//  StikJIT
//
//  Created by s s on 2025/3/28.
//
@import Foundation;
@import UIKit;
#include "idevice.h"
#include "jit.h"
#include "mount.h"

typedef void (^LogFuncC)(const char* message, ...);
typedef void (^LogFunc)(NSString *message);
typedef void (^SyslogLineHandler)(NSString *line);
typedef void (^SyslogErrorHandler)(NSError *error);

@interface JITEnableContext : NSObject {
    // tunnel
    @protected AdapterHandle *adapter;
    @protected RsdHandshakeHandle *handshake;

    // process
    @protected dispatch_queue_t processInspectorQueue;

    // syslog
    @protected dispatch_queue_t syslogQueue;
    @protected BOOL syslogStreaming;
    @protected SyslogRelayClientHandle *syslogClient;
    @protected SyslogLineHandler syslogLineHandler;
    @protected SyslogErrorHandler syslogErrorHandler;

    // ideviceInfo
    @protected LockdowndClientHandle *   g_client;
}
@property (class, readonly)JITEnableContext* shared;
- (RpPairingFileHandle*)getPairingFileWithError:(NSError**)error;
- (BOOL)ensureTunnelWithError:(NSError**)err;
- (BOOL)startTunnel:(NSError**)err;

@end

@interface JITEnableContext(JIT)
- (BOOL)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger jsCallback:(DebugAppCallback)jsCallback;
- (BOOL)debugAppWithPID:(int)pid logger:(LogFunc)logger jsCallback:(DebugAppCallback)jsCallback;
- (BOOL)launchAppWithoutDebug:(NSString*)bundleID logger:(LogFunc)logger;
@end

@interface JITEnableContext(DDI)
- (NSUInteger)getMountedDeviceCount:(NSError**)error __attribute__((swift_error(zero_result)));
- (NSInteger)mountPersonalDDIWithImagePath:(NSString*)imagePath trustcachePath:(NSString*)trustcachePath manifestPath:(NSString*)manifestPath error:(NSError**)error __attribute__((swift_error(nonzero_result)));
@end

@interface JITEnableContext(Profile)
- (NSArray<NSData*>*)fetchAllProfiles:(NSError **)error;
- (BOOL)removeProfileWithUUID:(NSString*)uuid error:(NSError **)error;
- (BOOL)addProfile:(NSData*)profile error:(NSError **)error;
@end

@interface JITEnableContext(Process)
- (NSArray<NSDictionary*>*)fetchProcessListWithError:(NSError**)error;
- (BOOL)killProcessWithPID:(int)pid error:(NSError **)error;
@end

@interface JITEnableContext(App)
- (UIImage*)getAppIconWithBundleId:(NSString*)bundleId error:(NSError**)error;
- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error;
- (NSDictionary<NSString*, NSString*>*)getAllAppsWithError:(NSError**)error;
- (NSDictionary<NSString*, NSString*>*)getHiddenSystemAppsWithError:(NSError**)error;
- (NSArray<NSDictionary*>*)getSideloadedAppsWithError:(NSError**)error;
@end

@interface JITEnableContext(Syslog)
- (void)startSyslogRelayWithHandler:(SyslogLineHandler)lineHandler
                             onError:(SyslogErrorHandler)errorHandler NS_SWIFT_NAME(startSyslogRelay(handler:onError:));
- (void)stopSyslogRelay;
@end

@interface JITEnableContext(DeviceInfo)
- (LockdowndClientHandle*)ideviceInfoInit:(NSError**)error;
- (char*)ideviceInfoGetXMLWithLockdownClient:(LockdowndClientHandle*)lockdownClient error:(NSError**)error;
@end

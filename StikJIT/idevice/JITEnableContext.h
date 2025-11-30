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

typedef void (^HeartbeatCompletionHandler)(int result, NSString *message);
typedef void (^LogFuncC)(const char* message, ...);
typedef void (^LogFunc)(NSString *message);
typedef void (^SyslogLineHandler)(NSString *line);
typedef void (^SyslogErrorHandler)(NSError *error);

@interface JITEnableContext : NSObject
@property (class, readonly)JITEnableContext* shared;
- (IdevicePairingFile*)getPairingFileWithError:(NSError**)error;
- (void)startHeartbeatWithCompletionHandler:(HeartbeatCompletionHandler)completionHandler logger:(LogFunc)logger;
- (BOOL)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger jsCallback:(DebugAppCallback)jsCallback;
- (BOOL)debugAppWithPID:(int)pid logger:(LogFunc)logger jsCallback:(DebugAppCallback)jsCallback;
- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error;
- (NSDictionary<NSString*, NSString*>*)getAllAppsWithError:(NSError**)error;
- (NSDictionary<NSString*, NSString*>*)getHiddenSystemAppsWithError:(NSError**)error;
- (UIImage*)getAppIconWithBundleId:(NSString*)bundleId error:(NSError**)error;
- (BOOL)launchAppWithoutDebug:(NSString*)bundleID logger:(LogFunc)logger;
- (void)startSyslogRelayWithHandler:(SyslogLineHandler)lineHandler
                             onError:(SyslogErrorHandler)errorHandler NS_SWIFT_NAME(startSyslogRelay(handler:onError:));
- (void)stopSyslogRelay;
- (NSArray<NSData*>*)fetchAllProfiles:(NSError **)error;
- (BOOL)removeProfileWithUUID:(NSString*)uuid error:(NSError **)error;
- (BOOL)addProfile:(NSData*)profile error:(NSError **)error;
@end

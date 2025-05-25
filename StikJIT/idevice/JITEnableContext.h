//
//  JITEnableContext.h
//  StikJIT
//
//  Created by s s on 2025/3/28.
//
@import Foundation;
@import UIKit;
#include "idevice.h"

typedef void (^HeartbeatCompletionHandler)(int result, NSString *message);
typedef void (^LogFuncC)(const char* message, ...);
typedef void (^LogFunc)(NSString *message);

@interface JITEnableContext : NSObject
@property (class, readonly)JITEnableContext* shared;
- (IdevicePairingFile*)getPairingFileWithError:(NSError**)error;
- (void)startHeartbeatWithCompletionHandler:(HeartbeatCompletionHandler)completionHandler logger:(LogFunc)logger;
- (BOOL)debugAppWithBundleID:(NSString*)bundleID logger:(LogFunc)logger;
- (BOOL)debugAppWithPID:(int)pid logger:(LogFunc)logger;
- (NSDictionary<NSString*, NSString*>*)getAppListWithError:(NSError**)error;
- (UIImage*)getAppIconWithBundleId:(NSString*)bundleId error:(NSError**)error;
@end

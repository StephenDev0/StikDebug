//
//  JSSupport.h
//  StikJIT
//
//  Created by s s on 2025/4/24.
//
#import "../../idevice/JITEnableContext.h"
#import "../../idevice/idevice.h"
@import JavaScriptCore;

@interface NSInvocation(MCUtilities)
-(void)invokeOnMainThreadWaitUntilDone:(BOOL)wait;
+(NSInvocation*)invocationWithTarget:(id)target
                            selector:(SEL)aSelector
                     retainArguments:(BOOL)retainArguments, ...;
@end

@interface IDeviceHandle : NSObject
@property void* handle;
@property void* freeFunc;
@end

@interface IDeviceJSBridge : NSObject {
    NSMutableDictionary<NSNumber*, IDeviceHandle*>* handles;
    NSMutableDictionary<NSNumber*, NSData*>* dataPool;
    NSArray<NSString*>* allowedFunctions;
    JSContext* context;
}
- (instancetype)initWithContext:(JSContext*)context allowedFunctions:(NSArray<NSString*>*)allowedFunctions;
- (void)didReceiveScriptMessage:(NSDictionary *)message resolve:(JSValue*)resolveFunc reject:(JSValue*)rejectFunc;
- (void)cleanUp;
- (NSString*)errFreeFromIdeviceFfiError:(IdeviceFfiError*)err;
- (int)registerIdeviceHandle:(void*)handle freeFunc:(void*)freeFunc;
- (BOOL)freeIdeviceHandle:(int)handleId;
- (int)registerNSData:(NSData*)data;
- (bool)freeNSData:(int)handleId;
@end


NSDictionary *dictionaryFromPlist(plist_t plist, NSError **error);
NSData *plistDataFromDictionary(NSDictionary *dictionary, NSError **error);
const char** cstrArrFromNSArray(NSArray* arr, int* validCount);

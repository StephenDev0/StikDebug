//
//  profiles.h
//  StikDebug
//
//  Created by s s on 2025/11/29.
//

#ifndef PROFILES_H
#define PROFILES_H
#include "idevice.h"
#include <Foundation/Foundation.h>
NSArray<NSData*>* fetchAppProfiles(IdeviceProviderHandle* provider, NSError** error);
bool removeProfile(IdeviceProviderHandle* provider, NSString* uuid, NSError** error);
bool addProfile(IdeviceProviderHandle* provider, NSData* profile, NSError** error);

@interface CMSDecoderHelper : NSObject
// Decode CMS/PKCS7 data and return decoded payload and any embedded certs
+ (NSData*)decodeCMSData:(NSData *)cmsData
//             outCerts:(NSArray<id> * _Nullable * _Nullable)outCerts
                 error:(NSError * _Nullable * _Nullable)error;
@end
#endif

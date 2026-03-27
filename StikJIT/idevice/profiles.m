//
//  profiles.m
//  StikDebug
//
//  Created by s s on 2025/11/29.
//
#include "profiles.h"
#import "JITEnableContext.h"
#import "JITEnableContextInternal.h"
@import Foundation;

NSError* makeError(int code, NSString* msg) {
    return [NSError errorWithDomain:@"profiles" code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
}


NSArray<NSData*>* fetchAppProfiles(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSError** error) {
    MisagentClientHandle *misagentHandle = NULL;
    IdeviceFfiError *err = misagent_connect_rsd(adapter, handshake, &misagentHandle);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return nil;
    }

    uint8_t **profileArr = NULL;
    size_t profileCount = 0;
    size_t *profileLengthArr = NULL;
    err = misagent_copy_all(misagentHandle, &profileArr, &profileLengthArr, &profileCount);

    if (err) {
        *error = makeError((err)->code, @((err)->message));
        misagent_client_free(misagentHandle);
        idevice_error_free(err);
        return nil;
    }
    
    NSMutableArray* ans = [NSMutableArray array];
    for(int i = 0; i < profileCount; ++i) {
        size_t len = profileLengthArr[i];
        uint8_t* profile = profileArr[i];
        NSData* profileData = [NSData dataWithBytes:profile length:len];

        [ans addObject:profileData];
    }
    
    misagent_free_profiles(profileArr, profileLengthArr, profileCount);
    misagent_client_free(misagentHandle);
    
    return ans;
}

bool removeProfile(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSString* uuid, NSError** error) {
    MisagentClientHandle *misagentHandle = NULL;
    IdeviceFfiError * err = misagent_connect_rsd(adapter, handshake, &misagentHandle);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return false;
    }
    
    err = misagent_remove(misagentHandle, [uuid UTF8String]);
    if (err) {
        *error = makeError((err)->code, @((err)->message));
        misagent_client_free(misagentHandle);
        idevice_error_free(err);
        return false;
    }
    
    misagent_client_free(misagentHandle);
    return true;
}

bool addProfile(AdapterHandle* adapter, RsdHandshakeHandle* handshake, NSData* profile, NSError** error) {
    MisagentClientHandle *misagentHandle = NULL;
    IdeviceFfiError * err = misagent_connect_rsd(adapter, handshake, &misagentHandle);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return false;
    }
    
    err = misagent_install(misagentHandle, [profile bytes], [profile length]);
    if (err) {
        *error = makeError((err)->code, @((err)->message));
        misagent_client_free(misagentHandle);
        idevice_error_free(err);
        return false;
    }
    
    misagent_client_free(misagentHandle);
    return true;
}

@implementation CMSDecoderHelper

+ (NSData*)decodeCMSData:(NSData *)cmsData
//             outCerts:(NSArray<id> * _Nullable * _Nullable)outCerts
                 error:(NSError * _Nullable * _Nullable)error
{
    if (!cmsData || cmsData.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSURLErrorBadURL
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid or empty CMS payload"}];
        }
        return nil;
    }

    NSData *xmlStart    = [@"<?xml"    dataUsingEncoding:NSASCIIStringEncoding];
    NSData *plistEnd    = [@"</plist>" dataUsingEncoding:NSASCIIStringEncoding];
    NSData *binaryMagic = [@"bplist00" dataUsingEncoding:NSASCIIStringEncoding];

    NSRange startRange = [cmsData rangeOfData:xmlStart options:0 range:NSMakeRange(0, cmsData.length)];
    if (startRange.location != NSNotFound) {
        NSRange endSearchRange = NSMakeRange(startRange.location, cmsData.length - startRange.location);
        NSRange endRange = [cmsData rangeOfData:plistEnd options:0 range:endSearchRange];
        if (endRange.location != NSNotFound) {
            NSUInteger plistEndIndex = NSMaxRange(endRange);
            if (plistEndIndex > startRange.location && plistEndIndex <= cmsData.length) {
                return [cmsData subdataWithRange:NSMakeRange(startRange.location, plistEndIndex - startRange.location)];
            }
        }
    }

    NSRange binaryRange = [cmsData rangeOfData:binaryMagic options:0 range:NSMakeRange(0, cmsData.length)];
    if (binaryRange.location != NSNotFound) {
        return [cmsData subdataWithRange:NSMakeRange(binaryRange.location, cmsData.length - binaryRange.location)];
    }

    if (error) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSFileReadUnknownError
                                 userInfo:@{NSLocalizedDescriptionKey: @"Unable to extract plist from CMS payload"}];
    }
    return nil;
}

@end

@implementation JITEnableContext(Profile)

- (NSArray<NSData*>*)fetchAllProfiles:(NSError **)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return nil;
    }
    
    return fetchAppProfiles(adapter, handshake, error);
}

- (BOOL)removeProfileWithUUID:(NSString*)uuid error:(NSError **)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return NO;
    }
    
    return removeProfile(adapter, handshake, uuid, error);
}

- (BOOL)addProfile:(NSData*)profile error:(NSError **)error {
    [self ensureTunnelWithError:error];
    if(*error) {
        return NO;
    }
    return addProfile(adapter, handshake, profile, error);
}


@end

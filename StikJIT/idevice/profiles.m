//
//  profiles.m
//  StikDebug
//
//  Created by s s on 2025/11/29.
//
#include "profiles.h"
@import Foundation;
@import Security;

NSError* makeError(int code, NSString* msg) {
    return [NSError errorWithDomain:@"profiles" code:code userInfo:@{NSLocalizedDescriptionKey: msg}];
}


NSArray<NSData*>* fetchAppProfiles(IdeviceProviderHandle* provider, NSError** error) {
    MisagentClientHandle* misagentHandle = 0;
    IdeviceFfiError * err = misagent_connect(provider, &misagentHandle);
    if (err) {
        *error = makeError(err->code, @(err->message));
        idevice_error_free(err);
        return nil;
    }
    
    uint8_t** profileArr = 0;
    size_t profileCount = 0;
    size_t* profileLengthArr = 0;
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

bool removeProfile(IdeviceProviderHandle* provider, NSString* uuid, NSError** error) {
    MisagentClientHandle* misagentHandle = 0;
    IdeviceFfiError * err = misagent_connect(provider, &misagentHandle);
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

bool addProfile(IdeviceProviderHandle* provider, NSData* profile, NSError** error) {
    MisagentClientHandle* misagentHandle = 0;
    IdeviceFfiError * err = misagent_connect(provider, &misagentHandle);
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

typedef CFTypeRef CMSDecoderRef;
OSStatus CMSDecoderCreate(CMSDecoderRef * cmsDecoderOut);
OSStatus CMSDecoderUpdateMessage(CMSDecoderRef cmsDecoder, const void * msgBytes, size_t msgBytesLen);
OSStatus CMSDecoderFinalizeMessage(CMSDecoderRef cmsDecoder);
OSStatus CMSDecoderCopyContent(CMSDecoderRef cmsDecoder, CFDataRef * contentOut);
OSStatus CMSDecoderCopyAllCerts(CMSDecoderRef cmsDecoder, CFArrayRef * certsOut);


// Helper to convert OSStatus -> NSError
static NSError *NSErrorFromOSStatus(OSStatus status, NSString *message) {
    if (status == errSecSuccess) return nil;
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: message ?: @"Security error",
                                @"OSStatus" : @(status) };
    return [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:userInfo];
}


@implementation CMSDecoderHelper

+ (NSData*)decodeCMSData:(NSData *)cmsData
//             outCerts:(NSArray<id> * _Nullable * _Nullable)outCerts
                 error:(NSError * _Nullable * _Nullable)error
{
    if (!cmsData) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSURLErrorBadURL userInfo:@{NSLocalizedDescriptionKey: @"cmsData is nil"}];
        return nil;
    }

    CMSDecoderRef decoder = NULL;
    OSStatus status = CMSDecoderCreate(&decoder);
    if (status != errSecSuccess || decoder == NULL) {
        if (error) *error = NSErrorFromOSStatus(status, @"Failed to create CMS decoder");
        return nil;
    }

    // Feed data to decoder
    status = CMSDecoderUpdateMessage(decoder, cmsData.bytes, cmsData.length);
    if (status != errSecSuccess) {
        if (error) *error = NSErrorFromOSStatus(status, @"Failed to update CMS decoder with message bytes");
        CFRelease(decoder);
        return nil;
    }

    // Finalize (parse) the message
    status = CMSDecoderFinalizeMessage(decoder);
    if (status != errSecSuccess) {
        if (error) *error = NSErrorFromOSStatus(status, @"Failed to finalize CMS message");
        CFRelease(decoder);
        return nil;
    }

    // Extract the content (the inner payload). This may be NULL if content is detached.
    CFDataRef contentData = NULL;
    status = CMSDecoderCopyContent(decoder, &contentData);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        // errSecItemNotFound could mean no content (detached signature)
        if (error) *error = NSErrorFromOSStatus(status, @"Failed to copy CMS content");
        if (contentData) CFRelease(contentData);
        CFRelease(decoder);
        return nil;
    }

//    // Extract embedded certificates (if any)
//    CFArrayRef certsArray = NULL;
//    status = CMSDecoderCopyAllCerts(decoder, &certsArray);
//    if (status == errSecSuccess && certsArray) {
//        // certsArray contains SecCertificateRef items
//        NSArray *certs = (__bridge_transfer NSArray *)certsArray;
//        if (outCerts) *outCerts = certs;
//    } else {
//        // no certs or error
//        if (status != errSecSuccess && status != errSecItemNotFound) {
//            if (error) *error = NSErrorFromOSStatus(status, @"Failed to copy embedded certificates (if any)");
//            CFRelease(decoder);
//            return NO;
//        }
//        if (outCerts) *outCerts = @[]; // empty
//    }

    CFRelease(decoder);
    return (__bridge NSData *)(contentData);
}

@end

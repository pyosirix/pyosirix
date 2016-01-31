//
//  POKeychain.m
//  pyOsiriX
//

/*
 Copyright (c) 2016, The Institute of Cancer Research and The Royal Marsden.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 * Neither the name of the copyright holder nor the names of its contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "POKeychain.h"
#import <CommonCrypto/CommonDigest.h>

@implementation POKeychain

+(NSString *)keychainPassword
{
    return [NSString stringWithFormat:@"%@%@%@", [[NSHost currentHost] address], [[NSHost currentHost] localizedName], NSUserName()];
}

+(NSString *)keychainPath
{
    return [NSString stringWithFormat:@"%@/pythonHashes.keychain", [[NSBundle bundleForClass:[self class]] resourcePath]];
}

+(NSString *)accountName
{
    return NSUserName();
}

+(SecAccessRef)keychainAccessForLabel:(NSString *)label
{
    OSStatus err;
    SecAccessRef access=nil;
    NSArray *trustedApplications=nil;
    
    SecTrustedApplicationRef myself, OsiriX;
    
    err = SecTrustedApplicationCreateFromPath(NULL, &myself);
    err = err ?: SecTrustedApplicationCreateFromPath("/Applications/OsiriX.app",
                                                     &OsiriX);
    
    if (err == noErr) {
        trustedApplications = [NSArray arrayWithObjects:(id)myself,
                               (id)OsiriX, nil];
    }
    
    err = err ?: SecAccessCreate((CFStringRef)label, (CFArrayRef)trustedApplications, &access);
    if (err) return nil;
    
    return access;
}

+(SecKeychainRef)keychain
{
    NSString *keychainPath = [POKeychain keychainPath];
    NSString *kcPw = [POKeychain keychainPassword];
    OSStatus err;
    SecKeychainRef kc;
    err = SecKeychainCreate([keychainPath UTF8String], (UInt32)[kcPw length], [kcPw UTF8String], FALSE, NULL , &kc);
    if (err){
        err = SecKeychainOpen([keychainPath UTF8String], &kc);
    }
    return kc;
}

+(NSData *)hashData:(NSData *)data
{
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([data bytes], (CC_LONG)[data length], hash);
    NSData *output = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
    return output;
}

+(BOOL)setHash:(NSData *)hash ForLabel:(NSString *)label
{
    SecKeychainRef kc = [POKeychain keychain];
    if (kc == nil)
        return FALSE;
    
    NSString *pwd = [POKeychain keychainPassword];
    SecKeychainUnlock(kc, (UInt32)[pwd length], [pwd UTF8String], YES);
    NSString *acc = [POKeychain accountName];
    
    OSStatus err;
    
    UInt32 nBytes;
    char * bytes;
    SecKeychainItemRef item;
    err = SecKeychainFindGenericPassword(kc, (UInt32)[label length], [label UTF8String], (UInt32)[acc length], [acc UTF8String], &nBytes, (void **)&bytes, &item);
    if (err == errSecItemNotFound) {
        SecKeychainAttribute attrs[] = {
            { kSecGenericItemAttr, (UInt32)16, "pythonScriptHash" },
            { kSecLabelItemAttr, (UInt32)[label length], (char *)[label UTF8String]},
            { kSecAccountItemAttr, (UInt32)[acc length], (char *)[acc UTF8String]},
            { kSecServiceItemAttr, (UInt32)[label length], (char *)[label UTF8String]},
        };
        SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]),
            attrs };
        
        SecAccessRef access = [POKeychain keychainAccessForLabel:label];
        err = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass,
                                               &attributes,
                                               (UInt32)[hash length],
                                               [hash bytes],
                                               kc,
                                               access,
                                               NULL);
        CFRelease(access);
    }
    else
    {
        err = SecKeychainItemModifyAttributesAndData (item,
                                                      NULL,
                                                      (UInt32)[hash length],
                                                      [hash bytes]);
        free(bytes);
        CFRelease(item);
    }
    
    if (kc) CFRelease(kc);
    
    return !err;
}

+(NSData *)hashForLabel:(NSString *)label
{
    SecKeychainRef kc = [POKeychain keychain];
    if (kc == nil)
        return nil;
    NSString *pwd = [POKeychain keychainPassword];
    SecKeychainUnlock(kc, (UInt32)[pwd length], [pwd UTF8String], YES);
    
    NSString *acc = [POKeychain accountName];
    char *bytes;
    UInt32 nBytes;
    OSStatus err;
    NSData *data = nil;
    err = SecKeychainFindGenericPassword(kc, (UInt32)[label length], [label UTF8String], (UInt32)[acc length], [acc UTF8String], &nBytes, (void **)&bytes, NULL);
    if (!err) {
        data = [NSData dataWithBytes:bytes length:nBytes];
        free(bytes);
    }
    return data;
}

@end

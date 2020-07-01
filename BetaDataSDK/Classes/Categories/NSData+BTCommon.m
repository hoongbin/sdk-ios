//
//  NSData+BTCommon.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2019/4/11.
//

#import "NSData+BTCommon.h"
#include <CommonCrypto/CommonCrypto.h>

@implementation NSData (BTCommon)

- (NSString *)bt_hmacSHA256StringWithKey:(NSString *)key {
    return [self hmacStringUsingAlg:kCCHmacAlgSHA256 withKey:key];
}

- (NSString *)hmacStringUsingAlg:(CCHmacAlgorithm)alg withKey:(NSString *)key {
    size_t size;
    switch (alg) {
        case kCCHmacAlgMD5: size = CC_MD5_DIGEST_LENGTH; break;
        case kCCHmacAlgSHA1: size = CC_SHA1_DIGEST_LENGTH; break;
        case kCCHmacAlgSHA224: size = CC_SHA224_DIGEST_LENGTH; break;
        case kCCHmacAlgSHA256: size = CC_SHA256_DIGEST_LENGTH; break;
        case kCCHmacAlgSHA384: size = CC_SHA384_DIGEST_LENGTH; break;
        case kCCHmacAlgSHA512: size = CC_SHA512_DIGEST_LENGTH; break;
        default: return nil;
    }
    unsigned char result[size];
    const char *cKey = [key cStringUsingEncoding:NSUTF8StringEncoding];
    CCHmac(alg, cKey, strlen(cKey), self.bytes, self.length, result);
    NSMutableString *hash = [NSMutableString stringWithCapacity:size * 2];
    for (int i = 0; i < size; i++) {
        [hash appendFormat:@"%02x", result[i]];
    }
    return hash;
}

@end

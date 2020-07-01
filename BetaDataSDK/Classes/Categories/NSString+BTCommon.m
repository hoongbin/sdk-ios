//
//  NSString.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2017/7/6.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "NSString+BTCommon.h"
#import "NSData+BTCommon.h"

@implementation NSString (BTCommon)

- (int)bt_hashCode {
    int hash = 0;
    for (int i = 0; i<[self length]; i++) {
        NSString *s = [self substringWithRange:NSMakeRange(i, 1)];
        char *unicode = (char *)[s cStringUsingEncoding:NSUnicodeStringEncoding];
        int charactorUnicode = 0;
        size_t length = strlen(unicode);
        for (int n = 0; n < length; n ++) {
            charactorUnicode += (int)((unicode[n] & 0xff) << (n * sizeof(char) * 8));
        }
        hash = hash * 31 + charactorUnicode;
    }
    
    return hash;
}

- (NSString *)bt_hmacSHA256StringWithKey:(NSString *)key {
    return [[self dataUsingEncoding:NSUTF8StringEncoding] bt_hmacSHA256StringWithKey:key];
}

- (NSString *)bt_urlEncode {
    NSString *encodedString = (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)self,
                                                              NULL,
                                                              (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                              kCFStringEncodingUTF8));
    return encodedString;
}

- (NSString *)bt_urlDecode {
    NSString *decodedString = (__bridge_transfer NSString *)
    CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                            (__bridge CFStringRef)self,
                                                            CFSTR(""),
                                                            CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    return decodedString;
}

- (instancetype)trimWhitespaceAndNewLine {
    if (!self.length) {
        return self;
    }
    NSString *copy = [self copy];
    copy = [copy stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    copy = [copy stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    copy = [copy stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    return copy;
}

@end

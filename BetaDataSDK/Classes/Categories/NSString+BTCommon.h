//
//  NSString.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2017/7/6.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSString (BTCommon)

-(int)bt_hashCode;

- (NSString *)bt_hmacSHA256StringWithKey:(NSString *)key;

- (NSString *)bt_urlEncode;

- (NSString *)bt_urlDecode;

- (instancetype)trimWhitespaceAndNewLine;

@end

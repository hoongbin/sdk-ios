//
//  NSThread+BTHelpers.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/6/26.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSThread (BTHelpers)
+ (void)bt_safelyRunOnMainThreadSync:(void (^)(void))block;
@end

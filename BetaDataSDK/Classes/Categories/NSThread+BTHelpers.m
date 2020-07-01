//
//  NSThread+BTHelpers.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/6/26.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "NSThread+BTHelpers.h"

@implementation NSThread (BTHelpers)
+ (void)bt_safelyRunOnMainThreadSync:(void (^)(void))block {
    if ([self isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
@end

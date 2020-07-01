//
//  BTSwizzler.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/20/16
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// Cast to turn things that are not ids into NSMapTable keys
#define MAPTABLE_ID(x) (__bridge id)((void *)x)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"
typedef void (^swizzleBlock)();
#pragma clang diagnostic pop

@interface BTSwizzler : NSObject

+ (void)swizzleSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(swizzleBlock)block named:(NSString *)aName;
+ (void)swizzleBoolSelector:(SEL)aSelector onClass:(Class)aClass withBlock:(swizzleBlock)aBlock named:(NSString *)aName;
+ (void)unswizzleSelector:(SEL)aSelector onClass:(Class)aClass named:(NSString *)aName;
+ (void)printSwizzles;

@end

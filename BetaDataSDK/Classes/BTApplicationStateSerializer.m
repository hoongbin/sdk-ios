//
//  BTApplicationStateSerializer.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import <QuartzCore/QuartzCore.h>
#import "BTApplicationStateSerializer.h"
#import "BTClassDescription.h"
#import "BTLogger.h"
#import "BTObjectIdentityProvider.h"
#import "BTObjectSerializer.h"
#import "BTObjectSerializerConfig.h"

@implementation BTApplicationStateSerializer {
    BTObjectSerializer *_serializer;
    UIApplication *_application;
}

- (instancetype)initWithApplication:(UIApplication *)application
                      configuration:(BTObjectSerializerConfig *)configuration
             objectIdentityProvider:(BTObjectIdentityProvider *)objectIdentityProvider {
    NSParameterAssert(application != nil);
    NSParameterAssert(configuration != nil);
    
    self = [super init];
    if (self) {
        _application = application;
        _serializer = [[BTObjectSerializer alloc] initWithConfiguration:configuration objectIdentityProvider:objectIdentityProvider];
    }
    
    return self;
}

- (UIImage *)screenshotImageForWindow:(UIWindow *)window {
    UIImage *image = nil;
    
    UIWindow *mainWindow = [self uiMainWindow:window];
    if (mainWindow && !CGRectEqualToRect(mainWindow.frame, CGRectZero)) {
        UIGraphicsBeginImageContextWithOptions(mainWindow.bounds.size, YES, mainWindow.screen.scale);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        if ([mainWindow respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
            if ([mainWindow drawViewHierarchyInRect:mainWindow.bounds afterScreenUpdates:NO] == NO) {
                BTLog(@"Unable to get complete screenshot for window at index: %d.", (int)index);
            }
        } else {
            [mainWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
        }
#else
        [mainWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
#endif
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    return image;
}

- (UIWindow *)uiMainWindow:(UIWindow *)window {
    if (window != nil) {
        return window;
    }
    return _application.windows[0];
}

- (NSDictionary *)objectHierarchyForWindow:(UIWindow *)window {
    UIWindow *mainWindow = [self uiMainWindow:window];
    if (mainWindow) {
        return [_serializer serializedObjectsWithRootObject:mainWindow];
    }
    
    return @{};
}

@end

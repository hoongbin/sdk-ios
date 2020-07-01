//
//  UIGestureRecognizer+AutoTrack.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/10/25.
//  Copyright © 2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "UIGestureRecognizer+AutoTrack.h"
#import "BetaDataSDK.h"
#import "UIView+AutoTrack.h"
#import "AutoTrackUtils.h"
#import "BTLogger.h"
#import "BetaDataSDK+Private.h"
#import <objc/runtime.h>
#import "BTConstants.h"
#import "UIImage+BetaData.h"
#import "UIView+BetaData.h"

@implementation UIGestureRecognizer (AutoTrack)

- (void)trackGestureRecognizerAppClick:(id)target {
    
    //暂定只采集 UILabel 和 UIImageView
    if (![self.view isKindOfClass:UILabel.class] && ![self.view isKindOfClass:UIImageView.class]) {
        return;
    }
    
    @try {
        if (target == nil) {
            return;
        }
        UIGestureRecognizer *gesture = target;
        if (gesture == nil) {
            return;
        }
        
        if (gesture.state != UIGestureRecognizerStateEnded) {
            return;
        }
        
        UIView *view = gesture.view;
        if (view == nil) {
            return;
        }
        //关闭 AutoTrack
        if (![[BetaDataSDK sharedInstance] isAutoTrackEnabled]) {
            return;
        }
        
        //忽略 $AppClick 事件
        if ([[BetaDataSDK sharedInstance] isAutoTrackEventTypeIgnored:BetaDataEventTypeAppClick]) {
            return;
        }
        
        if ([view isKindOfClass:[UILabel class]]) {//UILabel
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[UILabel class]]) {
                return;
            }
        } else if ([view isKindOfClass:[UIImageView class]]) {//UIImageView
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[UIImageView class]]) {
                return;
            }
        }
        
        UIViewController *viewController = [[BetaDataSDK sharedInstance] currentViewController];
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        
        if (viewController != nil) {
            if ([[BetaDataSDK sharedInstance] isViewControllerIgnored:viewController]) {
                return;
            }
            
            //获取 Controller 名称($screen_name)
            NSString *screenName = NSStringFromClass([viewController class]);
            [properties setValue:screenName forKey:BT_EVENT_PROPERTY_SCREEN_NAME];
            
            NSString *controllerTitle = [AutoTrackUtils titleFromViewController:viewController];
            if (controllerTitle) {
                [properties setValue:controllerTitle forKey:BT_EVENT_PROPERTY_TITLE];
            }
        }
        
        //ViewID
        if (view.betaDataViewID != nil) {
            //[properties setValue:view.betaDataViewID forKey:BT_EVENT_PROPERTY_ELEMENT_ID];
        }
        
        if ([view isKindOfClass:[UILabel class]]) {
            //[properties setValue:@"UILabel" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
            UILabel *label = (UILabel*)view;
            NSString *bt_elementContent = label.bt_elementContent;
            if (bt_elementContent && bt_elementContent.length > 0) {
                [properties setValue:bt_elementContent forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
            }
            [AutoTrackUtils addViewPathProperties:properties withObject:view withViewController:viewController];
        } else if ([view isKindOfClass:[UIImageView class]]) {
            //[properties setValue:@"UIImageView" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME
            UIImageView *imageView = (UIImageView *)view;
            [AutoTrackUtils addViewPathProperties:properties withObject:view withViewController:viewController];

            NSString *imageName = imageView.image.betaDataImageName;
            if (imageName.length > 0) {
                [properties setValue:[NSString stringWithFormat:@"_%@", imageName] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
            }
#endif
        }else {
            return;
        }
        
        //View Properties
        NSDictionary* propDict = view.betaDataViewProperties;
        if (propDict != nil) {
            [properties addEntriesFromDictionary:propDict];
        }
        
        [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
}

@end


@implementation UITapGestureRecognizer (AutoTrack)

- (instancetype)bt_initWithTarget:(id)target action:(SEL)action {
    [self bt_initWithTarget:target action:action];
    [self removeTarget:target action:action];
    [self addTarget:target action:action];
    return self;
}

- (void)bt_addTarget:(id)target action:(SEL)action {
    [self bt_addTarget:self action:@selector(trackGestureRecognizerAppClick:)];
    [self bt_addTarget:target action:action];
}

@end



@implementation UILongPressGestureRecognizer (AutoTrack)

- (instancetype)bt_initWithTarget:(id)target action:(SEL)action {
    [self bt_initWithTarget:target action:action];
    [self removeTarget:target action:action];
    [self addTarget:target action:action];
    return self;
}

- (void)bt_addTarget:(id)target action:(SEL)action {
    [self bt_addTarget:self action:@selector(trackGestureRecognizerAppClick:)];
    [self bt_addTarget:target action:action];
}
@end

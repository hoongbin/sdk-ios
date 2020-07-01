//
//  UIApplication+AutoTrack.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 17/3/22.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "UIApplication+AutoTrack.h"
#import "BTLogger.h"
#import "BetaDataSDK.h"
#import "AutoTrackUtils.h"
#import "UIView+BTHelpers.h"
#import "UIView+AutoTrack.h"
#import "BTConstants.h"
#import "BetaDataSDK+Private.h"
#import "UIImage+BetaData.h"
#import "UIView+BetaData.h"

@implementation UIApplication (AutoTrack)

- (BOOL)bt_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {

    /*
     默认先执行 AutoTrack
     如果先执行原点击处理逻辑，可能已经发生页面 push 或者 pop，导致获取当前 ViewController 不正确
     可以通过 UIView 扩展属性 betaDataAutoTrackAfterSendAction，来配置 AutoTrack 是发生在原点击处理函数之前还是之后
     */

    BOOL ret = YES;
    BOOL betaDataAutoTrackAfterSendAction = NO;

    @try {
        if (from) {
            if ([from isKindOfClass:[UIView class]]) {
                UIView* view = (UIView *)from;
                if (view) {
                    if (view.betaDataAutoTrackAfterSendAction) {
                        betaDataAutoTrackAfterSendAction = YES;
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
        betaDataAutoTrackAfterSendAction = NO;
    }

    if (betaDataAutoTrackAfterSendAction) {
        ret = [self bt_sendAction:action to:to from:from forEvent:event];
    }

    @try {
        /*
//         caojiangPreVerify:forEvent: & caojiangEventAction:forEvent: 是我们可视化埋点中的点击事件
//         这个地方如果不过滤掉，会导致 swizzle 多次，从而会触发多次 $AppClick 事件
//         caojiang 是我们 CTO 名字，我们相信这个前缀应该是唯一的
//         如果这个前缀还会重复，请您告诉我，我把我们架构师的名字也加上
//         */
//        if (![@"caojiangPreVerify:forEvent:" isEqualToString:NSStringFromSelector(action)] &&
//            ![@"caojiangEventAction:forEvent:" isEqualToString:NSStringFromSelector(action)]) {
            [self sa_track:action to:to from:from forEvent:event];
//        }
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }

    if (!betaDataAutoTrackAfterSendAction) {
        ret = [self bt_sendAction:action to:to from:from forEvent:event];
    }

    return ret;
}

- (void)sa_track:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    @try {
        //关闭 AutoTrack
        if (![[BetaDataSDK sharedInstance] isAutoTrackEnabled]) {
            return;
        }
        
        //忽略 $AppClick 事件
        if ([[BetaDataSDK sharedInstance] isAutoTrackEventTypeIgnored:BetaDataEventTypeAppClick]) {
            return;
        }
        
        // ViewType 被忽略
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
        if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[UITabBar class]]) {
                return;
            }
        } else if ([from isKindOfClass:[NSClassFromString(@"UINavigationButton") class]]) {
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[UIBarButtonItem class]]) {
                return;
            }
        } else
#endif
        if ([to isKindOfClass:[UISearchBar class]]) {
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[UISearchBar class]]) {
                return;
            }
        } else {
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[from class]]) {
                return;
            }
        }
        
        /*
         此处不处理 UITabBar，放到 UITabBar+AutoTrack.h 中处理
         */
        if (from != nil) {
            if ([from isKindOfClass:[UIBarButtonItem class]]) {
                return;
            }
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
            if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {
                return;
            }
#else
            if ([to isKindOfClass:[UITabBar class]]) {
                return;
            }
#endif
        }
        
        if (([event isKindOfClass:[UIEvent class]] && event.type==UIEventTypeTouches) ||
            [from isKindOfClass:[UISwitch class]] ||
            [from isKindOfClass:[UIStepper class]] ||
            [from isKindOfClass:[UISegmentedControl class]]) {//0
            if (![from isKindOfClass:[UIView class]]) {
                return;
            }
            
            UIView* view = (UIView *)from;
            if (!view) {
                return;
            }
            
            if (view.betaDataIgnoreView) {
                return;
            }
            
            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
            
            //ViewID
            if (view.betaDataViewID != nil) {
                //[properties setValue:view.betaDataViewID forKey:BT_EVENT_PROPERTY_ELEMENT_ID];
            }
            
            UIViewController *viewController = [view sensorsAnalyticsViewController];
            
            if (viewController == nil || [viewController isKindOfClass:UINavigationController.class]) {
                viewController = [[BetaDataSDK sharedInstance] currentViewController];
            }
            
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
            
            //UISwitch
            if ([from isKindOfClass:[UISwitch class]]) {
                //[properties setValue:@"UISwitch" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                UISwitch *uiSwitch = (UISwitch *)from;
                if (uiSwitch.on) {
                    [properties setValue:@"checked" forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                } else {
                    [properties setValue:@"unchecked" forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                }
                
                [AutoTrackUtils addViewPathProperties:properties withObject:uiSwitch withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.betaDataViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }

                [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
                return;
            }

            //UIStepper
            if ([from isKindOfClass:[UIStepper class]]) {
                //[properties setValue:@"UIStepper" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                UIStepper *stepper = (UIStepper *)from;
                if (stepper) {
                    [properties setValue:[NSString stringWithFormat:@"%g", stepper.value] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                }
                
                [AutoTrackUtils addViewPathProperties:properties withObject:stepper withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.betaDataViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }

                [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
                return;
            }

            //UISearchBar
            //        if ([to isKindOfClass:[UISearchBar class]] && [from isKindOfClass:[[NSClassFromString(@"UISearchBarTextField") class] class]]) {
            //            UISearchBar *searchBar = (UISearchBar *)to;
            //            if (searchBar != nil) {
            //                [properties setValue:@"UISearchBar" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
            //                NSString *searchText = searchBar.text;
            //                if (searchText == nil || [searchText length] == 0) {
            //                    [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties];
            //                    return;
            //                }
            //            }
            //        }
            
            //UISegmentedControl
            if ([from isKindOfClass:[UISegmentedControl class]]) {
                UISegmentedControl *segmented = (UISegmentedControl *)from;
                //[properties setValue:@"UISegmentedControl" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                
                if ([segmented selectedSegmentIndex] == UISegmentedControlNoSegment) {
                    return;
                }
                [properties setValue:[NSString stringWithFormat: @"%ld", (long)[segmented selectedSegmentIndex]] forKey:BT_EVENT_PROPERTY_ELEMENT_POSITION];
                [properties setValue:[segmented titleForSegmentAtIndex:[segmented selectedSegmentIndex]] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                
                [AutoTrackUtils addViewPathProperties:properties withObject:segmented withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.betaDataViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }

                [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
                return;
                
            }
            
            //只统计触摸结束时
            if ([event isKindOfClass:[UIEvent class]] && [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
                if ([from isKindOfClass:[NSClassFromString(@"UINavigationButton") class]]) {
                    UIButton *button = (UIButton *)from;
                    [properties setValue:@"UIBarButtonItem" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                    if (button != nil) {
                        NSString *currentTitle = button.bt_elementContent;
                        if (currentTitle != nil) {
                            [properties setValue:currentTitle forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                        } else {
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME

                            NSString *imageName = button.currentImage.betaDataImageName;
                            if (imageName.length > 0) {
                                [properties setValue:[NSString stringWithFormat:@"_%@", imageName] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                            }
#endif
                        }
                    }
                } else
#endif
                    if ([from isKindOfClass:[UIButton class]]) {//UIButton
                        UIButton *button = (UIButton *)from;
                        //[properties setValue:@"UIButton" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                        
                        NSString *currentTitle = [AutoTrackUtils contentFromView:button];
                        if (currentTitle.length > 0) {
                            [properties setValue:currentTitle forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                        } else {
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME
                            NSString *imageName = button.currentImage.betaDataImageName;
                            if (imageName.length > 0) {
                                [properties setValue:[NSString stringWithFormat:@"_%@", imageName] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                            }
#endif
                        }
                    }
#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
                else if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {//UITabBarButton
                    if ([to isKindOfClass:[UITabBar class]]) {//UITabBar
                        UITabBar *tabBar = (UITabBar *)to;
                        if (tabBar != nil) {
                            UITabBarItem *item = [tabBar selectedItem];
                            [properties setValue:@"UITabbar" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                            [properties setValue:item.title forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                        }
                    }
                }
#endif
                else if([from isKindOfClass:[UITabBarItem class]]){//For iOS7 TabBar
                    UITabBarItem *tabBarItem = (UITabBarItem *)from;
                    if (tabBarItem) {
                        //[properties setValue:@"UITabbar" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                        [properties setValue:tabBarItem.title forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                    }
                } else if ([from isKindOfClass:[UISlider class]]) {//UISlider
                    UISlider *slide = (UISlider *)from;
                    if (slide != nil) {
                        //[properties setValue:@"UISlider" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                        [properties setValue:[NSString stringWithFormat:@"%f",slide.value] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                    }
                } else {
                    if ([from isKindOfClass:[UIControl class]]) {
                        //[properties setValue:@"UIControl" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                        UIControl *fromView = (UIControl *)from;
                        if (fromView.subviews.count > 0) {
                            NSString *elementContent = [AutoTrackUtils contentFromView:fromView];
                            if (elementContent.length > 0) {
                                [properties setValue:elementContent forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                            }
                        }
                    }
                }
                
                [AutoTrackUtils addViewPathProperties:properties withObject:view withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.betaDataViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }

                [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
            }
        }
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
}

@end

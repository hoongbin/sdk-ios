//
//  UIViewController.m
//  HookTest
//
//  Created by Zhou Kang on 2017/10/18.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "UIViewController+AutoTrack.h"
#import "BetaDataSDK.h"
#import "BTLogger.h"
#import "BTSwizzler.h"
#import "AutoTrackUtils.h"
#import "BetaDataSDK+Private.h"

@implementation UIViewController (AutoTrack)
- (void)bt_autotrack_viewWillAppear:(BOOL)animated {
    @try {
        
        if ([[BetaDataSDK sharedInstance] isAutoTrackEventTypeIgnored:BetaDataEventTypeAppViewScreen] == NO) {
#ifndef SENSORS_ANALYTICS_ENABLE_AUTOTRACK_CHILD_VIEWSCREEN
            UIViewController *viewController = (UIViewController *)self;
            if (![viewController.parentViewController isKindOfClass:[UIViewController class]] ||
                [viewController.parentViewController isKindOfClass:[UITabBarController class]] ||
                [viewController.parentViewController isKindOfClass:[UINavigationController class]] ||
                [viewController.parentViewController isKindOfClass:[UIPageViewController class]] ||
                [viewController.parentViewController isKindOfClass:[UISplitViewController class]] ||
                [viewController.parentViewController isKindOfClass:NSClassFromString(@"WMPageController")]) {
                [[BetaDataSDK sharedInstance] autoTrackViewScreen: viewController];
            }
#else
            [[BetaDataSDK sharedInstance] autoTrackViewScreen:self];
#endif
        }
#ifndef SENSORS_ANALYTICS_ENABLE_AUTOTRACK_DIDSELECTROW
        if ([BetaDataSDK.sharedInstance isAutoTrackEventTypeIgnored: BetaDataEventTypeAppClick] == NO) {
            //UITableView
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UITABLEVIEW
            void (^tableViewBlock)(id, SEL, id, id) = ^(id view, SEL command, UITableView *tableView, NSIndexPath *indexPath) {
                [AutoTrackUtils trackAppClickWithUITableView:tableView didSelectRowAtIndexPath:indexPath];
            };
            if ([self respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
                [BTSwizzler swizzleSelector:@selector(tableView:didSelectRowAtIndexPath:) onClass:self.class withBlock:tableViewBlock named:[NSString stringWithFormat:@"%@_%@", NSStringFromClass(self.class), @"UITableView_AutoTrack"]];
            }
#endif
            
            //UICollectionView
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UICOLLECTIONVIEW
            void (^collectionViewBlock)(id, SEL, id, id) = ^(id view, SEL command, UICollectionView *collectionView, NSIndexPath *indexPath) {
                [AutoTrackUtils trackAppClickWithUICollectionView:collectionView didSelectItemAtIndexPath:indexPath];
            };
            if ([self respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
                [BTSwizzler swizzleSelector:@selector(collectionView:didSelectItemAtIndexPath:) onClass:self.class withBlock:collectionViewBlock named:[NSString stringWithFormat:@"%@_%@", NSStringFromClass(self.class), @"UICollectionView_AutoTrack"]];
            }
#endif
        }
#endif
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
    [self bt_autotrack_viewWillAppear:animated];
}
@end

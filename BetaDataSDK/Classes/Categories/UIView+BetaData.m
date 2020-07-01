//
//  UIView+BetaData.m
//  BetaDataSDK
//
//  Created by ZK on 2019/7/23.
//

#import "UIView+BetaData.h"
#import <objc/runtime.h>

@implementation UIView (BetaData)

- (UIViewController *)sensorsAnalyticsViewController {
    UIResponder *next = self.nextResponder;
    do {
        if ([next isKindOfClass:UIViewController.class]) {
            UIViewController *vc = (UIViewController *)next;
            if ([vc isKindOfClass:UINavigationController.class]) {
                next = [(UINavigationController *)vc topViewController];
                break;
            }else if([vc isKindOfClass:UITabBarController.class]) {
                next = [(UITabBarController *)vc selectedViewController];
                break;
            }
            UIViewController *parentVC = vc.parentViewController;
            if (parentVC) {
                if ([parentVC isKindOfClass:UINavigationController.class]||
                    [parentVC isKindOfClass:UITabBarController.class]||
                    [parentVC isKindOfClass:UIPageViewController.class]||
                    [parentVC isKindOfClass:UISplitViewController.class]) {
                    break;
                } else if ([parentVC.class isKindOfClass:NSClassFromString(@"WMPageController")]) {
                    break;
                }
            }else {
                break;
            }
        }
    } while ((next=next.nextResponder));
    return [next isKindOfClass:UIViewController.class]?(UIViewController *)next:nil;
}

//viewID
- (NSString *)betaDataViewID {
    return objc_getAssociatedObject(self, @selector(betaDataViewID));
}

- (void)setBetaDataViewID:(NSString *)betaDataViewID {
    objc_setAssociatedObject(self, @selector(betaDataViewID), betaDataViewID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

//ignoreView
- (BOOL)betaDataIgnoreView {
    return [objc_getAssociatedObject(self, @selector(betaDataIgnoreView)) boolValue];
}

- (void)setBetaDataIgnoreView:(BOOL)betaDataIgnoreView {
    objc_setAssociatedObject(self, @selector(betaDataIgnoreView), [NSNumber numberWithBool:betaDataIgnoreView], OBJC_ASSOCIATION_ASSIGN);
}

//afterSendAction
- (BOOL)betaDataAutoTrackAfterSendAction {
    return [objc_getAssociatedObject(self, @selector(betaDataAutoTrackAfterSendAction)) boolValue];
}

- (void)setBetaDataAutoTrackAfterSendAction:(BOOL)betaDataAutoTrackAfterSendAction {
    objc_setAssociatedObject(self, @selector(betaDataAutoTrackAfterSendAction), [NSNumber numberWithBool:betaDataAutoTrackAfterSendAction], OBJC_ASSOCIATION_ASSIGN);
}

//viewProperty
- (NSDictionary *)betaDataViewProperties {
    return objc_getAssociatedObject(self, @selector(betaDataViewProperties));
}

- (void)setBetaDataViewProperties:(NSDictionary *)betaDataViewProperties {
    objc_setAssociatedObject(self, @selector(betaDataViewProperties), betaDataViewProperties, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)betaDataDelegate {
    return objc_getAssociatedObject(self, @selector(betaDataDelegate));
}

- (void)setBetaDataDelegate:(id)betaDataDelegate {
    objc_setAssociatedObject(self, @selector(betaDataDelegate), betaDataDelegate, OBJC_ASSOCIATION_ASSIGN);
}

@end

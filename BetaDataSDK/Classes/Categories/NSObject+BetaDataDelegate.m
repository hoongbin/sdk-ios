//
//  NSObject+betaDataDelegate.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/8/8.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//
#ifdef SENSORS_ANALYTICS_ENABLE_AUTOTRACK_DIDSELECTROW

#import "NSObject+BetaDataDelegate.h"
#import <objc/runtime.h>
#import <objc/objc.h>
#import <objc/message.h>
#import "AutoTrackUtils.h"
#import "BetaDataSDK.h"

static void bt_tablViewDidSelectRowAtIndexPath(id self, SEL _cmd, id tableView, id indexPath){
    SEL selector = NSSelectorFromString(@"sa_tableView:didSelectRowAtIndexPath:");
    ((void(*)(id, SEL, id, id))objc_msgSend)(self, selector, tableView, indexPath);
    [AutoTrackUtils trackAppClickWithUITableView:tableView didSelectRowAtIndexPath:indexPath];
}

static void bt_collectionViewDidSelectItemAtIndexPath(id self, SEL _cmd, id collectionView, id indexPath){
    SEL selector = NSSelectorFromString(@"sa_collectionView:didSelectItemAtIndexPath:");
    ((void(*)(id, SEL, id, id))objc_msgSend)(self, selector, collectionView, indexPath);
    [AutoTrackUtils trackAppClickWithUICollectionView:collectionView didSelectItemAtIndexPath:indexPath];
}

static void bt_setDelegate(id obj ,SEL sel, id delegate){
    SEL swizzileSel = sel_getUid("bt_setDelegate:");
    ((void (*)(id, SEL,id))objc_msgSend)(obj,swizzileSel,delegate);
    if (delegate == nil) {
        return;
    }
    if ([[BetaDataSDK sharedInstance] isAutoTrackEnabled]){
        if ([obj isKindOfClass:UITableView.class]) {
            if ([delegate isKindOfClass:[UITableView class]]) {
                return;
            }
            Class class = [delegate class];
            do {
                Method rootMethod = nil;
                if ((rootMethod = class_getInstanceMethod(class, @selector(tableView:didSelectRowAtIndexPath:)))) {
                    if (!class_getInstanceMethod(class_getSuperclass(class), @selector(tableView:didSelectRowAtIndexPath:))) {
                        const char* encoding = method_getTypeEncoding(rootMethod);
                        SEL swizSel = NSSelectorFromString(@"sa_tableView:didSelectRowAtIndexPath:");
                        if (class_addMethod(class , swizSel, (IMP)bt_tablViewDidSelectRowAtIndexPath, encoding)) {
                            Method originalMethod = class_getInstanceMethod(class, @selector(tableView:didSelectRowAtIndexPath:));
                            Method swizzledMethod = class_getInstanceMethod(class, swizSel);
                            method_exchangeImplementations(originalMethod, swizzledMethod);
                        }
                        break;
                    }
                }
            } while ((class = class_getSuperclass(class)));
        }else if ([obj isKindOfClass:UICollectionView.class]){
            if ([delegate isKindOfClass:[UICollectionView class]]) {
                return;
            }
            Class class = [delegate class];
            do {
                Method rootMethod = nil;
                if ((rootMethod = class_getInstanceMethod(class, @selector(collectionView:didSelectItemAtIndexPath:)))) {
                    if (!class_getInstanceMethod(class_getSuperclass(class), @selector(collectionView:didSelectItemAtIndexPath:))) {
                        const char* encoding = method_getTypeEncoding(rootMethod);
                        SEL swizSel = NSSelectorFromString(@"sa_collectionView:didSelectItemAtIndexPath:");
                        if (class_addMethod(class, swizSel, (IMP)bt_collectionViewDidSelectItemAtIndexPath, encoding)) {
                            Method originalMethod = class_getInstanceMethod(class, @selector(collectionView:didSelectItemAtIndexPath:));
                            Method swizzledMethod = class_getInstanceMethod(class, swizSel);
                            method_exchangeImplementations(originalMethod, swizzledMethod);
                        }
                        break;
                    }
                }
            } while ((class = class_getSuperclass(class)));
        }
    }
}

@implementation UITableView (BetaDataDelegate)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL origSel_ = sel_getUid("setDelegate:");
        SEL swizzileSel = sel_getUid("bt_setDelegate:");
        Method origMethod = class_getInstanceMethod(self, origSel_);
        const char* type = method_getTypeEncoding(origMethod);
        class_addMethod(self, swizzileSel, (IMP)bt_setDelegate, type);
        Method swizzleMethod = class_getInstanceMethod(self, swizzileSel);
        IMP origIMP = method_getImplementation(origMethod);
        IMP swizzleIMP = method_getImplementation(swizzleMethod);
        method_setImplementation(origMethod, swizzleIMP);
        method_setImplementation(swizzleMethod, origIMP);
    });
}

@end

@implementation UICollectionView (BetaDataDelegate)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL origSel_ = sel_getUid("setDelegate:");
        SEL swizzileSel = sel_getUid("bt_setDelegate:");
        Method origMethod = class_getInstanceMethod(self, origSel_);
        const char* type = method_getTypeEncoding(origMethod);
        class_addMethod(self, swizzileSel, (IMP)bt_setDelegate, type);
        Method swizzleMethod = class_getInstanceMethod(self, swizzileSel);
        IMP origIMP = method_getImplementation(origMethod);
        IMP swizzleIMP = method_getImplementation(swizzleMethod);
        method_setImplementation(origMethod, swizzleIMP);
        method_setImplementation(swizzleMethod, origIMP);
    });
}

@end

#endif

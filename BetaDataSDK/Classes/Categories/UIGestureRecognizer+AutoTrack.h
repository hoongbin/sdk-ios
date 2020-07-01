//
//  UIGestureRecognizer+AutoTrack.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/10/25.
//  Copyright © 2018 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIGestureRecognizer (AutoTrack)

@end


@interface UITapGestureRecognizer (AutoTrack)

- (instancetype)bt_initWithTarget:(id)target action:(SEL)action;

- (void)bt_addTarget:(id)target action:(SEL)action;

@end


@interface UILongPressGestureRecognizer (AutoTrack)

- (instancetype)bt_initWithTarget:(id)target action:(SEL)action;

- (void)bt_addTarget:(id)target action:(SEL)action;

@end

NS_ASSUME_NONNULL_END

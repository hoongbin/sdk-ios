//
//  UIApplication+AutoTrack.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 17/3/22.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (AutoTrack)

- (BOOL)bt_sendAction:(SEL)action
                   to:(nullable id)to
                 from:(nullable id)from
             forEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END

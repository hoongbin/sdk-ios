//
//  UIView+sa_autoTrack.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/6/11.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@protocol SAUIViewAutoTrack
@optional
-(NSString *)bt_elementContent;
@end;

@interface UIView (AutoTrack)<SAUIViewAutoTrack>
-(NSString *)bt_elementContent;
@end

@interface UIButton (AutoTrack)<SAUIViewAutoTrack>
-(NSString *)bt_elementContent;
@end

@interface UILabel (AutoTrack)<SAUIViewAutoTrack>
-(NSString *)bt_elementContent;
@end

@interface UITextView (AutoTrack)<SAUIViewAutoTrack>
-(NSString *)bt_elementContent;
@end

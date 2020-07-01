//
//  UIView+sa_autoTrack.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/6/11.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "UIView+AutoTrack.h"

@implementation UIView (AutoTrack)
-(NSString *)bt_customContent {
    NSString *contentTitle = nil;
    SEL hintSel = NSSelectorFromString(@"btTitle");
    if ([self respondsToSelector:hintSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSString *btTitle = [self performSelector:hintSel];
#pragma clang diagnostic pop
        if (btTitle.length) {
            contentTitle = btTitle;
        }
    }
    return contentTitle;
}

-(NSString *)bt_elementContent {
    return [self bt_customContent];
}
@end

@implementation UIButton (AutoTrack)
-(NSString *)bt_elementContent {
    NSString *customContent = [self bt_customContent];;
    if (customContent) { return customContent; }
    NSString *bt_elementContent = self.currentAttributedTitle.string;
    if (bt_elementContent != nil && bt_elementContent.length > 0) {
        return bt_elementContent;
    }
    return self.currentTitle;
}
@end

@implementation UILabel (AutoTrack)
-(NSString *)bt_elementContent {
    NSString *customContent = [self bt_customContent];;
    if (customContent) { return customContent; }
    NSString *attributedText = self.attributedText.string;
    if (attributedText != nil && attributedText.length > 0) {
        return attributedText;
    }
    return self.text;
}
@end

@implementation UITextView (AutoTrack)
-(NSString *)bt_elementContent {
    NSString *customContent = [self bt_customContent];;
    if (customContent) { return customContent; }
    NSString *attributedText = self.attributedText.string;
    if (attributedText != nil && attributedText.length > 0) {
        return attributedText;
    }
    return  self.text;
}
@end

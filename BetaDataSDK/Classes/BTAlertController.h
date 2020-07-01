//
//  BTAlertController.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2019/3/4.
//  Copyright © 2019 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SAAlertActionStyle) {
    SAAlertActionStyleDefault,
    SAAlertActionStyleCancel,
    SAAlertActionStyleDestructive
};

typedef NS_ENUM(NSUInteger, BTAlertControllerStyle) {
    BTAlertControllerStyleActionSheet = 0,
    BTAlertControllerStyleAlert
};

@interface SAAlertAction : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic) SAAlertActionStyle style;
@property (nonatomic, copy) void (^handler)(SAAlertAction *);

@property (nonatomic, readonly) NSInteger tag;

+ (instancetype)actionWithTitle:(nullable NSString *)title style:(SAAlertActionStyle)style handler:(void (^ __nullable)(SAAlertAction *))handler;

@end

/**
 神策弹框的 BTAlertController，添加到黑名单。
 防止 $AppViewScreen 事件误采
 当系统版本低于8.0时，会使用 UIAlertView 或者 UIActionSheet，此时最多支持 4 个其他按钮
 */
@interface BTAlertController : UIViewController


/**
 BTAlertController 初始化

 @param title 标题
 @param message 提示信息
 @param preferredStyle 弹框类型
 @return BTAlertController
 */
- (instancetype)initWithTitle:(nullable NSString *)title message:(nullable NSString *)message preferredStyle:(BTAlertControllerStyle)preferredStyle;


/**
 添加一个 Action

 @param title Action 显示的 title
 @param style Action 的类型
 @param handler 回调处理方法，带有这个 Action 本身参数
 */
- (void)addActionWithTitle:(NSString *_Nullable)title style:(SAAlertActionStyle)style handler:(void (^ __nullable)(SAAlertAction *))handler;


/**
 显示 BTAlertController
 */
- (void)show;

@end

NS_ASSUME_NONNULL_END

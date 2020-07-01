//
//  UIDevice+BTCommon.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2019/4/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (BTCommon)

+ (NSString *)bt_getIPAddress:(BOOL)preferIPv4;

+ (NSString *)bt_getNetWorkStates;

@property (nullable, nonatomic, readonly) NSString *bt_machineModel;

@property (nullable, nonatomic, readonly) NSString *bt_machineModelName;

@end

NS_ASSUME_NONNULL_END

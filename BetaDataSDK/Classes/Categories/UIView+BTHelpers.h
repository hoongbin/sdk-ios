//  BTSwizzle.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/20/16
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIView (BTHelpers)

- (UIImage *)bt_snapshotImage;
- (UIImage *)bt_snapshotForBlur;
- (int)bt_fingerprintVersion;

- (NSString *)bt_varA;
- (NSString *)bt_varB;
- (NSString *)bt_varC;
- (NSArray *)bt_varSetD;
- (NSString *)bt_varE;

@end


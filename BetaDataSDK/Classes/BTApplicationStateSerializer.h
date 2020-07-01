//
//  BTApplicationStateSerializer.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BTObjectSerializerConfig;
@class BTObjectIdentityProvider;

@interface BTApplicationStateSerializer : NSObject

- (instancetype)initWithApplication:(UIApplication *)application
                      configuration:(BTObjectSerializerConfig *)configuration
             objectIdentityProvider:(BTObjectIdentityProvider *)objectIdentityProvider;

- (UIImage *)screenshotImageForWindow:(UIWindow *)window;

- (NSDictionary *)objectHierarchyForWindow:(UIWindow *)window;

@end

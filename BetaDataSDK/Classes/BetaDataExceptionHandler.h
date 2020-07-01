//
//  BetaDataExceptionHandler.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2017/5/26.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BetaDataSDK;

@interface BetaDataExceptionHandler : NSObject

+ (instancetype)sharedHandler;
- (void)addSensorsAnalyticsInstance:(BetaDataSDK *)instance;

@end

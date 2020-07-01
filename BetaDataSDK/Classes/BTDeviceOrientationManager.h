//
//  BTDeviceOrientationManager.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/5/21.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
@interface SADeviceOrientationConfig:NSObject
@property (nonatomic,strong) NSString *deviceOrientation;
@property (nonatomic,assign) BOOL enableTrackScreenOrientation;//default is NO
@end

@interface BTDeviceOrientationManager : NSObject
@property (nonatomic,strong) void(^deviceOrientationBlock)(NSString * deviceOrientation);
- (void)startDeviceMotionUpdates;
- (void)stopDeviceMotionUpdates;
@end
#endif

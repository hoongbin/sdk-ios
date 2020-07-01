//
//  BTAppDelegate.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 04/11/2019.
//  Copyright (c) 2019 Zhou Kang. All rights reserved.
//

#import "BTAppDelegate.h"
#import "BetaDataSDK.h"
#import "BTRootViewController.h"

@implementation BTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self addRootVC];
    [self initBetaDataWithLaunchOptions:launchOptions];
    return YES;
}

- (void)addRootVC {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    BTRootViewController *rootVC = [BTRootViewController new];
    UINavigationController *navc = [[UINavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = navc;
    [self.window makeKeyAndVisible];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)initBetaDataWithLaunchOptions:(NSDictionary *)launchOptions {
    NSString *appID = @"1347736735";
    NSString *appSecret = @"098f6bcd4621d373cade4e832627b4f6";
    
    BTConfigOptions *options = [[BTConfigOptions alloc] initWithServerURL:@"http://t.api.betadata.mocaapp.cn/tracks" appID:appID secret:appSecret launchOptions:launchOptions];
    [BetaDataSDK sharedInstanceWithConfig:options];
    
    [[BetaDataSDK sharedInstance] enableLog:true];
    
    // 设置公共属性
//    [[BetaDataSDK sharedInstance] registerSuperProperties:@{@"appName": @"BTDemo"}];
    [[BetaDataSDK sharedInstance] trackInstallation];
    
    [[BetaDataSDK sharedInstance] trackViewScreen:_window.rootViewController];
    
    [[BetaDataSDK sharedInstance] set:@{ @"name": @"周康", @"age": @(1) }];
    
    // 打开自动采集, 并指定追踪哪些 AutoTrack 事件
    [[BetaDataSDK sharedInstance] enableAutoTrack:BetaDataEventTypeAppStart|
     BetaDataEventTypeAppEnd|
     BetaDataEventTypeAppViewScreen|
     BetaDataEventTypeAppClick];
    
    // 打通 App 与 H5，详见：https://sensorsdata.cn/manual/app_h5.html
    [[BetaDataSDK sharedInstance] addWebViewUserAgentSensorsDataFlag];
    
    [[BetaDataSDK sharedInstance] track:@"Buy_Flower" withProperties:@{ @"flower_count": @200, @"money": @100 }];
    
    [[BetaDataSDK sharedInstance] flush];
}

@end

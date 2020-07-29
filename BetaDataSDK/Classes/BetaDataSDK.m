//  BetaDataSDK.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 15/7/1.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif

#import <objc/runtime.h>
#include <sys/sysctl.h>
#include <stdlib.h>

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIScreen.h>

#import "JSONUtil.h"
#import "MessageQueueBySqlite.h"
#import "BTLogger.h"
#import "NSObject+BTSwizzle.h"
#import "BetaDataSDK.h"
#import "UIApplication+AutoTrack.h"
#import "UIViewController+AutoTrack.h"
#import "BTSwizzler.h"
#import "AutoTrackUtils.h"
#import "NSString+BTCommon.h"
#import "BetaDataExceptionHandler.h"
#import "BTServerUrl.h"
#import "BTAppExtensionDataManager.h"

#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
#import "BTKeyChainItemWrapper.h"
#endif

#import "BTDeviceOrientationManager.h"
#import "BTLocationManager.h"
#import "UIView+AutoTrack.h"
#import "NSThread+BTHelpers.h"
#import "BTCommonUtility.h"
#import "BTConstants.h"
#import "UIGestureRecognizer+AutoTrack.h"
#import "BetaDataSDK+Private.h"
#import "BTAlertController.h"
#import "NSData+GZIP.h"
#import "UIDevice+BTCommon.h"
#import "UIView+BetaData.h"
#import <WebKit/WebKit.h>

#define VERSION @"1.2.23"

static NSUInteger const SA_PROPERTY_LENGTH_LIMITATION = 8191;

static NSString *const BT_JS_GET_APP_INFO_SCHEME = @"betadataanalytics://getAppInfo";
static NSString *const BT_JS_TRACK_EVENT_NATIVE_SCHEME = @"betadataanalytics://trackEvent";
static NSString *const BT_TIME_DIFF = @"TIME_DIFF";
//中国运营商 mcc 标识
static NSString* const CARRIER_CHINA_MCC = @"460";

void *BetaDataAnalyticsQueueTag = &BetaDataAnalyticsQueueTag;

@implementation BetaDataDebugException

@end

@interface BTConfigOptions()
/**
 数据接收地址 Url
 */
@property(nonatomic, copy) NSString *serverURL;

@property(nonatomic, copy) NSString *appID;

@property(nonatomic, copy) NSString *appSecret;
/**
 App 启动的 launchOptions
 */
@property(nonatomic, copy) NSDictionary<NSString *, id> *launchOptions;
@end

@implementation BTConfigOptions

- (instancetype)initWithServerURL:(NSString *)serverURL appID:(nonnull NSString *)appID secret:(nonnull NSString *)secret launchOptions:(nullable NSDictionary<NSString *,id> *)launchOptions {
    self = [super init];
    if (self) {
        _serverURL = serverURL;
        _appID = appID;
        _appSecret = secret;
        _launchOptions = launchOptions;
    }
    return self;
}

@end

static BetaDataSDK *sharedInstance_ = nil;

@interface BetaDataSDK()

// 在内部，重新声明成可读写的
@property (atomic, strong) BetaDataAnalyticsPeople *people;

@property (atomic, copy) NSString *serverURL;

@property (atomic, copy) NSString *distinctId;
@property (atomic, copy) NSString *originalId;
@property (atomic, copy) NSString *loginId;
@property (atomic, copy) NSString *firstDay;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t readWriteQueue;

@property (atomic, strong) NSDictionary *automaticProperties;
@property (atomic, strong) NSDictionary *superProperties;
@property (nonatomic, strong) NSMutableDictionary *trackTimer;

@property (nonatomic, strong) NSPredicate *regexTestName;

@property (nonatomic, strong) NSPredicate *regexEventName;

@property (atomic, strong) MessageQueueBySqlite *messageQueue;

@property (nonatomic, strong) NSTimer *timer;

//用户设置的不被AutoTrack的Controllers
@property (nonatomic, strong) NSMutableArray *ignoredViewControllers;

@property (nonatomic, strong) NSMutableArray *heatMapViewControllers;

@property (nonatomic, strong) NSMutableArray *ignoredViewTypeList;

@property (nonatomic, strong) BTConfigOptions *configOptions;

#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
@property (nonatomic, strong) BTDeviceOrientationManager *deviceOrientationManager;
@property (nonatomic, strong) SADeviceOrientationConfig *deviceOrientationConfig;
#endif

#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_GPS
@property (nonatomic, strong) BTLocationManager *locationManager;
@property (nonatomic, strong) SAGPSLocationConfig *locationConfig;
#endif

@property (nonatomic, copy) void(^reqConfigBlock)(BOOL success , NSDictionary *configDict);
@property (nonatomic, assign) NSUInteger pullSDKConfigurationRetryMaxCount;

@property (nonatomic, copy) NSDictionary<NSString *,id> *(^dynamicSuperProperties)(void);
@property (nonatomic, copy) BOOL (^trackEventCallback)(NSString *, NSMutableDictionary<NSString *, id> *);

@property (nonatomic, strong) WKWebView *wkWebView;
@property (nonatomic, strong) dispatch_group_t loadUAGroup;
@property (nonatomic, copy)   NSString *userAgent;

///是否为被动启动
@property(nonatomic, assign, getter=isLaunchedPassively) BOOL launchedPassively;
@property(nonatomic,strong) NSMutableArray <UIViewController *> *launchedPassivelyControllers;
@end

@implementation BetaDataSDK {
    BetaDataDebugMode _debugMode;
    UInt64 _flushBulkSize;
    UInt64 _flushInterval;
    UInt64 _maxCacheSize;
    NSDateFormatter *_dateFormatter;
    BOOL _autoTrack;                    // 自动采集事件
    BOOL _appRelaunched;                // App 从后台恢复
    BOOL _showDebugAlertView;
    BOOL _heatMap;
    UInt8 _debugAlertViewHasShownNumber;
    NSString *_referrerScreenUrl;
    NSDictionary *_lastScreenTrackProperties;
    BOOL _applicationWillResignActive;
    BOOL _clearReferrerWhenAppEnd;
    BetaDataAnalyticsAutoTrackEventType _autoTrackEventType;
    BetaDataNetworkType _networkTypePolicy;
    NSString *_deviceModel;
    NSString *_osVersion;
    NSString *_originServerUrl;
    NSString *_cookie;
    NSString *_prevTrackID;
}

#pragma mark - Initialization

+ (BetaDataSDK *)sharedInstanceWithConfig:(nonnull BTConfigOptions *)configOptions {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance_ = [[self alloc] initWithServerURL:configOptions.serverURL
                                         andLaunchOptions:configOptions.launchOptions
                                             andDebugMode:BetaDataDebugOff];
        
        sharedInstance_.configOptions = configOptions;
        [sharedInstance_ checkAppKey];
    });
    return sharedInstance_;
}

+ (BetaDataSDK *_Nullable)sharedInstance {
    return sharedInstance_;
}

+ (UInt64)getCurrentTime {
    NSTimeInterval timeDelta = [[[NSUserDefaults standardUserDefaults] objectForKey:BT_TIME_DIFF] doubleValue];
    UInt64 time = [[NSDate date] timeIntervalSince1970] * 1000 - timeDelta;
    return time;
}

+ (UInt64)getSystemUpTime {
    UInt64 time = NSProcessInfo.processInfo.systemUptime * 1000;
    return time;
}

- (NSString *)uuid {
    return [[self class] getUniqueHardwareId];
}

+ (NSString *)getUniqueHardwareId {
//    NSString *uuidStr = [[UIDevice currentDevice] uuid];
//    if (uuidStr.length) {
//        return uuidStr;
//    }
//    else {
//        return @"";
//    }
    
    NSString *distinctId = NULL;
    
    // 宏 SENSORS_ANALYTICS_IDFA 定义时，优先使用IDFA
    //#if defined(SENSORS_ANALYTICS_IDFA)
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *uuid = ((NSUUID * (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        distinctId = [uuid UUIDString];
        // 在 iOS 10.0 以后，当用户开启限制广告跟踪，advertisingIdentifier 的值将是全零
        // 00000000-0000-0000-0000-000000000000
        if (!distinctId || [distinctId hasPrefix:@"00000000"]) {
            distinctId = NULL;
        }
    }
    //#endif
    
    // 没有IDFA，则使用IDFV
    if (!distinctId && NSClassFromString(@"UIDevice")) {
        distinctId = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
    
    // 没有IDFV，则使用UUID
    if (!distinctId) {
        BTLog(@"%@ error getting device identifier: falling back to uuid", self);
        distinctId = [[NSUUID UUID] UUIDString];
    }
    return distinctId;
    
}

- (void)loadUserAgentWithCompletion:(void (^)(NSString *))completion {
    if (self.userAgent) {
        return completion(self.userAgent);
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.wkWebView) {
            dispatch_group_notify(self.loadUAGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                completion(self.userAgent);
            });
        } else {
            self.wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero];
            self.loadUAGroup = dispatch_group_create();
            dispatch_group_enter(self.loadUAGroup);

            [self.wkWebView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id _Nullable response, NSError *_Nullable error) {
                if (error || !response) {
                    BTLog(@"WKWebView evaluateJavaScript load UA error:%@", error);
                    completion(nil);
                } else {
                    weakSelf.userAgent = response;
                    completion(weakSelf.userAgent);
                }
                weakSelf.wkWebView = nil;
                dispatch_group_leave(weakSelf.loadUAGroup);
            }];
        }
    });
}

- (BOOL)shouldTrackViewScreen:(UIViewController *)controller {
    static NSSet *blacklistedClasses = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSBundle *sensorsBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[BetaDataSDK class]] pathForResource:@"BetaDataSDK" ofType:@"bundle"]];
        //文件路径
        NSString *jsonPath = [sensorsBundle pathForResource:@"bt_autotrack_viewcontroller_blacklist.json" ofType:nil];
        NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
        @try {
            NSArray *blacklistedViewControllerClassNames = [NSJSONSerialization JSONObjectWithData:jsonData  options:NSJSONReadingAllowFragments  error:nil];
            blacklistedClasses = [NSSet setWithArray:blacklistedViewControllerClassNames];
        } @catch(NSException *exception) {  // json加载和解析可能失败
            BTLog(@"%@ error: %@", self, exception);
        }
    });
    
    __block BOOL shouldTrack = YES;
    [blacklistedClasses enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSString *blackClassName = (NSString *)obj;
        Class blackClass = NSClassFromString(blackClassName);
        if (blackClass && [controller isKindOfClass:blackClass]) {
            shouldTrack = NO;
            *stop = YES;
        }
    }];
    return shouldTrack;
}

- (instancetype)initWithServerURL:(NSString *)serverURL
                 andLaunchOptions:(NSDictionary *)launchOptions
                     andDebugMode:(BetaDataDebugMode)debugMode {
    @try {
        if (self = [self init]) {
            _autoTrackEventType = BetaDataEventTypeNone;
            _networkTypePolicy = BetaDataNetworkType3G | BetaDataNetworkType4G | BetaDataNetworkTypeWIFI;
            
            [NSThread bt_safelyRunOnMainThreadSync:^{
                UIApplicationState applicationState = UIApplication.sharedApplication.applicationState;
                //判断被动启动
                if (applicationState == UIApplicationStateBackground) {
                    self->_launchedPassively = YES;
                }
            }];
            
            _people = [[BetaDataAnalyticsPeople alloc] init];
            
            _debugMode = debugMode;
            [self enableLog];
            [self setServerUrl:serverURL];
            
            _flushInterval = 15 * 1000;
            _flushBulkSize = 100;
            _maxCacheSize = 10000;
            _autoTrack = NO;
            _heatMap = NO;
            _appRelaunched = NO;
            _showDebugAlertView = YES;
            _debugAlertViewHasShownNumber = 0;
            _referrerScreenUrl = nil;
            _lastScreenTrackProperties = nil;
            _applicationWillResignActive = NO;
            _clearReferrerWhenAppEnd = NO;
            _pullSDKConfigurationRetryMaxCount = 3;// SDK 开启关闭功能接口最大重试次数
            
            _prevTrackID = @"";
            
            NSString *label = [NSString stringWithFormat:@"com.betadata.serialQueue.%p", self];
            self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
            dispatch_queue_set_specific(self.serialQueue, BetaDataAnalyticsQueueTag, &BetaDataAnalyticsQueueTag, NULL);
            
            NSString *readWriteLabel = [NSString stringWithFormat:@"com.betadata.readWriteQueue.%p", self];
            self.readWriteQueue = dispatch_queue_create([readWriteLabel UTF8String], DISPATCH_QUEUE_SERIAL);
            
            NSDictionary *sdkConfig = [[NSUserDefaults standardUserDefaults] objectForKey:BT_SDK_TRACK_CONFIG];
            
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
            _deviceOrientationConfig = [[SADeviceOrientationConfig alloc]init];
#endif
            
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_GPS
            _locationConfig = [[SAGPSLocationConfig alloc]init];
#endif
            _ignoredViewControllers = [[NSMutableArray alloc] init];
            _ignoredViewTypeList = [[NSMutableArray alloc] init];
            _heatMapViewControllers = [[NSMutableArray alloc] init];
            _dateFormatter = [[NSDateFormatter alloc] init];
            [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            
            self.flushBeforeEnterBackground = YES;
            
            self.messageQueue = [[MessageQueueBySqlite alloc] initWithFilePath:[self filePathForData:@"message-v2"]];
            if (self.messageQueue == nil) {
                BTLog(@"SqliteException: init Message Queue in Sqlite fail");
            }
            
            // 取上一次进程退出时保存的distinctId、loginId、superProperties
            [self unarchive];
            
            if (self.firstDay == nil) {
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                self.firstDay = [dateFormatter stringFromDate:[NSDate date]];
                [self archiveFirstDay];
            }
            
            self.automaticProperties = [self collectAutomaticProperties];
            self.trackTimer = [NSMutableDictionary dictionary];
            
            NSString *namePattern = @"^((?!^distinct_id$|^original_id$|^time$|^event$|^properties$|^id$|^first_id$|^second_id$|^users$|^events$|^event$|^user_id$|^date$|^datetime$)[a-zA-Z_$][a-zA-Z\\d_$]{0,99})$";
            self.regexTestName = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", namePattern];
            
            NSString *eventPattern = @"^\\_((AppEnd)|(AppStart)|(AppViewScreen)|(AppClick)|(SignUp))|(^AppCrashed)$";
            self.regexEventName = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",eventPattern];
            
            [self setUpListeners];
            
            // XXX: App Active 的时候会启动计时器，此处不需要启动
            //        [self startFlushTimer];
            NSString *logMessage = nil;
            logMessage = [NSString stringWithFormat:@"%@ initialized the instance of Sensors Analytics SDK with server url '%@', debugMode: '%@'",
                          self, serverURL, [self debugModeToString:debugMode]];
            BTLog(@"%@", logMessage);
            
            //打开debug模式，弹出提示
#ifndef SENSORS_ANALYTICS_DISABLE_DEBUG_WARNING
            if (_debugMode != BetaDataDebugOff) {
                NSString *alertMessage = nil;
                if (_debugMode == BetaDataDebugOnly) {
                    alertMessage = @"现在您打开了'DEBUG_ONLY'模式，此模式下只校验数据但不导入数据，数据出错时会以提示框的方式提示开发者，请上线前一定关闭。";
                } else if (_debugMode == BetaDataDebugAndTrack) {
                    alertMessage = @"现在您打开了'DEBUG_AND_TRACK'模式，此模式下会校验数据并且导入数据，数据出错时会以提示框的方式提示开发者，请上线前一定关闭。";
                }
                [self showDebugModeWarning:alertMessage withNoMoreButton:NO];
            }
#endif
        }
    } @catch(NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
    return self;
}

- (NSDictionary *)getPresetProperties {
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    @try {
        id app_version = [_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
        if (app_version) {
            [properties setValue:app_version forKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
        }
        [properties setValue:[_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_LIB] forKey:BT_EVENT_COMMON_PROPERTY_LIB];
        [properties setValue:[_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_LIB_VERSION] forKey:BT_EVENT_COMMON_PROPERTY_LIB_VERSION];
        [properties setValue:@"Apple" forKey:BT_EVENT_COMMON_PROPERTY_MANUFACTURER];
        [properties setValue:_deviceModel forKey:BT_EVENT_COMMON_PROPERTY_MODEL];
        [properties setValue:@"iOS" forKey:BT_EVENT_COMMON_PROPERTY_OS];
        [properties setValue:_osVersion forKey:BT_EVENT_COMMON_PROPERTY_OS_VERSION];
        [properties setValue:[_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_SCREEN_HEIGHT] forKey:BT_EVENT_COMMON_PROPERTY_SCREEN_HEIGHT];
        [properties setValue:[_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_SCREEN_WIDTH] forKey:BT_EVENT_COMMON_PROPERTY_SCREEN_WIDTH];
        NSString *networkType = [UIDevice bt_getNetWorkStates];
        [properties setObject:networkType forKey:BT_EVENT_COMMON_PROPERTY_NETWORK_TYPE];
        if ([networkType isEqualToString:@"WIFI"]) {
            [properties setObject:@YES forKey:BT_EVENT_COMMON_PROPERTY_WIFI];
        } else {
            [properties setObject:@NO forKey:BT_EVENT_COMMON_PROPERTY_WIFI];
        }
        [properties setValue:[_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_CARRIER] forKey:BT_EVENT_COMMON_PROPERTY_CARRIER];
        if ([self isFirstDay]) {
            [properties setObject:@YES forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY];
        } else {
            [properties setObject:@NO forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY];
        }
        [properties setValue:[_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_DEVICE_ID] forKey:BT_EVENT_COMMON_PROPERTY_DEVICE_ID];
    } @catch(NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
    return [properties copy];
}

- (void)setServerUrl:(NSString *)serverUrl {
    _originServerUrl = serverUrl;
    if (serverUrl == nil || [serverUrl length] == 0 || _debugMode == BetaDataDebugOff) {
        _serverURL = serverUrl;
    } else {
        // 将 Server URI Path 替换成 Debug 模式的 '/debug'
        NSURL *tempBaseUrl = [NSURL URLWithString:serverUrl];
        if (tempBaseUrl.lastPathComponent.length > 0) {
            tempBaseUrl = [tempBaseUrl URLByDeletingLastPathComponent];
        }
        NSURL *url = [tempBaseUrl URLByAppendingPathComponent:@"debug"];
        NSString *host = url.host;
        if ([host rangeOfString:@"_"].location != NSNotFound) { //包含下划线日志提示
            NSString * referenceUrl = @"https://en.wikipedia.org/wiki/Hostname";
            BTLog(@"Server url:%@ contains '_'  is not recommend,see details:%@",serverUrl,referenceUrl);
        }
        _serverURL = [url absoluteString];
    }
}

- (void)configDebugModeServerUrl {
    if (_debugMode  == BetaDataDebugOff ) {
        self.serverURL = _originServerUrl;
    } else {
        [self setServerUrl:_originServerUrl];
    }
}

- (void)disableDebugMode {
    _debugMode = BetaDataDebugOff;
    _serverURL = _originServerUrl;
    [self enableLog:NO];
}

- (NSString *)debugModeToString:(BetaDataDebugMode)debugMode {
    NSString *modeStr = nil;
    switch (debugMode) {
    case BetaDataDebugOff:
        modeStr = @"DebugOff";
        break;
    case BetaDataDebugAndTrack:
        modeStr = @"DebugAndTrack";
        break;
    case BetaDataDebugOnly:
        modeStr = @"DebugOnly";
        break;
    default:
        modeStr = @"Unknown";
        break;
    }
    return modeStr;
}

- (void)showDebugModeWarning:(NSString *)message withNoMoreButton:(BOOL)showNoMore {
#ifndef SENSORS_ANALYTICS_DISABLE_DEBUG_WARNING
    if (_debugMode == BetaDataDebugOff) {
        return;
    }
    
    if (!_showDebugAlertView) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self->_debugAlertViewHasShownNumber >= 3) {
                return;
            }
            self->_debugAlertViewHasShownNumber += 1;
            NSString *alertTitle = @"SensorsData 重要提示";
            BTAlertController *alertController = [[BTAlertController alloc] initWithTitle:alertTitle message:message preferredStyle:BTAlertControllerStyleAlert];
            [alertController addActionWithTitle:@"确定" style:SAAlertActionStyleCancel handler:^(SAAlertAction * _Nonnull action) {
                self->_debugAlertViewHasShownNumber -= 1;
            }];
            if (showNoMore) {
                [alertController addActionWithTitle:@"不再显示" style:SAAlertActionStyleDefault handler:^(SAAlertAction * _Nonnull action) {
                    self->_showDebugAlertView = NO;
                }];
            }
            [alertController show];
        } @catch (NSException *exception) {
        } @finally {
        }
    });
#endif
}

- (void)showDebugModeAlertWithParams:(NSDictionary<NSString *, id> *)params {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            
            dispatch_block_t alterViewBlock = ^{
                
                NSString *alterViewMessage = @"";
                if (self -> _debugMode == BetaDataDebugAndTrack) {
                    alterViewMessage = @"开启调试模式，校验数据，并将数据导入神策分析中；\n关闭 App 进程后，将自动关闭调试模式。";
                }else if (self -> _debugMode == BetaDataDebugOnly) {
                    alterViewMessage = @"开启调试模式，校验数据，但不进行数据导入；\n关闭 App 进程后，将自动关闭调试模式。";
                }else {
                    alterViewMessage = @"已关闭调试模式，重新扫描二维码开启";
                }
                BTAlertController *alertController = [[BTAlertController alloc] initWithTitle:@"" message:alterViewMessage preferredStyle:BTAlertControllerStyleAlert];
                [alertController addActionWithTitle:@"确定" style:SAAlertActionStyleCancel handler:nil];
                [alertController show];
            };
            
            NSString *alertTitle = @"SDK 调试模式选择";
            NSString *alertMessage = @"";
            if (self->_debugMode == BetaDataDebugAndTrack) {
                alertMessage = @"当前为 调试模式（导入数据）";
            }else if (self->_debugMode == BetaDataDebugOnly) {
                alertMessage = @"当前为 调试模式（不导入数据）";
            }else {
                alertMessage = @"调试模式已关闭";
            }
            BTAlertController *alertController = [[BTAlertController alloc] initWithTitle:alertTitle message:alertMessage preferredStyle:BTAlertControllerStyleAlert];
            void(^handler)(BetaDataDebugMode) = ^(BetaDataDebugMode debugMode) {
                self -> _debugMode = debugMode;
                [self enableLog:YES];
                
                alterViewBlock();
                
                [self configDebugModeServerUrl];
                [self debugModeCallBackWithParams:params];
            };
            [alertController addActionWithTitle:@"开启调试模式（导入数据）" style:SAAlertActionStyleDefault handler:^(SAAlertAction * _Nonnull action) {
                handler(BetaDataDebugAndTrack);
            }];
            [alertController addActionWithTitle:@"开启调试模式（不导入数据）" style:SAAlertActionStyleDefault handler:^(SAAlertAction * _Nonnull action) {
                handler(BetaDataDebugOnly);
            }];
            [alertController addActionWithTitle:@"取消" style:SAAlertActionStyleCancel handler:nil];
            [alertController show];
        } @catch (NSException *exception) {
        } @finally {
        }
    });
}

- (void)debugModeCallBackWithParams:(NSDictionary<NSString *,id> *)params {
    
    if (!self.serverURL) {
        BTLog(@"serverURL error，Please check the serverURL");
        return;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:self.serverURL];
    
    NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray arrayWithArray:urlComponents.queryItems];
    //添加参数
    [params enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSURLQueryItem *queryItem = [NSURLQueryItem queryItemWithName:key value:obj];
        [queryItems addObject:queryItem];
    }];
    
    urlComponents.queryItems = queryItems;
    NSURL *callBackUrl = [urlComponents URL];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:callBackUrl];
    request.timeoutInterval = 30;
    [request setHTTPMethod:@"POST"];
    
    NSDictionary *callData = @{@"distinct_id":[self getBestId]};
    JSONUtil *jsonUtil = [[JSONUtil alloc] init];
    NSData *jsonData = [jsonUtil JSONSerializeObject:callData];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [request setHTTPBody:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSInteger statusCode = [(NSHTTPURLResponse*)response statusCode];
        if (statusCode == 200) {
            BTLog(@"config debugMode CallBack success");
        } else {
            BTLog(@"config debugMode CallBack Faild statusCode：%d，url：%@",statusCode,callBackUrl);
        }
    }];
    [task resume];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 1) {
        _showDebugAlertView = NO;
    } else if (buttonIndex == 0) {
        _debugAlertViewHasShownNumber -= 1;
    }
}

- (BOOL)isFirstDay {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *current = [dateFormatter stringFromDate:[NSDate date]];
    
    return [[self firstDay] isEqualToString:current];
}

- (void)setFlushNetworkPolicy:(BetaDataNetworkType)networkType {
    @synchronized (self) {
        _networkTypePolicy = networkType;
    }
}

- (BetaDataNetworkType)toNetworkType:(NSString *)networkType {
    if ([@"NULL" isEqualToString:networkType]) {
        return BetaDataNetworkTypeNONE;
    } else if ([@"WIFI" isEqualToString:networkType]) {
        return BetaDataNetworkTypeWIFI;
    } else if ([@"2G" isEqualToString:networkType]) {
        return BetaDataNetworkType2G;
    }   else if ([@"3G" isEqualToString:networkType]) {
        return BetaDataNetworkType3G;
    }   else if ([@"4G" isEqualToString:networkType]) {
        return BetaDataNetworkType4G;
    }else if ([@"UNKNOWN" isEqualToString:networkType]) {
        return BetaDataNetworkType4G;
    }
    return BetaDataNetworkTypeNONE;
}

- (UIViewController *)currentViewController {
    __block UIViewController *currentVC = nil;
    if ([NSThread isMainThread]) {
        @try {
            UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
            if (rootViewController != nil) {
                currentVC = [self getCurrentVCFrom:rootViewController isRoot:YES];
            }
        } @catch (NSException *exception) {
            BTLog(@"%@ error: %@", self, exception);
        }
        return currentVC;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            @try {
                UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
                if (rootViewController != nil) {
                    currentVC = [self getCurrentVCFrom:rootViewController isRoot:YES];
                }
            } @catch (NSException *exception) {
                BTLog(@"%@ error: %@", self, exception);
            }
        });
        return currentVC;
    }
}

- (UIViewController *)getCurrentVCFrom:(UIViewController *)rootVC isRoot:(BOOL)isRoot{
    @try {
        UIViewController *currentVC;
        if ([rootVC presentedViewController]) {
            // 视图是被presented出来的
            rootVC = [self getCurrentVCFrom:rootVC.presentedViewController isRoot:NO];
        }
        
        if ([rootVC isKindOfClass:[UITabBarController class]]) {
            // 根视图为UITabBarController
            currentVC = [self getCurrentVCFrom:[(UITabBarController *)rootVC selectedViewController] isRoot:NO];
        } else if ([rootVC isKindOfClass:[UINavigationController class]]){
            // 根视图为UINavigationController
            currentVC = [self getCurrentVCFrom:[(UINavigationController *)rootVC visibleViewController] isRoot:NO];
        } else {
            // 根视图为非导航类
            if ([rootVC respondsToSelector:NSSelectorFromString(@"contentViewController")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                UIViewController *tempViewController = [rootVC performSelector:NSSelectorFromString(@"contentViewController")];
#pragma clang diagnostic pop
                if (tempViewController) {
                    currentVC = [self getCurrentVCFrom:tempViewController isRoot:NO];
                }
            } else {
                if (rootVC.childViewControllers && rootVC.childViewControllers.count == 1 && isRoot) {
                    currentVC = [self getCurrentVCFrom:rootVC.childViewControllers[0] isRoot:NO];
                }
                else {
                    currentVC = rootVC;
                }
            }
        }
        
        return currentVC;
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
}

- (void)trackFromH5WithEvent:(NSString *)eventInfo enableVerify:(BOOL)enableVerify {
    dispatch_async(self.serialQueue, ^{
        @try {
            if (eventInfo == nil) {
                return;
            }
            
            NSData *jsonData = [eventInfo dataUsingEncoding:NSUTF8StringEncoding];
            NSError *err;
            NSMutableDictionary *eventDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                             options:NSJSONReadingMutableContainers
                                                                               error:&err];
            if(err) {
                return;
            }
            
            if (!eventDict) {
                return;
            }
            
            if (enableVerify) {
                NSString *serverUrl = [eventDict valueForKey:@"server_url"];
                if (serverUrl != nil) {
                    BTServerUrl *h5ServerUrl = [[BTServerUrl alloc] initWithUrl:serverUrl];
                    BTServerUrl *appServerUrl = [[BTServerUrl alloc] initWithUrl:self->_serverURL];
                    if (![appServerUrl check:h5ServerUrl]) {
                        return;
                    }
                } else {
                    //防止 H5 集成的 JS SDK 版本太老，没有发 server_url
                    return;
                }
            }
            
            NSString *type = [eventDict valueForKey:BT_EVENT_TYPE];
            NSString *bestId = self.getBestId;
            
            [eventDict setValue:@([[self class] getCurrentTime]) forKey:BT_EVENT_TIME];
            
            if([type isEqualToString:@"track_signup"]){
                NSString *realOriginalId = self.originalId ?: self.distinctId;
                [eventDict setValue:realOriginalId forKey:@"original_id"];
            } else {
                //[eventDict setValue:bestId forKey:BT_EVENT_DISTINCT_ID];
            }
            [eventDict setValue:@(arc4random()) forKey:BT_EVENT_TRACK_ID];
            
            //NSDictionary *libDict = [eventDict objectForKey:BT_EVENT_LIB];
            id app_version = [self->_automaticProperties objectForKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
            if (app_version) {
                //[libDict setValue:app_version forKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
            }
            
            //update lib $app_version from super properties
            app_version = [self->_superProperties objectForKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
            if (app_version) {
                //[libDict setValue:app_version forKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
            }
            
            NSMutableDictionary *automaticPropertiesCopy = [NSMutableDictionary dictionaryWithDictionary:self->_automaticProperties];
            [automaticPropertiesCopy removeObjectForKey:BT_EVENT_COMMON_PROPERTY_LIB];
            [automaticPropertiesCopy removeObjectForKey:BT_EVENT_COMMON_PROPERTY_LIB_VERSION];
            
            NSMutableDictionary *propertiesDict = [eventDict objectForKey:BT_EVENT_PROPERTIES];
            if([type isEqualToString:@"track"] || [type isEqualToString:@"track_signup"]){
                // track / track_signup 类型的请求，还是要加上各种公共property
                // 这里注意下顺序，按照优先级从低到高，依次是automaticProperties, superProperties,dynamicSuperPropertiesDict,propertieDict
                [propertiesDict addEntriesFromDictionary:automaticPropertiesCopy];
                [propertiesDict addEntriesFromDictionary:self->_superProperties];
                NSDictionary *dynamicSuperPropertiesDict = self.dynamicSuperProperties?self.dynamicSuperProperties():nil;
                //去重
                [self unregisterSameLetterSuperProperties:dynamicSuperPropertiesDict];
                [propertiesDict addEntriesFromDictionary:dynamicSuperPropertiesDict];
                
                // 每次 track 时手机网络状态
                NSString *networkType = [UIDevice bt_getNetWorkStates];
                [propertiesDict setObject:networkType forKey:BT_EVENT_COMMON_PROPERTY_NETWORK_TYPE];
                if ([networkType isEqualToString:@"WIFI"]) {
                    [propertiesDict setObject:@YES forKey:BT_EVENT_COMMON_PROPERTY_WIFI];
                } else {
                    [propertiesDict setObject:@NO forKey:BT_EVENT_COMMON_PROPERTY_WIFI];
                }
                
                //  是否首日访问
                if([type isEqualToString:@"track"]) {
                    if ([self isFirstDay]) {
                        [propertiesDict setObject:@YES forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY];
                    } else {
                        [propertiesDict setObject:@NO forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY];
                    }
                }
                [propertiesDict removeObjectForKey:@"_nocache"];
            }
            
            [eventDict removeObjectForKey:@"_nocache"];
            [eventDict removeObjectForKey:@"server_url"];
            
            // $project & $token
            //NSString *project = [propertiesDict objectForKey:BT_EVENT_COMMON_OPTIONAL_PROPERTY_PROJECT];
            //NSString *token = [propertiesDict objectForKey:BT_EVENT_COMMON_OPTIONAL_PROPERTY_TOKEN];
            //            if (project) {
            //                [propertiesDict removeObjectForKey:BT_EVENT_COMMON_OPTIONAL_PROPERTY_PROJECT];
            //                [eventDict setValue:project forKey:BT_EVENT_PROJECT];
            //            }
            //            if (token) {
            //                [propertiesDict removeObjectForKey:BT_EVENT_COMMON_OPTIONAL_PROPERTY_TOKEN];
            //                [eventDict setValue:token forKey:BT_EVENT_TOKEN];
            //            }
            
            NSDictionary *enqueueEvent = [self willEnqueueWithType:type andEvent:eventDict];
            if (!enqueueEvent) {
                return;
            }
            BTLog(@"\n【track event from H5】:\n%@", enqueueEvent);
            
            if([type isEqualToString:@"track_signup"]) {
                
                NSString *newLoginId = [eventDict objectForKey:BT_EVENT_DISTINCT_ID];
                
                if (![newLoginId isEqualToString:[self loginId]]) {
                    self.loginId = newLoginId;
                    [self archiveLoginId];
                    if (![newLoginId isEqualToString:[self distinctId]]) {
                        self.originalId = [self distinctId];
                        [self enqueueWithType:type andEvent:[enqueueEvent copy]];
                    }
                }
            } else {
                [self enqueueWithType:type andEvent:[enqueueEvent copy]];
            }
        } @catch (NSException *exception) {
            BTLog(@"%@: %@", self, exception);
        }
    });
}

- (void)trackFromH5WithEvent:(NSString *)eventInfo {
    [self trackFromH5WithEvent:eventInfo enableVerify:NO];
}

- (BOOL)showUpWebView:(id)webView WithRequest:(NSURLRequest *)request {
    return [self showUpWebView:webView WithRequest:request andProperties:nil];
}

- (BOOL)showUpWebView:(id)webView WithRequest:(NSURLRequest *)request enableVerify:(BOOL)enableVerify {
    return [self showUpWebView:webView WithRequest:request andProperties:nil enableVerify:enableVerify];
}

-(BOOL)shouldHandleWebView:(id)webView request:(NSURLRequest*)request {
    if (webView == nil) {
        BTLog(@"showUpWebView == nil");
        return NO;
    }
    
    if (request == nil || ![request isKindOfClass:NSURLRequest.class]) {
        BTLog(@"request == nil or not NSURLRequest class");
        return NO;
    }
    
    NSString *urlString = request.URL.absoluteString;
    if ([urlString rangeOfString:BT_JS_GET_APP_INFO_SCHEME].length ||[urlString rangeOfString:BT_JS_TRACK_EVENT_NATIVE_SCHEME].length) {
        return YES;
    }
    return NO;
}

- (BOOL)showUpWebView:(id)webView WithRequest:(NSURLRequest *)request andProperties:(NSDictionary *)propertyDict enableVerify:(BOOL)enableVerify {
    if (![self shouldHandleWebView:webView request:request]) {
        return NO;
    }
    @try {
        BTLog(@"showUpWebView");
        JSONUtil *_jsonUtil = [[JSONUtil alloc] init];
        NSDictionary *bridgeCallbackInfo = [self webViewJavascriptBridgeCallbackInfo];
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        if (bridgeCallbackInfo) {
            [properties addEntriesFromDictionary:bridgeCallbackInfo];
        }
        if (propertyDict) {
            [properties addEntriesFromDictionary:propertyDict];
        }
        NSData* jsonData = [_jsonUtil JSONSerializeObject:properties];
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        NSString *js = [NSString stringWithFormat:@"sensorsdata_app_js_bridge_call_js('%@')", jsonString];
        
        //判断系统是否支持WKWebView
        Class wkWebViewClass = NSClassFromString(@"WKWebView");
        
        NSString *urlstr = request.URL.absoluteString;
        if (urlstr == nil) {
            return YES;
        }
        
        //解析参数
        NSAssert(![webView isKindOfClass:NSClassFromString(@"UIWebView")], @"当前集成方式已禁用 UIWebView！❌");
        
        NSMutableDictionary *paramsDic = [[NSMutableDictionary alloc] init];
        NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlstr];
        for (NSURLQueryItem *item in urlComponents.queryItems) {
            [paramsDic setValue:item.value forKey:item.name];
        }
        
        if(wkWebViewClass && [webView isKindOfClass:wkWebViewClass]) {//WKWebView
            BTLog(@"showUpWebView: WKWebView");
            if ([urlstr rangeOfString:BT_JS_GET_APP_INFO_SCHEME].location != NSNotFound) {
                typedef void(^Myblock)(id,NSError *);
                Myblock myBlock = ^(id _Nullable response, NSError * _Nullable error){
                    BTLog(@"response: %@ error: %@", response, error);
                };
                SEL sharedManagerSelector = NSSelectorFromString(@"evaluateJavaScript:completionHandler:");
                if (sharedManagerSelector) {
                    ((void (*)(id, SEL, NSString *, Myblock))[webView methodForSelector:sharedManagerSelector])(webView, sharedManagerSelector, js, myBlock);
                }
            } else if ([urlstr rangeOfString:BT_JS_TRACK_EVENT_NATIVE_SCHEME].location != NSNotFound) {
                if ([paramsDic count] > 0) {
                    NSString *eventInfo = [paramsDic objectForKey:BT_EVENT_NAME];
                    if (eventInfo != nil) {
                        NSString* encodedString = [eventInfo stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                        [self trackFromH5WithEvent:encodedString enableVerify:enableVerify];
                    }
                }
            }
        } else{
            BTLog(@"showUpWebView: not WKWebView");
        }
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
    } @finally {
        return YES;
    }
}

- (BOOL)showUpWebView:(id)webView WithRequest:(NSURLRequest *)request andProperties:(NSDictionary *)propertyDict {
    return [self showUpWebView:webView WithRequest:request andProperties:propertyDict enableVerify:NO];
}

- (void)setMaxCacheSize:(UInt64)maxCacheSize {
    if (maxCacheSize > 0) {
        //防止设置的值太小导致事件丢失
        if (maxCacheSize < 10000) {
            maxCacheSize = 10000;
        }
        _maxCacheSize = maxCacheSize;
    }
}

- (UInt64)getMaxCacheSize {
    return _maxCacheSize;
}

- (NSMutableDictionary *)webViewJavascriptBridgeCallbackInfo {
    NSMutableDictionary *libProperties = [[NSMutableDictionary alloc] init];
    //[libProperties setValue:@"iOS" forKey:BT_EVENT_TYPE];
    if ([self loginId] != nil) {
        //[libProperties setValue:[self loginId] forKey:BT_EVENT_DISTINCT_ID];
        [libProperties setValue:[NSNumber numberWithBool:YES] forKey:@"is_login"];
    } else{
        //[libProperties setValue:[self distinctId] forKey:BT_EVENT_DISTINCT_ID];
        [libProperties setValue:[NSNumber numberWithBool:NO] forKey:@"is_login"];
    }
    return [libProperties copy];
}

- (void)login:(NSString *)loginId {
    [self login:loginId withProperties:nil];
}

- (void)login:(NSString *)loginId withProperties:(NSDictionary * _Nullable )properties {
    if (loginId == nil || loginId.length == 0) {
        BTLog(@"%@ cannot login blank login_id: %@", self, loginId);
        return;
    }
    if (loginId.length > 255) {
        BTLog(@"%@ max length of login_id is 255, login_id: %@", self, loginId);
        return;
    }
    if (![loginId isEqualToString:[self loginId]]) {
        self.loginId = loginId;
        [self archiveLoginId];
        if (![loginId isEqualToString:[self distinctId]]) {
            self.originalId = [self distinctId];
            // to do track event
        }
    }
}

- (void)logout {
    self.loginId = nil;
    [self archiveLoginId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST];
}

- (NSString *)anonymousId {
    return _distinctId;
}

- (void)resetAnonymousId {
    self.distinctId = [[self class] getUniqueHardwareId];
    [self archiveDistinctId];
}

- (void)trackAppCrash {
    // Install uncaught exception handlers first
    [[BetaDataExceptionHandler sharedHandler] addSensorsAnalyticsInstance:self];
}

- (void)enableAutoTrack:(BetaDataAnalyticsAutoTrackEventType)eventType {
    if (_autoTrackEventType != eventType) {
        _autoTrackEventType = eventType;
        _autoTrack = (_autoTrackEventType != BetaDataEventTypeNone);
        [self _enableAutoTrack];
    }
    // 是否首次启动
    BOOL isFirstStart = NO;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:BT_HAS_LAUNCHED_ONCE]) {
        isFirstStart = YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:BT_HAS_LAUNCHED_ONCE];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([self isLaunchedPassively]) {
            // 追踪 AppStart 事件
            if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppStart] == NO) {
                
                //                [self track:BT_EVENT_NAME_APP_START_PASSIVELY withProperties:@{
                //                                                                               BT_EVENT_PROPERTY_RESUME_FROM_BACKGROUND : @(self->_appRelaunched),
                //                                                                               BT_EVENT_PROPERTY_APP_FIRST_START : @(isFirstStart),
                //                                                                               } withTrackType:BetaDataTrackTypeAuto];
            }
        } else {
            // 追踪 AppStart 事件
            if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppStart] == NO) {
                [self track:BT_EVENT_NAME_APP_START withProperties:@{
                    //                                                                     BT_EVENT_PROPERTY_RESUME_FROM_BACKGROUND : @(self->_appRelaunched),
                    //BT_EVENT_PROPERTY_APP_FIRST_START : @(isFirstStart),
                } withTrackType:BetaDataTrackTypeAuto];
            }
            // 启动 AppEnd 事件计时器
            if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppEnd] == NO) {
                [self trackTimer:BT_EVENT_NAME_APP_END withTimeUnit:BetaDataTimeUnitMilliseconds];
            }
        }
    });
}

- (BOOL)isAutoTrackEnabled {
    return _autoTrack;
}

- (BOOL)isAutoTrackEventTypeIgnored:(BetaDataAnalyticsAutoTrackEventType)eventType {
    return !(_autoTrackEventType & eventType);
}

- (void)ignoreViewType:(Class)aClass {
    [_ignoredViewTypeList addObject:aClass];
}

- (BOOL)isViewTypeIgnored:(Class)aClass {
    return [_ignoredViewTypeList containsObject:aClass];
}

- (BOOL)isViewControllerIgnored:(UIViewController *)viewController {
    if (viewController == nil) {
        return false;
    }
    NSString *screenName = NSStringFromClass([viewController class]);
    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
        if ([_ignoredViewControllers containsObject:screenName]) {
            return true;
        }
    }
    return false;
}

- (BOOL)isViewControllerStringIgnored:(NSString *)viewControllerString {
    if (viewControllerString == nil) {
        return false;
    }
    
    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
        if ([_ignoredViewControllers containsObject:viewControllerString]) {
            return true;
        }
    }
    return false;
}

- (void)showDebugInfoView:(BOOL)show {
    _showDebugAlertView = show;
}

- (void)flushByType:(NSString *)type withSize:(int)flushSize andFlushMethod:(BOOL (^)(NSArray *, NSString *))flushMethod {
    while (true) {
        NSArray *recordArray = [self.messageQueue getFirstRecords:flushSize withType:type];
        if (recordArray == nil) {
            BTLog(@"Failed to get records from SQLite.");
            break;
        }
        
        if ([recordArray count] == 0 || !flushMethod(recordArray, type)) {
            break;
        }
        
        if (![self.messageQueue removeFirstRecords:recordArray.count withType:type]) {
            BTLog(@"Failed to remove records from SQLite.");
            break;
        }
    }
}

- (void)_flush:(BOOL) vacuumAfterFlushing {
    if (_serverURL == nil || [_serverURL isEqualToString:@""]) {
        return;
    }
    // 判断当前网络类型是否符合同步数据的网络策略
    NSString *networkType = [UIDevice bt_getNetWorkStates];
    if (!([self toNetworkType:networkType] & _networkTypePolicy)) {
        return;
    }
    // 使用 Post 发送数据
    BOOL (^flushByPost)(NSArray *, NSString *) = ^(NSArray *recordArray, NSString *type) {
        NSString *jsonString;
        NSData *zippedData;
        NSString *b64String;
        NSString *postBody;
        
        @try {
            // 1. 先进行数据组装并转JSON
            NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
            dataDict[@"device_id"] = [[self class] getUniqueHardwareId];
            if (self->_prevTrackID.length) {
                dataDict[@"before_id"] = self->_prevTrackID;
            }
            dataDict[@"events"] = recordArray;
            dataDict[@"time"] = [@([[self class] getCurrentTime]) stringValue];
            
            // -- for sdk
            NSMutableDictionary *sdk = [NSMutableDictionary dictionary];
            
            sdk[@"sdk"] = _automaticProperties[BT_EVENT_COMMON_PROPERTY_LIB];
            sdk[@"sdk_version"] = _automaticProperties[BT_EVENT_COMMON_PROPERTY_LIB_VERSION];
            
            id app_version = _automaticProperties[BT_EVENT_COMMON_PROPERTY_APP_VERSION];
            if (app_version) {
                sdk[@"app_version"] = app_version;
            }
            dataDict[@"sdk"] = sdk;
            
            // --
            
            BTLog(@"\n贝塔准备上传的原始数据: \n%@", dataDict);
            
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dataDict options:kNilOptions error:nil];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            // 2. 使用gzip进行压缩
            zippedData = [[jsonString dataUsingEncoding:NSUTF8StringEncoding] gzippedData];
            // 3. base64
            b64String = [zippedData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
            
            NSString *appID = self.configOptions.appID;
            NSString *appSecret = self.configOptions.appSecret;
            NSNumber *timestamp = [NSNumber numberWithLongLong:[[self class] getCurrentTime]];
            NSString *combinedString = [NSString stringWithFormat:@"%@%@%@", appID, b64String, timestamp.stringValue];
            NSString *sign = [combinedString bt_hmacSHA256StringWithKey:appSecret];
            BTLog(@"Sign: %@", sign);
            
            postBody = [NSString stringWithFormat:@"app_id=%@&data=%@&timestamp=%@&sign=%@", appID, [b64String bt_urlEncode], timestamp, sign];
            
            BTLog(@"\n贝塔数据即将上传：\n上传服务器地址：%@\n上传参数：\n%@\n", self.serverURL,postBody);
            
        } @catch (NSException *exception) {
            BTLog(@"%@ flushByPost format data error: %@", self, exception);
            return YES;
        }
        
        NSURL *url = [NSURL URLWithString:self.serverURL];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.timeoutInterval = 30;
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];
        // 普通事件请求，使用标准 UserAgent
        [request setValue:@"BetaData iOS SDK" forHTTPHeaderField:@"User-Agent"];
        if (self->_debugMode == BetaDataDebugOnly) {
            [request setValue:@"true" forHTTPHeaderField:@"Dry-Run"];
        }
        
        //Cookie
        [request setValue:[[BetaDataSDK sharedInstance] getCookieWithDecode:NO] forHTTPHeaderField:@"Cookie"];
        
        dispatch_semaphore_t flushSem = dispatch_semaphore_create(0);
        __block BOOL flushSucc = YES;
        
        void (^completionHandler)(NSData*, NSURLResponse*, NSError*) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
                BTLog(@"%@", [NSString stringWithFormat:@"%@ network failure: %@", self, error ? error : @"Unknown error"]);
                flushSucc = NO;
                dispatch_semaphore_signal(flushSem);
                return;
            }
            
            NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse*)response;
            NSString *urlResponseContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            BTLog(@"\n贝塔响应数据: %@\n", urlResponseContent);
            NSString *errMsg = [NSString stringWithFormat:@"%@ flush failure with response '%@'.", self, urlResponseContent];
            NSString *messageDesc = nil;
            NSInteger statusCode = urlResponse.statusCode;
            if (statusCode == 200) {
                messageDesc = @"\n【valid message】\n";
                NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                if ([responseDict isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dataDict = responseDict[@"data"];
                    NSString *prevID = dataDict[@"track_id"];
                    self->_prevTrackID = prevID;
                    
                    // save serve time
                    [self saveServeTime:[responseDict[@"timestamp"] doubleValue]];
                }
            }
            else {
                messageDesc = @"\n【invalid message】\n";
                if (self->_debugMode != BetaDataDebugOff) {
                    if (statusCode >= 300) {
                        [self showDebugModeWarning:errMsg withNoMoreButton:YES];
                    }
                } else {
                    if (statusCode >= 300) {
                        flushSucc = NO;
                    }
                }
            }
            BTLog(@"==========================================================================");
            if ([BTLogger isLoggerEnabled]) {
                @try {
                    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
                    NSString *logString=[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
                    BTLog(@"%@ %@: %@", self,messageDesc,logString);
                } @catch (NSException *exception) {
                    BTLog(@"%@: %@", self, exception);
                }
            }
            if (statusCode != 200) {
                BTLog(@"%@ ret_code: %ld", self, statusCode);
                BTLog(@"%@ ret_content: %@", self, urlResponseContent);
            }
            
            dispatch_semaphore_signal(flushSem);
        };
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:completionHandler];
        [task resume];
        
        dispatch_semaphore_wait(flushSem, DISPATCH_TIME_FOREVER);
        
        return flushSucc;
    };
    
    [self flushByType:@"Post" withSize:(_debugMode == BetaDataDebugOff ? 50 : 1) andFlushMethod:flushByPost];
    
    if (vacuumAfterFlushing) {
        if (![self.messageQueue vacuum]) {
            BTLog(@"failed to VACUUM SQLite.");
        }
    }
    
    BTLog(@"events flushed.");
}

- (void)saveServeTime:(NSTimeInterval)serverTime {
    if(serverTime < 140000000000) {
        serverTime = serverTime * 1000;
    }
    NSTimeInterval timeDelta = [[NSDate date] timeIntervalSince1970] * 1000 - serverTime;
    [[NSUserDefaults standardUserDefaults] setObject:@(timeDelta) forKey:BT_TIME_DIFF];
}

- (void)flush {
    dispatch_async(self.serialQueue, ^{
        [self _flush:NO];
    });
}

- (void)deleteAll {
    [self.messageQueue deleteAll];
}

-(BOOL)handleSchemeUrl:(NSURL *)url {
    @try {
        if (!url) {
            return NO;
        }
        
        if ([@"heatmap" isEqualToString:url.host]) {//点击图
            NSString *featureCode = nil;
            NSString *postUrl = nil;
            NSString *query = [url query];
            if (query != nil) {
                NSArray *subArray = [query componentsSeparatedByString:@"&"];
                NSMutableDictionary *tempDic = [[NSMutableDictionary alloc] init];
                if (subArray) {
                    for (int j = 0 ; j < subArray.count; j++) {
                        //在通过=拆分键和值
                        NSArray *dicArray = [subArray[j] componentsSeparatedByString:@"="];
                        //给字典加入元素
                        [tempDic setObject:dicArray[1] forKey:dicArray[0]];
                    }
                    featureCode = [tempDic objectForKey:@"feature_code"];
                    postUrl = [tempDic objectForKey:@"url"];
                }
            }
            NSString *networkType = [UIDevice bt_getNetWorkStates];
            BOOL isWifi = NO;
            if ([networkType isEqualToString:@"WIFI"]) {
                isWifi = YES;
            }
        } else if ([@"debugmode" isEqualToString:url.host]) {//动态 debug 配置
            
            NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
            
            // url query 解析
            NSMutableDictionary *paramDic = [NSMutableDictionary dictionary];
            for (NSURLQueryItem *item in urlComponents.queryItems) {
                
                if ([item.name isEqualToString:@"info_id"]) {
                    [paramDic setValue:item.value forKey:item.name];
                }
            }
            
            //如果没传 info_id，视为伪造二维码，不做处理
            if ([paramDic.allKeys containsObject:@"info_id"]) {
                [self showDebugModeAlertWithParams:paramDic];
                return YES;
            } else {
                return NO;
            }
        }
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
    }
    return NO;
}

- (void)enableHeatMap {
    _heatMap = YES;
}

- (BOOL)isHeatMapEnabled {
    return _heatMap;
}

- (void)addHeatMapViewControllers:(NSArray *)controllers {
    @try {
        if (controllers == nil || controllers.count == 0) {
            return;
        }
        [_heatMapViewControllers addObjectsFromArray:controllers];
        
        //去重
        NSSet *set = [NSSet setWithArray:_heatMapViewControllers];
        if (set != nil) {
            _heatMapViewControllers = [NSMutableArray arrayWithArray:[set allObjects]];
        } else{
            _heatMapViewControllers = [[NSMutableArray alloc] init];
        }
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
    }
}

- (BOOL)isHeatMapViewController:(UIViewController *)viewController {
    @try {
        if (viewController == nil) {
            return NO;
        }
        
        if (_heatMapViewControllers == nil || _heatMapViewControllers.count == 0) {
            return YES;
        }
        
        NSString *screenName = NSStringFromClass([viewController class]);
        if ([_heatMapViewControllers containsObject:screenName]) {
            return YES;
        }
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
    }
    return NO;
}

- (BOOL) isValidName : (NSString *) name {
    @try {
        if (_deviceModel == nil) {
            _deviceModel = [self deviceModel];
        }
        
        if (_osVersion == nil) {
            UIDevice *device = [UIDevice currentDevice];
            _osVersion = [device systemVersion];
        }
        
        //据反馈，该函数在 iPhone 8、iPhone 8 Plus，并且系统版本号为 11.0 上可能会 crash，具体原因暂未查明
        if ([_osVersion isEqualToString:@"11.0"]) {
            if ([_deviceModel isEqualToString:@"iPhone10,1"] ||
                [_deviceModel isEqualToString:@"iPhone10,4"] ||
                [_deviceModel isEqualToString:@"iPhone10,2"] ||
                [_deviceModel isEqualToString:@"iPhone10,5"]) {
                return YES;
            }
        }
        return [self.regexTestName evaluateWithObject:name];
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
        return NO;
    }
}

- (NSString *)filePathForData:(NSString *)data {
    NSString *filename = [NSString stringWithFormat:@"betadataanalytics-%@.plist", data];
    NSString *filepath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
                          stringByAppendingPathComponent:filename];
    BTLog(@"filepath for %@ is %@", data, filepath);
    return filepath;
}

- (NSDictionary<NSString *, id> *)willEnqueueWithType:(NSString *)type andEvent:(NSDictionary *)e {
    if (!self.trackEventCallback) {
        return [e copy];
    }
    NSMutableDictionary *event = [e mutableCopy];
    
    NSDictionary<NSString *, id> *originProperties = event[@"properties"];
    // can only modify "$device_id"
    NSArray *modifyKeys = @[@"_device_id"];
    BOOL(^canModifyPropertyKeys)(NSString *key) = ^BOOL(NSString *key) {
        return (![key hasPrefix:@"_"] || [modifyKeys containsObject:key]);
    };
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    // 添加可修改的事件属性
    [originProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (canModifyPropertyKeys(key)) {
            properties[key] = obj;
        }
    }];
    BOOL isIncluded = self.trackEventCallback(event[@"event"], properties);
    if (!isIncluded) {
        BTLog(@"\n【track event】: %@ can not enter database.", event[@"event"]);
        return nil;
    }
    // 校验 properties
    if (![self assertPropertyTypes:&properties withEventType:type]) {
        BTLog(@"%@ failed to track event.", self);
        return nil;
    }
    // assert 可能修改 properties 的类型
    properties = [properties mutableCopy];
    // 添加不可修改的事件属性，得到修改之后的所有属性
    [originProperties enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (!canModifyPropertyKeys(key)) {
            properties[key] = obj;
        }
    }];
    // 对 properties 重新赋值
    event[BT_EVENT_PROPERTIES] = properties;
    
    return event;
}

- (void)enqueueWithType:(NSString *)type andEvent:(NSDictionary *)e {
    [self.messageQueue addObejct:e withType:@"Post"];
}

- (BOOL)guardIfLegalLWithEventName:(NSString *)eventName properties:(NSDictionary *)propertieDict eventType:(NSString *)type {
    if (eventName == nil || [eventName length] == 0) {
        NSString *errMsg = @"SensorsAnalytics track called with empty event parameter";
        BTLog(@"%@", errMsg);
        if (_debugMode != BetaDataDebugOff) {
            [self showDebugModeWarning:errMsg withNoMoreButton:YES];
        }
        return false;
    }
    if (![self isValidName:eventName]) {
        NSString *errMsg = [NSString stringWithFormat:@"Event name[%@] not valid", eventName];
        BTLog(@"%@", errMsg);
        if (_debugMode != BetaDataDebugOff) {
            [self showDebugModeWarning:errMsg withNoMoreButton:YES];
        }
        return false;
    }
    
    if (propertieDict && ![self assertPropertyTypes:&propertieDict withEventType:type]) {
        BTLog(@"%@ failed to track event.", self);
        return false;
    }
    return true;
}

- (CGFloat)calcEventDurationWithTimerInfo:(NSDictionary *)eventTimer {
    NSNumber *currentSystemUpTime = @([[self class] getSystemUpTime]);
    
    NSNumber *eventBegin = [eventTimer valueForKey:@"eventBegin"];
    NSNumber *eventAccumulatedDuration = [eventTimer objectForKey:@"eventAccumulatedDuration"];
    BetaDataTimeUnit timeUnit = [[eventTimer valueForKey:@"timeUnit"] intValue];
    
    CGFloat eventDuration;
    if (eventAccumulatedDuration) {
        eventDuration = [currentSystemUpTime longValue] - [eventBegin longValue] + [eventAccumulatedDuration longValue];
    } else {
        eventDuration = [currentSystemUpTime longValue] - [eventBegin longValue];
    }
    
    if (eventDuration < 0) {
        eventDuration = 0;
    }
    
    if (eventDuration > 0 && eventDuration < 24 * 60 * 60 * 1000) {
        switch (timeUnit) {
        case BetaDataTimeUnitHours:
            eventDuration = eventDuration / 60.0;
        case BetaDataTimeUnitMinutes:
            eventDuration = eventDuration / 60.0;
        case BetaDataTimeUnitSeconds:
            eventDuration = eventDuration / 1000.0;
        case BetaDataTimeUnitMilliseconds:
            break;
        }
    }
    
    return eventDuration;
}

- (void)track:(NSString *)eventName withProperties:(NSDictionary *)propertieDict withType:(NSString *)type {
    propertieDict = [propertieDict copy];
    
    if (![self guardIfLegalLWithEventName:eventName properties:propertieDict eventType:type]) {
        return;
    }
    
    NSMutableDictionary *userProperties = [NSMutableDictionary dictionary];
    BOOL isLogin = [eventName isEqualToString:BT_EVENT_NAME_APP_REGISTER] ||
                   [eventName isEqualToString:BT_EVENT_NAME_APP_LOGIN];
    // 如果是BT_PROFILE_SET、BT_EVENT_NAME_APP_REGISTER、BT_EVENT_NAME_APP_LOGIN，则需要填充BT_USER_PROPERTIES
    if ([eventName isEqualToString:BT_PROFILE_SET] || isLogin) {
        [userProperties addEntriesFromDictionary:propertieDict];
        userProperties[BT_EVENT_COMMON_PROPERTY_USER_ID] = [self getBestId];
        if (isLogin) {
            userProperties[BT_EVENT_COMMON_PROPERTY_LAST_TIME] = @([[self class] getCurrentTime]);
        }
    }
    
    __block NSDictionary *dynamicSuperPropertiesDict = self.dynamicSuperProperties?self.dynamicSuperProperties():nil;
    dispatch_async(self.serialQueue, ^{
        //获取用户自定义的动态公共属性
        if (![dynamicSuperPropertiesDict isKindOfClass:NSDictionary.class]) {
            BTLog(@"dynamicSuperProperties  returned: %@  is not an NSDictionary Obj.",dynamicSuperPropertiesDict);
            dynamicSuperPropertiesDict = nil;
        }
        else if (![self assertPropertyTypes:&dynamicSuperPropertiesDict withEventType:@"register_super_properties"]) {
            dynamicSuperPropertiesDict = nil;
        }
        //去重
        [self unregisterSameLetterSuperProperties:dynamicSuperPropertiesDict];
        
        NSNumber *timeStamp = @([[self class] getCurrentTime]);
        
        NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
        NSString *bestId = self.getBestId;
        if (bestId.length) {
            eventProperties[BT_EVENT_COMMON_PROPERTY_USER_ID] = bestId;
        }
        // 判断这个事件是不是首次事件，所谓首次事件，有两种场景，第一次安装和退出登录后的第一个事件。这里用valueForKey，有值则表示着首次事件已经传过去了
        eventProperties[BT_EVENT_COMMON_PROPERTY_IS_FIRST] = @NO;
        if (![[NSUserDefaults standardUserDefaults] valueForKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST]) {
            eventProperties[BT_EVENT_COMMON_PROPERTY_IS_FIRST] = @YES;
            [[NSUserDefaults standardUserDefaults] setValue:@YES forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST];
        }
        
        // track / track_signup 类型的请求，还是要加上各种公共property
        // 这里注意下顺序，按照优先级从低到高，依次是automaticProperties, superProperties,dynamicSuperPropertiesDict,propertieDict
        [eventProperties addEntriesFromDictionary:self->_automaticProperties];
        [eventProperties addEntriesFromDictionary:self->_superProperties];
        [eventProperties addEntriesFromDictionary:dynamicSuperPropertiesDict];
        
        // 每次 track 时手机网络状态
        NSString *networkType = [UIDevice bt_getNetWorkStates];
        eventProperties[BT_EVENT_COMMON_PROPERTY_NETWORK_TYPE] = networkType;
        //properties[BT_EVENT_COMMON_PROPERTY_IP] = [UIDevice getIPAddress:true];
        
        if ([networkType isEqualToString:@"WIFI"]) {
            [eventProperties setObject:@YES forKey:BT_EVENT_COMMON_PROPERTY_WIFI];
        } else {
            [eventProperties setObject:@NO forKey:BT_EVENT_COMMON_PROPERTY_WIFI];
        }
        
        NSDictionary *eventTimer = self.trackTimer[eventName];
        if (eventTimer) {
            [self.trackTimer removeObjectForKey:eventName];
            CGFloat eventDuration = [self calcEventDurationWithTimerInfo:eventTimer];
            @try {
                [eventProperties setObject:@([[NSString stringWithFormat:@"%.3f", eventDuration] floatValue]) forKey:@"_event_duration"];
            } @catch (NSException *exception) {
                BTLog(@"%@: %@", self, exception);
            }
        }
        
        if (propertieDict) {
            NSArray *keys = propertieDict.allKeys;
            for (id key in keys) {
                NSObject *obj = propertieDict[key];
                if ([obj isKindOfClass:[NSDate class]]) {
                    // 序列化所有 NSDate 类型
                    NSString *dateStr = [self->_dateFormatter stringFromDate:(NSDate *)obj];
                    [eventProperties setObject:dateStr forKey:key];
                } else {
                    [eventProperties setObject:obj forKey:key];
                }
            }
        }
        
        //  是否首日访问
        if ([self isFirstDay]) {
            [eventProperties setObject:@YES forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY];
        } else {
            [eventProperties setObject:@NO forKey:BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY];
        }
        
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
        @try {
            //采集设备方向
            if (self.deviceOrientationConfig.enableTrackScreenOrientation && self.deviceOrientationConfig.deviceOrientation.length) {
                //[properties setObject:self.deviceOrientationConfig.deviceOrientation forKey:BT_EVENT_COMMON_OPTIONAL_PROPERTY_SCREEN_ORIENTATION];
            }
        } @catch (NSException *e) {
            BTLog(@"%@: %@", self, e);
        }
#endif
        
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_GPS
        @try {
            //采集地理位置信息
            if (self.locationConfig.enableGPSLocation) {
                if (CLLocationCoordinate2DIsValid(self.locationConfig.coordinate)) {
                    double latitude = self.locationConfig.coordinate.latitude;
                    double longitude = self.locationConfig.coordinate.longitude;
                    eventProperties[BT_EVENT_COMMON_OPTIONAL_PROPERTY_LBS] = @{ @"lat": [NSNumber numberWithDouble:latitude],
                                                                                @"lon": [NSNumber numberWithDouble:longitude],
                    };
                }
            }
        } @catch (NSException *e) {
            BTLog(@"%@: %@", self, e);
        }
#endif
        NSMutableDictionary *rawEventDict = [@{ BT_EVENT_NAME: eventName,
                                                BT_EVENT_PROPERTIES: eventProperties.copy,
                                                BT_EVENT_TIME: timeStamp,
        } mutableCopy];
        if ([[userProperties allKeys] count]) {
            rawEventDict[BT_USER_PROPERTIES] = userProperties.copy;
        }
        
        //修正 $device_id，防止用户修改
        NSDictionary *infoProperties = [rawEventDict objectForKey:BT_EVENT_PROPERTIES];
        if (infoProperties && [infoProperties.allKeys containsObject:BT_EVENT_COMMON_PROPERTY_DEVICE_ID]) {
            NSDictionary *autoProperties = self.automaticProperties;
            if (autoProperties && [autoProperties.allKeys containsObject:BT_EVENT_COMMON_PROPERTY_DEVICE_ID]) {
                NSMutableDictionary *correctInfoProperties = [NSMutableDictionary dictionaryWithDictionary:infoProperties];
                correctInfoProperties[BT_EVENT_COMMON_PROPERTY_DEVICE_ID] = autoProperties[BT_EVENT_COMMON_PROPERTY_DEVICE_ID];
                [rawEventDict setObject:correctInfoProperties forKey:BT_EVENT_PROPERTIES];
            }
        }
        
        NSDictionary *eventDic = [self willEnqueueWithType:type andEvent:rawEventDict];
        if (!eventDic || ![eventDic[BT_EVENT_NAME] length]) {
            return;
        }
        BTLog(@"\n【track event】:\n%@", eventDic);
        
        [self enqueueWithType:type andEvent:eventDic];
        
        if (self->_debugMode != BetaDataDebugOff) {
            // 在DEBUG模式下，直接发送事件
            [self flush];
        } else {
            // 否则，在满足发送条件时，发送事件
            if ([type isEqualToString:@"track_signup"] || [[self messageQueue] count] >= self.flushBulkSize) {
                [self flush];
            }
        }
    });
}

-(NSString *)getBestId{
    NSString *bestId = [self loginId];
    
    return bestId ?: @"";
    
    /**
     if ([self loginId] != nil) {
     bestId = [self loginId];
     }
     else{
     bestId = [self distinctId];
     }
     
     if (bestId == nil) {
     [self resetAnonymousId];
     bestId = [self anonymousId];
     }
     */
    
    
    return bestId;
}

- (void)track:(NSString *)event {
    [self track:event withProperties:nil withTrackType:BetaDataTrackTypeCode];;
}

- (void)track:(NSString *)event withProperties:(NSDictionary *)propertieDict {
    [self track:event withProperties:propertieDict withTrackType:BetaDataTrackTypeCode];
}

- (void)track:(NSString *)event withTrackType:(BetaDataTrackType)trackType {
    [self track:event withProperties:nil withTrackType:trackType];
}

- (void)track:(NSString *)event withProperties:(NSDictionary *)propertieDict withTrackType:(BetaDataTrackType)trackType {
    if (trackType == BetaDataTrackTypeCode) {
        //事件校验，预置事件提醒
        if ([self.regexEventName evaluateWithObject:event]) {
            BTLog(@"\n【event warning】\n %@ is a preset event name of us, it is recommended that you use a new one",event);
        };
        
        [self track:event withProperties:propertieDict withType:@"codeTrack"];
    } else {
        [self track:event withProperties:propertieDict withType:@"track"];
    }
}

- (void)setCookie:(NSString *)cookie withEncode:(BOOL)encode {
    if (encode) {
        _cookie = (id)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                (CFStringRef)cookie,
                                                                                NULL,
                                                                                CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                                kCFStringEncodingUTF8));
    } else {
        _cookie = cookie;
    }
}

- (NSString *)getCookieWithDecode:(BOOL)decode {
    if (decode) {
        return (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,(__bridge CFStringRef)_cookie, CFSTR(""),CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    } else {
        return _cookie;
    }
}

- (void)trackTimer:(NSString *)event {
    [self trackTimer:event withTimeUnit:BetaDataTimeUnitMilliseconds];
}

- (void)trackTimerStart:(NSString *)event {
    [self trackTimer:event withTimeUnit:BetaDataTimeUnitMilliseconds];
}

- (void)trackTimer:(NSString *)event withTimeUnit:(BetaDataTimeUnit)timeUnit {
    if (![self isValidName:event]) {
        NSString *errMsg = [NSString stringWithFormat:@"Event name[%@] not valid", event];
        BTLog(@"%@", errMsg);
        if (_debugMode != BetaDataDebugOff) {
            [self showDebugModeWarning:errMsg withNoMoreButton:YES];
        }
        return;
    }
    
    NSNumber *eventBegin = @([[self class] getSystemUpTime]);
    dispatch_async(self.serialQueue, ^{
        self.trackTimer[event] = @{@"eventBegin" : eventBegin, @"eventAccumulatedDuration" : [NSNumber numberWithLong:0], @"timeUnit" : [NSNumber numberWithInt:timeUnit]};
    });
}

- (void)trackTimerEnd:(NSString *)event {
    [self track:event withTrackType:BetaDataTrackTypeAuto];
}

- (void)trackTimerEnd:(NSString *)event withProperties:(NSDictionary *)propertyDict {
    [self track:event withProperties:propertyDict withTrackType:BetaDataTrackTypeAuto];
}

- (void)clearTrackTimer {
    dispatch_async(self.serialQueue, ^{
        self.trackTimer = [NSMutableDictionary dictionary];
    });
}

- (void)trackInstallation {
    [self trackInstallationWithProperties:nil];
}

- (void)trackInstallationWithProperties:(NSDictionary *)propertyDict {
    [self trackInstallationWithProperties:propertyDict disableCallback:NO];
}

- (void)trackInstallationWithProperties:(NSDictionary *)propertyDict disableCallback:(BOOL)disableCallback {
    BOOL hasTrackInstallation = NO;
    NSString *userDefaultsKey = nil;
    userDefaultsKey = disableCallback?BT_HAS_TRACK_INSTALLATION_DISABLE_CALLBACK:BT_HAS_TRACK_INSTALLATION;
    
    //#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
    //#ifndef SENSORS_ANALYTICS_DISABLE_INSTALLATION_MARK_IN_KEYCHAIN
    //    hasTrackInstallation = disableCallback?[BTKeyChainItemWrapper hasTrackInstallationWithDisableCallback]:[BTKeyChainItemWrapper hasTrackInstallation];
    //    if (hasTrackInstallation) {
    //        return;
    //    }
    //#endif
    //#endif
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:userDefaultsKey]) {
        hasTrackInstallation = NO;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:userDefaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        hasTrackInstallation = YES;
    }
    //#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
    //#ifndef SENSORS_ANALYTICS_DISABLE_INSTALLATION_MARK_IN_KEYCHAIN
    //    if (disableCallback) {
    //        [BTKeyChainItemWrapper markHasTrackInstallationWithDisableCallback];
    //    }else{
    //        [BTKeyChainItemWrapper markHasTrackInstallation];
    //    }
    //#endif
    //#endif
    if (!hasTrackInstallation) {
        // 追踪渠道是特殊功能，需要同时发送 track 和 profile_set_once
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        NSString *idfa = [self getIDFA];
        //        if (idfa != nil) {
        //            [properties setValue:[NSString stringWithFormat:@"idfa=%@", idfa] forKey:BT_EVENT_PROPERTY_APP_INSTALL_SOURCE];
        //        } else {
        //            [properties setValue:@"" forKey:BT_EVENT_PROPERTY_APP_INSTALL_SOURCE];
        //        }
        
        if (disableCallback) {
            [properties setValue:@YES forKey:BT_EVENT_PROPERTY_APP_INSTALL_DISABLE_CALLBACK];
        }
        
        //        NSString *userAgent = [propertyDict objectForKey:BT_EVENT_PROPERTY_APP_INSTALL_USER_AGENT];
        //        if (userAgent ==nil || userAgent.length == 0) {
        //            userAgent = self.class.getUserAgent;
        //        }
        //        if (userAgent) {
        //            [properties setValue:userAgent forKey:BT_EVENT_PROPERTY_APP_INSTALL_USER_AGENT];
        //        }
        
        if (propertyDict != nil) {
            [properties addEntriesFromDictionary:propertyDict];
        }
        
        // 先发送 track
        [self track:BT_EVENT_NAME_INSTALL withProperties:properties withType:@"track"];
        
        // 再发送 profile_set_once
        NSMutableDictionary *profileProperties = [properties mutableCopy];
        //[profileProperties setValue:[NSDate date] forKey:BT_EVENT_PROPERTY_APP_INSTALL_FIRST_VISIT_TIME];
        [self track:nil withProperties:profileProperties withType:BT_PROFILE_SET_ONCE];
        
        [self flush];
    }
}

- (NSString  *)getIDFA {
    NSString *idfa = nil;
    @try {
        Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
        if (ASIdentifierManagerClass) {
            SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
            id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
            SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
            NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
            NSString *temp = [uuid UUIDString];
            // 在 iOS 10.0 以后，当用户开启限制广告跟踪，advertisingIdentifier 的值将是全零
            // 00000000-0000-0000-0000-000000000000
            if (temp && ![temp hasPrefix:@"00000000"]) {
                idfa = temp;
            }
        }
        //#endif
        return idfa;
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
        return idfa;
    }
}

- (void)ignoreAutoTrackViewControllers:(NSArray *)controllers {
    if (controllers == nil || controllers.count == 0) {
        return;
    }
    [_ignoredViewControllers addObjectsFromArray:controllers];
    
    //去重
    NSSet *set = [NSSet setWithArray:_ignoredViewControllers];
    if (set != nil) {
        _ignoredViewControllers = [NSMutableArray arrayWithArray:[set allObjects]];
    } else{
        _ignoredViewControllers = [[NSMutableArray alloc] init];
    }
}

- (void)identify:(NSString *)distinctId {
    if (distinctId.length == 0) {
        BTLog(@"%@ cannot identify blank distinct id: %@", self, distinctId);
        //        @throw [NSException exceptionWithName:@"InvalidDataException" reason:@"SensorsAnalytics distinct_id should not be nil or empty" userInfo:nil];
        return;
    }
    if (distinctId.length > 255) {
        BTLog(@"%@ max length of distinct_id is 255, distinct_id: %@", self, distinctId);
        //        @throw [NSException exceptionWithName:@"InvalidDataException" reason:@"SensorsAnalytics max length of distinct_id is 255" userInfo:nil];
    }
    dispatch_async(self.serialQueue, ^{
        // 先把之前的distinctId设为originalId
        self.originalId = self.distinctId;
        // 更新distinctId
        self.distinctId = distinctId;
        [self archiveDistinctId];
    });
}

- (NSString *)deviceModel {
    return [UIDevice currentDevice].bt_machineModelName;
}

- (NSString *)libVersion {
    return VERSION;
}

- (BOOL)assertPropertyTypes:(NSDictionary **)propertiesAddress withEventType:(NSString *)eventType {
    NSDictionary *properties = *propertiesAddress;
    NSMutableDictionary *newProperties = nil;
    NSMutableArray *mutKeyArrayForValueIsNSNull = nil;
    for (id __unused k in properties) {
        // key 必须是NSString
        if (![k isKindOfClass: [NSString class]]) {
            NSString *errMsg = @"Property Key should by NSString";
            BTLog(@"%@", errMsg);
            if (_debugMode != BetaDataDebugOff) {
                [self showDebugModeWarning:errMsg withNoMoreButton:YES];
            }
            return NO;
        }
        
        // key的名称必须符合要求
        if (![self isValidName: k]) {
            NSString *errMsg = [NSString stringWithFormat:@"property name[%@] is not valid", k];
            BTLog(@"%@", errMsg);
            if (_debugMode != BetaDataDebugOff) {
                [self showDebugModeWarning:errMsg withNoMoreButton:YES];
            }
            return NO;
        }
        
        // value的类型检查
        id propertyValue = properties[k];
        if(![propertyValue isKindOfClass:[NSString class]] &&
           ![propertyValue isKindOfClass:[NSNumber class]] &&
           ![propertyValue isKindOfClass:[NSSet class]] &&
           ![propertyValue isKindOfClass:[NSArray class]] &&
           ![propertyValue isKindOfClass:[NSDate class]]) {
            NSString * errMsg = [NSString stringWithFormat:@"%@ property values must be NSString, NSNumber, NSSet, NSArray or NSDate. got: %@ %@", self, [propertyValue class], propertyValue];
            BTLog(@"%@", errMsg);
            if (_debugMode != BetaDataDebugOff) {
                [self showDebugModeWarning:errMsg withNoMoreButton:YES];
            }
            
            if ([propertyValue isKindOfClass:[NSNull class]]) {
                //NSNull 需要对数据做修复，remove 对应的 key
                if (!mutKeyArrayForValueIsNSNull) {
                    mutKeyArrayForValueIsNSNull = [NSMutableArray arrayWithObject:k];
                }else {
                    [mutKeyArrayForValueIsNSNull addObject:k];
                }
            }else {
                return NO;
            }
        }
        
        // NSSet、NSArray 类型的属性中，每个元素必须是 NSString 类型
        if ([propertyValue isKindOfClass:[NSSet class]] || [propertyValue isKindOfClass:[NSArray class]]) {
            NSEnumerator *enumerator = [propertyValue objectEnumerator];
            id object;
            while (object = [enumerator nextObject]) {
                if (![object isKindOfClass:[NSString class]]) {
                    NSString * errMsg = [NSString stringWithFormat:@"%@ value of NSSet、NSArray must be NSString. got: %@ %@", self, [object class], object];
                    BTLog(@"%@", errMsg);
                    if (_debugMode != BetaDataDebugOff) {
                        [self showDebugModeWarning:errMsg withNoMoreButton:YES];
                    }
                    return NO;
                }
                NSUInteger objLength = [((NSString *)object) lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
                if (objLength > SA_PROPERTY_LENGTH_LIMITATION) {
                    //截取再拼接 $ 末尾，替换原数据
                    NSMutableString *newObject = [NSMutableString stringWithString:[BTCommonUtility subByteString:(NSString *)object byteLength:SA_PROPERTY_LENGTH_LIMITATION - 1]];
                    [newObject appendString:@"$"];
                    if (!newProperties) {
                        newProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
                    }
                    
                    NSMutableSet *newSetObject = nil;
                    if ([propertyValue isKindOfClass:[NSArray class]]) {
                        newSetObject = [NSMutableSet setWithArray:propertyValue];
                    } else {
                        newSetObject = [NSMutableSet setWithSet:propertyValue];
                    }
                    [newSetObject removeObject:object];
                    [newSetObject addObject:newObject];
                    [newProperties setObject:newSetObject forKey:k];
                }
            }
        }
        
        // NSString 检查长度，但忽略部分属性
        if ([propertyValue isKindOfClass:[NSString class]]) {
            NSUInteger objLength = [((NSString *)propertyValue) lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
            NSUInteger valueMaxLength = SA_PROPERTY_LENGTH_LIMITATION;
            if ([k isEqualToString:@"_crash_reason"]) {
                valueMaxLength = SA_PROPERTY_LENGTH_LIMITATION * 2;
            }
            if (objLength > valueMaxLength) {
                //截取再拼接 $ 末尾，替换原数据
                NSMutableString *newObject = [NSMutableString stringWithString:[BTCommonUtility subByteString:propertyValue byteLength:valueMaxLength - 1]];
                [newObject appendString:@"$"];
                if (!newProperties) {
                    newProperties = [NSMutableDictionary dictionaryWithDictionary:properties];
                }
                [newProperties setObject:newObject forKey:k];
            }
        }
        
        // profileIncrement的属性必须是NSNumber
        if ([eventType isEqualToString:BT_PROFILE_INCREMENT]) {
            if (![propertyValue isKindOfClass:[NSNumber class]]) {
                NSString *errMsg = [NSString stringWithFormat:@"%@ profile_increment value must be NSNumber. got: %@ %@", self, [properties[k] class], propertyValue];
                BTLog(@"%@", errMsg);
                if (_debugMode != BetaDataDebugOff) {
                    [self showDebugModeWarning:errMsg withNoMoreButton:YES];
                }
                return NO;
            }
        }
        
        // profileAppend的属性必须是个NSSet、NSArray
        if ([eventType isEqualToString:BT_PROFILE_APPEND]) {
            if (![propertyValue isKindOfClass:[NSSet class]] && ![propertyValue isKindOfClass:[NSArray class]]) {
                NSString *errMsg = [NSString stringWithFormat:@"%@ profile_append value must be NSSet、NSArray. got %@ %@", self, [propertyValue  class], propertyValue];
                BTLog(@"%@", errMsg);
                if (_debugMode != BetaDataDebugOff) {
                    [self showDebugModeWarning:errMsg withNoMoreButton:YES];
                }
                return NO;
            }
        }
    }
    //截取之后，修改原 properties
    if (newProperties) {
        *propertiesAddress = [NSDictionary dictionaryWithDictionary:newProperties];
    }
    
    if (mutKeyArrayForValueIsNSNull) {
        NSMutableDictionary *mutDict = [NSMutableDictionary dictionaryWithDictionary:*propertiesAddress];
        [mutDict removeObjectsForKeys:mutKeyArrayForValueIsNSNull];
        *propertiesAddress = [NSDictionary dictionaryWithDictionary:mutDict];
    }
    return YES;
}

- (NSDictionary *)collectAutomaticProperties {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    _deviceModel = [self deviceModel];
    _osVersion = [device systemVersion];
    struct CGSize size = [UIScreen mainScreen].bounds.size;
    CTTelephonyNetworkInfo *telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = nil;
    
    if (@available(iOS 12.0, *)) {
        carrier = telephonyInfo.serviceSubscriberCellularProviders.allValues.lastObject;
    } else {
        carrier = telephonyInfo.subscriberCellularProvider;
    }
    
    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:BT_EVENT_COMMON_PROPERTY_APP_VERSION];
    if (carrier != nil) {
        NSString *networkCode = [carrier mobileNetworkCode];
        NSString *countryCode = [carrier mobileCountryCode];
        
        NSString *carrierName = nil;
        //中国运营商
        if (countryCode && [countryCode isEqualToString:CARRIER_CHINA_MCC]) {
            if (networkCode) {
                
                //中国移动
                if ([networkCode isEqualToString:@"00"] || [networkCode isEqualToString:@"02"] || [networkCode isEqualToString:@"07"] || [networkCode isEqualToString:@"08"]) {
                    carrierName= @"中国移动";
                }
                //中国联通
                if ([networkCode isEqualToString:@"01"] || [networkCode isEqualToString:@"06"] || [networkCode isEqualToString:@"09"]) {
                    carrierName= @"中国联通";
                }
                //中国电信
                if ([networkCode isEqualToString:@"03"] || [networkCode isEqualToString:@"05"] || [networkCode isEqualToString:@"11"]) {
                    carrierName= @"中国电信";
                }
                //中国卫通
                if ([networkCode isEqualToString:@"04"]) {
                    carrierName= @"中国卫通";
                }
                //中国铁通
                if ([networkCode isEqualToString:@"20"]) {
                    carrierName= @"中国铁通";
                }
            }
        } else { //国外运营商解析
            //加载当前 bundle
            NSBundle *sensorsBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[BetaDataSDK class]] pathForResource:@"BetaDataSDK" ofType:@"bundle"]];
            //文件路径
            NSString *jsonPath = [sensorsBundle pathForResource:@"bt_mcc_mnc_mini.json" ofType:nil];
            NSData *jsonData = [NSData dataWithContentsOfFile:jsonPath];
            if (jsonData) {
                NSDictionary *dicAllMcc =  [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
                if (dicAllMcc) {
                    NSString *mccMncKey = [NSString stringWithFormat:@"%@%@",countryCode,networkCode];
                    carrierName = dicAllMcc[mccMncKey];
                }
            }
        }
        
        if (carrierName != nil) {
            [p setValue:carrierName forKey:BT_EVENT_COMMON_PROPERTY_CARRIER];
        } else {
            if (carrier.carrierName) {
                [p setValue:carrier.carrierName forKey:BT_EVENT_COMMON_PROPERTY_CARRIER];
            }
        }
    }
    
#if !SENSORS_ANALYTICS_DISABLE_AUTOTRACK_DEVICEID
    [p setValue:[[self class] getUniqueHardwareId] forKey:BT_EVENT_COMMON_PROPERTY_DEVICE_ID];
#endif
    [p addEntriesFromDictionary:@{
        BT_EVENT_COMMON_PROPERTY_LIB: @"iOS",
        BT_EVENT_COMMON_PROPERTY_LIB_VERSION: [self libVersion],
        BT_EVENT_COMMON_PROPERTY_MANUFACTURER: @"Apple",
        BT_EVENT_COMMON_PROPERTY_OS: @"iOS",
        BT_EVENT_COMMON_PROPERTY_OS_VERSION: _osVersion,
        BT_EVENT_COMMON_PROPERTY_MODEL: _deviceModel,
        BT_EVENT_COMMON_PROPERTY_SCREEN_HEIGHT: @((NSInteger)size.height),
        BT_EVENT_COMMON_PROPERTY_SCREEN_WIDTH: @((NSInteger)size.width),
    }];
    return [p copy];
}

- (void)registerSuperProperties:(NSDictionary *)propertyDict {
    propertyDict = [propertyDict copy];
    if (![self assertPropertyTypes:&propertyDict withEventType:@"register_super_properties"]) {
        BTLog(@"%@ failed to register super properties.", self);
        return;
    }
    dispatch_async(self.serialQueue, ^{
        [self unregisterSameLetterSuperProperties:propertyDict];
        // 注意这里的顺序，发生冲突时是以propertyDict为准，所以它是后加入的
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self->_superProperties];
        [tmp addEntriesFromDictionary:propertyDict];
        self->_superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveSuperProperties];
    });
}

- (void)registerDynamicSuperProperties:(NSDictionary<NSString *,id> *(^)(void)) dynamicSuperProperties {
    dispatch_async(self.serialQueue, ^{
        self.dynamicSuperProperties = dynamicSuperProperties;
    });
}

- (void)trackEventCallback:(BOOL (^)(NSString *eventName, NSMutableDictionary<NSString *, id> *properties))callback {
    if (!callback) {
        return;
    }
    BTLog(@"SDK have set trackEvent callBack");
    dispatch_async(self.serialQueue, ^{
        self.trackEventCallback = callback;
    });
}

///注销仅大小写不同的 SuperProperties
- (void)unregisterSameLetterSuperProperties:(NSDictionary *)propertyDict {
    dispatch_block_t block =^{
        NSArray *allNewKeys = [propertyDict.allKeys copy];
        //如果包含仅大小写不同的 key ,unregisterSuperProperty
        NSArray *superPropertyAllKeys = [self.superProperties.allKeys copy];
        NSMutableArray *unregisterPropertyKeys = [NSMutableArray array];
        for (NSString *newKey in allNewKeys) {
            [superPropertyAllKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *usedKey = (NSString *)obj;
                if ([usedKey caseInsensitiveCompare:newKey] == NSOrderedSame) { // 存在不区分大小写相同 key
                    [unregisterPropertyKeys addObject:usedKey];
                }
            }];
        }
        if (unregisterPropertyKeys.count > 0) {
            [self unregisterSuperPropertys:unregisterPropertyKeys];
        }
    };
    
    if (dispatch_get_specific(BetaDataAnalyticsQueueTag)) {
        block();
    } else {
        dispatch_async(self.serialQueue, block);
    }
}

- (void)unregisterSuperProperty:(NSString *)property {
    dispatch_async(self.serialQueue, ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self->_superProperties];
        if (tmp[property] != nil) {
            [tmp removeObjectForKey:property];
        }
        self->_superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveSuperProperties];
    });
}

- (void)unregisterSuperPropertys:(NSArray <NSString *>*)propertys {
    dispatch_block_t block =  ^{
        NSMutableDictionary *tmp = [NSMutableDictionary dictionaryWithDictionary:self->_superProperties];
        [tmp removeObjectsForKeys:propertys];
        self->_superProperties = [NSDictionary dictionaryWithDictionary:tmp];
        [self archiveSuperProperties];
    };
    if (dispatch_get_specific(BetaDataAnalyticsQueueTag)) {
        block();
    }else {
        dispatch_async(self.serialQueue, block);
    }
}

- (void)clearSuperProperties {
    dispatch_async(self.serialQueue, ^{
        self->_superProperties = @{};
        [self archiveSuperProperties];
    });
}

- (NSDictionary *)currentSuperProperties {
    return [_superProperties copy];
}

#pragma mark - Local caches

- (void)unarchive {
    [self unarchiveDistinctId];
    [self unarchiveLoginId];
    [self unarchiveSuperProperties];
    [self unarchiveFirstDay];
}

- (void)checkAppKey {
    NSString *userDefaultKey = @"BetaDataSDK_VersionRecord";
    NSString *appKey = sharedInstance_.configOptions.appID;
    NSString *lastAppKey = [[NSUserDefaults standardUserDefaults] objectForKey:userDefaultKey];
    BOOL isNewAppKey = ![appKey isEqualToString:lastAppKey];
    if (isNewAppKey) {
        // 清除本地数据
        [self deleteAll];
        [[NSUserDefaults standardUserDefaults]  setObject:appKey forKey:userDefaultKey];
    }
}

- (id)unarchiveFromFile:(NSString *)filePath {
    id unarchivedData = nil;
    @try {
        unarchivedData = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    } @catch (NSException *exception) {
        BTLog(@"%@ unable to unarchive data in %@, starting fresh", self, filePath);
        unarchivedData = nil;
    }
    return unarchivedData;
}

- (void)unarchiveDistinctId {
    NSString *filePath = [self filePathForData:BT_EVENT_DISTINCT_ID];
    NSString *archivedDistinctId = (NSString *)[self unarchiveFromFile:filePath];
    
#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
    NSString *distinctIdInKeychain = [BTKeyChainItemWrapper saUdid];
    if (distinctIdInKeychain != nil && distinctIdInKeychain.length > 0) {
        self.distinctId = distinctIdInKeychain;
        if (![archivedDistinctId isEqualToString:distinctIdInKeychain]) {
            //保存 Archiver
            NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
            [[NSFileManager defaultManager] setAttributes:protection ofItemAtPath:filePath error:nil];
            if (![NSKeyedArchiver archiveRootObject:[[self distinctId] copy] toFile:filePath]) {
                BTLog(@"%@ unable to archive distinctId", self);
            }
        }
    } else {
#endif
        if (archivedDistinctId.length == 0) {
            self.distinctId = [[self class] getUniqueHardwareId];
            [self archiveDistinctId];
        } else {
            self.distinctId = archivedDistinctId;
#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
            //保存 KeyChain
            [BTKeyChainItemWrapper saveUdid:self.distinctId];
        }
#endif
    }
}

- (void)unarchiveLoginId {
    NSString *archivedLoginId = (NSString *)[self unarchiveFromFile:[self filePathForData:@"login_id"]];
    self.loginId = archivedLoginId;
}

- (void)unarchiveFirstDay {
    NSString *archivedFirstDay = (NSString *)[self unarchiveFromFile:[self filePathForData:@"first_day"]];
    self.firstDay = archivedFirstDay;
}

- (void)unarchiveSuperProperties {
    NSDictionary *archivedSuperProperties = (NSDictionary *)[self unarchiveFromFile:[self filePathForData:@"super_properties"]];
    if (archivedSuperProperties == nil) {
        _superProperties = [NSDictionary dictionary];
    } else {
        _superProperties = [archivedSuperProperties copy];
    }
}

- (void)archiveDistinctId {
    NSString *filePath = [self filePathForData:BT_EVENT_DISTINCT_ID];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[[self distinctId] copy] toFile:filePath]) {
        BTLog(@"%@ unable to archive distinctId", self);
    }
#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
    [BTKeyChainItemWrapper saveUdid:self.distinctId];
#endif
    BTLog(@"%@ archived distinctId", self);
}

- (void)archiveLoginId {
    NSString *filePath = [self filePathForData:@"login_id"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[[self loginId] copy] toFile:filePath]) {
        BTLog(@"%@ unable to archive loginId", self);
    }
    BTLog(@"%@ archived loginId", self);
}

- (void)archiveFirstDay {
    NSString *filePath = [self filePathForData:@"first_day"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[[self firstDay] copy] toFile:filePath]) {
        BTLog(@"%@ unable to archive firstDay", self);
    }
    BTLog(@"%@ archived firstDay", self);
}

- (void)archiveSuperProperties {
    NSString *filePath = [self filePathForData:@"super_properties"];
    /* 为filePath文件设置保护等级 */
    NSDictionary *protection = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                           forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:protection
                                     ofItemAtPath:filePath
                                            error:nil];
    if (![NSKeyedArchiver archiveRootObject:[self.superProperties copy] toFile:filePath]) {
        BTLog(@"%@ unable to archive super properties", self);
    }
    BTLog(@"%@ archive super properties data", self);
}

#pragma mark - Network control

- (UInt64)flushInterval {
    @synchronized(self) {
        return _flushInterval;
    }
}

- (void)setFlushInterval:(UInt64)interval {
    @synchronized(self) {
        if (interval < 5 * 1000) {
            interval = 5 * 1000;
        }
        _flushInterval = interval;
    }
    [self flush];
    [self startFlushTimer];
}

- (void)startFlushTimer {
    [self stopFlushTimer];
    BTLog(@"starting flush timer.");
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_flushInterval > 0) {
            double interval = self->_flushInterval > 100 ? (double)self->_flushInterval / 1000.0 : 0.1f;
            self.timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                          target:self
                                                        selector:@selector(flush)
                                                        userInfo:nil
                                                         repeats:YES];
            [[NSRunLoop currentRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];
        }
    });
}

- (void)stopFlushTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
        }
        self.timer = nil;
    });
}

- (UInt64)flushBulkSize {
    @synchronized(self) {
        return _flushBulkSize;
    }
}

- (void)setFlushBulkSize:(UInt64)bulkSize {
    @synchronized(self) {
        //加上最小值保护，50
        _flushBulkSize = bulkSize >= 50 ? bulkSize : 50;
    }
}

- (NSString *)getLastScreenUrl {
    return _referrerScreenUrl;
}

- (void)clearReferrerWhenAppEnd {
    _clearReferrerWhenAppEnd = YES;
}

- (NSDictionary *)getLastScreenTrackProperties {
    return _lastScreenTrackProperties;
}

- (void)addWebViewUserAgentSensorsDataFlag {
    [self addWebViewUserAgentSensorsDataFlag:YES];
}

- (void)addWebViewUserAgentSensorsDataFlag:(BOOL)enableVerify  {
    [self addWebViewUserAgentSensorsDataFlag:enableVerify userAgent:nil];
}

- (void)addWebViewUserAgentSensorsDataFlag:(BOOL)enableVerify userAgent:(nullable NSString *)userAgent{
    void (^changeUserAgent)(BOOL verify, NSString *oldUserAgent) = ^void (BOOL verify, NSString *oldUserAgent) {
        NSString *newAgent = oldUserAgent;
        BTServerUrl *ss = [[BTServerUrl alloc]initWithUrl:self->_serverURL];
        if ([oldUserAgent rangeOfString:@"betadata-sdk-ios"].location == NSNotFound) {
            if (verify) {
                newAgent = [oldUserAgent stringByAppendingString:[NSString stringWithFormat: @" /betadata-sdk-ios/sensors-verify/%@?%@ ", ss.host, ss.project]];
            } else {
                newAgent = [oldUserAgent stringByAppendingString:@" /betadata-sdk-ios"];
            }
        }
        //使 newAgent 生效，并设置 userAgent
        NSDictionary *dictionnary = [[NSDictionary alloc] initWithObjectsAndKeys:newAgent, @"UserAgent", nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:dictionnary];
        self.userAgent = newAgent;
        [[NSUserDefaults standardUserDefaults] synchronize];
    };
    
    [NSThread bt_safelyRunOnMainThreadSync:^{
        BOOL verify = enableVerify;
        @try {
            if (self->_serverURL == nil || self->_serverURL.length == 0) {
                verify = NO;
            }
            NSString *oldAgent = userAgent.length > 0 ? userAgent : self.userAgent;
            if (oldAgent) {
                changeUserAgent(verify, oldAgent);
            } else {
                [self loadUserAgentWithCompletion:^(NSString *ua) {
                    changeUserAgent(verify, ua);
                }];
            }
        } @catch (NSException *exception) {
            BTLog(@"%@: %@", self, exception);
        }
    }];
}

- (void)setDebugMode:(BetaDataDebugMode)debugMode {
    _debugMode = debugMode;
    [self enableLog];
    [self configDebugModeServerUrl];
}

- (BetaDataDebugMode)debugMode {
    return _debugMode;
}

- (void)trackViewAppClick:(UIView *)view {
    [self trackViewAppClick:view withProperties:nil];
}

- (void)trackViewAppClick:(UIView *)view withProperties:(NSDictionary *)p {
    @try {
        if (view == nil) {
            return;
        }
        
        //关闭 AutoTrack
        if (![[BetaDataSDK sharedInstance] isAutoTrackEnabled]) {
            return;
        }
        
        //忽略 $AppClick 事件
        if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppClick]) {
            return;
        }
        
        if ([self isViewTypeIgnored:[view class]]) {
            return;
        }
        
        if (view.betaDataIgnoreView) {
            return;
        }
        
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        
        UIViewController *viewController = [self currentViewController];
        if (viewController != nil) {
            if ([[BetaDataSDK sharedInstance] isViewControllerIgnored:viewController]) {
                return;
            }
            
            //获取 Controller 名称($screen_name)
            NSString *screenName = NSStringFromClass([viewController class]);
            [properties setValue:screenName forKey:BT_EVENT_PROPERTY_SCREEN_NAME];
            NSString *controllerTitle = [AutoTrackUtils titleFromViewController:viewController];
            if (controllerTitle) {
                [properties setValue:controllerTitle forKey:BT_EVENT_PROPERTY_TITLE];
            }
        }
        
        //ViewID
        if (view.betaDataViewID != nil) {
            //[properties setValue:view.betaDataViewID forKey:BT_EVENT_PROPERTY_ELEMENT_ID];
        }
        
        //[properties setValue:NSStringFromClass([view class]) forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
        
        NSString *elementContent = [AutoTrackUtils contentFromView:view];
        elementContent = [elementContent trimWhitespaceAndNewLine];
        if (elementContent.length > 0) {
            [properties setValue:elementContent forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
        }
        
        if (p != nil) {
            [properties addEntriesFromDictionary:p];
        }
        
        //View Properties
        NSDictionary* propDict = view.betaDataViewProperties;
        if (propDict != nil) {
            [properties addEntriesFromDictionary:propDict];
        }
        
        [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
    } @catch (NSException *exception) {
        BTLog(@"%@: %@", self, exception);
    }
}

#pragma mark - UIApplication Events

- (void)setUpListeners {
    // 监听 App 启动或结束事件
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminateNotification:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
    
    [self _enableAutoTrack];
}

- (void)autoTrackViewScreen:(UIViewController *)controller {
    NSString *screenName = NSStringFromClass(controller.class);
    //过滤用户设置的不被AutoTrack的Controllers
    if (_ignoredViewControllers.count > 0 && screenName) {
        if ([_ignoredViewControllers containsObject:screenName]) {
            return;
        }
    }
    
    if (self.launchedPassively) {
        if (controller) {
            if (!self.launchedPassivelyControllers) {
                self.launchedPassivelyControllers = [NSMutableArray array];
            }
            
            if ([self shouldTrackViewScreen:controller]) {
                [self.launchedPassivelyControllers addObject:controller];
            }
        }
        return;
    }
    
    [self trackViewScreen:controller];
}

- (void)trackViewScreen:(UIViewController *)controller {
    [self trackViewScreen:controller properties:nil];
}

- (void)trackViewScreen:(UIViewController *)controller properties:(nullable NSDictionary<NSString *,id> *)properties_{
    if (!controller) {
        return;
    }
    
    if ([[BetaDataSDK sharedInstance] isViewControllerIgnored:controller]) {
        return;
    }
    
    if (![self shouldTrackViewScreen:controller]) {
        return;
    }
    
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    
    NSString *screenName = NSStringFromClass(controller.class);
    [properties setValue:screenName forKey:BT_EVENT_PROPERTY_SCREEN_NAME];
    
    @try {
        NSString *controllerTitle = [AutoTrackUtils titleFromViewController:controller];
        if (controllerTitle) {
            [properties setValue:controllerTitle forKey:BT_EVENT_PROPERTY_TITLE];
        }
    } @catch (NSException *exception) {
        BTLog(@"%@ failed to get UIViewController's title error: %@", self, exception);
    }
    
    if ([controller conformsToProtocol:@protocol(SAAutoTracker)] && [controller respondsToSelector:@selector(getTrackProperties)]) {
        UIViewController<SAAutoTracker> *autoTrackerController = (UIViewController<SAAutoTracker> *)controller;
        _lastScreenTrackProperties = [autoTrackerController getTrackProperties];
        [properties addEntriesFromDictionary:_lastScreenTrackProperties];
    }
    
#ifdef SENSORS_ANALYTICS_AUTOTRACT_APPVIEWSCREEN_URL
    [properties setValue:screenName forKey:BT_EVENT_PROPERTY_SCREEN_URL];
    @synchronized(_referrerScreenUrl) {
        if (_referrerScreenUrl) {
            [properties setValue:_referrerScreenUrl forKey:BT_EVENT_PROPERTY_SCREEN_REFERRER_URL];
        }
        _referrerScreenUrl = screenName;
    }
#endif
    
    if ([controller conformsToProtocol:@protocol(SAScreenAutoTracker)] && [controller respondsToSelector:@selector(getScreenUrl)]) {
        UIViewController<SAScreenAutoTracker> *screenAutoTrackerController = (UIViewController<SAScreenAutoTracker> *)controller;
        NSString *currentScreenUrl = [screenAutoTrackerController getScreenUrl];
        
        [properties setValue:currentScreenUrl forKey:BT_EVENT_PROPERTY_SCREEN_URL];
        
        @synchronized(_referrerScreenUrl) {
            if (_referrerScreenUrl) {
                [properties setValue:_referrerScreenUrl forKey:BT_EVENT_PROPERTY_SCREEN_REFERRER_URL];
            }
            _referrerScreenUrl = currentScreenUrl;
        }
    }
    [properties addEntriesFromDictionary:properties_];
    [self track:BT_EVENT_NAME_APP_VIEW_SCREEN withProperties:properties withTrackType:BetaDataTrackTypeAuto];
}

#ifdef SENSORS_ANALYTICS_REACT_NATIVE
static inline void __sa_methodExchange(const char *className, const char *originalMethodName, const char *replacementMethodName, IMP imp) {
    @try {
        Class cls = objc_getClass(className);//得到指定类的类定义
        SEL oriSEL = sel_getUid(originalMethodName);//把originalMethodName注册到RunTime系统中
        Method oriMethod = class_getInstanceMethod(cls, oriSEL);//获取实例方法
        struct objc_method_description *desc = method_getDescription(oriMethod);//获得指定方法的描述
        if (desc->types) {
            SEL buSel = sel_registerName(replacementMethodName);//把replacementMethodName注册到RunTime系统中
            if (class_addMethod(cls, buSel, imp, desc->types)) {//通过运行时，把方法动态添加到类中
                Method buMethod  = class_getInstanceMethod(cls, buSel);//获取实例方法
                method_exchangeImplementations(oriMethod, buMethod);//交换方法
            }
        }
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", [BetaDataSDK sharedInstance], exception);
    }
}

static void sa_imp_setJSResponderBlockNativeResponder(id obj, SEL cmd, id reactTag, BOOL blockNativeResponder){
    //先执行原来的方法
    SEL oriSel = sel_getUid("sda_setJSResponder:blockNativeResponder:");
    void (*setJSResponderWithBlockNativeResponder)(id, SEL, id, BOOL) = (void (*)(id,SEL,id,BOOL))[NSClassFromString(@"RCTUIManager") instanceMethodForSelector:oriSel];//函数指针
    setJSResponderWithBlockNativeResponder(obj, cmd, reactTag, blockNativeResponder);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            //关闭 AutoTrack
            if (![[BetaDataSDK sharedInstance] isAutoTrackEnabled]) {
                return;
            }
            
            //忽略 $AppClick 事件
            if ([[BetaDataSDK sharedInstance] isAutoTrackEventTypeIgnored:BetaDataEventTypeAppClick]) {
                return;
            }
            
            if ([[BetaDataSDK sharedInstance] isViewTypeIgnored:[NSClassFromString(@"RNView") class]]) {
                return;
            }
            
            if ([obj isKindOfClass:NSClassFromString(@"RCTUIManager")]) {
                SEL viewForReactTagSelector = NSSelectorFromString(@"viewForReactTag:");
                UIView *uiView = ((UIView* (*)(id, SEL, NSNumber*))[obj methodForSelector:viewForReactTagSelector])(obj, viewForReactTagSelector, reactTag);
                NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
                
                if ([uiView isKindOfClass:[NSClassFromString(@"RCTSwitch") class]] || [uiView isKindOfClass:[NSClassFromString(@"RCTScrollView") class]]) {
                    //好像跟 UISwitch 会重复
                    return;
                }
                
                [properties setValue:@"RNView" forKey:BT_EVENT_PROPERTY_ELEMENT_TYPE];
                [properties setValue:[uiView.accessibilityLabel stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:BT_EVENT_PROPERTY_ELEMENT_CONTENT];
                
                UIViewController *viewController = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                if ([uiView respondsToSelector:NSSelectorFromString(@"reactViewController")]) {
                    viewController = [uiView performSelector:NSSelectorFromString(@"reactViewController")];
                }
#pragma clang diagnostic pop
                if (viewController) {
                    //获取 Controller 名称($screen_name)
                    NSString *screenName = NSStringFromClass([viewController class]);
                    [properties setValue:screenName forKey:BT_EVENT_PROPERTY_SCREEN_NAME];
                    
                    NSString *controllerTitle = viewController.navigationItem.title;
                    if (controllerTitle != nil) {
                        [properties setValue:viewController.navigationItem.title forKey:BT_EVENT_PROPERTY_TITLE];
                    }
                }
                
                [[BetaDataSDK sharedInstance] track:BT_EVENT_NAME_APP_CLICK withProperties:properties withTrackType:BetaDataTrackTypeAuto];
            }
        } @catch (NSException *exception) {
            BTLog(@"%@ error: %@", [BetaDataSDK sharedInstance], exception);
        }
    });
}
#endif

- (void)_enableAutoTrack {
#ifndef SENSORS_ANALYTICS_ENABLE_AUTOTRACK_DIDSELECTROW
    void (^unswizzleUITableViewAppClickBlock)(id, SEL, id) = ^(id obj, SEL sel, NSNumber* a) {
        UIViewController *controller = (UIViewController *)obj;
        if (!controller) {
            return;
        }
        
        Class klass = [controller class];
        if (!klass) {
            return;
        }
        
        NSString *screenName = NSStringFromClass(klass);
        
        //UITableView
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UITABLEVIEW
        if ([controller respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
            [BTSwizzler unswizzleSelector:@selector(tableView:didSelectRowAtIndexPath:) onClass:klass named:[NSString stringWithFormat:@"%@_%@", screenName, @"UITableView_AutoTrack"]];
        }
#endif
        
        //UICollectionView
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UICOLLECTIONVIEW
        if ([controller respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [BTSwizzler unswizzleSelector:@selector(collectionView:didSelectItemAtIndexPath:) onClass:klass named:[NSString stringWithFormat:@"%@_%@", screenName, @"UICollectionView_AutoTrack"]];
        }
#endif
    };
#endif
    
    // 监听所有 UIViewController 显示事件
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //$AppViewScreen
        [UIViewController bt_swizzleMethod:@selector(viewWillAppear:) withMethod:@selector(bt_autotrack_viewWillAppear:) error:NULL];
        NSError *error = NULL;
        //$AppClick
        // Actions & Events
        [UIApplication bt_swizzleMethod:@selector(sendAction:to:from:forEvent:)
                             withMethod:@selector(bt_sendAction:to:from:forEvent:)
                                  error:&error];
        if (error) {
            BTLog(@"Failed to swizzle sendAction:to:forEvent: on UIAppplication. Details: %@", error);
            error = NULL;
        }
    });
#ifndef SENSORS_ANALYTICS_ENABLE_AUTOTRACK_DIDSELECTROW
    //$AppClick
    //UITableView、UICollectionView
#if (!defined SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UITABLEVIEW) || (!defined SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UICOLLECTIONVIEW)
    [BTSwizzler swizzleBoolSelector:@selector(viewWillDisappear:)
                            onClass:[UIViewController class]
                          withBlock:unswizzleUITableViewAppClickBlock
                              named:@"track_UITableView_UICollectionView_AppClick_viewWillDisappear"];
#endif
#endif
    //UILabel
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_GESTURE
    static dispatch_once_t onceTokenGesture;
    dispatch_once(&onceTokenGesture, ^{
        
        NSError *error = NULL;
        //$AppClick
        [UITapGestureRecognizer bt_swizzleMethod:@selector(addTarget:action:)
                                      withMethod:@selector(bt_addTarget:action:)
                                           error:&error];
        
        [UITapGestureRecognizer bt_swizzleMethod:@selector(initWithTarget:action:)
                                      withMethod:@selector(bt_initWithTarget:action:)
                                           error:&error];
        
        [UILongPressGestureRecognizer bt_swizzleMethod:@selector(addTarget:action:)
                                            withMethod:@selector(bt_addTarget:action:)
                                                 error:&error];
        
        [UILongPressGestureRecognizer bt_swizzleMethod:@selector(initWithTarget:action:)
                                            withMethod:@selector(bt_initWithTarget:action:)
                                                 error:&error];
        if (error) {
            BTLog(@"Failed to swizzle Target on UITapGestureRecognizer. Details: %@", error);
            error = NULL;
        }
    });
#endif
    
    //React Natove
#ifdef SENSORS_ANALYTICS_REACT_NATIVE
    if (NSClassFromString(@"RCTUIManager")) {
        //        [BTSwizzle swizzleSelector:NSSelectorFromString(@"setJSResponder:blockNativeResponder:") onClass:NSClassFromString(@"RCTUIManager") withBlock:reactNativeAutoTrackBlock named:@"track_React_Native_AppClick"];
        __sa_methodExchange("RCTUIManager", "setJSResponder:blockNativeResponder:", "sda_setJSResponder:blockNativeResponder:", (IMP)sa_imp_setJSResponderBlockNativeResponder);
    }
#endif
}


- (void)trackViewScreen:(NSString *)url withProperties:(NSDictionary *)properties {
    NSMutableDictionary *trackProperties = [[NSMutableDictionary alloc] init];
    if (properties) {
        [trackProperties addEntriesFromDictionary:properties];
    }
    @synchronized(_lastScreenTrackProperties) {
        _lastScreenTrackProperties = properties;
    }
    
    [trackProperties setValue:url forKey:BT_EVENT_PROPERTY_SCREEN_URL];
    @synchronized(_referrerScreenUrl) {
        if (_referrerScreenUrl) {
            [trackProperties setValue:_referrerScreenUrl forKey:BT_EVENT_PROPERTY_SCREEN_REFERRER_URL];
        }
        _referrerScreenUrl = url;
    }
    [self track:BT_EVENT_NAME_APP_VIEW_SCREEN withProperties:trackProperties withTrackType:BetaDataTrackTypeAuto];
}

- (void)trackEventFromExtensionWithGroupIdentifier:(NSString *)groupIdentifier completion:(void (^)(NSString *groupIdentifier, NSArray *events)) completion {
    @try {
        if (groupIdentifier == nil || [groupIdentifier isEqualToString:@""]) {
            return;
        }
        NSArray *eventArray = [[BTAppExtensionDataManager sharedInstance] readAllEventsWithGroupIdentifier:groupIdentifier];
        if (eventArray) {
            for (NSDictionary *dict in eventArray) {
                [[BetaDataSDK sharedInstance] track:dict[BT_EVENT_NAME] withProperties:dict[BT_EVENT_PROPERTIES] withTrackType:BetaDataTrackTypeAuto];
            }
            [[BTAppExtensionDataManager sharedInstance] deleteEventsWithGroupIdentifier:groupIdentifier];
            if (completion) {
                completion(groupIdentifier, eventArray);
            }
        }
    } @catch (NSException *exception) {
        BTLog(@"%@ error: %@", self, exception);
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    BTLog(@"%@ application will enter foreground", self);
    
    _appRelaunched = YES;
    self.launchedPassively = NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    BTLog(@"%@ application did become active", self);
    if (_appRelaunched) {
        //下次启动 app 的时候重新初始化
        NSDictionary *sdkConfig = [[NSUserDefaults standardUserDefaults] objectForKey:BT_SDK_TRACK_CONFIG];
    }
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
    if (self.deviceOrientationConfig.enableTrackScreenOrientation) {
        [self.deviceOrientationManager startDeviceMotionUpdates];
    }
#endif
    
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_GPS
    if (self.locationConfig.enableGPSLocation) {
        [self.locationManager startUpdatingLocation];
    }
#endif
    if (_applicationWillResignActive) {
        _applicationWillResignActive = NO;
        if (self.timer == nil || ![self.timer isValid]) {
            [self startFlushTimer];
        }
        return;
    }
    _applicationWillResignActive = NO;
    
    // 是否首次启动
    BOOL isFirstStart = NO;
    if (![[NSUserDefaults standardUserDefaults] boolForKey:BT_HAS_LAUNCHED_ONCE]) {
        isFirstStart = YES;
    }
    
    // 遍历 trackTimer ,修改 eventBegin 为当前 currentSystemUpTime
    dispatch_async(self.serialQueue, ^{
        
        NSNumber *currentSystemUpTime = @([[self class] getSystemUpTime]);
        NSArray *keys = [self.trackTimer allKeys];
        NSString *key = nil;
        NSMutableDictionary *eventTimer = nil;
        for (key in keys) {
            eventTimer = [[NSMutableDictionary alloc] initWithDictionary:self.trackTimer[key]];
            if (eventTimer) {
                [eventTimer setValue:currentSystemUpTime forKey:@"eventBegin"];
                self.trackTimer[key] = eventTimer;
            }
        }
    });
    
    if ([self isAutoTrackEnabled] && _appRelaunched) {
        // 追踪 AppStart 事件
        if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppStart] == NO) {
            [self track:BT_EVENT_NAME_APP_START withProperties:@{
                //                                                                 BT_EVENT_PROPERTY_RESUME_FROM_BACKGROUND : @(_appRelaunched),
                //BT_EVENT_PROPERTY_APP_FIRST_START : @(isFirstStart),
            } withTrackType:BetaDataTrackTypeAuto];
        }
        // 启动 AppEnd 事件计时器
        if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppEnd] == NO) {
            [self trackTimer:BT_EVENT_NAME_APP_END withTimeUnit:BetaDataTimeUnitMilliseconds];
        }
    }
    
    //track 被动启动的页面浏览
    if (self.launchedPassivelyControllers) {
        [self.launchedPassivelyControllers enumerateObjectsUsingBlock:^(UIViewController * _Nonnull controller, NSUInteger idx, BOOL * _Nonnull stop) {
            [self trackViewScreen:controller];
        }];
        self.launchedPassivelyControllers = nil;
    }
    
    [self startFlushTimer];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    BTLog(@"%@ application will resign active", self);
    _applicationWillResignActive = YES;
    [self stopFlushTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    BTLog(@"%@ application did enter background", self);
    _applicationWillResignActive = NO;
    self.launchedPassively = NO;
    
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
    [self.deviceOrientationManager stopDeviceMotionUpdates];
#endif
    
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_GPS
    [self.locationManager stopUpdatingLocation];
#endif
    
    UIApplication *application = UIApplication.sharedApplication;
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    // 结束后台任务
    void (^endBackgroundTask)(void) = ^(){
        [application endBackgroundTask:backgroundTaskIdentifier];
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    };
    
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        endBackgroundTask();
    }];
    
    // 遍历 trackTimer
    // eventAccumulatedDuration = eventAccumulatedDuration + currentSystemUpTime - eventBegin
    dispatch_async(self.serialQueue, ^{
        NSNumber *currentSystemUpTime = @([[self class] getSystemUpTime]);
        NSArray *keys = [self.trackTimer allKeys];
        NSString *key = nil;
        NSMutableDictionary *eventTimer = nil;
        for (key in keys) {
            if (key != nil) {
                if ([key isEqualToString:BT_EVENT_NAME_APP_END]) {
                    continue;
                }
            }
            eventTimer = [[NSMutableDictionary alloc] initWithDictionary:self.trackTimer[key]];
            if (eventTimer) {
                NSNumber *eventBegin = [eventTimer valueForKey:@"eventBegin"];
                NSNumber *eventAccumulatedDuration = [eventTimer objectForKey:@"eventAccumulatedDuration"];
                long eventDuration;
                if (eventAccumulatedDuration) {
                    eventDuration = [currentSystemUpTime longValue] - [eventBegin longValue] + [eventAccumulatedDuration longValue];
                } else {
                    eventDuration = [currentSystemUpTime longValue] - [eventBegin longValue];
                }
                [eventTimer setObject:[NSNumber numberWithLong:eventDuration] forKey:@"eventAccumulatedDuration"];
                [eventTimer setObject:currentSystemUpTime forKey:@"eventBegin"];
                self.trackTimer[key] = eventTimer;
            }
        }
    });
    
    if ([self isAutoTrackEnabled]) {
        // 追踪 AppEnd 事件
        if ([self isAutoTrackEventTypeIgnored:BetaDataEventTypeAppEnd] == NO) {
            if (_clearReferrerWhenAppEnd) {
                _referrerScreenUrl = nil;
            }
            [self track:BT_EVENT_NAME_APP_END withTrackType:BetaDataTrackTypeAuto];
        }
    }
    
    if (self.flushBeforeEnterBackground) {
        dispatch_async(self.serialQueue, ^{
            [self _flush:YES];
            endBackgroundTask();
        });
    }else {
        dispatch_async(self.serialQueue, ^{
            endBackgroundTask();
        });
    }
}

-(void)applicationWillTerminateNotification:(NSNotification *)notification {
    BTLog(@"applicationWillTerminateNotification");
    dispatch_sync(self.serialQueue, ^{
    });
}

#pragma mark - SensorsData  Analytics

- (void)set:(NSDictionary *)profileDict {
    [[self people] set:profileDict];
}

- (void)profilePushKey:(NSString *)pushKey pushId:(NSString *)pushId {
    if ([pushKey isKindOfClass:NSString.class] && pushKey.length && [pushId isKindOfClass:NSString.class] && pushId.length) {
        NSString * distinctId = self.getBestId;
        NSString * keyOfPushId = [NSString stringWithFormat:@"sa_%@_%@",distinctId,pushKey];
        NSString * valueOfPushId = [NSUserDefaults.standardUserDefaults valueForKey:keyOfPushId];
        NSString * newValueOfPushId = [NSString stringWithFormat:@"%@_%@",distinctId,pushId];
        if (![valueOfPushId isEqualToString:newValueOfPushId]) {
            [self set:@{pushKey:pushId}];
            [NSUserDefaults.standardUserDefaults setValue:newValueOfPushId forKey:keyOfPushId];
        }
    }
}


- (void)setOnce:(NSDictionary *)profileDict {
    [[self people] setOnce:profileDict];
}

- (void)set:(NSString *) profile to:(id)content {
    [[self people] set:profile to:content];
}

- (void)setOnce:(NSString *) profile to:(id)content {
    [[self people] setOnce:profile to:content];
}

- (void)unset:(NSString *) profile {
    [[self people] unset:profile];
}

- (void)increment:(NSString *)profile by:(NSNumber *)amount {
    [[self people] increment:profile by:amount];
}

- (void)increment:(NSDictionary *)profileDict {
    [[self people] increment:profileDict];
}

- (void)append:(NSString *)profile by:(NSObject<NSFastEnumeration> *)content {
    if ([content isKindOfClass:[NSSet class]] || [content isKindOfClass:[NSArray class]]) {
        [[self people] append:profile by:content];
    }
}

- (void)deleteUser {
    [[self people] deleteUser];
}

- (void)enableLog:(BOOL)enabelLog{
    [BTLogger enableLog:enabelLog];
}

- (void)enableLog {
    BOOL printLog = NO;
#if (defined SENSORS_ANALYTICS_ENABLE_LOG)
    printLog = YES;
#endif
    
    if ( [self debugMode] != BetaDataDebugOff) {
        printLog = YES;
    }
    [BTLogger enableLog:printLog];
}

- (void)enableTrackScreenOrientation:(BOOL)enable {
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_DEVICE_ORIENTATION
    @try {
        self.deviceOrientationConfig.enableTrackScreenOrientation = enable;
        if (enable) {
            if (_deviceOrientationManager == nil) {
                _deviceOrientationManager = [[BTDeviceOrientationManager alloc]init];
                __weak BetaDataSDK *weakSelf = self;
                _deviceOrientationManager.deviceOrientationBlock = ^(NSString *deviceOrientation) {
                    __strong BetaDataSDK *strongSelf = weakSelf;
                    if (deviceOrientation) {
                        strongSelf.deviceOrientationConfig.deviceOrientation = deviceOrientation;
                    }
                };
            }
            [_deviceOrientationManager startDeviceMotionUpdates];
        } else {
            _deviceOrientationConfig.deviceOrientation = @"";
            if (_deviceOrientationManager) {
                [_deviceOrientationManager stopDeviceMotionUpdates];
            }
        }
    } @catch (NSException * e) {
        BTLog(@"%@ error: %@", self, e);
    }
#endif
}

- (void)enableTrackGPSLocation:(BOOL)enableGPSLocation {
#ifndef BETADATA_ANALYTICS_DISABLE_TRACK_GPS
    dispatch_block_t block = ^{
        self.locationConfig.enableGPSLocation = enableGPSLocation;
        if (enableGPSLocation) {
            if (self.locationManager == nil) {
                self.locationManager = [[BTLocationManager alloc]init];
                __weak BetaDataSDK *weakSelf = self;
                self.locationManager.updateLocationBlock = ^(CLLocation * location,NSError *error){
                    __strong BetaDataSDK *strongSelf = weakSelf;
                    if (location) {
                        strongSelf.locationConfig.coordinate = location.coordinate;
                    }
                    if (error) {
                        BTLog(@"enableTrackGPSLocation error：%@",error);
                    }
                };
            }
            [self.locationManager startUpdatingLocation];
        }else{
            if (self.locationManager != nil) {
                [self.locationManager stopUpdatingLocation];
            }
        }
    };
    if (NSThread.isMainThread) {
        block();
    }else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
#endif
}

- (void)clearKeychainData {
#ifndef SENSORS_ANALYTICS_DISABLE_KEYCHAIN
    [BTKeyChainItemWrapper deletePasswordWithAccount:kSAUdidAccount service:kSAService];
    [BTKeyChainItemWrapper deletePasswordWithAccount:kSAAppInstallationAccount service:kSAService];
    [BTKeyChainItemWrapper deletePasswordWithAccount:kSAAppInstallationWithDisableCallbackAccount service:kSAService];
#endif
    
}

@end

#pragma mark - People analytics

@implementation BetaDataAnalyticsPeople

- (void)set:(NSDictionary *)profileDict {
    if (profileDict) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_SET withProperties:profileDict withType:BT_PROFILE_SET];
    }
}

- (void)setOnce:(NSDictionary *)profileDict {
    if (profileDict) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_SET_ONCE withProperties:profileDict withType:BT_PROFILE_SET_ONCE];
    }
}

- (void)set:(NSString *) profile to:(id)content {
    if (profile && content) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_SET withProperties:@{profile: content} withType:BT_PROFILE_SET];
    }
}

- (void)setOnce:(NSString *) profile to:(id)content {
    if (profile && content) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_SET_ONCE withProperties:@{profile: content} withType:BT_PROFILE_SET_ONCE];
    }
}

- (void)unset:(NSString *) profile {
    if (profile) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_UNSET withProperties:@{profile: @""} withType:BT_PROFILE_UNSET];
    }
}

- (void)increment:(NSString *)profile by:(NSNumber *)amount {
    if (profile && amount) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_INCREMENT withProperties:@{profile: amount} withType:BT_PROFILE_INCREMENT];
    }
}

- (void)increment:(NSDictionary *)profileDict {
    if (profileDict) {
        [[BetaDataSDK sharedInstance] track:BT_PROFILE_INCREMENT withProperties:profileDict withType:BT_PROFILE_INCREMENT];
    }
}

- (void)append:(NSString *)profile by:(NSObject<NSFastEnumeration> *)content {
    if (profile && content) {
        if ([content isKindOfClass:[NSSet class]] || [content isKindOfClass:[NSArray class]]) {
            [[BetaDataSDK sharedInstance] track:BT_PROFILE_APPEND withProperties:@{profile: content} withType:BT_PROFILE_APPEND];
        }
    }
}

- (void)deleteUser {
    [[BetaDataSDK sharedInstance] track:nil withProperties:@{} withType:BT_PROFILE_DELETE];
}

@end

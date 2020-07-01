//
//  BTConstants.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/8/9.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#pragma mark--evnet nanme

// 自动追踪相关事件及属性
//extern NSString * const BT_EVENT_PROPERTY_APP_INSTALL_SOURCE;
#pragma mark - app install property

extern NSString * const BT_EVENT_PROPERTY_APP_INSTALL_DISABLE_CALLBACK;

// App 是否从后台恢复
//extern NSString * const BT_EVENT_PROPERTY_RESUME_FROM_BACKGROUND;


// ----

#pragma mark - event
extern NSString * const BT_EVENT_TIME;
extern NSString * const BT_EVENT_TRACK_ID;
extern NSString * const BT_EVENT_NAME;
extern NSString * const BT_EVENT_PROPERTIES;
extern NSString * const BT_USER_PROPERTIES;

#pragma mark - event name
// App 启动或激活
extern NSString * const BT_EVENT_NAME_APP_START;
// App 退出或进入后台
extern NSString * const BT_EVENT_NAME_APP_END;
// App 浏览页面
extern NSString * const BT_EVENT_NAME_APP_VIEW_SCREEN;
// App 元素点击
extern NSString * const BT_EVENT_NAME_APP_CLICK;

extern NSString * const BT_EVENT_NAME_INSTALL;
extern NSString * const BT_EVENT_NAME_APP_LOGIN;
extern NSString * const BT_EVENT_NAME_APP_REGISTER;

#pragma mark - autoTrack property
// App 首次启动
// App 浏览页面 Url
extern NSString * const BT_EVENT_PROPERTY_SCREEN_URL;
// App 浏览页面 Referrer Url
extern NSString * const BT_EVENT_PROPERTY_SCREEN_REFERRER_URL;
extern NSString * const BT_EVENT_PROPERTY_TITLE;

extern NSString * const BT_EVENT_PROPERTY_ELEMENT_POSITION;
extern NSString * const BT_EVENT_PROPERTY_ELEMENT_SELECTOR;
extern NSString * const BT_EVENT_PROPERTY_ELEMENT_CONTENT;

#pragma mark - common property
extern NSString * const BT_EVENT_COMMON_PROPERTY_LIB;
extern NSString * const BT_EVENT_COMMON_PROPERTY_LIB_VERSION;

extern NSString * const BT_EVENT_COMMON_PROPERTY_APP_VERSION;
extern NSString * const BT_EVENT_COMMON_PROPERTY_MODEL;
extern NSString * const BT_EVENT_COMMON_PROPERTY_MANUFACTURER;
extern NSString * const BT_EVENT_COMMON_PROPERTY_OS;
extern NSString * const BT_EVENT_COMMON_PROPERTY_OS_VERSION;
extern NSString * const BT_EVENT_COMMON_PROPERTY_SCREEN_HEIGHT;
extern NSString * const BT_EVENT_COMMON_PROPERTY_SCREEN_WIDTH;
extern NSString * const BT_EVENT_PROPERTY_SCREEN_NAME;

extern NSString * const BT_EVENT_COMMON_PROPERTY_NETWORK_TYPE;
extern NSString * const BT_EVENT_COMMON_PROPERTY_WIFI;
//extern NSString * const BT_EVENT_COMMON_PROPERTY_IP;
extern NSString * const BT_EVENT_COMMON_PROPERTY_CARRIER;
extern NSString * const BT_EVENT_COMMON_PROPERTY_DEVICE_ID;
extern NSString * const BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY;
extern NSString * const BT_EVENT_COMMON_PROPERTY_IS_FIRST;
extern NSString * const BT_EVENT_COMMON_PROPERTY_USER_ID;
extern NSString * const BT_EVENT_COMMON_PROPERTY_LAST_TIME;
extern NSString * const BT_EVENT_COMMON_PROPERTY_REGISTER_TIME;

extern NSString * const BT_EVENT_COMMON_OPTIONAL_PROPERTY_LBS;

#pragma mark - profile
extern NSString * const BT_PROFILE_SET;
extern NSString * const BT_PROFILE_SET_ONCE;
extern NSString * const BT_PROFILE_UNSET;
extern NSString * const BT_PROFILE_DELETE;
extern NSString * const BT_PROFILE_APPEND;
extern NSString * const BT_PROFILE_INCREMENT;
extern NSString * const BT_EVENT_PROPERTY_APP_FIRST_START;
extern NSString * const BT_PROFILE_PROPERTY_PHONE;
extern NSString * const BT_PROFILE_PROPERTY_EMAIL;
extern NSString * const BT_PROFILE_PROPERTY_GENDER;

#pragma mark - pay
extern NSString * const BT_EVENT_PAYMENT;

#pragma mark - NSUserDefaults
extern NSString * const BT_SDK_TRACK_CONFIG;
extern NSString * const BT_HAS_LAUNCHED_ONCE;
extern NSString * const BT_HAS_TRACK_INSTALLATION;
extern NSString * const BT_HAS_TRACK_INSTALLATION_DISABLE_CALLBACK;

extern NSString * const BT_EVENT_DISTINCT_ID;
extern NSString * const BT_EVENT_TYPE;

NS_ASSUME_NONNULL_END

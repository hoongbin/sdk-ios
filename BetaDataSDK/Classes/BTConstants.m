//
//  BTConstants.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/8/9.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import "BTConstants.h"

// 自动追踪相关事件及属性
//NSString * const BT_EVENT_PROPERTY_APP_INSTALL_SOURCE = @"ios_install_source";
#pragma mark - app install property

NSString * const BT_EVENT_PROPERTY_APP_INSTALL_DISABLE_CALLBACK = @"_ios_install_disable_callback";
// App 是否从后台恢复
//NSString * const BT_EVENT_PROPERTY_RESUME_FROM_BACKGROUND = @"resume_from_background";

// ----

#pragma mark - event
NSString * const BT_EVENT_TIME = @"_time";
NSString * const BT_EVENT_TRACK_ID = @"_track_id";
NSString * const BT_EVENT_NAME = @"_event";
NSString * const BT_EVENT_PROPERTIES = @"event_properties";
NSString * const BT_USER_PROPERTIES = @"user_properties";

#pragma mark - event name
// App 启动或激活
NSString * const BT_EVENT_NAME_APP_START = @"_app_start";
// App 退出或进入后台
NSString * const BT_EVENT_NAME_APP_END = @"_app_end";
// App 浏览页面
NSString * const BT_EVENT_NAME_APP_VIEW_SCREEN = @"_app_pageview";
// App 元素点击
NSString * const BT_EVENT_NAME_APP_CLICK = @"_app_click";

NSString * const BT_EVENT_NAME_INSTALL = @"_app_install";

NSString * const BT_EVENT_NAME_APP_LOGIN = @"_app_login";

NSString * const BT_EVENT_NAME_APP_REGISTER = @"_app_register";


#pragma mark - autoTrack property
// App 首次启动
// App 浏览页面 Url
NSString * const BT_EVENT_PROPERTY_SCREEN_URL = @"_url";
// App 浏览页面 Referrer Url
NSString * const BT_EVENT_PROPERTY_SCREEN_REFERRER_URL = @"_referrer";
NSString * const BT_EVENT_PROPERTY_TITLE = @"_title";

NSString * const BT_EVENT_PROPERTY_ELEMENT_POSITION = @"_element_position";
NSString * const BT_EVENT_PROPERTY_ELEMENT_SELECTOR = @"_element_selector";
NSString * const BT_EVENT_PROPERTY_ELEMENT_CONTENT = @"_element_content";

#pragma mark - common property
NSString * const BT_EVENT_COMMON_PROPERTY_LIB = @"_sdk";
NSString * const BT_EVENT_COMMON_PROPERTY_LIB_VERSION = @"_sdk_version";

NSString * const BT_EVENT_COMMON_PROPERTY_APP_VERSION = @"_app_version";
NSString * const BT_EVENT_COMMON_PROPERTY_MODEL = @"_model";
NSString * const BT_EVENT_COMMON_PROPERTY_MANUFACTURER = @"_manufacturer";
NSString * const BT_EVENT_COMMON_PROPERTY_OS = @"_os";
NSString * const BT_EVENT_COMMON_PROPERTY_OS_VERSION = @"_os_version";
NSString * const BT_EVENT_COMMON_PROPERTY_SCREEN_HEIGHT = @"_screen_height";
NSString * const BT_EVENT_COMMON_PROPERTY_SCREEN_WIDTH = @"_screen_width";
NSString * const BT_EVENT_PROPERTY_SCREEN_NAME = @"_screen_name";

NSString * const BT_EVENT_COMMON_PROPERTY_NETWORK_TYPE = @"_network_type";
NSString * const BT_EVENT_COMMON_PROPERTY_WIFI = @"_wifi";
//NSString * const BT_EVENT_COMMON_PROPERTY_IP = @"_ip";
NSString * const BT_EVENT_COMMON_PROPERTY_CARRIER = @"_carrier";
NSString * const BT_EVENT_COMMON_PROPERTY_DEVICE_ID = @"_device_id";
NSString * const BT_EVENT_COMMON_PROPERTY_IS_FIRST_DAY = @"_is_first_day";
NSString * const BT_EVENT_COMMON_PROPERTY_IS_FIRST = @"_is_first";
NSString * const BT_EVENT_COMMON_PROPERTY_USER_ID = @"_second_id";
NSString * const BT_EVENT_COMMON_PROPERTY_LAST_TIME = @"_last_time";
NSString * const BT_EVENT_COMMON_PROPERTY_REGISTER_TIME = @"_register_time";

NSString * const BT_EVENT_COMMON_OPTIONAL_PROPERTY_LBS = @"_lbs";

#pragma mark - profile
NSString * const BT_PROFILE_SET = @"_app_profile";
NSString * const BT_PROFILE_SET_ONCE = @"profile_set_once";
NSString * const BT_PROFILE_UNSET = @"profile_unset";
NSString * const BT_PROFILE_DELETE = @"profile_delete";
NSString * const BT_PROFILE_APPEND = @"profile_append";
NSString * const BT_PROFILE_INCREMENT = @"profile_increment";
NSString * const BT_EVENT_PROPERTY_APP_FIRST_START = @"_first_visit_time";
NSString * const BT_PROFILE_PROPERTY_PHONE = @"_mobile";
NSString * const BT_PROFILE_PROPERTY_EMAIL = @"_email";
NSString * const BT_PROFILE_PROPERTY_GENDER = @"_gender";

#pragma mark - pay
NSString * const BT_EVENT_PAYMENT = @"_app_payment";
NSString * const BT_PAYMENT_PROPERTY_GOODS_TYPE = @"_payment_goods_type";
NSString * const BT_PAYMENT_PROPERTY_TRADE_NO   = @"_payment_trade_no";
NSString * const BT_PAYMENT_PROPERTY_CHANNEL    = @"_payment_channel";
NSString * const BT_PAYMENT_PROPERTY_AMOUNT     = @"_payment_amount";

#pragma mark - NSUserDefaults
NSString * const BT_SDK_TRACK_CONFIG = @"SASDKConfig";
NSString * const BT_HAS_LAUNCHED_ONCE = @"HasLaunchedOnce";
NSString * const BT_HAS_TRACK_INSTALLATION = @"HasTrackInstallation";
NSString * const BT_HAS_TRACK_INSTALLATION_DISABLE_CALLBACK = @"HasTrackInstallationWithDisableCallback";

NSString * const BT_EVENT_DISTINCT_ID = @"distinct_id";
NSString * const BT_EVENT_TYPE = @"type";

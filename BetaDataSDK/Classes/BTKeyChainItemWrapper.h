//
//  SAUdid.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/3/26.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
extern  NSString * const kSAService;
extern  NSString * const kSAUdidAccount;
extern  NSString * const kSAAppInstallationAccount;
extern  NSString * const kSAAppInstallationWithDisableCallbackAccount;
@interface BTKeyChainItemWrapper : NSObject

+ (NSString *)saUdid;
+ (NSString *)saveUdid:(NSString *)udid;

#ifndef SENSORS_ANALYTICS_DISABLE_INSTALLATION_MARK_IN_KEYCHAIN
+ (BOOL)hasTrackInstallation;
+ (BOOL)hasTrackInstallationWithDisableCallback;
+ (BOOL)markHasTrackInstallation;
+ (BOOL)markHasTrackInstallationWithDisableCallback;
#endif

+ (BOOL)saveOrUpdatePassword:(NSString *)password account:(NSString *)account service:(NSString *)service ;
+ (NSDictionary *)fetchPasswordWithAccount:(NSString *)account service:(NSString *)service ;
+ (BOOL)deletePasswordWithAccount:(NSString *)account service:(NSString *)service ;

+ (BOOL)saveOrUpdatePassword:(NSString *)password account:(NSString *)account service:(NSString *)service accessGroup:(NSString *)accessGroup;
+ (NSDictionary *)fetchPasswordWithAccount:(NSString *)account service:(NSString *)service accessGroup:(NSString *)accessGroup;
+ (BOOL)deletePasswordWithAccount:(NSString *)account service:(NSString *)service accessGroup:(NSString *)accessGroup;

@end

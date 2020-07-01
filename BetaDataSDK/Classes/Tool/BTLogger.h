//
//  BTLogger.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 15/7/6.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//
#import <UIKit/UIKit.h>
#ifndef __BetaDataSDK__BTLogger__
#define __BetaDataSDK__BTLogger__

#define BTLogLevel(lvl,fmt,...)\
[BTLogger log : YES                                  \
level : lvl                                          \
file : __FILE__                                      \
function : __PRETTY_FUNCTION__                       \
line : __LINE__                                      \
format : (fmt), ## __VA_ARGS__]

#define BTLog(fmt,...)\
BTLogLevel(BTLoggerLevelInfo,(fmt), ## __VA_ARGS__)

#endif/* defined(__BetaDataSDK__BTLogger__) */
typedef NS_ENUM(NSUInteger,BTLoggerLevel){
    BTLoggerLevelInfo = 1,
    BTLoggerLevelWarning ,
    BTLoggerLevelError ,
};

@interface BTLogger:NSObject
@property(class , readonly, strong) BTLogger *sharedInstance;
+ (BOOL)isLoggerEnabled;
+ (void)enableLog:(BOOL)enableLog;
+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... ;
@end

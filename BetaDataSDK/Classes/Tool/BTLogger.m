//
//  BTLogger.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/3/28.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import <Foundation/Foundation.h>
#import "BTLogger.h"

static BOOL enableLog_;
static dispatch_queue_t logQueue_;

@implementation BTLogger
+ (void)initialize {
    enableLog_ = NO;
    logQueue_ = dispatch_queue_create("com.betadata.log", DISPATCH_QUEUE_SERIAL);
}

+ (BOOL)isLoggerEnabled {
    __block BOOL enable = NO;
    dispatch_sync(logQueue_, ^{
        enable = enableLog_;
    });
    return enable;
}

+ (void)enableLog:(BOOL)enableLog {
    dispatch_async(logQueue_, ^{
        enableLog_ = enableLog;
    });
}

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {
    
    //iOS 10.x 有可能触发 [[NSString alloc] initWithFormat:format arguments:args]  crash ，不在启用 Log
    NSInteger systemVersion = UIDevice.currentDevice.systemVersion.integerValue;
    if (systemVersion == 10) {
        return;
    }
    @try{
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:message level:level file:file function:function line:line];
        va_end(args);
    } @catch(NSException *e){
       
    }
}

- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line {
    @try{
        NSString *logMessage = [[NSString alloc]initWithFormat:@"[贝塔数据][%@]  %s [line %lu]    %s %@", [self descriptionForLevel:level], function, (unsigned long)line, [@"" UTF8String], message];
        if ([BTLogger isLoggerEnabled]) {
            NSLog(@"\n%@",logMessage);
        }
    } @catch(NSException *e){
       
    }
}

-(NSString *)descriptionForLevel:(BTLoggerLevel)level {
    NSString *desc = nil;
    switch (level) {
        case BTLoggerLevelInfo:
            desc = @"INFO";
            break;
        case BTLoggerLevelWarning:
            desc = @"WARN";
            break;
        case BTLoggerLevelError:
            desc = @"ERROR";
            break;
        default:
            desc = @"UNKNOW";
            break;
    }
    return desc;
}

- (void)dealloc {
    
}

@end

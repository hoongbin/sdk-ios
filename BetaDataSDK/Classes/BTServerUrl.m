//
//  BTServerUrl.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/1/2.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "BTServerUrl.h"
#import "BTLogger.h"

@interface BTServerUrl ()

@property (nonatomic, copy, readwrite) NSString *url;
@property (nonatomic, copy, readwrite) NSString *host;
@property (nonatomic, copy, readwrite) NSString *project;
@property (nonatomic, copy, readwrite) NSString *token;

@end

@implementation BTServerUrl

- (BOOL)check:(BTServerUrl *)serverUrl {
    @try {
        if ([_host isEqualToString:serverUrl.host] &&
            [_project isEqualToString:serverUrl.project]) {
            return YES;
        }
    } @catch(NSException *exception) {
        BTLog(@"%@: %@", self, exception);
    }
    return NO;
}

- (instancetype)initWithUrl:(NSString *)url {
    if (self = [super init]) {
        _url = url;
        if (url != nil) {
            @try {
                NSURLComponents *urlComponents = [NSURLComponents componentsWithString:url];
                if (urlComponents) {
                    _host = urlComponents.host;
                    NSMutableDictionary *tempDic = [[NSMutableDictionary alloc] init];
                    for (NSURLQueryItem *item in urlComponents.queryItems) {
                        [tempDic setValue:item.value forKey:item.name];
                    }

                    if (tempDic.count) {
                        _project = [tempDic objectForKey:@"project"];
                        _token = [tempDic objectForKey:@"token"];
                    }
                }
            } @catch(NSException *exception) {
                BTLog(@"%@: %@", self, exception);
            } @finally {
                if (_host == nil) {
                    _host = @"";
                }
                if (_project == nil) {
                    _project = @"default";
                }
                if (_token == nil) {
                    _token = @"";
                }
            }
        }
    }
    return self;
}
@end

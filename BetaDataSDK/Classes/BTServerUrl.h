//
//  BTServerUrl.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/1/2.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BTServerUrl : NSObject
@property (nonatomic, copy, readonly) NSString *url;
@property (nonatomic, copy, readonly) NSString *host;
@property (nonatomic, copy, readonly) NSString *project;
@property (nonatomic, copy, readonly) NSString *token;

- (instancetype)initWithUrl:(NSString *)url;
- (BOOL)check:(BTServerUrl *)serverUrl;
@end

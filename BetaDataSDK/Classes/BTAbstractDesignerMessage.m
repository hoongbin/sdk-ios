//
//  BTAbstractDesignerMessage.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "BTAbstractDesignerMessage.h"
#import "BTLogger.h"
#import "NSData+GZIP.h"

@interface BTAbstractDesignerMessage ()

@property (nonatomic, copy, readwrite) NSString *type;

@end

@implementation BTAbstractDesignerMessage {
    NSMutableDictionary *_payload;
}

+ (instancetype)messageWithType:(NSString *)type payload:(NSDictionary *)payload {
    return [[self alloc] initWithType:type payload:payload];
}

- (instancetype)initWithType:(NSString *)type {
    return [self initWithType:type payload:@{}];
}

- (instancetype)initWithType:(NSString *)type payload:(NSDictionary *)payload {
    self = [super init];
    if (self) {
        _type = type;
        _payload = [payload mutableCopy];
    }

    return self;
}

- (void)setPayloadObject:(id)object forKey:(NSString *)key {
    _payload[key] = object ?: [NSNull null];
}

- (id)payloadObjectForKey:(NSString *)key {
    id object = _payload[key];
    return [object isEqual:[NSNull null]] ? nil : object;
}

- (NSDictionary *)payload {
    return [_payload copy];
}

- (NSData *)JSONData:(BOOL)useGzip {
    NSMutableDictionary *jsonObject = [[NSMutableDictionary alloc] init];
    
    [jsonObject setObject:_type forKey:@"type"];

    if (useGzip) {
        // 如果使用 GZip 压缩
        NSError *error = nil;
        
        // 1. 序列化 Payload
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[_payload copy] options:0 error:&error];
        NSString * jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        // 2. 使用 GZip 进行压缩
        NSData *zippedData = [[jsonString dataUsingEncoding:NSUTF8StringEncoding] gzippedData];

        // 3. Base64 Encode
        NSString *b64String = [zippedData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];

        [jsonObject setValue:b64String forKey:@"gzip_payload"];
    } else {
        [jsonObject setValue:[_payload copy] forKey:@"payload"];
    }

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&error];
    if (jsonData == nil && error) {
        BTLog(@"Failed to serialize test designer message: %@", error);
    }

    return jsonData;
}

- (NSOperation *)responseCommandWithConnection:(SADesignerConnection *)connection {
    return nil;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@:%p type='%@'>", NSStringFromClass([self class]), (__bridge void *)self, self.type];
}

@end

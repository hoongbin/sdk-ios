//
//  BTAbstractHeatMapMessage.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 8/1/17.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BTHeatMapMessage.h"

@interface BTAbstractHeatMapMessage : NSObject <BTHeatMapMessage>

@property (nonatomic, copy, readonly) NSString *type;

+ (instancetype)messageWithType:(NSString *)type payload:(NSDictionary *)payload;

- (instancetype)initWithType:(NSString *)type;
- (instancetype)initWithType:(NSString *)type payload:(NSDictionary *)payload;

- (void)setPayloadObject:(id)object forKey:(NSString *)key;
- (id)payloadObjectForKey:(NSString *)key;
- (NSDictionary *)payload;

- (NSData *)JSONData:(BOOL)useGzip withFeatuerCode:(NSString *)fetureCode;

@end

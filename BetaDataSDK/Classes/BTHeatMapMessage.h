//
//  BTHeatMapMessage.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 8/1/17.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BTHeatMapConnection;

@protocol BTHeatMapMessage <NSObject>

@property (nonatomic, copy, readonly) NSString *type;

- (void)setPayloadObject:(id)object forKey:(NSString *)key;
- (id)payloadObjectForKey:(NSString *)key;

- (NSData *)JSONData:(BOOL)useGzip withFeatuerCode:(NSString *)fetureCode;

- (NSOperation *)responseCommandWithConnection:(BTHeatMapConnection *)connection;

@end

//
//  BTObjectSerializer.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BTClassDescription;
@class BTObjectSerializerConfig;
@class BTObjectIdentityProvider;

@interface BTObjectSerializer : NSObject

- (instancetype)initWithConfiguration:(BTObjectSerializerConfig *)configuration
               objectIdentityProvider:(BTObjectIdentityProvider *)objectIdentityProvider;

- (NSDictionary *)serializedObjectsWithRootObject:(id)rootObject;

@end

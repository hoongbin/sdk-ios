//
//  BTObjectSerializerConfig.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BTEnumDescription;
@class BTClassDescription;
@class BTTypeDescription;

@interface BTObjectSerializerConfig : NSObject

@property (nonatomic, readonly) NSArray *classDescriptions;
@property (nonatomic, readonly) NSArray *enumDescriptions;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

- (BTTypeDescription *)typeWithName:(NSString *)name;
- (BTEnumDescription *)enumWithName:(NSString *)name;
- (BTClassDescription *)classWithName:(NSString *)name;

@end

//
//  BTPropertyDescription.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BTObjectSerializerContext;

@interface SAPropertySelectorParameterDescription : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *type;

@end

@interface SAPropertySelectorDescription : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
@property (nonatomic, readonly) NSString *selectorName;
@property (nonatomic, readonly) NSString *returnType;
@property (nonatomic, readonly) NSArray *parameters; // array of SAPropertySelectorParameterDescription

@end

@interface BTPropertyDescription : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) BOOL readonly;
@property (nonatomic, readonly) BOOL nofollow;
@property (nonatomic, readonly) BOOL useKeyValueCoding;
@property (nonatomic, readonly) BOOL useInstanceVariableAccess;
@property (nonatomic, readonly) NSString *name;

@property (nonatomic, readonly) SAPropertySelectorDescription *getSelectorDescription;
@property (nonatomic, readonly) SAPropertySelectorDescription *setSelectorDescription;

- (BOOL)shouldReadPropertyValueForObject:(NSObject *)object;

- (NSValueTransformer *)valueTransformer;

@end

//
//  BTClassDescription.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BTTypeDescription.h"

@interface BTClassDescription : BTTypeDescription

@property (nonatomic, readonly) BTClassDescription *superclassDescription;
@property (nonatomic, readonly) NSArray *propertyDescriptions;
@property (nonatomic, readonly) NSArray *delegateInfos;

- (instancetype)initWithSuperclassDescription:(BTClassDescription *)superclassDescription dictionary:(NSDictionary *)dictionary;

- (BOOL)isDescriptionForKindOfClass:(Class)class;

@end

@interface SADelegateInfo : NSObject

@property (nonatomic, readonly) NSString *selectorName;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

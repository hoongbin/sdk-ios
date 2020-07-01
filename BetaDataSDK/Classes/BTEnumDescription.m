//
//  BTEnumDescription.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import "BTEnumDescription.h"

@implementation BTEnumDescription {
    NSMutableDictionary *_values;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    NSParameterAssert(dictionary[@"flag_set"] != nil);
    NSParameterAssert(dictionary[@"base_type"] != nil);
    NSParameterAssert(dictionary[@"values"] != nil);

    self = [super initWithDictionary:dictionary];
    if (self) {
        _flagSet = [dictionary[@"flag_set"] boolValue];
        _baseType = [dictionary[@"base_type"] copy];
        _values = [[NSMutableDictionary alloc] init];

        for (NSDictionary *value in dictionary[@"values"]) {
            _values[value[@"value"]] = value[@"display_name"];
        }
    }

    return self;
}

- (NSArray *)allValues {
    return [_values allKeys];
}

@end

//
//  BTObjectIdentityProvider.m
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/18/16.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag on this file.
#endif


#import <libkern/OSAtomic.h>

#import "BTObjectIdentityProvider.h"

@interface SASequenceGenerator : NSObject

- (int32_t)nextValue;

@end

@implementation SASequenceGenerator {
    int32_t _value;
}

- (instancetype)init {
    return [self initWithInitialValue:0];
}

- (instancetype)initWithInitialValue:(int32_t)initialValue {
    self = [super init];
    if (self) {
        _value = initialValue;
    }
    
    return self;
}

- (int32_t)nextValue {
    return OSAtomicAdd32(1, &_value);
}

@end

@implementation BTObjectIdentityProvider {
    NSMapTable *_objectToIdentifierMap;
    SASequenceGenerator *_sequenceGenerator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _objectToIdentifierMap = [NSMapTable weakToStrongObjectsMapTable];
        _sequenceGenerator = [[SASequenceGenerator alloc] init];
    }

    return self;
}

- (NSString *)identifierForObject:(id)object {
    if ([object isKindOfClass:[NSString class]]) {
        return object;
    }
    NSString *identifier = [_objectToIdentifierMap objectForKey:object];
    if (identifier == nil) {
        identifier = [NSString stringWithFormat:@"$%" PRIi32, [_sequenceGenerator nextValue]];
        [_objectToIdentifierMap setObject:identifier forKey:object];
    }

    return identifier;
}

@end

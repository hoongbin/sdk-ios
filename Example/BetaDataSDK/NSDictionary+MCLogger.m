//
//  NSDictionary+MCLogger.m
//  Huizhen
//
//  Created by Zhou Kang on 2019/3/26.
//  Copyright © 2019 Moca Inc. All rights reserved.
//

#import "NSDictionary+MCLogger.h"

id prettify(id obj) {
    id tempObj = obj;
    // 遇到NSArray、NSSet或NSDictionary的子类，内容后移\t
    if ([obj isKindOfClass:[NSDictionary class]] ||
        [obj isKindOfClass:[NSArray class]] ||
        [obj isKindOfClass:[NSSet class]]) {
        NSString *str = [NSString stringWithFormat:@"%@", obj];
        str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"];
        tempObj = str;
    } else if ([obj isKindOfClass:[NSString class]]) { // NSString类型数据加双引号
        tempObj = [NSString stringWithFormat:@"\"%@\"", obj];
    }
    return tempObj;
}

@implementation NSArray (MCLogger)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *str = [NSMutableString stringWithString:@"(\n"];
    // 遍历数组的所有元素
    for (id obj in self) {
        [str appendFormat:@"\t%@,\n", prettify(obj)];
    }
    [str appendString:@")"];
    return str;
}

@end

@implementation NSDictionary (MCLogger)

- (NSString *)descriptionWithLocale:(id)locale {
    __block NSMutableString *str = [NSMutableString stringWithString:@"{\n"];
    // 遍历字典的所有键值对
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [str appendFormat:@"\t%@ = %@,\n", key, prettify(obj)];
    }];
    [str appendString:@"}"];
    // 删掉最后一个','
    NSRange range = [str rangeOfString:@"," options:NSBackwardsSearch];
    if (range.location > 0 && range.location < str.length) {
        [str deleteCharactersInRange:range];
    }
    return str;
}

@end

@implementation NSSet (MCLogger)

- (NSString *)descriptionWithLocale:(id)locale {
    NSMutableString *str = [NSMutableString stringWithString:@"{(\n"];
    for (id value in self) {
        NSLog(@"%@", value);
        [str appendFormat:@"\t%@,\n", prettify(value)];
    }
    [str appendString:@")}"];
    // 删掉最后一个,
    NSRange range = [str rangeOfString:@"," options:NSBackwardsSearch];
    if (range.location > 0 && range.location < str.length) {
        [str deleteCharactersInRange:range];
    }
    return str;
}

@end

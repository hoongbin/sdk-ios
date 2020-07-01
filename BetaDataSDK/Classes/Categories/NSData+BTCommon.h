//
//  NSData+BTCommon.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2019/4/11.
//

NS_ASSUME_NONNULL_BEGIN

@interface NSData (BTCommon)

- (NSString *)bt_hmacSHA256StringWithKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END

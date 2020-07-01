//
//  BTCommonUtility.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2018/7/26.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BTCommonUtility : NSObject

///按字节截取指定长度字符，包括汉字和表情
+ (NSString *)subByteString:(NSString *)string byteLength:(NSInteger )length;

@end

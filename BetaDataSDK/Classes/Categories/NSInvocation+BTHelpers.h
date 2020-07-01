//  BTSwizzle.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/20/16
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSInvocation (BTHelpers)

- (void)sa_setArgumentsFromArray:(NSArray *)argumentArray;
- (id)sa_returnValue;

@end

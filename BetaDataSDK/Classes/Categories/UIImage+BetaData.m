//
//  UIImage+BTCommon.m
//  BetaDataSDK
//
//  Created by ZK on 2019/7/23.
//

#import "UIImage+BetaData.h"
#import <objc/runtime.h>

@implementation UIImage (BetaData)

- (NSString *)betaDataImageName {
    return objc_getAssociatedObject(self, @selector(betaDataImageName));
}

- (void)setBetaDataImageName:(NSString *)betaDataImageName {
    objc_setAssociatedObject(self, @selector(betaDataImageName), betaDataImageName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

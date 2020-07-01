//
//  ObjectSelector.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 1/20/16
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//
//

#import <Foundation/Foundation.h>

@interface BTObjectSelector : NSObject

@property (nonatomic, strong, readonly) NSString *string;

+ (BTObjectSelector *)objectSelectorWithString:(NSString *)string;
- (instancetype)initWithString:(NSString *)string;

- (NSArray *)selectFromRoot:(id)root;
- (NSArray *)fuzzySelectFromRoot:(id)root;

- (BOOL)isLeafSelected:(id)leaf fromRoot:(id)root;
- (BOOL)fuzzyIsLeafSelected:(id)leaf fromRoot:(id)root;

- (Class)selectedClass;
- (NSString *)description;

@end

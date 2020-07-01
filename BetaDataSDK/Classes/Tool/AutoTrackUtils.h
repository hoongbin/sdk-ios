//
//  AutoTrackUtils.h
//  BetaDataSDK
//
//  Created by Zhou Kang on 2017/6/29.
//  Copyright © 2015－2018 Beta Data Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AutoTrackUtils : NSObject

+ (void)trackAppClickWithUITableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

+ (void)trackAppClickWithUICollectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;

+ (NSString *)contentFromView:(UIView *)rootView;

+ (NSString *)titleFromViewController:(UIViewController *)viewController;

+ (void)addViewPathProperties:(NSMutableDictionary *)properties withObject:(UIView *)view withViewController:(UIViewController *)viewController;

@end

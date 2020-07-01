//
//  UIView+BetaData.h
//  BetaDataSDK
//
//  Created by ZK on 2019/7/23.
//



NS_ASSUME_NONNULL_BEGIN

@interface UIView (BetaData)

- (nullable UIViewController *)sensorsAnalyticsViewController;

//viewID
@property (copy,nonatomic) NSString* betaDataViewID;

//AutoTrack 时，是否忽略该 View
@property (nonatomic,assign) BOOL betaDataIgnoreView;

//AutoTrack 发生在 SendAction 之前还是之后，默认是 SendAction 之前
@property (nonatomic,assign) BOOL betaDataAutoTrackAfterSendAction;

//AutoTrack 时，View 的扩展属性
@property (strong,nonatomic) NSDictionary* betaDataViewProperties;

@property (nonatomic, weak, nullable) id betaDataDelegate;

@end

NS_ASSUME_NONNULL_END

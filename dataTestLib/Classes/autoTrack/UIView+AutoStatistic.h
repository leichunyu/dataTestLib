//
//  UIView+AutoStatistic.h
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (AutoStatistic)

- (nullable UIViewController *)viewController;

//viewID
@property (copy,nonatomic) NSString* sensorsAnalyticsViewID;
//AutoTrack 时，View 的扩展属性
@property (strong,nonatomic) NSDictionary* sensorsAnalyticsViewProperties;
@end

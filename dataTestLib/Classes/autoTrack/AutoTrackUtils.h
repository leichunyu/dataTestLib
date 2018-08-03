//
//  AutoTrackUtils.h
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "DTLogger.h"

@interface AutoTrackUtils : NSObject

+ (void)trackAppClickWithUITableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

+ (void)trackAppClickWithUICollectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;

+ (NSString *)contentFromView:(UIView *)rootView;

+ (void)sa_addViewPathProperties:(NSMutableDictionary *)properties withObject:(UIView *)view withViewController:(UIViewController *)viewController;

+ (UIViewController *)currentViewController;
+ (NSString *)getUIViewControllerTitle:(UIViewController *)controller;
+ (void)trackClickEvent:(NSDictionary *)eventMessage;
+ (void)enableAutoTrack;
//+ (void)trackViewScreen:(UIViewController *)controller;
@end

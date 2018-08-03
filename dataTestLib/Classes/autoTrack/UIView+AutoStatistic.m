//
//  UIView+AutoStatistic.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import "UIView+AutoStatistic.h"
#import <objc/runtime.h>

@implementation UIView (AutoStatistic)

- (UIViewController *)viewController {
    UIResponder *next = [self nextResponder];
    do {
        if ([next isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)next;
        }
        next = [next nextResponder];
    } while (next != nil);
    return nil;
}

//viewID
- (NSString *)sensorsAnalyticsViewID {
    return objc_getAssociatedObject(self, @"sensorsAnalyticsViewID");
}

- (void)setSensorsAnalyticsViewID:(NSString *)sensorsAnalyticsViewID {
    objc_setAssociatedObject(self, @"sensorsAnalyticsViewID", sensorsAnalyticsViewID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

//viewProperty
- (NSDictionary *)sensorsAnalyticsViewProperties {
    return objc_getAssociatedObject(self, @"sensorsAnalyticsViewProperties");
}

- (void)setSensorsAnalyticsViewProperties:(NSDictionary *)sensorsAnalyticsViewProperties {
    objc_setAssociatedObject(self, @"sensorsAnalyticsViewProperties", sensorsAnalyticsViewProperties, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

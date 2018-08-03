//
//  UIApplication+AutoTrack.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import "UIApplication+AutoTrack.h"
#import "AutoTrackUtils.h"
//#import "UIView+SAHelpers.h"
#import "UIView+AutoStatistic.h"
#import "SASwizzle.h"
#import "DTLogger.h"
#import "DatatistTracker.h"
#import <objc/runtime.h>

@implementation UIApplication (AutoTrack)

//+(void)load
//{
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        @try {
//            NSError *error = NULL;
//            [UIApplication sa_swizzleMethod:@selector(sendAction:to:from:forEvent:) withMethod:@selector(sa_sendAction:to:from:forEvent:) error:&error];
//            if (error) {
//                DTError(@"Failed to swizzle sendAction: on UIApplication. Details: %@", error);
//                error = NULL;
//            }
//        } @catch (NSException *exception) {
//            DTError(@"%@ error: %@", self, exception);
//        }
//    });
//
//}

- (BOOL)sa_sendAction:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {

//    BOOL ret = YES;
//    BOOL sensorsAnalyticsAutoTrackAfterSendAction = NO;
    [self sa_sendAction:action to:to from:from forEvent:event];
    [self sa_track:action to:to from:from forEvent:event];
    return YES;
}

- (void)sa_track:(SEL)action to:(id)to from:(id)from forEvent:(UIEvent *)event {
    @try {
        
        if (from == nil)
        {
            return;
        }
        if (![DatatistTracker sharedInstance].enableAutoTrack)
        {
            return;
        }
        if ([[DatatistTracker sharedInstance] isViewTypeForbidden:[from class]])
        {
            return;
        }
        if (([event isKindOfClass:[UIEvent class]] && event.type==UIEventTypeTouches) ||
            [from isKindOfClass:[UISwitch class]] ||
            [from isKindOfClass:[UIStepper class]] ||
            [from isKindOfClass:[UISegmentedControl class]]
        ) {//0
            if (![from isKindOfClass:[UIView class]]) {
                return;
            }
            
            UIView* view = (UIView *)from;
            if (!view) {
                return;
            }
            
            NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
            
            UIViewController *viewController = [view viewController];
            
            if (viewController == nil ||
                [@"UINavigationController" isEqualToString:NSStringFromClass([viewController class])] || [@"TabBarController" isEqualToString:NSStringFromClass([viewController class])]) {
                viewController = [AutoTrackUtils currentViewController];
            }
            
            if (viewController != nil) {
//                if (当前ViewController被忽略) {
//                    return;
//                }
                
                //获取 Controller 名称(screen_name)
                NSString *screenName = NSStringFromClass([viewController class]);
                [properties setValue:screenName forKey:@"screen_name"];
                
                NSString *controllerTitle = viewController.navigationItem.title;
                if (controllerTitle != nil) {
                    [properties setValue:viewController.navigationItem.title forKey:@"title"];
                }
                //再获取 controller.navigationItem.titleView, 并且优先级比较高
                NSString *elementContent = [AutoTrackUtils getUIViewControllerTitle:viewController];
                if (elementContent != nil && [elementContent length] > 0) {
                    elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                    [properties setValue:elementContent forKey:@"title"];
                }
            }
            
            //UISwitch
            if ([from isKindOfClass:[UISwitch class]]) {
                if (NSStringFromClass([from class])) {
                    [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                }
                UISwitch *uiSwitch = (UISwitch *)from;
                if (uiSwitch.on) {
                    [properties setValue:@"checked" forKey:@"eContent"];
                } else {
                    [properties setValue:@"unchecked" forKey:@"eContent"];
                }
                
                [AutoTrackUtils sa_addViewPathProperties:properties withObject:uiSwitch withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                DTLog(@"%@",properties);
                [AutoTrackUtils trackClickEvent:properties];
//                [[SensorsAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties];
                return;
            }

            //UIStepper
            if ([from isKindOfClass:[UIStepper class]]) {
                [properties setValue:@"UIStepper" forKey:@"eType"];
                UIStepper *stepper = (UIStepper *)from;
                if (stepper) {
                    [properties setValue:[NSString stringWithFormat:@"%g", stepper.value] forKey:@"eContent"];
                }
                
                [AutoTrackUtils sa_addViewPathProperties:properties withObject:stepper withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                DTLog(@"%@",properties);
                [AutoTrackUtils trackClickEvent:properties];
                return;
            }

           // UISearchBar
//            if ([to isKindOfClass:[UISearchBar class]] && [from isKindOfClass:[[NSClassFromString(@"UISearchBarTextField") class] class]]) {
//                UISearchBar *searchBar = (UISearchBar *)to;
//                if (searchBar != nil) {
//                    [properties setValue:@"UISearchBar" forKey:@"eType"];
//                    NSString *searchText = searchBar.text;
//                    if (searchText == nil || [searchText length] == 0) {
//                        //                                [[SensorsAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties];
//                        return;
//                    }
//                }
//            }
            
            //UISegmentedControl
            if ([from isKindOfClass:[UISegmentedControl class]]) {
                UISegmentedControl *segmented = (UISegmentedControl *)from;
                if (NSStringFromClass([from class])) {
                    [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                }
                
                if ([segmented selectedSegmentIndex] == UISegmentedControlNoSegment) {
                    return;
                }
                
                [properties setValue:[NSString stringWithFormat: @"%ld", (long)[segmented selectedSegmentIndex]] forKey:@"ePosition"];
                [properties setValue:[segmented titleForSegmentAtIndex:[segmented selectedSegmentIndex]] forKey:@"eContent"];
                
                [AutoTrackUtils sa_addViewPathProperties:properties withObject:segmented withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                DTLog(@"%@",properties);
                [AutoTrackUtils trackClickEvent:properties];
                return;
                
            }
            
            //只统计触摸结束时
            if ([event isKindOfClass:[UIEvent class]] && [[[event allTouches] anyObject] phase] == UITouchPhaseEnded) {
                if ([from isKindOfClass:[UIButton class]]) {//UIButton
                    UIButton *button = (UIButton *)from;
                    if (NSStringFromClass([from class])) {
                        [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                    }
                    if (button != nil) {
                        if ([button currentTitle] != nil) {
                            [properties setValue:[button currentTitle] forKey:@"eContent"];
                        } else {
                            if (button.subviews.count > 0) {
                                NSString *elementContent = [[NSString alloc] init];
                                elementContent = [AutoTrackUtils contentFromView:button];
                                if (elementContent != nil && [elementContent length] > 0) {
                                    elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                                    [properties setValue:elementContent forKey:@"eContent"];
                                } else {
//#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME
//                                    UIImage *image = button.currentImage;
//                                    if (image) {
//                                        NSString *imageName = image.sensorsAnalyticsImageName;
//                                        if (imageName != nil) {
//                                            [properties setValue:[NSString stringWithFormat:@"$%@", imageName] forKey:@"eContent"];
//                                        }
//                                    }
//#endif
                                }
                            }
                        }
                    }
                }
                else if ([from isKindOfClass:[NSClassFromString(@"UITabBarButton") class]]) {//UITabBarButton
                    if ([to isKindOfClass:[UITabBar class]]) {//UITabBar
//                        unsigned int methodCount = 0;
//                        Ivar * ivars = class_copyIvarList([from class], &methodCount);
//                        Ivar _label;
                        Ivar ivar = class_getInstanceVariable([from class], "_label");
                        id item = object_getIvar(from, ivar);
                        if ([item isKindOfClass:[UILabel class]])
                        {
                            if (((UILabel *)item).text.length > 0)
                            {
                                [properties setValue:((UILabel *)item).text forKey:@"eContent"];
                            }
                        }
                        if (NSStringFromClass([from class])) {
                            [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                        }
                    }
                }
//#endif
                else if([from isKindOfClass:[UITabBarItem class]]){//For iOS7 TabBar
                    UITabBarItem *tabBarItem = (UITabBarItem *)from;
                    if (tabBarItem) {
                        if (NSStringFromClass([from class])) {
                            [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                        }
                        [properties setValue:tabBarItem.title forKey:@"eContent"];
                    }
                } else if ([from isKindOfClass:[UISlider class]]) {//UISlider
                    UISlider *slide = (UISlider *)from;
                    if (slide != nil) {
                        if (NSStringFromClass([from class])) {
                            [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                        }
                        [properties setValue:[NSString stringWithFormat:@"%f",slide.value] forKey:@"eContent"];
                    }
                } else {
                    if ([from isKindOfClass:[UIControl class]]) {
                        if (NSStringFromClass([from class])) {
                            [properties setValue:NSStringFromClass([from class]) forKey:@"eType"];
                        }
                        UIControl *fromView = (UIControl *)from;
                        if (fromView.subviews.count > 0) {
                            NSString *elementContent = [[NSString alloc] init];
                            elementContent = [AutoTrackUtils contentFromView:fromView];
                            if (elementContent != nil && [elementContent length] > 0) {
                                elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                                [properties setValue:elementContent forKey:@"eContent"];
                            }
                        }
                    }
                }
                
                [AutoTrackUtils sa_addViewPathProperties:properties withObject:view withViewController:viewController];
                
                //View Properties
                NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
                if (propDict != nil) {
                    [properties addEntriesFromDictionary:propDict];
                }
                DTLog(@"%@",properties);
                [AutoTrackUtils trackClickEvent:properties];
            }
        }
    } @catch (NSException *exception) {
//        DTError(@"%@ error: %@", self, exception);
    }
}

@end

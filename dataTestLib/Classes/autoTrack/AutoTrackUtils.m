//
//  AutoTrackUtils.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import "AutoTrackUtils.h"
#import "UIView+AutoStatistic.h"
#import <CommonCrypto/CommonDigest.h>
#import "DatatistTracker.h"
#import "UserAgent.h"
#import "SASwizzler.h"
#import "SASwizzle.h"
#import "UIApplication+AutoTrack.h"
#import "DTLogger.h"
#import <objc/runtime.h>
//#import "UIViewController+autoTrack.h"
//#import "UIView+SAHelpers.h"

@implementation AutoTrackUtils

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

//该方法没有用到
+ (void)sa_find_view_responder:(UIView *)view withViewPathArray:(NSMutableArray *)viewPathArray {
    NSMutableArray *viewVarArray = [[NSMutableArray alloc] init];
//    NSString *varE = [view jjf_varE];
    NSString *varE = @"111111";
    if (varE != nil) {
//        [viewVarArray addObject:[NSString stringWithFormat:@"jjf_varE='%@'", varE]];
    }
    //    NSArray *varD = [view jjf_varSetD];
    //    if (varD != nil && [varD count] > 0) {
    //        [viewVarArray addObject:[NSString stringWithFormat:@"jjf_varSetD='%@'", [varD componentsJoinedByString:@","]]];
    //    }
//    varE = [view jjf_varC];
//    if (varE != nil) {
//        [viewVarArray addObject:[NSString stringWithFormat:@"jjf_varC='%@'", varE]];
//    }
//    varE = [view jjf_varB];
//    if (varE != nil) {
//        [viewVarArray addObject:[NSString stringWithFormat:@"jjf_varB='%@'", varE]];
//    }
//    varE = [view jjf_varA];
//    if (varE != nil) {
//        [viewVarArray addObject:[NSString stringWithFormat:@"jjf_varA='%@'", varE]];
//    }
    if ([viewVarArray count] == 0) {
        long count = 0;
        NSArray<__kindof UIView *> *subviews;
        NSMutableArray<__kindof UIView *> *sameTypeViews = [[NSMutableArray alloc] init];
        id nextResponder = [view nextResponder];
        if (nextResponder) {
            if ([nextResponder respondsToSelector:NSSelectorFromString(@"subviews")]) {
                subviews = [nextResponder subviews];
                if ([view isKindOfClass:[UITableView class]] || [view isKindOfClass:[UICollectionView class]]) {
                    subviews =  [[subviews reverseObjectEnumerator] allObjects];
                }
            }

            for (UIView *v in subviews) {
                if (v) {
                    if ([NSStringFromClass([view class]) isEqualToString:NSStringFromClass([v class])]) {
                        [sameTypeViews addObject:v];
                    }
                }
            }
            count = (unsigned long)subviews.count;
        }
        if (sameTypeViews.count > 1) {
            NSString * className = nil;
            NSUInteger index = [sameTypeViews indexOfObject:view];
            className = [NSString stringWithFormat:@"%@[%lu]", NSStringFromClass([view class]), (unsigned long)index];
            [viewPathArray addObject:className];
        } else {
            [viewPathArray addObject:NSStringFromClass([view class])];
        }
    } else {
        NSString *viewIdentify = [NSString stringWithString:NSStringFromClass([view class])];
        viewIdentify = [viewIdentify stringByAppendingString:@"[("];
        for (int i = 0; i < viewVarArray.count; i++) {
            viewIdentify = [viewIdentify stringByAppendingString:viewVarArray[i]];
            if (i != (viewVarArray.count - 1)) {
                viewIdentify = [viewIdentify stringByAppendingString:@" AND "];
            }
        }
        viewIdentify = [viewIdentify stringByAppendingString:@")]"];
        [viewPathArray addObject:viewIdentify];
    }
}

+ (void)sa_find_responder:(id)responder withViewPathArray:(NSMutableArray *)viewPathArray {

    while (responder!=nil&&![responder isKindOfClass:[UIViewController class]] &&
           ![responder isKindOfClass:[UIWindow class]]) {
        long count = 0;
        NSArray<__kindof UIView *> *subviews;
        id nextResponder = [responder nextResponder];
        if (nextResponder) {
            if ([nextResponder respondsToSelector:NSSelectorFromString(@"subviews")]) {
                subviews = [nextResponder subviews];
                if ([responder isKindOfClass:[UITableView class]] || [responder isKindOfClass:[UICollectionView class]]) {
                    subviews =  [[subviews reverseObjectEnumerator] allObjects];
                }
                if (subviews) {
                    count = (unsigned long)subviews.count;
                }
            }
        }
        if (count <= 1) {
            if (NSStringFromClass([responder class])) {
                [viewPathArray addObject:NSStringFromClass([responder class])];
            }
        } else {
            NSMutableArray<__kindof UIView *> *sameTypeViews = [[NSMutableArray alloc] init];
            for (UIView *v in subviews) {
                if (v) {
                    if ([NSStringFromClass([responder class]) isEqualToString:NSStringFromClass([v class])]) {
                        [sameTypeViews addObject:v];
                    }
                }
            }
            if (sameTypeViews.count > 1) {
                NSString * className = nil;
                NSUInteger index = [sameTypeViews indexOfObject:responder];
                className = [NSString stringWithFormat:@"%@[%lu]", NSStringFromClass([responder class]), (unsigned long)index];
                [viewPathArray addObject:className];
            } else {
                [viewPathArray addObject:NSStringFromClass([responder class])];
            }
        }
        
        responder = [responder nextResponder];
    }
    
    if (responder && [responder isKindOfClass:[UIViewController class]]) {
        while ([responder parentViewController]) {
            UIViewController *viewController = [responder parentViewController];
            if (viewController) {
                NSArray<__kindof UIViewController *> *childViewControllers = [viewController childViewControllers];
                if (childViewControllers > 0) {
                    NSMutableArray<__kindof UIViewController *> *items = [[NSMutableArray alloc] init];
                    for (UIViewController *v in childViewControllers) {
                        if (v) {
                            if ([NSStringFromClass([responder class]) isEqualToString:NSStringFromClass([v class])]) {
                                [items addObject:v];
                            }
                        }
                    }
                    if (items.count > 1) {
                        NSString * className = nil;
                        NSUInteger index = [items indexOfObject:responder];
                        className = [NSString stringWithFormat:@"%@[%lu]", NSStringFromClass([responder class]), (unsigned long)index];
                        [viewPathArray addObject:className];
                    } else {
                        [viewPathArray addObject:NSStringFromClass([responder class])];
                    }
                } else {
                    [viewPathArray addObject:NSStringFromClass([responder class])];
                }
                
                responder = viewController;
            }
        }
        [viewPathArray addObject:NSStringFromClass([responder class])];
    }
}

+ (NSString *)contentFromView:(UIView *)rootView {
    @try {
        NSMutableString *elementContent = [NSMutableString string];
        NSArray *subviews = [rootView subviews];
        if (subviews.count == 0)
        {
            if ([rootView isKindOfClass:[UIButton class]] || [rootView isKindOfClass:[UITextView class]] || [rootView isKindOfClass:[UILabel class]] ) {
                subviews = @[rootView];
            }
        }
        for (UIView *subView in subviews) {
            if (subView) {
//                if (subView.sensorsAnalyticsIgnoreView) {
//                    continue;
//                }

                if (subView.isHidden) {
                    continue;
                }

                if ([subView isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)subView;
                    if ([button currentTitle] != nil && ![@"" isEqualToString:[button currentTitle]]) {
                        [elementContent appendString:[button currentTitle]];
                        [elementContent appendString:@"-"];
                    }
                } else if ([subView isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subView;
                    if (label.text != nil && ![@"" isEqualToString:label.text]) {
                        [elementContent appendString:label.text];
                        [elementContent appendString:@"-"];
                    }
                } else if ([subView isKindOfClass:[UITextView class]]) {
                    UITextView *textView = (UITextView *)subView;
                    if (textView.text != nil && ![@"" isEqualToString:textView.text]) {
                        [elementContent appendString:textView.text];
                        [elementContent appendString:@"-"];
                    }
                } else if ([subView isKindOfClass:NSClassFromString(@"RTLabel")]) {//RTLabel:https://github.com/honcheng/RTLabel
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    if ([subView respondsToSelector:NSSelectorFromString(@"text")]) {
                        NSString *title = [subView performSelector:NSSelectorFromString(@"text")];
                        if (title != nil && ![@"" isEqualToString:title]) {
                            [elementContent appendString:title];
                            [elementContent appendString:@"-"];
                        }
                    }
                    #pragma clang diagnostic pop
                } else if ([subView isKindOfClass:NSClassFromString(@"YYLabel")]) {//RTLabel:https://github.com/ibireme/YYKit
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    if ([subView respondsToSelector:NSSelectorFromString(@"text")]) {
                        NSString *title = [subView performSelector:NSSelectorFromString(@"text")];
                        if (title != nil && ![@"" isEqualToString:title]) {
                            [elementContent appendString:title];
                            [elementContent appendString:@"-"];
                        }
                    }
                    #pragma clang diagnostic pop
                }
                else {
                    NSString *temp = [self contentFromView:subView];
                    if (temp != nil && ![@"" isEqualToString:temp]) {
                        [elementContent appendString:temp];
                    }
                }
            }
        }
        return elementContent;
    } @catch (NSException *exception) {
        DTError(@"%@ error: %@", self, exception);
        return nil;
    }
}

+ (void)trackAppClickWithUICollectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    @try {
//        //关闭 AutoTrack
//        if (![[SensorsAnalyticsSDK sharedInstance] isAutoTrackEnabled]) {
//            return;
//        }
//
//        //忽略 $AppClick 事件
//        if ([[SensorsAnalyticsSDK sharedInstance] isAutoTrackEventTypeIgnored:SensorsAnalyticsEventTypeAppClick]) {
//            return;
//        }
//
//        if ([[SensorsAnalyticsSDK sharedInstance] isViewTypeIgnored:[UICollectionView class]]) {
//            return;
//        }

        if (!collectionView) {
            return;
        }

        UIView *view = (UIView *)collectionView;
        if (!view) {
            return;
        }

        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];

        [properties setValue:@"UICollectionView" forKey:@"eType"];

        UIViewController *viewController = [view viewController];

        if (viewController == nil ||
            [@"UINavigationController" isEqualToString:NSStringFromClass([viewController class])]) {
            viewController = [self currentViewController];
        }

        if (viewController != nil) {
            //获取 Controller 名称(screen_name)
            NSString *screenName = NSStringFromClass([viewController class]);
            [properties setValue:screenName forKey:@"screen_name"];

            NSString *controllerTitle = viewController.navigationItem.title;
            if (controllerTitle != nil) {
                [properties setValue:viewController.navigationItem.title forKey:@"title"];
            }
        }

        if (indexPath) {
            [properties setValue:[NSString stringWithFormat: @"%ld:%ld", (unsigned long)indexPath.section,(unsigned long)indexPath.row] forKey:@"ePosition"];
        }

        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
        if (cell==nil) {
            [collectionView layoutIfNeeded];
            cell = [collectionView cellForItemAtIndexPath:indexPath];
        }
        NSString *cellClass =NSStringFromClass([cell class]);
        NSMutableArray *viewPathArray = [[NSMutableArray alloc] init];
        long section = (unsigned long)indexPath.section;
        int count = 0;
        for (int i = 0; i <= section; i++) {
            NSInteger numberOfItemsInSection = [collectionView numberOfItemsInSection:i];
            if (i == section) {
                numberOfItemsInSection = indexPath.row;
            }
            for (int j = 0; j < numberOfItemsInSection; j++) {
                UICollectionViewCell *cellRow = [collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:j inSection:i]];
                if(cellRow == nil) {
                    [collectionView layoutIfNeeded];
                    cellRow = [collectionView cellForItemAtIndexPath:indexPath];
                }
                if(cellRow == nil) {
                    [collectionView reloadData];
                    [collectionView layoutIfNeeded];
                    cellRow = [collectionView cellForItemAtIndexPath:indexPath];
                }
                if ([cellClass isEqualToString:NSStringFromClass([cellRow class])]) {
                    count++;
                }
            }
        }
        [viewPathArray addObject:[NSString stringWithFormat:@"%@[%d]",NSStringFromClass([cell class]), count]];
        id responder = cell.nextResponder;
        
        NSArray<__kindof UIView *> *subviews = [collectionView.superview subviews];
        NSMutableArray<__kindof UIView *> *viewsArray = [[NSMutableArray alloc] init];
        for (UIView *obj in subviews) {
            if ([NSStringFromClass([responder class]) isEqualToString:NSStringFromClass([obj class])]) {
                [viewsArray addObject:obj];
            }
        }
        
        if ([viewsArray count] == 1) {
            [viewPathArray addObject:NSStringFromClass([responder class])];
        } else {
            NSUInteger index = [viewsArray indexOfObject:collectionView];
            [viewPathArray addObject:[NSString stringWithFormat:@"%@[%lu]", NSStringFromClass([responder class]), (unsigned long)index]];
        }
        
        responder = [responder nextResponder];
        [self sa_find_responder:responder withViewPathArray:viewPathArray];
        
        NSArray *array = [[viewPathArray reverseObjectEnumerator] allObjects];
        
        NSString *viewPath = [[NSString alloc] init];
        for (int i = 0; i < array.count; i++) {
            viewPath = [viewPath stringByAppendingString:array[i]];
            if (i != (array.count - 1)) {
                viewPath = [viewPath stringByAppendingString:@"/"];
            }
        }
        [properties setValue:viewPath forKey:@"ePath"];
        
        NSString *elementContent = [[NSString alloc] init];
        elementContent = [self contentFromView:cell];
        if (elementContent != nil && [elementContent length] > 0) {
            elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
            [properties setValue:elementContent forKey:@"eContent"];
        }

        //View Properties
        NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
        if (propDict != nil) {
            [properties addEntriesFromDictionary:propDict];
        }
        DTLog(@"%@",properties);
        [self trackClickEvent:properties];
    } @catch (NSException *exception) {
        DTError(@"%@", exception);
    }
}

+ (void)trackAppClickWithUITableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    @try {
        //关闭 AutoTrack
//        if (![[SensorsAnalyticsSDK sharedInstance] isAutoTrackEnabled]) {
//            return;
//        }
//
//        //忽略 $AppClick 事件
//        if ([[SensorsAnalyticsSDK sharedInstance] isAutoTrackEventTypeIgnored:SensorsAnalyticsEventTypeAppClick]) {
//            return;
//        }
//
//        if ([[SensorsAnalyticsSDK sharedInstance] isViewTypeIgnored:[UITableView class]]) {
//            return;
//        }

        if (!tableView) {
            return;
        }

        UIView *view = (UIView *)tableView;
        if (!view) {
            return;
        }

        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];

        [properties setValue:@"UITableView" forKey:@"eType"];
       

        UIViewController *viewController = [tableView viewController];

        if (viewController == nil ||
            [@"UINavigationController" isEqualToString:NSStringFromClass([viewController class])]) {
            viewController = [self currentViewController];
        }

        if (viewController != nil) {

            //获取 Controller 名称(screen_name)
            NSString *screenName = NSStringFromClass([viewController class]);
            [properties setValue:screenName forKey:@"screen_name"];

            NSString *controllerTitle = viewController.navigationItem.title;
            if (controllerTitle != nil) {
                [properties setValue:viewController.navigationItem.title forKey:@"title"];
            }

            NSString *elementContent = [self getUIViewControllerTitle:viewController];
            if (elementContent != nil && [elementContent length] > 0) {
                elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
                [properties setValue:elementContent forKey:@"title"];
            }
        }

        if (indexPath) {
            [properties setValue:[NSString stringWithFormat: @"%ld:%ld", (unsigned long)indexPath.section,(unsigned long)indexPath.row] forKey:@"ePosition"];
        }
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell == nil) {
            [tableView layoutIfNeeded];
            cell = [tableView cellForRowAtIndexPath:indexPath];
        }
        NSString *cellClass =NSStringFromClass([cell class]);
        NSString *elementContent = [[NSString alloc] init];

        
        NSMutableArray *viewPathArray = [[NSMutableArray alloc] init];
        long section = (unsigned long)indexPath.section;
        int count = 0;
        for (int i = 0; i <= section; i++) {
            NSInteger numberOfItemsInSection = [tableView numberOfRowsInSection:i];
            if (i == section) {
                numberOfItemsInSection = indexPath.row;
            }
            for (int j = 0; j < numberOfItemsInSection; j++) {
                UITableViewCell *cellRow = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:j inSection:i]];
                if(cellRow == nil) {
                    [tableView layoutIfNeeded];
                    cellRow = [tableView cellForRowAtIndexPath:indexPath];
                }
                if(cellRow == nil) {
                    [tableView reloadData];
                    [tableView layoutIfNeeded];
                    cellRow = [tableView cellForRowAtIndexPath:indexPath];
                }
                if ([cellClass isEqualToString:NSStringFromClass([cellRow class])]) {
                    count++;
                }
            }
        }
        [viewPathArray addObject:[NSString stringWithFormat:@"%@[%d]",NSStringFromClass([cell class]), count]];
        id responder = cell.nextResponder;
        NSArray<__kindof UIView *> *subviews = [tableView.superview subviews];
        NSMutableArray<__kindof UIView *> *viewsArray = [[NSMutableArray alloc] init];
        for (UIView *obj in subviews) {
            if ([NSStringFromClass([responder class]) isEqualToString:NSStringFromClass([obj class])]) {
                [viewsArray addObject:obj];
            }
        }
        if ([viewsArray count] == 1) {
            [viewPathArray addObject:NSStringFromClass([responder class])];
        } else {
            NSUInteger index = [viewsArray indexOfObject:tableView];
            [viewPathArray addObject:[NSString stringWithFormat:@"%@[%lu]", NSStringFromClass([responder class]), (unsigned long)index]];
        }
        responder = [responder nextResponder];
        [self sa_find_responder:responder withViewPathArray:viewPathArray];
        
        NSArray *array = [[viewPathArray reverseObjectEnumerator] allObjects];
        
        NSMutableString *viewPath = [[NSMutableString alloc] init];
        for (int i = 0; i < array.count; i++) {
            [viewPath appendString:array[i]];
            if (i != (array.count - 1)) {
                [viewPath appendString:@"/"];
            }
        }
        NSRange range = [viewPath rangeOfString:@"UITableViewWrapperView/"];
        if (range.length) {
            [viewPath deleteCharactersInRange:range];
        }
        [properties setValue:viewPath forKey:@"ePath"];

        elementContent = [self contentFromView:cell];
        if (elementContent != nil && [elementContent length] > 0) {
            elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
            [properties setValue:elementContent forKey:@"eContent"];
        }

        //View Properties
        NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
        if (propDict != nil) {
            [properties addEntriesFromDictionary:propDict];
        }
        DTLog(@"%@",properties);
        [self trackClickEvent:properties];
    } @catch (NSException *exception) {
        DTError(@"%@", exception);
    }
}

+ (void)sa_addViewPathProperties:(NSMutableDictionary *)properties withObject:(UIView *)view withViewController:(UIViewController *)viewController {
    @try {

        NSMutableArray *viewPathArray = [[NSMutableArray alloc] init];

//        [self sa_find_view_responder:view withViewPathArray:viewPathArray];
//        id responder = view.nextResponder;
        id responder = view;
        [self sa_find_responder:responder withViewPathArray:viewPathArray];
        
        NSArray *array = [[viewPathArray reverseObjectEnumerator] allObjects];
        
        NSString *viewPath = [[NSString alloc] init];
        for (int i = 0; i < array.count; i++) {
            viewPath = [viewPath stringByAppendingString:array[i]];
            if (i != (array.count - 1)) {
                viewPath = [viewPath stringByAppendingString:@"/"];
            }
        }
        [properties setValue:viewPath forKey:@"ePath"];
    } @catch (NSException *exception) {
        DTError(@"%@ error: %@", self, exception);
    }
}

+ (UIViewController *)currentViewController {
    __block UIViewController *currentVC = nil;
    if ([NSThread isMainThread]) {
        @try {
            UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
            if (rootViewController != nil) {
                currentVC = [self getCurrentVCFrom:rootViewController];
            }
        } @catch (NSException *exception) {
            DTError(@"%@ error: %@", self, exception);
        }
        return currentVC;
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            @try {
                UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
                if (rootViewController != nil) {
                    currentVC = [self getCurrentVCFrom:rootViewController];
                }
            } @catch (NSException *exception) {
                DTError(@"%@ error: %@", self, exception);
            }
        });
        return currentVC;
    }
}

+ (UIViewController *)getCurrentVCFrom:(UIViewController *)rootVC {
    @try {
        UIViewController *currentVC;
        if ([rootVC presentedViewController]) {
            // 视图是被presented出来的
            rootVC = [self getCurrentVCFrom:rootVC.presentedViewController];
        }
        
        if ([rootVC isKindOfClass:[UITabBarController class]]) {
            // 根视图为UITabBarController
            currentVC = [self getCurrentVCFrom:[(UITabBarController *)rootVC selectedViewController]];
        } else if ([rootVC isKindOfClass:[UINavigationController class]]){
            // 根视图为UINavigationController
            currentVC = [self getCurrentVCFrom:[(UINavigationController *)rootVC visibleViewController]];
        } else {
            // 根视图为非导航类
            if ([rootVC respondsToSelector:NSSelectorFromString(@"contentViewController")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                UIViewController *tempViewController = [rootVC performSelector:NSSelectorFromString(@"contentViewController")];
#pragma clang diagnostic pop
                if (tempViewController) {
                    currentVC = [self getCurrentVCFrom:tempViewController];
                }
            } else {
                currentVC = rootVC;
            }
        }
        
        return currentVC;
    } @catch (NSException *exception) {
        DTError(@"%@ error: %@", self, exception);
    }
}

+ (NSString *)getUIViewControllerTitle:(UIViewController *)controller {
    @try {
        if (controller == nil) {
            return nil;
        }
        
        UIView *titleView = controller.navigationItem.titleView;
        if (titleView != nil) {
            return [AutoTrackUtils contentFromView:titleView];
        }
    } @catch (NSException *exception) {
        DTError(@"%@: %@", self, exception);
    }
    return nil;
}

+ (void)trackClickEvent:(NSDictionary *)eventMessage
{
    @try{
        if (eventMessage && [eventMessage isKindOfClass:[NSDictionary class]])
        {
            NSString *url = [NSString stringWithFormat:@"http://%@/%@",[UserAgent sharedInstance].appName, eventMessage[@"screen_name"]];
            
            NSMutableDictionary *eventBody = [NSMutableDictionary new];
            if (eventMessage[@"eType"] && [eventMessage[@"eType"] isKindOfClass:[NSString class]]) {
                eventBody[@"eType"] = eventMessage[@"eType"];
            }
            if (eventMessage[@"ePath"] && [eventMessage[@"ePath"] isKindOfClass:[NSString class]]) {
                eventBody[@"ePath"] = eventMessage[@"ePath"];
            }
            if (eventMessage[@"ePosition"] && [eventMessage[@"ePosition"] isKindOfClass:[NSString class]])
            {
                eventBody[@"ePosition"] = eventMessage[@"ePosition"];
            }
            if (eventMessage[@"eContent"] && [eventMessage[@"eContent"] isKindOfClass:[NSString class]]) {
                eventBody[@"eContent"] = eventMessage[@"eContent"];
            }
            
            NSString *md5_id =  [UserAgent md5:[NSString stringWithFormat:@"datatist%@%@",url,eventMessage[@"ePath"]]];
            if (md5_id.length > 16) {
                md5_id = [md5_id substringWithRange:NSMakeRange(0, 16)];
                eventBody[@"id"] = md5_id;
            }
            NSMutableDictionary *param = [NSMutableDictionary new];
            
            if (url.length != 0)
            {
                param[@"url"] = url;
            }
            if (eventMessage[@"title"] && [eventMessage[@"title"] isKindOfClass:[NSString class]]) {
                param[@"title"] = eventMessage[@"title"];
            }
            if (eventBody && [eventBody isKindOfClass:[NSDictionary class]]) {
                param[@"eventBody"] = eventBody;
            }
            param[@"eventName"] = @"click";
            [DatatistTracker.sharedInstance trackClick: param];
        }
        
    }@catch(NSException *exception){
        
        DTError(@"%@",exception.description);
    }
}

+ (void)enableAutoTrack {
    NSLog(@"enableAutoTrack");
//    void (^unswizzleUITableViewAppClickBlock)(id, SEL, id) = ^(id obj, SEL sel, NSNumber* a) {
//        UIViewController *controller = (UIViewController *)obj;
//        if (!controller) {
//            return;
//        }
//
//        Class klass = [controller class];
//        if (!klass) {
//            return;
//        }
//
//        NSString *screenName = NSStringFromClass(klass);
//
//        //UITableView
//#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UITABLEVIEW
//        if ([controller respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
//            [SASwizzler unswizzleSelector:@selector(tableView:didSelectRowAtIndexPath:) onClass:klass named:[NSString stringWithFormat:@"%@_%@", screenName, @"UITableView_AutoTrack"]];
//        }
//#endif
//
//        //UICollectionView
//#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UICOLLECTIONVIEW
//        if ([controller respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
//            [SASwizzler unswizzleSelector:@selector(collectionView:didSelectItemAtIndexPath:) onClass:klass named:[NSString stringWithFormat:@"%@_%@", screenName, @"UICollectionView_AutoTrack"]];
//        }
//#endif
//    };
    
    void (^gestureRecognizerAppClickBlock)(id, SEL, id) = ^(id target, SEL command, id arg) {
        @try {
            if ([arg isKindOfClass:[UITapGestureRecognizer class]] ||
                [arg isKindOfClass:[UILongPressGestureRecognizer class]]) {
                [arg addTarget:self action:@selector(trackGestureRecognizerAppClick:)];
            }
        } @catch (NSException *exception) {
            DTError(@"%@ error: %@", self, exception);
        }
    };
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //$AppViewScreen
//        [UIViewController sa_swizzleMethod:@selector(viewWillAppear:) withMethod:@selector(sa_autotrack_viewWillAppear:) error:NULL];
        NSError *error = NULL;
//        $AppClick
//         Actions & Events
        [UIApplication sa_swizzleMethod:@selector(sendAction:to:from:forEvent:)
                                     withMethod:@selector(sa_sendAction:to:from:forEvent:)
                                          error:&error];
        if (error) {
            DTError(@"Failed to swizzle sendAction:to:forEvent: on UIAppplication. Details: %@", error);
            error = NULL;
        }
    });
    //UILabel
    [SASwizzler swizzleSelector:@selector(addGestureRecognizer:) onClass:[UILabel class] withBlock:gestureRecognizerAppClickBlock named:@"track_UILabel_addGestureRecognizer"];
    
    //UIImageView
    [SASwizzler swizzleSelector:@selector(addGestureRecognizer:) onClass:[UIImageView class] withBlock:gestureRecognizerAppClickBlock named:@"track_UIImageView_addGestureRecognizer"];
    //UIAlertController & UIActionSheet
    //iOS9
    [SASwizzler swizzleSelector:@selector(addGestureRecognizer:) onClass:NSClassFromString(@"_UIAlertControllerView") withBlock:gestureRecognizerAppClickBlock named:@"track__UIAlertControllerView_addGestureRecognizer"];
    //iOS10
    [SASwizzler swizzleSelector:@selector(addGestureRecognizer:) onClass:NSClassFromString(@"_UIAlertControllerInterfaceActionGroupView") withBlock:gestureRecognizerAppClickBlock named:@"track__UIAlertControllerInterfaceActionGroupView_addGestureRecognizer"];
}

+ (void)trackGestureRecognizerAppClick:(id)target {
    @try {
        NSLog(@"GestureRecognizer");
        if (target == nil) {
            return;
        }
        UIGestureRecognizer *gesture = target;
        if (gesture == nil) {
            return;
        }
        
        if (gesture.state != UIGestureRecognizerStateEnded) {
            return;
        }
        
        UIView *view = gesture.view;
        if (view == nil) {
            return;
        }
        //关闭 AutoTrack
        if (![DatatistTracker sharedInstance].enableAutoTrack) {
            return;
        }
        
        if ([view isKindOfClass:[UILabel class]]) {//UILabel
            
            if ([[DatatistTracker sharedInstance] isViewTypeForbidden:[UILabel class]])
            {
                return;
            }
            
        } else if ([view isKindOfClass:[UIImageView class]]) {//UIImageView

            if ([[DatatistTracker sharedInstance] isViewTypeForbidden:[UIImageView class]])
            {
                return;
            }
        }
        else if ([view isKindOfClass:NSClassFromString(@"_UIAlertControllerView")] ||
                 [view isKindOfClass:NSClassFromString(@"_UIAlertControllerInterfaceActionGroupView")]){
            
            if ([[DatatistTracker sharedInstance] isViewTypeForbidden:[UIAlertController class]])
            {
                return;
            }
        }
        
        
        UIViewController *viewController = [AutoTrackUtils currentViewController];
        NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
        
        if (viewController != nil) {
//            if ([[SensorsAnalyticsSDK sharedInstance] isViewControllerIgnored:viewController]) {
//                return;
//            }
            
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
        
        if ([view isKindOfClass:[UILabel class]]) {
            [properties setValue:@"UILabel" forKey:@"eType"];
            UILabel *label = (UILabel*)view;
            [properties setValue:label.text forKey:@"eContent"];
            [AutoTrackUtils sa_addViewPathProperties:properties withObject:view withViewController:viewController];
        } else if ([view isKindOfClass:[UIImageView class]]) {
            [properties setValue:@"UIImageView" forKey:@"eType"];
#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UIIMAGE_IMAGENAME
            UIImageView *imageView = (UIImageView *)view;
            [AutoTrackUtils sa_addViewPathProperties:properties withObject:view withViewController:viewController];
            if (imageView) {
//                if (imageView.image) {
//                    NSString *imageName = imageView.image.sensorsAnalyticsImageName;
//                    if (imageName != nil) {
//                        [properties setValue:[NSString stringWithFormat:@"$%@", imageName] forKey:@"eContent"];
//                    }
//                }
            }
#endif
        }
//#if (defined SENSORS_ANALYTICS_ENABLE_NO_PUBLICK_APIS)
        else if ([NSStringFromClass([view class]) isEqualToString:@"_UIAlertControllerView"]) {//iOS9
            BOOL isOK = NO;
            [properties setObject:[NSString stringWithFormat:@"%@/UIAlertController",NSStringFromClass([viewController class])] forKey:@"ePath"];
            Ivar ivar = class_getInstanceVariable([view class], "_actionViews");
            NSMutableArray *actionviews =  object_getIvar(view, ivar);
            for (UIView *actionview in actionviews) {
                CGPoint point = [gesture locationInView:actionview];
                if ([NSStringFromClass([actionview class]) isEqualToString:@"_UIAlertControllerActionView"] &&
                    point.x > 0 && point.x < CGRectGetWidth(actionview.bounds) &&
                    point.y > 0 && point.y < CGRectGetHeight(actionview.bounds) &&
                    gesture.state == UIGestureRecognizerStateEnded) {
                    UILabel *titleLabel = [actionview performSelector:@selector(titleLabel)];
                    if (titleLabel) {
                        isOK = YES;
                        [properties setValue:@"UIAlertController" forKey:@"eType"];
                        [properties setValue:titleLabel.text forKey:@"eContent"];
                    }
                }
            }
            if (!isOK) {
                return;
            }
        } else if ([NSStringFromClass([view class]) isEqualToString:@"_UIAlertControllerInterfaceActionGroupView"]) {//iOS10
            BOOL isOK = NO;
            [properties setObject:[NSString stringWithFormat:@"%@/UIAlertController",NSStringFromClass([viewController class])] forKey:@"ePath"];
            NSMutableArray *targets = [gesture valueForKey:@"_targets"];
            id targetContainer = targets[0];
            id targetOfGesture = [targetContainer valueForKey:@"_target"];
            if ([targetOfGesture isKindOfClass:[NSClassFromString(@"UIInterfaceActionSelectionTrackingController") class]]) {
                Ivar ivar = class_getInstanceVariable([targetOfGesture class], "_representationViews");
                NSMutableArray *representationViews =  object_getIvar(targetOfGesture, ivar);
                for (UIView *representationView in representationViews) {
                    CGPoint point = [gesture locationInView:representationView];
                    if ([NSStringFromClass([representationView class]) isEqualToString:@"_UIInterfaceActionCustomViewRepresentationView"] &&
                        point.x > 0 && point.x < CGRectGetWidth(representationView.bounds) &&
                        point.y > 0 && point.y < CGRectGetHeight(representationView.bounds) &&
                        gesture.state == UIGestureRecognizerStateEnded) {
                        isOK = YES;
                        if ([representationView respondsToSelector:NSSelectorFromString(@"action")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            NSObject *action = [representationView performSelector:NSSelectorFromString(@"action")];
                            if (action) {
                                if ([action respondsToSelector:NSSelectorFromString(@"title")]) {
                                    NSString *title = [action performSelector:NSSelectorFromString(@"title")];
                                    if (title) {
                                        isOK = YES;
                                        [properties setValue:@"UIAlertController" forKey:@"eType"];
                                        [properties setValue:title forKey:@"eContent"];
                                    }
                                }
                            }
#pragma clang diagnostic pop
                        }
                    }
                }
            }
            if (!isOK) {
                return;
            }
        }
//#endif
        else {
            return;
        }
        
        //View Properties
        NSDictionary* propDict = view.sensorsAnalyticsViewProperties;
        if (propDict != nil) {
            [properties addEntriesFromDictionary:propDict];
        }
        DTLog(@"%@",properties);
        [self trackClickEvent:properties];
//        [[SensorsAnalyticsSDK sharedInstance] track:@"$AppClick" withProperties:properties];
    } @catch (NSException *exception) {
        DTError(@"%@ error: %@", self, exception);
    }
}

//+ (void)trackViewScreen:(UIViewController *)controller {
//    if (!controller) {
//        return;
//    }
//
//    Class klass = [controller class];
//    if (!klass) {
//        return;
//    }
//
//    NSString *screenName = NSStringFromClass(klass);
//    //    if (![self shouldTrackClass:klass]) {
//    //        return;
//    //    }
//
//    if ([controller isKindOfClass:NSClassFromString(@"UINavigationController")] ||
//        [controller isKindOfClass:NSClassFromString(@"UITabBarController")]) {
//        return;
//    }
//
//    //过滤用户设置的不被AutoTrack的Controllers
//    //    if (_ignoredViewControllers != nil && _ignoredViewControllers.count > 0) {
//    //        if ([_ignoredViewControllers containsObject:screenName]) {
//    //            return;
//    //        }
//    //    }
//
//    if (1) {
//        //UITableView
//#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UITABLEVIEW
//        void (^tableViewBlock)(id, SEL, id, id) = ^(id view, SEL command, UITableView *tableView, NSIndexPath *indexPath) {
//            [AutoTrackUtils trackAppClickWithUITableView:tableView didSelectRowAtIndexPath:indexPath];
//        };
//        if ([controller respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
//            [SASwizzler swizzleSelector:@selector(tableView:didSelectRowAtIndexPath:) onClass:klass withBlock:tableViewBlock named:[NSString stringWithFormat:@"%@_%@", screenName, @"UITableView_AutoTrack"]];
//        }
//#endif
//
//        //UICollectionView
//#ifndef SENSORS_ANALYTICS_DISABLE_AUTOTRACK_UICOLLECTIONVIEW
//        void (^collectionViewBlock)(id, SEL, id, id) = ^(id view, SEL command, UICollectionView *collectionView, NSIndexPath *indexPath) {
//            [AutoTrackUtils trackAppClickWithUICollectionView:collectionView didSelectItemAtIndexPath:indexPath];
//        };
//        if ([controller respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
//            [SASwizzler swizzleSelector:@selector(collectionView:didSelectItemAtIndexPath:) onClass:klass withBlock:collectionViewBlock named:[NSString stringWithFormat:@"%@_%@", screenName, @"UICollectionView_AutoTrack"]];
//        }
//#endif
//    }
//
//    //    if ([self isAutoTrackEventTypeIgnored:SensorsAnalyticsEventTypeAppViewScreen]) {
//    //        return;
//    //    }
//    //
//    //    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
//    //    [properties setValue:NSStringFromClass(klass) forKey:SCREEN_NAME_PROPERTY];
//    //
//    //    @try {
//    //        //先获取 controller.navigationItem.title
//    //        NSString *controllerTitle = controller.navigationItem.title;
//    //        if (controllerTitle != nil) {
//    //            [properties setValue:controllerTitle forKey:@"$title"];
//    //        }
//    //
//    //        //再获取 controller.navigationItem.titleView, 并且优先级比较高
//    //        NSString *elementContent = [self getUIViewControllerTitle:controller];
//    //        if (elementContent != nil && [elementContent length] > 0) {
//    //            elementContent = [elementContent substringWithRange:NSMakeRange(0,[elementContent length] - 1)];
//    //            [properties setValue:elementContent forKey:@"$title"];
//    //        }
//    //    } @catch (NSException *exception) {
//    //        SAError(@"%@ failed to get UIViewController's title error: %@", self, exception);
//    //    }
//    //
//    //    if ([controller conformsToProtocol:@protocol(SAAutoTracker)]) {
//    //        UIViewController<SAAutoTracker> *autoTrackerController = (UIViewController<SAAutoTracker> *)controller;
//    //        [properties addEntriesFromDictionary:[autoTrackerController getTrackProperties]];
//    //        _lastScreenTrackProperties = [autoTrackerController getTrackProperties];
//    //    }
//    //
//    //#ifdef SENSORS_ANALYTICS_AUTOTRACT_APPVIEWSCREEN_URL
//    //    [properties setValue:screenName forKey:SCREEN_URL_PROPERTY];
//    //    @synchronized(_referrerScreenUrl) {
//    //        if (_referrerScreenUrl) {
//    //            [properties setValue:_referrerScreenUrl forKey:SCREEN_REFERRER_URL_PROPERTY];
//    //        }
//    //        _referrerScreenUrl = screenName;
//    //    }
//    //#endif
//    //
//    //    if ([controller conformsToProtocol:@protocol(SAScreenAutoTracker)]) {
//    //        UIViewController<SAScreenAutoTracker> *screenAutoTrackerController = (UIViewController<SAScreenAutoTracker> *)controller;
//    //        NSString *currentScreenUrl = [screenAutoTrackerController getScreenUrl];
//    //
//    //        [properties setValue:currentScreenUrl forKey:SCREEN_URL_PROPERTY];
//    //        @synchronized(_referrerScreenUrl) {
//    //            if (_referrerScreenUrl) {
//    //                [properties setValue:_referrerScreenUrl forKey:SCREEN_REFERRER_URL_PROPERTY];
//    //            }
//    //            _referrerScreenUrl = currentScreenUrl;
//    //        }
//    //    }
//
//    //    [self track:APP_VIEW_SCREEN_EVENT withProperties:properties];
//}
//

@end


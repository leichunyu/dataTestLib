//
//
//  UITableView+SensorsAnalytics.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import "UITableView+AutoTrack.h"
#import "DatatistTracker.h"
#import "DTLogger.h"
#import "SASwizzle.h"
#import "AutoTrackUtils.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation UITableView (AutoTrack)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSError *error = NULL;
            [[self class] sa_swizzleMethod:@selector(setDelegate:)
                                withMethod:@selector(sa_tableViewSetDelegate:)
                                     error:&error];
            if (error) {
                DTError(@"Failed to swizzle setDelegate: on UITableView. Details: %@", error);
                error = NULL;
            }
        } @catch (NSException *exception) {
            DTError(@"%@ error: %@", self, exception);
        }
    });
}

void sa_tableViewDidSelectRowAtIndexPath(id self, SEL _cmd, id tableView, NSIndexPath* indexPath) {
    SEL selector = NSSelectorFromString(@"sa_tableViewDidSelectRowAtIndexPath");
    ((void(*)(id, SEL, id, id))objc_msgSend)(self, selector, tableView, indexPath);
    
    //插入埋点
    [AutoTrackUtils trackAppClickWithUITableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)sa_tableViewSetDelegate:(id<UITableViewDelegate>)delegate {
    [self sa_tableViewSetDelegate:delegate];
    if (![DatatistTracker sharedInstance].enableAutoTrack){
        return;
    }
    if ([[DatatistTracker sharedInstance] isViewTypeForbidden:[UITableView class]])
    {
        return;
    }
    @try {
        Class class = [delegate class];
        //        static dispatch_once_t onceToken;
        //        dispatch_once(&onceToken, ^{
        if (class_addMethod(class, NSSelectorFromString(@"sa_tableViewDidSelectRowAtIndexPath"), (IMP)sa_tableViewDidSelectRowAtIndexPath, "v@:@@")) {
            Method dis_originMethod = class_getInstanceMethod(class, NSSelectorFromString(@"sa_tableViewDidSelectRowAtIndexPath"));
            Method dis_swizzledMethod = class_getInstanceMethod(class, @selector(tableView:didSelectRowAtIndexPath:));
            method_exchangeImplementations(dis_originMethod, dis_swizzledMethod);
        }
        //        });
    } @catch (NSException *exception) {
        DTError(@"%@ error: %@", self, exception);
    }
}

@end

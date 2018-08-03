//
//  UIViewController+autoTrack.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/6/20.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import "UIViewController+autoTrack.h"
#import "SASwizzle.h"
#import "DatatistTracker.h"
#import "CustomType.h"

@implementation UIViewController (autoTrack)

//+(void)load
//{
//        static dispatch_once_t onceToken;
//        dispatch_once(&onceToken, ^{
//            @try {
//                NSError *error = NULL;
//                [[self class] sa_swizzleMethod:@selector(v:)
//                                    withMethod:@selector(sa_autotrack_viewWillAppear:)
//                                         error:&error];
//                if (error) {
////                    DTError(@"Failed to swizzle setDelegate: on UIAlertView. Details: %@", error);
//                    error = NULL;
//                }
//            } @catch (NSException *exception) {
////                DTError(@"%@ error: %@", self, exception);
//            }
//        });
//}
-(void)sa_autotrack_viewDidAppear:(BOOL)animated
{
    [self sa_autotrack_viewDidAppear:animated];
    NSLog(@"sa_autotrack_viewDidAppear");

    NSString *title = self.title;
    
    if (!title && self.navigationItem.titleView) {
        if ([self.navigationItem.titleView isKindOfClass: [UILabel class]]) {
            title = ((UILabel *)self.navigationItem.titleView).text;
        } else {
            for (UIView *lbTitle in self.navigationItem.titleView.subviews) {
                if ([lbTitle isKindOfClass: [UILabel class]]) {
                    title = ((UILabel *)lbTitle).text;
                    
                    break;
                }
            }
        }
    }
    
    NSString *controllerClassName = NSStringFromClass([self class]);
    BOOL isPermittedController = [[DatatistTracker sharedInstance] permittedController: controllerClassName];
    
    if (isPermittedController) {
        BOOL isWebViewController = [[DatatistTracker sharedInstance] hasWebView: self.view];
        
        if (!isWebViewController)
        {
            if (!title) {
                title = @"";
            }
            [[DatatistTracker sharedInstance] trackPageView:controllerClassName title:title udVariable:nil];
            DatatistLog(@"autoViewController %@ %@", controllerClassName, title);
        }
    }
}

@end

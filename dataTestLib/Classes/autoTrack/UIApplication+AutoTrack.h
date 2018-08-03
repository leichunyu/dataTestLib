//
//  UIApplication+AutoTrack.h
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface UIApplication (AutoTrack)

- (BOOL)sa_sendAction:(SEL)action
                   to:(nullable id)to
                 from:(nullable id)from
             forEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END

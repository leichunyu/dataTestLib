//
//  UIGestureRecognizer+AutoStatistic.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//
#import <UIKit/UIKit.h>
#ifndef __DataTistTrackerSDK__DTLogger__
#define __DataTistTrackerSDK__DTLogger__

#define DTLogLevel(lvl,fmt,...)\
[DTLogger log : YES                                      \
level : lvl                                                  \
file : __FILE__                                            \
function : __PRETTY_FUNCTION__                       \
line : __LINE__                                           \
format : (fmt), ## __VA_ARGS__]

#define DTLog(fmt,...)\
DTLogLevel(DTLoggerLevelInfo,(fmt), ## __VA_ARGS__)

#define DTError DTLog
#define DTDebug DTLog

#endif/* defined(__DataTistTrackerSDK__DTLogger__) */
typedef NS_ENUM(NSUInteger,DTLoggerLevel){
    DTLoggerLevelInfo = 1,
    DTLoggerLevelWarning ,
    DTLoggerLevelError ,
};

@interface DTLogger:NSObject
@property(class , readonly, strong) DTLogger *sharedInstance;
+ (BOOL)isLoggerEnabled;
+ (void)enableLog:(BOOL)enableLog;
+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... ;
@end

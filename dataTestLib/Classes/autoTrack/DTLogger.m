//
//  DTLogger.m
//  AutoStatistic
//
//  Created by IOS01 on 2018/5/29.
//  Copyright © 2018年 IOS01. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "DTLogger.h"
#import "DatatistTracker.h"
static BOOL __enableLog__ ;
static dispatch_queue_t __logQueue__ ;
@implementation DTLogger
+ (void)initialize {
    __enableLog__ = NO;
    __logQueue__ = dispatch_queue_create("com.datatist.analytics.log", DISPATCH_QUEUE_SERIAL);
}

+ (BOOL)isLoggerEnabled {
    __block BOOL enable = NO;
    dispatch_sync(__logQueue__, ^{
        enable = __enableLog__;
    });
    return enable;
}

+ (void)enableLog:(BOOL)enableLog {
    dispatch_sync(__logQueue__, ^{
        __enableLog__ = enableLog;
    });
}

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {
    @try{
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:message level:level file:file function:function line:line];
        va_end(args);
    } @catch(NSException *e){
       
    }
}

- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line {
    @try{
        NSString *logMessage = [[NSString alloc]initWithFormat:@"[DTLog][%@]  %s [line %lu]    %s %@",[self descriptionForLevel:level],function,(unsigned long)line,[@"" UTF8String],message];
        if ([DatatistTracker sharedInstance].showLog) {
            NSLog(@"%@",logMessage);
        }
    } @catch(NSException *e){
       
    }
}

-(NSString *)descriptionForLevel:(DTLoggerLevel)level {
    NSString *desc = nil;
    switch (level) {
        case DTLoggerLevelInfo:
            desc = @"INFO";
            break;
        case DTLoggerLevelWarning:
            desc = @"WARN";
            break;
        case DTLoggerLevelError:
            desc = @"ERROR";
            break;
        default:
            desc = @"UNKNOW";
            break;
    }
    return desc;
}

- (void)dealloc {
    
}

@end

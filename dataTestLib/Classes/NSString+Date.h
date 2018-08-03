//
//  NSString+Date.h
//  DatatistTracker
//
//  Created by zhangjipeng on 9/10/16.
//  Copyright (c) 2016 Datatist. All rights reserved.
//

#define kDateFormat @"yyyy-MM-dd HH:mm:ss"

#define kDateFormatShort @"yyyy-MM-dd"

#import <Foundation/Foundation.h>

@interface NSString (Date)

+ (NSDate *)dateFromString:(NSString *)string ForDateFormatter:(NSString *)formatterString;
+ (NSString *)stringFromDate:(NSDate *)date ForDateFormatter:(NSString *)formatterString;

@end

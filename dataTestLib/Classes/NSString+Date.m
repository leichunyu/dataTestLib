//
//  NSString+Date.m
//  DatatistTracker
//
//  Created by zhangjipeng on 9/10/16.
//  Copyright (c) 2016 Datatist. All rights reserved.
//

#import "NSString+Date.h"

@implementation NSString (Date)

+ (NSDate *)dateFromString:(NSString *)string ForDateFormatter:(NSString *)formatterString {
    NSString *formatter = formatterString;
    if (!formatter) {
        formatter = kDateFormat;
    }
    
    static NSDateFormatter *dateFormatter;
    if (!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    }

    [dateFormatter setDateFormat:formatter];
    return [dateFormatter dateFromString:string];
}

+ (NSString *)stringFromDate:(NSDate *)date ForDateFormatter:(NSString *)formatterString {
    NSString *formatter = formatterString;
    if (!formatter) {
        formatter = kDateFormat;
    }

    static NSDateFormatter *dateFormatter;
    if (!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    }
    
    [dateFormatter setDateFormat:formatter];
    return [dateFormatter stringFromDate:date];
}

@end

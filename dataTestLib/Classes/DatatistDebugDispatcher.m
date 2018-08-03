//
//  DatatistDebugDispatcher.m
//  DatatistTracker
//
//  Created by Mattias Levin on 29/08/14.
//  Copyright (c) 2014 Mattias Levin. All rights reserved.
//

#import "DatatistDebugDispatcher.h"
#import "CustomType.h"


@implementation DatatistDebugDispatcher

- (void)setUserAgent:(NSString *)userAgent {
    DatatistDebugLog(@"Set custom user agent: \n%@", userAgent);
}

- (void)sendSingleEventWithParameters:(NSDictionary*)parameters
                              success:(void (^)(void))successBlock
                              failure:(void (^)(BOOL shouldContinue))failureBlock {
    
    //NSLog(@"Dispatch single event with debug dispatcher");
    
    DatatistDebugLog(@"Request: \n%@", parameters);
    
    successBlock();
    
}


- (void)sendBulkEventWithParameters:(NSDictionary*)parameters
                            success:(void (^)(void))successBlock
                            failure:(void (^)(BOOL shouldContinue))failureBlock {
    
    //NSLog(@"Dispatch batch events with debug dispatcher");
    
    DatatistDebugLog(@"Request: \n%@", parameters);
    
    successBlock();
    
}


@end

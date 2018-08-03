//
//  UserAgent.h
//  DatatistTracker
//
//  Created by 张继鹏 on 08/10/2016.
//  Copyright © 2016 YunfengQi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserAgent : NSObject

/**
 The application name.
 
 The application name will be sent as a custom variable (index 2). By default the application name stored in CFBundleDisplayName will be used.
 */
@property (nonatomic, strong) NSString *appName;

/**
 The application version.
 
 The application version will be sent as a custom variable (index 3). By default the application version stored in CFBundleVersion will be used.
 */
@property (nonatomic, strong) NSString *appVersion;

@property (nonatomic, strong) NSString *osVersion;

@property (nonatomic, strong) NSString *build;

@property (nonatomic, strong) NSString *platformName;

@property (nonatomic, strong) NSString *networkType;

@property (nonatomic, readonly, strong) NSString *values;

- (id)getTargetGroupId:(NSDictionary *)info;

- (NSString *)getUUIDFromKeychain;

+ (instancetype)sharedInstance;

+ (NSString*)md5:(NSString*)input;

- (UInt64)sn;

@end

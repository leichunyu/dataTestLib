//
//  UserAgent.m
//  DatatistTracker
//
//  Created by 张继鹏 on 08/10/2016.
//  Copyright © 2016 YunfengQi. All rights reserved.
//

#import "UserAgent.h"
#import "DTReachability.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "CustomType.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <CommonCrypto/CommonDigest.h>

@implementation UserAgent

+ (instancetype)sharedInstance {
    static UserAgent *ua = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ua = [UserAgent new];
    });
    return ua;
}

- (NSString *)values {
    return [NSString stringWithFormat:@"%@/%@ (%@; iOS %@)", self.appName, self.appVersion, self.platformName, self.osVersion];
}

- (NSString *)appName {
    if (!_appName) {
        // Use the CFBundleDispayName and CFBundleName as default
        _appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleDisplayName"];
        if (!_appName) {
            _appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
        }
    }
    
    return _appName;
}

- (NSString *)appVersion {
    if (!_appVersion) {
        // Use the CFBundleVersion as default
        _appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    }
    
    return _appVersion;
}

#pragma mark - Help methods
- (NSString *)platform {
    
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size * sizeof(char));
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    
    return platform;
}

- (NSString *)osVersion {
#if TARGET_OS_IPHONE
    return [NSString stringWithFormat:@"%@", [UIDevice currentDevice].systemVersion];
#else
    return [NSString stringWithFormat:@"%@", [NSProcessInfo processInfo].operatingSystemVersionString];
#endif
}

- (NSString *)platformName  {
    if (!_platformName) {
        _platformName = [self platformValue];
    }
    
    return _platformName;
}

#pragma mark - Help methods
- (UInt64)sn {
    NSNumber *snNumber = [[NSUserDefaults standardUserDefaults] objectForKey:@"DatatistEventSN"];
    if (!snNumber) {
        [[NSUserDefaults standardUserDefaults] setObject:@1 forKey:@"DatatistEventSN"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return 1;
    } else {
        if (snNumber.unsignedLongLongValue == UINT64_MAX) {
            [[NSUserDefaults standardUserDefaults] setObject:@1 forKey:@"DatatistEventSN"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            return UINT64_MAX;
        } else {
            UInt64 next = snNumber.unsignedLongLongValue + 1;
            [[NSUserDefaults standardUserDefaults] setObject:@(next) forKey:@"DatatistEventSN"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            return next;
        }
    }
}

+ (NSString*)md5:(NSString*)input {
    const char* str = [input UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    
    NSMutableString *hexString = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hexString appendFormat:@"%02x", result[i]];
    }
    
    return hexString;
}

+ (NSString*)UUIDString {
    CFUUIDRef UUID = CFUUIDCreate(kCFAllocatorDefault);
    NSString *UUIDString = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, UUID);
    CFRelease(UUID); // Need to release the UUID, the UUIDString ownership is transfered
    
    return UUIDString;
}

- (NSString *)getUUIDFromKeychain {
    // Identifier for our keychain entry - should be unique for your application
    static const uint8_t kKeychainIdentifier[] = "com.datatist.uuid";
    NSData *tag = [[NSData alloc] initWithBytesNoCopy:(void *)kKeychainIdentifier
                                               length:sizeof(kKeychainIdentifier)
                                         freeWhenDone:NO];
    
    // First check in the keychain for an existing key
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassKey,
                            (__bridge id)kSecAttrApplicationTag: tag,
                            (__bridge id)kSecAttrKeySizeInBits: @64,
                            (__bridge id)kSecReturnData: @YES};
    
    CFTypeRef dataRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataRef);
    if (status == errSecSuccess) {
        NSString *result = [[NSString alloc] initWithData:(__bridge NSData *)dataRef encoding:NSUTF8StringEncoding];
        CFRelease(dataRef);
        return result;
    }
    
    // Get an UUID
    NSString *UUID = [UserAgent UUIDString];
    // md5 and max 16 chars
    NSString *clientId = [[UserAgent md5:UUID] substringToIndex:16];
    
    NSData *keyData = [clientId dataUsingEncoding:NSUTF8StringEncoding];
    
    // Store the key in the keychain
    query = @{(__bridge id)kSecClass: (__bridge id)kSecClassKey,
              (__bridge id)kSecAttrApplicationTag: tag,
              (__bridge id)kSecAttrKeySizeInBits: @64,
              (__bridge id)kSecValueData: keyData};
    
    status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    NSAssert(status == errSecSuccess, @"Failed to insert new key in the keychain");
    
    return clientId;
}

- (id)getTargetGroupId:(NSDictionary *)info {
    id campaignId = nil;
    NSArray *allKeys = info.allKeys;
    for (NSString *key in allKeys) {
        if ([key isEqualToString:@"target_group_id"]) {
            campaignId = info[key];
        } else if ([info[key] isKindOfClass:[NSString class]]) {
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[info[key] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
            if (dic) {
                campaignId = [self getTargetGroupId:dic];
            }
        } else if ([info[key] isKindOfClass:[NSDictionary class]]) {
            campaignId = [self getTargetGroupId:info[key]];
        }
        
        if (campaignId) {
            break;
        }
    }
    return campaignId;
}

- (NSString *)build {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

- (NSString *)platformValue  {
    NSString *platform = [self platform];
    
    // https://gist.github.com/Jaybles/1323251
    // https://www.theiphonewiki.com/wiki/Models
    
    // iPhone
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"Verizon iPhone 4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone 5 (GSM)";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone 5 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPhone5,3"])    return @"iPhone 5c (GSM)";
    if ([platform isEqualToString:@"iPhone5,4"])    return @"iPhone 5c (Global)";
    if ([platform isEqualToString:@"iPhone6,1"])    return @"iPhone 5s (GSM)";
    if ([platform isEqualToString:@"iPhone6,2"])    return @"iPhone 5s (Global)";
    if ([platform isEqualToString:@"iPhone7,1"])    return @"iPhone 6+";
    if ([platform isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([platform isEqualToString:@"iPhone8,2"])    return @"iPhone 6s+";
    if ([platform isEqualToString:@"iPhone8,4"])    return @"iPhone SE";
    if ([platform isEqualToString:@"iPhone9,1"])    return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,3"])    return @"iPhone 7 (not support CDMA)";
    if ([platform isEqualToString:@"iPhone9,2"])    return @"iPhone 7+";
    if ([platform isEqualToString:@"iPhone9,4"])    return @"iPhone 7+ (not support CDMA)";
    if ([platform isEqualToString:@"iPhone10,1"])   return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,4"])   return @"iPhone 8 (not support CDMA)";
    if ([platform isEqualToString:@"iPhone10,2"])   return @"iPhone 8+";
    if ([platform isEqualToString:@"iPhone10,5"])   return @"iPhone 8+ (not support CDMA)";
    if ([platform isEqualToString:@"iPhone10,3"])   return @"iPhone X";
    if ([platform isEqualToString:@"iPhone10,6"])   return @"iPhone X (not support CDMA)";
    
    // iPod
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([platform isEqualToString:@"iPod7,1"])      return @"iPod Touch 6G";
    
    // iPad
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad 2 (WiFi)";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPad Mini (WiFi)";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPad Mini (GSM)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPad Mini (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad 3 (WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad 3 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad 3 (GSM)";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad 4 (GSM)";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad 4 (GSM+CDMA)";
    if ([platform isEqualToString:@"iPad4,1"])      return @"iPad Air (WiFi)";
    if ([platform isEqualToString:@"iPad4,2"])      return @"iPad Air (Cellular)";
    if ([platform isEqualToString:@"iPad4,3"])      return @"iPad Air";
    if ([platform isEqualToString:@"iPad4,4"])      return @"iPad Mini 2 (WiFi)";
    if ([platform isEqualToString:@"iPad4,5"])      return @"iPad Mini 2 (Cellular)";
    if ([platform isEqualToString:@"iPad4,6"])      return @"iPad Mini 2 (Rev)";
    if ([platform isEqualToString:@"iPad4,7"])      return @"iPad Mini 3 (WiFi)";
    if ([platform isEqualToString:@"iPad4,8"])      return @"iPad Mini 3 (WiFi)";
    if ([platform isEqualToString:@"iPad4,9"])      return @"iPad Mini 3 (WiFi+Cellular)";
    if ([platform isEqualToString:@"iPad5,1"])      return @"iPad Mini 4 (WiFi)";
    if ([platform isEqualToString:@"iPad5,2"])      return @"iPad Mini 4 ((WiFi+Cellular)";
    if ([platform isEqualToString:@"iPad5,3"])      return @"iPad Air 2 (WiFi)";
    if ([platform isEqualToString:@"iPad5,4"])      return @"iPad Air 2 ((WiFi+Cellular)";
    if ([platform isEqualToString:@"iPad6,3"])      return @"iPad Pro (9.7 inch WiFi)";
    if ([platform isEqualToString:@"iPad6,4"])      return @"iPad Pro (9.7 inch WiFi+LTE)";
    if ([platform isEqualToString:@"iPad6,7"])      return @"iPad Pro (12.9 inch WiFi)";
    if ([platform isEqualToString:@"iPad6,8"])      return @"iPad Pro (12.9 inch WiFi+LTE)";
    if ([platform isEqualToString:@"iPad6,11"])     return @"iPad (5th generation 9.7 inch WiFi)";
    if ([platform isEqualToString:@"iPad6,12"])     return @"iPad (5th generation 9.7 inch WiFi+Cellular)";
    if ([platform isEqualToString:@"iPad7,1"])      return @"iPad Pro (2nd generation 12.9 inch WiFi)";
    if ([platform isEqualToString:@"iPad7,2"])      return @"iPad Pro (2nd generation 12.9 inch WiFi+Cellular)";
    if ([platform isEqualToString:@"iPad7,3"])      return @"iPad Pro (10.5 inch WiFi)";
    if ([platform isEqualToString:@"iPad7,4"])      return @"iPad Pro (10.5 inch WiFi+Cellular)";
    
    if ([platform isEqualToString:@"i386"])         return @"Simulator";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator";
    
    return platform;
    
}

- (NSString *)getNetconnType{
    
    NSString *netconnType = @"";
    
    DTReachability *reach = [DTReachability reachabilityWithHostName:@"www.apple.com"];
    
    switch ([reach currentReachabilityStatus]) {
        case DTNotReachable:// 没有网络
        {
            
            netconnType = @"no network";
        }
            break;
            
        case DTReachableViaWiFi:// Wifi
        {
            netconnType = @"Wifi";
        }
            break;
            
        case DTReachableViaWWAN:// 手机自带网络
        {
            // 获取手机网络类型
            CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
            
            NSString *currentStatus = info.currentRadioAccessTechnology;
            
            if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyGPRS"]) {
                
                netconnType = @"GPRS";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyEdge"]) {
                
                netconnType = @"2.75G EDGE";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyWCDMA"]){
                
                netconnType = @"3G";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyHSDPA"]){
                
                netconnType = @"3.5G HSDPA";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyHSUPA"]){
                
                netconnType = @"3.5G HSUPA";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMA1x"]){
                
                netconnType = @"2G";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORev0"]){
                
                netconnType = @"3G";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORevA"]){
                
                netconnType = @"3G";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORevB"]){
                
                netconnType = @"3G";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyeHRPD"]){
                
                netconnType = @"HRPD";
            }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyLTE"]){
                
                netconnType = @"4G";
            }
        }
            break;
            
        default:
            break;
    }
    
    return netconnType;
}

- (NSString *)networkType {
    return [self getNetconnType];
}

@end

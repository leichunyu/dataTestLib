//
//  DatatistNSURLSessionDispatcher.m
//  DatatistTracker
//
//  Created by Mattias Levin on 29/08/14.
//  Copyright (c) 2014 Mattias Levin. All rights reserved.
//

#import "DatatistNSURLSessionDispatcher.h"
#import "CustomType.h"
#import "UserAgent.h"
#import "DatatistTracker.h"


@interface DatatistNSURLSessionDispatcher ()

@property (nonatomic, strong) NSURL *datatistURL;
@property (nonatomic, readonly, strong) dispatch_semaphore_t semaphore;

@end


static NSUInteger const DatatistHTTPRequestTimeout = 5;


@implementation DatatistNSURLSessionDispatcher

@synthesize isOldVersion;

- (instancetype)initWithDatatistURL:(NSURL*)datatistURL {
    self = [super init];
    if (self) {
        _datatistURL = datatistURL;
        _semaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (NSString *)userAgent {
    return [[UserAgent sharedInstance] values];
}

- (void)sendSingleEventWithParameters:(NSDictionary*)parameters
                              success:(void (^)(void))successBlock
                              failure:(void (^)(BOOL shouldContinue))failureBlock {
    
    //NSLog(@"Dispatch single event with NSURLSession dispatcher");
    
    NSMutableArray *parameterPairs = [NSMutableArray arrayWithCapacity:parameters.count];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
//        if ([obj isKindOfClass: [NSString class]]) {
//            //            obj = @"abc?op&lp?78&";
//            obj = [(NSString *)obj stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
//            obj = [(NSString *)obj stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
//        }
        [parameterPairs addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
    }];
    
    // URL encoded query string
    NSString *queryString = [parameterPairs componentsJoinedByString:@"&"];

    queryString = (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)queryString,
                                                              NULL,
                                                              (CFStringRef)@"!$&'()*+,-./:;=?@_~%#[]",
                                                              kCFStringEncodingUTF8));
    
    

    NSString *charactersToEscape = @"?!@#$^&%*+,:;='\"`<>()[]{}/\\| ";
    NSCharacterSet *allowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:charactersToEscape] invertedSet];
    NSString *encodedUrl = [queryString stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
    NSLog(@"\n%@",encodedUrl);
    
    
//    NSString *queryString = [[parameterPairs componentsJoinedByString:@"&"] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];

    NSURL *URL = [NSURL URLWithString:[@"?" stringByAppendingString:queryString] relativeToURL:self.datatistURL];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
                                    initWithURL:URL
                                    cachePolicy:NSURLRequestReloadIgnoringCacheData
                                    timeoutInterval:DatatistHTTPRequestTimeout];
    if (self.userAgent) {
        [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
        DatatistDebugLog(@"userAgent: \n%@", self.userAgent);
    }
    
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"skyhttp request Get %@", URL);
    }

    
    request.HTTPMethod = @"GET";
    
    [self sendRequest:request success:^() {
        if (successBlock) {
            successBlock();
        }
    }failure:failureBlock];
}

+ (NSString *)dicToJSONString:(id)dic {
    if (dic) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic
                                                           options:0//NSJSONWritingPrettyPrinted
                                                             error:&error];
        if (!jsonData) {
            return nil;
        } else {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
          
            NSRange range = [jsonString rangeOfString:@"\\/"];
            if (range.length > 0)
            {
                jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            }
            return jsonString;
        }
    } else {
        return nil;
    }
}

+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

- (void)sendBulkEventWithParameters:(NSDictionary*)parameters
                            success:(void (^)(void))successBlock
                            failure:(void (^)(BOOL shouldContinue))failureBlock {
    
    DatatistDebugLog(@"Dispatch batch events with NSURLSession dispatcher");
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.datatistURL
                                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                            timeoutInterval:DatatistHTTPRequestTimeout];
    if (self.userAgent) {
        [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
        DatatistDebugLog(@"userAgent: \n%@", self.userAgent);
    }
    
    request.HTTPMethod = @"POST";
    
    NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
    [request setValue:[NSString stringWithFormat:@"application/json; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
    
    if (self.isOldVersion)
    {
        NSError *error;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
    }
    else
    {
        NSString *body = [[DatatistNSURLSessionDispatcher dicToJSONString:parameters] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        request.HTTPBody = [body dataUsingEncoding:NSUTF8StringEncoding];
    }

    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"request Post %@\n%@", self.datatistURL, parameters);
    }
    
    [self sendRequest:request success:^() {
        if (successBlock) {
            successBlock();
        }
    }failure:failureBlock];
}

- (void)sendRequest:(NSURLRequest*)request success:(void (^)(void))successBlock failure:(void (^)(BOOL shouldContinue))failureBlock {
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if ([DatatistTracker sharedInstance].showLog) {
            NSLog(@"skyhttp response url:%@\nresponese:%@\nerror:%@", request.URL.absoluteString, response, error);
        }
        if (!error) {
            successBlock();
            dispatch_semaphore_signal(self.semaphore);
        } else {
            failureBlock([self shouldAbortdispatchForNetworkError:error]);
            dispatch_semaphore_signal(self.semaphore);
        }
    }];
    
    [task resume];
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
}

// Should the dispatch be aborted and pending events rescheduled
- (BOOL)shouldAbortdispatchForNetworkError:(NSError*)error {
    if (error.code == NSURLErrorBadURL ||
        error.code == NSURLErrorUnsupportedURL ||
        error.code == NSURLErrorCannotFindHost ||
        error.code == NSURLErrorCannotConnectToHost ||
        error.code == NSURLErrorDNSLookupFailed) {
        return YES;
    } else {
        return NO;
    }
}

@end

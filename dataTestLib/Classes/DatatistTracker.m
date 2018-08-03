//
//  DatatistTracker.m
//  DatatistTracker
//
//  Created by Mattias Levin on 3/12/13.
//  Copyright 2013 Mattias Levin. All rights reserved.
//
//  Change log: 将eventsFromStore函数中的@"date"改为@"cdt"  ---应用中报错
//  Change log: 将eventsFromStore函数中的ascending:YES改为NO ---应用中报错
//
//

//@import Aspects;
//#import "Aspects.h"

#import "DatatistTracker.h"
#import <CoreData/CoreData.h>
#import <CoreLocation/CoreLocation.h>

#import "DatatistTransaction.h"
#import "DatatistTransactionItem.h"
#import "PTEventEntity.h"
#import "DatatistLocationManager.h"

#import "DatatistDispatcher.h"
#import "DatatistNSURLSessionDispatcher.h"

#include <sys/types.h>
#include <sys/sysctl.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "CustomType.h"
#import "UserAgent.h"
#import "NSString+Date.h"
#import "Constant.h"
#import "DatatistOldTracker.h"
#import "AutoTrackUtils.h"
#import "UIViewController+autoTrack.h"
#import "SASwizzle.h"

#pragma mark - Constants

#pragma mark - Custom variable

@implementation CustomVariable

- (id)initWithIndex:(NSUInteger)index name:(NSString*)name value:(NSString*)value {
    self = [super init];
    if (self) {
        _index = index;
        _name = name;
        _value = value;
    }
    return self;
}

@end

#pragma mark - Datatist tracker

@interface DatatistTracker(){
    NSString *_siteIDH5;
    NSString *_projectIdH5;
    NSString *_referrerUrl;
    NSString *_pageviewUrl;
    NSString *_pageviewTitle;
}

@property (nonatomic, strong) NSMutableArray *forbiddenController;
@property (nonatomic, strong) NSMutableArray *forbiddenControlClass;
@property (nonatomic, strong) DatatistOldTracker *datatistOldTracker;

@property (nonatomic, readonly) NSString *clientID;
@property (nonnull, strong) NSString *siteID;

@property (nonatomic, strong) NSString *lastGeneratedPageURL;
@property (nonatomic, strong) NSDate *appDidEnterBackgroundDate;

@property (nonatomic, strong) NSDictionary *customVariables;
@property (nonatomic, strong) NSDictionary *sessionParameters;
@property (nonatomic, strong) NSDictionary *staticParameters;
@property (nonatomic, strong) NSDictionary *campaignParameters;

@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, strong) NSString *sessionStartTime;  // 时间戳，单位秒

@property (nonatomic, strong) id<DatatistDispatcher> dispatcher;
@property (nonatomic, strong) NSTimer *dispatchTimer;
@property (nonatomic) BOOL isDispatchRunning;
@property (nonatomic, assign) BOOL enableJSProjectIdTrack;

@property (nonatomic) BOOL includeLocationInformation; // Disabled, see comments in .h file
@property (nonatomic, strong) DatatistLocationManager *locationManager;

@property (nonatomic, readonly, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic, readonly, strong) NSOperationQueue *operationQueue;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskInentifier;

@property (nonatomic, strong) NSString *pushClientId;
@property (nonatomic, strong) NSString *pushCampaignId;
@property (nonatomic, strong) NSNumber *pushType;

@property (nonatomic, strong) NSNumber *dcid;
@property (nonatomic, strong) NSNumber *dtg;

@end

NSString* UserDefaultKeyWithSiteID(NSString* siteID, NSString *key);

@implementation DatatistTracker
@synthesize clientID = _clientID;

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize operationQueue = _operationQueue;
@synthesize userID = _userID;
@synthesize enableAutoTrack = _enableAutoTrack;

static DatatistTracker *_sharedInstance;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (instancetype)initWithSiteID:(NSString*)siteID baseURL:(NSURL*)baseURL {
    return [self sharedInstanceWithSiteID:siteID dispatcher:[self defaultDispatcherWithDatatistURL:baseURL] AutoTrack: NO];
}

+ (instancetype)initWithSiteID:(NSString*)siteID baseURL:(NSURL*)baseURL  AutoTrack:(BOOL)autoTrack {
    return [self sharedInstanceWithSiteID:siteID dispatcher:[self defaultDispatcherWithDatatistURL:baseURL] AutoTrack: autoTrack];
}

+ (instancetype)initWithSiteID:(NSString*)siteID BaseURL:(NSURL*)baseURL Site_1_ID:(NSString*)site_1_ID Base_1_URL:(NSURL*)base_1_URL
{
    return [self initWithSiteID:siteID BaseURL:baseURL AutoTrack:NO Site_1_ID:site_1_ID Base_1_URL: base_1_URL];
}

+ (instancetype)initWithSiteID:(NSString*)siteID BaseURL:(NSURL*)baseURL AutoTrack:(BOOL)autoTrack Site_1_ID:(NSString*)site_1_ID Base_1_URL:(NSURL*)base_1_URL {
    DatatistTracker *tempDatatistTracker = [self sharedInstanceWithSiteID:siteID dispatcher:[self defaultDispatcherWithDatatistURL:baseURL] AutoTrack: autoTrack];
    
    if (site_1_ID && site_1_ID.length) {
        tempDatatistTracker.datatistOldTracker = [DatatistOldTracker sharedInstanceWithSiteID: site_1_ID baseURL: base_1_URL];
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDatatistUserId];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return tempDatatistTracker;
}

+ (id<DatatistDispatcher>)defaultDispatcherWithDatatistURL:(NSURL*)datatistURL {
    return [[DatatistNSURLSessionDispatcher alloc] initWithDatatistURL:datatistURL];
}

+ (instancetype)sharedInstanceWithSiteID:(NSString*)siteID dispatcher:(id<DatatistDispatcher>)dispatcher AutoTrack:(BOOL)autoTrack{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[DatatistTracker alloc] initWithSiteID:siteID dispatcher:dispatcher AutoTrack: autoTrack];
    });
    
    return _sharedInstance;
}

+ (instancetype)sharedInstance {
    if (!_sharedInstance) {
        DatatistLog(@"Tracker must first be initialized using sharedInstanceWithBaseURL:siteID:");
        return nil;
    } else {
        return _sharedInstance;
    }
}

+ (NSString *)version {
    return DatatistTrackerVersion;
}

- (void)resetSiteId:(NSString *)siteId
{
    if (siteId.length > 0)
    {
        self.siteID = siteId;
    }
}

- (NSOperationQueue *)operationQueue {
    if (!_operationQueue) {
        _operationQueue = [NSOperationQueue new];
        [_operationQueue setMaxConcurrentOperationCount:1];
    }
    return _operationQueue;
}

- (instancetype)initWithSiteID:(NSString*)siteID dispatcher:(id<DatatistDispatcher>)dispatcher AutoTrack:(BOOL)autoTrack {
    
    if (self = [super init]) {
        
        // Initialize instance variables
        _enableTrack = YES;
        _siteID = siteID;
        _dispatcher = dispatcher;
        
        _sessionTimeout = DatatistDefaultSessionTimeout;
        
        // By default a new session will be started when the tracker is created
        _sessionStart = YES;
        _sessionId = [DatatistTracker generateNewSessionId];
        _sessionStartTime = [DatatistTracker getNewSessionStartTime];
        
        _dispatchInterval = DatatistDefaultDispatchTimer;
        _maxNumberOfQueuedEvents = DatatistDefaultMaxNumberOfStoredEvents;
        _isDispatchRunning = NO;
        
        _eventsPerRequest = DatatistDefaultNumberOfEventsPerRequest;
        
        _includeLocationInformation = YES;
        _locationManager = [[DatatistLocationManager alloc] init];
        _enableJSProjectIdTrack = NO;
        _enableAutoTrack = NO;
        
        _showLog = NO;
        _forbiddenControlClass = [NSMutableArray array];
        _forbiddenController = @[@"UIInputViewController", @"UIInputWindowController", @"UIApplicationRotationFollowingController", @"UIAlertController", @"UICompatibilityInputViewController",
            @"_UIRemoteInputViewController",
            @"UIApplicationRotationFollowingControllerNoTouches"].mutableCopy;
        NSString* suffixUA = @" datatist-sdk-ios";
        UIWebView* webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        NSString* defaultUA = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        
        if ([defaultUA rangeOfString: @"datatist-sdk-ios"].location == NSNotFound) {
            NSString* finalUA = [defaultUA stringByAppendingString:suffixUA];
            
            DatatistLog(@"DatatistWebViewAgentController %@", finalUA);
            NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:finalUA, @"UserAgent", nil];
            [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
        }
        
        
        DatatistLog(@"Tracker created with siteID %@", siteID);
        
        if (autoTrack) {
            [UIViewController sa_swizzleMethod:@selector(viewDidAppear:) withMethod:@selector(sa_autotrack_viewDidAppear:) error:NULL]; 
            /*
            __weak __typeof (self)weakSelf = self;
            [self trackEventWithClass:[UIViewController class]
                             selector:@selector(viewDidAppear:)
                         eventHandler:^(id<AspectInfo> aspectInfo) {
                             UIViewController *controller =  aspectInfo.instance;
                             
                             NSString *title = controller.title;
                             
                             if (!title && controller.navigationItem.titleView) {
                                 if ([controller.navigationItem.titleView isKindOfClass: [UILabel class]]) {
                                     title = ((UILabel *)controller.navigationItem.titleView).text;
                                 } else {
                                     for (UIView *lbTitle in controller.navigationItem.titleView.subviews) {
                                         if ([lbTitle isKindOfClass: [UILabel class]]) {
                                             title = ((UILabel *)lbTitle).text;
                                             
                                             break;
                                         }
                                     }
                                 }
                             }
                             
                             NSString *controllerClassName = NSStringFromClass([controller class]);
                             BOOL isPermittedController = [weakSelf permittedController: controllerClassName];
                             
                             if (isPermittedController) {
                                 BOOL isWebViewController = [weakSelf hasWebView: controller.view];
                                 
                                 if (!isWebViewController)
                                 {
                                     if (!title) {
                                         title = @"";
                                     }
                                     [[DatatistTracker sharedInstance] trackPageView:controllerClassName title:title udVariable:nil];
                                     DatatistLog(@"autoViewController %@ %@", controllerClassName, title);
                                 }
                             }
                         }]; */
        }
        
        [self startDispatchTimer];
        
#if TARGET_OS_IPHONE
        // Notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
        
        return self;
    } else {
        return nil;
    }
}

- (BOOL)permittedController:(NSString *)controllerName
{
    for (NSString *forbiddenControllerName in self.forbiddenController) {
        if ([forbiddenControllerName isEqualToString: controllerName]) {
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)hasWebView:(UIView *)view
{
    for (UIView *subview in [view subviews])
    {
#if ABOVE_IOS_8_0
        if ([subview isKindOfClass: [UIWebView class]] || [subview isKindOfClass: [WKWebView class]])
#else
            if ([subview isKindOfClass: [UIWebView class]])
#endif
            {
                return YES;
            }
    }
    
    return NO;
}

- (BOOL)isViewTypeForbidden:(Class)aClass
{
    if ([self.forbiddenControlClass containsObject:aClass])
    {
        return YES;
    }else
    {
        return NO;
    }
}

- (void)trackForbiddenController:(NSArray *)array {
    for (NSString *controllerName in array) {
        if (![self.forbiddenController containsObject: controllerName]) {
            [self.forbiddenController addObject: controllerName];
        }
    }
}

- (void)trackForbiddenControlClass:(NSArray *)array
{
    for (Class class in array)
    {
        if (![self.forbiddenControlClass containsObject:class])
        {
            [self.forbiddenControlClass addObject:class];
        }
    }
}
//- (void)trackEventWithClass:(Class)klass
//                   selector:(SEL)selector
//               eventHandler:(void (^)(id<AspectInfo> aspectInfo))eventHandler
//{
//    [klass aspect_hookSelector:selector withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo) {
//        if (eventHandler) {
//            eventHandler(aspectInfo);
//        }
//    } error:NULL];
//}

- (void)startDispatchTimer {
    //return;  // sky test
    // Run on main thread run loop
    __weak typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [weakSelf stopDispatchTimer];
        
        // If dispatch interval is < 0, manual dispatch must be used
        // If dispatch internal is = 0, the event is dispatched automatically directly after the event is tracked
        if (weakSelf.dispatchInterval > 0) {
            
            // Run on timer
            weakSelf.dispatchTimer = [NSTimer scheduledTimerWithTimeInterval:weakSelf.dispatchInterval
                                                                      target:weakSelf
                                                                    selector:@selector(dispatch:)
                                                                    userInfo:nil
                                                                     repeats:NO];
            
            DatatistDebugLog(@"Dispatch timer started with interval %f", weakSelf.dispatchInterval);
        }
    });
}

- (void)stopDispatchTimer {
    
    if (self.dispatchTimer) {
        [self.dispatchTimer invalidate];
        self.dispatchTimer = nil;
        
        DatatistDebugLog(@"Dispatch timer stopped");
    }
}

- (void)appDidBecomeActive:(NSNotification*)notification {
    
    if (!self.appDidEnterBackgroundDate) {
        // Cold start, init have already configured and started any services needed
        return;
    }
    
    // Create new session?
    if (fabs([self.appDidEnterBackgroundDate timeIntervalSinceNow]) >= self.sessionTimeout
        || ![[NSCalendar currentCalendar] isDate:self.appDidEnterBackgroundDate inSameDayAsDate:[NSDate date]]) {
        self.sessionStart = YES;
        self.dcid = nil;
        self.dtg = nil;
        self.sessionId = [DatatistTracker generateNewSessionId];
        self.sessionStartTime = [DatatistTracker getNewSessionStartTime];
    }
    
    if (self.includeLocationInformation) {
        [self.locationManager starUpdateLocation];
    }
    
    [self startDispatchTimer];
}

- (void)appDidEnterBackground:(NSNotification*)notification {
    self.backgroundTaskInentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundTask];
    }];
    
    if (!self.isDispatchRunning) {
        [self stopDispatchTimer];
        self.isDispatchRunning = YES;
        [self sendEventOnBackground];
    }
}

- (void)endBackgroundTask {
    self.appDidEnterBackgroundDate = [NSDate date];
    
    if (self.includeLocationInformation) {
        [self.locationManager stopUpdataLocation];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopDispatchTimer];
    });
}

#pragma mark Views and Events

- (void)setUserID:(NSString *)userID {
    _userID = userID;
    
    if (![_userID isKindOfClass: [NSString class]]) {
        _userID = @"";
    }
    
    if (_userID && _userID.length) {
        [[NSUserDefaults standardUserDefaults] setObject:_userID forKey:kDatatistUserId];
        
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDatatistUserId];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (!self.isDispatchRunning) {
        [self stopDispatchTimer];
        [self updateEventsWithCompletionBlock:^{
            [self dispatch];
        }];
    }
}

- (NSString *)userID {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDatatistUserId];
}

+ (NSString *)generateNewSessionId {
    NSString *idString = [NSString stringWithFormat:@"Datatist-iOS-%@", [DatatistTracker getNewSessionStartTime]];
    // md5 and max 16 chars
    NSString *sessionId = [[UserAgent md5:idString] substringToIndex:16];
    return sessionId;
}

+ (NSString *)getNewSessionStartTime {
    NSTimeInterval current = [[NSDate date] timeIntervalSince1970] * 1000;
    NSString *sessionStartTime = [NSString stringWithFormat:@"%ld", (long)current];
    
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"getNewSessionStartTime %@", [NSDate date]);
    }
    
    return sessionStartTime;
}

- (void)updateEventsWithCompletionBlock:(void (^)(void))finish {
    [self.managedObjectContext performBlock:^{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"PTEventEntity"];
        
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
        fetchRequest.sortDescriptors = @[sortDescriptor];
        
        NSError *error;
        NSArray *eventEntities = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (eventEntities && eventEntities.count > 0) {
            
            [eventEntities enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, eventEntities.count)] options:0
                                          usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                              
                                              PTEventEntity *eventEntity = (PTEventEntity*)obj;
                                              NSMutableDictionary *parameters = (NSMutableDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:eventEntity.datatistRequestParameters];
                                              
                                              if (!parameters[DatatistParameterUserId] && self.userID) {
                                                  parameters[DatatistParameterUserId] = self.userID;
                                                  eventEntity.datatistRequestParameters = [NSKeyedArchiver archivedDataWithRootObject:parameters];
                                              }
                                          }];
            
            [self.managedObjectContext save:&error];
            if (finish) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    finish();
                });
            }
        } else {
            if (finish) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    finish();
                });
            }
        }
    }];
}

// Each Datatist request must contain a page URL
// For screen views the page URL is generated based on the screen hierarchy
// For other types of events (e.g. goals, custom events etc) the page URL is set to the value generated by the last page view
- (NSString*)generatePageURL:(NSArray*)components {
    if (components) {
        NSString *pageURL = [NSString stringWithFormat:@"http://%@/%@", [UserAgent sharedInstance].appName, [components componentsJoinedByString:@"/"]];
        self.lastGeneratedPageURL = pageURL;
        return pageURL;
    } else if (self.lastGeneratedPageURL) {
        return self.lastGeneratedPageURL;
    } else {
        return [NSString stringWithFormat:@"http://%@", [UserAgent sharedInstance].appName];
    }
}

- (void)trackPageView:(NSString *)views title:(NSString *)title udVariable:(NSDictionary *)vars {
    if (!title){
        title = @"";
    }
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[DatatistParameterEventName] = DatatistParameterPageView;
    params[DatatistParameterURL] = [NSString stringWithFormat: @"http://%@/%@", [UserAgent sharedInstance].appName, views];
    
    NSString *str_utm_campaign = [[NSUserDefaults standardUserDefaults] objectForKey: @"utm_campaign"];
    if (str_utm_campaign && str_utm_campaign.length) {
        NSRange range = [params[DatatistParameterURL] rangeOfString: @"?"];
        if (NSNotFound == range.location) {
            params[DatatistParameterURL] = [NSString stringWithFormat: @"%@?utm_campaign=%@", params[DatatistParameterURL], str_utm_campaign];
        } else {
            params[DatatistParameterURL] = [NSString stringWithFormat: @"%@&utm_campaign=%@", params[DatatistParameterURL], str_utm_campaign];
        }
        
        NSString *str_pushContent = [[NSUserDefaults standardUserDefaults] objectForKey: @"pushContent"];
        
        if ([str_pushContent isKindOfClass: [NSDictionary class]]) {
            str_pushContent = ((NSDictionary *)str_pushContent).description;
        }
        
        if (![str_pushContent isKindOfClass: [NSString class]]) {
            str_pushContent = @"";
        }
        
        if (str_pushContent && str_pushContent.length) {
            params[DatatistParameterURL] = [NSString stringWithFormat: @"%@&pushContent=%@", params[DatatistParameterURL], str_pushContent];
        }
        
        [[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"pushContent"];
        [[NSUserDefaults standardUserDefaults] setObject: nil forKey: @"utm_campaign"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    params[DatatistParameterTitle] = title;
    
    _referrerUrl = _pageviewUrl;
    _pageviewUrl = params[DatatistParameterURL];
    _pageviewTitle = params[DatatistParameterTitle];

    DatatistLog(@"seturl sdk %@", params[DatatistParameterURL]);
    
    NSMutableDictionary *eventBody = [NSMutableDictionary dictionary];
    
    if (vars) {
        eventBody[DatatistParameterUdVariable] = vars;
    }
    
    NSString *bodyString = [DatatistNSURLSessionDispatcher dicToJSONString:eventBody];
    if (bodyString) {
        params[DatatistParameterEventBody] = bodyString;
    }
    
    [self trackEventBody:params];
}

- (void)trackSearch:(NSString *)keyword recommendationSearchFlag:(BOOL)recommendationFlag historySearchFlag:(BOOL)historyFlag udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistParameterKeyword] = keyword;
    body[DatatistParameterRecommendationSearchFlag] = recommendationFlag ? @(1) : @(0);
    body[DatatistParameterHistorySearchFlag] = historyFlag ? @(1) : @(0);
    
    [self trackEvent: DatatistParameterSearch body:body udVariable: vars];
}

- (void)trackProductPage:(NSString *)sku productCategory1:(NSString *)category1 productCategory2:(NSString *)category2 productCategory3:(NSString *)category3 productOriginPrice: (double)originPrice productRealPrice:(double)realPrice udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistParameterSKU] = sku;
    body[DatatistParameterProductCategory1] = category1;
    
    if (category2) {
        body[DatatistParameterProductCategory2] = category2;
    }
    if (category3) {
        body[DatatistParameterProductCategory3] = category3;
    }
    body[DatatistParameterProductOriginalPrice] = [NSString stringWithFormat: @"%.2f", originPrice];
    body[DatatistParameterProductRealPrice] = [NSString stringWithFormat: @"%.2f", realPrice];
    
    [self trackEvent: DatatistParameterProductPage body:body udVariable: vars];
}

- (void)trackAddCart:(NSString *)sku productQuantity:(long)quantity productRealPrice:(double)realPrice udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistParameterSKU] = sku;
    body[DatatistParameterProductQuantity] = @(quantity);
    body[DatatistParameterProductRealPrice] = [NSString stringWithFormat: @"%.2f", realPrice];
    
    [self trackEvent: DatatistParameterAddCart body:body udVariable: vars];
}

- (NSDictionary *)orderInfoToDic:(DatatistOrderInfo *)info {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (info.orderID) {
        params[@"orderID"] = info.orderID;
    }
    params[@"orderAMT"] = [NSString stringWithFormat: @"%.2f", info.orderAMT];
    params[@"shipAMT"] = [NSString stringWithFormat: @"%.2f", info.shipAMT];
    if (info.shipAddress) {
        params[@"shipAddress"] = info.shipAddress;
    }
    if (info.shipMethod) {
        params[@"shipMethod"] = info.shipMethod;
    }
    
    return params;
}

- (NSDictionary *)couponInfoToDic:(DatatistCouponInfo *)info {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (info.couponType) {
        params[@"couponType"] = info.couponType;
    }
    
    params[@"couponAMT"] = [NSString stringWithFormat: @"%.2f", info.couponAMT];
    
    return params;
}

- (NSDictionary *)productInfoToDic:(DatatistProductInfo *)info {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (info.productSKU) {
        params[@"sku"] = info.productSKU;
    }
    if (info.productSourceSku) {
        params[@"productSourceSku"] = info.productSourceSku;
    }
    if (info.productCategory) {
        params[@"productCategory"] = info.productCategory;
    }
    params[@"productRealPrice"] = [NSString stringWithFormat: @"%.2f", info.productRealPrice];
    params[@"productOriPrice"] = [NSString stringWithFormat: @"%.2f", info.productOriPrice];
    params[@"productQuantity"] = @(info.productQuantity);
    if (info.productTitle) {
        params[@"productTitle"] = info.productTitle;
    }
    
    return params;
}

- (void)trackOrder:(DatatistOrderInfo *)order couponInfo:(NSArray *)coupons productInfo:(NSArray *)products udVariable:(NSDictionary *)vars {
    if ([order.orderID isKindOfClass: [NSString class]] && !order.orderID.length) {
        NSLog(@"缺少OrderId,打点失败.");
        
        return;
    }
    
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistParameterOrderInfo] = [self orderInfoToDic:order];
    
    if (coupons && coupons.count) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:coupons.count];
        for (DatatistCouponInfo *coupon in coupons) {
            [array addObject:[self couponInfoToDic:coupon]];
        }
        body[DatatistParameterCouponInfo] = array;
    }
    if (products && products.count) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:products.count];
        for (DatatistProductInfo *product in products) {
            [array addObject:[self productInfoToDic:product]];
        }
        body[DatatistParameterProductInfo] = array;
    }
    
    //    vars = @{@"abc":@"opq"};
    [self trackEvent: DatatistParameterOrder body:body udVariable: nil];
    
    if ([DatatistTracker sharedInstance].datatistOldTracker && self.enableTrack) {
        
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:products.count];
        
        if (products && products.count) {
            
            for (DatatistProductInfo *product in products) {
                if (product.productSKU && product.productTitle)
                {
                    //        NSArray *dictTest = @[@[@"sku:43557566343547653",@"iPhone X",@"8,900.00",@"2"],@[@"sku:43557566343546535",@"罗4abc技光电鼠标",@"67.00",@"3"],@[@"sku:43557566343546700",@"西麦燕麦",@"35.00",@"10"]]; item sku, item name, item category, item price, item quantity
                    
                    NSArray *arrayItem =@[[NSString stringWithFormat: @"sku:%@", product.productSKU], product.productTitle, product.productCategory, [NSString stringWithFormat: @"%.2f", product.productRealPrice], @(product.productQuantity)];
                    
                    [array addObject: arrayItem];
                }
            }
        }
        
        if (array && array.count) {
            NSMutableDictionary *orderParams = [NSMutableDictionary dictionary];
            
            orderParams[DatatistParameterTransactionItems] =  [DatatistNSURLSessionDispatcher dicToJSONString: array];
            orderParams[DatatistParameterEventName] = DatatistParameterOrder;
            orderParams[DatatistParameterTransactionIdentifier] = order.orderID;
            orderParams[DatatistParameterRevenue] = [NSString stringWithFormat: @"%.2f", order.orderAMT];
            orderParams[DatatistParameterTransactionShipping] = [NSString stringWithFormat: @"%.2f", order.shipAMT];
            orderParams[DatatistParameterTransactionSubTotal] = [NSString stringWithFormat: @"%.2f", order.orderAMT - order.shipAMT];
            
            if (vars) {
                NSString *udVariableString = [DatatistNSURLSessionDispatcher dicToJSONString:vars];
                
                orderParams[DatatistParameterUdVariable] = udVariableString;
            }
            
            [[DatatistTracker sharedInstance].datatistOldTracker queueEvent: orderParams];
        }
    }
}

- (void)trackPayment:(NSString *)orderId payMethod:(NSString *)method payStatus:(BOOL)pay payAMT:(double)amt udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistParameterOrderID] = orderId;
    body[DatatistParameterPayMethod] = method;
    body[DatatistParameterPayStatus] = pay ? @(1) : @(0);
    body[DatatistParameterPayAMT] = [NSString stringWithFormat: @"%.2f", amt];
    
    [self trackEvent: DatatistParameterPayment body:body udVariable: vars];
}

- (void)trackPreCharge:(double)amt chargeMethod:(NSString *)chargeMethod couponAMT:(double)coupon payStatus:(BOOL)pay udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistParameterChargeAMT] = [NSString stringWithFormat: @"%.2f", amt];
    body[DatatistParameterChargeMethod] = chargeMethod;
    body[DatatistParameterPayStatus] = pay ? @(1) : @(0);
    body[DatatistParameterCouponAMT] = [NSString stringWithFormat: @"%.2f", coupon];
    
    [self trackEvent: DatatistParameterPreCharge body:body udVariable: vars];
}

- (void)trackRegister:(NSString *)uid type:(NSString *)type authenticated:(BOOL)auth udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    //    if (uid) {  // 注册时只放到body里.
    //        self.userID = uid;
    //    }
    
    if (uid) {
        body[@"uid"] = uid;
    }
    
    if (type) {
        body[DatatistParameterType] = type;
    }
    body[DatatistParameterAuthenticated] = auth ? @(1) : @(0);
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey: @"DatatistRegistrationID"]) {
        body[@"registrationID"] = [[NSUserDefaults standardUserDefaults] objectForKey: @"DatatistRegistrationID"];
    }
    
    [self trackEvent:DatatistParameterRegister body:body udVariable:vars];
}

- (void)trackLogin:(NSString *)uid udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    if (uid) {
        self.userID = uid;
    }
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey: @"DatatistRegistrationID"]) {
        body[@"registrationID"] = [[NSUserDefaults standardUserDefaults] objectForKey: @"DatatistRegistrationID"];
    }
    
    [self trackEvent:DatatistParameterLogin body:body udVariable:vars];
}

- (void)trackLogout:(NSString *)uid udVariable:(NSDictionary *)vars {
    if (uid) {
        self.userID = uid;
    }
    
    [self trackEvent:DatatistParameterLogout body:nil udVariable:vars];
    
    self.userProperty = nil;
}

- (void)trackLogout:(NSDictionary *)vars {
    [self trackEvent:DatatistParameterLogout body:nil udVariable:vars];
    
    self.userID = nil;
    
    self.userProperty = nil;
}

- (void)trackEvent:(NSString*)name udVariable:(NSDictionary *)vars {
    [self customerTrack:name udVariable:vars];
}

- (void)customerTrack:(NSString*)name udVariable:(NSDictionary *)vars {
    
    if (![self isValidateByRegex:@"[a-zA-Z_0-9]+$" sourceStr:name])
    {
        return;
    }
    if (vars)
    {
         [self trackEvent:name body:[NSMutableDictionary dictionaryWithDictionary:vars] udVariable:nil];
    }
   else
   {
       [self trackEvent:name body:nil udVariable:vars];
   }
}

- (void)trackEvent:(NSString*)name body:(NSMutableDictionary *)eventBody udVariable:(NSDictionary *)vars {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    if (!eventBody) {
        eventBody = [NSMutableDictionary dictionary];
    }
    
    if (vars) {
        eventBody[DatatistParameterUdVariable] = vars;
    }
    
    params[DatatistParameterEventName] = name;
    
    //    if (self.dcid && self.dtg) {
    //        eventBody[DatatistpushExtraDcid] = self.dcid;
    //        eventBody[DatatistpushExtraDtg] = self.dtg;
    //    }
    
    NSString *bodyString = [DatatistNSURLSessionDispatcher dicToJSONString:eventBody];
    if (bodyString) {
        params[DatatistParameterEventBody] = bodyString;
    }
    
    //    params[DatatistParameterEventBody] = eventBody;
    
    [self trackEventBody:params];
}

- (void)enableTrack:(BOOL)enable {
    DatatistLog(@"enableTrack %d", enable);
    
    self.enableTrack = enable;
}

- (void)enableGPSTrack:(BOOL)enable
{
    DatatistLog(@"enableGPSTrack %d", enable);
    self.includeLocationInformation = YES;
}

- (void)enableJSProjectIdTrack:(BOOL)enable
{
    _enableJSProjectIdTrack = enable;
}

- (void)trackEventBody:(NSDictionary *)event {
    if (!self.enableTrack) {
        return;
    }
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:event];
    
    //    if (self.sessionStart) {
    //        self.sessionStart = NO;
    //        params[DatatistParameterSessionStart] = @"1";
    //    }
    
    if (self.sessionId) {
        params[DatatistParameterSessionId] = self.sessionId;
        params[DatatistParameterSessionStartTime] = self.sessionStartTime;
    }
    
    if (_pageviewUrl && !params[DatatistParameterURL]) {
        params[DatatistParameterURL] = _pageviewUrl;
    }
    if (_pageviewTitle && !params[DatatistParameterTitle]) {
        params[DatatistParameterTitle] = _pageviewTitle;
    }
    if (_referrerUrl) {
        params[DatatistParameterReferrerUrl] = _referrerUrl;
    }
    
    NSArray *allKeys = params.allKeys;
    
    for (NSString *key in allKeys) {
        id obj = params[key];
        
        if ([obj isKindOfClass: [NSString class]]) {
            obj = [(NSString *)obj stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
            obj = [(NSString *)obj stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
            
            params[key] = obj;
        }
    }
    
    if ([DatatistTracker sharedInstance].datatistOldTracker) {
        NSString *eventName = event[DatatistParameterEventName];
        if (![eventName isEqualToString: DatatistParameterTrackInitJPush] && ![eventName isEqualToString: DatatistParameterTrackJPush] && ![eventName isEqualToString: DatatistParameterTrackOpenChannel]) {
            [[DatatistTracker sharedInstance].datatistOldTracker queueEvent: params];
        }
    }
    
    [self queueEvent:params];
}

- (BOOL)sendTransaction:(DatatistTransaction*)transaction withCustomVariable:(NSDictionary *)vars {
    return [[DatatistTracker sharedInstance].datatistOldTracker sendTransaction:transaction withCustomVariable:vars];
}

- (BOOL)sendEventWithCategory:(NSString*)category action:(NSString*)action name:(NSString*)name value:(NSString *)value withCustomVariable:(NSDictionary *)vars {
    return [[DatatistTracker sharedInstance].datatistOldTracker sendEventWithCategory:category action:action name:name value:value withCustomVariable:vars];
}

- (BOOL)sendWithCustomVariable:(NSDictionary *)vars Views:(NSString*)screen, ... {
    // Collect var args
    NSMutableArray *components = [NSMutableArray array];
    va_list args;
    va_start(args, screen);
    for (NSString *arg = screen; arg != nil; arg = va_arg(args, NSString*)) {
        [components addObject:arg];
    }
    va_end(args);
    
    return [[DatatistTracker sharedInstance].datatistOldTracker sendViewsFromArray:components withCustomVariable:vars];
}

/**
 *  track JPush
 **/
- (void)trackJPush:(NSDictionary *)pushInfo pushIntent:(NSDictionary *)pushIntent udVariable:(NSDictionary *)vars {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    if (!pushInfo || (!pushInfo[DatatistPushInfoAlias] && !pushInfo[DatatistPushInfoRegistrationID] && !pushInfo[DatatistPushInfoTag])) {
        return;
    }
    
    body[DatatistPushInfo] = pushInfo;
    body[DatatistPushContent] = pushIntent[@"aps"][@"alert"] ? : @"";
    self.dcid = [NSNumber numberWithInt: [pushIntent[DatatistpushExtraDcid] intValue]];
    self.dtg = [NSNumber numberWithInt: [pushIntent[DatatistpushExtraDtg] intValue]];
    body[DatatistpushExtraDcid] = self.dcid;
    body[DatatistpushExtraDtg] = self.dtg;
    
    if (self.dcid.intValue != 0 && self.dtg.intValue != 0)
    {
        self.sessionId = [DatatistTracker generateNewSessionId];
        self.sessionStartTime = [DatatistTracker getNewSessionStartTime];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject: body[DatatistPushContent] forKey: @"pushContent"];
    [[NSUserDefaults standardUserDefaults] setObject: @"trackJPush" forKey: @"utm_campaign"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self trackEvent: DatatistParameterTrackJPush body:body udVariable: vars];
}

/**
 *  track Init JPush
 **/
- (void)trackInitJPush:(NSDictionary *)pushManager udVariable:(NSDictionary *)vars
{
    if (pushManager[@"registrationID"]) {
        [[NSUserDefaults standardUserDefaults] setObject: pushManager[@"registrationID"] forKey: @"DatatistRegistrationID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    
    body[DatatistpushManager] = pushManager;
    
    [self trackEvent: DatatistParameterTrackInitJPush body:body udVariable: vars];
}

/**
 *  track Open Channel
 **/
- (void)trackOpenChannel:(NSString *)openChannelName udVariable:(NSDictionary *)vars
{
    //openChannelName:打开来源渠道名称
    //udVariable: 客户可扩展的自定义变量，以JSON对象的形式进行传输
    //    1.0：不发此接口，只做utm_campaign设置，在下一个pageview发送参数。伪代码如下：
    //    设置全局变量 utm_campaign = openChannelName.value
    //    ……
    //    当第一个pageview调用时pageview中加判断
    //    if(utm_campaign !=null){
    //        new_visit=1；重设session；
    //        pageview.url拼接上?utm_campaign= openChannelName.value；
    //        发出消息后，new_visit=0 utm_campaign=null；
    //    }
    //    ……
    //    2.0：重设session，参数放在eventbody中
    
    if (![openChannelName isKindOfClass: [NSString class]])
    {
        openChannelName = @"";
    }
    [[NSUserDefaults standardUserDefaults] setObject: openChannelName forKey: @"utm_campaign"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.sessionId = [DatatistTracker generateNewSessionId];
    self.sessionStartTime = [DatatistTracker getNewSessionStartTime];
    
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[DatatistParameterTrackOpenChannelName] = openChannelName;
    
    [self trackEvent: DatatistParameterTrackOpenChannel body:body udVariable: vars];
}

- (NSString*)JSONEncodeTransactionItems:(NSArray*)items {
    NSMutableArray *JSONObject = [NSMutableArray arrayWithCapacity:items.count];
    for (DatatistTransactionItem *item in items) {
        // The order of the properties are important
        NSMutableArray *itemArray = [[NSMutableArray alloc] init];
        if (item.sku) {
            [itemArray addObject:item.sku];
        }
        if (item.name) {
            [itemArray addObject:item.name];
        }
        if (item.category) {
            [itemArray addObject:item.category];
        }
        if (item.price) {
            [itemArray addObject:item.price];
        }
        if (item.quantity) {
            [itemArray addObject:item.quantity];
        }
        
        [JSONObject addObject:itemArray];
    }
    
    NSError *error;
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
    
    return [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
}

- (NSString *)serialCustomCustomVariables {
    if (self.customVariables) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"["];
        for (NSString *key in self.customVariables.allKeys) {
            [string appendString:[NSString stringWithFormat:@"{key:%@, value:%@},",key, [self.customVariables objectForKey:key]]];
        }
        
        [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
        [string appendString:@"]"];
        
        self.customVariables = nil;
        return string;
    } else {
        return nil;
    }
}

- (NSDictionary *)addIdentifyInfoParameters:(NSDictionary *)parameters {
    NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    NSDate *now = [NSDate date];
    joinedParameters[DatatistParameterSiteID] = self.siteID;
    
    if (self.projectId && self.projectId.length > 0) {
        joinedParameters[DatatistParameterProjectId] = self.projectId;
    }
    
//    if (_projectIdH5) {
//        joinedParameters[DatatistParameterProjectId] = _projectIdH5;
//        _projectIdH5 = nil;
//    }
//    if (_siteIDH5) {
//        joinedParameters[DatatistParameterSiteID] = _siteIDH5;
//        _siteIDH5 = nil;
//    }
    
    if (self.userProperty && [self.userProperty isKindOfClass: [NSDictionary class]]) {
        NSString *userPropertyString = [DatatistNSURLSessionDispatcher dicToJSONString:self.userProperty];
        if (userPropertyString) {
            joinedParameters[DatatistParameterUserProperty] = userPropertyString;
        }
    }
//    if (brigeInfo && [brigeInfo isKindOfClass:[NSDictionary class]])
//    {
//        NSString *brigeInfoString = [DatatistNSURLSessionDispatcher dicToJSONString:brigeInfo];
//        if (brigeInfo)
//        {
//            joinedParameters[DatatistParameterBridgeInfo] = brigeInfoString;
//        }
//    }
    
    joinedParameters[DatatistParameterDeviceId] = self.clientID;
    joinedParameters[DatatistParameterEventTime] = [NSString stringWithFormat:@"%llu", (long long)([now timeIntervalSince1970] * 1000)];
    joinedParameters[DatatistParameterSerialNumber] = [NSString stringWithFormat:@"%llu", [[UserAgent sharedInstance] sn]];
    // User id
    if (self.userID && self.userID.length > 0) {
        joinedParameters[DatatistParameterUserId] = self.userID;
    }
    
    return joinedParameters;
}

- (NSDictionary *)addUserAgentParameters:(NSDictionary *)parameters {
    NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    UserAgent *ua = [UserAgent sharedInstance];
    UIScreen *screen = [UIScreen mainScreen];
    joinedParameters[DatatistParameterUserAgentOS] = @"iOS";
    
    NSArray *osVersions = [ua.osVersion componentsSeparatedByString:@"."];
    joinedParameters[DatatistParameterUserAgentOSMajor] = osVersions[0];
    joinedParameters[DatatistParameterUserAgentOSMinor] = osVersions[1];
    
    NSArray *appVersions = [ua.appVersion componentsSeparatedByString:@"."];
    joinedParameters[DatatistParameterUserAgentBuild] = ua.build;
    //    joinedParameters[DatatistParameterUserAgentName] = ua.appName;
    //    joinedParameters[DatatistParameterUserAgentMajor] = appVersions[0];
    //    joinedParameters[DatatistParameterUserAgentMinor] = appVersions[1];
    joinedParameters[DatatistParameterUserAgentName] = @"\"\"";
    joinedParameters[DatatistParameterUserAgentMajor] = @"\"\"";
    joinedParameters[DatatistParameterUserAgentMinor] = @"\"\"";
    if ([appVersions count] >= 3) {
        joinedParameters[DatatistParameterUserAgentRevision] = appVersions[2];
    }
    
    joinedParameters[DatatistParameterUserAgentDevice] = ua.platformName;
    joinedParameters[DatatistParameterResolution] = [NSString stringWithFormat:@"%ld*%ld", (long)screen.bounds.size.width, (long)screen.bounds.size.height];
    if (![ua.networkType isEqualToString:@"--"]) {
        joinedParameters[DatatistParameterNetType] = ua.networkType;
    }
    
    joinedParameters[DatatistParameterLanguage] = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
    return joinedParameters;
}

- (NSDictionary *)addGEOInfoParameters:(NSDictionary *)parameters {
    NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    
    // Location
    if (self.includeLocationInformation) {
        // The first request for location will ask the user for permission
        CLLocation *location = self.locationManager.location;
        if (location) {
            joinedParameters[DatatistParameterLatitude] = @(location.coordinate.latitude);
            joinedParameters[DatatistParameterLongitude] = @(location.coordinate.longitude);
        }
    }
    
    return joinedParameters;
}

- (NSDictionary *)addVersionParameters:(NSDictionary *)parameters {
    NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    UserAgent *ua = [UserAgent sharedInstance];
    
    NSDictionary *temp = @{
                           @"appVersion":ua.appVersion,
                           @"sdkVersion":DatatistTrackerVersion
                           };
    
    NSString *bodyString = [DatatistNSURLSessionDispatcher dicToJSONString:temp];
    if (bodyString) {
        joinedParameters[DatatistParameterCustomVariable] = bodyString;
    }
    
    return joinedParameters;
}

- (BOOL)queueEvent:(NSDictionary*)parameters {
    
    parameters = [self addIdentifyInfoParameters:parameters];
    //parameters = [self addSessionParameters:parameters];
    parameters = [self addUserAgentParameters:parameters];
    parameters = [self addGEOInfoParameters:parameters];
    parameters = [self addVersionParameters:parameters];
    
    if (self.showLog) {
        NSLog(@"[Datatist] Store event 2.0 with parameters %@", parameters);
    }
    
    [self storeEventWithParameters:parameters completionBlock:^{
        
        if (self.dispatchInterval == 0) {
            // Trigger dispatch
            __weak typeof(self)weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf dispatch];
            });
        }
        
    }];
    
    return YES;
}

/*
 - (NSDictionary*)addSessionParameters:(NSDictionary*)parameters {
 
 if (self.sessionStart) {
 
 self.totalNumberOfVisits = self.totalNumberOfVisits + 1;
 self.currentVisitTimestamp = [[NSDate date] timeIntervalSince1970];
 
 // Reset session params and visit custom variables to force a rebuild
 self.sessionParameters = nil;
 self.visitCustomVariables = nil;
 
 // Send notifications to allow observers to set new visit custom variables
 [[NSNotificationCenter defaultCenter] postNotificationName:DatatistSessionStartNotification object:self];
 }
 
 if (!self.sessionParameters) {
 NSMutableDictionary *sessionParameters = [NSMutableDictionary dictionary];
 
 sessionParameters[DatatistParameterTotalNumberOfVisits] = [NSString stringWithFormat:@"%ld", (unsigned long)self.totalNumberOfVisits];
 
 sessionParameters[DatatistParameterPreviousVisitTimestamp] = [NSString stringWithFormat:@"%.0f", self.previousVisitTimestamp];
 
 self.sessionParameters = sessionParameters;
 }
 
 // Join event parameters with session parameters
 NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
 [joinedParameters addEntriesFromDictionary:self.sessionParameters];
 
 if (self.sessionStart) {
 joinedParameters[DatatistParameterSessionStart] = @"1";
 self.sessionStart = NO;
 }
 
 // Set custom variables - platform, OS version and application version
 if (self.includeDefaultCustomVariable) {
 if (!_visitCustomVariables) {
 _visitCustomVariables = [NSMutableDictionary dictionary];
 }
 
 NSString *deviceInfo = [self deviceInfo];
 if (deviceInfo) {
 _visitCustomVariables[@(0)] = [[CustomVariable alloc] initWithIndex:1 name:@"device_info" value:deviceInfo];
 }
 }
 
 if (self.visitCustomVariables) {
 joinedParameters[DatatistParameterVisitScopeCustomVariables] = [DatatistTracker JSONEncodeCustomVariables:self.visitCustomVariables];
 }
 
 
 return joinedParameters;
 }
 */


- (NSString *)deviceInfo {
    UserAgent *ua = [UserAgent sharedInstance];
    
    if (self.pushClientId && self.pushType) {
        return [NSString stringWithFormat:@"{App_Name : %@, App_Version : %@, OS_Version : %@, Platform : %@, SDK_Version : %@, Push_ClientId: %@, Push_Type: %@}", ua.appName, ua.appVersion, ua.osVersion, ua.platformName, DatatistTrackerVersion, self.pushClientId, self.pushType];
    } else {
        return [NSString stringWithFormat:@"{App_Name : %@, App_Version : %@, OS_Version : %@, Platform : %@, SDK_Version : %@}", ua.appName, ua.appVersion, ua.osVersion, ua.platformName, DatatistTrackerVersion];
    }
}

/*
 - (NSDictionary*)addStaticParameters:(NSDictionary*)parameters {
 
 if (!self.staticParameters) {
 NSMutableDictionary *staticParameters = [NSMutableDictionary dictionary];
 
 staticParameters[DatatistParameterSiteID] = self.siteID;
 
 staticParameters[DatatistParameterRecord]  = DatatistDefaultRecordValue;
 
 staticParameters[DatatistParameterAPIVersion] = DatatistDefaultAPIVersionValue;
 
 // Set resolution
 #if TARGET_OS_IPHONE
 CGRect screenBounds = [[UIScreen mainScreen] bounds];
 CGFloat screenScale = [[UIScreen mainScreen] scale];
 #else
 CGRect screenBounds = [[NSScreen mainScreen] frame];
 CGFloat screenScale = [[NSScreen mainScreen] backingScaleFactor];
 #endif
 CGSize screenSize = CGSizeMake(CGRectGetWidth(screenBounds) * screenScale, CGRectGetHeight(screenBounds) * screenScale);
 staticParameters[DatatistParameterScreenReseloution] = [NSString stringWithFormat:@"%.0fx%.0f", screenSize.width, screenSize.height];
 
 staticParameters[DatatistParameterVisitorID] = self.clientID;
 
 // Timestamps
 staticParameters[DatatistParameterFirstVisitTimestamp] = [NSString stringWithFormat:@"%.0f", self.firstVisitTimestamp];
 
 // As of Datatist server 2.10.0, the server will return http 204 (not content) when including send_image=0
 // If the parameter is not included http 200 and an image will be returned
 staticParameters[DatatistParameterSendImage] = @(0);
 
 self.staticParameters = staticParameters;
 }
 
 // Join event parameters with static parameters
 NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
 [joinedParameters addEntriesFromDictionary:self.staticParameters];
 
 return joinedParameters;
 }
 */

+ (NSString*)JSONEncodeCustomVariables:(NSDictionary*)variables {
    
    // Travers all custom variables and create a JSON object that be be serialized
    NSMutableDictionary *JSONObject = [NSMutableDictionary dictionaryWithCapacity:variables.count];
    for (CustomVariable *customVariable in [variables objectEnumerator]) {
        JSONObject[[NSString stringWithFormat:@"%ld", (long)customVariable.index]] = [NSArray arrayWithObjects:customVariable.name, customVariable.value, nil];
    }
    
    NSError *error;
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
    
    return [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
}

- (void)dispatch:(NSNotification*)notification {
    DatatistDebugLog(@"timer fired!");
    [self dispatch];
}

- (BOOL)dispatch {
    if (self.isDispatchRunning) {
        return YES;
    } else {
        self.isDispatchRunning = YES;
        [self sendEvent];
        return YES;
    }
}

- (void)sendEvent {
    NSUInteger numberOfEventsToSend = self.eventsPerRequest;
    [self eventsFromStore:numberOfEventsToSend completionBlock:^(NSArray *entityIDs, NSArray *events, BOOL hasMore) {
        
        if (!events || events.count == 0) {
            // No pending events
            [self sendEventDidFinishHasMorePending:NO];
            
        } else {
            NSDictionary *requestParameters = [self requestParametersForEvents:events];
            
            __weak typeof(self)weakSelf = self;
            void (^successBlock)(void) = ^ () {
                [weakSelf deleteEventsWithIDs:entityIDs];
                [weakSelf sendEventDidFinishHasMorePending:hasMore];
            };
            
            void (^failureBlock)(BOOL shouldContinue) = ^ (BOOL shouldContinue) {
                DatatistDebugLog(@"Failed to send stats to Datatist server");
                if (shouldContinue) {
                    [weakSelf sendEventDidFinishHasMorePending:hasMore];
                } else {
                    [weakSelf sendEventDidFinishHasMorePending:NO];
                }
            };
            
//            if (events.count == 1) {
//                [self.dispatcher sendSingleEventWithParameters:requestParameters success:successBlock failure:failureBlock];
//            } else
            {
                [self.dispatcher sendBulkEventWithParameters:requestParameters success:successBlock failure:failureBlock];
            }
        }
    }];
}

- (void)sendEventOnBackground {
    DatatistDebugLog(@"send event when enter background!");
    NSUInteger numberOfEventsToSend = self.eventsPerRequest;
    [self eventsFromStore:numberOfEventsToSend completionBlock:^(NSArray *entityIDs, NSArray *events, BOOL hasMore) {
        
        if (!events || events.count == 0) {
            // No pending events
            self.isDispatchRunning = NO;
            [self endBackgroundTask];
        } else {
            NSDictionary *requestParameters = [self requestParametersForEvents:events];
            
            __weak typeof(self)weakSelf = self;
            void (^successBlock)(void) = ^ () {
                [weakSelf deleteEventsWithIDs:entityIDs];
                if (hasMore) {
                    [weakSelf sendEventOnBackground];
                } else {
                    weakSelf.isDispatchRunning = NO;
                    [weakSelf endBackgroundTask];
                }
            };
            
            void (^failureBlock)(BOOL shouldContinue) = ^ (BOOL shouldContinue) {
                DatatistDebugLog(@"Failed to send stats to Datatist server");
                if (shouldContinue) {
                    [weakSelf sendEventOnBackground];
                } else {
                    weakSelf.isDispatchRunning = NO;
                    [weakSelf endBackgroundTask];
                }
            };
            
//            if (events.count == 1) {
//                [self.dispatcher sendSingleEventWithParameters:requestParameters success:successBlock failure:failureBlock];
//            } else
            {
                [self.dispatcher sendBulkEventWithParameters:requestParameters success:successBlock failure:failureBlock];
            }
        }
    }];
}

- (NSDictionary*)requestParametersForEvents:(NSArray*)events {
//    if (events.count == 1) {
//        
//        // Send events as query parameters
//        return [events objectAtIndex:0];
//        
//    } else
    {
        
        // Send events as JSON encoded post body
        NSMutableDictionary *JSONParams = [NSMutableDictionary dictionaryWithCapacity:2];
        
        NSComparator comparator = ^(id first, id second) {
            NSInteger time1 = [first[DatatistParameterEventTime] integerValue];
            NSInteger time2 = [second[DatatistParameterEventTime] integerValue];
            
            if (time1 == time2) {
                NSNumber *sn1 = [self snInEvent:first];
                NSNumber *sn2 = [self snInEvent:second];
                
                if (!sn1 || !sn2 ) {
                    return NSOrderedSame;
                }else if (sn1.integerValue < sn2.integerValue) {
                    return NSOrderedAscending;
                } else if (sn1.integerValue > sn2.integerValue) {
                    return NSOrderedDescending;
                } else {
                    return NSOrderedSame;
                }
            } else if (time1 < time2) {
                return NSOrderedAscending;
            } else {
                return NSOrderedDescending;
            }
        };
        
        NSMutableArray *sortEvents = [NSMutableArray arrayWithArray:events];
        [sortEvents sortUsingComparator:comparator];
        
        NSMutableArray *queryStrings = [NSMutableArray arrayWithCapacity:events.count];
        [sortEvents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary *params = (NSDictionary*)obj;
            
            // As of Datatist 2.0 the query string should not be url encoded in the request body
            // Unfortenatly the DTNetworking methods for create parameter pairs are not external
            NSMutableArray *parameterPair = [NSMutableArray arrayWithCapacity:params.count];
            [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [parameterPair addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
            }];
            
            NSString *queryString = [NSString stringWithFormat:@"?%@", [parameterPair componentsJoinedByString:@"&"]];
            
            [queryStrings addObject:queryString];
        }];
        
        JSONParams[@"requests"] = queryStrings;
        
        return JSONParams;
    }
}

- (NSNumber *)snInEvent:(NSDictionary *)event {
    NSInteger snInt = [event[DatatistParameterSerialNumber] integerValue];
    NSNumber *sn = [NSNumber numberWithInteger:snInt];
    return sn;
}

- (void)sendEventDidFinishHasMorePending:(BOOL)hasMore {
    if (hasMore) {
        [self sendEvent];
    } else {
        self.isDispatchRunning = NO;
        [self startDispatchTimer];
    }
}

#pragma mark - Properties

- (void)setIncludeLocationInformation:(BOOL)includeLocationInformation {
    _includeLocationInformation = includeLocationInformation;
    
    if (_includeLocationInformation) {
        [self.locationManager starUpdateLocation];
    } else {
        [self.locationManager stopUpdataLocation];
    }
    
}

- (void)setDispatchInterval:(NSTimeInterval)interval {
    
    if (interval == 0) {
        // Trigger a dispatch
        [self dispatch];
    }
    
    _dispatchInterval = interval;
}


- (NSString*)clientID {
    if (nil == _clientID) {
        _clientID = [[UserAgent sharedInstance] getUUIDFromKeychain];
        DatatistLog(@"DeviceID: %@",_clientID);
    }
    
    return _clientID;
}

- (void)setEnableAutoTrack:(BOOL)enableAutoTrack
{
    _enableAutoTrack = enableAutoTrack;
    if (_enableAutoTrack)
    {
        [AutoTrackUtils enableAutoTrack];
    }
}

#pragma mark - Core data methods

- (BOOL)storeEventWithParameters:(NSDictionary*)parameters completionBlock:(void (^)(void))completionBlock {
    
    DatatistDebugLog(@"managedObjectContext: %@", self.managedObjectContext);
    [self.managedObjectContext performBlock:^{
        
        NSError *error;
        
        // Check if we reached the limit of the number of queued events
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"PTEventEntity"];
        NSUInteger count = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];
        
        if (error) {
            DatatistDebugLog(@"fetch request error: %@", error.localizedDescription);
        }
        
        if (count < self.maxNumberOfQueuedEvents) {
            
            // Create new event entity
            PTEventEntity *eventEntity = [NSEntityDescription insertNewObjectForEntityForName:@"PTEventEntity" inManagedObjectContext:self.managedObjectContext];
            NSString *timestampeString = parameters[DatatistParameterEventTime];
            
            eventEntity.datatistRequestParameters = [NSKeyedArchiver archivedDataWithRootObject:parameters];
            eventEntity.date = [NSDate dateWithTimeIntervalSince1970:[timestampeString integerValue]];
            
            [self.managedObjectContext save:&error];
            
        } else {
            DatatistLog(@"Tracker reach maximum number of queued events");
        }
        
        completionBlock();
        
    }];
    
    return YES;
}

- (void)eventsFromStore:(NSUInteger)numberOfEvents completionBlock:(void (^)(NSArray *entityIDs, NSArray *events, BOOL hasMore))completionBlock {
    
    [self.managedObjectContext performBlock:^{
        
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"PTEventEntity"];
        
        // Oldest first
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
        fetchRequest.sortDescriptors = @[sortDescriptor];
        
        fetchRequest.fetchLimit = numberOfEvents + 1;
        
        NSError *error;
        NSArray *eventEntities = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        
        NSUInteger returnCount = eventEntities.count == fetchRequest.fetchLimit ? numberOfEvents : eventEntities.count;
        
        NSMutableArray *events = [NSMutableArray arrayWithCapacity:returnCount];
        NSMutableArray *entityIDs = [NSMutableArray arrayWithCapacity:returnCount];
        
        if (eventEntities && eventEntities.count > 0) {
            
            [eventEntities enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, returnCount)]
                                             options:0
                                          usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                                              
                                              PTEventEntity *eventEntity = (PTEventEntity*)obj;
                                              NSDictionary *parameters = (NSDictionary*)[NSKeyedUnarchiver unarchiveObjectWithData:eventEntity.datatistRequestParameters];
                                              
                                              [events addObject:parameters];
                                              [entityIDs addObject:eventEntity.objectID];
                                          }];
            
            completionBlock(entityIDs, events, eventEntities.count == fetchRequest.fetchLimit ? YES : NO);
            
        } else {
            // No more pending events
            completionBlock(nil, nil, NO);
        }
    }];
}

- (void)deleteEventsWithIDs:(NSArray*)entityIDs {
    [self.managedObjectContext performBlock:^{
        
        NSError *error;
        
        for (NSManagedObjectID *entityID in entityIDs) {
            
            PTEventEntity *event = (PTEventEntity*)[self.managedObjectContext existingObjectWithID:entityID error:&error];
            if (event) {
                [self.managedObjectContext deleteObject:event];
            }
            
        }
        
        [self.managedObjectContext save:&error];
    }];
}

#pragma mark - Core Data stack

- (NSManagedObjectContext*)managedObjectContext {
    
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    
    return _managedObjectContext;
}

- (NSManagedObjectModel*)managedObjectModel {
    
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
    
    //    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"DatatistTrackerModel" ofType:@"bundle"];
    //    NSLog(@"model path: %@", modelPath);
    //    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle bundleWithPath:modelPath]]];
    
    //    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"DatatistTracker" withExtension:@"momd"];
    //    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    NSManagedObjectModel *model = [NSManagedObjectModel new];
    
    //create the entity
    NSEntityDescription *entity = [NSEntityDescription new];
    [entity setName:@"PTEventEntity"];
    [entity setManagedObjectClassName:@"PTEventEntity"];
    
    // create the attributes
    NSMutableArray *properties = [NSMutableArray array];
    
    NSAttributeDescription *paramAttribute = [NSAttributeDescription new];
    [paramAttribute setName:@"datatistRequestParameters"];
    [paramAttribute setAttributeType:NSBinaryDataAttributeType];
    [paramAttribute setRenamingIdentifier:@"requestParameters"];
    [properties addObject:paramAttribute];
    
    NSAttributeDescription *dateAttribute = [NSAttributeDescription new];
    [dateAttribute setName:@"date"];
    [dateAttribute setAttributeType:NSDateAttributeType];
    [properties addObject:dateAttribute];
    
    // add attributes to entity
    [entity setProperties:properties];
    
    // add entity to model
    [model setEntities:[NSArray arrayWithObject:entity]];
    _managedObjectModel = model;
    
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator*)persistentStoreCoordinator {
    
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"datatisttracker"];
    
    // Support lightweigt data migration
    NSDictionary *options = @{
                              NSMigratePersistentStoresAutomaticallyOption: @(YES),
                              NSInferMappingModelAutomaticallyOption: @(YES)
                              };
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:storeURL
                                                         options:options
                                                           error:&error]) {
        
        BOOL isMigrationError = [error code] == NSPersistentStoreIncompatibleVersionHashError || [error code] == NSMigrationMissingSourceModelError;
        
        if ([[error domain] isEqualToString:NSCocoaErrorDomain] && isMigrationError) {
            
            DatatistLog(@"Remove incompatible model version: %@", [storeURL lastPathComponent]);
            
            // Could not open the database, remove it and try again
            [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
            
            
            // Try one more time to create the store
            [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                      configuration:nil
                                                                URL:storeURL
                                                            options:nil
                                                              error:&error];
            
            if (_persistentStoreCoordinator) {
                // If we successfully added a store, remove the error that was initially created
                DatatistLog(@"Recovered from migration error");
                error = nil;
            } else {
                // Not possible to recover of workaround
                DatatistLog(@"Unresolved error when setting up code data stack %@, %@", error, [error userInfo]);
                abort();
            }
            
        }
        
    }
    
    return _persistentStoreCoordinator;
}

- (NSURL*)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#if ABOVE_IOS_8_0 && WKWebView_Bridge
- (void)setBridge:(WebViewJavascriptBridge *)bridge {
    if (_bridge != bridge) {
        _bridge = bridge;
        
        [self registerTrackEvent];
    }
}

- (void)registerTrackEvent {
    __weak __typeof(self) weakSelf = self;
    
    void (^handler)(id, WVJBResponseCallback) = ^(id data, WVJBResponseCallback responseCallback){
        NSDictionary *parameters = (NSDictionary *)data;
        
        [weakSelf trackJSEvent: parameters];
    };
    
    [self.bridge registerHandler:@"bridgeTrack" handler:handler];
}
#endif

- (void)trackJSEvent:(NSDictionary *)parameters {
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"sdk trackJSEvent %@", parameters);
    }
    
    if (![parameters isKindOfClass: [NSDictionary class]]) {
        return;
    }
    
    NSString *eventName = @"";
    NSMutableDictionary *eventBody = [[NSMutableDictionary alloc] init];
    
    if (parameters[@"eventName"]) {
        eventName = parameters[@"eventName"];
    }
    
    if (parameters[@"eventBody"]) {
        if ([parameters[@"eventBody"] isKindOfClass: [NSDictionary class]]) {
            eventBody = [[NSMutableDictionary alloc] initWithDictionary: parameters[@"eventBody"]];
        } else if ([parameters[@"eventBody"] isKindOfClass: [NSString class]]){
            eventBody = [[NSMutableDictionary alloc] initWithDictionary:   [DatatistNSURLSessionDispatcher dictionaryWithJsonString: parameters[@"eventBody"]]];
        }
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[DatatistParameterEventName] = eventName;
    
    if (parameters[@"title"]) {
        params[DatatistParameterTitle] = parameters[@"title"];
    }
    if (parameters[@"url"]) {
        params[DatatistParameterURL] = parameters[@"url"];
    }
    
    if (parameters[@"projectId"] && [parameters[@"projectId"] isKindOfClass: [NSString class]]) {
        if (![parameters[@"projectId"] isEqualToString: self.projectId])
        {
            _projectIdH5 = parameters[@"projectId"];
            
            if (parameters[@"siteId"] && [parameters[@"siteId"] isKindOfClass: [NSString class]]) {
                _siteIDH5 = parameters[@"siteId"];
            }
        }
    }
    
    if ([eventName isEqualToString: @"pageview"]) {
        if (parameters[@"title"]) {
            _pageviewTitle = params[DatatistParameterTitle];
            
            if (self.showLog) {
                NSLog(@"seturl js %@", params[DatatistParameterTitle]);
            }
        }
        
        if (parameters[@"url"]) {
            _referrerUrl = _pageviewUrl;
            _pageviewUrl = params[DatatistParameterURL];
            
            if (self.showLog) {
                NSLog(@"seturl js %@", params[DatatistParameterURL]);
            }
        }
    } else if ([eventName isEqualToString: @"login"] || [eventName isEqualToString: @"logout"]) {
        if ([eventName isEqualToString: @"login"]) {
            NSString *userID = parameters[@"userId"];
            self.userID = userID;
        }
    }
    
    NSString *bodyString = [DatatistNSURLSessionDispatcher dicToJSONString:eventBody];
    if (bodyString) {
        params[DatatistParameterEventBody] = bodyString;
    }
    
    //新增brigeInfo
    NSMutableDictionary *brigeInfo = [NSMutableDictionary dictionary];
    if (_projectIdH5)
    {
        brigeInfo[@"sourceProjectId"] = _projectIdH5;
        brigeInfo[@"dupFlag"] = @(1);
    }
    else
    {
        brigeInfo[@"sourceProjectId"] = self.projectId;
    }
    brigeInfo[@"destProjectId"] = self.projectId;
    if (parameters[@"siteId"])
    {
        brigeInfo[@"sourceSiteId"] = parameters[@"siteId"];
    }
    brigeInfo[@"destSiteId"] = self.siteID;
    NSString *brigeInfoString = [DatatistNSURLSessionDispatcher dicToJSONString:brigeInfo];
    if (brigeInfoString) {
        params[DatatistParameterBridgeInfo] = brigeInfoString;
    }
    [self trackEventBody: params];
    
    //如果projectId不同，把H5传过来的数据上报到H5的projectId上面
    if (_projectIdH5 && _enableJSProjectIdTrack)
    {
        NSMutableDictionary *paramsH5 = [parameters mutableCopy];
        paramsH5[DatatistParameterEventBody] = bodyString;
        
        brigeInfo[@"dupFlag"] = @(0);
        NSString *brigeInfoStringH5 = [DatatistNSURLSessionDispatcher dicToJSONString:brigeInfo];
        if (brigeInfoStringH5) {
            params[DatatistParameterBridgeInfo] = brigeInfoStringH5;
        }
        [self storeEventWithParameters:paramsH5 completionBlock:^{
            if (self.dispatchInterval == 0) {
                // Trigger dispatch
                __weak typeof(self)weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf dispatch];
                });
            }
        }];
        _projectIdH5 = nil;
    }
    
    if ([eventName isEqualToString: @"logout"]) {
        self.userID = nil;
        self.userProperty = nil;
    }
}

- (void)trackClick:(NSDictionary *)parameters {
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"sdk trackClick %@", parameters);
    }
    
    if (![parameters isKindOfClass: [NSDictionary class]]) {
        return;
    }
    
    NSString *eventName;
    NSMutableDictionary *eventBody = [[NSMutableDictionary alloc] init];
    
    if (parameters[@"eventName"]) {
        eventName = parameters[@"eventName"];
    }
    
    if (parameters[@"eventBody"]) {
        if ([parameters[@"eventBody"] isKindOfClass: [NSDictionary class]]) {
            eventBody = [[NSMutableDictionary alloc] initWithDictionary: parameters[@"eventBody"]];
        } else if ([parameters[@"eventBody"] isKindOfClass: [NSString class]]){
            eventBody = [[NSMutableDictionary alloc] initWithDictionary:   [DatatistNSURLSessionDispatcher dictionaryWithJsonString: parameters[@"eventBody"]]];
        }
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (parameters[@"title"]) {
        params[DatatistParameterTitle] = parameters[@"title"];
        
        if (self.showLog) {
            NSLog(@"seturl click js %@", params[DatatistParameterTitle]);
        }
    }
    
    if (parameters[@"url"]) {
        params[DatatistParameterURL] = parameters[@"url"];
        
        if (self.showLog) {
            NSLog(@"seturl click js %@", params[DatatistParameterURL]);
        }
    }
    
    NSString *bodyString = [DatatistNSURLSessionDispatcher dicToJSONString:eventBody];
    if (bodyString) {
        params[DatatistParameterEventBody] = bodyString;
    }
    
    params[DatatistParameterEventName] = DatatistParameterClick;
    
    [self trackEventBody:params];
}

#pragma mark -- 私有工具方法
//正则表达式校验
- (BOOL)isValidateByRegex:(NSString *)regex sourceStr:(NSString *)string{
    if (!string) {
        return NO;
    }
    NSPredicate *pre = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
    return [pre evaluateWithObject:string];
}

//- (NSDictionary *)isValidateByDictionary:(NSDictionary *)dic
//{
//    if (dic)
//    {
//        NSMutableDictionary *mutDic = [NSMutableDictionary dictionaryWithDictionary:dic];
//        NSArray *keys = mutDic.allKeys;
//        [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//
//            if (obj && [obj isKindOfClass:[NSString class]])
//            {
//                if (![self isValidateByRegex:@"^\\w+$" sourceStr:obj]) {
//                    [mutDic removeObjectForKey:obj];
//                }
//            }
//
//        }];
//    }
//}
@end



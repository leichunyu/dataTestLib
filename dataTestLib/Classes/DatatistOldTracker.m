//
//  DatatistOldTracker.m
//  DatatistOldTracker
//
//  Created by Mattias Levin on 3/12/13.
//  Copyright 2013 Mattias Levin. All rights reserved.
//
//  Change log: 将eventsFromStore函数中的@"date"改为@"cdt"  ---应用中报错
//  Change log: 将eventsFromStore函数中的ascending:YES改为NO ---应用中报错
//
//

#import "DatatistOldTracker.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreData/CoreData.h>
#import <CoreLocation/CoreLocation.h>

#import "DatatistTransaction.h"
#import "DatatistTransactionItem.h"
#import "PTEventEntity.h"
#import "DatatistLocationManager.h"

#import "DatatistDispatcher.h"
#import "DatatistNSURLSessionDispatcher.h"

//#include <sys/types.h>
//#include <sys/sysctl.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "CustomType.h"
#import "UserAgent.h"
#import "NSString+Date.h"
#import "Constant.h"
#import "DatatistTracker.h"

@interface DatatistOldTracker ()

@property (nonatomic, readonly) NSString *clientID;

@property (nonatomic, strong) NSString *lastGeneratedPageURL;

@property (nonatomic) NSUInteger totalNumberOfVisits;

@property (nonatomic, readonly) NSTimeInterval firstVisitTimestamp;
@property (nonatomic) NSTimeInterval previousVisitTimestamp;
@property (nonatomic) NSTimeInterval currentVisitTimestamp;
@property (nonatomic, strong) NSDate *appDidEnterBackgroundDate;

@property (nonatomic, strong) NSMutableDictionary *screenCustomVariables;
@property (nonatomic, strong) NSMutableDictionary *visitCustomVariables;
@property (nonatomic, strong) NSDictionary *sessionParameters;
@property (nonatomic, strong) NSDictionary *staticParameters;
@property (nonatomic, strong) NSDictionary *campaignParameters;
@property (nonatomic, strong) NSDictionary *customDimensions;

@property (nonatomic, strong) id<DatatistDispatcher> dispatcher;
@property (nonatomic, strong) NSTimer *dispatchTimer;
@property (nonatomic) BOOL isDispatchRunning;

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

@end

NSString* UserDefaultKeyWithSiteID(NSString* siteID, NSString *key);

@implementation DatatistOldTracker

@synthesize totalNumberOfVisits = _totalNumberOfVisits;
@synthesize firstVisitTimestamp = _firstVisitTimestamp;
@synthesize previousVisitTimestamp = _previousVisitTimestamp;
@synthesize currentVisitTimestamp = _currentVisitTimestamp;
@synthesize clientID = _clientID;

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize operationQueue = _operationQueue;
@synthesize userID = _userID;

static DatatistOldTracker *_sharedInstance;


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


+ (instancetype)sharedInstanceWithSiteID:(NSString*)siteID baseURL:(NSURL*)baseURL {
    
    // Make sure the base url is correct
//    NSString *lastPathComponent = [baseURL lastPathComponent];
//    if ([lastPathComponent isEqualToString:@"datatist.php"] || [lastPathComponent isEqualToString:@"datatist-proxy.php"]) {
//        baseURL = [baseURL URLByDeletingLastPathComponent];
//    }
    
    return [self sharedInstanceWithSiteID:siteID dispatcher:[self defaultDispatcherWithDatatistURL:baseURL]];
}


+ (id<DatatistDispatcher>)defaultDispatcherWithDatatistURL:(NSURL*)datatistURL {
    
    NSURL *endpoint = [[NSURL alloc] initWithString:@"datatist.php" relativeToURL:datatistURL];
    
    return [[DatatistNSURLSessionDispatcher alloc] initWithDatatistURL:endpoint];
}


+ (instancetype)sharedInstanceWithSiteID:(NSString*)siteID dispatcher:(id<DatatistDispatcher>)dispatcher {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[DatatistOldTracker alloc] initWithSiteID:siteID dispatcher:dispatcher];
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
    return DatatistOldTrackerVersion;
}

- (NSOperationQueue *)operationQueue {
    if (!_operationQueue) {
        _operationQueue = [NSOperationQueue new];
        [_operationQueue setMaxConcurrentOperationCount:1];
    }
    return _operationQueue;
}


- (id)initWithSiteID:(NSString*)siteID dispatcher:(id<DatatistDispatcher>)dispatcher {
    
    if (self = [super init]) {
        
        // Initialize instance variables
        _siteID = siteID;
        _dispatcher = dispatcher;
        _dispatcher.isOldVersion = YES;
        
        _isPrefixingEnabled = YES;
        
        _sessionTimeout = DatatistDefaultSessionTimeout;
        
        _sampleRate = DatatistDefaultSampleRate;
        
        // By default a new session will be started when the tracker is created
        _sessionStart = YES;
        
        _includeDefaultCustomVariable = YES;
        
        _dispatchInterval = DatatistDefaultDispatchTimer;
        _maxNumberOfQueuedEvents = DatatistDefaultMaxNumberOfStoredEvents;
        _isDispatchRunning = NO;
        
        _eventsPerRequest = DatatistDefaultNumberOfEventsPerRequest;
        
        _locationManager = [[DatatistLocationManager alloc] init];
        _includeLocationInformation = NO;
        
        _showLog = NO;
        
        // Set default user defatult values
        NSDictionary *defaultValues = @{DatatistUserDefaultOptOutKey : @NO};
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
        
        DatatistLog(@"Tracker created with siteID %@", siteID);
        
        if (self.optOut) {
            DatatistLog(@"Tracker user optout from tracking");
        }
        
        if (_debug) {
            DatatistLog(@"Tracker in debug mode, nothing will be sent to the server");
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
    }
    else {
        return nil;
    }
}

- (void)startDispatchTimer {
    
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
    if (fabs([self.appDidEnterBackgroundDate timeIntervalSinceNow]) >= self.sessionTimeout) {
        self.sessionStart = YES;
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
                                              
                                              if (!parameters[DatatistParameterUserID] && self.userID) {
                                                  parameters[DatatistParameterUserID] = self.userID;
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

- (BOOL)sendView:(NSString*)screen {
    return [self sendView:screen withCustomVariable:nil];
}

- (BOOL)sendView:(NSString*)screen withCustomVariable:(NSDictionary *)vars {
    return [self sendWithCustomVariable:vars Views:screen, nil];
}


// Datatist support screen names with / and will group views hierarchically
- (BOOL)sendViews:(NSString*)screen, ... {
    // Collect var args
    NSMutableArray *components = [NSMutableArray array];
    va_list args;
    va_start(args, screen);
    for (NSString *arg = screen; arg != nil; arg = va_arg(args, NSString*)) {
        [components addObject:arg];
    }
    va_end(args);
    
    return [self sendViewsFromArray:components withCustomVariable:nil];
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
    
    return [self sendViewsFromArray:components withCustomVariable:vars];
}

- (BOOL)sendViewsFromArray:(NSArray*)screens {
    return [self sendViewsFromArray:screens withCustomVariable:nil];
}

- (BOOL)sendViewsFromArray:(NSArray*)screens withCustomVariable:(NSDictionary *)vars {
    
    if (self.isPrefixingEnabled) {
        // Add prefix
        NSMutableArray *prefixedScreens = [NSMutableArray arrayWithObject:DatatistPrefixView];
        [prefixedScreens addObjectsFromArray:screens];
        screens = prefixedScreens;
    }
    
    return [self send:screens withCustomVariable:vars];
}

- (BOOL)sendEventWithCategory:(NSString *)category action:(NSString *)action name:(NSString *)name value:(NSString *)value {
    return [self sendEventWithCategory:category action:action name:name value:value withCustomVariable:nil];
}

- (BOOL)sendEventWithCategory:(NSString*)category action:(NSString*)action name:(NSString*)name value:(NSString *)value withCustomVariable:(NSDictionary *)vars {
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    
    params[DatatistParameterEventCategory] = category;
    params[DatatistParameterEventAction] = action;
    if (name) {
        params[DatatistParameterEventName_1] = name;
    }
    if (value) {
        params[DatatistParameterEventValue] = value;
    }
    
    // Setting the url is mandatory
    params[DatatistParameterURL] = [self generatePageURL:nil];
    
    self.customDimensions = vars;
    
    NSDictionary *dictChangeTo1 = [self addPerRequestParameters:params];
    dictChangeTo1 = [self addSessionParameters:dictChangeTo1];
    dictChangeTo1 = [self addStaticParameters:dictChangeTo1];
    
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"[Datatist] Store event 1.0 ff with parameters %@", dictChangeTo1);
    }
    
    [self storeEvent: dictChangeTo1];
    
    return YES;
    
//    return [self queueEvent:params];
}

- (BOOL)sendEventWithCategory:(NSString*)category action:(NSString*)action name:(NSString*)name withCustomVariable:(NSDictionary *)vars {
    
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    
    params[DatatistParameterEventCategory] = category;
    params[DatatistParameterEventAction] = action;
    if (name) {
        params[DatatistParameterEventName_1] = name;
    }
    
    // Setting the url is mandatory
    params[DatatistParameterURL] = [self generatePageURL:nil];
    
    self.customDimensions = vars;
    
    NSDictionary *dictChangeTo1 = [self addPerRequestParameters:params];
    dictChangeTo1 = [self addSessionParameters:dictChangeTo1];
    dictChangeTo1 = [self addStaticParameters:dictChangeTo1];
    
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"[Datatist] Store event 1.0 ff with parameters %@", dictChangeTo1);
    }
    
    [self storeEvent: dictChangeTo1];
    
    return YES;
    
//    return [self queueEvent:params];
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

- (BOOL)send:(NSArray*)components withCustomVariable:(NSDictionary *)vars {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    NSString *actionName = [components componentsJoinedByString:@"/"];
    params[DatatistParameterActionName] = actionName;
    
    // Setting the url is mandatory
    params[DatatistParameterURL] = [self generatePageURL:components];
    
    self.customDimensions = vars;
    
    NSDictionary *dictChangeTo1 = [self addPerRequestParameters:params];
    dictChangeTo1 = [self addSessionParameters:dictChangeTo1];
    dictChangeTo1 = [self addStaticParameters:dictChangeTo1];
    
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"[Datatist] Store event 1.0 ff with parameters %@", dictChangeTo1);
    }
    
    [self storeEvent: dictChangeTo1];
    
    return YES;
    
//    return [self queueEvent:params];
}

- (BOOL)sendScreenTransaction:(DatatistTransaction *)transaction {
    if (self.customDimensions) {
        NSMutableDictionary *customVar = [[NSMutableDictionary alloc] initWithDictionary:self.customDimensions];
        customVar[@"OrderId"] = transaction.identifier;
        self.customDimensions = nil;
        return [self sendView:@"OrderCreation" withCustomVariable:customVar];
    } else {
        return [self sendView:@"OrderCreation" withCustomVariable:@{@"OrderId" : transaction.identifier}];
    }
}

- (BOOL)sendTransaction:(DatatistTransaction *)transaction {
    return [self sendTransaction:transaction withCustomVariable:nil];
}

- (BOOL)sendTransaction:(DatatistTransaction*)transaction withCustomVariable:(NSDictionary *)vars {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    params[DatatistParameterTransactionIdentifier] = transaction.identifier;
    // Must idgoal=0 or revenue parameter will be ignored
    params[DatatistParameterGoalID] = @(0);
    params[DatatistParameterRevenue] = transaction.grandTotal;
    if (transaction.grandTotal && transaction.shippingCost) {
        params[DatatistParameterTransactionSubTotal] = @(transaction.grandTotal.floatValue - transaction.shippingCost.floatValue);
    }
    
    params[DatatistParameterTransactionTax] = 0;
    
    if (transaction.shippingCost) {
        params[DatatistParameterTransactionShipping] = transaction.shippingCost;
    }
    if (transaction.discount) {
        params[DatatistParameterTransactionDiscount] = transaction.discount;
    }
    if (transaction.items.count > 0) {
        // Items should be a JSON encoded string
        params[DatatistParameterTransactionItems] = [self JSONEncodeTransactionItems:transaction.items];
    }
    
    // Setting the url is mandatory
    params[DatatistParameterURL] = [self generatePageURL:nil];
    
    self.customDimensions = vars;
    [self sendScreenTransaction:transaction];
    
    return YES;
//    return [self queueEvent:params];
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


- (BOOL)setCustomVariableForIndex:(NSUInteger)index name:(NSString*)name value:(NSString*)value scope:(CustomVariableScope)scope {
    
    NSParameterAssert(index > 0);
    NSParameterAssert(name);
    NSParameterAssert(value);
    
    if (index < 1) {
        DatatistLog(@"Custom variable index must be > 0");
        return NO;
    } else if (scope == VisitCustomVariableScope && self.includeDefaultCustomVariable && index <= 3) {
        DatatistLog(@"Custom variable index conflicting with default indexes used by the SDK. Change index or turn off default default variables");
        return NO;
    }
    
    CustomVariable *customVariable = [[CustomVariable alloc] initWithIndex:index name:name value:value];
    
    if (scope == VisitCustomVariableScope) {
        
        if (!self.visitCustomVariables) {
            self.visitCustomVariables = [NSMutableDictionary dictionary];
        }
        self.visitCustomVariables[@(index)] = customVariable;
        
        // Force generation of session parameters
        self.sessionParameters = nil;
        
    } else if (scope == ScreenCustomVariableScope) {
        
        if (!self.screenCustomVariables) {
            self.screenCustomVariables = [NSMutableDictionary dictionary];
        }
        self.screenCustomVariables[@(index)] = customVariable;
        
    }
    
    return YES;
}

- (BOOL)setCustomDimensionWithParamters:(NSDictionary *)params {
//    NSParameterAssert(params);
    
    if (!params || [[params allKeys] count] == 0) {
        DatatistLog(@"Custom dimension is empty!");
        return NO;
    }
    
    self.customDimensions = params;
    return YES;
}

- (NSString *)serialCustomDimension {
    if (self.customDimensions) {
        NSMutableString *string = [NSMutableString stringWithFormat:@"["];
        for (NSString *key in self.customDimensions.allKeys) {
            [string appendString:[NSString stringWithFormat:@"{keyName:%@, keyValue:%@},",key, [self.customDimensions objectForKey:key]]];
        }
        
        [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
        [string appendString:@"]"];
        
        self.customDimensions = nil;
        return string;
    } else {
        return nil;
    }
}

- (BOOL)queueEvent:(NSDictionary*)parameters {
    
    // OptOut check
    if (self.optOut) {
        // User opted out from tracking, to nothing
        // Still return YES, since returning NO is considered an error
        return YES;
    }
    
    // Use the sampling rate to decide if the event should be queued or not
    if (self.sampleRate != 100 && self.sampleRate < (arc4random_uniform(101))) {
        // Outsampled, do not queue
        return YES;
    }
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithObjectsAndKeys: @"event1.0",@"e_c", nil];

    if (parameters[DatatistParameterEventBody]) {
        NSMutableDictionary *dictEN = [NSMutableDictionary dictionaryWithDictionary: [DatatistNSURLSessionDispatcher dictionaryWithJsonString: parameters[DatatistParameterEventBody]]];
        
        if (parameters[DatatistParameterEventName] && ([parameters[DatatistParameterEventName] isEqualToString: DatatistParameterLogin])) //  || [parameters[DatatistParameterEventName] isEqualToString: DatatistParameterRegister]
        {
            dictEN[DatatistParameterUserID] = self.userID;
        }
        
        if (parameters[DatatistParameterEventName] && [parameters[DatatistParameterEventName] isEqualToString: DatatistParameterSearch])
        {
            dict[@"search"] = dictEN[@"keyword"];
        }
        
        if (parameters[DatatistParameterEventName] && [parameters[DatatistParameterEventName] isEqualToString: DatatistParameterPageView])
        {
            id udVariable = dictEN[DatatistParameterUdVariable];

            if ([udVariable isKindOfClass: [NSDictionary class]]) {
                [self setCustomDimensionWithParamters: udVariable];
            }
            
            [dictEN removeObjectForKey: DatatistParameterUdVariable];
            
            [dict removeObjectForKey: @"e_c"];
            
            dict[@"action_name"] = parameters[DatatistParameterTitle];
            
            if (parameters[DatatistParameterTitle]) {
                dict[DatatistParameterTitle] = parameters[DatatistParameterTitle];
            }

            if (parameters[DatatistParameterURL]) {
                dict[DatatistParameterURL] = parameters[DatatistParameterURL];
                
                if ([dict[DatatistParameterURL] rangeOfString: @"utm_campaign"].location != NSNotFound) {
                    self.sessionStart = YES;
                }
            }
        } else {
            dict[@"e_n"] = [DatatistNSURLSessionDispatcher dicToJSONString: dictEN];
        }
    }
    
    if (parameters[DatatistParameterEventName]) {
        dict[@"e_a"] = parameters[DatatistParameterEventName];
    }
    
    if (parameters[DatatistParameterTransactionItems]) {
        dict[DatatistParameterTransactionItems] = parameters[DatatistParameterTransactionItems];
        dict[DatatistParameterRevenue] = parameters[DatatistParameterRevenue];
        dict[DatatistParameterTransactionShipping] = parameters[DatatistParameterTransactionShipping];
        dict[DatatistParameterTransactionSubTotal] = parameters[DatatistParameterTransactionSubTotal];
        
        dict[@"idgoal"] = @"0";
        
        if (!dict[@"e_n"])
        {
            dict[@"e_n"] = @"";
        }
    }
    
    if (parameters[DatatistParameterEventName] && [parameters[DatatistParameterEventName] isEqualToString: DatatistParameterSearch])
    {
        [dict removeObjectForKey: @"e_n"];
        [dict removeObjectForKey: @"e_c"];
        [dict removeObjectForKey: @"e_a"];
    }
    
    dict[@"ec_tx"] = @(0);
    
    if (parameters[DatatistParameterTransactionIdentifier]) {
        dict[DatatistParameterTransactionIdentifier] = parameters[DatatistParameterTransactionIdentifier];
    }
    
//    if (parameters[DatatistParameterSessionId]) {
//        dict[DatatistParameterSessionId] = parameters[DatatistParameterSessionId];
//    }
//    if (parameters[DatatistParameterSessionStartTime]) {
//        dict[DatatistParameterSessionStartTime] = parameters[DatatistParameterSessionStartTime];
//    }

    NSDictionary *dictChangeTo1 = [self addPerRequestParameters:dict];
    dictChangeTo1 = [self addSessionParameters:dictChangeTo1];
    dictChangeTo1 = [self addStaticParameters:dictChangeTo1];
    
    if ([DatatistTracker sharedInstance].showLog) {
        NSLog(@"[Datatist] Store event 1.0 with parameters %@", dictChangeTo1);
    }
    
    [self storeEvent: dictChangeTo1];
    
    return YES;
}

- (void)storeEvent:(NSDictionary*)parameters
{
    [self storeEventWithParameters:parameters completionBlock:^{
        
        if (self.dispatchInterval == 0) {
            // Trigger dispatch
            __weak typeof(self)weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf dispatch];
            });
        }
    }];
}

- (NSDictionary*)addPerRequestParameters:(NSDictionary*)parameters {
    
    NSMutableDictionary *joinedParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    
    // User id
    if (self.userID && self.userID.length > 0) {
        joinedParameters[DatatistParameterUserID] = self.userID;
    }
    
    joinedParameters[DatatistParameterDeviceId] = self.clientID;
    
    // Custom parameters
    if (![parameters objectForKey:DatatistParameterTransactionIdentifier]
        && ![parameters objectForKey:DatatistParameterGoalID]
        && ![parameters objectForKey:DatatistParameterSearchKeyword]) {
        NSString *systemVarString = [NSString stringWithFormat:@"{Lifetime_seq:%@}", [NSString stringWithFormat:@"%llu", [[UserAgent sharedInstance] sn]]];
        [self setCustomVariableForIndex:5 name:@"systemvariable" value:systemVarString scope:ScreenCustomVariableScope];
    }
    
    NSString *dimensionString = [self serialCustomDimension];
    if (dimensionString) {
        [self setCustomVariableForIndex:4 name:@"customvariable" value:dimensionString scope:ScreenCustomVariableScope];
    }
    
    if (self.screenCustomVariables) {
        joinedParameters[DatatistParameterScreenScopeCustomVariables] = [DatatistOldTracker JSONEncodeCustomVariables:self.screenCustomVariables];
        self.screenCustomVariables = nil;
    }
    
    // Add campaign parameters if they are set
    if (self.campaignParameters.count > 0) {
        [joinedParameters addEntriesFromDictionary:self.campaignParameters];
        self.campaignParameters = nil;
    }
    
    // Add random number (cache buster)
    int randomNumber = arc4random_uniform(50000);
    joinedParameters[DatatistParameterRandomNumber] = [NSString stringWithFormat:@"%ld", (long)randomNumber];
    
    // Location
    if (self.includeLocationInformation) {
        // The first request for location will ask the user for permission
        CLLocation *location = self.locationManager.location;
        if (location) {
            joinedParameters[DatatistParameterLatitude] = @(location.coordinate.latitude);
            joinedParameters[DatatistParameterLongitude] = @(location.coordinate.longitude);
        }
    }
    
    // Add local time
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute |  NSCalendarUnitSecond;
    NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:now];
    joinedParameters[DatatistParameterHours] = [NSString stringWithFormat:@"%ld", (long)[dateComponents hour]];
    joinedParameters[DatatistParameterMinutes] = [NSString stringWithFormat:@"%ld", (long)[dateComponents minute]];
    joinedParameters[DatatistParameterSeconds] = [NSString stringWithFormat:@"%ld", (long)[dateComponents second]];
    
    // Add UTC time
    static NSDateFormatter *UTCDateFormatter = nil;
    if (!UTCDateFormatter) {
        UTCDateFormatter = [[NSDateFormatter alloc] init];
        UTCDateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        UTCDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    }
    joinedParameters[DatatistParameterDateAndTime] = [UTCDateFormatter stringFromDate:now];
    
    return joinedParameters;
}

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
        joinedParameters[DatatistParameterSessionStart_1] = @"1";
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
        joinedParameters[DatatistParameterVisitScopeCustomVariables] = [DatatistOldTracker JSONEncodeCustomVariables:self.visitCustomVariables];
    }

    return joinedParameters;
}

- (NSString *)deviceInfo {
    UserAgent *ua = [UserAgent sharedInstance];

    if (self.pushClientId && self.pushType) {
        return [NSString stringWithFormat:@"{App_Name : %@, App_Version : %@, OS_Version : %@, Platform : %@, SDK_Version : %@, Push_ClientId: %@, Push_Type: %@}", ua.appName, ua.appVersion, ua.osVersion, ua.platformName, DatatistOldTrackerVersion, self.pushClientId, self.pushType];
    } else {
        return [NSString stringWithFormat:@"{App_Name : %@, App_Version : %@, OS_Version : %@, Platform : %@, SDK_Version : %@}", ua.appName, ua.appVersion, ua.osVersion, ua.platformName, DatatistOldTrackerVersion];
    }
}

- (NSDictionary*)addStaticParameters:(NSDictionary*)parameters {
    
    if (!self.staticParameters) {
        NSMutableDictionary *staticParameters = [NSMutableDictionary dictionary];
        
        staticParameters[DatatistParameterSiteID_1] = self.siteID;
        
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
            
//            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
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
            
//            [self.dispatcher sendBulkEventWithParameters:requestParameters success:successBlock failure:failureBlock];

//                if (events.count == 1)
//                {
//                    [self.dispatcher sendSingleEventWithParameters:requestParameters success:successBlock failure:failureBlock];
//                } else
                {
                    [self.dispatcher sendBulkEventWithParameters:requestParameters success:successBlock failure:failureBlock];
                }
//            }];
//            [self.operationQueue addOperation:operation];
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
            
            //            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
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
            //            }];
            //            [self.operationQueue addOperation:operation];
        }
    }];
}

- (NSDictionary*)requestParametersForEvents:(NSArray*)events {
//    if (events.count == 1) {
//        // Send events as query parameters
//        return [events objectAtIndex:0];
//
//    } else
    {
        
        // Send events as JSON encoded post body
        NSMutableDictionary *JSONParams = [NSMutableDictionary dictionaryWithCapacity:2];
        
        NSComparator comparator = ^(id first, id second) {
            NSString *cdt1 = first[DatatistParameterDateAndTime];
            NSString *cdt2 = second[DatatistParameterDateAndTime];
            
            NSComparisonResult order = [cdt1 compare:cdt2];
            if (order == NSOrderedSame) {
                NSNumber *sn1 = [self snInEvent:first];
                NSNumber *sn2 = [self snInEvent:second];
                
                if (!sn1 || !sn2 ) {
                    return order;
                }else if (sn1.integerValue < sn2.integerValue) {
                    return NSOrderedAscending;
                } else if (sn1.integerValue > sn2.integerValue) {
                    return NSOrderedDescending;
                } else {
                    return NSOrderedSame;
                }
            } else {
                return order;
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
        
        // Datatist server will process each record in the batch request in reverse order, not sure if this is a bug
        // Build the request in revers order
//        NSEnumerationOptions enumerationOption = NSEnumerationConcurrent;
//        [sortEvents enumerateObjectsWithOptions:enumerationOption usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//            
//            NSDictionary *params = (NSDictionary*)obj;
//            
//            // As of Datatist 2.0 the query string should not be url encoded in the request body
//            // Unfortenatly the DTNetworking methods for create parameter pairs are not external
//            NSMutableArray *parameterPair = [NSMutableArray arrayWithCapacity:params.count];
//            [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
//                [parameterPair addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
//            }];
//            
//            NSString *queryString = [NSString stringWithFormat:@"?%@", [parameterPair componentsJoinedByString:@"&"]];
//            
//            [queryStrings addObject:queryString];
//            
//        }];
        
        JSONParams[@"requests"] = queryStrings;
        //    DLog(@"Bulk request:\n%@", JSONParams);
        
        return JSONParams;
    }
}

- (NSNumber *)snInEvent:(NSDictionary *)event {
    NSString *screenCustomVariable = event[DatatistParameterScreenScopeCustomVariables];
    if (!screenCustomVariable) {
        return nil;
    }
    
    NSData *data = [screenCustomVariable dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
    if (error) {
        return nil;
    }
    
    NSArray *array = dic[@"5"];
    __block NSNumber *sn = nil;
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *string = (NSString *)obj;
        if ([string containsString:@"Lifetime_seq"]) {
            NSArray *components = [string componentsSeparatedByString:@":"];
            sn = @([components.lastObject integerValue]);
        }
    }];
   
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

- (void)setDebug:(BOOL)debug {
    
    if (debug && !_debug) {
        DatatistDebugDispatcher *debugDispatcher = [[DatatistDebugDispatcher alloc] init];
        debugDispatcher.wrappedDispatcher = self.dispatcher;
        self.dispatcher = debugDispatcher;
    } else if (!debug && [self.dispatcher isKindOfClass:[DatatistDebugDispatcher class]]) {
        self.dispatcher = ((DatatistDebugDispatcher*)self.dispatcher).wrappedDispatcher;
    }
    
    _debug = debug;
}

- (void)setOptOut:(BOOL)optOut {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:optOut forKey:DatatistUserDefaultOptOutKey];
    [userDefaults synchronize];
}

- (BOOL)optOut {
    return [[NSUserDefaults standardUserDefaults] boolForKey:DatatistUserDefaultOptOutKey];
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
        DatatistLog(@"clientID: %@",_clientID);
    }
    
    return _clientID;
}

inline NSString* UserDefaultKeyWithSiteID(NSString *siteID, NSString *key) {
    return [NSString stringWithFormat:@"%@_%@", siteID, key];
}

- (void)setCurrentVisitTimestamp:(NSTimeInterval)currentVisitTimestamp {
    
    self.previousVisitTimestamp = _currentVisitTimestamp;
    
    _currentVisitTimestamp = currentVisitTimestamp;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setDouble:_currentVisitTimestamp forKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultCurrentVisitTimestampKey)];
    [userDefaults synchronize];
}

- (NSTimeInterval)currentVisitTimestamp {
    
    if (_currentVisitTimestamp == 0) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        _currentVisitTimestamp = [userDefaults doubleForKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultCurrentVisitTimestampKey)];
        
        if (_currentVisitTimestamp == 0) {
            // If still no value, create one
            _currentVisitTimestamp = [[NSDate date] timeIntervalSince1970];
            [userDefaults setDouble:_currentVisitTimestamp  forKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultCurrentVisitTimestampKey)];
            [userDefaults synchronize];
        }
    }
    
    return _currentVisitTimestamp;
}

- (void)setPreviousVisitTimestamp:(NSTimeInterval)previousVisitTimestamp {
    
    _previousVisitTimestamp = previousVisitTimestamp;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setDouble:previousVisitTimestamp forKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultPreviousVistsTimestampKey)];
    [userDefaults synchronize];
}

- (NSTimeInterval)previousVisitTimestamp {
    
    if (_previousVisitTimestamp == 0) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        _previousVisitTimestamp = [userDefaults doubleForKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultPreviousVistsTimestampKey)];
        
        if (_previousVisitTimestamp == 0) {
            // If still no value, create one
            _previousVisitTimestamp = [[NSDate date] timeIntervalSince1970];
            [userDefaults setDouble:_previousVisitTimestamp  forKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultPreviousVistsTimestampKey)];
            [userDefaults synchronize];
        }
        
    }
    
    return _previousVisitTimestamp;
}

- (NSTimeInterval)firstVisitTimestamp {
    
    if (_firstVisitTimestamp == 0) {
        
        // Get the value from user defaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        _firstVisitTimestamp = [userDefaults doubleForKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultFirstVistsTimestampKey)];
        
        if (_firstVisitTimestamp == 0) {
            // If still no value, create one
            _firstVisitTimestamp = [[NSDate date] timeIntervalSince1970];
            [userDefaults setDouble:_firstVisitTimestamp  forKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultFirstVistsTimestampKey)];
            [userDefaults synchronize];
        }
    }
    
    return _firstVisitTimestamp;
}

- (void)setTotalNumberOfVisits:(NSUInteger)numberOfVisits {
    
    _totalNumberOfVisits = numberOfVisits;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:numberOfVisits forKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultTotalNumberOfVisitsKey)];
    [userDefaults synchronize];
}

- (NSUInteger)totalNumberOfVisits {
    
    if (_totalNumberOfVisits <= 0) {
        // Read value from user defaults
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        _totalNumberOfVisits = [userDefaults integerForKey:UserDefaultKeyWithSiteID(self.siteID, DatatistUserDefaultTotalNumberOfVisitsKey)];
    }
    
    return _totalNumberOfVisits;
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
            eventEntity.datatistRequestParameters = [NSKeyedArchiver archivedDataWithRootObject:parameters];
            eventEntity.date = [NSString dateFromString:[parameters objectForKey:DatatistParameterDateAndTime] ForDateFormatter:nil];
            
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
    
//    NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"DatatistOldTrackerModel" ofType:@"bundle"];
//    NSLog(@"model path: %@", modelPath);
//    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle bundleWithPath:modelPath]]];

//    NSURL *modelURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"DatatistOldTracker" withExtension:@"momd"];
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
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"DatatistOldTracker"];
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
@end


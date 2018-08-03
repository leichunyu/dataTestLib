//
//  Constant.h
//  DatatistTrackerDemo
//
//  Created by sky on 2017/12/24.
//  Copyright © 2017年 YunfengQi. All rights reserved.
//

#ifndef Constant_h
#define Constant_h

// SDK Version
static NSString * const DatatistTrackerVersion = @"2.2.1";
#define kDatatistUserId @"kDatatistUserId"


// Notifications
static NSString * const DatatistSessionStartNotification = @"DatatistSessionStartNotification";


// Datatist query parameter names
//---------------------------------- Identify Info -------------------------------------
static NSString * const DatatistParameterSiteID = @"siteId";
static NSString * const DatatistParameterEventTime = @"eventTime";
static NSString * const DatatistParameterDeviceId = @"deviceId";
static NSString * const DatatistParameterSessionId = @"sessionId";
static NSString * const DatatistParameterSessionStartTime = @"seStartTime";
static NSString * const DatatistParameterUserId = @"userId";
static NSString * const DatatistParameterChannelId = @"channelId";
static NSString * const DatatistParameterSerialNumber = @"sn";

static NSString * const DatatistParameterProjectId = @"projectId";
static NSString * const DatatistParameterUserProperty = @"userProperty";
static NSString * const DatatistParameterBridgeInfo = @"bridgeInfo";

//---------------------------------- User Agent ----------------------------------------
static NSString * const DatatistParameterUserAgentName = @"uaName";
static NSString * const DatatistParameterUserAgentBuild = @"uaBuild";
static NSString * const DatatistParameterUserAgentMajor = @"uaMajor";
static NSString * const DatatistParameterUserAgentMinor = @"uaMinor";
static NSString * const DatatistParameterUserAgentRevision = @"uaRevision";
static NSString * const DatatistParameterUserAgentOS = @"uaOs";
static NSString * const DatatistParameterUserAgentOSMajor = @"uaOsMajor";
static NSString * const DatatistParameterUserAgentOSMinor = @"uaOsMinor";
static NSString * const DatatistParameterUserAgentDevice = @"uaDevice";
static NSString * const DatatistParameterResolution = @"resolution";
static NSString * const DatatistParameterLanguage = @"language";
static NSString * const DatatistParameterNetType = @"netType";


//---------------------------------- Geo Info -----------------------------------------
static NSString * const DatatistParameterIP = @"ip";
static NSString * const DatatistParameterContinentCode = @"continentCode";
static NSString * const DatatistParameterCountry = @"country";
static NSString * const DatatistParameterRegion = @"region";
static NSString * const DatatistParameterCity = @"city";
static NSString * const DatatistParameterLatitude = @"lat";
static NSString * const DatatistParameterLongitude = @"lgt";


//---------------------------------- Page Info ---------------------------------------
static NSString * const DatatistParameterURL = @"url";
static NSString * const DatatistParameterTitle = @"title";

static NSString * const DatatistParameterReferrerUrl = @"referrer";


//---------------------------------- Event Info --------------------------------------
static NSString * const DatatistParameterEventName = @"eventName";
static NSString * const DatatistParameterEventBody = @"eventBody";
static NSString * const DatatistParameterCustomVariable = @"customerVar";
static NSString * const DatatistParameterPageView = @"pageview";
static NSString * const DatatistParameterRegister = @"register";
static NSString * const DatatistParameterSessionStart = @"newVisit";
static NSString * const DatatistParameterUdVariable = @"udVariable";
static NSString * const DatatistParameterClick = @"click";

//---------------------------------- Search Event ------------------------------------
static NSString * const DatatistParameterSearch = @"search";
static NSString * const DatatistParameterKeyword = @"keyword";
static NSString * const DatatistParameterRecommendationSearchFlag = @"recommendationSearchFlag";
static NSString * const DatatistParameterHistorySearchFlag = @"historySearchFlag";


//-------------------------------- Register Evnet ------------------------------------
static NSString * const DatatistParameterType = @"type";
static NSString * const DatatistParameterAuthenticated = @"authenticated";


//-------------------------------- Product Event -------------------------------------
static NSString * const DatatistParameterProductPage = @"productPage";
static NSString * const DatatistParameterSKU = @"sku";
static NSString * const DatatistParameterProductCategory1 = @"productCategory1";
static NSString * const DatatistParameterProductCategory2 = @"productCategory2";
static NSString * const DatatistParameterProductCategory3 = @"productCategory3";
static NSString * const DatatistParameterProductOriginalPrice = @"productOriginalPrice";
static NSString * const DatatistParameterProductRealPrice = @"productRealPrice";


//-------------------------------- Add Cart Event ------------------------------------
static NSString * const DatatistParameterAddCart = @"addCart";
static NSString * const DatatistParameterProductQuantity = @"productQuantity";


//-------------------------------- Order Event ---------------------------------------
static NSString * const DatatistParameterOrder = @"order";
static NSString * const DatatistParameterOrderInfo = @"orderInfo";
static NSString * const DatatistParameterCouponInfo = @"couponInfo";
static NSString * const DatatistParameterProductInfo = @"productInfo";


//-------------------------------- Payment Event -------------------------------------
static NSString * const DatatistParameterPayment = @"payment";
static NSString * const DatatistParameterOrderID = @"orderID";
static NSString * const DatatistParameterPayMethod = @"payMethod";
static NSString * const DatatistParameterPayAMT = @"payAMT";
static NSString * const DatatistParameterPayStatus = @"payStatus";


//-------------------------------- PreCharge Event -----------------------------------
static NSString * const DatatistParameterPreCharge = @"preCharge";
static NSString * const DatatistParameterChargeAMT = @"chargeAMT";
static NSString * const DatatistParameterChargeMethod = @"chargeMethod";
static NSString * const DatatistParameterCouponAMT = @"couponAMT";

//-------------------------------- trackJPush Event -----------------------------------
static NSString * const DatatistParameterTrackJPush = @"jPush";
static NSString * const DatatistPushInfoAlias = @"alias";
static NSString * const DatatistPushInfoRegistrationID = @"registrationID";
static NSString * const DatatistPushInfoTag = @"tag";
static NSString * const DatatistPushInfo = @"pushInfo";
static NSString * const DatatistPushContent = @"pushContent";
static NSString * const DatatistpushExtraDcid = @"dcid";
static NSString * const DatatistpushExtraDtg = @"dtg";

//-------------------------------- trackOpenChannel Event -----------------------------------
static NSString * const DatatistParameterTrackOpenChannel = @"openChannel";
static NSString * const DatatistParameterTrackOpenChannelName = @"openChannelName";

static NSString * const DatatistParameterTrackInitJPush = @"initJPush";
static NSString * const DatatistpushManager = @"pushManager";

//-------------------------------- Login Event --------------------------------------
static NSString * const DatatistParameterLogin = @"login";
static NSString * const DatatistParameterLogout = @"logout";


// Default values
static NSUInteger const DatatistDefaultSessionTimeout = 1800;
static NSUInteger const DatatistDefaultDispatchTimer = 20;  //120;
static NSUInteger const DatatistDefaultMaxNumberOfStoredEvents = 500;
//static NSUInteger const DatatistDefaultSampleRate = 100;
static NSUInteger const DatatistDefaultNumberOfEventsPerRequest = 10;
//static NSUInteger const DatatistExceptionDescriptionMaximumLength = 50;


// Incoming campaign URL parameters
static NSString * const DatatistURLCampaignName = @"pk_campaign";
static NSString * const DatatistURLCampaignKeyword = @"pk_kwd";



// 1.0
// SDK Version
static NSString * const DatatistOldTrackerVersion = DatatistTrackerVersion;  // @"2.1.2";
#define kDatatistUserId @"kDatatistUserId"


// Notifications

// User default keys
// The key withh include the site id in order to support multiple trackers per application
static NSString * const DatatistUserDefaultTotalNumberOfVisitsKey = @"DatatistTotalNumberOfVistsKey";
static NSString * const DatatistUserDefaultCurrentVisitTimestampKey = @"DatatistCurrentVisitTimestampKey";
static NSString * const DatatistUserDefaultPreviousVistsTimestampKey = @"DatatistPreviousVistsTimestampKey";
static NSString * const DatatistUserDefaultFirstVistsTimestampKey = @"DatatistFirstVistsTimestampKey";
static NSString * const DatatistUserDefaultVisitorIDKey = @"DatatistVisitorIDKey";
static NSString * const DatatistUserDefaultOptOutKey = @"DatatistOptOutKey";

// Datatist query parameter names
static NSString * const DatatistParameterSiteID_1 = @"idsite";
static NSString * const DatatistParameterRecord = @"rec";
static NSString * const DatatistParameterAPIVersion = @"apiv";
static NSString * const DatatistParameterScreenReseloution = @"res";
static NSString * const DatatistParameterHours = @"h";
static NSString * const DatatistParameterMinutes = @"m";
static NSString * const DatatistParameterSeconds = @"s";
static NSString * const DatatistParameterDateAndTime = @"cdt";
static NSString * const DatatistParameterActionName = @"action_name";
static NSString * const DatatistParameterVisitorID = @"_id";
static NSString * const DatatistParameterUserID = @"uid";
static NSString * const DatatistParameterVisitScopeCustomVariables = @"_cvar";
static NSString * const DatatistParameterScreenScopeCustomVariables = @"cvar";
static NSString * const DatatistParameterRandomNumber = @"r";
static NSString * const DatatistParameterFirstVisitTimestamp = @"_idts";
static NSString * const DatatistParameterPreviousVisitTimestamp = @"_viewts";
static NSString * const DatatistParameterTotalNumberOfVisits = @"_idvc";
static NSString * const DatatistParameterGoalID = @"idgoal";
static NSString * const DatatistParameterRevenue = @"revenue";
static NSString * const DatatistParameterSessionStart_1 = @"new_visit";
static NSString * const DatatistParameterLanguage_1 = @"lang";
static NSString * const DatatistParameterSearchKeyword = @"search";
static NSString * const DatatistParameterSearchCategory = @"search_cat";
static NSString * const DatatistParameterSearchNumberOfHits = @"search_count";
static NSString * const DatatistParameterLink = @"link";
static NSString * const DatatistParameterDownload = @"download";
static NSString * const DatatistParameterSendImage = @"send_image";
// Ecommerce
static NSString * const DatatistParameterTransactionIdentifier = @"ec_id";
static NSString * const DatatistParameterTransactionSubTotal = @"ec_st";
static NSString * const DatatistParameterTransactionTax = @"ec_tx";
static NSString * const DatatistParameterTransactionShipping = @"ec_sh";
static NSString * const DatatistParameterTransactionDiscount = @"ec_dt";
static NSString * const DatatistParameterTransactionItems = @"ec_items";
// Campaign
static NSString * const DatatistParameterReferrer = @"urlref";
static NSString * const DatatistParameterCampaignName = @"_rcn";
static NSString * const DatatistParameterCampaignKeyword = @"_rck";
// Events
static NSString * const DatatistParameterEventCategory = @"e_c";
static NSString * const DatatistParameterEventAction = @"e_a";
static NSString * const DatatistParameterEventName_1 = @"e_n";
static NSString * const DatatistParameterEventValue = @"e_v";
// Content impression
static NSString * const DatatistParameterContentName = @"c_n";
static NSString * const DatatistParameterContentPiece = @"c_p";
static NSString * const DatatistParameterContentTarget = @"c_t";
static NSString * const DatatistParameterContentInteraction = @"c_i";

// Datatist default parmeter values
static NSString * const DatatistDefaultRecordValue = @"1";
static NSString * const DatatistDefaultAPIVersionValue = @"1";
static NSString * const DatatistDefaultContentInteractionName = @"tap";

// Default values
static NSUInteger const DatatistDefaultSampleRate = 100;

static NSUInteger const DatatistExceptionDescriptionMaximumLength = 50;

// Page view prefix values
static NSString * const DatatistPrefixView = @"screen";
static NSString * const DatatistPrefixEvent = @"event";
static NSString * const DatatistPrefixException = @"exception";
static NSString * const DatatistPrefixExceptionFatal = @"fatal";
static NSString * const DatatistPrefixExceptionCaught = @"caught";
static NSString * const DatatistPrefixSocial = @"social";


#endif /* Constant_h */

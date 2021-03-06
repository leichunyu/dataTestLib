//
//  DatatistLocationManager.h
//  DatatistTracker
//
//  Created by Mattias Levin on 10/13/13.
//  Copyright (c) 2013 Mattias Levin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>


@interface DatatistLocationManager : NSObject

@property (nonatomic, strong, readonly) CLLocation *location;

//- (void)startMonitoringLocationChanges;
//- (void)stopMonitoringLocationChanges;
- (void)starUpdateLocation;
- (void)stopUpdataLocation;
@end


//
//  DatatistProductInfo.m
//  DatatistTracker
//
//  Created by 张继鹏 on 17/10/2017.
//  Copyright © 2017 Datatist. All rights reserved.
//

#import "DatatistProductInfo.h"
#import "float.h"

@implementation DatatistProductInfo

- (instancetype)init {
    self = [super init];
    if (self) {
        self.productCategory = @"";
        self.productOriPrice = -1;
    }
    return self;
}

@end

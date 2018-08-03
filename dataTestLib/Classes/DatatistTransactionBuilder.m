//
//  DatatistTransactionBuilder.m
//  DatatistTracker
//
//  Created by Mattias Levin on 19/01/14.
//  Copyright (c) 2014 Mattias Levin. All rights reserved.
//

#import "DatatistTransactionBuilder.h"
#import "DatatistTransaction.h"
#import "DatatistTransactionItem.h"
#import "CustomType.h"


@implementation DatatistTransactionBuilder


- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}


- (void)addItemWithSku:(NSString*)sku {
    DatatistTransactionItem *item = [DatatistTransactionItem itemWithSKU:sku];
    [self addTransactionItem:item];
}


- (void)addItemWithSku:(NSString*)sku
                  name:(NSString*)name
              category:(NSString*)category
                 price:(float)price
              quantity:(NSUInteger)quantity {
    
    DatatistTransactionItem *item = [DatatistTransactionItem itemWithSku:sku name:name category:category price:price quantity:quantity];
    [self addTransactionItem:item];
}


- (void)addTransactionItem:(DatatistTransactionItem*)item {
    [self.items addObject:item];
}


- (DatatistTransaction*)build {
    
    // Verify that mandatory parameters have been set
    __block BOOL isTransactionValid = [self.identifier isKindOfClass: [NSString class]] && self.identifier.length > 0 && self.grandTotal;
    
    [self.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        DatatistTransactionItem *item = (DatatistTransactionItem*)obj;
        if (!item.isValid) {
            isTransactionValid = NO;
            *stop = YES;
        }
    }];
    
    if (isTransactionValid) {
        return [[DatatistTransaction alloc] initWithBuilder:self];
    } else {
        DatatistDebugLog(@"Failed to build transaction, missing mandatory parameters");
        return nil;
    }
    
}


@end

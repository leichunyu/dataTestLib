//
//  DatatistTransactionItem.m
//  DatatistTracker
//
//  Created by Mattias Levin on 19/01/14.
//  Copyright (c) 2014 Mattias Levin. All rights reserved.
//

#import "DatatistTransactionItem.h"

@implementation DatatistTransactionItem


+ (instancetype)itemWithSku:(NSString*)sku
                       name:(NSString*)name
                   category:(NSString*)category
                      price:(float)price
                   quantity:(NSUInteger)quantity {
    
    return [[DatatistTransactionItem alloc] initWithSku:sku name:name category:category price:@(price) quantity:@(quantity)];
}


+ (instancetype)itemWithSKU:(NSString*)sku {
    return [[DatatistTransactionItem alloc] initWithSku:sku name:nil category:nil price:nil quantity:nil];
}


- (id)initWithSku:(NSString*)sku name:(NSString*)name category:(NSString*)category price:(NSNumber*)price quantity:(NSNumber*)quantity {
    
    self = [super init];
    if (self) {
        _sku = sku;
        _name = name;
        _category = category;
        _price = price;
        _quantity = quantity;
    }
    return self;
    
}


- (BOOL)isValid {
    if (![self.sku isKindOfClass: [NSString class]]) {
        return NO;
    }
    
    return self.sku.length > 0;
}


@end

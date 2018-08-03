//
//  DatatistTransaction.m
//  DatatistTracker
//
//  Created by Mattias Levin on 19/01/14.
//  Copyright (c) 2014 Mattias Levin. All rights reserved.
//

#import "DatatistTransaction.h"
#import "DatatistTransactionBuilder.h"


@implementation DatatistTransaction


+ (instancetype)transactionWithBuilder:(TransactionBuilderBlock)block {
    NSParameterAssert(block);
    
    DatatistTransactionBuilder *builder = [[DatatistTransactionBuilder alloc] init];
    block(builder);
    
    return [builder build];
}


- (id)initWithBuilder:(DatatistTransactionBuilder*)builder {
    
    self = [super init];
    if (self) {
        _identifier = builder.identifier;
        _grandTotal = builder.grandTotal;
        _subTotal = builder.subTotal;
        _tax = builder.tax;
        _shippingCost = builder.shippingCost;
        _discount = builder.discount;
        _items = builder.items;
    }
    return self;
}


@end

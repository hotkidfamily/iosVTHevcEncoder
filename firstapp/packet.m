//
//  packet.m
//  firstapp
//
//  Created by yanli on 2017/7/7.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "packet.h"

@interface packet ()
@property(nonatomic) NSUInteger capability;
@end

@implementation packet

- (instancetype)initWithSize:(NSUInteger)size
{
    self = [super init];
    self.capability = size + 16;
    self.data = malloc(self.capability);
    self.length = size;
    
    return self;
}

- (void)dealloc
{
    if (self.data) {
        free(self.data);
    }
    
    self.data = nil;
    self.capability = 0;
    self.length = 0;
}

@end

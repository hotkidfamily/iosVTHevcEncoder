//
//  packet.h
//  firstapp
//
//  Created by yanli on 2017/7/7.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface packet: NSObject

@property uint8_t* data;
@property(nonatomic) NSUInteger length;

@end


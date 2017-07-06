//
//  fileparser.h
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoPacket : NSObject

@property uint8_t* buffer;
@property NSInteger size;

@end


@interface fileparser : NSObject

-(BOOL)open:(NSString*)fileName;
-(VideoPacket *)nextPacket;
-(void)close;

@end

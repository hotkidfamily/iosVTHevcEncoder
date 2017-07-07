//
//  elementStream.h
//  firstapp
//
//  Created by yanli on 2017/7/7.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "decoder.h"

@interface ElementStream: NSObject

- (BOOL)open:(NSString *)fileName;
- (packet *)nextPacket;
- (void)close;

@end



//
//  vthevcencoder.h
//  firstapp
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "encoder.h"

@interface VTHevcEncoder : Encoder {
    VTCompressionSessionRef hevcsession;
    int64_t startPTSInMS;
}

@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) BOOL initialized;
@property(nonatomic) NSData *vps;
@property(nonatomic) NSData *sps;
@property(nonatomic) NSData *pps;

@end

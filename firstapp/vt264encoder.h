//
//  vt264encoder.h
//  appTest
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "encoder.h"


@interface VT264Encoder : Encoder {
    VTCompressionSessionRef session;
    int64_t startPTSInMS;
}

@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) BOOL initialized;
@property(nonatomic) NSData *sps;
@property(nonatomic) NSData *pps;

@end

//
//  vt264encoder.h
//  appTest
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "encoder.h"


@interface vt264encoder : encoder {
    VTCompressionSessionRef session;
    int64_t startPTSInMS;
}

@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) BOOL initialized;
@property(nonatomic) NSData *sps;
@property(nonatomic) NSData *pps;

-(BOOL)reset:(DWEncodeParam *)params;
-(BOOL)encode:(CMSampleBufferRef)buffer;
-(BOOL)flush;
-(BOOL)destory;

@end

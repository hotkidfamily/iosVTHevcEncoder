//
//  vt264decoder.h
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "decoder.h"

@interface vt264decoder : decoder {
    VTDecompressionSessionRef session;
}

-(BOOL)reset:(DWDecodeParam *)params;
-(BOOL)decode:(CMSampleBufferRef)buffer;
-(BOOL)flush;
-(BOOL)destroy;
-(NSString *)description;

@end

//
//  vt264decoder.m
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "vt264decoder.h"

@implementation vt264decoder

- (id)init {
    
    if (self = [super init]) {
        self.name = @"DW video decoder base VideoToolbox.";
        self.standard = DWVideoStandardH264;
        self.index = DWCodecIndexVT264;
    }
    return self;
}

-(BOOL)reset:(DWDecodeParam *)params
{
    return YES;
}

-(BOOL)decode:(CMSampleBufferRef)buffer
{
    return YES;
}

-(BOOL)flush
{
    return YES;
}

-(BOOL)destroy
{
    return YES;
}

@end

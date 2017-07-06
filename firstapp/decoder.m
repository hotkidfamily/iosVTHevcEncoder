//
//  decoder.m
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "decoder.h"

@implementation decoder

- (id)init {
    
    self.name = @"DW video decoder base interface.";
    self.standard = DWVideoStandardNone;
    self.index = DWCodecIndexNone;
    self.type = DWCodecTypeDecoder;
    
    return self;
}


+ (NSString *)listDecoders
{
    return nil;
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

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %@ - %@", @(self.standard), @(self.index), self.name];
}

@end

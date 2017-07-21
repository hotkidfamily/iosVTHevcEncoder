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


-(NSString *)description
{
    return [NSString stringWithFormat:@"%@ - %@ -%@ - %@", @(self.standard), @(self.index), @(self.type), self.name];
}


#pragma mark - Utils

+(CMSampleBufferRef)createCMSampleBufferFromData:(NSData *)naluData
                                         andDesc:(CMFormatDescriptionRef)formatDesc
{
    OSStatus status = noErr;
    CMBlockBufferRef blockBuffer = nil;
    CMSampleBufferRef sampleBuffer = nil;
    
    if (status == noErr){
        status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                     (void*)naluData.bytes, naluData.length,
                                                     kCFAllocatorNull,
                                                     NULL, 0, naluData.length,
                                                     0, &blockBuffer);
    }
    
    if(status == kCMBlockBufferNoErr) {
        const size_t sampleSizeArray[] = { naluData.length };
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           formatDesc,
                                           1, 0, nil, 1, sampleSizeArray,
                                           &sampleBuffer);
    }
    
    CFRelease(blockBuffer);
    
    if (status == kCMBlockBufferNoErr) {
        return sampleBuffer;
    }
    else {
        CFRelease(sampleBuffer);
        NSLog(@"Fail to create block buffer ret %d", (int)status);
        return nil;
    }
}


+ (CMFormatDescriptionRef)createCMFormatDescFromSPS:(NSData *)spsData
                                             andPPS:(NSData *)ppsData
{
    OSStatus status = noErr;
    CMFormatDescriptionRef h264FormatDescription = nil;
    
    if (status == noErr) {
        const uint8_t* const parameterSetPointers[2] = { spsData.bytes, ppsData.bytes};
        const size_t parameterSetSizes[2] = { spsData.length,  ppsData.length };
        
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                     2, //param count
                                                                     parameterSetPointers,
                                                                     parameterSetSizes,
                                                                     4, //nal start code size
                                                                     &h264FormatDescription);
    }
    
    if (status == kCMBlockBufferNoErr) {
        return h264FormatDescription;
    }
    else {
        CFRelease(h264FormatDescription);
        
        NSLog(@"Fail to create format desc ret %d", (int)status);
        return nil;
    }
}


+ (CMFormatDescriptionRef)createCMFormatDescFromVPS:(NSData *)vpsData
                                             andSPS:(NSData *)spsData
                                             andPPS:(NSData *)ppsData
{
    OSStatus status = noErr;
    
    CMFormatDescriptionRef hevcFormatDescription = nil;
    
    if (status == noErr) {
        const uint8_t* const parameterSetPointers[3] = { vpsData.bytes, spsData.bytes, ppsData.bytes };
        const size_t parameterSetSizes[3] = { vpsData.length, spsData.length,  ppsData.length};
        
        status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault,
                                                                     3, //param count
                                                                     parameterSetPointers,
                                                                     parameterSetSizes,
                                                                     4, //nal start code size
                                                                     &hevcFormatDescription);
    }
    
    if (status == kCMBlockBufferNoErr) {
        return hevcFormatDescription;
    }
    else {
        CFRelease(hevcFormatDescription);
        
        NSLog(@"Fail to create format desc ret %d", (int)status);
        return nil;
    }
}


@end

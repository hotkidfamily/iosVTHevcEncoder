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
    uint32_t h264DataSize = 0;
    uint8_t *h264Data = nil;
    
    h264DataSize = (uint32_t)naluData.length;
    h264Data = (uint8_t*)malloc(h264DataSize);
    if (!h264Data) {
        NSLog(@"Fail to alloc buffer at %p(%d)", h264Data, h264DataSize);
        status = kCMBlockBufferBlockAllocationFailedErr;
    }
    else {
        [naluData getBytes:h264Data length:h264DataSize];
    }
    
    if (status == noErr){
        [naluData getBytes:h264Data length:h264DataSize];
        
        status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                     (void*)h264Data, h264DataSize,
                                                     kCFAllocatorNull,
                                                     NULL, 0, h264DataSize,
                                                     0, &blockBuffer);
    }
    
    if(status == kCMBlockBufferNoErr) {
        const size_t sampleSizeArray[] = { h264DataSize };
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           formatDesc,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
    }
    
    CFRelease(blockBuffer);
    
    if (status == kCMBlockBufferNoErr) {
        return sampleBuffer;
    }
    else {
        if (h264Data)
            free(h264Data);
        
        CFRelease(sampleBuffer);
        NSLog(@"Fail to create block buffer ret %d", (int)status);
        return nil;
    }
}


+ (CMFormatDescriptionRef)createCMFormatDescFromSPS:(NSData *)spsData
                                             andPPS:(NSData *)ppsData
{
    OSStatus status = noErr;
    uint8_t *sps = nil, *pps = nil;
    uint32_t spsSize = (uint32_t)spsData.length;
    uint32_t ppsSize = (uint32_t)ppsData.length;
    CMFormatDescriptionRef h264FormatDescription = nil;
    
    sps = (uint8_t*)malloc(spsSize);
    pps = (uint8_t*)malloc(ppsSize);
    if (!sps || !pps){
        NSLog(@"Fail to alloc buffer at %p(%d) and %p(%d)", sps, spsSize, pps, ppsSize);
        status = kCMFormatDescriptionError_AllocationFailed;
    }
    else {
        [spsData getBytes:sps length:spsData.length];
        [ppsData getBytes:pps length:ppsData.length];
    }
    
    if (status == noErr) {
        const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)sps, (const uint8_t*)pps};
        const size_t parameterSetSizes[2] = { spsSize,  ppsSize };
        
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                     2, //param count
                                                                     parameterSetPointers,
                                                                     parameterSetSizes,
                                                                     4, //nal start code size
                                                                     &h264FormatDescription);
    }
    
    if (sps)
        free(sps);
    
    if (pps)
        free(pps);
    
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
    uint8_t *vps = nil, *sps = nil, *pps = nil;
    uint32_t vpsSize, spsSize, ppsSize;
    CMFormatDescriptionRef hevcFormatDescription = nil;
    
    vpsSize = (uint32_t)vpsData.length;
    spsSize = (uint32_t)spsData.length;
    ppsSize = (uint32_t)ppsData.length;
    
    vps = (uint8_t*)malloc(vpsSize);
    sps = (uint8_t*)malloc(spsSize);
    pps = (uint8_t*)malloc(ppsSize);
    
    if (!vps || !sps || !pps){
        NSLog(@"Fail to alloc buffer at %p(%d), %p(%d) and %p(%d)", vps, vpsSize, sps, spsSize, pps, ppsSize);
        status = kCMFormatDescriptionError_AllocationFailed;
    }
    else {
        [vpsData getBytes:vps length:vpsData.length];
        [spsData getBytes:sps length:spsData.length];
        [ppsData getBytes:pps length:ppsData.length];
    }
    
    if (status == noErr) {
        const uint8_t* const parameterSetPointers[3] = { (const uint8_t*)vps, (const uint8_t*)sps, (const uint8_t*)pps };
        const size_t parameterSetSizes[3] = { vpsSize, spsSize,  ppsSize};
        
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
        if (sps)
            free(sps);
        
        if (pps)
            free(pps);
        
        CFRelease(hevcFormatDescription);
        
        NSLog(@"Fail to create format desc ret %d", (int)status);
        return nil;
    }
}


@end

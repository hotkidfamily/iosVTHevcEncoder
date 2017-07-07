//
//  vt264decoder.m
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "vt264decoder.h"

@interface vt264decoder () {
    VTDecompressionSessionRef session;
    CMFormatDescriptionRef formatDescription;
    CMVideoDimensions dimensions;
}
@end

@implementation vt264decoder


- (id)init {
    
    if (self = [super init]) {
        self.name = @"DW video decoder base VideoToolbox.";
        self.standard = DWVideoStandardH264;
        self.index = DWCodecIndexVT264;
    }
    return self;
}


void didDecompressH264( void * CM_NULLABLE decompressionOutputRefCon,
                       void * CM_NULLABLE sourceFrameRefCon,
                       OSStatus status,
                       VTDecodeInfoFlags infoFlags,
                       CM_NULLABLE CVImageBufferRef imageBuffer,
                       CMTime presentationTimeStamp,
                       CMTime presentationDuration)
{
    if (!imageBuffer) {
        return;
    }
    
    if (status != noErr) {
        return;
    }
    
    int64_t outputBufferAddress = (int64_t)sourceFrameRefCon;
    if (outputBufferAddress < 0x100) {
        return;
    }
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    CVPixelBufferRef output = CVPixelBufferRetain(imageBuffer);
    *outputPixelBuffer = output;
}


-(BOOL)reset:(DWDecodeParam *)params
{
    const uint8_t* const parameterSetPointers[2] = { (const uint8_t*)params->sps, (const uint8_t*)params->pps};
    const size_t parameterSetSizes[2] = { params->spsLength,  params->ppsLength };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &formatDescription);
    
    dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
    
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompressH264;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)(self);
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              formatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &session);
        CFRelease(attrs);
    }
    
    return status == noErr;
}


-(BOOL)decode:(CMBlockBufferRef)buffer
{
    CVPixelBufferRef outputPixelBuffer = NULL;
    const uint8_t *h264Data, h264DataSize;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)h264Data, h264DataSize,
                                                          kCFAllocatorNull,
                                                          NULL, 0, h264DataSize,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {h264DataSize};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           formatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            status = VTDecompressionSessionDecodeFrame(session,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            /* vterror.h */
            if(status != noErr) {
            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    return status == noErr;
}

-(BOOL)flush
{
    return YES;
}

-(BOOL)destroy
{
    VTDecompressionSessionInvalidate(session);
    CFRelease(session);
    return YES;
}

@end

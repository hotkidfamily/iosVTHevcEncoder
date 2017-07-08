//
//  vt264decoder.m
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "vt264decoder.h"

@interface VT264Decoder () {
    VTDecompressionSessionRef session;
    CMFormatDescriptionRef formatDescription;
    CMVideoDimensions dimensions;
    BOOL bInitialized;
}
@end

@implementation VT264Decoder


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
    OSStatus status = noErr;
    
    CFDictionaryRef attrs = NULL;
    const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
    uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
    attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = didDecompressH264;
    callBackRecord.decompressionOutputRefCon = (__bridge void *)(self);
    
    status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                          params->formatDesc,
                                          NULL, attrs,
                                          &callBackRecord,
                                          &session);
    CFRelease(attrs);
    
    return status == noErr;
}


-(BOOL)decode:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef outputPixelBuffer = NULL;
    OSStatus status = noErr;
    
    if (!session) {
        status = kVTInvalidSessionErr;
    }
    
    if (status == noErr && sampleBuffer) {
        VTDecodeFrameFlags flags = 0;
        VTDecodeInfoFlags flagOut = 0;
        status = VTDecompressionSessionDecodeFrame(session,
                                                  sampleBuffer,
                                                  flags,
                                                  &outputPixelBuffer,
                                                  &flagOut);
        CFRelease(sampleBuffer);
    }
    
    /* vterror.h */
    if(status != noErr) {
        NSLog(@"decode frame error for %d.", status);
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

//
//  vthevcdecoder.m
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "vthevcdecoder.h"

@interface VTHevcDecoder () {
    VTDecompressionSessionRef session;
}

@end



void didDecompressH265( void * CM_NULLABLE decompressionOutputRefCon,
                       void * CM_NULLABLE sourceFrameRefCon,
                       OSStatus status,
                       VTDecodeInfoFlags infoFlags,
                       CM_NULLABLE CVImageBufferRef imageBuffer,
                       CMTime presentationTimeStamp,
                       CMTime presentationDuration)
{
    if ( status != noErr
        || !imageBuffer) {
        NSLog(@"didDecompressH265 return %d with image %p", (int)status, imageBuffer);
        return;
    }
    
    int64_t ptsInMs = presentationTimeStamp.value * 1000 / presentationTimeStamp.timescale;
    NSLog(@"decode pts %lld", ptsInMs);
    
    VTHevcDecoder* encoder = (__bridge VTHevcDecoder*)decompressionOutputRefCon;
    
    CVPixelBufferRef output = CVPixelBufferRetain(imageBuffer);
    
    if (encoder.delegate) {
        [encoder.delegate gotDecodedData:output];
    }
    else {
        CVPixelBufferRelease(output);
    }
}


@implementation VTHevcDecoder

- (id)init {
    
    if (self = [super init]) {
        self.name = @"DW video decoder base VideoToolbox.";
        self.standard = DWVideoStandardHEVC;
        self.index = DWCodecIndexVTHEVC;
    }
    return self;
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
    callBackRecord.decompressionOutputCallback = didDecompressH265;
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
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression | kVTDecodeFrame_EnableTemporalProcessing;
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
        NSLog(@"decode frame error for %d.", (int)status);
    }
    
    return status == noErr;
}

-(BOOL)flush
{
    return YES;
}

-(BOOL)destroy
{
    if (session) {
        VTDecompressionSessionInvalidate(session);
        CFRelease(session);
        session = nil;
    }
    
    return YES;
}

@end

//
//  vt264encoder.m
//  appTest
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY inc. All rights reserved.
//

#import "vt264encoder.h"

@interface VT264Encoder () {
    VTCompressionSessionRef session;
    int64_t startPTSInMS;
}

@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) BOOL initialized;
@property(nonatomic) NSData *sps;
@property(nonatomic) NSData *pps;

@end


@implementation VT264Encoder

- (id)init
{
    
    if (self = [super init]) {
        self.initialized = NO;
        self.sessionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.sps = nil;
        self.pps = nil;
        self.name = @"Apple VideoToolbox 264";
        self.standard = DWVideoStandardH264;
        self.index = DWCodecIndexVT264;
        self.type = DWCodecTypeEncoder;
        
        stats.frameCount = 0;
        stats.workingDuration = 0;
        startPTSInMS = 0;
        session = nil;
    }
    
    return self;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    if (status != 0) {
        NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    VT264Encoder* encoder = (__bridge VT264Encoder*)outputCallbackRefCon;
    
    CMTime presentTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime decodeTimestamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
    int64_t dtsInMs = 0,  ptsInMs = 0;
    if (presentTimestamp.flags & kCMTimeFlags_Valid) {
        ptsInMs = presentTimestamp.value * 1000 / presentTimestamp.timescale;
    }
    if (decodeTimestamp.flags & kCMTimeFlags_Valid) {
        dtsInMs = decodeTimestamp.value * 1000 / decodeTimestamp.timescale;
    }
    NSLog(@"pts %lld dts %lld", ptsInMs, dtsInMs);
    
    if (encoder->startPTSInMS == 0){
        encoder->startPTSInMS = ptsInMs;
    }
    else {
        encoder->stats.workingDuration = (uint32_t)((ptsInMs - encoder->startPTSInMS)/1000);
    }
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        const uint8_t *sps = nil, *pps = nil;
        size_t spsSize = 0, ppsSize = 0, exCount = 0;
        
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &spsSize, &exCount, 0 );
        if (statusCode == noErr) {
            statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &ppsSize, &exCount, 0 );
        }
        
        if (statusCode == noErr) {
            // Found pps
            encoder.sps = [NSData dataWithBytes:sps length:spsSize];
            encoder.pps = [NSData dataWithBytes:pps length:ppsSize];
        }
        
        if (encoder.delegate) {
            [encoder.delegate gotExtraData:nil sps:encoder.sps pps:encoder.pps];
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
            if(encoder.delegate)
                [encoder.delegate gotEncodedData:data isKeyFrame:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }   
    }
}

- (BOOL)reset:(DWEncodeParam *)inParams {
    
    params = *inParams;
    
    dispatch_async(self.sessionQueue, ^{
        
        // For testing out the logic, lets read from a file and then send it to encoder to create h264 stream
        
        // Create the compression session
        OSStatus err = VTCompressionSessionCreate(NULL, params.width, params.height, kCMVideoCodecType_H264, NULL, NULL, NULL,
                                                     didCompressH264, (__bridge void *)(self),
                                                     &session);
        
        if (err != noErr)
        {
            NSLog(@"H264: Unable to create a H264 session");
        }
        
        if(err == noErr) {
            const int32_t v = params.keyInterval;
            
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            const int v = params.fps;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            CFBooleanRef allowFrameReodering = kCFBooleanTrue;
            err = VTSessionSetProperty(session , kVTCompressionPropertyKey_AllowFrameReordering, allowFrameReodering);
        }
        
        if(err == noErr) {
            const int v = params.maxBitrate;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            int v = params.bitrate / 8;
            CFNumberRef bytes = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &v);
            v = 1;
            CFNumberRef duration = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &v);
            CFMutableArrayRef limit = CFArrayCreateMutable(kCFAllocatorDefault, 2, &kCFTypeArrayCallBacks);
            
            CFArrayAppendValue(limit, bytes);
            CFArrayAppendValue(limit, duration);
            
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, limit);
            
            CFRelease(bytes);
            CFRelease(duration);
            CFRelease(limit);
        }
        
        if(err == noErr) {
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        }
        
        if(err == noErr) {
            CFStringRef profileLevel = kVTProfileLevel_H264_Main_AutoLevel;
            
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, profileLevel);
        }
        
        if (err == noErr) {
            CFStringRef ref = kCVImageBufferColorPrimaries_ITU_R_709_2;
            VTSessionSetProperty(session,
                                 kVTCompressionPropertyKey_ColorPrimaries,
                                 ref);
            CFRelease(ref);
        }
        
        if (err == noErr) {
            CFStringRef ref = kCVImageBufferTransferFunction_ITU_R_709_2;
            VTSessionSetProperty(session,
                                 kVTCompressionPropertyKey_TransferFunction,
                                 ref);
            CFRelease(ref);
        }
        
        if (err == noErr) {
            CFStringRef ref = kCVImageBufferYCbCrMatrix_ITU_R_601_4;
            VTSessionSetProperty(session,
                                 kVTCompressionPropertyKey_YCbCrMatrix,
                                 ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            VTSessionSetProperty(session, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
        }
        
        if(err == noErr) {
            VTCompressionSessionPrepareToEncodeFrames(session);
        }
        
        if (err == noErr) {
            self.initialized = YES;
        }
    });
    
    return self.initialized;
}

- (BOOL)encode:(CMSampleBufferRef)sampleBuffer {
    
    CFRetain(sampleBuffer);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CMTime presentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime durationTime = kCMTimeInvalid; //CMSampleBufferGetDuration(sampleBuffer);
    
    CGSize bufferSize = CVImageBufferGetEncodedSize(imageBuffer);
    CGSize dispalySize = CVImageBufferGetDisplaySize(imageBuffer);

    //NSLog(@"frame size %.2fx%.2f - buffer %.2fx%.2f", dispalySize.width, dispalySize.height, bufferSize.width, bufferSize.height);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    OSType pixelType = CVPixelBufferGetPixelFormatType(imageBuffer);
    
    if(pixelType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
       pixelType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange){
        VTEncodeInfoFlags flags;
        VTCompressionSessionEncodeFrame(session, imageBuffer, presentTime, durationTime, nil, nil, &flags);
    }
    
    //NSLog(@"pixel buffer %ldx%ld, stride %ld, pixel %x", width, height, bytesPerRow, (unsigned int)pixelType);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CFRelease(sampleBuffer);
    return TRUE;
}

- (BOOL)flush {
    return TRUE;
}

- (BOOL)destroy {
    
    if(session) {
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
        session = nil;
    }
    
    self.initialized = NO;
    self.delegate = nil;
    stats.frameCount = 0;
    stats.workingDuration = 0;
    startPTSInMS = 0;
    
    return TRUE;
}

@end

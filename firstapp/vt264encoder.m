//
//  vt264encoder.m
//  appTest
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY inc. All rights reserved.
//

#import "vt264encoder.h"

@implementation vt264encoder

- (id)init {
    
    if (self = [super init]) {
        self.initialized = NO;
        self.sessionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        DWEncodeStat stat = self.stats;
        stat.frameCount = 0;
        stat.workingDuration = 0;
        self.stats = stat;
        self.sps = nil;
        self.pps = nil;
        self.name = @"Apple VideoToolbox 264";
        self.standard = DWVideoStandardH264;
        self.index = DWCodecIndexVT264;
        startPTSInMS = 0;
        session = nil;
    }
    
    return self;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    vt264encoder* encoder = (__bridge vt264encoder*)outputCallbackRefCon;
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                encoder.sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder.pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder.delegate)
                {
                    [encoder.delegate gotExtraData:nil sps:encoder.sps pps:encoder.pps];
                }
            }
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

-(BOOL)reset:(DWEncodeParam *)params {
    
    self.params = *params;
    
    dispatch_async(self.sessionQueue, ^{
        
        // For testing out the logic, lets read from a file and then send it to encoder to create h264 stream
        
        // Create the compression session
        OSStatus err = VTCompressionSessionCreate(NULL, self.params.width, self.params.height, kCMVideoCodecType_H264, NULL, NULL, NULL,
                                                     didCompressH264, (__bridge void *)(self),
                                                     &session);
        
        if (err != noErr)
        {
            NSLog(@"H264: Unable to create a H264 session");
        }
        
        if(err == noErr) {
            const int32_t v = params->keyInterval;
            
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            const int v = params->fps;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            CFBooleanRef allowFrameReodering = kCFBooleanTrue;
            err = VTSessionSetProperty(session , kVTCompressionPropertyKey_AllowFrameReordering, allowFrameReodering);
        }
        
        if(err == noErr) {
            const int v = params->maxBitrate;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            int v = params->bitrate / 8;
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

-(BOOL)encode:(CMSampleBufferRef)sampleBuffer {
    
    CFRetain(sampleBuffer);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CMTime presentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime durationTime = kCMTimeInvalid; //CMSampleBufferGetDuration(sampleBuffer);
    int64_t ptsInMs = presentTime.value * 1000 / presentTime.timescale;
    if (startPTSInMS == 0){
        startPTSInMS = ptsInMs;
    }
    else {
        DWEncodeStat stats = self.stats;
        stats.workingDuration = (uint32_t)((ptsInMs - startPTSInMS)/1000);
        self.stats = stats;
    }
    
    CGSize bufferSize = CVImageBufferGetEncodedSize(imageBuffer);
    CGSize dispalySize = CVImageBufferGetDisplaySize(imageBuffer);

    NSLog(@"frame %lld size %.2fx%.2f - buffer %.2fx%.2f", ptsInMs, dispalySize.width, dispalySize.height, bufferSize.width, bufferSize.height);
    
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
    
    NSLog(@"pixel buffer %ldx%ld, stride %ld, pixel %x", width, height, bytesPerRow, (unsigned int)pixelType);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CFRelease(sampleBuffer);
    return TRUE;
}

-(BOOL)flush {
    return TRUE;
}

-(BOOL)destory {
    
    if(session) {
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
        session = nil;
    }
    
    self.initialized = NO;
    self.delegate = nil;
    startPTSInMS = 0;
    return TRUE;
}

@end

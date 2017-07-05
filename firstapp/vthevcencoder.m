//
//  vthevcencoder.m
//  firstapp
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "vthevcencoder.h"

@implementation vthevcencoder

- (id)init {
    
    if (self = [super init]) {
        
        DWEncodeStat stat = self.stats;
        stat.frameCount = 0;
        stat.workingDuration = 0;
        self.stats = stat;
        
        self.initialized = NO;
        self.sessionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.vps = nil;
        self.sps = nil;
        self.pps = nil;
        self.name = @"Apple VideoToolbox HEVC";
        self.standard = DWVideoStandardHEVC;
        self.index = DWCodecIndexVTHEVC;
        
        startPTSInMS = 0;
    }
    
    return self;
}


void didCompressH265(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    NSLog(@"didCompressH265 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH265 data is not ready ");
        return;
    }
    vthevcencoder* encoder = (__bridge vthevcencoder*)outputCallbackRefCon;
    
    CMTime presentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    int64_t ptsInMs = presentTime.value * 1000 / presentTime.timescale;
    if (encoder->startPTSInMS == 0){
        encoder->startPTSInMS = ptsInMs;
    }
    else {
        DWEncodeStat stats = encoder.stats;
        stats.workingDuration = (uint32_t)((ptsInMs - encoder->startPTSInMS)/1000);
        encoder.stats = stats;
    }
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        const uint8_t *vps = nil;
        size_t vpsSize = 0, vpsCount = 0;
        const uint8_t *sps = nil;
        size_t spsSize = 0, spsCount = 0;
        const uint8_t *pps = nil;
        size_t ppsSize = 0, ppsCount = 0;
        
        OSStatus statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 0, &vps, &vpsSize, &vpsCount, 0 );
        
        if (statusCode == noErr){
            statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 1, &sps, &spsSize, &spsCount, 0 );
        }
        
        if (statusCode == noErr){
            statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 2, &pps, &ppsSize, &ppsCount, 0 );
        }
        
        if(vpsCount != 1
           || spsCount != 1
           || ppsCount != 1){
            NSLog(@"multi extra data found.  ===> ");
        }
        
        if (statusCode == noErr){
            encoder.vps = [NSData dataWithBytes:vps length:vpsSize];
            encoder.sps = [NSData dataWithBytes:sps length:spsSize];
            encoder.pps = [NSData dataWithBytes:pps length:ppsSize];
        }
        
        if (encoder.delegate
            && statusCode == noErr)
        {
            [encoder.delegate gotExtraData:encoder.vps sps:encoder.sps pps:encoder.pps];
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
        
        CFDictionaryRef specification;
        CFStringRef encoderID;
        CFDictionaryRef properties;
        OSStatus err = noErr;
        
        err = VTCopySupportedPropertyDictionaryForEncoder(1280, 720, kCMVideoCodecType_HEVC, nil, &encoderID, &properties);
        
        if (err == noErr){
            NSLog(@"get encodr %@ specification.", encoderID);
            CFRelease(encoderID);
            CFRelease(properties);
        }
#if 0
        CFMutableDictionaryRef encoderSpecifications = nil;
        
        CFStringRef bkey = CFSTR("EnableHardwareAcceleratedVideoEncoder");
        CFBooleanRef bvalue = kCFBooleanTrue;
        
        CFStringRef ckey = CFSTR("RequireHardwareAcceleratedVideoEncoder");
        CFBooleanRef cvalue = kCFBooleanTrue;
        
        encoderSpecifications = CFDictionaryCreateMutable(
                                                          kCFAllocatorDefault,
                                                          2,
                                                          &kCFTypeDictionaryKeyCallBacks,
                                                          &kCFTypeDictionaryValueCallBacks);
        
        CFDictionaryAddValue(encoderSpecifications, bkey, bvalue);
        CFDictionaryAddValue(encoderSpecifications, ckey, cvalue);
#endif
        
        // Create the compression session
        err = VTCompressionSessionCreate(NULL, self.params.width, self.params.height, kCMVideoCodecType_HEVC, nil, NULL, NULL,
                                                  didCompressH265, (__bridge void *)(self),
                                                  &hevcsession);
        if (err != noErr)
        {
            NSLog(@"H264: Unable to create a H264 hevcsession");
        }
        
        if(err == noErr) {
            const int32_t v = params->keyInterval;
            
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_MaxKeyFrameInterval, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            const int v = params->fps;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_ExpectedFrameRate, ref);
            
            CFRelease(ref);
        }
        
        if(err == noErr) {
            const int v = params->fps;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_BaseLayerFrameRate, ref);
            CFRelease(ref);
        }
        
        if (err == noErr) {
            const int v = params->fps;
            CFBooleanRef ref = kCFBooleanTrue;
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_BaseLayerFrameRate, ref);
            CFRelease(ref);
        }
        
        if(err == noErr) {
            const int v = params->maxBitrate;
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_AverageBitRate, ref);
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
            
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_DataRateLimits, limit);
            
            CFRelease(bytes);
            CFRelease(duration);
            CFRelease(limit);
        }
        
        if(err == noErr) {
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        }
        
        if(err == noErr) {
            CFStringRef profileLevel = kVTProfileLevel_HEVC_Main_AutoLevel;
            err = VTSessionSetProperty(hevcsession, kVTCompressionPropertyKey_ProfileLevel, profileLevel);
        }
        
        if(err == noErr) {
            err = VTCompressionSessionPrepareToEncodeFrames(hevcsession);
        }
        
        if (err == noErr) {
            self.initialized = YES;
        }
        else {
            NSLog(@"init vthevc error");
        }
    });
    
    return self.initialized;
}

-(BOOL)encode:(CMSampleBufferRef)sampleBuffer {
    CFRetain(sampleBuffer);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CMTime presentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime durationTime = kCMTimeInvalid; //CMSampleBufferGetDuration(sampleBuffer);
    
    CGSize bufferSize = CVImageBufferGetEncodedSize(imageBuffer);
    CGSize dispalySize = CVImageBufferGetDisplaySize(imageBuffer);
    
    NSLog(@"frame size %.2fx%.2f - buffer %.2fx%.2f", dispalySize.width, dispalySize.height, bufferSize.width, bufferSize.height);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    OSType pixelType = CVPixelBufferGetPixelFormatType(imageBuffer);
    
    if(pixelType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
       pixelType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange){
        VTEncodeInfoFlags flags;
        OSStatus err = VTCompressionSessionEncodeFrame(hevcsession, imageBuffer, presentTime, durationTime, nil, nil, &flags);
        if (err != noErr){
            
        }
    }
    
    NSLog(@"pixel buffer %ldx%ld, stride %ld, pixel %x", width, height, bytesPerRow, (unsigned int)pixelType);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CFRelease(sampleBuffer);
    return TRUE;
}

-(BOOL)flush {
    return YES;
}

-(BOOL)destory {
    if(hevcsession) {
        VTCompressionSessionInvalidate(hevcsession);
        CFRelease(hevcsession);
        hevcsession = nil;
    }
    
    self.initialized = NO;
    self.delegate = nil;
    startPTSInMS = 0;
    return TRUE;
}

@end

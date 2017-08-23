//
//  capture.m
//  firstapp
//
//  Created by yanli on 2017/7/5.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "capture.h"

static void * SessionRunningContext = &SessionRunningContext;
static void * FocusModeContext = &FocusModeContext;

@implementation VideoCapture


- (id)init
{
    cfgInternal.res.width = 1280;
    cfgInternal.res.height = 720;
    cfgInternal.fps = 25.0;
    cfgInternal.pixelFormat = 0;
    cfgInternal.switchCamera = FALSE;
    
    [self reconfig:cfgInternal];
    return self;
}


- (BOOL)reconfig:(CAPTURECFG)cfg;
{
    if (!self.session) {
        self.session = [[AVCaptureSession alloc] init];
    }
    
    if (!self.sessionQueue) {
        self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    }
    
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusNotDetermined:
        {
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    setupRes = 1;
                }
                dispatch_resume( self.sessionQueue );
            }];
        }
            break;
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
            break;
        case AVAuthorizationStatusAuthorized:
            setupRes = 0;
            break;
    }
    
    dispatch_async( self.sessionQueue, ^{
        AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
        
        if (!self.device) {
            preferredPosition = AVCaptureDevicePositionBack;
        }
        else if (cfg.switchCamera){
            switch ( self.device.position )
            {
                case AVCaptureDevicePositionUnspecified:
                case AVCaptureDevicePositionFront:
                    preferredPosition = AVCaptureDevicePositionBack;
                    break;
                case AVCaptureDevicePositionBack:
                    preferredPosition = AVCaptureDevicePositionFront;
                    break;
            }
        }
        else {
            preferredPosition = AVCaptureDevicePositionBack;
        }
        
        AVCaptureDevice *newVideoDevice;
        NSArray *types = [NSArray arrayWithObjects:AVCaptureDeviceTypeBuiltInWideAngleCamera, nil];
        AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:types mediaType:AVMediaTypeVideo position:preferredPosition];
        
        for (AVCaptureDevice *device in discovery.devices){
            newVideoDevice = device;
        }
        
        AVCaptureDeviceInput *newVideoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevice error:nil];
        
        [self.session beginConfiguration];
        
        // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
        [self.session removeInput:self.input];
        if ( [self.session canAddInput:newVideoDeviceInput] ) {
            [self.session addInput:newVideoDeviceInput];
            self.input = newVideoDeviceInput;
            self.device = newVideoDevice;
        }
        else {
            [self.session addInput:self.input];
        }
        
        NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
        
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        NSArray *formats = [videoOutput availableVideoCVPixelFormatTypes];
        for( NSNumber *format in formats){
            if (format == val) {
                [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:format forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
                break;
            }
        }
        
        [videoOutput setSampleBufferDelegate:(id)self queue:self.sessionQueue];
        
        if ( [self.session canAddOutput:videoOutput]){
            [self.session addOutput:videoOutput];
            self.output = videoOutput;
        }
        
        CMTime frameDuration = CMTimeMake(1, (uint32_t)cfg.fps);
        NSLog(@"device fps(%f ~ %f), current %f", 1/CMTimeGetSeconds(self.device.activeVideoMaxFrameDuration), 1/CMTimeGetSeconds(self.device.activeVideoMinFrameDuration),
              1/CMTimeGetSeconds(frameDuration));
        [self.device setActiveVideoMaxFrameDuration:frameDuration];
        [self.device setActiveVideoMinFrameDuration:frameDuration];
        
        
        [self.session commitConfiguration];
    } );
    
    return YES;
}

- (BOOL)start
{
    BOOL ret = NO;
    
    if(self.session) {
        if(![self.session isRunning])
            [self.session startRunning];
            [self addObservers];
        
        ret = [self.session isRunning];
    }
    
    return ret;
}

- (BOOL)stop
{
    BOOL ret = NO;
    
    if(self.session) {
        [self.session stopRunning];
        [self removeObservers];
        ret = [self.session isRunning];
    }
    else {
        ret = YES;
    }
    
    return ret;
}

- (void)destroy
{
    NSLog(@"Capture: %lu total frames %lu drop frames", stat.statDropFramesCount + stat.statCaptureFramesCount, stat.statDropFramesCount);
}

- (BOOL)isRunning
{
    if (self.session){
        return self.session.isRunning;
    }
    else {
        return NO;
    }
}

- (void)addObservers
{
    [self addObserver:self forKeyPath:@"session.running" options: (NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningContext];
    [self addObserver:self forKeyPath:@"device.focusMode" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:FocusModeContext];
}
- (void)removeObservers
{
    [self removeObserver:self forKeyPath:@"session.running" context:SessionRunningContext];
    [self removeObserver:self forKeyPath:@"device.focusMode" context:FocusModeContext];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    id oldValue = change[NSKeyValueChangeOldKey];
    id newValue = change[NSKeyValueChangeNewKey];
    
    if ( context == FocusModeContext ) {
        if ( newValue && newValue != [NSNull null] ) {
            AVCaptureFocusMode newMode = [newValue intValue];
            if ( oldValue && oldValue != [NSNull null] ) {
                NSLog( @"focus mode (0:lock 1:auto 2:continue auto): %d -> %ld", [oldValue intValue], (long)newMode );
            }
            else {
                NSLog( @"focus mode (0:lock 1:auto 2:continue auto): %ld", (long)newMode);
            }
        }
    }
    else if ( context == SessionRunningContext ) {
        BOOL isRunning = NO;
        if ( newValue && newValue != [NSNull null] ) {
            isRunning = [newValue boolValue];
        }
        
        NSLog( @"session %@ running", isRunning?@"start":@"stop" );
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    stat.statCaptureFramesCount ++;
    if (self.delegate) {
        [self.delegate gotSampleBuffer:sampleBuffer];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    stat.statDropFramesCount ++;
}


@end

//
//  capture.m
//  firstapp
//
//  Created by yanli on 2017/7/5.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "capture.h"

@implementation VideoCapture

- (id)init
{
    [self initCamera];
    return self;
}

- (BOOL)initCamera {
    setupRes = 1;
    
    self.session = [[AVCaptureSession alloc] init];
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    
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
    
    dispatch_async(self.sessionQueue, ^{
        if(setupRes)
        {
            return;
        }
        
        if( [self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]){
            self.session.sessionPreset = AVCaptureSessionPreset1280x720;
        }
        
        AVCaptureDevice *videoDevice;
        NSArray *types = [NSArray arrayWithObjects:AVCaptureDeviceTypeBuiltInWideAngleCamera, nil];
        AVCaptureDeviceDiscoverySession *discovery = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:types mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        
        for (AVCaptureDevice *device in discovery.devices){
            videoDevice = device;
        }
        
        [self.session beginConfiguration];
        AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:nil];
        
        if( [self.session canAddInput:videoInput]){
            [self.session addInput:videoInput];
            self.input = videoInput;
            self.device = videoDevice;
        }
        
        AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        NSArray *formats = [videoOutput availableVideoCVPixelFormatTypes];
        for( NSNumber *format in formats){
            [videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:format forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
            break;
        }
        
        [videoOutput setSampleBufferDelegate:(id)self queue:self.sessionQueue];
        
        if ( [self.session canAddOutput:videoOutput]){
            [self.session addOutput:videoOutput];
            self.output = videoOutput;
        }
        
        CMTime frameDuration = CMTimeMake(1, 25);
        [self.device setActiveVideoMaxFrameDuration:frameDuration];
        
        [self.session commitConfiguration];
        
    });
    
    return YES;
}

- (BOOL)start
{
    BOOL ret = NO;
    
    if(self.session) {
        if(![self.session isRunning])
            [self.session startRunning];
        
        ret = [self.session isRunning];
    }
    
    return ret;
}

- (BOOL)stop
{
    BOOL ret = NO;
    
    if(self.session) {
        [self.session stopRunning];
        ret = [self.session isRunning];
    }
    else {
        ret = YES;
    }
    
    return ret;
}

- (void)destory
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

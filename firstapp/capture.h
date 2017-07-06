//
//  capture.h
//  firstapp
//
//  Created by yanli on 2017/7/5.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef struct tagCaptureParams {
    CGSize res;
    float fps;
    uint32_t pixelFormat;
    BOOL switchCamera;
}CAPTURECFG;

typedef struct tagCaptureStat {
    NSUInteger statCaptureFramesCount;
    NSUInteger statDropFramesCount;
}CAPTURESTAT;

@protocol CaptureDelegate <NSObject>

- (void)gotSampleBuffer:(CMSampleBufferRef)buffer;

@end

@interface VideoCapture : NSObject {
    NSUInteger setupRes;
    CAPTURESTAT stat;
    CAPTURECFG cfgInternal;
}

@property(nonatomic) AVCaptureDevice *device;
@property(nonatomic) AVCaptureDeviceInput *input;
@property(nonatomic) AVCaptureSession *session;
@property(nonatomic) AVCaptureVideoDataOutput *output;
@property(nonatomic) dispatch_queue_t sessionQueue;
@property(weak, nonatomic) id<CaptureDelegate> delegate;

- (id)init;
- (BOOL)reconfig:(CAPTURECFG)cfg;
- (BOOL)start;
- (BOOL)stop;
- (void)destroy;
- (BOOL)isRunning;

@end

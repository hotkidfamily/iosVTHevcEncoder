//
//  ViewController.m
//  firstapp
//
//  Created by yanli on 2017/1/24.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/NSTimer.h>
#import "vt264encoder.h"
#import "vthevcencoder.h"
#import "outputStream.h"

@interface ViewController ()

@property (strong, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UIButton *openButton;
@property (weak, nonatomic) IBOutlet UIButton *switchButton;
@property (weak, nonatomic) IBOutlet UIButton *encodeButton;
@property (weak, nonatomic) IBOutlet UILabel *recordingLabel;
@property (weak, nonatomic) IBOutlet UITextView *encoderListText;

- (IBAction)pressOpenButton:(id)sender;
- (IBAction)pressSwitchButton:(id)sender;
- (IBAction)pressEncodeButton:(id)sender;
- (IBAction)touchSettingButton:(id)sender;
- (IBAction)removeFromSettingButton:(id)sender;

@property(nonatomic) vthevcencoder *encoder;

@property(nonatomic) AVCaptureDevice *device;
@property(nonatomic) AVCaptureDeviceInput *input;
@property(nonatomic) AVCaptureSession *session;
@property(nonatomic) AVCaptureVideoDataOutput *output;
@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) NSUInteger setupRes;
@property(nonatomic) NSUInteger statCaptureFramesCount;
@property(nonatomic) NSUInteger statDropFramesCount;

@property(nonatomic) outputStream *streamOutput;

@property(nonatomic) NSTimer *timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self initCamera];
    AVCaptureVideoPreviewLayer *previewlayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.mainView.layer.masksToBounds = YES;
    previewlayer.frame = self.mainView.bounds;
    previewlayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.mainView.layer insertSublayer:previewlayer below:self. switchButton.layer];
    self.recordingLabel.hidden = YES;
}


- (BOOL)initCamera {
    self.setupRes = 1;
    
    self.session = [[AVCaptureSession alloc] init];
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusNotDetermined:
        {
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                if ( ! granted ) {
                    self.setupRes = 1;
                }
                dispatch_resume( self.sessionQueue );
            }];
        }
            break;
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
            break;
        case AVAuthorizationStatusAuthorized:
            self.setupRes = 0;
            break;
    }
    
    dispatch_async(self.sessionQueue, ^{
        if (self.setupRes)
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


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)pressOpenButton:(id)sender {
    if(self.session){
        if( [self.session isRunning]){
            [self.session stopRunning];
            [self.openButton setTitle:@"打开" forState:UIControlStateNormal];
        }
        else{
            [self.session startRunning];
            [self.openButton setTitle:@"关闭" forState:UIControlStateNormal];
        }
    }
}

- (IBAction)pressSwitchButton:(id)sender {
}

- (IBAction)pressEncodeButton:(id)sender {
    
    if (!self.encoder) {
        self.streamOutput = [[outputStream alloc] init];
        [self.streamOutput initFileManager];
        self.encoder = [[vthevcencoder alloc] init];
        DWEncodeParam params;
        params.bitrate = 1000*1024;
        params.maxBitrate = 1200*1024;
        params.fps = 25;
        params.width = 1280;
        params.height = 720;
        params.keyInterval = 25*2;
        
        [self.encoder reset:&params];
        [self.encoder setDelegate:self.streamOutput];
        [self initTimer];
        [self.encodeButton setTitle:@"停止" forState:UIControlStateNormal];
        self.recordingLabel.hidden = NO;
    }else{
        [self.encoder destory];
        [self.streamOutput destoryFileManager];
        self.encoder = nil;
        [self destoryTimer];
        self.recordingLabel.hidden = YES;
        [self.encodeButton setTitle:@"编码" forState:UIControlStateNormal];
    }
}

- (IBAction)touchSettingButton:(id)sender {
    NSString * encoders = [encoder listEncoders];
    self.encoderListText.text = encoders;
    self.encoderListText.hidden = NO;
}

- (IBAction)removeFromSettingButton:(id)sender {
    self.encoderListText.hidden = YES;
}

- (void)flushRecordingLabel {
    uint32_t duration = 0;
    if (self.encoder){
        duration = self.encoder->stats.workingDuration;
    }
    NSString *label = [[NSString alloc] initWithFormat:@"Recording... %d", duration];
    self.recordingLabel.text = label;
}

- (void)initTimer {
    self.timer =  [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(flushRecordingLabel) userInfo:nil repeats:YES];
}

- (void)destoryTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    self.statCaptureFramesCount ++;
    if( self.encoder ){
        [self.encoder encode:sampleBuffer];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    self.statDropFramesCount ++;
}



@end

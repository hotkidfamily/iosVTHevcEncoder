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
#import "capture.h"
#import "vt264encoder.h"
#import "vthevcencoder.h"
#import "outputStream.h"
#import "elementStream.h"

@interface ViewController () {
    dispatch_queue_t dispatchQueue;
}

@property (strong, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UIButton *openButton;
@property (weak, nonatomic) IBOutlet UIButton *switchButton;
@property (weak, nonatomic) IBOutlet UIButton *encodeButton;
@property (weak, nonatomic) IBOutlet UILabel *recordingLabel;
@property (weak, nonatomic) IBOutlet UITextView *encoderListText;
@property (weak, nonatomic) IBOutlet UIButton *playButton;

- (IBAction)pressOpenButton:(id)sender;
- (IBAction)pressSwitchButton:(id)sender;
- (IBAction)pressEncodeButton:(id)sender;
- (IBAction)touchSettingButton:(id)sender;
- (IBAction)removeFromSettingButton:(id)sender;
- (IBAction)pressPlayButton:(id)sender;

@property(nonatomic) VTHevcEncoder *encoder;
@property(nonatomic) VideoCapture *capture;
@property(nonatomic) OutputStream *streamOutput;
@property(nonatomic) ElementStream *streamInput;
@property(nonatomic) NSTimer *timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.capture = [[VideoCapture alloc] init];
    AVCaptureVideoPreviewLayer *previewlayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.capture.session];
    self.mainView.layer.masksToBounds = YES;
    previewlayer.frame = self.mainView.bounds;
    previewlayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.mainView.layer insertSublayer:previewlayer below:self. switchButton.layer];
    self.recordingLabel.hidden = YES;
    //dispatchQueue = dispatch_queue_create("com.yanli.test.gcd.queue", DISPATCH_QUEUE_SERIAL);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)pressOpenButton:(id)sender {
    if ([self.capture isRunning]){
        [self.capture stop];
        [self.capture destroy];
        self.capture.delegate = nil;
        [self.openButton setTitle:@"打开" forState:UIControlStateNormal];
    }
    else {
        self.capture.delegate = self;
        [self.capture start];
        [self.openButton setTitle:@"关闭" forState:UIControlStateNormal];
    }
}

- (IBAction)pressSwitchButton:(id)sender {
    if (self.capture) {
        CAPTURECFG cfg;
        cfg.fps = 25.0;
        cfg.switchCamera = YES;
        [self.capture reconfig:cfg];
    }
}

- (IBAction)pressEncodeButton:(id)sender {
    
    if (!self.encoder) {
        self.streamOutput = [[OutputStream alloc] init];
        [self.streamOutput open:@"test.h265"];
        self.encoder = [[VTHevcEncoder alloc] init];
        DWEncodeParam params;
        params.bitrate = 1000*1024;
        params.maxBitrate = 1200*1024;
        params.fps = 25;
        params.width = 1280;
        params.height = 720;
        params.keyInterval = 25*2;
        
        [self.encoder reset:&params];
        self.encoder.delegate = self.streamOutput;
        self.capture.delegate = self;
        [self initTimer];
        [self.encodeButton setTitle:@"停止" forState:UIControlStateNormal];
        self.recordingLabel.hidden = NO;
    }else{
        self.capture.delegate = nil;
        [self.encoder destroy];
        self.encoder = nil;
        [self.streamOutput close];
        [self destoryTimer];
        self.recordingLabel.hidden = YES;
        [self.encodeButton setTitle:@"编码" forState:UIControlStateNormal];
    }
}

- (IBAction)touchSettingButton:(id)sender {
    NSString * encoders = [Encoder listEncoders];
    self.encoderListText.text = encoders;
    self.encoderListText.hidden = NO;
}

- (IBAction)removeFromSettingButton:(id)sender {
    self.encoderListText.hidden = YES;
}

- (IBAction)pressPlayButton:(id)sender {
    self.streamInput = [[ElementStream alloc] init];
//    [self.streamInput open:@"test.h265"];
    
}

- (void)flushRecordingLabel {
    uint32_t duration = 0;
    if (self.encoder){
        duration = self.encoder->stats.workingDuration;
    }
    NSString *label = [[NSString alloc] initWithFormat:@"Recording... %d", duration + 1];
    self.recordingLabel.text = label;
}

- (void)initTimer {
    self.timer =  [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(flushRecordingLabel) userInfo:nil repeats:YES];
}

- (void)destoryTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)gotSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (self.encoder) {
        [self.encoder encode:sampleBuffer];
    }
}

@end

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
#import "vt264decoder.h"
#import "vthevcdecoder.h"
#import "outputStream.h"
#import "elementStream.h"

typedef NS_ENUM(NSUInteger, VCAppStatus) {
    VCAppStatusNone,
    VCAppStatusCapture,
    VCAppStatusRecord,
    VCAppStatusPlay,
};

@interface ViewController () {
    dispatch_queue_t decodeQueue;
}

@property (strong, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UIButton *openButton;
@property (weak, nonatomic) IBOutlet UIButton *switchButton;
@property (weak, nonatomic) IBOutlet UIButton *encodeButton;
@property (weak, nonatomic) IBOutlet UILabel *recordingLabel;
@property (weak, nonatomic) IBOutlet UITextView *encoderListText;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UISwitch *hevcSwitch;

- (IBAction)pressOpenButton:(id)sender;
- (IBAction)pressSwitchButton:(id)sender;
- (IBAction)pressEncodeButton:(id)sender;
- (IBAction)touchSettingButton:(id)sender;
- (IBAction)removeFromSettingButton:(id)sender;
- (IBAction)pressPlayButton:(id)sender;
- (IBAction)onHevcSwitchValueChange:(id)sender;

@property(nonatomic) BOOL hevcEnabled;
@property(nonatomic) AVCaptureVideoPreviewLayer *previewlayer;
@property(nonatomic) AVCaptureVideoPreviewLayer *decodelayer;
@property(nonatomic) Encoder *encoder;
@property(nonatomic) decoder *decoder;
@property(nonatomic) VideoCapture *capture;
@property(nonatomic) OutputStream *streamOutput;
@property(nonatomic) ElementStream *streamInput;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) VCAppStatus curStatus;

@end

@implementation ViewController

//AVSampleBufferDisplayLayer *decodeLayer = [[AVSampleBufferDisplayLayer alloc] initWithCoder:self.decoder];

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.capture = [[VideoCapture alloc] init];
    self.curStatus = VCAppStatusNone;
    self.hevcEnabled = [self.hevcSwitch isOn];
    self.recordingLabel.hidden = YES;
    decodeQueue = dispatch_queue_create("com.yanli.test.gcd.queue", DISPATCH_QUEUE_SERIAL);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)initPreviewLayer {
    AVCaptureVideoPreviewLayer *previewlayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.capture.session];
    self.mainView.layer.masksToBounds = YES;
    previewlayer.frame = self.mainView.bounds;
    previewlayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.mainView.layer insertSublayer:previewlayer below:self.encodeButton.layer];
}

- (void)removePreiewLayer {
    //self.mainView.layer.sublayers = nil;
    self.mainView.backgroundColor = [UIColor clearColor];
    [self.previewlayer removeFromSuperlayer];
    self.previewlayer = nil;
    self.mainView.layer.backgroundColor = [UIColor whiteColor].CGColor;
     
}

- (IBAction)pressOpenButton:(id)sender {
    
    if ([self.capture isRunning]){
        dispatch_async(decodeQueue, ^{
            if (self.curStatus == VCAppStatusRecord) {
                return ;
            }
            
            [self.capture stop];
            [self.capture destroy];
            self.capture.delegate = nil;
            self.curStatus = VCAppStatusNone;
            
        });
        [self.openButton setTitle:@"打开" forState:UIControlStateNormal];
        [self removePreiewLayer];
    }
    else {
        [self initPreviewLayer];
        [self.openButton setTitle:@"关闭" forState:UIControlStateNormal];
        dispatch_async(decodeQueue, ^{
            if (self.curStatus != VCAppStatusNone) {
                return;
            }
            
            self.capture.delegate = self;
            [self.capture start];
            self.curStatus = VCAppStatusCapture;
        });
        
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
    
    if (self.curStatus != VCAppStatusCapture
        && self.curStatus != VCAppStatusRecord){
        return ;
    }
    
    if (!self.encoder) {
        dispatch_async(decodeQueue, ^{
            Class encoder;
            NSString *fileName;
            
            if (self.hevcEnabled) {
                encoder = [VTHevcEncoder class];
                fileName = @"test.h265";
            }
            else {
                encoder = [VT264Encoder class];
                fileName = @"test.h264";
            }
            
            self.streamOutput = [[OutputStream alloc] init];
            [self.streamOutput open:fileName];
            self.encoder = [[encoder alloc] init];
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
        });
        [self initTimer];
        self.curStatus = VCAppStatusRecord;
        self.recordingLabel.hidden = YES;
        [self.encodeButton setTitle:@"停止" forState:UIControlStateNormal];
    }else{
        dispatch_async(decodeQueue, ^{
            self.capture.delegate = nil;
            [self.encoder destroy];
            self.encoder = nil;
            [self.streamOutput close];
        });
        [self destoryTimer];
        self.curStatus = VCAppStatusCapture;
        self.recordingLabel.hidden = NO;
        [self.encodeButton setTitle:@"编码" forState:UIControlStateNormal];
    }
}

- (IBAction)touchSettingButton:(id)sender {
    NSString * encoders = [Encoder listEncoders];
    self.encoderListText.text = encoders;
    self.encoderListText.hidden = NO;
    [self.mainView.layer insertSublayer:self.encoderListText.layer above:nil];
}

- (IBAction)removeFromSettingButton:(id)sender {
    self.encoderListText.hidden = YES;
}

- (IBAction)pressPlayButton:(id)sender {
    
    if (self.curStatus != VCAppStatusNone){
        return ;
    }
    
    dispatch_async( decodeQueue, ^{
        self.curStatus = VCAppStatusPlay;
        BOOL bH265 = self.hevcEnabled;
        Class decoderClass;
        NSString *fileName;
        if (bH265) {
            decoderClass = [VT264Decoder class];
            fileName = @"test.h265";
        }
        else {
            decoderClass = [VT264Decoder class];
            fileName = @"test.h264";
        }
        self.decoder = [[decoderClass alloc] init];
        self.streamInput = [[ElementStream alloc] init];
        [self.streamInput open:fileName];
        NSData *sps = nil, *pps = nil, *vps = nil;
        packet *pkt = nil;
        DWDecodeParam cfg;
        cfg.sps = nil;
        cfg.spsLength = 0;
        cfg.pps = nil;
        cfg.ppsLength = 0;
        cfg.formatDesc = nil;
        cfg.codec_id = DWCodecIndexVT264DEC;
        uint32_t updateExtraDataFlag = 0;
        
        while ((pkt = [self.streamInput nextPacket])) {
            uint8_t nalType = 0;
            
            if (bH265) {
                nalType = (pkt.packetType >> 1) & 0x3f;
            }
            else {
                nalType = pkt.packetType & 0x1f;
            }
            
            NSLog(@"get a packet %d - %lu", nalType, pkt.length);
            
            switch (nalType) {
                case 0x5:
                {
                    [self.decoder reset:&cfg];
                    uint32_t nalSize = (uint32_t)(pkt.length - 4);
                    uint8_t *pNalSize = (uint8_t*)(&nalSize);
                    pkt.data[0] = *(pNalSize + 3);
                    pkt.data[1] = *(pNalSize + 2);
                    pkt.data[2] = *(pNalSize + 1);
                    pkt.data[3] = *(pNalSize);
                    NSData * data = [[NSData alloc] initWithBytes:pkt.data length:pkt.length];
                    
                    CMSampleBufferRef ref = [decoder createCMSampleBufferFromData:data andDesc:cfg.formatDesc];
                    [self.decoder decode:ref];
                    //CFRelease(ref);
                }
                    break;
                case 0x7:
                {
                    if (sps) {
                        sps = nil;
                    }
                    updateExtraDataFlag |= 1<<0;
                    NSData * data = [[NSData alloc] initWithBytes:(pkt.data+4) length:pkt.length-4];
                    sps = data;
                }
                    break;
                case 0x8:
                {
                    if (pps) {
                        pps = nil;
                    }
                    updateExtraDataFlag |= 1<<1;
                    NSData * data = [[NSData alloc] initWithBytes:(pkt.data+4) length:pkt.length-4];
                    pps = data;
                }
                    break;
                case 0x20:
                {
                    if (vps) {
                        vps = nil;
                    }
                    updateExtraDataFlag |= 1<<0;
                    NSData * data = [[NSData alloc] initWithBytes:(pkt.data+4) length:pkt.length-4];
                    vps = data;
                }
                    break;
                case 0x21:
                {
                    if (sps) {
                        sps = nil;
                    }
                    updateExtraDataFlag |= 1<<0;
                    NSData * data = [[NSData alloc] initWithBytes:(pkt.data+4) length:pkt.length-4];
                    sps = data;
                }
                    break;
                case 0x22:
                {
                    if (pps) {
                        pps = nil;
                    }
                    updateExtraDataFlag |= 1<<1;
                    NSData * data = [[NSData alloc] initWithBytes:(pkt.data+4) length:pkt.length-4];
                    pps = data;
                }
                    break;
                default:
                {
                    uint32_t nalSize = (uint32_t)(pkt.length - 4);
                    uint8_t *pNalSize = (uint8_t*)(&nalSize);
                    pkt.data[0] = *(pNalSize + 3);
                    pkt.data[1] = *(pNalSize + 2);
                    pkt.data[2] = *(pNalSize + 1);
                    pkt.data[3] = *(pNalSize);
                    NSData * data = [[NSData alloc] initWithBytes:pkt.data length:pkt.length];
                    CMSampleBufferRef ref = [decoder createCMSampleBufferFromData:data andDesc:cfg.formatDesc];
                    [self.decoder decode:ref];
                    //CFRelease(ref);
                }
                    break;
            }
            
            if (bH265) {
                if (updateExtraDataFlag & (~0x07)) {
                    if (cfg.formatDesc) {
                        CFRelease(cfg.formatDesc);
                    }
                    
                    cfg.formatDesc = [decoder createCMFormatDescFromVPS:vps andSPS:sps andPPS:pps];
                    updateExtraDataFlag = 0;
                }
            }
            else {
                if ((updateExtraDataFlag & 0x03) == 0x03) {
                    if (cfg.formatDesc) {
                        CFRelease(cfg.formatDesc);
                    }
                    
                    cfg.formatDesc =  [decoder createCMFormatDescFromSPS:sps andPPS:pps];
                    updateExtraDataFlag = 0;
                }
            }
            
            pkt = nil;
        }
        
        [self.decoder destroy];
        self.curStatus = VCAppStatusNone;
    } );
}


#pragma mark UISwitch

- (IBAction)onHevcSwitchValueChange:(id)sender {
    UISwitch *switcher = (UISwitch*)sender;
    self.hevcEnabled = [switcher isOn];
    NSLog(@"hevc is %@", self.hevcEnabled?@"enabled":@"disabled");
}


#pragma mark recording...
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


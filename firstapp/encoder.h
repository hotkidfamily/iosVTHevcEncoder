//
//  encoder.h
//  appTest
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>
#import "video.h"


typedef struct tagEncodeParam {
    uint32_t width;
    uint32_t height;
    uint32_t fps;
    uint32_t keyInterval; // gop size
    uint32_t bitrate; // in Kbps
    uint32_t maxBitrate; //in kbps
    DWCodecIndex codec_id;
}DWEncodeParam;


typedef struct tagEncodeStat {
    uint32_t frameCount;
    uint32_t workingDuration;
}DWEncodeStat;


@protocol EncoderDataDelegate <NSObject>

- (void)gotExtraData:(NSData *)vps sps:(NSData*)sps pps:(NSData*)pps;
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;

@end


@interface Encoder : NSObject {
@public
    DWEncodeStat stats;
@protected
    DWEncodeParam params;
}

@property(nonatomic) NSString *name;
@property(nonatomic) DWVideoStandard standard;
@property(nonatomic) DWCodecIndex index;
@property(nonatomic) DWCodecType type;
@property(weak, nonatomic) id<EncoderDataDelegate> delegate;

+ (NSString *)listEncoders;

-(BOOL)reset:(DWEncodeParam *)params;
-(BOOL)encode:(CMSampleBufferRef)buffer;
-(BOOL)flush;
-(BOOL)destroy;
-(NSString *)description;

@end

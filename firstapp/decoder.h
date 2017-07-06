//
//  decoder.h
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "video.h"


typedef struct tagDecodeParam {
    DWCodecIndex codec_id;
}DWDecodeParam;


typedef struct tagDecodeStat {
    uint32_t frameCount;
    uint32_t workingDuration;
    uint32_t failCount;
}DWDecodeStat;

@protocol DecoderDataDelegate <NSObject>

- (void)gotDecodedData:(CMSampleBufferRef)samplebuffer;

@end

@interface decoder : NSObject {
@public
    DWDecodeStat stats;
@protected
    DWDecodeParam params;
}

@property(nonatomic) NSString *name;
@property(nonatomic) DWVideoStandard standard;
@property(nonatomic) DWCodecIndex index;
@property(nonatomic) DWCodecType type;
@property(weak, nonatomic) id<DecoderDataDelegate> delegate;

+ (NSString *)listDecoders;

-(BOOL)reset:(DWDecodeParam *)params;
-(BOOL)decode:(CMSampleBufferRef)buffer;
-(BOOL)flush;
-(BOOL)destroy;
-(NSString *)description;

@end



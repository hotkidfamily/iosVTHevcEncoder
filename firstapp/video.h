//
//  video.h
//  firstapp
//
//  Created by yanli on 2017/7/6.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#ifndef video_h
#define video_h

typedef NS_ENUM(NSUInteger, DWVideoStandard){
    DWVideoStandardNone = 0,
    DWVideoStandardH264,
    DWVideoStandardHEVC,
};


typedef NS_ENUM(NSUInteger, DWCodecIndex){
    DWCodecIndexNone,
    DWCodecIndexLIBX264,
    DWCodecIndexLIBX265,
    DWCodecIndexVT264,
    DWCodecIndexVTHEVC,
    DWCodecIndexVT264DEC,
    DWCodecIndexVTHEVCDEC,
};


typedef NS_ENUM(NSUInteger, DWCodecType){
    DWCodecTypeNone,
    DWCodecTypeEncoder,
    DWCodecTypeDecoder,
};

static const Byte startCode[4] = { 0x00, 0x00, 0x00, 0x01 };

#endif /* video_h */

//
//  outputStream.m
//  firstapp
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "outputStream.h"

const Byte startCode[4] = { 0x00, 0x00, 0x00, 0x01 };

@implementation outputStream 

- (void)initFileManager {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *h264File = [documentsDirectory stringByAppendingPathComponent:@"test.h265"];
    [fileManager removeItemAtPath:h264File error:nil];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
}

- (void)destoryFileManager {
    [self.fileHandle closeFile];
}

- (void)writeData:(NSData *)data {
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:data];
}

- (void)gotExtraData:(NSData*)vps sps:(NSData*)sps pps:(NSData*)pps
{
    NSData *nalCode = [NSData dataWithBytes:startCode length:4];
    if(vps != nil){
        [self writeData:nalCode];
        [self writeData:vps];
    }
    [self writeData:nalCode];
    [self writeData:sps];
    [self writeData:nalCode];
    [self writeData:pps];
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSData *nalCode = [NSData dataWithBytes:startCode length:4];
    [self writeData:nalCode];
    [self writeData:data];
}

@end

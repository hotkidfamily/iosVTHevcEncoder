//
//  outputStream.m
//  firstapp
//
//  Created by yanli on 2017/7/3.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "outputStream.h"

@implementation OutputStream

- (void)open:(NSString*)fileName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
    [fileManager removeItemAtPath:filePath error:nil];
    [fileManager createFileAtPath:filePath contents:nil attributes:nil];
    
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
}

- (void)close {
    [self.fileHandle closeFile];
}

- (void)writeData:(NSData *)data {
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:data];
}


#pragma mark - EncoderDataDelegate

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

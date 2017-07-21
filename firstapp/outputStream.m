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
    NSString *tempDir = NSTemporaryDirectory();
    
    NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
    
    self.fileHandle = [[NSOutputStream alloc] initToFileAtPath:filePath append:NO];
    [self.fileHandle open];
}

- (void)close {
    [self.fileHandle close];
}

- (void)writeData:(NSData *)data {
    NSInteger ret = [self.fileHandle write:data.bytes maxLength:data.length];
    if (ret <= 0){
        NSLog(@"write data error.");
    } 
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

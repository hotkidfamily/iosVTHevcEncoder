//
//  elementStream.m
//  firstapp
//
//  Created by yanli on 2017/7/7.
//  Copyright © 2017年 YY Inc. All rights reserved.
//

#import "elementStream.h"


@interface packet ()
@property(nonatomic) NSUInteger capability;
@end

@implementation packet

- (instancetype)initWithSize:(NSUInteger)size
{
    self = [super init];
    self.capability = size + 16;
    self.data = malloc(self.capability);
    self.length = size;
    
    return self;
}

- (void)dealloc
{
    if (self.data) {
        free(self.data);
    }
    
    self.data = nil;
    self.capability = 0;
    self.length = 0;
}

@end

@interface ElementStream () {
    uint8_t *buffer;
    NSInteger bufferSize;
    NSInteger bufferCap;
}

@property NSString *fileName;
@property NSInputStream *streamReader;

@end


@implementation ElementStream

- (BOOL)open:(NSString *)fileName
{
    bufferSize = 0;
    bufferCap = 400*1024;
    buffer = malloc(bufferCap);
    self.fileName = fileName;
    
    NSString *tempDir = NSTemporaryDirectory();
    NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
    
    self.streamReader = [NSInputStream inputStreamWithFileAtPath:filePath];
    [self.streamReader open];
    
    return YES;
}

- (packet*)nextPacket
{
    if(bufferSize < bufferCap && self.streamReader.hasBytesAvailable) {
        NSInteger readBytes = [self.streamReader read:buffer + bufferSize maxLength:bufferCap - bufferSize];
        bufferSize += readBytes;
    }
    
    if(memcmp(buffer, startCode, 4) != 0) {
        return nil;
    }
    
    if(bufferSize >= 5) {
        uint8_t *bufferBegin = buffer + 4;
        uint8_t *bufferEnd = buffer + bufferSize;
        while(bufferBegin != bufferEnd) {
            if(*bufferBegin == 0x01) {
                if(memcmp(bufferBegin - 3, startCode, 4) == 0) {
                    NSInteger packetSize = bufferBegin - buffer - 3;
                    packet *vp = [[packet alloc] initWithSize:packetSize];
                    memcpy(vp.data, buffer, packetSize);
                    vp.packetType = vp.data[4];
                    
                    memmove(buffer, buffer + packetSize, bufferSize - packetSize);
                    bufferSize -= packetSize;
                    
                    return vp;
                }
            }
            ++bufferBegin;
        }
    }
    return nil;
}


- (void)close
{
    if (buffer) {
        free(buffer);
    }
    
    buffer = 0;
    bufferCap = 0;
    bufferSize = 0;
    
    [self.streamReader close];
}

@end


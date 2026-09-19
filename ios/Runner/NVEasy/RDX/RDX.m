//
//  RDX.m
//  NVEasyDemo
//
//  Created by zlj on 2025/1/9.
//

#import "RDX.h"
#import <NVEasyAudioProcess/NVEasyAudioToMic.h>

//void audio2mic_rb_init(unsigned char* plaintext);
//
//int audio2mic_rb_process(short* indata, short* outdata, unsigned char* ciphertext);

const NSInteger kRDXPCMLength = 256 * 2 * 2;

@implementation RDX

+ (NSInteger)pcmLength {
    return kRDXPCMLength;
}

+ (NSData *)plainText {
    unsigned char plaintext[16];
    [NVEasyAudioToMic audio2mic_rb_init:plaintext];
    NSData *data = [NSData dataWithBytes:plaintext length:16];
    return data;
}

//双声道pcm, 2位深, Int16
//一次处理256个点（Int16）的数据 * 2声道
//pcm必须为 256 * 2 * 2
+ (NSData *_Nullable)process:(NSData *)pcm cipher:(NSData *)cipher {
    
    if (pcm.length != kRDXPCMLength) {
        return nil;
    }
    
//    unsigned char ciphertext[16] = { 0xff,0x33,0xf3,0xd6,0x6e,0x98,0x29,0x7a,0xec,0x15,0xba,0xfa,0x24,0x88,0x0e,0xdd };
//    NSData *cipherData = [[NSData alloc] initWithBytes:ciphertext length:sizeof(ciphertext)];

    NSInteger outLength = [pcm length] / 2;
    int16_t *inData = (int16_t *)[pcm bytes];
    int16_t *outData = (int16_t *)malloc(outLength);  // 分配输出数据的内存空间，假设输出长度和输入长度相同，实际可能需要调整
//    int result = [NVEasyAudioToMic audio2mic_rb_processIndata:inData outdata:outData ciphertext:(unsigned char *)cipherData.bytes];
    int result = [NVEasyAudioToMic audio2mic_rb_processIndata:inData outdata:outData ciphertext:(unsigned char *)cipher.bytes];

    NSLog(@"%d,", result);
    if (result == 0) {
        free(outData);
        return nil;
    } else {
        NSData *outputData = [NSData dataWithBytes:outData length:outLength];
        free(outData);
        return outputData;
    }
}

@end

//
//  NVEasyAudioToMic.h
//  NVEasyAudioProcess
//
//  Created by zlj on 2025/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NVEasyAudioToMic : NSObject

+ (void)audio2mic_rb_init:(unsigned char*)plaintext;

+ (int)audio2mic_rb_processIndata:(short*)indata outdata:(short*)outdata ciphertext:(unsigned char*)ciphertext;

@end

NS_ASSUME_NONNULL_END

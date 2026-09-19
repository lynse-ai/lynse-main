#ifndef _AUDIO2MIC_RB_H_
#define _AUDIO2MIC_RB_H_
#ifdef __cplusplus
extern "C" {
#endif

void audio2mic_rb_init(unsigned char* plaintext);

int audio2mic_rb_process(short* indata, short* outdata, unsigned char* ciphertext);

#ifdef __cplusplus
}
#endif
#endif
//
//  RDX.h
//  NVEasyDemo
//
//  Created by zlj on 2025/1/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RDX : NSObject

+ (NSInteger)pcmLength;

+ (NSData *)plainText;

//双声道pcm, 2位深, Int16
//一次处理256个点（Int16）的数据 * 2声道
//pcm必须为 256 * 2 * 2
+ (NSData * _Nullable)process:(NSData *)pcm cipher:(NSData *)cipher;

@end

NS_ASSUME_NONNULL_END

//
//  NVOpusCodec.h
//  opus
//
//  Created by zlj on 2024/11/19.
//  Copyright © 2024 Viv Labs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NVOpusCodec : NSObject

+ (void)enqueueAudio40DataToDecode:(NSData *)opus completion:(void (^ __nullable)(NSData *__nullable))completion;
+ (void)enqueueAudio80DataToDecode:(NSData *)opus completion:(void (^ __nullable)(NSData *__nullable))completion;

@end

NS_ASSUME_NONNULL_END

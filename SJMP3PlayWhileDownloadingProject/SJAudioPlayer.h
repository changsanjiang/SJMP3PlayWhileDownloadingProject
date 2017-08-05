//
//  SJAudioPlayer.h
//  SJMP3PlayWhileDownloadingProject
//
//  Created by BlueDancer on 2017/6/21.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SJAudioPlayerPlayProtocol;

@protocol SJAudioPlayerDelegate;

@interface SJAudioPlayer : NSObject

@property (nonatomic, weak,   readwrite) id<SJAudioPlayerDelegate> delegate;

@property (nonatomic, assign, readwrite) CGFloat rate;

@property (nonatomic, strong, readonly) NSString *currentPlayingURLStr;

@property (nonatomic, assign, readonly) BOOL playStatus;

/*!
 *  初始化
 */
+ (instancetype)player;

/*!
 *  播放
 */
- (void)playAudioWithPlayURL:(NSString *)playURL;

/*!
 *  从指定的进度播放
 */
- (void)setPlayProgress:(float)progress;

/*!
 *  暂停
 */
- (void)pause;

/*!
 *  恢复播放
 */
- (void)resume;

/*!
 *  停止播放, 停止缓存
 */
- (void)stop;

/*!
 *  清除本地缓存
 */
- (void)clearDiskAudioCache;

/*!
 *  已缓存的audios的大小
 */
- (NSInteger)diskAudioCacheSize;

/*!
 *  查看音乐是否已缓存
 */
- (BOOL)checkMusicHasBeenCachedWithPlayURL:(NSString *)playURL;

@end


@protocol SJAudioPlayerPlayProtocol <NSObject>

@required

@property (nonatomic, strong) NSString *playUrl;

@end


@protocol SJAudioPlayerDelegate <NSObject>

@optional

- (void)audioPlayer:(SJAudioPlayer *)player audioDownloadProgress:(CGFloat)progress;

- (void)audioPlayer:(SJAudioPlayer *)player currentTime:(NSTimeInterval)currentTime reachableTime:(NSTimeInterval)reachableTime totalTime:(NSTimeInterval)totalTime;

- (void)audioPlayerDidFinishPlaying:(SJAudioPlayer *)player;

@end

NS_ASSUME_NONNULL_END

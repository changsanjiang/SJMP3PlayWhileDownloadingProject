//
//  SJAudioPlayer.m
//  SJMP3PlayWhileDownloadingProject
//
//  Created by BlueDancer on 2017/6/21.
//  Copyright © 2017年 SanJiang. All rights reserved.
//

#import "SJAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "NSObject+Extension.h"
#import "NSDate+Extension.h"
#import <objc/message.h>
#import "YYTimer.h"

#define DBugLog

/**
 *  0.00 - 1.00
 *  If it's 1.00, play after download.
 */
#define SJAudioWhenToStartPlaying   (0.025)

NSString *const SJAudioPlayerDownloadAudioIdentifier = @"com.dancebaby.lanwuzhe.audioCacheSession";



@interface SJAudioPlayer (NSURLSessionDownloadDelegateMethos) <NSURLSessionDownloadDelegate>
@end



@interface SJAudioPlayer (AVAudioPlayerDelegateMethods) <AVAudioPlayerDelegate>
@end



typedef NS_ENUM(NSUInteger, SJAudioPlayerDownloadStatus) {
    SJAudioPlayerDownloadStatus_Unknown,
    SJAudioPlayerDownloadStatus_Start,
    SJAudioPlayerDownloadStatus_Ing,
    SJAudioPlayerDownloadStatus_End,
    SJAudioPlayerDownloadStatus_Error,
};

static NSMutableDictionary<NSString *, void (^)()> *_completionHandlerDictionary;

@interface SJAudioPlayer ()

@property (nonatomic, strong, readwrite) AVAudioPlayer *audioPlayer;

@property (nonatomic, strong, readonly)  NSURLSession *audioCacheSession;

@property (nonatomic, strong) NSString *currentPlayingURLStr;

/*!
 *  All DownloadTask
 *  Key : DownloadURL Hash
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSURLSessionDownloadTask *> *audioDownloadTaskDictM;

/*!
 *  All AppleTmpDownload Data Path
 *  Key : DownlaodURL Hash
 *  Value : ItemPath
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *tmpDownloadingItemPathDictM;

/*!
 *  Audio Play duration
 *  Key   : DownlaodURL Hash
 *  Value : NSNumber type int64_t
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSNumber *> *reachableTimeDictM;


@property (nonatomic, strong, readonly) YYTimer *checkAudioTimeTimer;

@property (nonatomic, assign, readwrite) BOOL userClickedPause;

@property (nonatomic, strong, readonly) NSOperationQueue *oprationQueue;

@property (nonatomic, strong) NSString *oldPlayURLStr;

@end





@implementation SJAudioPlayer

@synthesize audioCacheSession = _audioCacheSession;
@synthesize audioDownloadTaskDictM = _audioDownloadTaskDictM;
@synthesize tmpDownloadingItemPathDictM = _tmpDownloadingItemPathDictM;
@synthesize reachableTimeDictM = _reachableTimeDictM;
@synthesize checkAudioTimeTimer = _checkAudioTimeTimer;
@synthesize oprationQueue = _oprationQueue;

// MARK: Init

- (instancetype)init {
    self = [super init];
    if (self) {
        
        [self _SJAudioPlayerInitialize];
        
        [self _SJAddObservers];
        
    }
    return self;
}

- (void)dealloc {
    [self _SJRemoveObservers];
    [self _SJClearTimer];
}

// MARK: Public

/**
 *  初始化
 */
+ (instancetype)player {
    return [self new];
}

/**
 *  播放
 */
- (void)playAudioWithPlayURL:(NSString *)playURL {
    
    if ( nil == playURL ) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( [self.delegate respondsToSelector:@selector(audioPlayer:currentTime:reachableTime:totalTime:)] ) [self.delegate audioPlayer:self currentTime:0 reachableTime:0 totalTime:0];
    });
    
    [self stop];
    
    self.userClickedPause = NO;
    
    self.currentPlayingURLStr = playURL;
    
    if ( _SJCacheExistsWithURLStr(playURL) || [playURL hasPrefix:@"file"]  )[self _SJPlayLocalCacheWithURLStr:playURL];
    else [self _SJStartDownloadWithURLStr:playURL];
}

/**
 *  从指定的进度播放
 */
- (void)setPlayProgress:(float)progress {
    if ( !self.audioPlayer ) return;
    
    NSTimeInterval reachableTime = 0;
    NSString *hashStr = [self _SJGetAudioPlayerItemPathMemoryHashKey];
    if ( hashStr ) reachableTime = [self.reachableTimeDictM[hashStr] integerValue];
    else reachableTime = self.audioPlayer.duration;
    
    if ( self.audioPlayer.duration * progress <= reachableTime ) self.audioPlayer.currentTime = self.audioPlayer.duration * progress;
}

/**
 *  暂停
 */
- (void)pause {
    
    self.userClickedPause = YES;
    
    if ( !self.audioPlayer.isPlaying ) return;
    
    [self.audioPlayer pause];
    
    [self.checkAudioTimeTimer invalidate];
    
    _checkAudioTimeTimer = nil;
}

/**
 *  恢复播放
 */
- (void)resume {
    
    self.userClickedPause = NO;
    
    if ( self.audioPlayer.isPlaying ) return;
    
    if ( nil == self.audioPlayer ) {
        [self playAudioWithPlayURL:self.currentPlayingURLStr];
    }
    else {
        if ( ![self.audioPlayer prepareToPlay] ) return;
        [self.audioPlayer play];
    }
    [self checkAudioTimeTimer];
}

/**
 *  停止播放, 停止缓存
 */
- (void)stop {
    
    self.userClickedPause = YES;
    
    if ( !self.audioPlayer ) return;
    
    NSString *ItemPath = self.audioPlayer.url.absoluteString;
    if ( !ItemPath ) return;
    if ( [ItemPath hasPrefix:@"file"] ) /* file:// */ ItemPath = [ItemPath substringFromIndex:7];
    
    NSString *hashKey = [self _SJGetAudioPlayerItemPathMemoryHashKey];
    
    if ( hashKey ) [self _SJClearMemoryDictCacheWithURLHashStr:hashKey];
    
    [self.audioPlayer stop];
    _audioPlayer = nil;
    
    [self.checkAudioTimeTimer invalidate];
    _checkAudioTimeTimer = nil;
    
}

/**
 *  清除本地缓存
 */
- (void)clearDiskAudioCache {
    if ( self.audioPlayer ) [self.audioPlayer stop];
    
    if ( _SJCacheFolderPath() )
        [_SJCacheItemPaths() enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [[NSFileManager defaultManager] removeItemAtPath:obj error:nil];
        }];
    
    if ( _SJResumeDataFolderPath() )
        [_SJResumeDataItemPaths() enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [[NSFileManager defaultManager] removeItemAtPath:obj error:nil];
        }];
}

/**
 *  已缓存的大小
 */
- (NSInteger)diskAudioCacheSize {
    
    __block NSInteger size = 0;
    if ( _SJCacheFolderPath() ) {
        [_SJCacheItemPaths() enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary<NSFileAttributeKey, id> *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:obj error:nil];
            size += [dict[NSFileSize] integerValue] / 1000 / 1000;
        }];
    }
    
    if ( _SJResumeDataFolderPath() ) {
        [_SJResumeDataItemPaths() enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSDictionary<NSFileAttributeKey, id> *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:obj error:nil];
            size += [dict[NSFileSize] integerValue] / 1000 / 1000;;
        }];
    }
    
    return size;
}

- (NSString *)_SJGetAudioPlayerItemPathMemoryHashKey {
    
    NSString *ItemPath = self.audioPlayer.url.absoluteString;
    if ( !ItemPath ) return nil;
    if ( [ItemPath hasPrefix:@"file"] ) /* file:// */ ItemPath = [ItemPath substringFromIndex:7];
    
    __block NSString *URLHashStr = nil;
    [self.tmpDownloadingItemPathDictM enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull HashStr, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        if ( [obj isEqualToString:ItemPath] ) {
            URLHashStr = HashStr;
            *stop = YES;
        }
    }];
    return URLHashStr;
}

- (void)_SJClearTimer {
    [self.checkAudioTimeTimer invalidate];
    _checkAudioTimeTimer = nil;
}

// MARK: Observers

- (void)_SJAddObservers {
    [self addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)_SJRemoveObservers {
    [self removeObserver:self forKeyPath:@"rate"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    if ( object != self ) { return;}
    
    if ( [keyPath isEqualToString:@"rate"] ) self.audioPlayer.rate = self.rate;
}

// MARK: Private

- (void)_SJAudioPlayerInitialize {
    
    if ( !_SJFolderExists() ) _SJCreateFolder();
    
    self.rate = 1;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive: YES error: nil];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
}

/**
 *  定时器事件
 */
- (void)_SJCheckAudioTime {
    if ( !self.audioPlayer ) return;
    
    NSTimeInterval currentTime = self.audioPlayer.currentTime;
    NSTimeInterval totalTime = self.audioPlayer.duration;
    NSTimeInterval reachableTime = 0;
    
    if ( totalTime < 5 ) return;
    
    NSString *hashStr = [self _SJGetAudioPlayerItemPathMemoryHashKey];
    if ( hashStr )
        reachableTime = [self.reachableTimeDictM[hashStr] integerValue];
    else reachableTime = self.audioPlayer.duration;
    
    if ( ![self.delegate respondsToSelector:@selector(audioPlayer:currentTime:reachableTime:totalTime:)] ) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate audioPlayer:self currentTime:currentTime reachableTime:reachableTime totalTime:totalTime];
    });
}

/**
 *  播放状态
 */
- (BOOL)playStatus {
    return self.audioPlayer.isPlaying;
}

- (void)_SJPlayLocalCacheWithURLStr:(NSString *)URLStr {
    
    __weak typeof(self) _self = self;
    [self.oprationQueue addOperationWithBlock:^{
        __strong typeof(_self) self = _self;
        
        if ( !self ) return;
        
        NSURL *contentsURL = nil;
        
        if ( [URLStr hasPrefix:@"file"] )
            contentsURL = [NSURL URLWithString:URLStr];
        else contentsURL = [NSURL fileURLWithPath:_SJCachePathWithURLStr(URLStr)];
        
        [self _SJPlayWithFileURL:contentsURL];
    }];
}

- (void)_SJPlayWithFileURL:(NSURL *)fileURL {
    
    @synchronized (self) {
        
        if ( nil != self.oldPlayURLStr && [self.audioPlayer.url.absoluteString isEqualToString:self.oldPlayURLStr] ) {
            return;
        }
        
        NSError *error = nil;
        
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL fileTypeHint:AVFileTypeMPEGLayer3 error:&error];
        
        if ( error ) return;
        
        if ( !self.audioPlayer ) return;
        
        self.audioPlayer.enableRate = YES;
        
        if ( ![self.audioPlayer prepareToPlay] ) return;
        
        self.audioPlayer.delegate = self;
        
#ifdef DBugLog
        NSLog(@"\n-开始播放\n-持续时间: %f 秒\n-播放地址为: %@", self.audioPlayer.duration, fileURL);
        NSLog(@"\n-线程: %@ \n", [NSThread currentThread]);
#endif
        if ( self.audioPlayer.duration < 5 ) return;
        
        [self.audioPlayer play];
        
        self.audioPlayer.rate = self.rate;
        
        self.oldPlayURLStr = self.audioPlayer.url.absoluteString;
        
        [self checkAudioTimeTimer];
    }
}


- (void)_SJStartDownloadWithURLStr:(NSString *)URLStr {
    
    NSURL *URL = [NSURL URLWithString:URLStr];
    
    if ( !URL ) return;
    
    NSURLSessionDownloadTask *task = nil;
    
    task = self.audioDownloadTaskDictM[_SJHashStr(URLStr)];
    
    if ( task ) [task cancel];
    
    task = [self.audioCacheSession downloadTaskWithRequest:[NSURLRequest requestWithURL:URL]];
    
    if ( !task ) return;
    
    [task resume];
    
    self.audioDownloadTaskDictM[_SJHashStr(URLStr)] = task;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.tmpDownloadingItemPathDictM[_SJHashStr(URLStr)] = _SJDownloadingItemPath();
    });
}

- (void)_SJClearMemoryDictCacheWithURLStr:(NSString *)URLStr {
    NSString *hashStr = _SJHashStr(URLStr);
    [self _SJClearMemoryDictCacheWithURLHashStr:hashStr];
}

- (void)_SJClearMemoryDictCacheWithURLHashStr:(NSString *)hashStr {
    NSURLSessionDownloadTask *task = self.audioDownloadTaskDictM[hashStr];
    if ( task.state != NSURLSessionTaskStateCompleted && task.state != NSURLSessionTaskStateCanceling) [task cancel];
    self.audioDownloadTaskDictM[hashStr] = nil;
    self.tmpDownloadingItemPathDictM[hashStr] = nil;
    self.reachableTimeDictM[hashStr] = nil;
}

- (NSString *)_SJCurrentPlayItemDownloadHashURLStr {
    NSString *ItemPath = self.audioPlayer.url.absoluteString;
    if ( !ItemPath ) return nil;
    if ( [ItemPath hasPrefix:@"file"] ) /* file:// */ ItemPath = [ItemPath substringFromIndex:7];
    
    __block NSString *hashStr = nil;
    [self.tmpDownloadingItemPathDictM enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull URLHashStr, NSString * _Nonnull itemP, BOOL * _Nonnull stop) {
        if ( [itemP isEqualToString:ItemPath] ) {
            hashStr = URLHashStr;
            *stop = YES;
        }
    }];
    return hashStr;
}

// MARK: Getter

- (NSURLSession *)audioCacheSession {
    if ( nil == _audioCacheSession ) {
        NSURLSessionConfiguration *cofig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:SJAudioPlayerDownloadAudioIdentifier];
        _audioCacheSession = [NSURLSession sessionWithConfiguration:cofig delegate:self delegateQueue:self.oprationQueue];
    }
    return _audioCacheSession;
}

- (NSOperationQueue *)oprationQueue {
    if ( nil == _oprationQueue ) {
        _oprationQueue = [NSOperationQueue new];
        _oprationQueue.maxConcurrentOperationCount = 1;
        _oprationQueue.name = @"com.dancebaby.lanwuzhe.audioCacheSessionOprationQueue";
    }
    return _oprationQueue;
}

- (NSMutableDictionary<NSString *,NSURLSessionDownloadTask *> *)audioDownloadTaskDictM {
    if ( nil == _audioDownloadTaskDictM ) {
        _audioDownloadTaskDictM = [NSMutableDictionary new];
    }
    return _audioDownloadTaskDictM;
}

- (NSMutableDictionary<NSString *,NSString *> *)tmpDownloadingItemPathDictM {
    if ( nil == _tmpDownloadingItemPathDictM ) {
        _tmpDownloadingItemPathDictM = [NSMutableDictionary new];
    }
    return _tmpDownloadingItemPathDictM;
}

+ (NSMutableDictionary<NSString *,void (^)()> *)completionHandlerDictionary {
    if ( nil == _completionHandlerDictionary ) {
        _completionHandlerDictionary = [NSMutableDictionary new];
    }
    return _completionHandlerDictionary;
}

- (NSMutableDictionary<NSString *,NSNumber *> *)reachableTimeDictM {
    if ( nil == _reachableTimeDictM ) {
        _reachableTimeDictM = [NSMutableDictionary new];
    }
    return _reachableTimeDictM;
}

- (YYTimer *)checkAudioTimeTimer {
    if ( nil == _checkAudioTimeTimer) {
        _checkAudioTimeTimer = [YYTimer timerWithTimeInterval:0.1 target:self selector:@selector(_SJCheckAudioTime) repeats:YES];
        [_checkAudioTimeTimer fire];
    }
    return _checkAudioTimeTimer;
}

// MARK: File Path

BOOL _SJFolderExists() { return [[NSFileManager defaultManager] fileExistsAtPath:_SJFolderPath()];}

BOOL _SJCacheFolderExists() { return [[NSFileManager defaultManager] fileExistsAtPath:_SJCacheFolderPath()];}

BOOL _SJReusmeDataFolderExists() { return [[NSFileManager defaultManager] fileExistsAtPath:_SJResumeDataFolderPath()];}

BOOL _SJCacheExistsWithURLStr(NSString *URLStr) { return [[NSFileManager defaultManager] fileExistsAtPath:_SJCachePathWithURLStr(URLStr)];}

BOOL _SJAppleTmpDownloadCacheDataExists() { return [[NSFileManager defaultManager] fileExistsAtPath:_NSURLSessionTmpFolderPath()];}

/**
 *  ../com.dancebaby.lanwuzhe.audioCacheFolder/
 */

NSString *_SJFolderPath() {
    NSString *sCachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    NSString *folderPath = [sCachePath stringByAppendingPathComponent:@"com.dancebaby.lanwuzhe.audioCacheFolder"];
    return folderPath;
}

NSString *_SJCacheFolderPath() { return [_SJFolderPath() stringByAppendingPathComponent:@"cache"];}

NSString *_SJResumeDataFolderPath() { return [_SJFolderPath() stringByAppendingPathComponent:@"resumeData"];}

/**
 *  Root Cache + cache + resumeData
 */
void _SJCreateFolder() {
    [[NSFileManager defaultManager] createDirectoryAtPath:_SJCacheFolderPath() withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:_SJResumeDataFolderPath() withIntermediateDirectories:YES attributes:nil error:nil];
}

/**
 *  ../com.dancebaby.lanwuzhe.audioCacheFolder/cache/StrHash
 */
NSString *_SJCachePathWithURLStr(NSString *URLStr) {
    NSString *cacheName = [_SJHashStr(URLStr) stringByAppendingString:@".mp3"];
    return [_SJCacheFolderPath() stringByAppendingPathComponent:cacheName];
}

/**
 *  Apple Tmp Folder Path
 *  ../Library/Caches/com.apple.nsurlsessiond/Downloads/com.dancebaby.SJAudioPlayer/CFNetworkDownload_Pwvolm.tmp
 */
NSString *_NSURLSessionTmpFolderPath() {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSString *pathComponent = [NSString stringWithFormat:@"com.apple.nsurlsessiond/Downloads/%@", bundleId];
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:pathComponent];
}

NSString *_SJDownloadingItemPath() {
    NSString *tmpFolder = _NSURLSessionTmpFolderPath();
    NSArray<NSString *> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpFolder error:nil];
    
    if ( 0 == items.count ) return nil;
    
    if ( 1 == items.count ) return [tmpFolder stringByAppendingPathComponent:items.firstObject];
    
    NSDictionary<NSFileAttributeKey, id> *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:[tmpFolder stringByAppendingPathComponent:items.firstObject] error:nil];
    __block NSDate *newItemDate = dict[NSFileCreationDate];
    __block NSString *newItemPath = nil;
    [items enumerateObjectsUsingBlock:^(NSString * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( 0 != idx ) {
            NSString *itemPath = [tmpFolder stringByAppendingPathComponent:item];
            NSDictionary<NSFileAttributeKey, id> *attrDict = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
            NSDate *itemDate = attrDict[NSFileCreationDate];
            NSComparisonResult result = [newItemDate compare:itemDate];
            if ( result == NSOrderedAscending ) {
                newItemDate = itemDate;
                newItemPath = itemPath;
            }
        }
    }];
    return newItemPath;
}

NSArray<NSString *> *_SJCacheItemPaths() { return _SJContentsOfPath(_SJCacheFolderPath());}

NSArray<NSString *> *_SJResumeDataItemPaths() { return _SJContentsOfPath(_SJResumeDataFolderPath());}

NSArray<NSString *> *_SJContentsOfPath(NSString *path) {
    NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    NSMutableArray<NSString *> *itemPaths = [NSMutableArray new];
    [paths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [itemPaths addObject:[path stringByAppendingPathComponent:obj]];
    }];
    return itemPaths;
}

NSString *_SJHashStr(NSString *str) { return [NSString stringWithFormat:@"%zd", [str hash]];}

@end

// MARK: Session Delegate
/* 保持只有一个任务在下载 */
@implementation SJAudioPlayer (NSURLSessionDownloadDelegateMethos)

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    NSString *URLStr = downloadTask.currentRequest.URL.absoluteString;
    
#ifdef DBugLog
    NSLog(@"\n-下载完成: %@", URLStr);
#endif
    
    NSString *cachePath = _SJCachePathWithURLStr(URLStr);
    
    BOOL moveResult = [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:cachePath error:nil];
    
    if ( !moveResult ) return;
    
    if ( self.audioPlayer.isPlaying ) return;
    
    if ( self.userClickedPause ) return;
    
    NSURL *fileURL = [NSURL fileURLWithPath:cachePath];
    
    if ( !fileURL ) return;
    
    [self _SJPlayWithFileURL:fileURL];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    
    //    if ( -999 == error.code ) return;
    
#ifdef DBugLog
    if ( error ) NSLog(@"\n-下载报错: %@", error);
#endif
    
    NSString *URLStr = task.currentRequest.URL.absoluteString;
    [self _SJClearMemoryDictCacheWithURLStr:URLStr];
}

- (void)_SJClearDiskDownloadingCacheWithURLStr:(NSString *)URLStr {
    
    NSString *itemPath = self.tmpDownloadingItemPathDictM[_SJHashStr(URLStr)];
    
    if ( !itemPath ) return;
    
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:itemPath] ) return;
    
    [[NSFileManager defaultManager] removeItemAtPath:itemPath error:nil];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
#ifdef DBugLog
    NSLog(@"-写入大小: %zd", totalBytesWritten);
#endif
    
    if ( 0 == totalBytesExpectedToWrite ) return;
    
    NSString *URLStr = downloadTask.currentRequest.URL.absoluteString;
    
    CGFloat progress = totalBytesWritten * 1.0 / totalBytesExpectedToWrite;
    
    CGFloat reachableTime = self.audioPlayer.duration * progress;
    
    self.reachableTimeDictM[_SJHashStr(URLStr)] = @(reachableTime);
    
    if ( [self.delegate respondsToSelector:@selector(audioPlayer:audioDownloadProgress:)] )
        [self.delegate audioPlayer:self audioDownloadProgress:progress];
    
    if ( self.userClickedPause ) return;
    
    if ( progress > SJAudioWhenToStartPlaying ) [self _SJReadyPlayDownloadingAudio:URLStr];
    
}

- (void)_SJReadyPlayDownloadingAudio:(NSString *)URLStr {
    
    if ( self.audioPlayer.isPlaying ) return;
    
    NSString *ItemPath = _tmpDownloadingItemPathDictM[_SJHashStr(URLStr)];
    
    if ( !ItemPath ) return;
    
    NSURL *fileURL = [NSURL fileURLWithPath:ItemPath];
    
    if ( !fileURL ) return;
    
    [self _SJPlayWithFileURL:fileURL];
}

/*!
 *  应用在后台，而且后台所有下载任务完成后，调用.
 */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    
    if (session.configuration.identifier) {
        // 调用在 -application:handleEventsForBackgroundURLSession: 中保存的 handler
        [self callCompletionHandlerForSession:session.configuration.identifier];
    }
}

- (void)callCompletionHandlerForSession:(NSString *)identifier {
    
    void (^handler)()  = [self class].completionHandlerDictionary[identifier];
    if ( !handler) return;
    handler();
    [self class].completionHandlerDictionary[identifier] = nil;
    
}


@end


@implementation SJAudioPlayer (AVAudioPlayerDelegateMethods)

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if ( self.audioPlayer.duration < 3 ) return;
    
    if ( ![self.delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:)] ) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate audioPlayerDidFinishPlaying:self];
    });
}

- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {
    if ( self.audioPlayer.isPlaying ) [self pause];
}

-(void)audioPlayerEndInterruption:(AVAudioPlayer *)player withOptions:(NSUInteger)flags {
    
    if ( ![self.audioPlayer prepareToPlay] ) return;
    
    [self.audioPlayer play];
}

@end

//
//  VideoPlayViewController.m
//  StreamingTestVLC
//
//  Created by Shin Chang Keun on 2018. 3. 26..
//  Copyright © 2018년 kokoro. All rights reserved.
//

#import "VideoPlayViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface VideoPlayViewController () <AVAudioSessionDelegate, VLCMediaPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIView *movieView;
@property (weak, nonatomic) IBOutlet UIView *titleParent;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UIView *controlParent;
@property (weak, nonatomic) IBOutlet UILabel *positionLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *downloadProgress;
@property (weak, nonatomic) IBOutlet UISlider *sliderCurrentDuration;
@property (weak, nonatomic) IBOutlet UIView *activityParentView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *controlBottomConstraint;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *prevTrackButton;
@property (weak, nonatomic) IBOutlet UIButton *nextTrackButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topMenuConstraint;

@property (nonatomic, strong) VLCMediaPlayer *mediaPlayer;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;

@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) id endObserver;
@property (nonatomic, strong) id connObserver;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, strong) NSTimer *controlTimer;
@property (nonatomic, strong) NSTimer *rtspPlayTimer;
@property (nonatomic, strong) NSTimer *timerDuration;

@property (nonatomic, strong) NSData *cacheData;
@property (nonatomic, strong) NSFileManager *fileMgr;
@property (nonatomic, strong) NSMutableArray *requests;
@property (nonatomic, strong) NSString *filename;

@property (nonatomic) int downloadedBytes;
@property (nonatomic) BOOL shouldDeleteTemporaryFile;
@property (nonatomic) BOOL resumesAutomatically;
@property (nonatomic) BOOL activityVisible;
@property (nonatomic) BOOL osdVisible;
@property (nonatomic) BOOL playVisible;
@property (nonatomic) BOOL playCheck;
@property (nonatomic) int  playCheckCount;

@property (nonatomic) BOOL wasPlayingOnSeekStart;
@property (nonatomic) BOOL canMoveToAnotherFile;
/////////

@property (weak, nonatomic) NSString *fileDuration;
@property (nonatomic) BOOL mDismissSatatus;

@property (nonatomic) float durationCurrent;
@property (nonatomic) float durationTotal;
@property (nonatomic) float durationPause;

@property (nonatomic) BOOL sliderDurationCurrentTouched;
@property (nonatomic) BOOL stoppingIsInPlaying;
@property (nonatomic, strong) NSMutableArray *observers;

@end

@implementation VideoPlayViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //self.activityParentView.layer.cornerRadius = 10.0;
    
    UIImage *thumb = [UIImage imageNamed:@"player_control_progrees"];
    [_sliderCurrentDuration setThumbImage:thumb forState:UIControlStateNormal];
    _sliderCurrentDuration.continuous = YES;
    [_sliderCurrentDuration addTarget:self action:@selector(onSliderCurrentDurationTouched:) forControlEvents:UIControlEventTouchDown];
    [_sliderCurrentDuration addTarget:self action:@selector(onSliderCurrentDurationTouchedOut:) forControlEvents:UIControlEventTouchUpInside];
    [_sliderCurrentDuration addTarget:self action:@selector(onSliderCurrentDurationTouchedOut:) forControlEvents:UIControlEventTouchUpOutside];
    [_sliderCurrentDuration addTarget:self action:@selector(onSliderCurrentDurationChanged:) forControlEvents:UIControlEventValueChanged];
    [_sliderCurrentDuration setHidden:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appplicationEnteredBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationEnteredForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)appplicationEnteredBackground:(NSNotification *)notification {
    NSLog(@"Application Did Become Active");
    if (self.mediaPlayer) {
        if (![self.mediaPlayer isPlaying]) {
            [self.mediaPlayer play];
            self.playVisible = YES;
        }
    }
}

- (void)applicationEnteredForeground:(NSNotification *)notification {
    NSLog(@"Application Entered Foreground");
    if (self.mediaPlayer) {
        if ([self.mediaPlayer isPlaying]) {
            [self.mediaPlayer pause];
            self.playVisible = NO;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self registerNotifications];
    
    [UIApplication sharedApplication].statusBarHidden = NO;
    self.activityVisible = YES;
    self.osdVisible = YES;
    self.playVisible = NO;
    self.playCheck = NO;
    self.playCheckCount = 0;
    self.prevTrackButton.enabled = [self.delegate hasPreviousFile];
    self.nextTrackButton.enabled = [self.delegate hasNextFile];
    if(_playType == 1){
        self.titleLabel.text = [self.recordData objectForKey:@"recordFileName"];
    }else {
        self.titleLabel.text = self.file.alertTitleString;
    }
    
    
    if([[UIApplication sharedApplication] statusBarFrame].size.height == 0){
        _topMenuConstraint.constant = 45;
    }
    
    [self turnRtspPlayModeOn];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self cancelControlTimer];
    [self deregisterNotifications];
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"isDismissing:%d", self.isBeingDismissed);
    //[self removePlayerObservers];
    //[self removeConnectionObserver];
    
    [super viewDidDisappear:animated];
}

#pragma mark - Notifications

- (void)registerNotifications
{
    if (self.observers) {
        return;
    }
    self.observers = [NSMutableArray array];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    id ob;
    
    TWAmbaConnection *ambaConn = [TWAmbaConnection sharedInstance];
    
    ob = [nc addObserverForName:TWAmbaConnectionDidChangeConnectionStatusNotification
                         object:ambaConn
                          queue:[NSOperationQueue mainQueue]
                     usingBlock:^(NSNotification *note) {
                         TWAmbaConnectionStatus status = ambaConn.connectionStatus;
                         switch (status) {
                             case TWAmbaConnectionStatusConnecting:
                             case TWAmbaConnectionStatusDisconnecting:
                                 break;
                             case TWAmbaConnectionStatusNotConnected:
                             {
                                 [self dismiss];
                                 break;
                             }
                             case TWAmbaConnectionStatusConnected:
                             {
                                 break;
                             }
                         }
                     }];
    
    [self.observers addObject:ob];
}

- (void)deregisterNotifications
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    for (id ob in self.observers) {
        [nc removeObserver:ob];
    }
    self.observers = nil;
}

- (void)startRtspPlayTimer
{
    [self cancelRtspPlayTimer];
    
    self.rtspPlayTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                          target:self
                                                        selector:@selector(onRtspPlayTimer:)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)cancelRtspPlayTimer
{
    if (self.rtspPlayTimer) {
        [self.rtspPlayTimer invalidate];
        self.rtspPlayTimer = nil;
    }
}

- (void)onRtspPlayTimer:(NSTimer *)timer {
    [self dismiss];
}

#pragma mark - Getter / Setter

+ (TWRecordFilePlayerViewController *)viewController
{
    TWRecordFilePlayerViewController *vc = [[self alloc] initWithNibName:@"TWRecordFilePlayerViewController" bundle:nil];
    return vc;
}

//- (void)setFile:(TWAmbaRecordingFile *)file
//{
//    self.canMoveToAnotherFile = NO;
//
//    _file = file;
//
//    [self clearPlayer];
//
//    self.prevTrackButton.enabled = [self.delegate hasPreviousFile];
//    self.nextTrackButton.enabled = [self.delegate hasNextFile];
//    self.titleLabel.text = file.alertTitleString;
//    //    NSLog(@"Prev=%d, Next=%d", (int)self.prevTrackButton.enabled, (int)self.nextTrackButton.enabled);
//
//    BOOL isDownloaded = file.existsInDownloadFolder;
//    if (isDownloaded) {
//        self.filename = file.downloadPath;
//        if (self.movieView) {
//            [self loadResource];
//        }
//    } else {
//        [self startDownloadingFile];
//    }
//}

- (NSFileManager *)fileMgr
{
    if (_fileMgr == nil) _fileMgr = [[NSFileManager alloc] init];
    return _fileMgr;
}

- (NSMutableArray *)requests
{
    if (_requests == nil) _requests = [NSMutableArray array];
    return _requests;
}

- (int)currentFileSize
{
    if (self.cacheData) {
        return (int)self.cacheData.length;
    }
    NSDictionary *attrs = [self.fileMgr attributesOfItemAtPath:self.filename error:nil];
    int size = [attrs[NSFileSize] intValue];
    return size;
}

- (void)setDownloadedBytes:(int)downloadedBytes
{
    _downloadedBytes = downloadedBytes;
    if (_expectedSize == 0) {
        return;
    }
    float progress = (float)downloadedBytes / _expectedSize;
    self.downloadProgress.progress = progress;
}

- (void)setActivityVisible:(BOOL)activityVisible
{
    _activityVisible = activityVisible;
    if (activityVisible) {
        //self.activityParentView.hidden = NO;
        [self.activityView startAnimating];
    } else {
        //self.activityParentView.hidden = YES;
        [self.activityView stopAnimating];
    }
}

- (void)setOsdVisible:(BOOL)osdVisible
{
    _osdVisible = osdVisible;
    
    NSLog(@"ShowsOSD=%d", osdVisible);
    
    CGFloat alpha, top, bot;
    if (osdVisible) {
        alpha = 1.0;
        top = 0.0;
        bot = 0.0;
    } else {
        alpha = 0.0;
        top = -self.titleParent.frame.size.height;
        bot = -self.controlParent.frame.size.height;
    }
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.titleParent.alpha = alpha;
                         self.controlParent.alpha = alpha;
                         self.titleTopConstraint.constant = top;
                         self.controlBottomConstraint.constant = bot;
                         [self.view layoutIfNeeded];
                     }];
    
    [[UIApplication sharedApplication] setStatusBarHidden:!osdVisible withAnimation:UIStatusBarAnimationSlide];
}

- (void)setPlayVisible:(BOOL)playVisible
{
    _playVisible = playVisible;
    
    UIImage *normal, *pressed;
    if (playVisible) {
        normal = [UIImage imageNamed:@"player_btn_play_n.png"];
        pressed = [UIImage imageNamed:@"player_btn_play_p.png"];
    } else {
        normal = [UIImage imageNamed:@"player_btn_pause_n.png"];
        pressed = [UIImage imageNamed:@"player_btn_pause_p.png"];
    }
    
    [self.playButton setImage:normal forState:UIControlStateNormal];
    [self.playButton setImage:pressed forState:UIControlStateHighlighted];
}

#pragma mark - Control Event

- (void)dismiss
{
    
    if (self.mediaPlayer && [self.mediaPlayer isPlaying]) {
        [self.mediaPlayer stop];
        //self.mediaPlayer = nil;
        self.playVisible = NO;
    }else {
        [self cancelRtspPlayTimer];
        [self cancelControlTimer];
        
        [self hideActivityIndicator];
    }
    
    //    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    //[self dismissViewControllerAnimated:YES completion:NULL];
    //    if(!_mDismissSatatus){
    //        _mDismissSatatus = YES;
    //        [self turnRtspPlayModeOff];
    //    }
    //[self performSelector:@selector(dismissNext) withObject:nil afterDelay:0.3];
    
}


- (void) dismissNext {
    //self.mediaPlayer = nil;
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)onBtnDone:(UIButton *)button
{
    [self dismiss];
}

- (IBAction)onBtnPrevious:(UIButton *)button
{
    //    if (!self.canMoveToAnotherFile) {
    //        NSLog(@"Cannot move to another file <Prev>");
    //        return;
    //    }
    self.playCheck = NO;
    self.playCheckCount = 0;
    [self startRtspPlayTimer];
    [self updateControlTimer];
    
    [self.delegate moveRtspFileIndex:-1 playerViewController:self];
    self.prevTrackButton.enabled = [self.delegate hasPreviousFile];
    self.nextTrackButton.enabled = [self.delegate hasNextFile];
    [self nextFilePlay];
}

- (IBAction)onBtnNext:(UIButton *)button
{
    //    if (!self.canMoveToAnotherFile) {
    //        NSLog(@"Cannot move to another file <Next>");
    //        return;
    //    }
    self.playCheck = NO;
    self.playCheckCount = 0;
    [self startRtspPlayTimer];
    [self updateControlTimer];
    
    [self.delegate moveRtspFileIndex:+1 playerViewController:self];
    self.prevTrackButton.enabled = [self.delegate hasPreviousFile];
    self.nextTrackButton.enabled = [self.delegate hasNextFile];
    [self nextFilePlay];
}

- (IBAction)onBtnPlayOrPause:(UIButton *)button
{
    if (self.mediaPlayer) {
        if ([self.mediaPlayer isPlaying]) {
            [self.mediaPlayer pause];
            self.playVisible = YES;
        }else {
            [self.mediaPlayer play];
            self.playVisible = NO;
        }
        [self updateControlTimer];
    }else {
        
    }
    
    //    [self performSelector:@selector(togglePause)];
    //
    //    BOOL isPlaying = _decodeManager.streamIsPaused;
    //    if (isPlaying) {
    //        self.playVisible = YES;
    //    } else {
    //        self.playVisible = NO;
    //    }
    //
    //    [self updateControlTimer];
    
}

- (void)togglePause {
    //    if(!_decodeManager.streamIsPaused){
    //        [_decodeManager performSelector:@selector(streamTogglePause)];
    //        _durationPause = (float)(_durationCurrent);
    //        NSLog(@"[CHECKS] TWRecordFilePlayerViewController : Pause duration : %.2f", _durationPause);
    //    }else {
    //        [self uninstallLiveDecoder:^{
    //            [self showActivityIndicator];
    //            [self installLiveDecoder];
    //        }];
    //        //[self setStreamCurrentDuration:_durationPause];
    //
    //    }
    
}

- (IBAction)onTapOnMovie:(UITapGestureRecognizer *)gr
{
    self.osdVisible = !self.osdVisible;
    if (self.osdVisible) {
        [self updateControlTimer];
    } else {
        [self cancelControlTimer];
    }
}

#pragma mark - Control Timer

- (void)updateControlTimer
{
    [self cancelControlTimer];
    
    self.controlTimer = [NSTimer scheduledTimerWithTimeInterval:5
                                                         target:self
                                                       selector:@selector(onControlTimer:)
                                                       userInfo:nil
                                                        repeats:NO];
}

- (void)cancelControlTimer
{
    if (self.controlTimer) {
        [self.controlTimer invalidate];
        self.controlTimer = nil;
    }
}

- (void)onControlTimer:(NSTimer *)timer
{
    self.osdVisible = NO;
}

#pragma mark - View Auto Rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    sleep(0.1);
    
    if (self.isBeingDismissed) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return UIInterfaceOrientationMaskLandscapeRight;
    //return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    //return UIInterfaceOrientationMaskLandscapeRight;
    return UIInterfaceOrientationLandscapeRight;
}

- (BOOL)prefersStatusBarHidden
{
    NSLog(@"");
    
    return YES;
}
///////////////////////////////////////////////////////////////////////////////
#pragma mark - RTSP handling

- (void)installLiveDecoder
{
    //NSDictionary *device = [[TWAmbaConnection sharedInstance] systemStatusWithKey:@"device"];
    NSString *urlString = @"";
    NSString *fileType = @"";
    if(_playType == 1){
        urlString = [_recordData objectForKey:@"recordDownUrl"];//@"rtsp://52.79.169.203/vod/_definst_/mp4:/blackbox/upload/record/20180220/EVT_2012_07_27_17_58_20_F.MP4";//
        fileType = @"EVT";
    }else {
        NSString *ipAddress = [TWAmbaConnection sharedInstance].ipAddress;
        NSString *fileName = self.file.file;
        NSString *fileDirectory = @"";
        
        fileType = self.file.type;
        
        if ([fileType isEqualToString:@"REC"]) {
            fileDirectory = @"cont_rec";
        } else if ([fileType isEqualToString:@"EVT"]) {
            fileDirectory = @"evt_rec";
        } else if ([fileType isEqualToString:@"PAK"]) {
            fileDirectory = @"parking_rec";
        } else if ([fileType isEqualToString:@"MOT"] || [fileType isEqualToString:@"TIM"]) {
            if([APP_DELEGATE checkAvailableTimelaps:[GlobalData getConnectedBlackboxModel]]){
                fileDirectory = @"motion_timelapse_rec";
            }else {
                fileDirectory = @"motion_rec";
            }
        } else if ([fileType isEqualToString:@"MAN"]) {
            fileDirectory = @"manual_rec";
        }
        
        urlString = [NSString stringWithFormat:@"rtsp://%@/tmp/SD0/%@/%@", ipAddress, fileDirectory, fileName];
    }
    
    NSLog(@"[CHECKS] TWRecordFilePlayerViewController - url : %@", urlString);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (_mediaPlayer == nil) {
            NSMutableArray *options = [[NSMutableArray alloc]init];
            
            [options addObject:@"--no-sub-autodetect-file"];
            [options addObject:@"--no-playlist-autostart"];
            [options addObject:@"--aout=opensles"];
            [options addObject:@"--audio-time-stretch"];
            [options addObject:@"--no-auto-preparse"];
            [options addObject:@"--no-drop-late-frames"];
            [options addObject:@"--no-skip-frames"];
            [options addObject:@"--play-and-stop"];
            [options addObject:@"--codec=all"];  // ffmpeg, avcodec
            [options addObject:@"--network-caching=1000"]; // 1000
            [options addObject:@"--rtsp-frame-buffer-size=400000"];
            
            
            if([fileType isEqualToString:@"PAK"] || [fileType isEqualToString:@"MOT"] || [fileType isEqualToString:@"TIM"]){
                //타임랩스, 모션 등의 저프레임(10fps)의 영상을 위한 세팅
                [options addObject:@"--file-caching=0"];
                [options addObject:@"--tcp-caching=0"];
                [options addObject:@"--rtsp-caching=1000"];
                [options addObject:@"--network-caching=1000"];
                [options addObject:@"--clock-jitter=5000"];
                [options addObject:@"--clock-synchro=0"];
            }
            
            _mediaPlayer = [[VLCMediaPlayer alloc] initWithOptions:options ];
            [_mediaPlayer setDeinterlaceFilter:@"blend"];
        }
        //_mediaPlayer = [[VLCMediaPlayer alloc] init];
        
        
        VLCMedia *media       = [VLCMedia mediaWithURL:[NSURL URLWithString:urlString]];
        //[media synchronousParse];
        
        _mediaPlayer.media    = media;
        _mediaPlayer.drawable = _movieView;
        _mediaPlayer.delegate = self;
        _mediaPlayer.libraryInstance.debugLogging = YES;
        
        [_mediaPlayer play];
    });
    __weak __typeof__(self) weakSelf = self;
    
    [weakSelf.ambaConn getRecordingFileInfo:_file completion:^(NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _fileDuration = [weakSelf secToTime:[result[@"duration"] intValue]];
            weakSelf.durationLabel.text = _fileDuration;
        });
    }];
    
}

- (void)decoderTimeChanged:(double)audioTime videoTime:(double)videoTime {
    NSLog(@"SCK decoderTimeChanged - audioTime : %f, videoTime : %f", audioTime, videoTime);
    
    //    if(_decodeManager.durationInSeconds <= round(videoTime)){
    //        [self dismiss];
    //    }else {
    //        _sliderCurrentDuration.value = round(videoTime) / _decodeManager.durationInSeconds;
    //        _positionLabel.text = [self secToTime:round(videoTime)];
    //        _durationLabel.text = [self secToTime:_decodeManager.durationInSeconds];
    //    }
}

#pragma mark - Amba Operations

- (void)turnRtspPlayModeOn
{
    [self showActivityIndicator];
    [self installLiveDecoder];
    [self startRtspPlayTimer];
}

- (void)turnRtspPlayModeOff
{
    [self hideActivityIndicator];
    if (self.mediaPlayer) {
        if ([self.mediaPlayer isPlaying]) {
            [self.mediaPlayer stop];
            //self.mediaPlayer = nil;
            self.playVisible = NO;
        }
    }
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)nextFilePlay{
    [self showActivityIndicator];
    
    if (self.mediaPlayer) {
        if ([self.mediaPlayer isPlaying]) {
            [self.mediaPlayer stop];
            _stoppingIsInPlaying = YES;
        }
        
        self.mediaPlayer = nil;
        self.playVisible = NO;
    }
    
    if(_playType == 1){
        self.titleLabel.text = [self.recordData objectForKey:@"recordFileName"];
    }else {
        self.titleLabel.text = self.file.alertTitleString;
    }
    
    [self performSelector:@selector(installLiveDecoder) withObject:nil afterDelay:1];
    //    [self uninstallLiveDecoder:^{
    //        if(_playType == 1){
    //            self.titleLabel.text = [self.recordData objectForKey:@"recordFileName"];
    //        }else {
    //            self.titleLabel.text = self.file.alertTitleString;
    //        }
    //        self.positionLabel.text = @"00:00:00";
    //        _durationPause = 0.0;
    //        [self installLiveDecoder];
    //    }];
}



- (NSString *)secToTime:(NSInteger)sec
{
    NSInteger hour = sec / 60*60;
    if (1 < hour)
    {
        hour = 0;
    }
    
    NSInteger min = (sec - (hour * 60)) / 60;
    if (1 < min)
    {
        min = 0;
    }
    
    sec = fmod(sec, 60);
    
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hour,(long)min,(long)sec];
}

- (IBAction)onSliderTouchDown:(UISlider *)slider
{
    //[_decodeManager togglePause];
}

- (IBAction)onSliderProgress:(UISlider *)slider
{
    double position = slider.value * self.duration;
    self.positionLabel.text = @""; //[self timeStringWithTimeInterval:position];
}

- (IBAction)onSliderTouchUp:(UISlider *)slider
{
    double seconds;
    //    seconds = slider.value * _decodeManager.durationInSeconds;
    //    [_decodeManager doSeek:seconds];
    //    [_decodeManager togglePause];
}

#pragma mark - Error descriptions

//static NSString * errorText(VSError errCode)
//{
//    switch (errCode) {
//        case kVSErrorNone:
//            return @"";
//
//        case kVSErrorUnsupportedProtocol:
//            return TR(@"Protocol is not supported");
//
//        case kVSErrorStreamURLParseError:
//            return TR(@"Stream url or params can not be parsed");
//
//        case kVSErrorOpenStream:
//            return TR(@"Failed to connect to the stream server");
//
//        case kVSErrorStreamInfoNotFound:
//            return TR(@"Can not find any stream info");
//
//        case kVSErrorStreamsNotAvailable:
//            return TR(@"Can not open any A-V stream");
//
//        case kVSErrorAudioCodecNotFound:
//            return TR(@"Audio codec is not found");
//
//        case kVSErrorStreamDurationNotFound:
//            return TR(@"Stream duration is not found");
//
//        case kVSErrorAudioStreamNotFound:
//            return TR(@"Audio stream is not found");
//
//        case kVSErrorVideoCodecNotFound:
//            return TR(@"Video codec is not found");
//
//        case kVSErrorVideoStreamNotFound:
//            return TR(@"Video stream is not found");
//
//        case kVSErrorAudioCodecNotOpened:
//            return TR(@"Audio codec can not be opened");
//
//        case kVSErrorVideoCodecNotOpened:
//            return TR(@"Video codec can not be opened");
//
//        case kVSErrorAudioAllocateMemory:
//            return TR(@"Can not allocate memory for Audio");
//
//        case kVSErrorVideoAllocateMemory:
//            return TR(@"Can not allocate memory for Video");
//
//        case kVSErrorUnsupportedAudioFormat:
//            return TR(@"Audio format is not supported");
//
//        case kVSErrorAudioStreamAlreadyOpened:
//            return TR(@"Audio is already opened, close the current first, then open again");
//
//        case kVSErroSetupScaler:
//            return TR(@"Unable to setup scaler");
//
//        case kVSErrorStreamReadError:
//            return TR(@"Can not read from stream server");
//
//        case kVSErrorStreamEOFError:
//            return TR(@"End of stream");
//    }
//    return nil;
//}

- (void)startDurationTimer {
    [self stopDurationTimer];
    _timerDuration = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(onTimerDurationFired:) userInfo:nil repeats:YES];
}

- (void)stopDurationTimer {
    if (_timerDuration && [_timerDuration isValid]) {
        [_timerDuration invalidate];
    }
    _timerDuration = nil;
}

#pragma mark Timers callbacks

- (void)onTimerDurationFired:(NSTimer *)timer {
    //    if (_decoderState == kVSDecoderStatePlaying) {
    //        _durationCurrent = (_decodeManager) ? [_decodeManager currentTime] : 0.0;
    //        NSLog(@"SCK DurationCurrent : %f",_durationCurrent);
    //        if (!isnan(_durationCurrent) && ((_durationTotal - _durationCurrent) > -1.0)) {
    //            _positionLabel.text = [NSString stringWithFormat:@"00:%02d:%02d", (int)_durationCurrent/60, ((int)_durationCurrent % 60)];
    //            if(!_sliderDurationCurrentTouched) {
    //                _sliderCurrentDuration.value = _durationCurrent;
    //                NSLog(@"Time : %d", @(_durationCurrent / _durationTotal));
    //                if (_durationTotal <= _durationCurrent) {
    //                    [self dismiss];
    //                }
    //            }
    //        }
    //    }
}

- (void)onSliderCurrentDurationTouched:(id) sender {
    _sliderDurationCurrentTouched = YES;
    [self stopDurationTimer];
    //[_decodeManager togglePause];
}

- (void)onSliderCurrentDurationTouchedOut:(id) sender {
    _sliderDurationCurrentTouched = NO;
    
    //_positionLabel.text = [NSString stringWithFormat:@"00:%02d:%02d", (int)_sliderCurrentDuration.value/60, ((int)_sliderCurrentDuration.value % 60)];
    [self setStreamCurrentDuration:_sliderCurrentDuration.value];
    [self startDurationTimer];
}

- (void)onSliderCurrentDurationChanged:(id) sender {
    _durationCurrent = [(UISlider*)sender value];
    [self updateControlTimer];
    _positionLabel.text = [NSString stringWithFormat:@"00:%02d:%02d", (int)_durationCurrent/60, ((int)_durationCurrent % 60)];
}

- (void)setStreamCurrentDuration:(float)value  {
    //[_decodeManager doSeek:value];
    //[_decodeManager togglePause];
}

#pragma mark - AudioSession interruption

#pragma mark iOS 5.x Audio interruption handling

- (void)beginInterruption {
    //    if (_decodeManager) {
    //        [_decodeManager beginInterruption];
    //    }
}

- (void)endInterruptionWithFlags:(NSUInteger)flags {
    // re-activate audio session after interruption
    //    if (_decodeManager) {
    //        [_decodeManager endInterruptionWithFlags:flags];
    //    }
}

#pragma mark iOS 6.x or higher Audio interruption handling

- (void) interruption:(NSNotification*)notification
{
    //    if (_decodeManager) {
    //        [_decodeManager interruption:notification];
    //    }
}

#pragma mark - VLCMediaPlayerDelegate
- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{
    [self hideActivityIndicator];
    
    VLCMediaPlayer *tempPlayer = (VLCMediaPlayer *)aNotification.object;
    if (tempPlayer) {
        if ([tempPlayer isPlaying]) {
            [self cancelRtspPlayTimer]; // RTSP 영상이 시작되면 종료시킨다.
            [self updateControlTimer];
            self.osdVisible = YES;
            self.playCheck = YES;
            [self hideActivityIndicator];
        }
        else {
            
            if(tempPlayer.state == VLCMediaPlayerStateStopped ){
                [self cancelRtspPlayTimer]; // RTSP 영상이 시작되면 종료시킨다.
                [self cancelControlTimer];
                _mediaPlayer.delegate = nil;
                _mediaPlayer = nil;
                _mediaPlayer = [[VLCMediaPlayer alloc] init];
                
                if(!_stoppingIsInPlaying){
                    if(!_playCheck && _playCheckCount < 3){
                        _playCheckCount++;
                        sleep(0.2);
                        [self turnRtspPlayModeOn];
                    }else {
                        [self stopDurationTimer];
                        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
                        [self performSelector:@selector(dismissNext) withObject:nil afterDelay:0.3];
                    }
                }else {
                    _stoppingIsInPlaying = NO;
                }
            }else{
                
            }
        }
    }
}

-(void)mediaPlayerTimeChanged:(NSNotification *)aNotification
{
    //NSLog(@"mediaPlayerTimeChanged : %@", aNotification);
    VLCMediaPlayer *tempPlayer = (VLCMediaPlayer *)aNotification.object;
    //NSLog(@"mediaPlayerTimeChanged : Time = %@, RemainingTime = %@", tempPlayer.time, tempPlayer.remainingTime);
    
    _durationLabel.text = [NSString stringWithFormat:@"00:%@", [tempPlayer.media.length stringValue]];
    _positionLabel.text = [NSString stringWithFormat:@"00:%@", [tempPlayer.time stringValue]];
    NSString *remainingTime = [tempPlayer.remainingTime stringValue];
    if([remainingTime isEqualToString:@"-00:01"]){
        [self dismiss];
    }
}

- (void)mediaPlayerSnapshot:(NSNotification *)aNotification
{
    // aNotification -> VLCMediaPlayerSnapshotTaken
    // Recently snapshot -> last object of snapshots
    //NSLog(@"mediaPlayerSnapshot : %@", aNotification);
    
    NSLog(@"SnapShots : %@", _mediaPlayer.snapshots);
    
    // 파일 읽어오기(테스트)
    //    NSFileManager * fileManager = [NSFileManager defaultManager];
    //    NSData * dataBuffer = [fileManager contentsAtPath:[_mediaPlayer.snapshots objectAtIndex:0]];
    //
    //    //_btnGallery.imageView.image = [UIImage imageWithData:dataBuffer];
    //    [_btnGallery setImage:[UIImage imageWithData:dataBuffer] forState:UIControlStateNormal];
    
}

@end

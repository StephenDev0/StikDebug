//
//  PiPController.m
//  StikDebug
//
//  Created by Stossy11 on 10/07/2025.
//

#import "PiPController.h"

@interface PiPController ()
@property (nonatomic, strong, nullable) AVPictureInPictureController *pipController;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, strong, nullable) UIView *customView;
@end

@implementation PiPController

+ (PiPController *)shared {
    static PiPController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isPiPActive = NO;
        [self setupAudioSession];
    }
    return self;
}

- (void)setupAudioSession {
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    if (![audioSession setCategory:AVAudioSessionCategoryPlayback error:&error]) {
        NSLog(@"Audio session setup error: %@", error.localizedDescription);
        return;
    }
    
    if (![audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error]) {
        NSLog(@"Audio session setup error: %@", error.localizedDescription);
    }
}

- (void)setupPiPWithPlayerLayer:(AVPlayerLayer *)playerLayer {
    if (![AVPictureInPictureController isPictureInPictureSupported]) {
        NSLog(@"Picture in Picture not supported");
        return;
    }
    
    self.playerLayer = playerLayer;
    
    self.pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:playerLayer];
    self.pipController.delegate = self;
    
    // Set controls style (equivalent to setValue:forKey: in Swift)
    if ([self.pipController respondsToSelector:@selector(setControlsStyle:)]) {
        [self.pipController setValue:@(1) forKey:@"controlsStyle"];
    }
}

- (void)startPiP {
    if (self.pipController.isPictureInPictureActive) return;
    
    [self.pipController startPictureInPicture];
}

- (void)stopPiP {
    if (!self.pipController.isPictureInPictureActive) return;
    
    [self.pipController stopPictureInPicture];
}

- (void)togglePiP {
    if (self.isPiPActive) {
        [self stopPiP];
    } else {
        [self startPiP];
    }
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    if (!self.customUIView) {
        NSLog(@"Fatal error: customUIView = nil");
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPiPActive = YES;
    });
    
    self.customView = self.customUIView;
    
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (window && self.customView) {
        self.customView.backgroundColor = [UIColor clearColor];
        [window addSubview:self.customView];
        
        self.customView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [self.customView.topAnchor constraintEqualToAnchor:window.topAnchor],
            [self.customView.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
            [self.customView.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
            [self.customView.bottomAnchor constraintEqualToAnchor:window.bottomAnchor]
        ]];
    }
}


- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    NSLog(@"PiP started");
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPiPActive = NO;
    });
    
    // Remove custom view
    [self.customView removeFromSuperview];
    self.customView = nil;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
    NSLog(@"Failed to start PiP: %@", error.localizedDescription);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isPiPActive = NO;
    });
}

@end
